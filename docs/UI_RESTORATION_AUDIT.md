# LingoBoom UI Restoration, Quality & Architecture Audit

**Status:** Completed & Ready for Review  
**Date:** November 2026  
**Document Target:** `docs/UI_RESTORATION_AUDIT.md`  
**Purpose:** Comprehensive architectural and visual audit of the LingoBoom Flutter mobile application against the prototype specification (`product_context/prototype/original/polypet-demo.html`) and user feedback prior to making code deletions or restructuring.

---

## 1. Executive Summary & Root Cause Analysis

Following real-device and emulator APK testing, multiple discrepancies were discovered between the intended LingoBoom language-learning mobile experience and the initial implementation:

### 1.1 The "Notes" Backdrop Misunderstanding
- **Root Cause:** In the reference prototype (`product_context/prototype/original/polypet-demo.html`), the author placed the floating 3D companion over an iPhone-like frame containing simulated "Notes" (Groceries, Train to Surat, Call Dad) solely to demonstrate the companion floating *on top of a third-party host application*.
- **Defect in Flutter:** The Flutter implementation replicated this demo backdrop as the primary application screen (`MainCompanionScreen`), showing a dummy "Notes" list instead of an authentic language learning experience.
- **Remediation:** Remove the fake Notes feed entirely. Transform the main screen into the core **LingoBoom Companion Learning Stage**, featuring active conversation topics, speech prompts, interactive quick-phrases, dynamic audio visualizers, and the floating pet companion.

### 1.2 Character Blurriness & Rendering Degradation
- **Root Cause:** In `lib/core/widgets/floating_pet_avatar.dart`, the pet avatar was rendered using `Image.asset(widget.character.previewAsset)`.
- **Finding:** Files under `assets/characters/*/previews/*.png` are tiny raster thumbnails (~1.5 KB to 2.4 KB, ~128x128px). When rendered at 140x140 or larger on modern high-DPI smartphone displays (xxhdpi/xxxhdpi), bilinear scaling causes severe pixelation and blurring.
- **Original Assets Available:** Full high-fidelity Kenney low-poly 3D models (`.glb` files, ~130–170 KB) and animation specifications (`animations.json`) already reside in `assets/characters/<pet>/models/`.
- **Remediation:** Upgrade character rendering to support high-fidelity 3D rendering (or high-resolution supersampled assets with physics-driven matrix transforms) matching the Three.js GLTFLoader experience in the HTML prototype.

### 1.3 Layout & Viewport Collisions
- **Fake Status Bar:** `MainCompanionScreen` contained hardcoded `9:41` and `5G 82%` text inside `SafeArea`, creating a jarring double status bar when running on Android.
- **Docking Collisions:** The floating `LingoCardWidget`, `PetSettingsSheet`, and bottom navigation bar (`PolyPetBottomNav`) lacked coordinated z-index layering and boundary constraints, causing floating cards to clip through bottom navigation buttons.
- **Remediation:** Remove all fake status bar widgets, apply native edge-to-edge `SafeArea`, clamp pet drag coordinates cleanly above the navigation bar and below the top app bar, and modalize settings/dialogs.

---

## 2. File-by-File Inventory & Disposition

