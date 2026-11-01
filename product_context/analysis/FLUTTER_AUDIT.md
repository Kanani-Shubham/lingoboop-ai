# LingoBoom — Flutter Project Health & Configuration Audit

**Auditor:** Senior Flutter Engineer & Android Native Architect  
**Inspection Date:** November 2026  
**Project Name in Config:** `lingoboop` (to be updated to `lingoboom` in manifest/app metadata)  
**SDK Channel:** Stable

---

## 1. Environment & SDK Verification

| Component | Installed / Configured Version | Status | Notes |
|---|---|---|---|
| **Flutter SDK** | `3.47.7` | ✅ Healthy | Stable channel revision `abaf9c5237` |
| **Dart SDK** | `3.13.5` | ✅ Healthy | Supports Dart 3 patterns, records, sealed classes |
| **Android Gradle Plugin** | `9.1.0` | ✅ Modern | Configured in `android/settings.gradle.kts` |
| **Kotlin** | `2.4.0` | ✅ Modern | Latest Kotlin DSL support |
| **Java Target** | `JavaVersion.VERSION_17` | ✅ Standard | Matches modern Gradle & AGP requirements |

---

## 2. Dependencies & Package Health

### Current `pubspec.yaml`
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

### Missing Critical Dependencies for Production
The current codebase is a bare Flutter starter template. To satisfy production requirements across Phases 1–12, the following packages must be introduced systematically in later phases (do NOT install during Phase 0):

| Functional Area | Recommended Production Package | Justification |
|---|---|---|
| **State Management** | `flutter_riverpod: ^2.6.1` + `riverpod_annotation` | Compile-safe dependency injection, testability, reactive state |
| **Navigation** | `go_router: ^14.8.1` | Declarative routing, deep linking, onboarding redirect guards |
| **Backend & Auth** | `supabase_flutter: ^2.8.4` | Supabase auth, PostgreSQL client, realtime subscriptions |
| **Local Storage** | `drift: ^2.24.2` + `flutter_secure_storage: ^9.2.4` | Offline learning cache, encrypted token storage |
| **Networking & WebSocket**| `dio: ^5.8.0` + `web_socket_channel: ^3.0.2` | Robust REST API interceptors and low-latency audio streaming |
| **Audio Capture & Playback**| `record: ^5.2.0` + `audioplayers: ^6.1.1` | Low-latency PCM recording for Gnani Prisma STT, audio playback |
| **3D GLB Rendering** | `o3d: ^3.1.2` / `model_viewer_plus: ^1.7.1` | Native GLB rendering with full animation clip switching |
| **Typography & UI** | `google_fonts: ^6.2.1` | Official Fredoka font rendering matching HTML prototype |
| **Monitoring & Crash** | `sentry_flutter: ^8.14.2` + `posthog_flutter: ^4.3.0` | Production crash reporting and telemetry |

---

## 3. Android Platform Configuration (`android/`)

### 3.1. Identifiers & SDK Settings
- **Namespace:** `com.lingoboop.lingoboop` (in `android/app/build.gradle.kts`).
- **Application ID:** `com.lingoboop.lingoboop` (Needs transition plan to `com.lingoboom.app`).
- **Compile SDK:** Defaults to `flutter.compileSdkVersion` (typically API 35).
- **Min SDK:** Defaults to `flutter.minSdkVersion` (API 21). *Recommendation:* Explicitly set `minSdk = 26` (Android 8.0 Oreo) because `WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY` and Foreground Services with notification channels require API 26+.
- **Target SDK:** Defaults to `flutter.targetSdkVersion` (API 34/35).

### 3.2. Android Manifest Audit (`AndroidManifest.xml`)
The current manifest has **no special permissions**:
```xml
<!-- Current permissions: NONE -->
```

### Required Permissions to Add (Phase 4 & 6):
1. **Overlay Permission:**
   ```xml
   <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
   ```
2. **Foreground Service & Battery Optimization:**
   ```xml
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
   <uses-permission android:name="android.permission.WAKE_LOCK" />
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
   ```
3. **Audio & Network:**
   ```xml
   <uses-permission android:name="android.permission.RECORD_AUDIO" />
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
   ```

---

## 4. Platform Channel Architecture Audit

- **Current State:** `MainActivity.kt` is a blank subclass of `FlutterActivity`. No custom `MethodChannel` or `EventChannel` handlers exist.
- **Architectural Requirement:** A robust bridge is needed:
  - `com.lingoboom/overlay_channel`: Methods to `startOverlay()`, `stopOverlay()`, `updateCharacter(charId)`, `setCardVisibility(bool)`.
  - `com.lingoboom/overlay_events`: Stream of touch coordinates, drag events, and micro-interactions emitted from native Kotlin WindowManager to Flutter.

---

## 5. Test Coverage
- `test/widget_test.dart` passes basic counter tests, but currently has 0% coverage on domain logic or services.
- Test suites must be established in Phase 1 for StateNotifier, Repository interfaces, and Audio pipeline models.

