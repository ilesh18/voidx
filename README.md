# CycloneX

CycloneX is an intelligent cyclone monitoring and emergency rescue coordination platform.
It combines live cyclone monitoring, GPS-based rescue routing, live SOS dispatch, emergency
guidance (chatbot/RAG), and responder dashboards for disaster response.

Citizens use the Flutter Android app to report SOS emergencies, view live cyclone data, and
request rescue assistance. Responders use the Next.js dashboard to receive real-time SOS
alerts over WebSocket, accept incidents, and coordinate rescue units. The FastAPI/Python
backend orchestrates SOS coordination, cyclone data (DTN), WebSocket dispatch, and RAG-based
emergency guidance.

## Android Release — Download

| Item | Link |
| --- | --- |
| GitHub Repository | https://github.com/ilesh18/voidx |
| GitHub Releases | https://github.com/ilesh18/voidx/releases |
| Latest APK Download | https://github.com/ilesh18/voidx/releases/latest/download/app-release.apk |
| Latest AAB Download | https://github.com/ilesh18/voidx/releases/latest/download/app-release.aab |

> **Release status:** The `v1.0.0` release is prepared in this repository. The APK/AAB assets are
> attached to the GitHub Release once the release tag is pushed and the GitHub Actions workflow
> publishes it. The download links above become active after the first tagged release is published.
> Until then, build the APK locally (see "Android Release Build" below).

**Application ID:** `com.cyclonex.app`
**Version:** `1.0.0` (version code `1`)
**Minimum SDK:** Android 6.0 (API 23)
**Signed:** Yes (release keystore; keystore and passwords are never committed)

## Architecture

```mermaid
flowchart LR
    Citizens[Flutter Android app] -->|HTTPS REST + WSS| API[Emergency API (FastAPI)]
    Responders[Next.js responder dashboard] -->|HTTPS REST| API
    Citizens -->|GPS + offline SOS queue| Citizens
    Responders -->|WebSocket /ws/rescue| API
    Citizens -->|Push / in-app SOS alerts| Citizens
    API --> SOS[SOS creation & responder coordination]
    API --> GIS[Haversine rescue-team matching]
    API --> Weather[DTN cyclone monitoring]
    API --> RAG[Emergency RAG & FAISS guidance]
```

## Features

- Live cyclone monitoring from the DTN Tropical Cyclone API (real data, no mocks)
- GPS location retrieval with Android runtime permissions (`ACCESS_FINE_LOCATION`,
  `ACCESS_COARSE_LOCATION`)
- SOS emergency workflow: create, list, accept, and update rescue incident status
- Real rescue teams and nearby assistance requests from the backend
- SOS alerts received over the `/ws/rescue` rescue WebSocket (WSS in production)
- Emergency chatbot / RAG guidance connected to the actual backend
- Authentication support (if the backend provides it)
- Secure storage for authentication tokens (`shared_preferences`)
- Loading, API-failure, disconnection, and empty-response handling
- Android release signing (keystore and passwords kept out of Git)

## Technology stack

| Layer | Technology |
| --- | --- |
| Mobile | Flutter 3.24.5, Dart 3.5.4 |
| Mobile language | Dart |
| Backend API | FastAPI / Python |
| Realtime | WebSocket (`/ws/rescue`) |
| Cyclone data | DTN Tropical Cyclone API (OAuth 2.0) |
| Guidance / RAG | FAISS (`cyclone_faq.faiss`) + optional LLM |
| Responder dashboard | Next.js / React |
| Android build | Gradle, AGP, JDK 17, Android SDK 34 |

## Backend setup

The Flutter app connects to the deployed CycloneX FastAPI backend via `lib/config/app_config.dart`,
which reads `BACKEND_URL` from `apps/mobile/.env` (never committed).

Production requirements:
- `BACKEND_URL` must be an HTTPS URL (e.g. `https://api.cyclonex.example.com`).
- WebSocket uses `WSS` (derived from `BACKEND_URL`).
- No DTN credentials, API secrets, database passwords, or private keys are stored in Flutter code.

1. Copy the backend env template and fill in provider values:
   ```bash
   cd apps/flask
   cp .env.example .env
   ```
2. Set `DTN_CLIENT_ID` / `DTN_CLIENT_SECRET` for live cyclone data (cyclones show
   `UNCONFIGURED` until these are set).