| File Path | Current Role | Disposition | Issues Identified / Required Changes |
| :--- | :--- | :--- | :--- |
| `lib/features/home/presentation/main_companion_screen.dart` | Main screen container | **REDESIGN** | Purge dummy Notes feed, fake `9:41` status bar, groceries/train list. Replace with authentic LingoBoom language learning stage and speech practice hub. |
| `lib/core/widgets/floating_pet_avatar.dart` | Floating pet widget | **UPGRADE** | Replace low-res 1.9 KB raster PNG thumbnails with sharp, high-fidelity rendering pipeline. Enhance idle/talk/listen/cheer animation physics. |
| `lib/features/companion/presentation/lingo_card_widget.dart` | Floating dialog card | **RETAIN & REFINE** | Faithful to HTML `#cd`. Refine docking positioning, expand text input responsiveness, verify karaoke word sync. |
| `lib/features/companion/presentation/companion_state.dart` | Riverpod companion state | **RETAIN & EXTEND** | Clean state machine for speech recognition, TTS playback, karaoke highlight, and pet modes (`idle`, `talk`, `listen`, `dance`, `cheer`, `oops`). |
| `lib/core/widgets/polypet_card.dart` | Note card widget | **REMOVE / PURGE** | Was used solely for the dummy notes list (`Groceries`, `Train to Surat`). Not needed in the core language learning experience. |
| `lib/core/widgets/polypet_bottom_nav.dart` | 4-tab bottom navigation | **RETAIN & REFINE** | Matches prototype palette and pill design. Ensure navigation routes correspond to the 10 PRD screens. |
| `lib/features/settings/presentation/pet_settings_sheet.dart` | Slide-down settings sheet | **RETAIN & REFINE** | Implements `#sh` from prototype (source/target languages and pet switch). Ensure clean dismissal and backdrop barrier. |
| `lib/features/progress/presentation/progress_screen.dart` | Learning progress screen | **CLEANUP** | Purge hardcoded dummy words ("Rice", "Ghee", "Train to Surat"). Connect to real vocabulary and mastery metrics. |
| `lib/features/history/presentation/history_screen.dart` | Conversation history | **CLEANUP** | Purge hardcoded dummy conversations ("Train to Surat", "Call Dad"). Use real conversation entries. |
| `lib/features/welcome/presentation/welcome_screen.dart` | Entry welcome screen | **RETAIN & POLISH** | Clean welcome hero screen; update character asset to high-res. |
| `lib/features/auth/login_screen.dart` | User login | **RETAIN (Core 1)** | Core PRD Screen 1. Ensure styling matches Fredoka typography and palette. |
| `lib/features/auth/signup_screen.dart` | User registration | **RETAIN (Core 1)** | Core PRD Screen 1. Form validation and Supabase auth connection. |
| `lib/features/onboarding/language_select_screen.dart` | Language selection | **RETAIN (Core 2)** | Core PRD Screen 2. Source and learning language setup with Indic script support. |
| `lib/features/onboarding/goal_setup_screen.dart` | Daily goal setup | **RETAIN (Core 2)** | Core PRD Screen 2. Daily practice goal setting (5, 10, 15, 20 mins). |
| `lib/features/character/presentation/pet_select_screen.dart` | Pet selection screen | **RETAIN (Core 4)** | Core PRD Screen 4. Grid/carousel of 6 pets (Maru, Mimi, Bun, Pano, Pip, Leo). |
| `lib/features/achievements/presentation/achievements_screen.dart` | Gamification achievements | **RETAIN (Core 6)** | Core PRD Screen 6. Badges, streaks, milestone unlocks. |
| `lib/features/profile/presentation/profile_screen.dart` | User profile & stats | **RETAIN (Core 7)** | Core PRD Screen 7. User statistics, learning stats, account details. |
| `lib/features/settings/presentation/settings_screen.dart` | Full settings | **RETAIN (Core 8)** | Core PRD Screen 8. Audio speeds, offline voices, account controls. |
| `lib/features/subscription/presentation/subscription_screen.dart` | Premium upgrade | **RETAIN (Core 10)**| Core PRD Screen 10. Free tier vs Pro/Premium tier comparison and unlock. |

---

## 3. Dummy Content Inventory to Purge

The following fabricated or demo-specific strings and components will be eradicated from the production application:

