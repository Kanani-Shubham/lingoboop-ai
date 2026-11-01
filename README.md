# LingoBoom

**Tagline:** Your on-screen AI pet for real-time speech and language learning.  
**First Target Platform:** Android Mobile (Android 8.0+ / API 26+)  
**Architecture:** Flutter + Native Android Kotlin Floating Overlay (`WindowManager`) + Python FastAPI + Supabase PostgreSQL + Gnani AI Suite.

---

## Project Structure Overview

```
lingoboom/
├── android/                         # Android native project (Kotlin 2.4, AGP 9.1, Java 17)
├── ios/                             # iOS native project runner
├── lib/                             # Flutter Dart source code
├── test/                            # Flutter test suite
├── web/                             # Web platform runner
│
├── assets/
│   ├── characters/                  # Production 3D characters
│   │   ├── maru/                    # Fox (Terracotta #c4571c)
│   │   │   ├── models/              # maru.glb (138.6 KB)
│   │   │   ├── animations/          # animations.json manifest (8 clips)
│   │   │   └── previews/            # maru.png preview
│   │   ├── mimi/                    # Cat (Purple #6a4cc4)
│   │   ├── pano/                    # Panda (Teal #2c6e5e)
│   │   ├── bun/                     # Bunny (Magenta #c23d7b)
│   │   ├── pip/                     # Penguin (Royal Blue #2c62c4)
│   │   └── leo/                     # Lion (Ochre Gold #9a6a06)
│   ├── images/
│   ├── icons/
│   ├── audio/
│   └── fonts/
│
├── product_context/                 # Complete product documentation & audit records
│   ├── prototype/
│   │   ├── original/                # Original polypet-demo.html reference
│   │   └── screenshots/             # 9 Reference UI screenshots
│   ├── original_assets/
│   │   ├── source_models/           # Reference to Kenney Cube Pets 24-character package
│   │   ├── source_documentation/    # Kenney documentation & Overview.html
│   │   └── source_zips/
│   ├── requirements/
│   │   └── PRODUCT_REQUIREMENTS.md  # Complete 20-feature PRD & subscription tiers
│   ├── architecture/
│   │   ├── TECHNICAL_ARCHITECTURE.md# System architecture & component mapping
│   │   ├── DATABASE_DESIGN.md       # Supabase PostgreSQL schema, RLS & tables
│   │   ├── AI_ARCHITECTURE.md       # Gnani Prisma (STT), Timbre (TTS) & Evon (LLM)
│   │   └── ANDROID_OVERLAY.md       # Kotlin WindowManager & Foreground Service
│   ├── analysis/
│   │   ├── PROJECT_INVENTORY.md     # Full recursive workspace asset audit
│   │   ├── PROTOTYPE_ANALYSIS.md    # UI breakdown of polypet-demo.html
│   │   ├── CHARACTER_ASSET_AUDIT.md # 3D GLB model specifications & animations
│   │   ├── FLUTTER_AUDIT.md         # Flutter SDK, dependencies & Android health
│   │   ├── SECURITY_AUDIT.md        # Threat modeling, RLS & key protection
│   │   └── IMPLEMENTATION_GAPS.md   # Prototype vs. Production delta matrix
│   ├── licenses/
│   │   └── ASSET_LICENSES.md        # CC0 Public Domain & Open Source licenses
│   └── antigravity/
│       ├── DEVELOPMENT_RULES.md     # Clean architecture & Riverpod standards
│       ├── PHASE_ROADMAP.md         # 13-phase dependency-aware engineering plan
│       └── NEXT_STEPS.md            # Immediate actionable steps for Phase 1
│
├── backend/                         # FastAPI service gateway (Phase 6)
├── supabase/                        # Supabase SQL migrations & config (Phase 2)
├── .env.example                     # Environment variables configuration template
├── .gitignore                       # Production-grade git ignore rules
└── README.md                        # Project root documentation
```

---

## 3D Character Roster

LingoBoom features six production-ready 3D characters created from the CC0 Kenney Cube Pets package. Each character is a low-poly binary GLB model (under 175 KB) containing 8 baked animations (`idle`, `walk`, `run`, `eat`/think, `dance`/cheer, `gesture-positive`/talk, `gesture-negative`/oops, `static`):

1. **Maru** (Fox) — Accent: `#c4571c` (Terracotta) — *Free Tier*
2. **Mimi** (Cat) — Accent: `#6a4cc4` (Purple) — *Free Tier*
3. **Pano** (Panda) — Accent: `#2c6e5e` (Teal Green) — *Premium Tier*
4. **Bun** (Bunny) — Accent: `#c23d7b` (Magenta) — *Free Tier*
5. **Pip** (Penguin) — Accent: `#2c62c4` (Royal Blue) — *Premium Tier*
6. **Leo** (Lion) — Accent: `#9a6a06` (Ochre Gold) — *Premium Tier*

---

## Subscription Pricing (India)

- **Free Tier:** 120 seconds of speech/day; 3 free characters (`Maru`, `Mimi`, `Bun`); standard translation.
- **Monthly Subscription:** **₹9 / month** — 1,800 seconds speech/day; unlocks all 6 characters; Gnani Evon conversational tutor.
- **Yearly Subscription:** **₹49 / year** — Best value annual pass; priority AI quota; pronunciation breakdown.

---

## Security Notice

Never commit API keys, provider tokens, signing keystores, or private environment files to this repository. All provider secrets (Gnani AI credentials, Supabase service-role keys, Razorpay secret keys) must be hosted strictly on the backend service. Refer to `.env.example` and `product_context/analysis/SECURITY_AUDIT.md` for guidelines.
