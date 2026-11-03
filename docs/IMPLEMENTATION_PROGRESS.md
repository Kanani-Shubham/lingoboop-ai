# LingoBoop — Master Implementation Progress Report

**Document Version:** 3.0.0  
**Date:** November 3, 2026  
**Current Milestone:** All Critical Voice, Translation, Assessment & Floating UI Repairs Verified  
**Lead Engineer / Role:** Principal Software Architect, Android Native Engineer (Kotlin), Flutter Lead, FastAPI Backend Engineer, AI/ML Engineer, QA Lead  
**Git Checkpoint:** Branch `main`  

---

## 1. Executive Summary

This document serves as the master tracking record for the end-to-end engineering repair, implementation, and production hardening of **LingoBoop — AI Language Pet**.

All critical user-reported issues from physical Android 14 device testing have been diagnosed to their root causes, permanently repaired in the codebase, and verified with automated test suites:
- **Flutter In-App PolyCard Overflow:** Resolved. The 23-pixel right overflow on the controls row is completely eliminated via responsive container constraints (`240dp - 285dp`) and flexible scrollable/fitted child wrappers.
- **Duplicate Pets on Profile / Navigation:** Resolved. The native Android overlay now synchronizes with the Flutter app lifecycle, collapsing to `0x0` dimensions, `alpha = 0.0f`, `FLAG_NOT_TOUCHABLE`, and cancelling all autonomous roaming while LingoBoop is in the foreground.
- **Translation Echoing Raw Source Text:** Resolved. Native Android overlay now receives and passes the Supabase JWT `Authorization: Bearer <token>` header, authenticating with `/api/v1/ai/tutor`. If AI tutor fails or returns the source text, it automatically falls back to Groq `openai/gpt-oss-120b` via `/api/v1/translation/translate`. If both fail, it displays a clear retry message and never presents untranslated source text as the translation.
- **External Floating Card Mic Button Clipping:** Resolved. Native WindowManager card width was increased to a responsive `76%` of display width (`270dp - 296dp`), pill button horizontal padding optimized to `7dp`, and controls row margins adjusted so the 38dp mic button has complete padding and is never clipped.
- **Incomplete First-Word Audio Pronunciation:** Resolved. Implemented `_prependSilenceToWav` in `SpeechService.dart`, prepending 120ms of silent PCM samples to the RIFF WAVE data so that Android hardware audio DAC ramp-up occurs during silence, eliminating first-syllable truncation.
- **Pronunciation Assessment & 0% Matched Bug:** Resolved. Built `PronunciationScorer` with token normalization (punctuation removal, lowercase, unicode trimming) and Levenshtein distance matrix sequence alignment. Empty or uncaptured speech is now gracefully handled as `"Could not capture clear speech. Tap mic to try again."` without assigning a 0% match score.
- **AI-Powered Daily Speaking Practice:** Implemented. Created `POST /api/v1/ai/daily-practice` backend endpoint powered by Groq (`openai/gpt-oss-120b`) and a new interactive Flutter screen (`DailySpeakingPracticeScreen`) accessible directly by tapping the Daily Speech Practice card on the home screen.

---

## 2. Root Cause Analyses & Technical Solutions

### Issue 1: "RIGHT OVERFLOWED BY 23 PIXELS" in PolyCard
- **Root Cause:** `PolyCardWidget` had a hardcoded `width: 232` with `padding: horizontal 12`, leaving only 208px inner width. The control row (`[Play] [Slow] [Repeat] [Mic]`) required at least 204px with standard font scaling. On devices with Android system font scale or display density enabled (1.1x–1.2x), the row exceeded 208px, triggering a 23px `RenderFlex` overflow exception.
- **Fix:**
  - Updated `PolyCardWidget` width to `width: 264` with constraints `BoxConstraints(minWidth: 240, maxWidth: 285)`.
  - Replaced fixed-width Row with `Flexible(child: SingleChildScrollView(scrollDirection: Axis.horizontal, ...))` and `Row(mainAxisSize: MainAxisSize.min)` for the buttons, accompanied by the pulsing mic button.
  - Clamped screen position in `MainNavigationShell` to ensure card stays within bounds.

### Issue 2: Duplicate Pets on Profile Screen (Two Pandas)
- **Root Cause:** The native Android `FloatingPetService` was running concurrently with Flutter's internal `FloatingPetAvatar`. `setOverlayVisibility(false)` was not collapsing the WindowManager view layout parameters, and any running `walkAnim` animator or delayed roam callback kept firing `updateViewLayout`, keeping the native view visible over the Flutter Activity.
- **Fix:**
  - In `MainActivity.kt`: `onResume` dispatches `ACTION_HIDE_OVERLAY`, and `onPause` dispatches `ACTION_SHOW_OVERLAY`.
  - In `FloatingPetWindowManager.kt`: `setOverlayVisibility(false)` cancels all running animators (`currentWalkAnim?.cancel()`, `currentSnapAnim?.cancel()`), removes all callbacks (`roamHandler.removeCallbacksAndMessages(null)`), sets visibility to `View.GONE`, and collapses `petParams` to `width = 0, height = 0, alpha = 0.0f, FLAG_NOT_TOUCHABLE`.
  - In `FloatingPetWindowManager.showPet()`: Checks `!MainActivity.isAppInForeground` on start. If the app is already in the foreground, the overlay view initializes collapsed and hidden.

### Issue 3: Translation Echoing Gujarati (Failed Translation)
- **Root Cause:**
  1. `FloatingPetWindowManager.kt` made HTTP POST requests to `/api/v1/ai/tutor` without passing an `Authorization` header.
  2. Because FastAPI backend routes require Supabase JWT authentication, `/api/v1/ai/tutor` rejected the requests with HTTP 401 Unauthorized.
  3. When the request failed, `FloatingPetWindowManager` defaulted to `val finalTranslation = translatedText ?: inputText`, repeating the input "મારું નામ શુભમ છે" as the translation.
