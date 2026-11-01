# LingoBoom — Implementation Gaps: Prototype vs. Production

**Date:** November 2026  
**Scope:** Gap analysis between `polypet-demo.html` visual mockups and production requirements.

---

## 1. Feature-by-Feature Gap Matrix

| # | Product Requirement | Prototype Status | Production Implementation Needed | Severity / Priority |
|---|---|---|---|---|
| **1** | **Login** | ❌ None | Supabase Auth (Email/Password, Google OAuth, Magic Link) | High (P0) |
| **2** | **Signup** | ❌ None | Onboarding user creation, initial language pairing, default character assignment | High (P0) |
| **3** | **Onboarding** | ❌ None | Multi-step interactive flow (target language, daily goal, pet intro, mic permission grant) | High (P0) |
| **4** | **Character Selection** | ⚠️ Basic chip selector | Interactive 3D carousel in Flutter with character stats, lore, free vs. premium badges | High (P0) |
| **5** | **Character Customization**| ❌ None | Custom accessory or color tinting, name customization, personality badges | Medium (P2) |
| **6** | **Language Selection** | ⚠️ Simple HTML dropdowns | Searchable modal selector supporting 12+ Indian and Global languages with flags | High (P0) |
| **7** | **User Profile** | ❌ None | Account management, streak counter, total words spoken, subscription status | Medium (P1) |
| **8** | **Application Settings** | ⚠️ Barebones gear sheet | Audio sensitivity, speed adjustments, notification frequency, theme toggle | Medium (P1) |
| **9** | **Floating Character Overlay**| ⚠️ In-browser absolute `<div>` | Native Android `WindowManager` with `TYPE_APPLICATION_OVERLAY` & Foreground Service | Critical (P0) |
| **10**| **Spotify-style LingoCard**| ⚠️ Web DOM elements | Custom Flutter widget with synced lyrics, dynamic character theming, word touch inspection | Critical (P0) |
| **11**| **Real-time Voice Translation**| ⚠️ Web Speech + MyMemory API | **Gnani Prisma v3.0** STT + **Gnani Evon** translation over streaming WebSocket | Critical (P0) |
| **12**| **Voice Playback** | ⚠️ Web SpeechSynthesis | **Gnani Timbre** high-fidelity neural audio streaming via `audioplayers` | Critical (P0) |
| **13**| **Slow Playback (0.7x)** | ⚠️ Browser rate adjustment | Native audio pitch-preserving tempo reduction (0.7x) in `audioplayers` | High (P1) |
| **14**| **Repeat-After-Me** | ⚠️ Substring string matching | Phonetic comparison, word-level confidence scoring via Gnani Prisma | High (P1) |
| **15**| **Pronunciation Practice** | ⚠️ Naive word highlighting | Detailed phonetic feedback, highlighting mispronounced syllables, retry loop | High (P1) |
| **16**| **AI Pet Conversation** | ❌ None | Contextual dialogue engine powered by **Gnani Evon** tutor persona | High (P1) |
| **17**| **Learning History** | ❌ None | Drift SQLite offline cache + Supabase sync with timestamped cards | Medium (P1) |
| **18**| **Learning Progress** | ❌ None | Vocabulary mastery tracking, SRS (Spaced Repetition System) intervals | Medium (P2) |
| **19**| **Achievements & Streaks** | ❌ None | Gamified streak calculations, daily XP, badge unlock celebrations (pet dances) | Medium (P2) |
| **20**| **Subscription & Payment** | ❌ None | Razorpay / Google Play Billing integration (₹9/mo, ₹49/yr) + backend entitlement checks | High (P0) |

---

## 2. Key Architecture Gaps

1. **Native Overlay Lifecycle:**
   - The prototype only operates within an HTML page.
   - Production requires an independent background Android service that floats over all applications (WhatsApp, YouTube, Instagram) and responds to touch gestures without blocking other apps.
2. **AI Provider Latency & Synchronization:**
   - In the prototype, karaoke timing was estimated using character length heuristic (`(length * 85 + 90)/rate`).
   - Production requires word-level timestamps emitted directly by Gnani Timbre / Prisma for sub-100ms synchronization precision.
3. **Backend Service Layer:**
   - No backend code exists in the workspace yet.
   - A Python FastAPI service must be architected with Supabase integration to proxy Gnani requests, meter rate limits, and enforce subscriptions.

