# LingoBoom — Complete Production Restoration Audit (`UI_RESTORATION_AUDIT.md`)

**Date:** 2026-11-01  
**Auditor:** Antigravity AI Senior Systems & Flutter Architecture Pair  
**Baseline Documents:** `product_context/FLUTTER_CONVERSION_BRIEF.md`, `product_context/prototype/original/polypet-demo.html`, `PROTOTYPE_ANALYSIS.md`, `TECHNICAL_ARCHITECTURE.md`, `AI_ARCHITECTURE.md`, `ANDROID_OVERLAY.md`  
**Execution Phase:** **Phase 0 — Audit Only (Strict Read-Only Verification)**

---

## 1. Current Project Architecture

### 1.1. System Overview
```
┌────────────────────────────────────────────────────────────────────────┐
│                        Android OS 14 Surface (I2208)                   │
├───────────────────────────────────┬────────────────────────────────────┤
│     Flutter Application Shell     │   Native Android Kotlin Overlay    │
│  - MaterialApp / AppRouter        │  - WindowManager (TYPE_APP_OVERLAY)│
│  - Riverpod State (companionState)│  - FloatingPetService (FGS)        │
│  - MainNavigationShell (Stack)    │  - Pet WebView (WebViewClient)     │
│  - Screens: Home/Progress/        │  - Native TTS / SpeechRecognizer   │
│    Achievements/Profile           │                                    │
└─────────────────┬─────────────────┴──────────────────┬─────────────────┘
                  │                                    │
                  │ MethodChannel: "com.lingoboop.app/overlay"
                  v                                    v
┌───────────────────────────────────┐ ┌──────────────────────────────────┐
│         Supabase Cloud            │ │     LingoBoom FastAPI Backend    │
│  - Supabase Auth (Email/Password) │ │  - /health (GET)                 │
│  - PostgreSQL RLS (Migrations 1-3)│ │  - /api/v1/stt/transcribe (POST) │
│  - profiles, user_preferences,    │ │  - /api/v1/tts/synthesize (POST) │
│    subscriptions, usage_records,  │ │  - RateLimiter & Token Security  │
│    learning_progress, achievements│ │  - Gnani.ai Proxy (vachana.ai)   │
└───────────────────────────────────┘ └──────────────────────────────────┘
```

### 1.2. Flutter Module Breakdown
- **Core Layer (`lib/core/`):**
  - `config/app_config.dart`: Supabase public URL and anon key; backend emulator/device URLs.
  - `constants/`: Design tokens (`app_colors.dart`), 6 character definitions (`character_data.dart`), language registries (`language_data.dart`).
  - `router/app_router.dart`: Imperative `onGenerateRoute` with route guard for protected paths.
  - `services/`: `auth_service.dart` (Supabase auth wrapper), `overlay_service.dart` (MethodChannel wrapper), `user_data_service.dart` (Supabase RLS client).
  - `theme/app_theme.dart`: Fredoka typography, custom input decoration, dynamic accent colors.
  - `widgets/`: `floating_pet_avatar.dart`, `karaoke_lyrics_view.dart`, `polypet_bottom_nav.dart`, `polypet_button.dart`, `polypet_mic_button.dart`, `character_chip.dart`.
- **Feature Layer (`lib/features/`):**
  - `welcome/`: Splash / entry point.
  - `auth/`: `signup_screen.dart`, `login_screen.dart`, `forgot_password_screen.dart`.
  - `onboarding/`: `language_select_screen.dart`, `goal_setup_screen.dart`, `pet_select_screen.dart`.
  - `home/`: `main_companion_screen.dart` (conversation prompt cards, history trigger, status pill).
  - `companion/`: `companion_state.dart` (Riverpod StateNotifier), `lingo_card_widget.dart` (karaoke dialogue card).
  - `navigation/`: `main_navigation_shell.dart` (persistent Stack hosting the pet above the 4 tab screens).
  - `progress/`: `progress_screen.dart` (vocabulary SRS cards with filter chips).
  - `achievements/`: `achievements_screen.dart` (milestone badges & streaks).
  - `profile/`: `profile_screen.dart` (speech quota gauge, streak, user metadata).
  - `settings/`: `settings_screen.dart`, `pet_settings_sheet.dart` (quick drawer).
  - `subscription/`: `subscription_screen.dart` (₹9/mo and ₹49/yr tier comparison).
  - `history/`: `history_screen.dart` (conversation log query).

---

