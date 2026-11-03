# LingoBoop — Master Text-to-Speech (TTS) Integration Report

**Date:** 2026-11-03  
**Status:** Complete & Verified on Physical Device (`10BCBF23HT000H7`, Android 14)  
**Release Target:** LingoBoop v3.2.0 Production

---

## 1. Executive Summary & Root Cause Analysis

During end-to-end device testing with live Gujarati, Hindi, and English voice interactions, three distinct failure modes were discovered and systematically eliminated:

1. **Gnani Timbre API PCM Wrapper:**
   - **Root Cause:** Gnani Timbre (`timbre-v3.0`) returns raw 16-bit 16kHz mono linear PCM byte stream without a 44-byte RIFF/WAVE header container. The Flutter audio engine (`just_audio` / ExoPlayer) rejected the raw bytes with `Loading interrupted`.
   - **Resolution:** Implemented `_wrap_pcm_as_wav()` in `backend/app/providers/gnani_tts.py` and client-side in `lib/core/services/speech_service.dart`. Injected 120ms of silence prefix padding to protect initial phonemes from mobile DAC hardware warm-up clipping.

2. **Mobile AudioSession State Lock:**
   - **Root Cause:** Following Speech-to-Text recording (`record` package), Android and iOS audio hardware remained configured in `playAndRecord` / microphone-priority mode, preventing `just_audio` from engaging the media playback channel.
   - **Resolution:** Added `audio_session` integration in `SpeechService.playAudioFile()`: explicitly configures `AVAudioSessionCategory.playback` and `AndroidAudioAttributes(usage: AndroidAudioUsage.media, contentType: AndroidAudioContentType.music)` with `setActive(true)` before each playback sequence.

3. **External Floating Overlay Authentication Fallback:**
   - **Root Cause:** In the native Android floating overlay (`FloatingPetWindowManager.kt`), requests were made without an authorization header when running in unauthenticated guest/local testing mode, receiving HTTP 401 and falling back to error states like `"Translation unavailable"`.
   - **Resolution:** Configured `verify_client_token` in `backend/app/core/security.py` and `_buildHeaders()` in Flutter / Android Kotlin to support `Bearer dev_guest_token` in development mode (`APP_ENV=development`), while keeping cryptographic JWT verification strictly enforced in production.

---

## 2. Verified 13 Timbre v3.0 Voice Characters

| Voice Character | Gender | Pitch / Tone | Language Support |
| :--- | :--- | :--- | :--- |
| **Shivani** (Default) | Female | Natural, warm, expressive | en-IN, gu-IN, hi-IN |
| **Chetana** | Female | Bright, articulate, cheerful | en-IN, gu-IN, hi-IN |
| **Kalpana** | Female | Soothing, gentle, melodic | en-IN, gu-IN, hi-IN |
| **Lakshmi** | Female | Clear, classic, professional | en-IN, gu-IN, hi-IN |
| **Riyaa** | Female | Lively, playful, enthusiastic | en-IN, gu-IN, hi-IN |
| **Tarika** | Female | Crisp, modern, pleasant | en-IN, gu-IN, hi-IN |
| **Vasudha** | Female | Calm, authoritative, balanced | en-IN, gu-IN, hi-IN |
| **Amartya** | Male | Deep, confident, articulate | en-IN, gu-IN, hi-IN |
| **Anurag** | Male | Friendly, conversational | en-IN, gu-IN, hi-IN |
| **Aryavarth** | Male | Resonant, classic, clear | en-IN, gu-IN, hi-IN |
| **Chaitanya** | Male | Warm, engaging, youthful | en-IN, gu-IN, hi-IN |
| **Devansh** | Male | Energetic, modern, bright | en-IN, gu-IN, hi-IN |
| **Gautam** | Male | Steady, professional, narrative | en-IN, gu-IN, hi-IN |

---

## 3. End-to-End Verification Matrix

| Surface | Input Method | Pipeline Steps | Observed Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **In-App PolyCard** | Mic (STT) | Gujarati speech → Prisma STT → Groq translation → Timbre TTS | Audio automatically plays; karaoke highlights words | ✅ Pass |
| **In-App PolyCard** | Text Input | Typed Gujarati → Groq translation → Timbre TTS | Audio synthesizes and plays; text updates cleanly | ✅ Pass |
| **In-App PolyCard** | Play ▶ / Slow | Tap Play/Slow on translated card | Replays at 1.0x or 0.75x speed via AudioSession | ✅ Pass |
| **Repeat Practice** | Mic (Audio) | User repeats English sentence → Levenshtein match | Scored 75%-100%, highlighted words, no playback block | ✅ Pass |
| **Settings Screen** | Voice Demo | Tap Demo for any of 13 voices | Synthesizes and plays preview audio smoothly | ✅ Pass |
| **External Overlay** | Mic / Text | Native speech recognition / text submit → Translation | Returns translation and speaks without 401 error | ✅ Pass |

---

## 4. Test Suite Execution Results

- **Backend Pytest:** 44 passed in 29.54s (`pytest backend/tests`)
- **Flutter Analyzer:** 0 issues found (`flutter analyze`)
- **Flutter Widget/Unit Tests:** 22 passed (`flutter test`)
- **Device Build:** `app-debug.apk` built and installed cleanly on Android 14 (`10BCBF23HT000H7`)
