#!/bin/bash

# Script to get SHA-1 and SHA-256 fingerprints for Android app signing
# These are needed for Google Sign-In on Android

echo "🔐 Getting SHA-1 and SHA-256 Fingerprints for Android"
echo "======================================================"
echo ""

# Debug keystore (for development)
echo "📱 DEBUG Keystore (for development/testing):"
echo "--------------------------------------------"
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android 2>/dev/null | grep -E "SHA1:|SHA256:"

echo ""
echo ""

# Release keystore (if exists)
if [ -f "android/app/release.keystore" ]; then
    echo "🚀 RELEASE Keystore (for production):"
    echo "-------------------------------------"
    echo "Enter release keystore password when prompted:"
    keytool -list -v -keystore android/app/release.keystore -alias release
else
    echo "ℹ️  No release keystore found at android/app/release.keystore"
    echo "For production, you'll need to create a release keystore"
fi

echo ""
echo ""
echo "📋 Next Steps:"
echo "1. Copy the SHA-1 and SHA-256 fingerprints above"
echo "2. Go to Firebase Console: https://console.firebase.google.com/"
echo "3. Select your project: Kaam 25 (chalmumbai)"
echo "4. Go to Project Settings > Your apps > Android app"
echo "5. Add SHA certificate fingerprints"
echo "6. Download the updated google-services.json"
echo "7. Replace android/app/google-services.json with the new file"
echo "8. Run: flutter clean && flutter pub get"
echo "9. Test Google Sign-In on Android device/emulator"
echo ""
