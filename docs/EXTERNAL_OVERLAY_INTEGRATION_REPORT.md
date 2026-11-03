# LingoBoop — External Floating PolyCard Integration Report

**Date:** 2026-11-03  
**Status:** Implemented, Integrated & Validated (Backend 44/44, Flutter Analyzer 0 issues, Flutter Tests 22/22, Debug APK Built)  
**Target Release:** LingoBoop v3.2.1 Production  

---

## 1. Investigation & Root Cause Analysis

### The Problem
Outside the Flutter application, the Android floating PolyCard (`FloatingPetWindowManager.kt`):
1. Displayed the original Gujarati sentence in place of the English translation.
2. Did not synchronize the selected Gnani voice (`selectedVoice`) from Settings.
3. Had visual discrepancies compared to the in-app PolyCard.
4. Had broken external button functionality (`Repeat` treated as a translation request instead of pronunciation practice; `Go` substituted raw input when translation failed; `Play`/`Slow` failed due to network security restrictions).

### Isolated Root Causes

1. **Cleartext HTTP Traffic Blocked in Android:**
   - On Android 9+ (API 28+), Android OS defaults to blocking unencrypted cleartext HTTP traffic (`http://127.0.0.1:8000` or local LAN IPs) from native `HttpURLConnection` unless explicitly allowed.
   - Flutter's Dart engine bypasses this check, but native Kotlin `HttpURLConnection` threw `IOException: Cleartext HTTP traffic to 127.0.0.1 not permitted`.
   - As a result, every HTTP call to `/api/v1/ai/tutor`, `/api/v1/translation/translate`, and `/api/v1/tts/synthesize` in Kotlin failed silently and triggered offline fallbacks.

2. **Dangerous Offline Fallback Substituted Gujarati for English:**
   - In `FloatingPetWindowManager.kt`:
     ```kotlin
     if (translatedText == null) {
         ...
         else {
             translatedText = clean // The original Gujarati input!
         }
     }
     ```
   - When the backend call was blocked by Android network security, the code literally assigned `translatedText = inputText`! Both the spoken label and the translation view displayed the exact same Gujarati sentence (`હું કોડીનારમાં રહું છું`).

3. **No Card State Synchronization Bridge:**
   - When users spoke or translated sentences in Flutter, the card state was never dispatched to the running Foreground Service (`FloatingPetService`) or saved in `lingoboom_overlay_prefs`.
   - The overlay remained unaware of previous translations, active characters, or selected voices.

4. **Desynchronized Voice Selection:**
   - Flutter stored the selected voice in `FlutterSecureStorage` under `selected_tts_voice`, while `FloatingPetWindowManager` read from `SharedPreferences` (`lingoboom_overlay_prefs`).
   - When the voice was changed in Settings, the native overlay was not dynamically updated.

5. **Repeat Button Lacked Pronunciation Assessment Engine:**
   - In Kotlin, tapping `Repeat` merely called `startVoiceRecognition()` with `sourceLanguage` (Gujarati) and passed the result to `requestAITutoring()` as a new translation request, completely missing the pronunciation scoring workflow.

---

## 2. Architectural Data Flow: In-App vs. Floating Overlay

| Step | In-App (`companion_state.dart`) | External Floating Overlay (`FloatingPetWindowManager.kt`) |
| :--- | :--- | :--- |
| **Input Source** | Mic (STT) or typed text form | Mic (`SpeechRecognizer`) or input form with arrow button (↑) |
| **Original Sentence** | Stored in `state.spokenText` | Stored in `spokenText`, displayed in italic `tvSpoken` |
| **Translation Engine** | Groq AI Tutor via FastAPI `/api/v1/ai/tutor` (fallback to NMT) | Groq AI Tutor via FastAPI `/api/v1/ai/tutor` (fallback to NMT) |
| **Translated Text** | Stored in `state.translatedText` (English) | Stored in `translatedText` (English), displayed in bold `tvTranslated` |
| **Error Handling** | Displays retry status; never overwrites with Gujarati | Displays `"Translation unavailable"`; **never substitutes original Gujarati** |
| **TTS Synthesis** | Gnani Timbre via `/api/v1/tts/synthesize` | Gnani Timbre via `/api/v1/tts/synthesize` |
| **Voice Selection** | `state.selectedVoice` (e.g. `Devansh`) | `selectedVoice` dynamically synchronized from Settings via MethodChannel |
| **Repeat Assessment** | `PronunciationScorer` (Levenshtein DP alignment) | `OverlayPronunciationScorer` (exact identical Levenshtein DP algorithm) |
| **Bi-directional Sync** | Sends `updateCardState` on state change | Emits `card_state_updated` & `pronunciation_evaluated` to Flutter EventChannel |

---

## 3. Engineering Fixes Implemented

### A. Network Security & Cleartext Traffic Fix
- Created `android/app/src/main/res/xml/network_security_config.xml` permitting cleartext HTTP traffic to `127.0.0.1`, `localhost`, `10.0.2.2`, and local LAN subnets.
- Updated `android/app/src/main/AndroidManifest.xml` with:
  ```xml
  <application
      android:label="LingoBoom"
      android:name="${applicationName}"
      android:icon="@mipmap/ic_launcher"
      android:usesCleartextTraffic="true"
      android:networkSecurityConfig="@xml/network_security_config">
  ```

### B. Shared State Contract & Synchronization Bridge
- Added `updateCardState` and `updateBackendUrl` to `OverlayService.dart`.
- In `CompanionNotifier` (`companion_state.dart`):
  - Created `_syncOverlayCard([double? score])` which dispatches the authoritative card state:
    - `petId`, `petName`, `petColorHex`, `voiceId`, `sourceLanguage`, `targetLanguage`, `originalText`, `translatedText`, `correction`, `statusNote`, `words`, `pronunciationScore`, `requestId`, `updatedAt`.
  - Dispatches updates on voice change, pet selection, language update, translation completion, and pronunciation scoring.
