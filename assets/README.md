# App Icon Setup

## Instructions

Please save the team image (the one with stick figures) as `app_icon.png` in this directory.

The image should be:
- Named exactly: `app_icon.png`
- Format: PNG
- Recommended size: 1024x1024px or larger
- The image will be automatically resized for all platforms

## After adding the image

Run this command to generate all platform-specific icons:

```bash
flutter pub run flutter_launcher_icons
```

This will automatically create icons for:
- iOS (all required sizes)
- Android (all required sizes)
- Web
- macOS
- Windows
- Linux
