# LingoBoom — API Integration Reference

This document details the exact endpoints, request formats, response schemas, and authentication schemes for all external and internal APIs powering LingoBoom.

---

## 1. Environment Configuration

All provider credentials live exclusively in `backend/.env`. Never commit this file or expose keys to the client.

```env
# Groq Cloud AI Intelligence
GROQ_API_KEY=gsk_your_groq_api_key_here
GROQ_MODEL=openai/gpt-oss-120b

# Gnani AI Suite (api.vachana.ai)
GNANI_BASE_URL=https://api.vachana.ai
GNANI_API_KEY_ID=your_gnani_api_key_here
GNANI_STT_MODEL=prisma-v3.0
GNANI_TTS_MODEL=timbre-v3.0

# Supabase PostgreSQL
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
DATABASE_URL=postgresql://postgres:...
```

---

## 2. Backend Gateway Endpoints (FastAPI)

### A. AI Intelligence: Tutor Interaction
- **Route:** `POST /api/v1/ai/tutor`
- **Auth:** Client JWT Bearer Token (or guest session in development)
- **Request Body (`AITutorRequest`):**
  ```json
  {
    "user_message": "તમે કેમ છો?",
    "native_language": "gu-IN",
    "target_language": "en-US",
    "proficiency_level": "beginner",
    "character_id": "fox",
    "history": [
      {"role": "user", "content": "નમસ્તે"},
      {"role": "assistant", "content": "Hello! Ready to practice?"}
    ],
    "mode": "tutor"
  }
  ```
- **Response (`APIResponse` wrapping `AITutorResponse`):**
  ```json
  {
    "success": true,
    "data": {
      "source_text": "તમે કેમ છો?",
      "translated_text": "How are you?",
      "detected_language": "gu",
      "target_language": "en",
      "correction": null,
      "explanation": "This is a common polite greeting in Gujarati.",
      "examples": ["How are you doing?", "How have you been?"],
      "reply_text": "I am doing well! What would you like to practice today?",
      "pronunciation_guide": "How are you? (ha-oo ahr yoo)",
      "vocabulary_breakdown": [
        {"word": "How", "meaning": "કેમ", "part_of_speech": "adverb", "example": "How are you?"}
      ],
      "conversation_mode": "learning",
      "provider": "groq",
      "model": "openai/gpt-oss-120b"
    }
  }
  ```

---

### B. Speech-to-Text: Transcribe Audio
- **Route:** `POST /api/v1/stt/transcribe`
- **Content-Type:** `multipart/form-data`
- **Fields:**
  - `audio_file`: Binary WAV / PCM / MP3 file (16kHz 16-bit mono recommended)
  - `language_code`: BCP-47 language tag (e.g. `gu-IN`, `hi-IN`, `en-IN`, `ta-IN`)
  - `model`: `prisma-v3.0`
- **Response (`APIResponse` wrapping `STTResponseData`):**
  ```json
  {
    "success": true,
    "data": {
      "transcript": "તમે કેમ છો",
      "confidence": 0.94,
      "language_code": "gu-IN",
      "model": "prisma-v3.0"
    }
  }
  ```

---

### C. Text-to-Speech: Synthesize Speech
- **Route:** `POST /api/v1/tts/synthesize`
- **Request Body (`TTSRequest`):**
  ```json
  {
    "text": "How are you doing today?",
    "voice": "Shivani",
    "language": "en-IN",
    "speed": 1.0,
    "model": "timbre-v3.0"
  }
  ```
- **Response (`APIResponse` wrapping `TTSResponseMetadata`):**
  ```json
  {
    "success": true,
    "data": {
      "audio_base64": "UklGRi...",
      "content_type": "audio/wav",
      "character_count": 24,
      "voice": "Shivani",
      "model": "timbre-v3.0",
      "language": "en-IN"
    }
  }
  ```

---

### D. Grammar Correction
- **Route:** `POST /api/v1/ai/correct`
- **Request Body (`GrammarCorrectionRequest`):**
  ```json
  {
    "sentence": "She go to school everyday.",
    "native_language": "gu-IN",
    "target_language": "en-US",
    "character_id": "cat"
  }
  ```
- **Response (`APIResponse` wrapping `GrammarCorrectionResponse`):**
  ```json
  {
    "success": true,
    "data": {
      "original_sentence": "She go to school everyday.",
      "corrected_sentence": "She goes to school every day.",
      "is_correct": false,
      "explanation": "Third-person singular subjects ('she') require the verb to end in '-es' ('goes'). Also, 'every day' is two words when describing frequency.",
      "improved_alternatives": [
        "She attends school every day.",
        "She goes to class daily."
      ]
    }
  }
  ```

