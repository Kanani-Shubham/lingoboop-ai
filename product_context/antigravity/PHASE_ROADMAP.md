# LingoBoom — Dependency-Aware Engineering Roadmap (Phases 0–12)

---

## Phase 0: Workspace Organization, Asset Audit & Technical Analysis
- **Status:** **Completed**
- **Objectives:** Inspect all workspace files, extract and audit 3D character models, analyze HTML prototype, establish clean directory architecture, and author comprehensive documentation.
- **Dependencies:** None.
- **Deliverables:** Organized `assets/characters/`, `product_context/` analysis reports, `.env.example`, hardened `.gitignore`, and updated root `README.md`.
- **Acceptance Criteria:** Full workspace audit completed without modifying application code or deleting original assets.

---

## Phase 1: Flutter Foundation & Core Architecture
- **Objectives:** Establish production clean architecture folders, configure Riverpod state management, setup GoRouter navigation, integrate Google Fonts (`Fredoka`), and implement base UI theme system.
- **Dependencies:** Phase 0.
- **Files / Modules:** `lib/core/`, `lib/theme/`, `lib/router/`, `pubspec.yaml`.
- **Expected Deliverables:** Compiling Flutter app with dynamic character theming, typography hierarchy, and scaffold navigation.
- **Acceptance Criteria:** `flutter analyze` passes with 0 errors; theme switches accent colors dynamically.
- **Testing Requirements:** Golden test on base theme; unit test on Riverpod theme providers.

---

## Phase 2: Authentication & Onboarding Flow
- **Objectives:** Integrate Supabase Flutter SDK, build email/password and Google OAuth login/signup screens, and create 4-step onboarding wizard.
- **Dependencies:** Phase 1.
- **Files / Modules:** `lib/features/auth/`, `lib/features/onboarding/`, `supabase/schema.sql`.
- **Expected Deliverables:** Functional login/signup, session persistence in `flutter_secure_storage`, and onboarding questionnaire.
- **Acceptance Criteria:** New user signs up, sets native/target languages, and record appears in Supabase `profiles`.
- **Testing Requirements:** Mock authentication service unit tests; onboarding page transition widget tests.

---

## Phase 3: Character Selection & 3D Model Rendering
- **Objectives:** Build interactive 3D character carousel showcasing the 6 pets, integrating GLB model rendering, and animating between `idle` and `dance` poses.
- **Dependencies:** Phase 1.
- **Files / Modules:** `lib/features/characters/`, `assets/characters/*/models/*.glb`.
- **Expected Deliverables:** 3D viewport widget rendering Maru, Mimi, Pano, Bun, Pip, and Leo with smooth touch rotation.
- **Acceptance Criteria:** Selected character persists to user profile; 60fps rendering without memory leaks.
- **Testing Requirements:** Model load error handling tests; memory profiling on asset switching.

---

## Phase 4: Android Native Floating Overlay Service
- **Objectives:** Implement Kotlin `WindowManager` service with `TYPE_APPLICATION_OVERLAY`, configure `SYSTEM_ALERT_WINDOW` permission request flow, and create platform channel bridge.
- **Dependencies:** Phase 1, Phase 3.
- **Files / Modules:** `android/app/src/main/kotlin/.../overlay/`, `lib/core/platform/overlay_bridge.dart`.
- **Expected Deliverables:** Native floating pet overlay that runs over any Android application with drag physics and floor lerp.
- **Acceptance Criteria:** Floating pet draggable anywhere on screen; touches outside pass through to underlying apps.
- **Testing Requirements:** Device testing on Android 10, 12, and 14; permission rejection handling.

---

## Phase 5: LingoCard Interface & Spotify-Style Synced Lyrics
- **Objectives:** Build docked floating LingoCard matching `polypet-demo.html` proportions, dock-side detection (left/right of pet), and word karaoke highlighting (`.w`, `.on`).
- **Dependencies:** Phase 4.
- **Files / Modules:** `lib/features/overlay/lingocard_view.dart`, `lib/features/overlay/karaoke_controller.dart`.
- **Expected Deliverables:** Floating card attached to character with Play, Slow, Repeat, and Mic buttons.
- **Acceptance Criteria:** Card smoothly pops out adjacent to pet; words illuminate progressively on timestamp ticks.
- **Testing Requirements:** Widget tests on word boundary highlight states and dock-position calculations.

---

