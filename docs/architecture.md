# Architecture

The app uses feature-first MVVM with Riverpod as dependency injection and state
management. Views are declarative and thin, controllers own UI state and
commands, repositories own persistence, and platform services isolate Android
method-channel work.

## Boundaries

- `shared/core`: immutable domain models, typed results, date and money helpers.
- `shared/persistence`: Hive setup and encrypted local boxes.
- `shared/platform`: method-channel facades for Gemma and native SMS.
- `features/*`: feature-local repositories, controllers, screens, and optional
  `*_api.dart` files for stable cross-feature operations.

Features may depend on `shared/*`. They must not import another feature's
implementation files unless the dependency is a stable public API or domain
type. Cross-feature writes should go through small interfaces, not concrete
repositories or controllers.

## Data Flow

SMS arrives in `SmsReceiver`, is queued by `SmsQueueStore`, then drained by the
Flutter app through `NativeSmsBridge`. `GemmaExpenseParser` asks the native
Gemma bridge for JSON and validates it before creating a pending
`SmsCandidate`. Only user confirmation creates an `Expense`.
