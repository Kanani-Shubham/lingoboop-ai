# LingoBoop — Prioritized Implementation Roadmap & Production Engineering Plan

**Document Version:** 1.0.0  
**Date:** November 2, 2026  
**Status:** Awaiting Architecture Review & User Authorization  
**Target Platform:** Flutter 3.38+ / Android 14 (API 34/35) / FastAPI / Supabase PostgreSQL 15  

---

## Roadmap Overview & Engineering Principles

This implementation roadmap outlines the concrete, prioritized engineering phases required to transition LingoBoop from its audited state to a hardened, production-grade application.

### Key Engineering Principles
1. **Zero-Mock Policy:** All voice, LLM, translation, and user persistence workflows must interact directly with production APIs (Groq `openai/gpt-oss-120b`, Gnani Prisma v3.0, Gnani Timbre v3.0, Supabase PostgreSQL).
2. **Phase Isolation:** Code modifications are staged in discrete, dependency-aware phases. Each phase concludes with explicit physical device testing on Android 14 (`10BCBF23HT000H7`).
3. **Preservation of Assets:** Original character assets, 3D GLB meshes, and database structures are maintained and leveraged without arbitrary rewrites.
4. **Independent Native Overlay:** The Android overlay must function as an autonomous system-level utility without coupling to Flutter's activity stack.

---

## Phase 1: Critical Foundation & Architectural Stabilization

- **Objective:** Establish baseline stability, resolve authentication token verification, remove dead code, and ensure clean communication between Flutter and FastAPI.
- **Estimated Complexity:** Medium
- **Dependencies:** None

### Tasks
1. **TASK-1.1:** Implement Supabase JWT cryptographic validation in `backend/app/core/security.py` using `python-jose` / `PyJWT` with `SUPABASE_JWT_SECRET`.
2. **TASK-1.2:** Deprecate and remove dead/orphaned code in `lib/features/pet_overlay/floating_pet_overlay_stack.dart` and unify duplicate character definitions in `lib/core/constants/character_data.dart`.
3. **TASK-1.3:** Harden FastAPI CORS and security headers in `backend/app/main.py`.
4. **TASK-1.4:** Validate environment variables at backend startup with detailed descriptive error messages in `backend/app/core/config.py`.

### Files to Modify
- `backend/app/core/security.py`
- `backend/app/core/config.py`
- `backend/app/main.py`
- `lib/features/pet_overlay/floating_pet_overlay_stack.dart` (mark deprecated / remove)
- `lib/core/constants/character_data.dart`

### Database Migrations
- None for this phase.

### Potential Risks & Mitigation
- *Risk:* Validating JWT tokens will block unauthenticated requests in development.
- *Mitigation:* Ensure Flutter client passes Supabase auth session token (`sbClient.auth.currentSession?.accessToken`) in HTTP Authorization header for all API requests.

### Acceptance Criteria
- `verify_client_token` in `security.py` correctly decodes user UUID from valid Supabase JWT and rejects expired or forged tokens with HTTP 401.
- Project compiles cleanly with zero references to obsolete overlay stack.

---

## Phase 2: Complete AI Voice Pipeline (Prisma, Groq & Timbre)

- **Objective:** Ensure end-to-end reliability of microphone audio capture, Gnani Prisma speech transcription, Groq AI tutoring, and Gnani Timbre neural voice synthesis.
- **Estimated Complexity:** Large
- **Dependencies:** Phase 1

### Tasks
1. **TASK-2.1:** Harden Flutter audio recording configuration in `lib/core/services/speech_service.dart` to enforce 16,000 Hz, 1-channel mono, 16-bit linear PCM WAV recording (`AudioEncoder.wav`).
2. **TASK-2.2:** Add pre-flight WAV header validation in `backend/app/services/speech_service.py` to reject corrupt or truncated audio before forwarding to Gnani.
3. **TASK-2.3:** Consolidate AI tutoring and translation into `backend/app/routers/ai.py`, deprecating redundant offline mock translation routes.
4. **TASK-2.4:** Implement automatic retry with exponential backoff for Gnani STT and Groq API calls in `backend/app/services/gnani_service.py` and `ai_service.py`.
5. **TASK-2.5:** Optimize audio player caching in `lib/core/services/audio_player_service.dart` to cache prompt responses locally.

