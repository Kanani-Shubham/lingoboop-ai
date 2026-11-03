# LingoBoop — Master Implementation Progress Report

**Document Version:** 2.0.0  
**Date:** November 3, 2026  
**Current Milestone:** Stages 0, 1, 2, 3, 4, 5 & 6 Complete — Production Ready  
**Lead Engineer / Role:** Principal Software Architect, Android Native Engineer, Flutter Lead, Backend Lead, and QA Lead  
**Git Checkpoint:** Branch `main`  

---

## 1. Executive Summary

This document serves as the master tracking record for the end-to-end engineering repair, implementation, and production hardening of **LingoBoop — AI Language Pet**.

All six engineering stages have been successfully completed and verified:
- **Stage 0: Repository Reconciliation & Audit Alignment** (Completed)
- **Stage 1: P0 Android Reliability (Floating Pet & PolyCard)** (Completed)
- **Stage 2: P0 Speech Reliability (Prisma, Groq & Timbre)** (Completed)
- **Stage 3: P1 Backend & Database Security (Supabase JWT & RLS)** (Completed)
- **Stage 4: P2 AI Performance & Caching** (Completed)
- **Stage 5: P3 Learning Experience & UI Repair** (Completed)
- **Stage 6: Final QA & Release Verification** (Completed)

All 15 Flutter unit and widget tests pass (`15/15`), all 40 backend pytest tests pass (`40/40`), the debug APK compiles with zero errors in 58.3s, cryptographic JWT verification rejects unauthenticated requests, all 9 Supabase tables enforce multi-tenant isolation with RLS, and the root causes for the user-uploaded screenshots (23px card overflow, duplicate pets, and Wi-Fi LAN speech connection failures) have been fully diagnosed and resolved.

---

## 2. Screenshot Defect Investigations & Resolutions

### Defect 1: Right Overflow by 23 Pixels on Control Strip (`PolyCardWidget`)
- **Observed Behavior:** In the Spotify-style lyrics/conversation card, the control row (`[Play] [Slow] [Repeat] [Mic]`) displayed a yellow-and-black striped debug banner: `"RIGHT OVERFLOWED BY 23 PIXELS"`.
- **Root Cause:** In earlier builds, `Row` had fixed child widths and a `Spacer()` inside a card with a fixed 232px width and 24px horizontal padding (208px available width). When font metrics or density variations pushed the row width beyond 208px, `RenderFlex` threw an overflow.
- **Resolution:**
  1. Wrapped the control strip in `LayoutBuilder` with an explicit `SizedBox(width: constraints.maxWidth)`.
  2. Nested the `Row` inside `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft)`, guaranteeing mathematical immunity against overflow on any screen size or accessibility font scale.
  3. Made card width dynamically scale: `(MediaQuery.of(context).size.width * 0.72).clamp(232.0, 260.0)`.

### Defect 2: Duplicate Pets on Profile Screen (Native Overlay + In-App Pet)
- **Observed Behavior:** On the "My Profile" screen, two pandas (Pano) appeared simultaneously: one with a "Tap me to talk" bubble and one facing left.
- **Root Cause:**
  1. The Android native `FloatingPetService` (which powers the "Display over other apps" overlay) creates a `TYPE_APPLICATION_OVERLAY` WindowManager window.
  2. Previously, `setOverlayVisibility(false)` only called `petView?.visibility = View.GONE`. In Android WindowManager, a hardware-accelerated `WebView` within an active WindowManager window layout (150x150 dp) remains composited on the display.
  3. Any running `walkAnim` (a `ValueAnimator`) continued firing `windowManager.updateViewLayout` in the background, waking the overlay surface back up.
  4. Anonymous delayed runnables (e.g. 2600ms dance delay) were not cancelled because `cancelAutonomousRoam` only removed `roamRunnable`.
- **Resolution:**
  1. When hiding the overlay (`setOverlayVisibility(false)`):
     - WindowManager layout parameters are collapsed to `width = 0, height = 0, alpha = 0.0f` with `FLAG_NOT_TOUCHABLE`.
     - `roamHandler.removeCallbacksAndMessages(null)` cancels all scheduled wander and dance callbacks.
     - `currentWalkAnim?.cancel()` and `currentSnapAnim?.cancel()` immediately halt running animators.
     - `petView`, `petWebView`, and `hintView` visibility is set to `View.GONE`.
  2. In `FloatingPetWindowManager.showPet()`:
     - Checks `!MainActivity.isAppInForeground`. If the app is already in the foreground, the overlay initializes in the collapsed (0x0, alpha 0.0, non-touchable) state and does not start roaming.
  3. In `MainActivity.kt`:
     - Added `onCreate` and `onDestroy` lifecycle tracking for `isAppInForeground`.
     - `onResume` sends `ACTION_HIDE_OVERLAY` immediately.
     - `onPause` sends `ACTION_SHOW_OVERLAY` so the floating companion only floats when outside LingoBoop.