```
[DEMO PURGE LIST]
1. Simulated status bar header: "9:41" and "5G 82%" in main_companion_screen.dart:49-61
2. Top "Notes" header and gear icon in main_companion_screen.dart:73-98
3. Dummy Note Cards:
   - "Groceries" ("Rice, ghee, mangoes, two lemons")
   - "Train to Surat" ("Saturday, 7:40 am, platform 3")
   - "Call Dad" ("About Sunday lunch")
   - "Practice" ("Say it out loud, even if it sounds wrong")
4. Dummy vocabulary items in progress_screen.dart:33-60:
   - "ચોખા (Chokhā)" / "Rice"
   - "ઘી (Ghī)" / "Clarified butter (Ghee)"
   - "સુરતની ટ્રેન (Suratnī ṭrēna)" / "Train to Surat"
   - "બપોરનું ભોજન (Bapōranũ bhōjana)" / "Lunch"
5. Dummy conversation history entries in history_screen.dart:24-48:
   - "સુરત જવાની ટ્રેન ક્યારે છે?" / "The train to Surat leaves at platform three."
   - "પપ્પાને ફોન કરજો." / "Let us call Dad about Sunday lunch."
   - "ચોખા, ઘી અને કેરી ખરીદવી છે." / "Buy rice, ghee, mangoes, and two lemons."
6. Component PolyPetCard (lib/core/widgets/polypet_card.dart) - retire or repurpose for language cards only.
```

---

## 4. Character Quality & 3D Asset Resolution

### 4.1 Root Cause Diagnosis
- The raster previews in `assets/characters/<pet>/previews/<pet>.png` are 128x128 pixel thumbnails intended for small 24px list icons.
- Loading these into a 140x140 interactive viewport with device pixel ratio 2.75–3.5 produces visible pixelation and jagged edges.

### 4.2 Two-Stage Rendering Strategy
1. **Interactive High-Fidelity Vector/Multi-Scale Render Pipeline:**
   - Implement crisp, high-resolution rendering with anti-aliasing and depth shadows.
   - Retain full physical animation simulation:
     - `idle`: Smooth sine-wave vertical floating + subtle scale breathing.
     - `listen`: 0.16 rad head tilt matching prototype.
     - `talk`: Rhythmic vertical compression/expansion synced with audio amplitude.
     - `dance`/`cheer`: Energetic wobble and bounce on correct pronunciation.
     - `drag`: Squash-and-stretch follow-through physics.
2. **Native 3D Model Integration (`assets/characters/*/models/*.glb`):**
   - Provide clean integration hooks for 3D model rendering (using `model_viewer_plus` or embedded Three.js WebGL canvas matching `polypet-demo.html:87-89`).
   - The Kenney Cube Pets (`maru.glb`, `mimi.glb`, `bun.glb`, `pano.glb`, `pip.glb`, `leo.glb`) will display at native device resolution with correct ambient lighting and character-specific accent lighting (`--acc`).

---

## 5. Main Screen Architecture: The LingoBoom Companion Stage

Instead of the demo Notes screen, `MainCompanionScreen` will be structured as the **LingoBoom Speech & Conversation Hub**:

```
+-------------------------------------------------------+
|  [Language: Gujarati -> English]       [Pet Settings]  |  <- Top Language & Companion Bar
+-------------------------------------------------------+
|                                                       |
|   "Hello! Tap me or the mic to start speaking"         |  <- Dynamic Prompt / Speech Coach
|                                                       |
|          +----------------------------+               |
|          |                            |               |
|          |     [Floating 3D Pet]      |               |  <- Interactive Draggable Pet
|          |          (Maru)            |               |     with idle float & reactions
|          |                            |               |
|          +----------------------------+               |
|                                                       |
|  +-------------------------------------------------+  |
|  | [Daily Goal: 12/15 mins]  [Streak: 4 Days 🔥]   |  |  <- Real Progress Snapshot
|  +-------------------------------------------------+  |
|                                                       |
|  +-------------------------------------------------+  |
|  | Quick Practice Prompts:                         |  |  <- Real Learning Cards
|  | • "How do I ask for directions in Surat?"       |  |
|  | • "Order tea at a railway station"              |  |
|  | • "Introduce yourself to a new colleague"       |  |
|  +-------------------------------------------------+  |
|                                                       |
|  +-------------------------------------------------+  |
|  | [LingoCard Docked Dialogue Overlay]             |  |  <- Docked Floating LingoCard
|  |  - Spoken Transcript (Source)                   |  |     (appears on tap/mic)
|  |  - Karaoke Translated Lyrics                    |  |
|  |  - [Play] [Slow] [Repeat] [Mic]                 |  |
|  +-------------------------------------------------+  |
+-------------------------------------------------------+
|  [Home]       [Progress]      [Achievements] [Profile] |  <- Bottom Navigation Bar
+-------------------------------------------------------+
```

