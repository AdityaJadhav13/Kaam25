#!/bin/bash

# Physical Device Build and Deploy Script
# This script builds and deploys the Kaam25 app to a connected physical Android device

echo "🚀 Kaam25 - Physical Device Deployment"
echo "========================================"
echo ""

# Set the project directory
PROJECT_DIR="/Users/adityajadhav/Engineering/Development /My Projects/Kaam 25/kaam25_app"
cd "$PROJECT_DIR" || exit 1

# Step 1: Check if device is connected
echo "📱 Step 1: Checking connected devices..."
flutter devices
echo ""

# Ask user to confirm device
read -p "Is your physical device listed above? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Please connect your physical device and enable USB debugging"
    echo ""
    echo "To enable USB debugging:"
    echo "1. Go to Settings → About Phone"
    echo "2. Tap 'Build Number' 7 times to enable Developer Options"
    echo "3. Go to Settings → Developer Options"
    echo "4. Enable 'USB Debugging'"
    echo "5. Connect device via USB and authorize the computer"
    exit 1
fi

# Step 2: Clean build
echo ""
echo "🧹 Step 2: Cleaning previous build..."
flutter clean
echo "✅ Clean complete"
echo ""

# Step 3: Get dependencies
echo "📦 Step 3: Getting Flutter dependencies..."
flutter pub get
echo "✅ Dependencies updated"
echo ""

# Step 4: Build and run on device
echo "🔨 Step 4: Building and deploying to physical device..."
echo "This may take a few minutes..."
echo ""

flutter run --release

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🧪 Testing Checklist:"
echo "  □ Test Google Sign-In"
echo "  □ Test Email/Password sign-in"
echo "  □ Verify user profile loads"
echo "  □ Check internet connectivity"
echo "  □ Test device approval flow"
echo ""
echo "📝 If you encounter issues:"
echo "  1. Check PHYSICAL_DEVICE_AUTH_FIX.md for troubleshooting"
echo "  2. Verify internet connection on device"
echo "  3. Ensure device is approved in admin panel (if applicable)"
echo ""
