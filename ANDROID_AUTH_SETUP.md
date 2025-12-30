# 🔧 Fixing Google Sign-In on Android

## ⚠️ Current Issue

Google Sign-In is failing on Android with error code 7 (NETWORK_ERROR). This is because SHA-1 certificate fingerprint is not configured in Firebase Console.

## ✅ Quick Solution: Use Email/Password Authentication

**Email/password authentication works perfectly on Android!** This is the recommended method for development and testing.

### To Use Email/Password:
1. Enable Email/Password in Firebase Console (already done)
2. Create a test user in Firebase Console:
   - Email: `test@example.com`
   - Password: `test123456`
3. Sign in using the email/password fields on the login page

---

## 🔐 To Fix Google Sign-In on Android (Optional)

If you want to enable Google Sign-In on Android, follow these steps:

### Step 1: Get SHA-1 Certificate Fingerprint

Run this command in your terminal:

```bash
cd android
./gradlew signingReport
```

Look for the output under `Variant: debug` and `Task: signingReport`:
```
SHA1: AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD
```

Copy this SHA-1 fingerprint.

### Step 2: Add SHA-1 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **chalmumbai**
3. Click the gear icon → **Project Settings**
4. Scroll down to **Your apps** section
5. Find your Android app: `com.kaam25.kaam25`
6. Click **Add fingerprint** button
7. Paste your SHA-1 fingerprint
8. Click **Save**

### Step 3: Download Updated google-services.json

1. Still in Firebase Console → Project Settings
2. Click on your Android app
3. Click **Download google-services.json**
4. Replace the file at: `android/app/google-services.json`

### Step 4: Rebuild and Test

```bash
flutter clean
flutter run -d emulator-5554
```

---

## 📱 Testing on Real Android Device

If you're using a real Android device (not emulator):

1. Enable USB debugging on your device
2. Connect device to computer
3. Run: `flutter devices` to see your device
4. Run: `flutter run -d <device-id>`

Google Sign-In typically works better on real devices than emulators.

---

## 🎯 Recommended Approach

**For Development**: Use **Email/Password** authentication
- ✅ Works immediately on all platforms
- ✅ No additional configuration needed
- ✅ Faster testing cycle
- ✅ No SHA-1 certificate issues

**For Production**: Configure both methods
- Enable Google Sign-In for user convenience
- Keep Email/Password as fallback option

---

## 🐛 Common Errors

### Error: `network_error` or `ApiException: 7`
**Cause**: SHA-1 fingerprint not configured
**Solution**: Follow steps above to add SHA-1 to Firebase Console

### Error: `sign_in_canceled` or error code 12501
**Cause**: User cancelled the sign-in flow
**Solution**: This is normal behavior, try signing in again

### Error: `10` (Developer Error)
**Cause**: SHA-1 mismatch or wrong package name
**Solution**: Verify package name matches in Firebase Console and google-services.json

---

## ✅ Current Working Authentication Methods

1. **Email/Password** ✅ - Fully functional on Android
2. **Google Sign-In** ⚠️ - Requires SHA-1 configuration
3. **Device Approval** ✅ - Working
4. **User Approval** ✅ - Working

---

## 📝 Test Credentials

Once you create a test user in Firebase Console, use:
- **Email**: `test@example.com`
- **Password**: `test123456`

Make sure to:
1. Set `approved: true` in Firestore users collection
2. Set `blocked: false` in Firestore users collection
3. Approve the device after first login attempt

---

## 💡 Quick Test

Run the app and try email/password sign-in:

```bash
flutter run -d emulator-5554
```

Then on the login page:
1. Enter email: `test@example.com`
2. Enter password: `test123456`
3. Click **Sign In**
4. Check terminal logs for authentication flow
