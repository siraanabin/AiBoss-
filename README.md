# AiBoss

AiBoss is a Flutter Android AI assistant with a provider adapter layer, persistent local chat history, rolling conversation memory, and an extensible plugin registry.

## Current MVP
- Gemini and OpenAI-compatible provider adapters
- API credentials stored in Android secure storage (never committed)
- Persistent chat history and rolling local memory
- Local Notes plugin (`/note your text`, `/notes`)
- Plugin Center and provider settings
- GitHub Actions release APK build

## Build locally
Install Flutter stable and Android SDK, then run:

```bash
flutter create --platforms=android --org com.aiboss --project-name aiboss .
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The generated APK is at `build/app/outputs/flutter-apk/app-release.apk`.

## CI
Every push to `main` and manual workflow dispatch runs analysis, tests, and a release APK build. The APK is uploaded as a workflow artifact.

## API keys
Add provider credentials inside the app's Settings screen. Do not place API keys in source code, GitHub commits, or public workflow files. For a public production release, route provider requests through a secured backend to avoid exposing shared credentials.
