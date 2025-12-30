#!/bin/bash

# 🔥 Fix Google Sign-In by Adding SHA-1 to Firebase Console

echo "================================================"
echo "🔥 GOOGLE SIGN-IN FIX - ADD SHA-1 TO FIREBASE"
echo "================================================"
echo ""
echo "Your SHA-1 Fingerprint:"
echo "D3:18:45:08:EE:89:F8:3E:63:35:56:DE:D8:44:C6:D6:F5:A1:95:10"
echo ""
echo "📋 This has been copied to your clipboard!"
echo ""

# Copy SHA-1 to clipboard
echo "D3:18:45:08:EE:89:F8:3E:63:35:56:DE:D8:44:C6:D6:F5:A1:95:10" | pbcopy

echo "🌐 Opening Firebase Console..."
echo ""
sleep 2

# Open Firebase Console
open "https://console.firebase.google.com/project/chalmumbai/settings/general"

echo "================================================"
echo "📝 FOLLOW THESE STEPS:"
echo "================================================"
echo ""
echo "1. ✅ Firebase Console is now opening in your browser"
echo ""
echo "2. 🔍 Find your Android app: 'com.kaam25.kaam25'"
echo ""
echo "3. 📜 Scroll down to 'SHA certificate fingerprints' section"
echo ""
echo "4. ➕ Click 'Add fingerprint' button"
echo ""
echo "5. 📋 Paste the SHA-1 (already in your clipboard):"
echo "   D3:18:45:08:EE:89:F8:3E:63:35:56:DE:D8:44:C6:D6:F5:A1:95:10"
echo ""
echo "6. 💾 Click 'Save'"
echo ""
echo "7. ⏱️  Wait 5-10 minutes for Firebase to propagate changes"
echo ""
echo "8. 🔄 Hot reload your app (press 'r' in terminal)"
echo ""
echo "================================================"
echo "✅ DONE! Google Sign-In will work after adding SHA-1"
echo "================================================"
