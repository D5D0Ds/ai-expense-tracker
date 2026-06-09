# PLAN.md: AI Expense Tracker Flutter App

## Project Structure

```text
.
├── PLAN.md
├── README.md
├── LICENSE
├── analysis_options.yaml
├── pubspec.yaml
├── .fvmrc
├── android/
│   └── app/src/main/kotlin/io/github/openexpense/tracker/
│       ├── MainActivity.kt
│       ├── ai/GemmaBridgePlugin.kt
│       ├── ai/GemmaEngineHolder.kt
│       └── sms/{SmsReceiver.kt,SmsParseService.kt,SmsQueueStore.kt}
├── lib/
│   ├── main.dart
│   ├── bootstrap.dart
│   ├── app/{app.dart,router.dart}
│   ├── shared/{core,persistence,platform,theme,widgets}/
│   └── features/{dashboard,expenses,sms_suggestions,model_asset,reports,settings}/
├── test/{unit,widget,golden}/
├── integration_test/app_journey_test.dart
├── assets/app_icon/
└── docs/{architecture.md,privacy.md,release.md}
```

## `pubspec.yaml`

```yaml
name: ai_expense_tracker
description: Offline-first Android expense tracker with on-device Gemma SMS parsing.
publish_to: none
version: 1.0.0+1

environment:
  sdk: ">=3.12.0 <4.0.0"
  flutter: ">=3.44.0"

dependencies:
  flutter: { sdk: flutter }
  flutter_riverpod: 3.3.1
  riverpod_annotation: 4.0.2
  go_router: 17.2.3
  shadcn_ui: 0.54.0
  google_fonts: 8.1.0
  flutter_animate: 4.5.2
  dio: 5.9.2
  hive_ce: 2.19.3
  hive_ce_flutter: 2.3.4
  flutter_secure_storage: 10.3.1
  path_provider: 2.1.5
  permission_handler: 12.0.3
  android_intent_plus: 6.0.0
  device_info_plus: 13.1.0
  connectivity_plus: 7.1.1
  package_info_plus: 10.1.0
  graphic: 2.7.0
  excel: 4.0.6
  pdf: 3.12.0
  share_plus: 13.1.0
  intl: 0.20.2
  uuid: 4.5.3
  collection: 1.19.1
  crypto: 3.0.7
  freezed_annotation: 3.1.0
  json_annotation: 4.12.0

dev_dependencies:
  flutter_test: { sdk: flutter }
  integration_test: { sdk: flutter }
  build_runner: 2.15.0
  riverpod_generator: 4.0.3
  riverpod_lint: 3.1.3
  custom_lint: 0.8.1
  freezed: 3.2.5
  json_serializable: 6.14.0
  hive_ce_generator: 1.11.2
  go_router_builder: 4.3.0
  mocktail: 1.0.5
  golden_toolkit: 0.15.0
  very_good_analysis: 10.2.0
  flutter_launcher_icons: 0.14.4
  flutter_native_splash: 2.4.8
```

Android native versions: Flutter `3.44.0`, Dart `3.12.0`, AGP `9.2.1`, Gradle `9.5.1`, Kotlin `2.3.21`, compile/target SDK `36`, build tools `36.0.0`, NDK `28.2.13676358`, LiteRT-LM `com.google.ai.edge.litertlm:litertlm-android:0.12.0`, WorkManager `2.11.2`, coroutines Android `1.11.0`, arm64-v8a only.

## README.md Plan

Include clone/build/sideload commands:

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

Document sideload fallback: copy the APK to the Samsung Galaxy S23, enable “Install unknown apps”, install, then grant SMS and notification permissions. State this is a personal sideload app, not Play Store SMS-policy compliant.

## Key Implementation

- Architecture: feature-first MVVM with Riverpod 3 `@riverpod` notifiers, repositories as single source of truth, typed `Result` failures, thin views, no cross-feature implementation imports.
- UI: first screen is the usable dashboard, not a landing page. Use `ShadApp`, custom dark Shad theme, Inter Tight/Inter via `google_fonts`, Lucide icons, 8px liquid glass surfaces, accessible contrast, no decorative blobs, no feature-explainer copy inside the app.
- Model asset: hard-code `gemma-4-E2B-it.litertlm`, expected size `2_590_000_000`, tolerance `±5_000_000`, public URL `https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm`. Verify file size in `Isolate.run`; download with Dio to `.part`, show full-screen percentage/speed/ETA/cancel, then atomically rename and persist status in Hive.
- LiteRT-LM: use native Kotlin LiteRT-LM bridge so Dart keeps the downloaded file path without duplicating the 2.59 GB model. Load engine on background coroutine, prefer GPU on S23, fall back to CPU, serialize inference with a mutex.
- SMS flow: native `BroadcastReceiver` captures Indian bank/UPI SMS, queues minimal encrypted payload, starts foreground parse service, runs headless Flutter entrypoint, uses Gemma to return strict JSON `{amount,currency,date,payee,category,confidence,reason,isPersonLike}`. Only `CONFIRM` creates an `Expense`.
- Reports: Graphic charts for monthly trend/category/merchant views; Excel via `excel`, PDF via `pdf`, share files with `share_plus`; dashboard banner appears near month end or when unexported confirmed expenses exist.

## Core Types

- `Expense`: id, amount, currency INR, occurredAt, payee, category, source, accountHint, rawSmsHash, confidence, reason, notes, createdAt, updatedAt.
- `SmsCandidate`: id, sender, receivedAt, bodyHash, redactedPreview, status pending/confirmed/ignored/edited, proposedExpense, modelReason.
- `ModelAssetState`: absent/checking/downloading/ready/failed/cancelled with bytes, speed, ETA, path.
- Repositories: `ExpenseRepository`, `SmsCandidateRepository`, `ModelAssetRepository`, `ReportRepository`.
- Services: `ModelDownloadService`, `GemmaExpenseParser`, `NativeSmsBridge`, `ReportExportService`, `ShareService`.

## Test Plan

- Unit: model size tolerance, Dio progress/cancel, parser JSON validation, person-name heuristic, category mapping, Hive repositories, report totals/export files.
- Widget/golden: dashboard empty/loaded, model progress, SMS suggestion confirm/ignore/edit, expense search/filter, details, settings, S23 viewport snapshots.
- Integration: fake native SMS injection, permission states, full suggestion flow, export/share path creation, release APK build.
- Commands: `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `dart run custom_lint`, `flutter test --coverage`, `flutter build apk --release --target-platform android-arm64`, then Android CLI `android run`, `android layout -p`, and `android screen capture` for device feedback.

## Assumptions

- User chose the public Hugging Face mirror because the originally requested `abhishekgoogle` URL returned `401` on June 1, 2026.
- User chose native Android SMS receiver.
- Code license defaults to MIT; model is downloaded at runtime and README links to the model license.
- No cloud sync, no telemetry, no external AI API.
- Follow loaded applicable skills with zero deviation: Flutter, Dart/Flutter patterns, Flutter architecture, Flutter test, Flutter chart, Flutter errors, Android CLI, frontend-design, design-taste-frontend, shadcn-ui-flutter, and imagegen only if creating bitmap app-icon assets.
- Sources verified: Flutter 3.44 docs, Android AGP docs, Gradle current release, Google LiteRT-LM Android docs, pub.dev package metadata, and Hugging Face model headers.
