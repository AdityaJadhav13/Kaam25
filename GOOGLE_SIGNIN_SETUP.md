# 🔐 Google Sign-In Setup for Android

## ✅ Your SHA-1 Certificate Fingerprint

```
SHA1: D3:18:45:08:EE:89:F8:3E:63:35:56:DE:D8:44:C6:D6:F5:A1:95:10
SHA256: 1B:26:C5:F3:0B:7D:69:B5:45:FE:68:A5:37:91:6B:A3:01:87:7A:21:FA:C5:45:3A:10:7F:C9:F6:6C:2B:60:6B
```

## 🚀 Steps to Enable Google Sign-In

### Step 1: Add SHA-1 to Firebase Console

1. **Go to Firebase Console**: https://console.firebase.google.com/
2. **Select your project**: `chalmumbai`
3. **Click the gear icon** (⚙️) → **Project Settings**
4. **Scroll down** to "Your apps" section
5. **Find your Android app**: `com.kaam25.kaam25`
6. **Click "Add fingerprint"** button
7. **Paste this SHA-1**:
   ```
   D3:18:45:08:EE:89:F8:3E:63:35:56:DE:D8:44:C6:D6:F5:A1:95:10
   ```
8. **Click "Save"**
9. **Add SHA-256** (optional but recommended):
   ```
   1B:26:C5:F3:0B:7D:69:B5:45:FE:68:A5:37:91:6B:A3:01:87:7A:21:FA:C5:45:3A:10:7F:C9:F6:6C:2B:60:6B
   ```

### Step 2: Download Updated google-services.json

1. Still in **Project Settings** → **Your apps**
2. Click on your Android app
3. **Click "google-services.json"** to download
4. **Replace** the file at:
   ```
   android/app/google-services.json
   ```

### Step 3: Clean and Rebuild

```bash
cd "/Users/adityajadhav/Engineering/Development /My Projects/Kaam 25/kaam25_app"
flutter clean
flutter pub get
flutter run -d emulator-5554
```

### Step 4: Test Google Sign-In

1. App will launch on Android emulator
2. Click **"Sign in with Google"** button
3. Select your Google account
4. Should successfully authenticate! ✅

---

## 🔍 Verification Checklist

Before testing, make sure:

- [x] SHA-1 fingerprint obtained: `D3:18:45:08:EE:89:F8:3E:63:35:56:DE:D8:44:C6:D6:F5:A1:95:10`
- [ ] SHA-1 added to Firebase Console
- [ ] google-services.json downloaded (if updated)
- [ ] App cleaned and rebuilt
- [ ] Android emulator running
- [ ] Internet connection working

---

## ❌ Common Issues

### Issue: Still getting error code 7 after adding SHA-1
**Solution**: 
- Make sure you downloaded the NEW google-services.json after adding SHA-1
- Replace the file in `android/app/google-services.json`
- Run `flutter clean` and rebuild

### Issue: "Developer Error" or error code 10
**Solution**:
- Verify package name matches: `com.kaam25.kaam25`
- Check SHA-1 is correctly copied (no extra spaces)
- Wait 5-10 minutes for Firebase to update

### Issue: Works on emulator but not on real device
**Solution**:
- Get SHA-1 for your release keystore
- Add that SHA-1 to Firebase as well
- For debug builds on real devices, the debug SHA-1 should work

---

## 📱 For Production Release

When building for production, you'll need to:

1. Generate a release keystore:
   ```bash
   keytool -genkey -v -keystore release.keystore -alias release -keyalg RSA -keysize 2048 -validity 10000
   ```

2. Get release SHA-1:
   ```bash
   keytool -list -v -alias release -keystore release.keystore
   ```

3. Add release SHA-1 to Firebase Console

---

## 🎯 Quick Command Reference

### Get SHA-1 from debug keystore:
```bash
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android | grep SHA
```

### Clean and rebuild:
```bash
flutter clean && flutter pub get && flutter run
```

### Check Google Sign-In logs:
Look for these in terminal:
```
🔐 Attempting Google sign-in...
✅ Google sign-in successful
```

---

## ✅ Expected Result

After completing the steps above, Google Sign-In will work and you'll see:

1. Google account picker appears
2. User selects account
3. App authenticates successfully
4. User proceeds to approval flow (if new user)

**No more error code 7!** 🎉