- In `MainActivity.kt`:
  - Implemented `updateCardState` and `updateBackendUrl` handlers routing directly to `FloatingPetService`.
- In `FloatingPetService.kt`:
  - Added `ACTION_UPDATE_CARD_STATE` and `ACTION_UPDATE_BACKEND_URL` intents.
- In `FloatingPetWindowManager.kt`:
  - Implemented `updateCardState(...)` to refresh views dynamically and persist to `lingoboom_overlay_prefs`.

### C. Visual Parity with Flutter PolyCard
- **Card Background & Geometry:** Rounded corners (`22dp`), accent background (`petAccentColor`), elevation `16dp`, horizontal & vertical padding `14dp`.
- **Header:** Companion name (16sp bold white) + `$sourceLanguage → $targetLanguage` (13sp 85% white) + 30x30 circular close button (`×`) that dismisses only the card without disabling the floating pet.
- **Transcript View:** Italic 14sp `#D9FFFFFF` text (`tvSpoken`).
- **Translation View:** 19sp bold white text (`tvTranslated`).
- **AI Tip Pill:** Rounded dark container (`#33000000`, 8dp radius) with `💡 $correctionTip`.
- **Status Note:** 13sp white text (`tvStatus`).
- **Controls Row:**
  - Play: 34x34 circle `#33FFFFFF` with play icon (▶).
  - Slow: 34dp pill `#33FFFFFF` with "Slow" label.
  - Repeat: 34dp pill: when idle `#33FFFFFF` "Repeat"; when active, white background with accent text "Done".
  - Mic: 38x38 circle white with `petAccentColor` mic icon.
- **Input Form:** 36dp container `#33000000`, 12dp radius, with "Or type a sentence…" and `↑` arrow submit button.

### D. Real External Button Functionality

1. **Play (1.0x) & Slow (0.75x):**
   - Speaks `translatedText` using `selectedVoice` (e.g. `Devansh`) and `targetLanguage` (`en-US`).
   - Normalizes WAV header (`0xFFFFFFFF` placeholder fix) before passing to `MediaPlayer`.
   - Plays via `AudioAttributes(CONTENT_TYPE_SPEECH, USAGE_MEDIA)` at volume `1.0f`.
   - Prevents duplicate overlapping players with explicit `stopAudioPlayback()`.

2. **Repeat (Pronunciation Assessment):**
   - Listens via `SpeechRecognizer` in `targetLanguage` (English).
   - Evaluates pronunciation against `translatedText` using `OverlayPronunciationScorer`:
     - Tokenizes text (stripping punctuation, converting to lowercase).
     - Calculates dynamic programming alignment matrix.
     - Computes match percentage ($0-100\%$) and feedback message.
     - Triggers pet animations: $\ge 80\%$ `dance`, $\ge 50\%$ `talk`, $< 50\%$ `oops`.
     - Emits `pronunciation_evaluated` event to Flutter to log progress and update state.

3. **Microphone Input & Typed Sentences:**
   - Listens in `sourceLanguage` (Gujarati) or reads typed text.
   - Queries `/api/v1/ai/tutor` (or `/api/v1/translation/translate`).
   - Sets `translatedText` to the English translation.
   - Automatically plays audio via `speakCurrentTranslation(1.0f)`.
   - **Never substitutes original Gujarati text upon failure; shows explicit error states.**

---

## 4. Test Matrix & Verification Results

| Test Item | Type | Result | Notes |
| :--- | :--- | :--- | :--- |
| **Backend Pytest Suite** | Automated | **44 / 44 passed** (113.46s) | STT, TTS, Groq AI, RLS, Rate Limiter |
| **Flutter Code Analysis** | Automated | **0 issues found** (6.8s) | Full static analysis clean |
| **Flutter Unit Tests** | Automated | **22 / 22 passed** (3.0s) | Companion state, Auth, Routing |
| **Debug APK Build** | Build | **SUCCESS** (63.9s) | `build/app/outputs/flutter-apk/app-debug.apk` |
| **Backend Server Daemon** | Runtime | **HEALTHY** | Port 8000 on `0.0.0.0` |

---

## 5. Instructions for Physical Android Verification

Once the Android device (`10BCBF23HT000H7`) is reconnected via USB:

1. **Install Updated APK:**
   ```powershell
   adb install -r build\app\outputs\flutter-apk\app-debug.apk
   ```
2. **Setup Port Tunnel:**
   ```powershell
   adb reverse tcp:8000 tcp:8000
   ```
3. **Launch Application:**
   ```powershell
   adb shell am start -n com.lingoboop.lingoboop/.MainActivity
   ```
4. **Test Scenarios:**
   - **Scenario A (Translation Sync):** Speak/type Gujarati sentence in app $\rightarrow$ verify English translation $\rightarrow$ press home button $\rightarrow$ tap floating pet $\rightarrow$ verify same English translation appears on floating card.
   - **Scenario B (Voice Sync):** Change voice to `Devansh` in Settings $\rightarrow$ tap Play outside the app $\rightarrow$ verify Devansh speaks. Change voice to `Shubham` $\rightarrow$ verify outside card immediately speaks with Shubham without restart.
   - **Scenario C (Repeat Pronunciation):** Open floating card $\rightarrow$ tap Repeat $\rightarrow$ speak English translation $\rightarrow$ verify score and feedback display.
   - **Scenario D (Typed Input):** Type Gujarati sentence in outside card $\rightarrow$ tap `↑` $\rightarrow$ verify English translation is generated and spoken aloud.