### Files to Modify
- `lib/core/services/speech_service.dart`
- `lib/core/services/audio_player_service.dart`
- `backend/app/services/speech_service.py`
- `backend/app/services/gnani_service.py`
- `backend/app/services/ai_service.py`
- `backend/app/routers/ai.py`
- `backend/app/routers/translation.py` (deprecate)

### Database Migrations
- None for this phase.

### Potential Risks & Mitigation
- *Risk:* Network latency on mobile data causing timeout errors during voice query.
- *Mitigation:* Set client timeout to 15s and implement intermediate UI feedback ("Listening...", "Transcribing...", "Thinking...", "Speaking...").

### Acceptance Criteria
- Spoken audio in Gujarati, Hindi, or English is transcribed accurately by Gnani Prisma v3.0.
- Groq `openai/gpt-oss-120b` returns bilingual translation and pronunciation hints within 800ms.
- Gnani Timbre synthesizes WAV audio that plays back clearly without clicking or distortion.

---

## Phase 3: Floating Pet System & Edge-Snapping Mechanics

- **Objective:** Hardening the native Android WindowManager floating pet service to provide fluid dragging, magnetic edge-snapping, and zero duplicate pets across lifecycle transitions.
- **Estimated Complexity:** Medium
- **Dependencies:** Phase 1

### Tasks
1. **TASK-3.1:** Verify and harden `FloatingPetWindowManager.kt` drag gesture detection and spring physics for left/right edge-snapping.
2. **TASK-3.2:** Maintain mutual exclusion in `MainActivity.kt` so the native overlay is automatically hidden on Activity `onResume()` and restored on `onPause()` (if enabled).
3. **TASK-3.3:** Add boundary clamping to prevent dragging the pet under the Android status bar notch or system navigation bar.
4. **TASK-3.4:** Add persistent storage of the last resting pet coordinates in SharedPreferences / user preferences so the pet reopens in the same position.

### Files to Modify
- `android/app/src/main/kotlin/com/example/lingoboop/FloatingPetWindowManager.kt`
- `android/app/src/main/kotlin/com/example/lingoboop/FloatingPetService.kt`
- `android/app/src/main/kotlin/com/example/lingoboop/MainActivity.kt`
- `lib/core/services/floating_pet_service.dart`

### Database Migrations
- Prerequisite: `20261102000100_overlay_preferences_and_pet_position.sql`.

### Potential Risks & Mitigation
- *Risk:* Android 14 restricts background services starting overlays without user consent.
- *Mitigation:* Verify `Settings.canDrawOverlays(context)` before starting service; prompt user with explanation dialog if permission is revoked.

### Acceptance Criteria
- User can freely drag the pet around the screen over any app (WhatsApp, Chrome, YouTube).
- Releasing the pet causes it to snap smoothly to the closest screen margin.
- Never more than one pet visible at any time.

---

## Phase 4: Independent Floating Conversation Card (Native Overlay)

- **Objective:** Enable direct opening and interaction with the floating conversation card directly over external applications without launching MainActivity.
- **Estimated Complexity:** Large
- **Dependencies:** Phase 2, Phase 3

### Tasks
1. **TASK-4.1:** Verify `onSingleTapConfirmed` in `FloatingPetWindowManager.kt` toggles the native overlay card directly via `togglePanel()` without calling `startActivity()`.
2. **TASK-4.2:** Ensure the native card view is dynamically positioned above or below the pet based on screen quadrant to prevent off-screen clipping.
3. **TASK-4.3:** Connect the action buttons in the native overlay card (Play, Repeat, Close) to audio playback and dismiss routines.
4. **TASK-4.4:** Support receiving new learning prompts from the backend via broadcast intent or service channel.

