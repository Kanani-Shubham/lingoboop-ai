# LingoBoop — Gnani Timbre TTS Integration Report

## 1. Executive Summary

This report documents the root-cause diagnosis, architectural repair, and end-to-end verification of Text-to-Speech (TTS) synthesis and playback across all surfaces in LingoBoop (in-app PolyCard, settings audio previews, and the native Android floating WindowManager overlay).

---

## 2. Root Cause Analysis

During QA on a physical Android 14 device, translated text appeared correctly inside the PolyCard, but pressing the **Play**, **Slow**, or **Repeat** buttons either resulted in silence or produced a playback error (`Loading interrupted`).

### Root Causes Identified:

1. **Missing Container Format in Upstream Gnani API:**
   - Gnani Timbre v3.0 (`https://api.vachana.ai/api/v1/tts/inference`) returns raw 16-bit 16kHz mono linear PCM byte buffers without a RIFF/WAVE header container.
   - Android's native `MediaPlayer` and Flutter's `just_audio` player require valid media containers with RIFF headers specifying sample rate, channels, bit depth, and data chunk lengths.

2. **Playback Interruption in just_audio:**
   - Stream timeouts and concurrent play calls caused `Loading interrupted` exceptions when attempting to stream audio while previous playback resources were still transitioning.

3. **Overlay Voice Character Parameter Omission:**
   - The native Kotlin `FloatingPetWindowManager` sent TTS synthesis payloads to `/api/v1/tts/synthesize` without specifying the user-selected voice character (`voice`), causing the backend to default to a single voice regardless of user preference.

---

## 3. Implemented Fixes & Audio Pipeline Architecture

### A. Raw PCM to RIFF/WAVE Container Packaging
Both the FastAPI backend provider (`backend/app/providers/gnani_tts.py`) and Flutter client (`lib/core/services/speech_service.dart`) now validate the returned audio buffer. If raw linear PCM is detected (missing `RIFF` magic bytes), a 44-byte canonical WAV header is synthesized and prepended:

```python
def _wrap_pcm_as_wav(pcm_bytes: bytes, sample_rate: int = 16000, num_channels: int = 1, bits_per_sample: int = 16) -> bytes:
    if pcm_bytes.startswith(b"RIFF"):
        return pcm_bytes
    riff_size = 36 + len(pcm_bytes)
    # Header format: RIFF <riff_size> WAVE fmt  <16> <1=PCM> <channels> <rate> <byterate> <align> <bits> data <data_size>
```

In addition, an optional 120ms silent lead-in is prepended to eliminate initial DAC click/pop artifacts on physical mobile speakers.

### B. Reliable Audio Playback Engine
In `SpeechService.playAudioFile`:
- Existing playback is cleanly halted (`await player.stop()`).
- File path is set and cached locally (`await player.setFilePath(filePath)`).
- Playback rate is adjusted (`await player.setSpeed(speed)` — support for 1.0x normal and 0.75x Slow).
- Audio starts immediately with proper exception handling.

### C. Live Backend Connection & LRU Cache
- The backend utilizes an asynchronous `httpx.AsyncClient` with connection pooling (`max_keepalive_connections=20, max_connections=50`).
- An in-memory LRU cache stores up to 128 synthesized phrases for sub-millisecond repeated playback (essential for repetition and slow practice).

---

## 4. Verified Gnani Timbre v3.0 Voices

All 13 voices below were queried and verified live against the Gnani Timbre API (`POST https://api.vachana.ai/api/v1/tts/inference`):

| Voice Name | Gender | Voice Quality & Tone | Model | Supported Languages | Status |
|---|---|---|---|---|---|
| **Shivani** | Female | Natural, warm, expressive (Default) | timbre-v3.0 | hi-IN, en-IN, gu-IN, mr-IN, ta-IN, te-IN, kn-IN, bn-IN | **Verified (HTTP 200)** |
| **Chetana** | Female | Bright, articulate, cheerful | timbre-v3.0 | hi-IN, en-IN, gu-IN, mr-IN, ta-IN, te-IN, kn-IN, bn-IN | **Verified (HTTP 200)** |
| **Kalpana** | Female | Soothing, gentle, melodic | timbre-v3.0 | hi-IN, en-IN, gu-IN, mr-IN, ta-IN, te-IN, kn-IN, bn-IN | **Verified (HTTP 200)** |
| **Lakshmi** | Female | Clear, classic, professional | timbre-v3.0 | hi-IN, en-IN, gu-IN, mr-IN, ta-IN, te-IN, kn-IN, bn-IN | **Verified (HTTP 200)** |
| **Riyaa** | Female | Lively, playful, enthusiastic | timbre-v3.0 | hi-IN, en-IN, gu-IN, mr-IN, ta-IN, te-IN, kn-IN, bn-IN | **Verified (HTTP 200)** |
| **Tarika** | Female | Crisp, modern, pleasant | timbre-v3.0 | hi-IN, en-IN, gu-IN, mr-IN, ta-IN, te-IN, kn-IN, bn-IN | **Verified (HTTP 200)** |
| **Vasudha** | Female | Rich, melodic, comforting | timbre-v3.0 | hi-IN, en-IN, gu-IN, mr-IN, ta-IN, te-IN, kn-IN, bn-IN | **Verified (HTTP 200)** |
| **Avinash** | Male | Warm, friendly, confident | timbre-v3.0 | hi-IN, en-IN, gu-IN, mr-IN, ta-IN, te-IN, kn-IN, bn-IN | **Verified (HTTP 200)** |
| **Devansh** | Male | Youthful, energetic, bright | timbre-v3.0 | hi-IN, en-IN, gu-IN, mr-IN, ta-IN, te-IN, kn-IN, bn-IN | **Verified (HTTP 200)** |
| **Prakash** | Male | Clear, mature, reassuring | timbre-v3.0 | hi-IN, en-IN, gu-IN, mr-IN, ta-IN, te-IN, kn-IN, bn-IN | **Verified (HTTP 200)** |
| **Shubham** | Male | Natural, casual, conversational | timbre-v3.0 | hi-IN, en-IN, gu-IN, mr-IN, ta-IN, te-IN, kn-IN, bn-IN | **Verified (HTTP 200)** |
| **Yashraj** | Male | Expressive, dynamic | timbre-v3.0 | hi-IN, en-IN, gu-IN, mr-IN, ta-IN, te-IN, kn-IN, bn-IN | **Verified (HTTP 200)** |
| **Harshad** | Male | Deep, authoritative, calm | timbre-v3.0 | hi-IN, en-IN, gu-IN, mr-IN, ta-IN, te-IN, kn-IN, bn-IN | **Verified (HTTP 200)** |

---

## 5. Security & Secret Protection

- No Gnani or AI API keys are stored in client code, Git, or Android assets.
- All credentials remain strictly encapsulated within the FastAPI backend environment (`backend/.env`).
- Client requests communicate via local reverse proxy (`http://127.0.0.1:8000`) or Android loopback (`http://10.0.2.2:8000`).