## Phase 6: Gnani AI Suite Integration & FastAPI Backend Gateway
- **Objectives:** Build FastAPI proxy backend, integrate Gnani Prisma v3.0 (STT), Gnani Timbre (TTS), and Gnani Evon (Tutor LLM), and establish streaming WebSocket channel.
- **Dependencies:** Phase 1, Phase 5.
- **Files / Modules:** `backend/`, `backend/services/gnani_service.py`, `lib/core/network/audio_stream_client.dart`.
- **Expected Deliverables:** Live microphone audio captured in Flutter, streamed to backend, transcribed by Prisma, translated, and synthesized by Timbre.
- **Acceptance Criteria:** Round-trip latency from speech finish to audio playback < 1,500ms; zero exposed API keys in mobile code.
- **Testing Requirements:** Mock Gnani API test harness; audio buffer stream integration tests.

---

## Phase 7: Real-Time Voice Translation & Conversational AI
- **Objectives:** Connect LingoCard microphone button to Gnani live streaming pipeline, display interim transcripts, and support freeform AI conversation with the pet.
- **Dependencies:** Phase 6.
- **Files / Modules:** `lib/features/translation/`, `lib/features/tutor_chat/`.
- **Expected Deliverables:** Tap mic -> speak Gujarati/Hindi -> see instant English translation -> hear pet speak.
- **Acceptance Criteria:** Audio plays automatically; pet performs `gesture-positive` (talk) animation during speech.
- **Testing Requirements:** Verification across all 6 core language pairs; error toast on network drop.

---

## Phase 8: Voice Playback & Pronunciation Practice
- **Objectives:** Implement Slow Playback (0.7x pitch-preserving), and "Repeat-After-Me" pronunciation evaluation using Gnani Prisma confidence scores.
- **Dependencies:** Phase 7.
- **Files / Modules:** `lib/features/practice/pronunciation_coach.dart`.
- **Expected Deliverables:** User taps "Repeat", speaks translated sentence, and sees matched words in green (`.ok`) or mispronounced words in red wavy underline (`.miss`). Pet dances on 100% score!
- **Acceptance Criteria:** Accuracy score matches phonetic reality; pet animations transition seamlessly (`dance` or `gesture-negative`).
- **Testing Requirements:** Phonetic alignment algorithm unit tests; scoring boundary tests.

---

## Phase 9: User Profile, Learning History & Progress Tracking
- **Objectives:** Implement local Drift SQLite database for instant offline history access, cloud sync to Supabase, streak counter, and vocabulary flashcard review.
- **Dependencies:** Phase 2, Phase 7.
- **Files / Modules:** `lib/features/history/`, `lib/features/profile/`, `lib/data/local/drift_database.dart`.
- **Expected Deliverables:** Interactive history tab with audio replay, daily streak flame counter, and vocabulary mastery stats.
- **Acceptance Criteria:** Offline translations persist locally and sync to Supabase upon reconnect.
- **Testing Requirements:** SQLite migration and CRUD unit tests; streak rollover calculation tests.

---

## Phase 10: Subscription & In-App Payment Integration
- **Objectives:** Implement Razorpay and Google Play Billing for India subscription tiers (₹9/month, ₹49/year), backend webhook verification, and entitlement gating.
- **Dependencies:** Phase 2, Phase 6.
- **Files / Modules:** `backend/routers/billing.py`, `lib/features/subscription/`.
- **Expected Deliverables:** Paywall sheet showcasing premium characters (`Pano`, `Pip`, `Leo`) and unlimited speech quota; instant activation on successful payment.
- **Acceptance Criteria:** Expired or unpaid users capped at 120s/day; server enforces limits via HTTP 429.
- **Testing Requirements:** Razorpay test sandbox end-to-end payment verification; webhook signature forgery rejection test.

---

## Phase 11: Security Hardening & Performance Optimization
- **Objectives:** Execute static application security testing (SAST), enforce strict Supabase RLS policies, audit Android overlay tapjacking defenses, optimize GLB draw calls, and profile battery usage.
- **Dependencies:** Phases 1–10.
- **Files / Modules:** Entire workspace, `android/`, `backend/`.
- **Expected Deliverables:** Zero high/critical vulnerabilities on Snyk/OWASP scans; CPU usage < 5% during idle overlay mode.
- **Acceptance Criteria:** 60fps stable overlay rendering; memory consumption < 120MB on mid-range Android hardware.
- **Testing Requirements:** Automated penetration tests; battery drain benchmark over 1 hour of background operation.

---

## Phase 12: Production Release & Google Play Store Launch
- **Objectives:** Configure Android app bundle (`.aab`) signing, create Play Store promotional graphics and privacy policy, set up CI/CD GitHub Actions release pipeline, and launch internal testing track.
- **Dependencies:** Phase 11.
- **Files / Modules:** `.github/workflows/`, `fastlane/`, Google Play Console listing.
- **Expected Deliverables:** Signed production `.aab` submitted to Google Play Closed Testing track.
- **Acceptance Criteria:** Google Play automated pre-launch report passes with 0 crashes or accessibility blocks.

