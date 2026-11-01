# LingoBoom — AI Architecture & Gnani Integration Specification

**AI Suite Provider:** Gnani.ai  
**Primary Engine Models:**
1. **Gnani Prisma v3.0** — Real-Time Streaming Speech-to-Text (STT)
2. **Gnani Timbre** — High-Fidelity Neural Text-to-Speech (TTS)
3. **Gnani Evon** — Contextual Language Tutor & Translation Reasoning (LLM)

---

## 1. End-to-End Processing Pipeline

```
[User Speaks into Phone Mic]
             |
             v  (16 kHz, 16-bit PCM Linear Mono)
[Android Record / Flutter Audio Engine]
             |
             v  (WebSocket 250ms chunks)
[LingoBoom FastAPI Backend Gateway]
             |
             +---> 1. Stream to Gnani Prisma v3.0 (STT)
             |        |
             |        +--- Emit interim transcripts ("Tamne kem chhe...")
             |        +--- Emit final transcript with confidence
             |
             +---> 2. Query Gnani Evon (Translation & Pedagogical Context)
             |        |
             |        +--- Source: Gujarati ("તમને કેમ છે?")
             |        +--- Target: English ("How are you?")
             |        +--- Grammar breakdown + pronunciation tip
             |
             +---> 3. Synthesize via Gnani Timbre (TTS)
                      |
                      +--- High-res neural audio stream
                      +--- Word boundary timestamps:
                           [ {word: "How", start: 0, end: 180},
                             {word: "are", start: 185, end: 320},
                             {word: "you", start: 325, end: 540} ]
                      |
             v
[LingoBoom Client Player & Spotify-style LingoCard]
  - Pet plays `gesture-positive` (talk)
  - Synced words highlight dynamically (`.on`)
```

---

## 2. Model Specifications & Integration Interfaces

### 2.1. Gnani Prisma v3.0 (Speech-to-Text)
- **Supported Languages:** English (Indian accent), Hindi, Gujarati, Tamil, Telugu, Kannada, Bengali, Marathi, and Hinglish.
- **Protocol:** Streaming bidirectional gRPC / WebSocket over TLS.
- **Audio Specification:**
  - Sample Rate: `16,000 Hz` (16 kHz)
  - Bit Depth: `16-bit signed integer (Linear PCM)`
  - Channels: `1` (Mono)
  - Encoding: Raw PCM or Opus encapsulated
- **Key Capabilities:**
  - Punctuation restoration and true-casing.
  - Indian mixed-language code-switching (e.g. Gujarati-English / Hindi-English).
  - Word-level confidence scores used directly for pronunciation grading.

### 2.2. Gnani Timbre (Text-to-Speech)
- **Supported Voices:** Regional native speaker accents with natural inflection and child/companion friendly voice personas.
- **Output Formats:** MP3, WAV, or streaming chunks.
- **Critical Requirement:** **Word Boundary Markers (`alignment_metadata`)**
  - Timbre returns JSON metadata detailing start and end milliseconds for each generated word.
  - The Flutter client uses these timestamps to drive the Spotify-style synced lyrics UI with millisecond accuracy, avoiding jitter.

### 2.3. Gnani Evon (Language Tutor LLM)
- **Role:**
  1. High-accuracy contextual translation that preserves colloquial idioms.
  2. Language tutor reasoning: explaining why a phrase is constructed a certain way.
  3. Interactive conversation mode: allowing the user to converse with Maru, Mimi, or Leo.
- **Prompt Isolation Architecture:**
  - Requests are enveloped in fixed system instructions on the FastAPI backend:
    ```json
    {
      "system_prompt": "You are LingoBoom Companion '{character_name}', a warm and encouraging language tutor. You help speakers of {native_lang} master {target_lang}. Keep explanations short (under 2 sentences). Always provide the translation, romanized pronunciation if applicable, and an encouraging remark.",
      "temperature": 0.3
    }
    ```

---

## 3. Resilience, Latency & Fallback Strategy

| Layer | Failure Scenario | Fallback Mechanism |
|---|---|---|
| **STT Stream** | Gnani Prisma temporary connection timeout (> 1.5s) | Fallback to buffered REST STT or on-device Android SpeechRecognizer |
| **TTS Stream** | Gnani Timbre synthesis delayed | Fallback to device-native Text-to-Speech engine (`flutter_tts`) |
| **Translation** | Gnani Evon unreachable | Fallback to cached translation dictionary or secondary translation API |
| **Network Loss** | Complete device offline | Cache spoken sentences in local Drift SQLite; display offline badge |

