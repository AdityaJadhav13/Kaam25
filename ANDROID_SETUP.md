# 🤖 Android Setup Guide for Kaam25

## ✅ Issues Fixed

### 1. **Authentication Permission Issue** ✅
- **Problem**: Users couldn't update `lastLogin` field
- **Fix**: Updated Firestore rules to allow users to update their own `lastLogin`
- **Status**: ✅ Deployed

### 2. **Android Permissions** ✅
- Added `INTERNET` permission
- Added `READ_EXTERNAL_STORAGE` permission
- Added `WRITE_EXTERNAL_STORAGE` permission
- **Status**: ✅ Added to AndroidManifest.xml

### 3. **Firebase Storage Rules** ✅
- Created storage security rules
- Only approved users can upload/download files
- Max file size: 50 MB
- **Status**: ✅ Deployed

### 4. **Android Build Configuration** ✅
- Set `minSdk = 21` (required for Firebase)
- Added `multiDexEnabled = true`
- Added multidex dependency
- **Status**: ✅ Updated build.gradle.kts

---

## 🔐 Google Sign-In Setup for Android

### **SHA-1 Fingerprints**

**DEBUG (Development):**
```
SHA1: D3:18:45:08:EE:89:F8:3E:63:35:56:DE:D8:44:C6:D6:F5:A1:95:10
SHA256: 1B:26:C5:F3:0B:7D:69:B5:45:FE:68:A5:37:91:6B:A3:01:87:7A:21:FA:C5:45:3A:10:7F:C9:F6:6C:2B:60:6B
```

### **Steps to Complete Android Setup:**

1. **Go to Firebase Console**
   - URL: https://console.firebase.google.com/
   - Select project: "Kaam 25" (chalmumbai)

2. **Add SHA Fingerprints**
   - Go to Project Settings (gear icon)
   - Scroll to "Your apps" section
   - Find the Android app (com.kaam25.kaam25)
   - Click "Add fingerprint"
   - Add the SHA-1 from above: `D3:18:45:08:EE:89:F8:3E:63:35:56:DE:D8:44:C6:D6:F5:A1:95:10`
   - Add the SHA-256 as well
   - Click "Save"

3. **Download Updated google-services.json**
   - After adding SHA fingerprints
   - Download the new `google-services.json` file
   - Replace `android/app/google-services.json` with the new file

4. **Clean and Rebuild**
   ```bash
   flutter clean
   flutter pub get
   cd android && ./gradlew clean && cd ..
   ```

5. **Test on Android**
   ```bash
   # For emulator
   flutter run
   
   # For physical device
   flutter run --release
   ```

---

## 🧪 Testing Checklist

### Authentication
- [ ] Email/Password sign-in works
- [ ] Google Sign-In works on Android
- [ ] User can see their profile
- [ ] Device approval flow works
- [ ] Admin panel accessible (for admin users)

### Home Page - Notes & Documents
- [ ] Can create folders
- [ ] Can rename folders
- [ ] Can change folder icons
- [ ] Can delete folders
- [ ] Can upload documents (PDF, DOCX, XLS, PPT, images)
- [ ] Can view documents list
- [ ] Can delete documents (owner only)
- [ ] Search works for folders
- [ ] Search works for documents
- [ ] Real-time sync works (test with 2 devices)
- [ ] Data persists after app restart

---

## 🔧 Troubleshooting

### If Google Sign-In Still Doesn't Work on Android:

1. **Verify SHA-1 in Firebase**
   - Make sure the SHA-1 is added to Firebase Console
   - Make sure you downloaded the NEW google-services.json

2. **Check google-services.json**
   ```bash
   cat android/app/google-services.json | grep client_id
   ```
   Should show multiple client IDs including web client

3. **Rebuild from scratch**
   ```bash
   flutter clean
   rm -rf android/app/build
   rm -rf build
   flutter pub get
   flutter run
   ```

4. **Check Firebase Console > Authentication**
   - Make sure Google Sign-In is enabled
   - Check that Web Client ID is configured

### If File Upload Doesn't Work:

1. **Check Permissions**
   - Android 11+ requires runtime permissions
   - App should request storage permissions automatically

2. **Check Firebase Storage Rules**
   - Rules deployed: ✅
   - Should allow approved users to upload

3. **Check File Size**
   - Max 50 MB per file
   - Supported types: PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, JPG, PNG, TXT, CSV

---

## 📱 Release Build (Future)

When ready for production:

1. **Create Release Keystore**
   ```bash
   keytool -genkey -v -keystore android/app/release.keystore -alias release -keyalg RSA -keysize 2048 -validity 10000
   ```

2. **Get Release SHA-1**
   ```bash
   ./android_setup_sha.sh
   ```

3. **Add Release SHA-1 to Firebase**
   - Same process as debug, but with release SHA-1

4. **Configure Signing in build.gradle.kts**
   - Add release signing configuration

---

## ✅ Current Status

- ✅ Firestore rules fixed and deployed
- ✅ Firebase Storage rules created and deployed
- ✅ Android permissions added
- ✅ Build configuration updated
- ✅ SHA-1 fingerprints identified
- ⏳ **NEXT**: Add SHA-1 to Firebase Console and test on Android

---

## 🚀 Ready to Test!

After adding SHA-1 to Firebase Console:

```bash
# Hot restart the app to pick up new rules
# In Flutter running terminal, press 'R' (capital R)

# OR rebuild completely
flutter clean && flutter run
```

The app should now work perfectly on Android! 🎉
