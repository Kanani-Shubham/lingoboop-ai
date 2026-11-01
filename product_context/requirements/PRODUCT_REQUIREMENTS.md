# LingoBoom — Comprehensive Product Requirements Document (PRD)

**Product Name:** LingoBoom  
**Tagline:** Your on-screen AI pet for real-time speech and language learning.  
**Target Market:** India & Global Learners (Focus on Indic + English pairs)  
**Initial Platform:** Android Mobile

---

## 1. Product Vision & Goals

LingoBoom transforms everyday smartphone usage into an effortless, contextual language learning experience. By pairing users with a charming, interactive 3D desktop/overlay pet that sits alongside any app, learners can speak, translate, practice pronunciation, and converse with an AI tutor in real time.

---

## 2. Monetization & Subscription Architecture

### 2.1. Subscription Pricing (India Tier)
- **Monthly Subscription:** **₹9 / month**
- **Yearly Subscription:** **₹49 / year**

### 2.2. Tier Matrix & Feature Gating

| Feature / Resource | Free Tier Users | Premium Subscribers (₹9/mo, ₹49/yr) |
|---|---|---|
| **Daily Speech Quota** | 120 seconds / day (2 minutes) | 1,800 seconds / day (30 minutes fair use) |
| **Available Characters** | 3 Free Pets (`Maru` Fox, `Mimi` Cat, `Bun` Bunny) | **All 6 Pets** (Unlocks `Pano`, `Pip`, `Leo`) |
| **Translation Engine** | Standard AI translation | Advanced contextual **Gnani Evon** with cultural nuances |
| **AI Conversation Mode** | 2 turns / day | Unlimited interactive conversational roleplay |
| **Pronunciation Coaching** | Basic word match score | Syllable-level phonetic breakdown & accent grading |
| **Learning History** | Past 20 entries | Unlimited historical search & audio playback |
| **Offline Sync** | Local cache only | Cloud backup & cross-device sync |

*Critical Architecture Requirement:* All quotas and entitlements must be verified and enforced by the FastAPI backend on every request. Client-side state is strictly advisory.

---

## 3. The 20 Core Product Capabilities

1. **Authentication:** Email/Password, Google OAuth, and phone OTP via Supabase Auth.
2. **User Signup & Profile Creation:** Quick onboarding capturing user name, native language, and learning target.
3. **Onboarding Flow:** 4-step wizard introducing the floating pet concept, explaining Android overlay permissions, and microphone setup.
4. **Character Selection:** 3D carousel showcasing Maru, Mimi, Pano, Bun, Pip, and Leo with lore, personality tags, and sample voices.
5. **Character Customization:** Unlocking accessories, custom pet naming, and interaction sound effects.
6. **Language Pair Selection:** Flexible matrix supporting Hindi, Gujarati, Tamil, Telugu, Bengali, Marathi, and English.
7. **User Profile:** Progress dashboard showing total words learned, current streak, active subscription plan, and daily speech quota gauge.
8. **Application Settings:** Speech rate (0.5x to 1.5x), audio input sensitivity, notification schedules, and overlay auto-hide rules.
9. **Floating 3D Companion Overlay:** Native Android `WindowManager` overlay with full touch physics (drag, floor snap, tap to toggle).
10. **LingoCard (Spotify-Style UI):** Docked floating card featuring synchronized lyrics that light up in real time during audio playback.
11. **Real-time Voice Translation:** Streaming speech input via **Gnani Prisma v3.0** with instant target translation.
12. **High-Fidelity Voice Playback:** Native-sounding voice synthesis via **Gnani Timbre**.
13. **Slow Audio Playback (0.7x):** Pitch-preserving slowed audio to help learners analyze distinct phonemes.
14. **Repeat-After-Me Mode:** Prompts the user to speak the translated phrase, listening on the target language model.
15. **Pronunciation Feedback:** Color-coded word evaluation showing matched words in green pills (`.ok`) and mispronounced words with wavy underlines (`.miss`).
16. **AI Pet Conversation:** Interactive dialogue where the pet responds conversationally to the user's spoken questions using **Gnani Evon**.
17. **Learning History:** Timestamped list of translated phrases, with replay and repeat-practice buttons.
18. **Vocabulary & Mastery Progress:** Spaced Repetition System (SRS) tracking word retention and practice intervals.
19. **Streaks & Gamified Achievements:** Daily practice streaks, milestone badges, and celebratory pet dance animations.
20. **Subscription & In-App Purchases:** Razorpay / Google Play Billing integration with instant server-verified entitlement updates.