3. Run the API:
   ```bash
   python fastapi_server.py
   ```
   The service listens on `http://localhost:8080` (dev) / your production host.
4. Verify health:
   ```bash
   curl https://<your-backend>/api/cyclones/health
   ```

## Flutter setup

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

Create `apps/mobile/.env` (gitignored — never commit) for development:
```dotenv
APP_ENV=development
BACKEND_URL=http://<development-machine-ip>:8080
```

## Android Release Build

Prerequisites: Flutter SDK 3.24.5, Android SDK (API 34), JDK 17.

```bash
cd apps/mobile
flutter pub get
flutter build apk --release
flutter build appbundle --release
```

Outputs:
- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

### Release signing

A release keystore (`cyclonex-release-key.jks`) and `android/app/key.properties` are used for
local signing. Both are gitignored and must NOT be committed.

To generate a new keystore:
```bash
keytool -genkeypair -v -keystore android/app/cyclonex-release-key.jks \
  -alias cyclonex -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=CycloneX, O=CycloneX, C=IN"
```
Then create `android/app/key.properties`:
```properties
storeFile=cyclonex-release-key.jks
storePassword=<your-store-password>
keyAlias=cyclonex
keyPassword=<your-key-password>
```

For CI signing, store the base64-encoded keystore and passwords as GitHub Actions secrets
(see `.github/workflows/android-release.yml`):
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `BACKEND_URL` (production HTTPS backend)

## Android installation

1. Download `app-release.apk` from the GitHub Releases link above.
2. On the device, enable "Install from unknown sources" for your browser/file manager.
3. Open the APK file and tap Install.
4. Grant location and notification permissions when prompted.
5. On first launch, ensure the device can reach the configured `BACKEND_URL`.

### Permissions
- `INTERNET`, `ACCESS_NETWORK_STATE` — API and WebSocket connectivity
- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` — GPS / cyclone proximity
- `POST_NOTIFICATIONS` — SOS alerts
- `SEND_SMS`, `RECEIVE_SMS`, `READ_SMS` — emergency SMS fallback
- `READ_CONTACTS` — emergency contacts

> WebSockets do not guarantee background delivery when Android suspends the app. For
> background SOS alerts, integrate Firebase Cloud Messaging (FCM) or an equivalent push
> service and test it separately.

## Build instructions (CI)

Push a release tag (e.g. `v1.0.0`) to trigger the GitHub Actions workflow
(`.github/workflows/android-release.yml`), which builds the signed release APK + AAB and
publishes them as release assets.

### Required GitHub Actions secrets
- `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `ANDROID_KEY_PASSWORD` — release signing
- `BACKEND_URL` — production HTTPS backend

Without signing secrets, the workflow builds an **unsigned testing APK only** (never
represented as a production release).

## Environment variables (backend — `apps/flask/.env`, never committed)

| Variable | Purpose |
| --- | --- |
| `BACKEND_URL` | Flutter REST/WebSocket base URL (HTTPS in production) |
| `DTN_CLIENT_ID` / `DTN_CLIENT_SECRET` | DTN Tropical Cyclone API OAuth credentials |
| `DTN_BASE_URL` | DTN API base (`https://tropical.api.dtn.com`) |
| `DTN_AUTH_URL` | DTN OAuth token endpoint |
| `WEATHERAPI_API_KEY` | Weather provider |
| `GEMINI_API_KEY` | AI guidance provider |
| `GOOGLE_MAPS_API_KEY` | Maps provider |
| `NOVU_API_KEY` / `TWILIO_ACCOUNT` | Notifications & alerts |

Never commit `.env` files or secrets. They are gitignored.

## Known limitations

- The production backend URL is not hard-coded; `BACKEND_URL` must be set before a production
  build. Until the backend is deployed, cyclone data reports `UNCONFIGURED`.
- SOS records and WebSocket connections are maintained in process memory; restarting the API
  clears active records and disconnects responders.
- WebSocket/SOS alerts are delivered only while the app is active; background delivery
  requires FCM (not yet integrated).
- DTN cyclone credentials are optional; live cyclone data is unavailable until configured.
- The APK built from this branch uses the development `BACKEND_URL` unless rebuilt with the
  production HTTPS backend URL.
