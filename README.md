# AI Expense Tracker

Offline-first Flutter expense tracker for personal Android use. The app stores
expenses locally, listens for Indian bank/UPI SMS messages, proposes editable
expense entries, and exports monthly reports to Excel or PDF.

This is a personal sideload app. It is not designed for Play Store distribution
because background SMS access is restricted by Play policy.

## Requirements

- Flutter `3.44.0+`
- Dart `3.12.0+`
- Android SDK platform `36`
- Android SDK build tools `36.0.0`
- Android NDK `28.2.13676358`
- Samsung Galaxy S23 or another arm64 Android device

## Clone, Build, Sideload

```bash
git clone <repo-url>
cd ai-expense-tracker
fvm install 3.44.0
fvm use 3.44.0
android sdk install platforms/android-36 build-tools/36.0.0 platform-tools ndk/28.2.13676358
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter build apk --release --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

If `adb` is not available, copy
`build/app/outputs/flutter-apk/app-release.apk` to the Galaxy S23, enable
`Install unknown apps` for the file manager, install the APK, and grant SMS and
notification permissions when prompted.

## Model Download

The model is downloaded at runtime and is not committed to the repository.

- Filename: `gemma-4-E2B-it.litertlm`
- Expected size: `2_590_000_000` bytes
- Accepted tolerance: `+/-5_000_000` bytes
- URL: `https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm`

The app verifies the file size in a background isolate, downloads with Dio to a
`.part` file, shows percentage, speed, ETA, and supports cancellation.

## Privacy

All expense data, SMS previews, and model files remain on-device. The app does
not upload SMS content or expenses. Report export files are created locally and
shared only when you explicitly tap Share.

## Development Checks

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
flutter build apk --release --target-platform android-arm64
android run --apks=build/app/outputs/flutter-apk/app-release.apk
android layout -p
android screen capture -o tmp/s23-dashboard.png
```
