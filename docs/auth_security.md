# KAAM25 Auth, Approval, and Device Control

## Auth Flow (Client)
- Firebase initializes in `main.dart` using `firebase_options.dart` before `runApp`.
- `AuthController` listens to Firebase Auth state and evaluates gates in this order:
  1) Admin role → allow.
  2) Blocked → `AuthGate.blocked` → `/blocked`.
  3) Not approved → `AuthGate.pendingApproval` → `/pending`.
  4) Device not in `users/{uid}.devices` → enqueue login_requests, set `AuthGate.devicePending` → `/device-pending`.
  5) Otherwise `AuthGate.authorized` → `/app`.
- Device ID is generated once, stored in secure storage, and re-used on every launch.
- Google and Email/Password feed the same approval path.

## Firestore Schema
- Collection `users/{uid}` fields:
  - `name`, `email`, `role: admin|member`, `approved: bool`, `blocked: bool`, `devices: string[]`, `createdAt: timestamp`, `lastLogin: timestamp?`, `photoUrl?`.
- Collection `login_requests/{uid_deviceId}` fields:
  - `userId`, `deviceId`, `deviceInfo` (map), `status: pending|approved|rejected`, `createdAt: timestamp`, `handledAt?`.

## Cloud Functions (Backend Authority)
Store `SUPER_ADMIN_UID` in env config, never in the client.

**bootstrapUser (HTTPS callable)**
```ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const SUPER_ADMIN_UID = process.env.SUPER_ADMIN_UID ?? '';

export const bootstrapUser = functions.https.onCall(async (data, context) => {
  const { uid, email, name, photoUrl, deviceId, deviceInfo } = data;
  if (!uid || !email) throw new functions.https.HttpsError('invalid-argument', 'uid/email required');

  const userRef = admin.firestore().collection('users').doc(uid);
  const snap = await userRef.get();
  if (snap.exists) return { ok: true };

  const isSuperAdmin = uid === SUPER_ADMIN_UID;
  const now = admin.firestore.FieldValue.serverTimestamp();

  const base = {
    email,
    name: name || email,
    photoUrl: photoUrl || null,
    createdAt: now,
    lastLogin: now,
    blocked: false,
    devices: isSuperAdmin ? [deviceId] : [],
  };

  if (isSuperAdmin) {
    await userRef.set({ ...base, role: 'admin', approved: true });
  } else {
    await userRef.set({ ...base, role: 'member', approved: false });
    await admin.firestore().collection('login_requests').doc(`${uid}_${deviceId}`).set({
      userId: uid,
      deviceId,
      deviceInfo,
      status: 'pending',
      createdAt: now,
    }, { merge: true });
  }

  return { ok: true };
});
```

**approveUser/approveDevice (admin-only callable)**
```ts
function assertAdmin(context: functions.https.CallableContext) {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Auth required');
  // Use custom claims set via Cloud Functions or Firebase Console
  if (!context.auth.token.admin) throw new functions.https.HttpsError('permission-denied', 'Admin only');
}

export const approveUser = functions.https.onCall(async (data, context) => {
  assertAdmin(context);
  const { uid } = data;
  await admin.firestore().collection('users').doc(uid).set({ approved: true }, { merge: true });
});

export const approveDevice = functions.https.onCall(async (data, context) => {
  assertAdmin(context);
  const { uid, deviceId } = data;
  const userRef = admin.firestore().collection('users').doc(uid);
  await userRef.update({ devices: admin.firestore.FieldValue.arrayUnion(deviceId) });
  await admin.firestore().collection('login_requests').doc(`${uid}_${deviceId}`).set({
    status: 'approved',
    handledAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
});
```

## Firestore Security Rules (enforce authority)
```rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() { return request.auth != null; }
    function isAdmin() { return request.auth.token.admin == true; }
    function isSelf(uid) { return request.auth != null && request.auth.uid == uid; }

    match /users/{uid} {
      allow read: if isSelf(uid) || isAdmin();
      allow update: if isAdmin();
      allow create: if false; // created only by Cloud Functions bootstrap
    }

    match /login_requests/{requestId} {
      allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
      allow read: if isAdmin();
      allow update, delete: if isAdmin();
    }
  }
}
```

## Test Matrix
1) Super admin first login → bootstrap creates admin, approved=true, device auto-approved → `/app`.
2) Member first login → user doc created with approved=false → `/pending`.
3) Admin approves user → user approved=true; next auth state → `/app`.
4) New device for member → login_requests entry created → `/device-pending` until admin approves device.
5) Admin approves device → device ID added → next auth refresh → `/app`.
6) Blocked user → blocked=true → `/blocked` immediately on auth refresh.
7) Client cannot set role/approved/devices due to rules and backend-only mutations.

## Release Checklist
- Firebase Auth providers enabled: Email/Password and Google.
- Firestore, Storage, Cloud Functions enabled.
- `firebase_options.dart` generated via FlutterFire CLI and checked in.
- `SUPER_ADMIN_UID` set in Cloud Functions environment (not in client).
- Security rules deployed with admin-only mutations.
- Play/App Store SHA/certs registered so Google Sign-In works.
- Manual smoke: Android/iOS sign-in, approval, device approval, block user, logout/login.