### Files to Modify
- `android/app/src/main/kotlin/com/example/lingoboop/FloatingPetWindowManager.kt`
- `android/app/src/main/kotlin/com/example/lingoboop/FloatingPetService.kt`

### Database Migrations
- None for this phase.

### Potential Risks & Mitigation
- *Risk:* Complex touch event collision between the pet view and the conversation card.
- *Mitigation:* Use separate `WindowManager.LayoutParams` and independent view instances for the pet and the conversation card.

### Acceptance Criteria
- Tapping the floating pet over WhatsApp displays the conversation card directly on top of WhatsApp.
- MainActivity is not brought to the foreground; WhatsApp remains active.
- Tapping the `✕` close button removes the conversation card while leaving the pet visible.

---

## Phase 5: UI/UX, Responsive Layouts & Three.js Animation Synchronization

- **Objective:** Eliminate visual layout overflow errors, ensure responsive sizing across all screen densities, and guarantee smooth 3D character animation transitions.
- **Estimated Complexity:** Medium
- **Dependencies:** Phase 2, Phase 3

### Tasks
1. **TASK-5.1:** Audit and eliminate all layout overflow errors in `lib/features/companion/widgets/poly_card_widget.dart` by using `FittedBox` and responsive padding.
2. **TASK-5.2:** Add `SafeArea` and dynamic bottom inset padding to companion selector modal and profile bottom sheets.
3. **TASK-5.3:** Optimize Three.js animation controller in `assets/web/pet_viewer.html` with smooth cross-fading (`fadeIn(0.25)`) between `idle`, `walk`, `run`, `listen`, `talk`, `think`, and `dance`.
4. **TASK-5.4:** Link UI companion switching directly to the active 3D character model and native overlay avatar.

### Files to Modify
- `lib/features/companion/widgets/poly_card_widget.dart`
- `lib/features/companion/screens/companion_screen.dart`
- `lib/features/profile/screens/profile_screen.dart`
- `assets/web/pet_viewer.html`

### Database Migrations
- None for this phase.

### Potential Risks & Mitigation
- *Risk:* Rapidly tapping the pet could trigger concurrent Three.js animation actions, causing T-pose glitch.
- *Mitigation:* Clamp animation transitions and enforce minimum 200ms debounce between animation switches.

### Acceptance Criteria
- Zero Flutter overflow stripe errors across any screen (tested on 360dp, 392dp, and 412dp viewports).
- Character animations transition smoothly without freezing or jumping.

---

## Phase 6: Database Persistence & User Preferences Synchronization

- **Objective:** Execute and verify Supabase PostgreSQL schema migrations and ensure bidirectional synchronization of user preferences, learning progress, and conversation history.
- **Estimated Complexity:** Medium
- **Dependencies:** Phase 1

### Tasks
1. **TASK-6.1:** Execute migration `supabase/migrations/20261102000100_overlay_preferences_and_pet_position.sql` against the Supabase cloud database.
2. **TASK-6.2:** Verify RLS policies on `user_preferences`, `learning_progress`, `conversations`, and `messages`.
3. **TASK-6.3:** Harden `lib/core/services/user_data_service.dart` with offline fallback caching using `SharedPreferences`.
4. **TASK-6.4:** Implement daily speech practice minutes incrementation in `learning_progress` when user completes voice interactions.

### Files to Modify
- `supabase/migrations/20261102000100_overlay_preferences_and_pet_position.sql`
- `lib/core/services/user_data_service.dart`
- `lib/features/companion/screens/companion_screen.dart`

### Database Migrations
- `20261102000100_overlay_preferences_and_pet_position.sql` (Required in production database).

