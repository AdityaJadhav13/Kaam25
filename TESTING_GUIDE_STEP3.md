# Step 3 Testing Guide

## Quick Test Instructions

### 1. Email/Password Authentication

**Test Credentials** (if you have any in Firebase):
```
Email: [your-test-email]
Password: [your-test-password]
```

**To create a test user in Firebase Console:**
1. Go to Firebase Console → Authentication → Users
2. Click "Add user"
3. Enter email: `test@example.com`
4. Enter password: `Test123456`
5. Click "Add user"

**Testing Steps:**
1. Launch the app
2. Go through onboarding (if first time)
3. On login screen, tap "Email/Password" login
4. Enter email and password
5. Tap "Sign In"

**Expected Results:**
✅ Loading indicator appears
✅ On success: Redirect to /app (home screen)
✅ On error: Shows user-friendly error message
✅ Debug logs show: `🔐 Attempting email/password sign-in` and `✅ Email/password sign-in successful`

### 2. Google Sign-In Authentication

**Testing Steps:**
1. Launch the app
2. On login screen, tap "Google Sign-In" button
3. Select a Google account from picker
4. Authorize the app

**Expected Results:**
✅ Google account picker appears
✅ On success: Redirect to /app (home screen)
✅ On cancel: Shows "Sign-in was cancelled"
✅ Debug logs show: `🔐 Attempting Google sign-in` and `✅ Google sign-in successful`

**Note:** Google Sign-In on Android requires SHA-1 fingerprint to be configured in Firebase Console. If not configured, you'll see a network error. Use email/password for testing in this case.

### 3. Sign Out

**Testing Steps:**
1. After successful login, navigate to Profile page
2. Tap "Sign Out" button (currently profile is disabled, so use logout from code or wait for Step 4)

**Expected Results:**
✅ User is signed out
✅ Secure storage is cleared
✅ Redirected to login screen
✅ Debug logs show: `✅ Logged out successfully`

## Debug Logs to Watch For

### Successful Email Login:
```
🔐 Attempting email/password sign-in for: test@example.com
✅ Email/password sign-in successful
🔐 User signed in: test@example.com
```

### Successful Google Login:
```
🔐 Attempting Google sign-in...
✅ Google sign-in successful
🔐 User signed in: user@gmail.com
```

### Sign Out:
```
✅ Logged out successfully
🔓 User signed out
```

### Common Errors:
```
❌ Auth error: wrong-password - Incorrect password.
❌ Auth error: user-not-found - No account found with this email.
❌ Auth error: invalid-email - Invalid email address.
```

## Verification Checklist

- [ ] App compiles without errors
- [ ] App launches successfully
- [ ] Login screen displays
- [ ] Email/password login works
- [ ] Google Sign-In works (if SHA-1 configured)
- [ ] Error messages are user-friendly
- [ ] Sign out works
- [ ] No crashes occur
- [ ] Auth state persists (stays logged in on app restart)

## Known Limitations (Will be fixed in Step 4)

- No user approval workflow
- No admin panel access
- No device tracking
- Profile page shows "temporarily unavailable"
- Some features may be limited without Firestore user document

## Troubleshooting

**Google Sign-In shows network error:**
- Solution: Configure SHA-1 fingerprint in Firebase Console
- Alternative: Use email/password for testing

**Email login fails:**
- Check user exists in Firebase Authentication
- Verify email/password is correct
- Check Firebase Console for error details

**App crashes:**
- Check debug logs for error messages
- Verify all dependencies are installed: `flutter pub get`
- Try clean build: `flutter clean && flutter pub get`
