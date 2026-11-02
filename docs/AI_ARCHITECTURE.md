# LingoBoom — AI Architecture Specification

**Architecture Version:** 2.0  
**Central AI Intelligence:** Groq Cloud `openai/gpt-oss-120b`  
**Speech-to-Text:** Gnani AI Prisma v3.0  
**Text-to-Speech:** Gnani AI Timbre  
**Backend:** FastAPI 0.115+ (Python 3.12)  
**Database & Auth:** Supabase PostgreSQL with Row Level Security (RLS)

---

## 1. High-Level AI Pipeline Flow

```
                      ┌─────────────────────────────────────────┐
                      │          Flutter Mobile Client          │
                      │  - User speaks in native/target lang    │
                      │  - 16-bit 16kHz Mono WAV captured       │
                      └────────────────────┬────────────────────┘
                                           │
                                           │ 1. Multipart Audio Upload
                                           ▼
                      ┌─────────────────────────────────────────┐
                      │          FastAPI Backend Gateway        │
                      │  - Client JWT token verification        │
                      │  - Sliding window rate limiter          │
                      └────────┬───────────────────────▲────────┘
                               │                       │
         2. Form-data Audio    │                       │ 3. Raw Transcript Text
                               ▼                       │
                      ┌────────────────────────────────┴────────┐
                      │          Gnani Prisma v3.0 STT          │
                      │  - POST https://api.vachana.ai/stt/v3   │
                      │  - Auth: X-API-Key-ID: <GNANI_API_KEY>  │
                      └─────────────────────────────────────────┘
                               │
                               │ 4. Transcript + Conversation History + User Persona
                               ▼
                      ┌─────────────────────────────────────────┐
                      │        Groq Cloud AI Intelligence       │
                      │  - Model: openai/gpt-oss-120b           │
                      │  - Endpoint: /chat/completions          │
                      │  - Strict JSON Output Schema Mode       │
                      │  - Persona adaptation by PolyPet key    │
                      └────────┬────────────────────────────────┘
                               │
                               │ 5. Structured AI Response
                               │    { translated_text, correction, explanation, reply_text }
                               ▼
                      ┌─────────────────────────────────────────┐
                      │          Gnani Timbre TTS               │
                      │  - POST /api/v1/tts/inference           │
                      │  - Text: translated_text / reply_text   │
                      │  - Returns real audio bytes (WAV)       │
                      └────────┬────────────────────────────────┘
                               │
                               │ 6. Real Audio Bytes (Base64) + AI Response JSON
                               ▼
                      ┌─────────────────────────────────────────┐
                      │          Flutter Mobile Client          │
                      │  - Spotify-style synced lyrics view     │
                      │  - Audio playback via just_audio        │
                      │  - Pet reaction animations              │
                      │  - Grammar feedback & alternatives      │
                      └─────────────────────────────────────────┘
```

---

## 2. Groq `openai/gpt-oss-120b` Structured Output Schema

The Groq inference provider is constrained using OpenAI-compatible `response_format={"type": "json_object"}`. The system prompt instructs the model to return strict, well-formed JSON:

```json
{
  "source_text": "તમે કેમ છો?",
  "translated_text": "How are you?",
  "detected_language": "gu",
  "target_language": "en",
  "correction": null,
  "explanation": "This is a polite greeting commonly used in daily conversation.",
  "examples": [
    "How are you doing?",
    "How have you been?"
  ],
  "reply_text": "I am doing great! How can I help with your English practice today?",
  "pronunciation_guide": "How are you? (ha-oo ahr yoo)",
  "vocabulary_breakdown": [
    {
      "word": "How",
      "meaning": "કેમ / કેવી રીતે",
      "part_of_speech": "adverb",
      "example": "How are you?"
    }
  ],
  "conversation_mode": "learning"
}
```

---

## 3. Character Persona Matrix

Each selected PolyPet brings a unique educational personality to the Groq prompt:

| Character Key | Name | Species | Persona Tone | Specialization |
|---|---|---|---|---|
| `fox` | Maru | Fox | Clever, energetic, enthusiastic | Idioms, quick banter, colloquial phrases |
| `cat` | Mimi | Cat | Stylish, sharp-witted, precise | Grammar nuance, formal phrasing |
| `rabbit` | Bun | Bunny | Cheerful, warm, celebratory | Daily greetings, positive reinforcement |
| `panda` | Pano | Panda | Gentle, calm, reassuring | Patient slow practice, beginner reassurance |
| `chick` | Pip | Chick | Inquisitive, peppy, curious | Vocabulary discovery, question asking |
| `lion` | Leo | Lion | Courageous, bold, motivating | Pronunciation confidence, public speaking |

---

## 4. Bounded Context & Token Management

- To maintain response latencies below 800ms and avoid token window exhaustion, conversation history sent to Groq is strictly bounded to the **last 8 turns** (`4 user messages + 4 AI replies`).
- Older messages remain permanently stored in Supabase `messages` for user history review, but are not serialized into the LLM context.
- System prompt and character personas are cached and immutable per conversation turn.

---

## 5. Fallback & Resilience Strategy

1. **Unconfigured Key Fallback:** If `GROQ_API_KEY` is not provided in `backend/.env`, the backend does not crash; it returns a `setup_required` response with clear instructions on setting the key.
2. **Provider Error Fallback:** If Groq encounters rate limiting (`429`) or network timeouts, the system falls back to the regional phrase translation cache, ensuring the user can still practice without an app crash.
3. **Markdown Fence Stripping:** `ai_service._clean_and_parse_json` automatically strips markdown code fences (` ```json ... ``` `) if returned by the LLM.