### Potential Risks & Mitigation
- *Risk:* Network failure during preference save leaving local and remote state desynchronized.
- *Mitigation:* Save locally first (optimistic UI), queue sync operation, and flush to Supabase upon reconnection.

### Acceptance Criteria
- User preference changes (e.g., active buddy, target language, overlay enabled) persist across app termination and reboot.
- Daily speech practice minutes accurately update in Supabase and reflect on the companion dashboard.

---

## Phase 7: Performance Optimization & Latency Reduction

- **Objective:** Optimize end-to-end latency across speech recognition, LLM reasoning, TTS synthesis, and 3D rendering.
- **Estimated Complexity:** Large
- **Dependencies:** Phase 2, Phase 5

### Tasks
1. **TASK-7.1:** Implement parallel pre-warming of the Gnani TTS connection while Groq LLM generates response tokens.
2. **TASK-7.2:** Cache pre-synthesized audio for default practice prompts ("Ask for Directions", "Order Refreshments", "Introduce Yourself").
3. **TASK-7.3:** Pre-warm the Three.js WebView in the background on app startup to eliminate the 450ms pet render delay.
4. **TASK-7.4:** Optimize base64 JSON payload sizes by streaming raw binary audio where supported.

### Files to Modify
- `backend/app/services/speech_service.py`
- `backend/app/services/gnani_service.py`
- `backend/app/routers/ai.py`
- `lib/core/services/speech_service.dart`
- `lib/main.dart`

### Database Migrations
- None for this phase.

### Potential Risks & Mitigation
- *Risk:* Pre-warming audio requests could increase cloud API cost.
- *Mitigation:* Restrict pre-warming strictly to active user sessions and top 5 standard prompt templates.

### Acceptance Criteria
- Total voice roundtrip latency (end of speech to audio playback) reduced to under 1.8 seconds.
- Repeat playback of standard practice prompts begins in under 50ms.

---

## Phase 8: Comprehensive Testing & Device Stabilization

- **Objective:** Execute exhaustive automated and physical device testing across all supported Android configurations.
- **Estimated Complexity:** Medium
- **Dependencies:** Phases 1–7

### Tasks
1. **TASK-8.1:** Run and verify backend test suite:
   - `backend/tests/test_groq_ai.py`
   - `backend/tests/live_gnani_check.py`
   - `backend/tests/test_supabase_rls_isolation.py`
2. **TASK-8.2:** Execute Flutter integration tests for authentication, companion switching, and practice prompts.
3. **TASK-8.3:** Perform physical device stress testing on Vivo/iQOO Android 14 (`10BCBF23HT000H7`):
   - Background execution test (> 30 minutes).
   - Rapid app switching (LingoBoop <-> WhatsApp <-> Chrome).
   - Low-bandwidth network throttling test.

### Files to Modify
- `backend/tests/` (expand test assertions)
- `test/` (Flutter unit and widget tests)

### Database Migrations
- None for this phase.

### Potential Risks & Mitigation
- *Risk:* OEM background execution kill (e.g. Funtouch OS battery manager).
- *Mitigation:* Document OEM permission setup (Autostart toggle) in settings screen.

### Acceptance Criteria
- All automated backend and Flutter tests pass with 100% success.
- Zero crashes or memory leaks during 30 minutes of continuous physical device usage.

---

## Phase 9: Production Readiness & Release Preparation

- **Objective:** Finalize security hardening, error monitoring, build configuration, and release artifact generation.
- **Estimated Complexity:** Medium
- **Dependencies:** Phase 8

### Tasks
1. **TASK-9.1:** Enable ProGuard/R8 code shrinking and resource optimization in `android/app/build.gradle.kts`.
2. **TASK-9.2:** Configure structured production logging with Sentry or Firebase Crashlytics.
3. **TASK-9.3:** Verify all `.env` secrets are excluded from release APK build.
4. **TASK-9.4:** Generate signed production release APK / AAB.

### Files to Modify
- `android/app/build.gradle.kts`
- `lib/main.dart`
- `backend/app/core/logging.py`

