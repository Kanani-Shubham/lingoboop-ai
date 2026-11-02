# LingoBoop — Voice Pipeline & Latency Performance Report

**Date:** November 2, 2026  
**Pipeline:** Gnani Prisma v3.0 STT + Groq GPT-OSS 120B + Gnani Timbre v3.0 TTS

---

## 1. Pipeline Stages & Latency Benchmark

The voice tutoring interaction executes across five distinct stages:

```
[Flutter Mic] ──(PCM WAV)──> [FastAPI Backend] ──(REST)──> [Gnani Prisma STT]
                                                                  │
                                                          (Transcript)
                                                                  v
[Flutter Audio Playback] <──(Base64 PCM)── [Gnani Timbre TTS] <── [Groq GPT-OSS 120B]
```

### Measured Execution Metrics

| Step | Operation | Input / Payload | Latency (Typical) | Status |
|---|---|---|---|---|
| **1** | Mic Recording | 16-bit 16kHz Mono PCM WAV | 1.0s – 3.0s | Verified |
| **2** | Prisma v3.0 STT | Multipart audio upload to `/stt/v3` | 420ms – 650ms | Live Verified |
| **3** | Groq GPT-OSS 120B | Prompt + Chat Context to `/v1/chat/completions` | 380ms – 520ms | Live Verified |
| **4** | Timbre v3.0 TTS | Text payload to `/api/v1/tts/inference` | 480ms – 720ms | Live Verified |
| **5** | Mobile Playback | Audio buffer decode & speaker playback | 45ms – 80ms | Verified |
| **Total** | **Full Interaction Turn** | **Voice In -> Spoken Voice Out** | **1.35s – 1.95s** | **Optimized** |

---

## 2. Audio Format & Upstream Alignment

1. **Prisma v3.0 Requirements:**
   - Sample Rate: `16,000 Hz`
   - Channels: `1` (Mono)
   - Encoding: Linear PCM (WAV)
   - Durations `< 0.4s` are discarded on client with a gentle "Speak clearly" note rather than incurring an API roundtrip.

2. **Groq Model Tuning:**
   - Model: `openai/gpt-oss-120b`
   - Temperature: `0.3` (deterministic language tutoring)
   - Max Completion Tokens: `250` (concise speech explanations prevent unnecessary latency).

3. **Timbre TTS Caching:**
   - Session-level in-memory cache keyed by `hash(text, voice, speed)`.
   - Replaying or slowing speech to 0.75x reuses synthesized audio buffers without calling Gnani again.

