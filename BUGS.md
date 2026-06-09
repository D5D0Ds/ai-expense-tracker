# Bugs

## Fixed: LiteRT-LM audio backend constraint blocked Gemma GPU load

- Date found: 2026-06-09
- Device: Samsung S23, SM-S911B
- Symptom: Settings showed `Backend: Not loaded` and `Failed to create engine: INVALID_ARGUMENT: Audio backend constraint mismatch. Model requires one of [cpu] but Audio backend is GPU`.
- Cause: `EngineConfig` forced the unused `audioBackend` to `Backend.GPU()`.
- Fix: Keep the text inference backend on `Backend.GPU()` and set only `audioBackend` to `Backend.CPU()` to satisfy the model constraint. No text CPU fallback was reintroduced.
- Verification: Rebuilt and reinstalled release APK on the S23. Settings now shows `Model ready for private parsing`, `Backend: GPU`, and init time `18867 ms`.

## Fixed: SMS sync date picker crashed before starting sync

- Date found: 2026-06-09
- Device: Samsung S23, SM-S911B
- Symptom: After choosing a date range and tapping Save, the SMS suggestions screen returned without showing progress or syncing.
- Evidence: Logcat showed `Unhandled Exception: Null check operator used on a null value` at `ScaffoldMessenger.of` in `sms_suggestions_screen.dart`.
- Cause: The screen looked up `ScaffoldMessenger` after the date-picker route was dismissed, using a context that no longer had a reliable scaffold messenger ancestor.
- Fix: Capture `ScaffoldMessenger.maybeOf(context)` before opening the date picker and use the stable messenger after sync.
- Verification: Unit tests pass. Real-device rerun showed the sync progress indicator and returned to the suggestions list after completion.

## Fixed: Inbox sync loading state was overwritten during long sync

- Date found: 2026-06-09
- Symptom: Sync progress could disappear while messages were still being parsed.
- Cause: `syncInbox` set provider state to loading, but each parsed SMS called `reload()`, replacing loading with the current pending list before the full inbox scan finished.
- Fix: `syncInbox` now parses/upserts without per-message reloads and refreshes pending suggestions only once at the end.
- Verification: Added unit coverage for inbox sync continuing after one parse failure. Real-device rerun kept the loading indicator visible during sync.

## Fixed: Weekly SMS sync could run too long on-device

- Date found: 2026-06-09
- Device: Samsung S23, SM-S911B
- Symptom: June 1-9 sync stayed in progress for minutes while Gemma parsed multiple inbox messages sequentially.
- Evidence: Android CLI screenshots showed progress correctly, but `meminfo` reached about 2.7 GB PSS during inference, mostly GL/GPU allocations.
- Cause: Manual inbox sync returned every likely financial SMS in the range and parsed them one-by-one with the full model.
- Fix: Native inbox query now caps a manual sync to the newest 12 likely financial messages.
- Verification: Bounded sync returned to the suggestions list instead of staying indefinitely in progress.

## Fixed: Over-aggressive token cap rejected real SMS prompts

- Date found: 2026-06-09
- Device: Samsung S23, SM-S911B
- Symptom: After reducing model context to 256, Gemma skipped all synced messages.
- Evidence: Logcat showed `Input token ids are too long. Exceeding the maximum number of tokens allowed: 393 >= 256` and similar values.
- Cause: `maxNumTokens` is a context budget, not just an output budget; the system prompt plus SMS body exceeded 256 tokens.
- Fix: Reduced the system prompt size and set `maxNumTokens` to 512.
- Verification: Release APK rebuilt and installed. Real-device logcat showed `max_tokens: 512` and no repeat of the 256-token input-length failure during the June 1-9 sync.

## Open: LiteRT sampler libraries are missing, reducing inference efficiency

- Date found: 2026-06-09
- Device: Samsung S23, SM-S911B
- Symptom: Gemma inference works on GPU, but sync still has high memory pressure and slower decode than expected.
- Evidence: Logcat showed `OpenCL sampler not available` and `WebGPU sampler not available`, then `GPU sampler unavailable. Falling back to CPU sampling.`
- Impact: This is not a text CPU backend fallback, but token sampling is not using the optimized GPU sampler path.
- Suggested fix: Package or configure the LiteRT-LM sampler shared libraries supported by the current Android/LiteRT build, then rerun decode throughput and battery tests.

## Open: Existing fallback-created SMS candidates can persist after fallback removal

- Date found: 2026-06-09
- Device: Samsung S23, SM-S911B
- Symptom: SMS suggestions contained an old candidate with reason `Gemma parse failed. Native fallback parser used.` after installing the GPU-only build.
- Cause: The candidate was created by an earlier APK and persisted in app storage across reinstall.
- Impact: It can confuse QA because the current build no longer creates that fallback reason.
- Suggested fix: Add a one-time migration or debug cleanup action to remove pending candidates whose `modelReason` contains legacy fallback text.