### Database Migrations
- None for this phase.

### Potential Risks & Mitigation
- *Risk:* R8 code obfuscation breaking reflection in Three.js WebView or Gnani serialization.
- *Mitigation:* Add explicit ProGuard keep rules for WebChromeClient and Pydantic models.

### Acceptance Criteria
- Release APK builds cleanly with ProGuard enabled.
- Application launches, logs in, renders 3D pet, and executes voice conversation with zero runtime errors.

---

## Implementation Priority Matrix

| Issue / Task ID | Feature | Severity | Priority | Complexity | User Impact | Dependencies | Target Phase |
|---|---|---|---|---|---|---|---|
| **TASK-3.2 / BUG-02** | Duplicate Pet Prevention | Critical | **P0** | Small | Prevents confusing dual-pet display on screen | None | Phase 3 |
| **TASK-4.1 / BUG-01** | Overlay Direct Card Open | Critical | **P0** | Medium | Enables core overlay utility over 3rd-party apps | Task 3.2 | Phase 4 |
| **TASK-2.1 / BUG-04** | 16kHz PCM WAV Recording | Critical | **P0** | Medium | Enables speech recognition to actually work | None | Phase 2 |
| **TASK-1.1 / BUG-05** | Supabase JWT Verification | High | **P0** | Medium | Secures backend APIs against unauthorized abuse | None | Phase 1 |
| **TASK-5.1 / BUG-03** | PolyCard Sizing Overflow | High | **P1** | Small | Eliminates ugly red/yellow overflow error stripe | None | Phase 5 |
| **TASK-6.1 / BUG-08** | Cloud SQL Migration | High | **P1** | Small | Ensures overlay preferences persist in cloud DB | None | Phase 6 |
| **TASK-2.3 / BUG-07** | Consolidate AI Routers | Medium | **P1** | Small | Removes divergent mock translation endpoints | Task 1.1 | Phase 2 |
| **TASK-1.2 / BUG-06** | Remove Dead Overlay Stack | Medium | **P2** | Small | Cleans codebase and prevents developer errors | None | Phase 1 |
| **TASK-7.1 / BUG-10** | Voice Latency Optimization | Medium | **P2** | Large | Drops voice roundtrip from 3.5s to < 1.8s | Task 2.1 | Phase 7 |
| **TASK-5.3 / BUG-09** | Three.js Animation Clamping | Low | **P3** | Small | Eliminates occasional animation freeze on spam | None | Phase 5 |

---

## The First Ten Engineering Tasks (Execution Order)

1. **Task 1 (P0):** Execute Supabase SQL migration `20261102000100_overlay_preferences_and_pet_position.sql` to align database schema.
2. **Task 2 (P0):** Enforce 16,000 Hz mono 16-bit linear PCM WAV recording in `lib/core/services/speech_service.dart`.
3. **Task 3 (P0):** Verify `FloatingPetWindowManager.kt` direct tap event (`togglePanel()`) without invoking `startActivity()`.
4. **Task 4 (P0):** Verify `MainActivity.kt` lifecycle hooks (`onResume` hide / `onPause` show) to guarantee single pet.
5. **Task 5 (P0):** Implement JWT verification in `backend/app/core/security.py` using `SUPABASE_JWT_SECRET`.
6. **Task 6 (P1):** Fix `PolyCardWidget` horizontal overflow by applying `FittedBox` and responsive padding.
7. **Task 7 (P1):** Deprecate orphaned `lib/features/pet_overlay/floating_pet_overlay_stack.dart`.
8. **Task 8 (P1):** Consolidate translation routes into `backend/app/routers/ai.py` and disable mock fallback in production.
9. **Task 9 (P2):** Implement pre-synthesized audio caching for standard practice prompt buttons.
10. **Task 10 (P2):** Clamp Three.js cross-fade animation durations in `assets/web/pet_viewer.html`.

