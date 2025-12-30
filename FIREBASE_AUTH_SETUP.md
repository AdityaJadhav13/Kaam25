# Firebase Authentication Setup Guide

## ✅ Email/Password Authentication Setup

### Step 1: Enable Email/Password Auth in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **chalmumbai**
3. Click on **Authentication** in the left sidebar
4. Click on the **Sign-in method** tab
5. Find **Email/Password** in the list
6. Click on it and **Enable** the provider
7. Click **Save**

### Step 2: Verify Configuration

Your current Firebase configuration is correctly set up:
- Project ID: `chalmumbai`
- Android App ID: `1:388870218082:android:b0f8f0f7bd904109db4c3b`
- iOS App ID: `1:388870218082:ios:16bbb8e17a94c2dadb4c3b`
- macOS App ID: Should be configured in Firebase Console

### Step 3: Test Authentication

#### For Email/Password Sign-In:
```dart
// In lib/features/auth/data/auth_repository.dart
Future<UserCredential> signInWithEmailPassword({
  required String email,
  required String password,
}) {
  return _auth.signInWithEmailAndPassword(email: email, password: password);
}
```

#### Common Email/Password Auth Errors:

1. **`user-not-found`**: No user with this email exists
   - Solution: User needs to be created first (contact admin)

2. **`wrong-password`**: Incorrect password
   - Solution: Check password and try again

3. **`invalid-email`**: Email format is invalid
   - Solution: Enter a valid email address

4. **`user-disabled`**: User account has been disabled
   - Solution: Contact admin to enable account

5. **`too-many-requests`**: Too many failed login attempts
   - Solution: Wait a few minutes and try again

6. **`operation-not-allowed`**: Email/Password auth not enabled
   - Solution: Enable in Firebase Console (see Step 1)

### Step 4: Create Test Users

#### Option A: Firebase Console
1. Go to Authentication > Users tab
2. Click "Add user"
3. Enter email and password
4. Click "Add user"

#### Option B: Firestore Bootstrap (Current App Flow)
1. User signs in with Google
2. Admin approves user in Admin Panel
3. User can then use email/password auth with the same email

### Step 5: Verify Firestore Rules

Your Firestore rules should allow user document reads:
```
match /users/{uid} {
  allow read: if isSelf(uid) || isAdmin();
  allow update: if isAdmin() || (isSelf(uid) && onlyUpdatingAllowedFields());
}
```

### Current Implementation Status ✅

- ✅ Firebase Auth SDK installed (`firebase_auth: ^5.3.3`)
- ✅ `AuthRepository` has `signInWithEmailPassword()` method
- ✅ `AuthController` has `loginWithEmailPassword()` method
- ✅ Login page has email/password fields
- ✅ Error handling with user-friendly messages
- ✅ Loading states during authentication

### Testing Checklist

- [ ] Email/Password provider enabled in Firebase Console
- [ ] Test user created in Firebase Authentication
- [ ] User document exists in Firestore `users` collection
- [ ] User is `approved: true` and `blocked: false`
- [ ] Device is approved for the user
- [ ] Try signing in with correct credentials
- [ ] Verify error messages for wrong password
- [ ] Verify error messages for invalid email

### Debugging Tips

1. **Check Firebase Console Logs**
   - Go to Firebase Console > Authentication
   - Check for failed sign-in attempts

2. **Check App Logs**
   - Look for debug prints starting with `🔄` or `❌`
   - Check for `FirebaseAuthException` errors

3. **Verify Firebase Initialization**
   ```dart
   // Should see this in main.dart
   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```

4. **Test with Firebase Auth Emulator (Optional)**
   ```bash
   firebase emulators:start --only auth
   ```

### Additional Security Features

The app includes additional security checks:
1. **User Approval**: Admin must approve new users
2. **Device Approval**: Admin must approve new devices
3. **Screenshot Protection**: Prevents screenshots of sensitive data
4. **Presence Tracking**: Monitors online/offline status