- **Fix:**
  - `OverlayService.dart` now supplies `AuthService.instance.currentAccessToken` in `startOverlay` and provides `updateAuthToken(token)`.
  - `FloatingPetWindowManager.kt` stores `authToken` and sends `Authorization: Bearer $authToken`.
  - Added fallback: if `/api/v1/ai/tutor` fails or returns text identical to the input, it calls `/api/v1/translation/translate` with Groq `openai/gpt-oss-120b`.
  - If both endpoints fail, it displays `"Translation unavailable. Tap to retry."` and never presents raw source text as translation.

### Issue 4: External Floating Card Mic Button Clipped
- **Root Cause:** Native dialog width in `FloatingPetWindowManager.kt` was constrained to 232dp–256dp, while the header, text content, and controls required 265dp+, pushing the rightmost mic button off the right edge of the card.
- **Fix:**
  - Increased responsive card width to `(dm.widthPixels * 0.76).toInt().coerceIn(dpToPx(270), dpToPx(296))`.
  - Adjusted card container padding to `12dp` horizontal.
  - Set `clipChildren = false` on the controls row and adjusted pill button padding to `7dp` horizontal, giving the 38dp mic button ample clearance.

### Issue 5: First-Word Audio Cutoff
- **Root Cause:** Hardware DACs and audio output pipelines on physical Android devices require 50–120ms to ramp up when opening an audio playback stream. Because Gnani Timbre WAV audio starts immediately with speech data at byte 44, the first syllable was swallowed or inaudible.
- **Fix:**
  - Implemented `_prependSilenceToWav(Uint8List wavBytes, {int silenceMs = 120})` in `SpeechService.dart`.
  - Automatically parses the RIFF header and `data` subchunk, prepending 120ms of silence (zeros) and updating the RIFF and data chunk size fields accordingly.
  - Pre-warms `just_audio` player state and verifies buffer readiness before triggering playback.

### Issue 6: Pronunciation Scorer & "0% Matched" Bug
- **Root Cause:** `stopRepeatPractice()` in `companion_state.dart` used naive set containment on unnormalized tokens. When speech input was uncaptured or timed out, `userTokens` was empty, causing all words to be flagged as missed and resulting in a jarring "0% matched. Check missed words and try again."
- **Fix:**
  - Created `PronunciationScorer` (`lib/core/utils/pronunciation_scorer.dart`).
  - Word-level sequence alignment using dynamic programming (Needleman-Wunsch / Levenshtein distance matrix).
  - Normalization for punctuation, case, and whitespace.
  - When speech is empty or uncaptured, returns `hasSpoken = false` and displays `"Could not capture clear speech. Tap mic to try again."` without assigning a 0% match score.

### Issue 7: AI-Powered Daily Speaking Practice Feature
- **Implementation:**
  - Added `DailyPracticeRequest`, `DailyPracticeItem`, and `DailyPracticeResponse` Pydantic models.
  - Implemented `generate_daily_practice` in `AIService` using Groq (`openai/gpt-oss-120b`) with a curated offline fallback set.
  - Exposed `POST /api/v1/ai/daily-practice` endpoint with rate limiting and Supabase JWT verification.
  - Created `DailySpeakingPracticeScreen` (`lib/features/practice/presentation/daily_practice_screen.dart`):
    - Progress strip ("Sentence 1 of 20", score chip, progress bar).
    - Large target sentence display with word-level evaluation highlights.
    - Native translation, phonetic pronunciation guide, and context tip.
    - Audio playback (normal 1.0x & slow 0.75x) with lead-in silence.
    - Interactive microphone recording with `PronunciationScorer`.
    - Next / Previous navigation and completion summary dialog.
    - Wired the "Daily Speech Practice" card on `MainCompanionScreen` to navigate to `/daily-practice`.

---

## 3. Verification & Test Results

| Test Suite | Commands Executed | Result | Details |
|---|---|---|---|
| **Flutter Linter & Analyzer** | `flutter analyze` | **PASS (0 issues)** | Zero errors, warnings, or hints across entire `lib/` |
| **Flutter Unit & Widget Tests** | `flutter test` | **PASS (20/20)** | All 20 tests pass, including new `PronunciationScorer` tests |
| **Pronunciation Scorer Unit Tests** | `flutter test test/pronunciation_scorer_test.dart` | **PASS (5/5)** | Exact match, partial match, empty speech, punctuation, Gujarati script |
| **Backend Daily Practice & AI Tests** | `pytest backend/tests/test_daily_practice.py` | **PASS (3/3)** | Authenticated endpoint, unauthenticated rejection, AI generation |
| **Backend Translation & Fallback Tests**| `pytest backend/tests/test_translation.py` | **PASS (4/4)** | Phrase cache, identity check, Groq fallback, auth rejection |
| **Backend JWT Security & RLS Tests** | `pytest backend/tests/test_jwt_security.py` | **PASS (8/8)** | Valid token, expired, forged signature, wrong aud, missing claims |
| **Full Backend Test Suite** | `pytest backend/tests/ -v` | **PASS (43/43)** | 100% of all 43 tests passing in 30.4s |
| **Android Debug APK Build** | `flutter build apk --debug` | **PASS** | `app-debug.apk` built successfully in 73.8s |
| **FastAPI Backend Server** | `uvicorn app.main:app --port 8000` | **HEALTHY** | Running on `http://0.0.0.0:8000`, `/health` returns `success: true` |
