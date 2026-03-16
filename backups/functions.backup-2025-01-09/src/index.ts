import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

admin.initializeApp();
const db = admin.firestore();

function getSuperAdminUid(): string {
  const uid = functions.config().super?.admin_uid;
  if (!uid) {
    throw new functions.https.HttpsError('failed-precondition', 'SUPER_ADMIN_UID not configured');
  }
  return uid as string;
}

// Better admin check that queries Firestore
async function assertAdminAsync(context: functions.https.CallableContext): Promise<void> {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  
  // Check custom claim first (fast)
  if (context.auth.token.admin) {
    return;
  }
  
  // Fallback to Firestore check (for admins without custom claims set yet)
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }
  
  const userData = userDoc.data();
  if (userData?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Admin only');
  }
  
  // Set custom claim for future requests
  await admin.auth().setCustomUserClaims(context.auth.uid, { admin: true });
}

export const bootstrapUser = functions.https.onCall(async (data, context) => {
  const { uid, email, name, photoUrl, deviceId, deviceInfo } = data;

  if (!uid || !email) {
    throw new functions.https.HttpsError('invalid-argument', 'uid and email are required');
  }

  const superAdminUid = getSuperAdminUid();
  const userRef = db.collection('users').doc(uid);
  const snap = await userRef.get();
  if (snap.exists) {
    return { ok: true, skipped: true };
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const isSuperAdmin = uid === superAdminUid;
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
    await userRef.set({
      ...base,
      role: 'admin',
      approved: true,
    });
    // Set custom claim so Firestore rules recognize admin
    await admin.auth().setCustomUserClaims(uid, { admin: true });
  } else {
    await userRef.set({
      ...base,
      role: 'member',
      approved: false,
    });

    await db.collection('login_requests').doc(`${uid}_${deviceId}`).set(
      {
        userId: uid,
        deviceId,
        deviceInfo: deviceInfo || {},
        status: 'pending',
        createdAt: now,
      },
      { merge: true },
    );
  }

  return { ok: true };
});

export const approveUser = functions.https.onCall(async (data, context) => {
  await assertAdminAsync(context);
  const { uid } = data;
  if (!uid) throw new functions.https.HttpsError('invalid-argument', 'uid required');

  // Approve user and set custom claim if they're an admin
  const userRef = db.collection('users').doc(uid);
  const userDoc = await userRef.get();
  
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }
  
  const userData = userDoc.data();
  
  await userRef.set({ approved: true }, { merge: true });
  
  // If user is admin, set custom claim
  if (userData?.role === 'admin') {
    await admin.auth().setCustomUserClaims(uid, { admin: true });
  }
  
  return { ok: true };
});

export const approveDevice = functions.https.onCall(async (data, context) => {
  await assertAdminAsync(context);
  const { uid, deviceId } = data;
  if (!uid || !deviceId) {
    throw new functions.https.HttpsError('invalid-argument', 'uid and deviceId required');
  }

  const userRef = db.collection('users').doc(uid);
  const userDoc = await userRef.get();
  
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }
  
  // Add device to user's approved devices
  await userRef.update({ 
    devices: admin.firestore.FieldValue.arrayUnion(deviceId),
    approved: true // Auto-approve user when approving their first device
  });
  
  // Update the login request status
  await db.collection('login_requests').doc(`${uid}_${deviceId}`).set(
    {
      status: 'approved',
      handledAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  
  return { ok: true };
});

export const blockUser = functions.https.onCall(async (data, context) => {
  await assertAdminAsync(context);
  const { uid, reason } = data;
  if (!uid) throw new functions.https.HttpsError('invalid-argument', 'uid required');

  await db.collection('users').doc(uid).set({ 
    blocked: true, 
    approved: false,
    blockedAt: admin.firestore.FieldValue.serverTimestamp(),
    blockedReason: reason || 'Blocked by administrator'
  }, { merge: true });
  
  return { ok: true };
});

export const setAdminClaim = functions.https.onCall(async (data, context) => {
  await assertAdminAsync(context);
  const { uid, admin: isAdmin } = data;
  if (!uid || typeof isAdmin !== 'boolean') {
    throw new functions.https.HttpsError('invalid-argument', 'uid and admin flag required');
  }
  await admin.auth().setCustomUserClaims(uid, { admin: isAdmin });
  return { ok: true };
});

// ========== SECURITY VIOLATION ENFORCEMENT ==========

/**
 * Firestore Trigger: Enforce automatic blocking on violation threshold
 * Triggered when users.screenshotAttempts is updated
 */
export const enforceViolationBlock = functions.firestore
  .document('users/{uid}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const uid = context.params.uid;

    // Check if screenshotAttempts was incremented
    const beforeAttempts = before.screenshotAttempts || 0;
    const afterAttempts = after.screenshotAttempts || 0;

    if (afterAttempts <= beforeAttempts) {
      return null; // No violation increase
    }

    const VIOLATION_THRESHOLD = 3;

    // Auto-block if threshold exceeded
    if (afterAttempts >= VIOLATION_THRESHOLD && !after.blocked) {
      console.log(`🚨 Auto-blocking user ${uid} for ${afterAttempts} violations`);
      
      await change.after.ref.update({
        blocked: true,
        approved: false,
        blockedAt: admin.firestore.FieldValue.serverTimestamp(),
        blockedReason: `Automatic suspension: ${afterAttempts} security violations detected`,
      });

      // Send notification to all admins
      await notifyAdminsOfViolation(uid, after.email, afterAttempts);
    }

    return null;
  });