## 2. Actual Welcome / Login / Signup Navigation

### Current State
- **Welcome Screen (`lib/features/welcome/presentation/welcome_screen.dart`):**
  - "Get Started" button calls `Navigator.pushNamed(context, '/signup')`.
  - "I already have an account" button calls `Navigator.pushNamed(context, '/login')`.
- **Signup Screen (`lib/features/auth/presentation/signup_screen.dart`):**
  - On submission: validates full name, email format, password (≥ 6 characters), and password confirmation matching.
  - Calls `AuthService.instance.signUpWithEmailPassword()`.
  - If session returned immediately: calls `Navigator.pushNamedAndRemoveUntil(context, '/onboarding/languages', (route) => false)`.
  - If email verification required: renders inline verification notice (`_infoMessage`).
- **Login Screen (`lib/features/auth/presentation/login_screen.dart`):**
  - Validates email and password.
  - Calls `AuthService.instance.signInWithEmailPassword()`.
  - Queries `UserDataService.instance.getUserLanguages()`. If empty, navigates to `/onboarding/languages`; otherwise navigates to `/home`.
- **Forgot Password Screen (`lib/features/auth/presentation/forgot_password_screen.dart`):**
  - Calls `AuthService.instance.sendPasswordResetEmail(email)`.

### Gaps Identified Against Conversion Brief
1. **Password Length:** Current validator checks `val.length < 6`, but the conversion brief explicitly requires **minimum 8 characters**.
2. **Routing Engine:** Currently implemented using imperative `Navigator.pushNamed` via `AppRouter.onGenerateRoute` rather than declarative `GoRouter` with auth-state refresh listening and automated redirect guards.
3. **Deep Link Handling:** Deep links for Supabase email confirmation (`/auth/v1/verify`) and password reset tokens (`type=recovery`) are not currently hooked up to Flutter intent filters or GoRouter branches.

---

## 3. Actual Supabase Authentication Behavior

### Verified Configuration
- **Supabase URL:** `https://kmkvyhtwxhsweznzubrr.supabase.co`
- **Anon Key:** Present in `AppConfig.supabaseAnonKey`.
- **Database Schema:** Tables `profiles`, `user_preferences`, `subscriptions`, `usage_records`, `conversations`, `conversation_messages`, `learning_progress`, `achievements`.
- **PostgreSQL Migrations:** Migrations 001, 002, and 003 applied with strict RLS policies, trigger `handle_new_user()` with security definer and hardened privileges (REVOKE TRUNCATE, RESTRICT DML on subscriptions/usage).
- **Backend Tests:** 24/24 tests pass in `backend/tests` (including 8 RLS cross-user isolation and privilege verification tests).

### Deficiencies in Client Auth Handling
- When Supabase initialization fails or network is offline, `AuthService.currentUser` returns `null`. `AppRouter` blocks navigation to `/home`, but does not provide an explicit retry/reconnect banner.
- Session persistence uses Supabase's built-in SharedPreferences storage; `flutter_secure_storage` is present in dependencies but not wired as the custom `LocalStorage` delegate for encrypted session tokens.

---

## 4. All Dummy or Simulated Functionality

| Component | File & Line Range | Dummy / Simulated Behavior | Production Requirement |
| :--- | :--- | :--- | :--- |
| **Speech Capture** | `companion_state.dart:174-179` | `Future.delayed(1500ms)` emitting hardcoded `'તમે કેમ છો? (How are you?)'` | Real audio recording via `record` package; streaming audio buffer to FastAPI |
| **Translation Engine** | `companion_state.dart:208-223` | Mirrors input text directly: `String targetSentence = input;` | Gnani Evon translation / tutoring via FastAPI |
| **Karaoke Synchronization** | `companion_state.dart:248-273` | Synthetic `Timer.periodic(intervalMs)` highlighting words by index heuristic | Word boundary millisecond timestamps from Gnani Timbre / Prisma alignment metadata |
| **Repetition Scoring** | `companion_state.dart:288-300` | Checks `cleanWord.isNotEmpty` marking all words `.ok` | Real word difference diffing against transcribed target speech |
| **Native Overlay Speech** | `FloatingPetWindowManager.kt:59-68` | Uses Android OS `TextToSpeech` and Google `SpeechRecognizer` | Shared backend pipeline via MethodChannel/EventChannel to FastAPI |

---

## 5. Current Pet Rendering Implementation & Package Dependencies