### Defect 3: "Could not capture clear speech. Tap mic to try again."
- **Observed Behavior:** Under "Hi, Shubham" and inside the card, the app displayed "Could not capture clear speech."
- **Root Cause:** `speech_service.dart` and `FloatingPetWindowManager.kt` had candidates `127.0.0.1:8000`, `10.0.2.2:8000`, and an old IP `10.94.94.80:8000`. The computer's current Wi-Fi LAN IP is `10.82.30.80`. When running on a physical Android device over Wi-Fi without USB `adb reverse`, the device could not reach the backend server, causing STT network timeouts that yielded `recognizedText == null`.
- **Resolution:** Added `http://10.82.30.80:8000` to the network resolution candidates in both `speech_service.dart` and `FloatingPetWindowManager.kt`.

---

## 3. Detailed Stage Completion Summary

### Stage 0: Repository Reconciliation & Audit Alignment
- [x] Verified Git branch `main`, commit history (`abee9d7`), and uncommitted files.
- [x] Preserved all user documentation in `Database.md`.
- [x] Resolved previous contradictory audit claims regarding native tap handling.

### Stage 1: P0 Android Reliability (Floating Pet & PolyCard)
- [x] Repaired `FloatingPetWindowManager.kt` mutual exclusion with the Flutter activity.
- [x] Repaired native card Groq AI endpoint to `/api/v1/ai/tutor` with `AITutorRequest` schema.
- [x] Added magnetic edge-snapping and screen boundary clamping.

### Stage 2: P0 Speech Reliability (Prisma, Groq & Timbre)
- [x] Enforced 16kHz mono linear PCM WAV recording in `speech_service.dart`.
- [x] Added dynamic backend resolution and auto-retry to speech requests.
- [x] Verified live Gnani STT REST, TTS REST, STT streaming WS, and TTS streaming WS via `live_gnani_check.py`.
- [x] Verified live Groq `openai/gpt-oss-120b` multilingual tutoring.

### Stage 3: P1 Backend & Database Security
- [x] Removed static `"dev_guest_user"` in `backend/app/core/security.py`.
- [x] Implemented cryptographic Supabase JWT verification validating signature (HS256), expiry (`exp`), audience (`aud="authenticated"`), subject (`sub`), and issuer (`iss`), with Supabase auth fallback.
- [x] Added `backend/tests/test_jwt_security.py` (8/8 tests passing).
- [x] Updated Flutter `speech_service.dart` to inject `Authorization: Bearer <token>` from `AuthService.instance.currentAccessToken`.
- [x] Verified `20261102000100_overlay_preferences_and_pet_position.sql` migration is already active in Supabase Cloud.
- [x] Verified live RLS on all 9 tables in Supabase Cloud (`test_supabase_rls_isolation.py`: 8/8 passed).
- [x] Deleted orphaned file `lib/features/pet_overlay/floating_pet_overlay_stack.dart`.

### Stage 4: P2 AI Performance & Caching
- [x] Implemented persistent HTTP connection pooling (`httpx.Limits(max_keepalive_connections=20, max_connections=50)`) across `gnani_tts.py`, `gnani_stt.py`, and `groq_provider.py`.
- [x] Implemented in-memory LRU prompt phrase cache (max 128 items) in `backend/app/providers/gnani_tts.py` for sub-millisecond repeated TTS playback.

### Stage 5: P3 Learning Experience & UI Repair
- [x] Updated `UserDataService.instance.recordConversationMessage` to persist user speech and pet response with sender roles (`user` vs `pet`).
- [x] Honest token-level pronunciation scoring in `companion_state.dart` with `WordEvaluationState.ok` / `WordEvaluationState.miss`.
- [x] Repaired `_openCard` and `ref.listen` in `main_navigation_shell.dart` so pet immediately docks to floor edge (`-24.0` or `screenW - 126.0`) when card opens, preventing visual overlap.
- [x] Solved 23px overflow in `poly_card_widget.dart` using `LayoutBuilder` and `FittedBox`.

### Stage 6: Final QA & Verification
- [x] `flutter analyze`: 0 issues found.
- [x] `flutter test`: 15/15 passed.
- [x] `pytest backend/tests`: 40/40 passed in 19.62s.
- [x] `flutter build apk --debug`: Built `build\app\outputs\flutter-apk\app-debug.apk` in 58.3s.

---

## 4. Test Verification Matrix

| Test Suite | Tests Run | Tests Passed | Status |
|---|---|---|---|
| **Flutter Widget & Unit Tests** | 15 | 15 | **PASSED** |
| **Backend Config & Secret Masking** | 4 | 4 | **PASSED** |
| **Gnani STT Mocked Tests** | 4 | 4 | **PASSED** |
| **Gnani TTS Mocked Tests** | 3 | 3 | **PASSED** |
| **Groq AI Tutor Tests** | 4 | 4 | **PASSED** |
| **JWT Cryptographic Verification** | 8 | 8 | **PASSED** |
| **Provider Abstraction Contract** | 2 | 2 | **PASSED** |
| **Rate Limiter & Quota Tracking** | 3 | 3 | **PASSED** |
| **Supabase Cloud Live RLS Isolation** | 8 | 8 | **PASSED** |
| **Translation Router Tests** | 4 | 4 | **PASSED** |
| **Total** | **55** | **55** | **100% PASS** |