/**
 * Notify admins via FCM when user is blocked for violations
 */
async function notifyAdminsOfViolation(
  violatorUid: string,
  violatorEmail: string,
  attempts: number
): Promise<void> {
  try {
    const adminsSnapshot = await db.collection('users')
      .where('role', '==', 'admin')
      .get();

    if (adminsSnapshot.empty) {
      console.log('No admins to notify');
      return;
    }

    const fcmTokens: string[] = [];
    adminsSnapshot.forEach((doc) => {
      const data = doc.data();
      if (data.fcmToken) {
        fcmTokens.push(data.fcmToken);
      }
    });

    if (fcmTokens.length === 0) {
      console.log('No admin FCM tokens available');
      return;
    }

    const message = {
      notification: {
        title: '🚨 Security Violation',
        body: `User ${violatorEmail} blocked after ${attempts} screenshot attempts`,
      },
      data: {
        type: 'security_violation',
        violatorUid,
        violatorEmail,
        attempts: attempts.toString(),
      },
      tokens: fcmTokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`✅ Notified ${response.successCount} admins of violation`);
  } catch (error) {
    console.error('❌ Failed to notify admins:', error);
  }
}

/**
 * Callable function: Validate user is not blocked
 * Called before granting access to protected resources
 */
export const validateUserAccess = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }

  const userData = userDoc.data()!;

  if (userData.blocked) {
    throw new functions.https.HttpsError(
      'permission-denied',
      userData.blockedReason || 'Your access has been suspended'
    );
  }

  if (!userData.approved) {
    throw new functions.https.HttpsError('permission-denied', 'Access pending approval');
  }

  return {
    ok: true,
    user: {
      uid: userDoc.id,
      email: userData.email,
      name: userData.name,
      role: userData.role,
      screenshotAttempts: userData.screenshotAttempts || 0,
    },
  };
});

// ========== NOTIFICATIONS ==========

/**
 * Firestore Trigger: Send FCM notification when new announcement is created
 */
export const onAnnouncementCreated = functions.firestore
  .document('announcements/{announcementId}')
  .onCreate(async (snap, context) => {
    const announcement = snap.data();
    const announcementId = context.params.announcementId;

    console.log(`📢 New announcement created: ${announcement.title}`);

    try {
      // Send to 'all_users' topic
      const message = {
        notification: {
          title: `📢 ${announcement.title}`,
          body: announcement.description,
        },
        data: {
          type: 'announcement',
          announcementId: announcementId,
          announcementType: announcement.type || 'general',
          actionRequired: announcement.actionRequired?.toString() || 'false',
        },
        topic: 'all_users',
      };

      await admin.messaging().send(message);
      console.log(`✅ Notification sent to all_users topic`);

      // Also send to announcements topic
      const announcementsMessage = {
        ...message,
        topic: 'announcements',
      };
      await admin.messaging().send(announcementsMessage);
      console.log(`✅ Notification sent to announcements topic`);

      return { success: true };
    } catch (error) {
      console.error('❌ Error sending announcement notification:', error);
      return { success: false, error };
    }
  });

/**
 * Firestore Trigger: Send FCM notification when new chat message is posted
 */
export const onChatMessageCreated = functions.firestore
  .document('chat_messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();

    // Don't send notification for file-only messages without text
    if (!message.content || message.content.trim() === '') {
      return null;
    }

    try {
      const notification = {
        notification: {
          title: `💬 ${message.senderName}`,
          body: message.isFile ? '📎 Sent a file' : message.content,
        },
        data: {
          type: 'chat',
          messageId: context.params.messageId,
          senderId: message.senderId,
          senderName: message.senderName,
        },
        topic: 'all_users',
      };

      await admin.messaging().send(notification);
      console.log(`✅ Chat notification sent for message from ${message.senderName}`);

      return { success: true };
    } catch (error) {
      console.error('❌ Error sending chat notification:', error);
      return { success: false, error };
    }
  });

