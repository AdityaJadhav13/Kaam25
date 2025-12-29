#!/bin/bash

# Script to set up app icon from clipboard or file

echo "🎨 Kaam25 App Icon Setup"
echo "======================="
echo ""
echo "Please choose an option:"
echo "1. Paste from clipboard (if you have the image copied)"
echo "2. Provide file path to the image"
echo "3. Download from URL"
echo ""
read -p "Enter option (1-3): " option

case $option in
  1)
    echo "Saving from clipboard..."
    osascript -e 'tell application "System Events" to set the clipboard to (the clipboard as «class PNGf»)' -e 'set the clipboard to (the clipboard as «class PNGf»)' -e 'do shell script "pngpaste assets/app_icon.png"' 2>/dev/null
    if [ $? -eq 0 ]; then
      echo "✅ Image saved from clipboard"
    else
      echo "❌ Failed. Try: brew install pngpaste"
      echo "Or manually save the image as assets/app_icon.png"
      exit 1
    fi
    ;;
  2)
    read -p "Enter full path to image: " image_path
    if [ -f "$image_path" ]; then
      cp "$image_path" assets/app_icon.png
      echo "✅ Image copied successfully"
    else
      echo "❌ File not found: $image_path"
      exit 1
    fi
    ;;
  3)
    read -p "Enter image URL: " image_url
    curl -L "$image_url" -o assets/app_icon.png
    if [ $? -eq 0 ]; then
      echo "✅ Image downloaded successfully"
    else
      echo "❌ Download failed"
      exit 1
    fi
    ;;
  *)
    echo "Invalid option"
    exit 1
    ;;
esac

echo ""
echo "Generating app icons for all platforms..."
flutter pub run flutter_launcher_icons

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ SUCCESS! App icons generated for all platforms"
  echo ""
  echo "Icon sizes created:"
  echo "  📱 iOS: All required sizes"
  echo "  🤖 Android: All required sizes"
  echo "  🌐 Web: favicon"
  echo "  💻 macOS, Windows, Linux: App icons"
  echo ""
  echo "You can now run the app to see the new icon!"
else
  echo "❌ Failed to generate icons"
  exit 1
fi
