# Privacy

The app is local-first by design.

- SMS bodies are processed on the device.
- Confirmed expenses are stored in encrypted Hive boxes.
- Report files are generated in the app documents directory.
- The Gemma model is downloaded directly from Hugging Face to local storage.
- No analytics, telemetry, cloud sync, or external AI API is used.

The app stores SMS previews and hashes for deduplication. Users can ignore or
delete suggestions before they become expenses.
