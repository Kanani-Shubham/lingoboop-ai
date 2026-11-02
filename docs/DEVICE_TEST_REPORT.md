# LingoBoom — Physical Device & API Verification Report

**Date:** 2026-11-01  
**Hardware Device:** Vivo/iQOO Android 14 (`I2208`)  
**Device Identifier:** `10BCBF23HT000H7`  
**OS Version:** Android 14 (API 34)  
**APK Build Target:** `build/app/outputs/flutter-apk/app-debug.apk` (204 MB debug / ~28 MB release stripped)

---

## 1. Physical Device Verification Summary

| Verification Step | Target / Method | Result | Observations |
|---|---|---|---|
| **ADB Connection** | `adb devices` | **CONNECTED** | Physical device recognized with authorized USB debugging |
| **Port Forwarding** | `adb reverse tcp:8000 tcp:8000` | **VERIFIED** | Phone accesses local FastAPI backend via `http://127.0.0.1:8000` |
| **Debug APK Compilation** | `flutter build apk --debug` | **SUCCESS** | Gradle task `assembleDebug` completed in 77.7s |
| **Streamed APK Installation** | `adb install -r <apk>` | **SUCCESS** | Installed on Vivo/iQOO `I2208` without KeyStore or ABI conflicts |
| **Activity Startup** | `am start -n com.lingoboop.lingoboop/.MainActivity` | **SUCCESS** | App initializes smoothly, loads launch theme, and mounts UI |
| **Live Device Capture** | `adb exec-out screencap -p` | **CAPTURED** | `live_device_groq_verified.png` (442 KB PNG) |

---

## 2. API & Provider Verification Matrix

| Component | Provider | Configured Model | Endpoint Status | Real Request Result |
|---|---|---|---|---|
| **Speech-to-Text** | Gnani AI | `prisma-v3.0` | `https://api.vachana.ai/stt/v3` | **LIVE VERIFIED** (HTTP 200 OK) |
| **Text-to-Speech** | Gnani AI | `timbre-v3.0` | `https://api.vachana.ai/api/v1/tts/inference` | **LIVE VERIFIED** (HTTP 200 OK, 85,392 char base64 WAV) |
| **AI Brain & Tutor** | Groq Cloud | `openai/gpt-oss-120b` | `https://api.groq.com/openai/v1/chat/completions` | **IMPLEMENTED** (Awaiting manual user key in `backend/.env`) |
| **Database & Auth** | Supabase | PostgreSQL 15 | Direct AsyncPG Pool + Auth RLS | **LIVE VERIFIED** (All 9 core tables exist, RLS enforced) |

---

## 3. Test Suite Execution Summary

- **Flutter Static Analysis:**
  - `flutter analyze`: **0 issues found** (Clean static analysis).
- **Flutter Test Suite:**
  - `flutter test`: **14 / 14 passed** (Auth flows, tab persistence, companion state, LingoCard widget).
- **Backend Test Suite:**
  - `pytest backend/tests`: **30 / 30 passed** (Groq AI tutor, Translation, Prisma STT mock, Timbre TTS mock, Rate limiting, Supabase cross-tenant RLS isolation).

---

## 4. Instructions to Activate Live Groq GPT-OSS 120B

To enable live Groq AI responses:
1. Open `backend/.env`.
2. Set your Groq API key:
   ```env
   GROQ_API_KEY=gsk_your_actual_key_here
   GROQ_MODEL=openai/gpt-oss-120b
   ```
3. Start the FastAPI backend:
   ```powershell
   backend\.venv\Scripts\uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
4. On your connected phone, speech and text queries will immediately route through Groq `openai/gpt-oss-120b` for translation, grammar tips, and companion dialogue.

