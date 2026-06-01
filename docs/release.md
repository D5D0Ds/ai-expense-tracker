# Release

## Release Build

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter build apk --release --target-platform android-arm64
```

## Device Feedback Loop

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
android layout -p
android screen capture -o tmp/release-screen.png
```

Review the APK on the target Galaxy S23 before tagging a GitHub release.
