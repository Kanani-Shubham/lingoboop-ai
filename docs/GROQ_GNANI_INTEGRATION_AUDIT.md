# LingoBoom — Groq GPT-OSS 120B & Gnani AI VoiceOS Integration Audit

**Date:** 2026-11-01  
**Project:** LingoBoom — AI Multilingual Floating Language Learning Companion  
**Objective:** Upgrade LingoBoom to a production-oriented AI language-learning application integrating **Gnani AI Prisma v3.0** (STT), **Groq `openai/gpt-oss-120b`** (AI Intelligence & Tutoring), and **Gnani AI Timbre** (TTS).

---

## 1. Existing Architecture

```
[ Flutter Mobile App (Android 14) ]
   ├── Presentation: Riverpod StateNotifier (`CompanionNotifier`), GoRouter Navigation Guards
   ├── Character System: 6 PolyPets (Maru, Mimi, Bun, Pano, Pip, Leo) via Three.js WebGL (1.95MB total)
   ├── Native Overlay: Android WindowManager floating service with edge-snapping physics
   └── Core Services:
         ├── `SpeechService`: Audio recording via `record: ^7.1.2`, playback via `just_audio: ^0.10.6`
         ├── `UserDataService`: Supabase client integration for progress, messages, and preferences
         ├── `OverlayService`: MethodChannel & EventChannel (`com.lingoboop.app/overlay_events`)
         └── `AuthService`: Supabase authentication with session persistence
              │
              ▼ HTTPS / REST
[ FastAPI Backend Gateway (port 8000) ]
   ├── Security & Entitlements: Supabase JWT validation, IP/User Sliding Rate Limiter
   ├── STT Gateway: `POST /api/v1/stt/transcribe` -> Gnani Prisma v3.0 REST
   ├── TTS Gateway: `POST /api/v1/tts/synthesize` -> Gnani Timbre REST
   ├── Translation: `POST /api/v1/translation/translate` -> Conversational phrase engine + NMT
   └── Database: AsyncPG direct pool to Supabase PostgreSQL with RLS policies enabled
              │
              ▼ External APIs
   ├── [ Gnani AI VoiceOS ]: `https://api.vachana.ai` (`X-API-Key-ID` header)
   ├── [ Groq Cloud API ]: `https://api.groq.com/openai/v1` (to be integrated)
   └── [ Supabase Cloud ]: Auth, RLS Isolated PostgreSQL DB, Realtime
```

---

## 2. Existing Working Features

1. **Authentication & Authorization:**
   - WelcomeScreen routes "Get Started" to `/signup` and "I already have an account" to `/login`.
   - Passwords enforce an 8-character minimum on signup.
   - Unauthenticated routes (`/home`, `/profile`, `/progress`, `/achievements`, `/pets`) are guarded and redirect to `/login`.
   - 14/14 Flutter tests passing.

2. **3D Pet Rendering:**
   - Real Three.js WebGL rendering loaded inside a single hardware-accelerated root WebView.
   - Bounding box centering and unculled geometry (`o.frustumCulled = false`) fixes model clipping.
   - Recursion bug in `pet_viewer.html` resolved (`applyMode` isolation).
   - Instant pet character switching without stale assets or layout glitches.

3. **Android Native Companion Overlay:**
   - Draggable floating window over external apps with boundary clamping.
   - Smooth horizontal edge snapping (`ValueAnimator` with `DecelerateInterpolator` to screen margins).
   - `com.lingoboop.app/overlay_events` `EventChannel` for pet interactions.
   - Compliant with Android 14 FGS requirements (`FOREGROUND_SERVICE_SPECIAL_USE` & `FOREGROUND_SERVICE_MICROPHONE`).

4. **Speech-to-Text (Gnani Prisma v3.0):**
   - Live API connectivity to `https://api.vachana.ai/stt/v3` verified with active credentials.
   - Flutter mic recording (`16kHz 16-bit mono WAV`) sent as multipart payload to FastAPI.

5. **Text-to-Speech (Gnani Timbre):**
   - Live API connectivity to `https://api.vachana.ai/api/v1/tts/inference` verified.
   - Returns WAV audio bytes decoded and played via `just_audio` in Flutter.