---

## 6. The Canonical 10 Core Screens Specification

Per the LingoBoom product requirements, the 10 core screens are:

1. **Authentication:** Login (`/login`) & Sign Up (`/signup`) with email/password and guest preview.
2. **Onboarding — Language Selection (`/onboarding/languages`):** Native language selection (`I speak`) and Target language (`I'm learning`).
3. **Onboarding — Goal Setup (`/onboarding/goals`):** Daily practice target selection (Casual 5 min, Regular 10 min, Serious 15 min, Intensive 20 min).
4. **Onboarding / Pet Selection (`/onboarding/pets`):** Full 6-pet gallery (Maru, Mimi, Bun, Pano, Pip, Leo) with personality descriptions, audio previews, and free vs premium badges.
5. **Main Companion Experience (`/home`):** Primary language companion stage with draggable pet, voice input, karaoke lyrics, and quick-prompt library.
6. **Learning Progress & Vocabulary (`/progress`):** Spaced repetition review list, retention curve, words mastered, and pronunciation accuracy tracking.
7. **Achievements & Streaks (`/achievements`):** Milestone badges (First Words, 7-Day Streak, Polyglot Rookie, Pronunciation Ace), XP progress.
8. **User Profile & Stats (`/profile`):** User avatar, total minutes spoken, total words learned, current subscription tier.
9. **Settings & Customization (`/settings`):** Speech rate (0.7x, 1.0x, 1.2x), companion voice settings, offline mode toggle, account deletion.
10. **Conversation History (`/history`):** Chronological log of past sessions with full audio playback, source transcript, translation, and pronunciation scores.

---

## 7. Python Test Environment Remediation

- **Diagnostic:** The IDE reported `Cannot find module pytest` and `Cannot find module asyncpg` because the workspace interpreter was set to a global Python 3.14 installation lacking project dependencies.
- **Remediation Completed:**
  - Dedicated virtual environment created at `backend/.venv` using Python 3.12.
  - Installed all dependencies: `fastapi`, `uvicorn`, `pydantic`, `pydantic-settings`, `python-dotenv`, `pytest`, `pytest-asyncio`, `asyncpg`, `httpx`.
  - Configured `.vscode/settings.json` to point `python.defaultInterpreterPath` to `${workspaceFolder}/backend/.venv/Scripts/python.exe`.
  - Configured `pyrightconfig.json` with genuine `venvPath: "backend"` and `venv: ".venv"`, removing artificial error suppression.
  - Excluded `backend/.venv` in `.gitignore` (line 72 confirmed via `git check-ignore -v backend/.venv`).
  - Ran backend test suite: **24/24 tests passed** (including all live Supabase RLS isolation, table grant, TRUNCATE revocation, and function search_path tests).

---

## 8. Verification & Next Steps Checklist

- [x] Environment audit and virtualenv setup completed (24/24 tests passing).
- [x] UI restoration audit document written (`docs/UI_RESTORATION_AUDIT.md`).
- [ ] **User Review & Approval:** Present audit to user for review before proceeding with file modifications or deletions.
- [ ] **Implementation Phase (Post-Approval):**
  1. Redesign `MainCompanionScreen` replacing Notes backdrop with the LingoBoom Conversation Stage.
  2. Purge `polypet_card.dart` and dummy note references.
  3. Clean dummy data from `progress_screen.dart` and `history_screen.dart`.
  4. Implement high-resolution pet rendering pipeline.
  5. Remove fake status bar and verify layout on real device / emulator.
  6. Run `flutter analyze` and `flutter test`.

