# AiBoss

AiBoss is a Flutter Android multi-provider AI assistant with automatic fallback, secure local API-key storage, persistent chat history, rolling conversation memory, and an extensible plugin registry.

## Multi-AI providers
The Settings screen supports these provider connections:
- Google Gemini (Gemini API)
- OpenAI
- DeepSeek
- Groq
- OpenRouter

Enable the providers you have API keys for. AiBoss tries enabled providers in the displayed order and moves to the next provider when a request fails (including temporary availability or rate-limit errors). Model IDs can be edited in Settings.

The OpenAI, DeepSeek, Groq, and OpenRouter adapters use OpenAI-compatible Chat Completions endpoints. Providers may change model IDs, endpoint behavior, quotas, or pricing; check each provider's current documentation.

## Important usage and security notes
- There is no unlimited-token or unlimited-free-usage setting. Each provider has its own rate limits, token quotas, and billing rules. Fallback can use another provider only when you have separately configured a valid key and available quota there.
- API keys are stored in Android secure storage on the device. Never commit keys to GitHub or share them in chat.
- For a public production release, route provider requests through a secured backend to avoid exposing shared credentials in a distributed APK.

## Current MVP
- Gemini and OpenAI-compatible provider adapters with automatic fallback
- Multiple provider profiles and per-provider API keys
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