6. **Database & RLS Isolation:**
   - All 9 core tables (`profiles`, `user_preferences`, `user_languages`, `conversations`, `messages`, `learning_progress`, `achievements`, `usage_records`, `subscriptions`) exist with Row Level Security enabled.
   - 27/27 backend tests passing including cross-tenant database isolation.

---

## 3. Gaps & Broken / Missing Features

1. **Groq AI Intelligence Missing:**
   - The backend currently routes translation through a local phrase dictionary/token fallback.
   - There is no central AI tutor brain that handles multi-turn conversation, grammar explanation, error correction, natural alternative phrasing, and proficiency-adaptive tutoring.
   - The application needs Groq `openai/gpt-oss-120b` integrated as the primary AI intelligence provider.

2. **Structured AI Response Pipeline Missing:**
   - The conversational card only displays source and translated text.
   - It lacks structured feedback: grammar explanation, corrected sentence diff, alternative examples, native-language word breakdown, and interactive follow-up prompts.

3. **Conversation State Management & Context Limits:**
   - Conversation history is not dynamically threaded into multi-turn LLM context.
   - Need a bounded context window (last 6-8 messages) to ensure low latency and avoid token budget overflow on Groq.

4. **Audio Playback Synchronization in LingoCard:**
   - Karaoke highlighting currently uses an estimated timer rather than tracking actual playback position or word-level timings from the AI pipeline.

---

## 4. Existing vs Required API Integrations

| Capability | Component | Status | Target Provider / Model |
|---|---|---|---|
| Speech-to-Text | Gnani STT | Working (Verified) | Gnani Prisma v3.0 (`/stt/v3`) |
| AI Tutoring & Reasoning | Groq LLM | **To Implement** | Groq `openai/gpt-oss-120b` (`/chat/completions`) |
| Bidirectional Translation | AI Service | Partially working (Local) | Groq `openai/gpt-oss-120b` + Phrase Cache |
| Grammar Correction & Explanations | AI Service | **To Implement** | Groq `openai/gpt-oss-120b` structured output |
| Text-to-Speech | Gnani TTS | Working (Verified) | Gnani Timbre (`/api/v1/tts/inference`) |
| Data Persistence & RLS | Supabase | Working (Verified) | Supabase PostgreSQL + Auth RLS |

---

## 5. Security Analysis

- **API Key Security:** Gnani and Groq keys must exist strictly in `backend/.env`. No client code in Flutter or Kotlin has direct access.
- **Traceback Leaks:** FastAPI exception handlers in `backend/app/main.py` sanitize upstream provider errors so no authorization headers or stack traces are transmitted to clients.
- **Microphone Permissions:** Flutter audio capture is only triggered by explicit user tap; audio recordings are stored in temporary cache and not retained without consent.
- **RLS Isolation:** User data in `conversations`, `messages`, and `learning_progress` is enforced through Supabase auth policies (`auth.uid() = user_id`).

---

## 6. Implementation Plan

- **Step 1:** Update `backend/app/core/config.py`, `.env.example`, and `backend/.env.example` with Groq configuration (`GROQ_API_KEY`, `GROQ_MODEL=openai/gpt-oss-120b`, `GROQ_BASE_URL`).
- **Step 2:** Build the Groq AI provider architecture under `backend/app/ai/`:
  - `backend/app/ai/schemas/ai_schemas.py`: Pydantic models for translation, tutoring, grammar correction, and conversation.
  - `backend/app/ai/providers/base_provider.py` & `groq_provider.py`: Official Groq REST API client with streaming/json_object mode.
  - `backend/app/ai/services/ai_service.py`: Central orchestrator uniting Groq, persona prompting (based on active pet), and prompt engineering.
  - `backend/app/routers/ai.py`: REST routes (`/api/v1/ai/tutor`, `/api/v1/ai/translate`, `/api/v1/ai/correct`, `/api/v1/ai/exercise`).
- **Step 3:** Connect Flutter `SpeechService` and `companion_state.dart` to the full Groq + Gnani pipeline:
  `Mic Capture -> Prisma STT -> Groq AI Tutor -> Timbre TTS -> Pet Speaks + Lyrics`.
- **Step 4:** Enhance the LingoCard UI to render rich AI feedback (Grammar hints, Corrections, Alternatives, Next Steps).
- **Step 5:** Run full test suite (`pytest`, `flutter analyze`, `flutter test`, `flutter build apk`) and verify on physical Android device.