### Current Flutter Pet Architecture
- Handled by [`FloatingPetAvatar`](file:///c:/Users/Public/Shubham/Desktop/lingoboop/lib/core/widgets/floating_pet_avatar.dart).
- Initializes an in-app `WebViewController` from `webview_flutter: ^4.14.1`.
- Loads `assets/web/pet_viewer.html` which embeds `three.min.js`, `GLTFLoader.js`, and `models_data.js` (1.25 MB base64 bundle).
- Uses Three.js WebGL canvas inside an Android WebView wrapped in `ClipOval`.

### Critical Production Failure Identified in Conversion Brief
1. **Live WebGL Context Overhead:** Running a full Three.js WebGL context inside a Flutter WebView creates an entire Chromium compositor surface. Placing this inside lists, carousels, or floating overlays causes:
   - GPU context thrashing and crashes on mid-tier/budget Android devices.
   - Significant memory footprint (40–70 MB per WebView instance).
   - Occasional blank/white screens on device rotation or activity resume.
2. **Conversion Brief Directive:** Replace live WebGL WebViews with **offline-baked WebP sprite atlases (320×320 @ 20 FPS)**. Rendered via Flutter `CustomPainter` + `Ticker` (`SpritePlayer`) and native Android Kotlin `PetView`.

---

## 6. Original HTML Renderer & Animation Comparison

### Reference Setup in `polypet-demo.html`
- **Engine:** Three.js r128 WebGLRenderer (`alpha: true`, `antialias: true`).
- **Resolution & Aspect:** `150px × 150px`, pixel ratio `Math.min(devicePixelRatio || 1, 2)`.
- **Camera:** `PerspectiveCamera(30, 1, 0.1, 50)` at `(0, 1.3, 4.6)`, lookAt `(0, 0.62, 0)`.
- **Lighting:**
  - `HemisphereLight(0xffffff, 0x8899aa, 0.95)`
  - `DirectionalLight(0xffffff, 0.8)` positioned at `(2, 4, 3)`
- **Model Normalization:**
  - `model.traverse(o => o.frustumCulled = false)`
  - Center `c = b.getCenter()`, Size `z = b.getSize()`, Scale `s = 1.25 / Math.max(z.x, z.y, z.z)`
  - Feet anchor positioning: `model.position.set(-c.x * s, -b.min.y * s, -c.z * s)`
- **Animation Mixer:**
  - Cross-fading: `a.reset().fadeIn(0.25).play(); curA.fadeOut(0.25);`
  - Mapping: `idle → idle`, `walk → walk`, `drag → run`, `think → eat`, `talk → gesture-positive`, `listen → idle` (with 0.16 rad head tilt), `cheer/dance → dance`, `oops → gesture-negative`.

---

## 7. GLB Asset & Animation Verification

All 6 canonical GLB models in `LingoBoom_Antigravity_Starter/kenney_cube-pets_1.0/Models/GLB format` were inspected at the binary level:

| Pet | Key | Source GLB | Binary Size | Meshes | Clips Verified (8/8) | Clip Names |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Maru** | `fox` | `animal-fox.glb` | 141 KB | 6 | ✅ 8 | `['static', 'idle', 'walk', 'run', 'eat', 'dance', 'gesture-positive', 'gesture-negative']` |
| **Mimi** | `cat` | `animal-cat.glb` | 165 KB | 7 | ✅ 8 | `['static', 'idle', 'walk', 'run', 'eat', 'dance', 'gesture-positive', 'gesture-negative']` |
| **Pano** | `panda` | `animal-panda.glb` | 133 KB | 5 | ✅ 8 | `['static', 'idle', 'walk', 'run', 'eat', 'dance', 'gesture-positive', 'gesture-negative']` |
| **Bun** | `bunny` | `animal-bunny.glb` | 131 KB | 5 | ✅ 8 | `['static', 'idle', 'walk', 'run', 'eat', 'dance', 'gesture-positive', 'gesture-negative']` |
| **Pip** | `penguin` | `animal-penguin.glb` | 130 KB | 5 | ✅ 8 | `['static', 'idle', 'walk', 'run', 'eat', 'dance', 'gesture-positive', 'gesture-negative']` |
| **Leo** | `lion` | `animal-lion.glb` | 172 KB | 6 | ✅ 8 | `['static', 'idle', 'walk', 'run', 'eat', 'dance', 'gesture-positive', 'gesture-negative']` |

*Texture & Rigging Architecture:* Rigid node hierarchy transforms (`skins: 0`), single 128×128 solid-block colormap palette. Extremely lightweight and ideal for offline Three.js baking.

---

## 8. Existing Sprite Assets

- **Search Query:** `Get-ChildItem -Recurse -Filter *.webp`
- **Result:** **0 WebP sprite files found**.
- **Assessment:** No sprite atlases have been baked yet.
- **Conversion Brief Solution:** Create `tools/bake_pets/` using Node.js, Three.js r128, Playwright headless browser, and Sharp image processor to render transparent 320×320 frames at 20 FPS into compact WebP sheets + JSON manifests.

---

## 9. Android Overlay Implementation & Missing Behavior

### Current State (`android/app/src/main/kotlin/.../overlay/`)
- `FloatingPetService.kt`: Android Foreground Service with ongoing notification (`CHANNEL_ID = "lingoboom_floating_companion_channel"`), action `ACTION_STOP`.
- `FloatingPetWindowManager.kt`: Creates a 130dp `WindowManager` view (`TYPE_APPLICATION_OVERLAY`) with touch listener (ACTION_DOWN, ACTION_MOVE with clamping, ACTION_UP).
- `MainActivity.kt`: MethodChannel `"com.lingoboop.app/overlay"` handling `checkPermission`, `requestPermission`, `startOverlay`, `stopOverlay`, `updatePet`, `updateLanguages`.

### Missing Behaviors & Deficiencies
1. **Edge Snapping:** `FloatingPetWindowManager.kt` clamps coordinates during dragging, but does not snap the pet to the nearest screen edge (left or right) upon touch release with a spring/lerp animation.
2. **Event Channel Missing:** `MainActivity.kt` only implements `MethodChannel` (Flutter → Android). There is no `EventChannel` (Android → Flutter) to inform Flutter when the overlay pet is tapped or the mic button is triggered.
3. **Overlay Pet View:** The overlay currently uses a native Android `WebView` loading HTML WebGL. It must be migrated to a lightweight native `PetView` powered by the baked WebP sprite atlases.
4. **Independent Window Hierarchy:** Currently, the LingoCard panel is embedded in the same window or inflated imperatively without focus management for soft-keyboard input.

---

## 10. Manifest Permission Audit

### Comparison Table

| Permission / Declaration | `src/main/` | `src/debug/` | `src/profile/` | `src/release/` | Status & Risk |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `android.permission.INTERNET` | ✅ Present | ✅ Present | ✅ Present | ❌ File missing | **Critical Risk:** `src/release/AndroidManifest.xml` does not exist. While Gradle merges `src/main/`, explicit release verification is required. |
| `android.permission.ACCESS_NETWORK_STATE` | ❌ Missing | ❌ Missing | ❌ Missing | ❌ Missing | **Missing:** Required for Supabase/Dio offline/online connectivity checks. |
| `android.permission.SYSTEM_ALERT_WINDOW` | ✅ Present | ❌ | ❌ | ❌ | Configured in main. |
| `android.permission.FOREGROUND_SERVICE` | ✅ Present | ❌ | ❌ | ❌ | Configured in main. |
| `android.permission.FOREGROUND_SERVICE_SPECIAL_USE`| ✅ Present | ❌ | ❌ | ❌ | Declared with property subtype. |
| `android.permission.FOREGROUND_SERVICE_MICROPHONE` | ❌ Missing | ❌ Missing | ❌ Missing | ❌ Missing | **Android 14 Violation:** Required if audio recording runs from the background/overlay service. |
| `android.permission.RECORD_AUDIO` | ✅ Present | ❌ | ❌ | ❌ | Configured in main. |
| `android.permission.POST_NOTIFICATIONS` | ✅ Present | ❌ | ❌ | ❌ | Configured in main (Android 13+). |
| `android.permission.VIBRATE` | ✅ Present | ❌ | ❌ | ❌ | Configured in main. |
| `<queries>` for TTS (`android.intent.action.TTS_SERVICE`)| ❌ Missing | ❌ Missing | ❌ Missing | ❌ Missing | **Android 11+ Package Visibility Gap:** Required to query device TTS engines. |
| `<queries>` for Speech (`RecognitionService`) | ❌ Missing | ❌ Missing | ❌ Missing | ❌ Missing | **Android 11+ Package Visibility Gap:** Required to query native speech recognizers. |

---

## 11. Existing FastAPI Endpoints & Provider Readiness

### Verified Backend Endpoints (`backend/app/routers/`)
- `GET /health` (`backend/app/routers/health.py`): Returns API operational status.
- `POST /api/v1/stt/transcribe` (`backend/app/routers/stt.py`):
  - Form parameters: `audio_file` (UploadFile), `language_code` (`gu-IN`, `hi-IN`, `en-IN`), `model` (`prisma-v3.0`).
  - Header: `Authorization: Bearer <token>` or verified client token.
  - Proxies to Gnani Prisma endpoint `https://api.vachana.ai/stt/v3` with header `X-API-Key-ID`.
- `POST /api/v1/tts/synthesize` (`backend/app/routers/tts.py`):
  - JSON payload: `text`, `voice` (`Shivani`), `model` (`timbre-v3.0`), `language`, `speed`, `audio_config`.
  - Proxies to Gnani Timbre endpoint `https://api.vachana.ai/api/v1/tts/inference` with header `X-API-Key-ID`.
  - Returns `audio_base64` and metadata.

### Missing Backend Endpoints
- **Translation / Evon Router:** There is currently NO translation endpoint (e.g. `/api/v1/translation/translate` or `/api/v1/tutor/chat`) in FastAPI.
- **Provider Status:**
  - `GNANI_API_KEY`: Verified configured in `backend/.env` (134-character production key starting with `vach...`).
  - Base URL: `https://api.vachana.ai`.
  - Evon API: The official hosted endpoint for Evon has not been confirmed. Per non-negotiable rule 14: *Do not claim Evon works until a real supported API or hosted deployment has been confirmed.*

---

## 12. Exact Reasons Speech Does Not Work

1. **Frontend Disconnection:** Flutter's `companion_state.dart` has never sent an HTTP request to `http://10.0.2.2:8000` (emulator) or `http://127.0.0.1:8000` / local IP (device). It immediately runs `Future.delayed(1500ms)`.
2. **Missing Recording Engine in Flutter:** `record` package is not in `pubspec.yaml`. The app cannot capture PCM/WAV mic buffers yet.
3. **Missing Audio Player in Flutter:** Neither `just_audio` nor `audioplayers` is installed in `pubspec.yaml`. The app has no mechanism to stream or play returned base64 WAV audio bytes.
4. **Android 14 FGS Microphone Type:** In the overlay, `RECORD_AUDIO` cannot be used from a service declared only as `specialUse` without `foregroundServiceType="specialUse|microphone"`.

---

## 13. Current Build & Test Results

- **Flutter Unit & Widget Tests:** **14/14 PASSED** (`flutter test`)
  - `test/auth_flow_test.dart`: 6 tests passing (Welcome routing, Signup validation, Login validation, ForgotPassword validation, Route protection).
  - `test/tab_persistence_test.dart`: 1 test passing (Pet avatar remains mounted across Home, Progress, Achievements, Profile).
  - `test/companion_state_test.dart`: 5 tests passing (Riverpod state logic).
  - `test/main_companion_screen_test.dart`: 1 test passing (Companion stage UI).
  - `test/widget_test.dart`: 1 test passing (Welcome screen brand verification).
- **Flutter Analyzer:** **0 warnings, 0 errors** (`flutter analyze` ran in 3.0s).
- **Backend Test Suite:** **24/24 PASSED** (`pytest backend/tests` in 22.42s).
- **Android APK Build:** `assembleDebug` completed in 28.9s (`build/app/outputs/flutter-apk/app-debug.apk`).
- **Device Installation:** Installed on connected physical Android 14 device `I2208` (`10BCBF23HT000H7`).

---

## 14. Risks, Missing Dependencies & Recommended Changes

### Identified Risks
1. **WebGL WebView Instability:** Keeping live 3D Three.js WebViews inside Flutter and Android `WindowManager` causes high memory consumption and GPU context crashes on Android.
2. **Android 14 FGS Enforcement:** Google Play and Android 14 will reject background mic recording without explicit `microphone` foreground service type.
3. **Offline Token Security:** Current auth tokens are stored in unencrypted SharedPreferences instead of Android KeyStore (`flutter_secure_storage`).

### Dependencies to Introduce in Subsequent Phases
```yaml
# To be added in Phase 1 & Phase 3:
dio: ^5.8.0
record: ^5.2.0
just_audio: ^0.9.43
audio_session: ^0.1.25
```

---

## 15. File-by-File Implementation Plan (Phases 1–5)

### Phase 1 — Authentication & Application Shell
| File | Action | Description |
| :--- | :--- | :--- |
| `lib/main.dart` | Refactor | Initialize GoRouter with auth-state refresh stream and redirect guards. |
| `lib/core/router/app_router.dart` | Replace | Transition from imperative `Navigator` to declarative `GoRouter` configuration. |
| `lib/features/auth/presentation/signup_screen.dart` | Update | Enforce minimum 8-character password validator; add inline error messages. |
| `lib/core/services/auth_service.dart` | Update | Integrate `flutter_secure_storage` as the custom `LocalStorage` delegate for Supabase session persistence. |
| `android/app/src/main/AndroidManifest.xml` | Update | Add `ACCESS_NETWORK_STATE`, verify `INTERNET` and deep-link intent filters for Supabase recovery. |

### Phase 2 — Pet Sprite Baking, Selection & Animations
| File | Action | Description |
| :--- | :--- | :--- |
| `tools/bake_pets/package.json` | Create | Node.js script environment with Three.js r128, Playwright, and Sharp. |
| `tools/bake_pets/bake.js` | Create | Headless WebGL pipeline rendering 6 canonical GLBs into 320×320 transparent WebP atlases @ 20 FPS with JSON manifests. |
| `assets/characters/<pet>/sprites/` | Output | Store generated `.webp` sprite sheets and `manifest.json` files for Maru, Mimi, Pano, Bun, Pip, Leo. |
| `lib/core/widgets/sprite_player.dart` | Create | High-performance Flutter `CustomPainter` + `Ticker` rendering sprite frames without WebViews. |
| `lib/core/widgets/floating_pet_avatar.dart` | Refactor | Swap `WebViewController` with `SpritePlayer`. |
| `lib/features/character/presentation/pet_select_screen.dart` | Update | Use 256px idle sprite frames in the selection carousel. |

### Phase 3 — Real Speech, Translation & Audio Pipeline
| File | Action | Description |
| :--- | :--- | :--- |
| `pubspec.yaml` | Update | Add `record: ^5.2.0`, `just_audio: ^0.9.43`, `audio_session: ^0.1.25`, `dio: ^5.8.0`. |
| `lib/core/services/speech_service.dart` | Create | Mic recording via `record`, multipart HTTP stream to FastAPI `/api/v1/stt/transcribe`. |
| `lib/core/services/audio_playback_service.dart` | Create | High-fidelity audio playback via `just_audio` with 1.0x and 0.7x speed support. |
| `lib/features/companion/presentation/companion_state.dart` | Refactor | Remove `Future.delayed(1500ms)`; connect real mic capture, STT, and TTS audio streaming. |
| `backend/app/routers/translation.py` | Create | Add contextual translation endpoint (falling back cleanly if Evon is not deployed). |

### Phase 4 — Native Android Floating Overlay & Independent Voice
| File | Action | Description |
| :--- | :--- | :--- |
| `android/app/src/main/kotlin/.../overlay/PetView.kt` | Create | Native Android custom `View` rendering baked WebP sprite atlases via `BitmapRegionDecoder` / Canvas. |
| `android/app/src/main/kotlin/.../overlay/FloatingPetWindowManager.kt` | Refactor | Replace `WebView` with `PetView`; implement edge snapping physics (lerp to screen boundary on release). |
| `android/app/src/main/kotlin/.../overlay/FloatingPetService.kt` | Update | Add `EventChannel` emission for pet touch and mic events; handle Android 14 FGS microphone type. |
| `android/app/src/main/AndroidManifest.xml` | Update | Declare `FOREGROUND_SERVICE_MICROPHONE` and package queries for TTS and SpeechRecognizer. |

### Phase 5 — Real Data, Settings, Profile & Polish
| File | Action | Description |
| :--- | :--- | :--- |
| `lib/features/profile/presentation/profile_screen.dart` | Polish | Hook real Supabase speech seconds gauge and streak counts. |
| `lib/features/progress/presentation/progress_screen.dart` | Polish | Wire Spaced Repetition mastery review loop with real conversation vocabulary. |
| `lib/features/achievements/presentation/achievements_screen.dart` | Polish | Render celebration pet dance trigger upon badge unlock. |

---

## 16. Audit Conclusion & Stop Gate

Phase 0 audit is complete. No application code, database schema, or assets have been modified or deleted during this phase.

**Awaiting your approval to begin Phase 1 (Authentication and Application Shell).**

