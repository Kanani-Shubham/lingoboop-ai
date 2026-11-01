# LingoBoom — Technical Architecture Specification

**Product:** LingoBoom  
**Author:** Senior Systems Architect & Engineering Team  
**Status:** Approved for Phase 0 Baseline

---

## 1. System Architecture Overview

```
                                      +------------------------------------+
                                      |         Android OS Surface         |
                                      +------------------------------------+
                                                        |
                     +----------------------------------+----------------------------------+
                     |                                                                     |
                     v                                                                     v
       +----------------------------+                                        +----------------------------+
       |   Flutter Main App         |                                        |  Native Kotlin Overlay     |
       |  - Onboarding & Auth       |                                        |  - WindowManager View      |
       |  - 3D Character Showcase   |                                        |  - Foreground Service      |
       |  - Profile & Settings      | <==== Platform Channels (Method/Event) =====>  - Transparent 3D Pet     |
       |  - Progress & Streaks      |                                        |  - Floating LingoCard      |
       |  - Subscriptions & Billing |                                        |  - Drag & Touch Physics    |
       +----------------------------+                                        +----------------------------+
                     |                                                                     |
                     +----------------------------------+----------------------------------+
                                                        |
                                                        v
                                      +------------------------------------+
                                      |     Local Cache & Security         |
                                      |  - Drift SQLite (History/Cache)    |
                                      |  - KeyStore Encrypted Storage      |
                                      +------------------------------------+
                                                        |
                                    HTTPS REST / Realtime WebSockets
                                                        |
                                                        v
                                      +------------------------------------+
                                      |    LingoBoom FastAPI Backend       |
                                      |  - Request Authentication          |
                                      |  - Rate Limiting & Quota Metering  |
                                      |  - Streaming Audio WebSocket Proxy |
                                      |  - Subscription Entitlement Engine |
                                      +------------------------------------+
                                         /              |               \
                                        /               |                \
                                       v                v                 v
            +------------------------------+  +-------------------+  +-----------------------+
            |        Gnani AI Suite        |  |  Supabase Cloud   |  |   Payment Gateway     |
            |  - Prisma v3.0 (STT Stream)  |  |  - PostgreSQL DB  |  |  - Razorpay / Play    |
            |  - Timbre (Neural TTS)       |  |  - Supabase Auth  |  |    Billing API        |
            |  - Evon (Tutor LLM / Trans)  |  |  - RLS Policies   |  |  - Subscriptions      |
            +------------------------------+  +-------------------+  +-----------------------+
```

---

## 2. Technology Stack Evaluation & Decisions

| Layer / Capability | Technology Selection | Evaluation & Compatibility Notes |
|---|---|---|
| **Mobile Client** | **Flutter 3.47+ & Dart 3.13+** | Cross-platform UI, excellent 60/120fps rendering, unified codebase for main app screens. |
| **Android Overlay** | **Kotlin + WindowManager** | Standalone Android Foreground Service with `TYPE_APPLICATION_OVERLAY`. Allows the character to float over external apps even when the Flutter activity is backgrounded. |
| **Backend API** | **Python 3.11+ / FastAPI** | High-throughput asynchronous endpoints, native WebSocket streaming for real-time audio chunks, low latency. |
| **Database** | **Supabase PostgreSQL** | Enterprise-grade relational DB, automated UUID auth linking, built-in Row Level Security (RLS), real-time tables. |
| **Authentication** | **Supabase Auth** | Native OAuth providers (Google), magic link, secure JWT session management with refresh token rotation. |
| **Local Storage** | **Drift (SQLite) + FlutterSecureStorage** | Type-safe SQL persistence for offline learning history; hardware-backed KeyStore encryption for tokens. |
| **Speech-to-Text** | **Gnani Prisma v3.0** | Optimized for Indian English and 12+ Indic languages (Hindi, Gujarati, Tamil, Telugu, etc.) with real-time streaming chunks. |
| **Text-to-Speech** | **Gnani Timbre** | High-fidelity neural TTS with authentic regional accents and word-level timing markers. |
| **Reasoning / Tutor** | **Gnani Evon** | Domain-optimized conversational LLM tailored for contextual language pedagogy and error explanation. |
| **State Management** | **Flutter Riverpod** | Compile-safe, test-friendly dependency injection with fine-grained reactivity. |
| **Navigation** | **GoRouter** | Declarative URL-style routing with onboarding redirect guards and deep link support. |
| **Analytics & Telemetry**| **PostHog** | Product event telemetry, conversion funnels, and retention cohort tracking. |
| **Error Monitoring** | **Sentry** | Full-stack crash diagnostics, native Android NDK crash capture, and ANR reporting. |
| **DevOps / CI/CD** | **GitHub Actions + Docker** | Automated linting, test suites, Dockerized backend deployment, and Fastlane Android APK builds. |

---

## 3. Communication Protocol Architecture

### 3.1. Real-time Audio & Translation Streaming (WebSocket)
- **Path:** `wss://api.lingoboom.com/ws/live-audio`
- **Protocol:** Binary PCM 16kHz 16-bit mono chunks sent in 250ms frames from client.
- **Server Action:**
  1. Authenticates JWT in handshake query param.
  2. Checks remaining user speech quota.
  3. Pipes PCM frames to **Gnani Prisma v3.0** streaming gRPC/REST interface.
  4. Yields intermediate transcripts back to client (`event: "transcript.interim"`).
  5. On end of utterance, triggers **Gnani Evon** translation and **Gnani Timbre** TTS synthesis.
  6. Emits synthesized audio URL + word boundary timestamp array (`event: "karaoke.ready"`).

### 3.2. REST Endpoints (FastAPI)
- `POST /api/v1/auth/sync` — Syncs authenticated user profile with Supabase.
- `GET /api/v1/user/entitlements` — Fetches current subscription status and remaining daily speech allowance.
- `POST /api/v1/tutor/chat` — Conversational dialogue practice with selected pet.
- `POST /api/v1/practice/score` — Phonetic comparison and pronunciation scoring.
- `POST /api/v1/billing/create-subscription` — Initiates Razorpay payment order (₹9/mo, ₹49/yr).
- `POST /api/v1/billing/webhook` — Verifies Razorpay webhook signature and updates user entitlements.

