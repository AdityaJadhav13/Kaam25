# 🔥 GOOGLE SIGN-IN FIX FOR ANDROID - IMMEDIATE ACTION REQUIRED

## ⚠️ THE PROBLEM

Google Sign-In is failing on Android because the SHA-1 certificate fingerprint needs to be added to Firebase Console.

## ✅ YOUR SHA-1 FINGERPRINT

```
SHA-1: D3:18:45:08:EE:89:F8:3E:63:35:56:DE:D8:44:C6:D6:F5:A1:95:10
```

---

## 🚀 FIX IT NOW - 3 MINUTES

### STEP 1: Go to Firebase Console
**URL:** https://console.firebase.google.com/project/chalmumbai/settings/general

### STEP 2: Add SHA-1 Fingerprint

1. You should see your Android app: `com.kaam25.kaam25`
2. Scroll down to find the "SHA certificate fingerprints" section
3. Click **"Add fingerprint"** button
4. Paste this EXACTLY:
   ```
   D3:18:45:08:EE:89:F8:3E:63:35:56:DE:D8:44:C6:D6:F5:A1:95:10
   ```
5. Click **"Save"**

### STEP 3: Download Updated google-services.json (OPTIONAL)

The google-services.json already has the SHA-1, but to be safe:
1. Click on your Android app in Firebase Console
2. Click the **google-services.json** download button
3. Replace the file at: `android/app/google-services.json`

### STEP 4: Clean & Rebuild

```bash
cd "/Users/adityajadhav/Engineering/Development /My Projects/Kaam 25/kaam25_app"
flutter clean
flutter run -d emulator-5554
```

---

## 🎯 ALTERNATIVE: USE EMAIL/PASSWORD (WORKS NOW!)

If you need immediate access, **Email/Password authentication works perfectly** on Android:

1. Create test user in Firebase Console:
   - Email: `test@example.com`
   - Password: `test123456`

2. Set in Firestore users collection:
   - `approved: true`
   - `blocked: false`

3. Sign in using email/password on the app ✅

---

## 🔍 HOW TO VERIFY IT'S FIXED

After adding SHA-1 and rebuilding:

1. Open the app on Android
2. Click "Sign in with Google"
3. Check terminal logs:

**SUCCESS:**
```
🔐 Attempting Google sign-in...
✅ Google sign-in successful
```

**STILL FAILING:**
```
❌ Unexpected error during Google sign-in: ApiException: 7
```

If still failing after adding SHA-1:
- Wait 5-10 minutes for Firebase to propagate changes
- Make sure you clicked "Save" in Firebase Console
- Try `flutter clean` and rebuild
- Check you copied SHA-1 correctly (no extra spaces)

---

## 📞 QUICK REFERENCE

**Firebase Console:** https://console.firebase.google.com/project/chalmumbai/settings/general

**Your SHA-1:** `D3:18:45:08:EE:89:F8:3E:63:35:56:DE:D8:44:C6:D6:F5:A1:95:10`

**Package Name:** `com.kaam25.kaam25`

**App Location:** `/Users/adityajadhav/Engineering/Development /My Projects/Kaam 25/kaam25_app`

---

## ✅ DONE!

Once SHA-1 is added to Firebase Console, Google Sign-In will work on Android! 🎉
