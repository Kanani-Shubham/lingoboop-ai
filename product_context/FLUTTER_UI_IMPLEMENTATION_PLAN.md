# LingoBoom — Flutter UI Implementation Plan & Prototype Mapping

**Primary Design Specification & Single Source of Truth:** `product_context/prototype/original/polypet-demo.html`  
**Architecture:** Flutter 3.47+ / Dart 3.13+, Flutter Riverpod, GoRouter, Supabase Flutter  
**Status:** Phase 2 Active Implementation Plan  

---

## 1. Design System Extraction from `polypet-demo.html`

### 1.1. Color Palette & Dynamic Character Theming

The visual core of LingoBoom is its **dynamic theme accent (`--acc`)**, which adapts based on the active character companion:

| Token / Element | HTML Hex / Value | Flutter Color Definition | Usage |
|:---|:---|:---|:---|
| **Outer Stage Backdrop** | `#13201E` | `Color(0xFF13201E)` | Desktop/web bezel and dark mode shell |
| **Phone Background** | `#EAF0EC` | `Color(0xFFEAF0EC)` | Primary application canvas / screen background |
| **Primary Text / Dark** | `#1D2B29` | `Color(0xFF1D2B29)` | Headers, card titles, active icons |
| **Secondary Text / Muted** | `#62746F` | `Color(0xFF62746F)` | Subtitles, helper text, inactive labels |
| **Card Surface** | `#FFFFFF` | `Color(0xFFFFFFFF)` | Notes cards, settings sheet, dialogs |
| **Border / Divider** | `#C5D3CD` | `Color(0xFFC5D3CD)` | Unselected chips, select borders, dividers |
| **Card Border Soft** | `#D5E0DB` | `Color(0xFFD5E0DB)` | Bottom bar top-border |
| **Input Background** | `rgba(0,0,0,0.2)` | `Color(0x33000000)` | Fallback text input inside LingoCard |
| **Word Karaoke Dim** | `rgba(255,255,255,0.42)`| `Color(0x6BFFFFFF)` | Unspoken words in translation card |
| **Word Karaoke Highlight** | `rgba(255,255,255,1.0)` | `Color(0xFFFFFFFF)` | Currently spoken / highlighted words |
| **Practice Match (OK)** | `rgba(255,255,255,0.2)` | `Color(0x33FFFFFF)` | Correctly pronounced word badge |
| **Practice Miss** | `#FFD9C9` (wavy underline)| `Color(0xFFFFD9C9)` | Mispronounced word wavy decoration |

#### Character Accent Colors (`--acc`):
- **Maru (Fox)**: `#C4571C` (Terracotta Orange)
- **Mimi (Cat)**: `#6A4CC4` (Soft Royal Purple)
- **Pano (Panda)**: `#2C6E5E` (Forest Jade)
- **Bun (Bunny)**: `#C23D7B` (Magenta Rose)
- **Pip (Penguin)**: `#2C62C4` (Cobalt Blue)
- **Leo (Lion)**: `#9A6A06` (Golden Ochre)

---

### 1.2. Typography (Fredoka)

Loaded via Google Fonts (`google_fonts: ^6.2.1`):

- **Font Family:** `Fredoka` (`GoogleFonts.fredoka()`)
- **Display / Header 1 (`.ah h1`):** `30px`, weight `FontWeight.w600` (`#1D2B29`)
- **Sheet Title (`#sh h2`):** `18px`, weight `FontWeight.w600` (`#1D2B29`)
- **Translated Karaoke (`#lyr`):** `25px`, weight `FontWeight.w600`, line height `1.22` (`#FFFFFF`)
- **Card Title / Word (`.n`):** `16px`, weight `FontWeight.w500` (`#1D2B29`)
- **Spoken Transcript (`#said`):** `14px`, weight `FontWeight.w500`, opacity `0.85` (`#FFFFFF`)
- **Subtitle / Small (`.n small`):** `14px`, weight `FontWeight.w400` (`#62746F`)
- **Status / Note (`#nt`):** `13px`, weight `FontWeight.w500` (`#FFFFFF` or `#62746F`)
- **Status Bar (`.sb`):** `13px`, weight `FontWeight.w600` (`#1D2B29`)

---

### 1.3. Component Metrics, Radii & Shadows

- **Standard Cards (`.n`):**
  - Radius: `BorderRadius.circular(16)`
  - Asymmetric Alternate Card (`.n:nth-child(odd)`): `BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4))`
  - Margin: `EdgeInsets.symmetric(horizontal: 16, vertical: 10)`
  - Padding: `EdgeInsets.symmetric(horizontal: 16, vertical: 14)`
- **LingoCard Floating Dialog (`#cd`):**
  - Width: `232px`, Max Height: `calc(100% - 150px)`
  - Background: `activePet.accentColor`
  - Radius: `BorderRadius.circular(22)`
  - Padding: `EdgeInsets.all(14)`
  - Shadow: `BoxShadow(color: Color(0x50000000), blurRadius: 40, offset: Offset(0, 18))`
- **Settings Sheet (`#sh`):**
  - Radius: `BorderRadius.circular(20)`
  - Padding: `EdgeInsets.all(16)`
  - Shadow: `BoxShadow(color: Color(0x30000000), blurRadius: 36, offset: Offset(0, 14))`
- **Pill Chips (`.chip`):**
  - Height: `36px`, Padding: `EdgeInsets.symmetric(horizontal: 12)`
  - Radius: `BorderRadius.circular(999)`
  - Border: `Border.all(color: isSelected ? activePet.accentColor : Color(0xFFC5D3CD), width: 2)`
- **Mic Button (`#mic`):**
  - Dimensions: `50px × 50px`, circular
  - Background: `#FFFFFF`, Icon color: `activePet.accentColor`
  - Active Pulse Shadow: `BoxShadow(color: Color(0x40FFFFFF), blurRadius: 0, spreadRadius: 9)`

---

## 2. Screen-by-Screen HTML-to-Flutter Implementation Mapping

| # | Screen Name | Route Path | Prototype Reference / Source | Flutter Implementation File | Key Features & Interactions |
|:---|:---|:---|:---|:---|:---|
| **1** | **Splash / Welcome** | `/` | HTML Hero & Brand Identity | `lib/features/welcome/presentation/welcome_screen.dart` | Animated brand logo, character greeting, Get Started & Login buttons. |
| **2** | **Login** | `/login` | Auth Form Specification | `lib/features/auth/presentation/login_screen.dart` | Email/Password, Supabase sign-in, validation, redirect to main/onboarding. |
| **3** | **Signup** | `/signup` | Auth Form & DB Trigger | `lib/features/auth/presentation/signup_screen.dart` | Email/Password signup, provisions profile/prefs/sub in Supabase. |
| **4** | **Language Onboarding** | `/onboarding/languages` | Prototype `#fs` & `#ts` selectors | `lib/features/onboarding/presentation/language_select_screen.dart` | Source (`I speak`) and Target (`I'm learning`) language selection. |
| **5** | **Goal & Level Setup** | `/onboarding/goals` | User Preferences DB model | `lib/features/onboarding/presentation/goal_setup_screen.dart` | Daily goal (10, 15, 20 mins), level (beginner, intermediate, advanced). |
| **6** | **Pet / Character Selection**| `/onboarding/pets` | Prototype `#ch` chip list & models | `lib/features/character/presentation/pet_select_screen.dart` | 6 pets carousel (Maru, Mimi, Pano, Bun, Pip, Leo) with colors & lore. |
| **7** | **Main Companion Screen** | `/home` | Prototype `#ph` (Notes, Pet, Dock) | `lib/features/home/presentation/main_companion_screen.dart` | Notes feed, draggable/snappable 3D pet, top bar, bottom bar, gear button. |
| **8** | **Floating LingoCard** | (Modal Widget) | Prototype `#cd` (Lyrics, Mic, Play) | `lib/features/companion/presentation/lingo_card_widget.dart` | Synced karaoke word illumination, slow audio, repeat practice, text input. |
| **9** | **Quick Settings Sheet** | (Overlay Sheet) | Prototype `#sh` (Drawer) | `lib/features/settings/presentation/pet_settings_sheet.dart` | Quick language switcher, pet switcher chips, Done button. |
| **10**| **Settings Screen** | `/settings` | Extended App Settings | `lib/features/settings/presentation/settings_screen.dart` | Audio speed slider (0.5x–2.0x), overlay toggle, haptics, logout. |
| **11**| **User Profile** | `/profile` | Profile & Quota Specs | `lib/features/profile/presentation/profile_screen.dart` | Speech quota gauge (seconds used/limit), streak counter, account details. |
| **12**| **Learning Progress** | `/progress` | `learning_progress` SRS Table | `lib/features/progress/presentation/progress_screen.dart` | Mastered words, review-due cards, Spaced Repetition mastery scores. |
| **13**| **Achievements** | `/achievements` | `achievements` Table | `lib/features/achievements/presentation/achievements_screen.dart` | Milestone badges, streak awards, celebration animations. |
| **14**| **Premium Subscription** | `/subscription` | Pricing PRD (₹9/mo, ₹49/yr) | `lib/features/subscription/presentation/subscription_screen.dart` | Tier comparison card, Free vs Premium feature matrix, upgrade button. |
| **15**| **Conversation History** | `/history` | `conversations` & `messages` | `lib/features/history/presentation/history_screen.dart` | Historical transcript search, audio replay, practice repeat trigger. |

---

## 3. Reusable Widget Mapping

| Widget Name | File Path | Maps To HTML Prototype Element |
|:---|:---|:---|
| `PolyPetButton` | `lib/core/widgets/polypet_button.dart` | `.row button`, `#play`, `#slow`, `#rep`, `#dn` |
| `PolyPetMicButton` | `lib/core/widgets/polypet_mic_button.dart` | `#mic` (50px circular pulse button) |
| `PolyPetCard` | `lib/core/widgets/polypet_card.dart` | `.n` (asymmetric rounded cards) |
| `CharacterChip` | `lib/core/widgets/character_chip.dart` | `.chip` (circular dot badge + label) |
| `KaraokeLyricsView` | `lib/core/widgets/karaoke_lyrics_view.dart` | `#lyr` (`.w.on`, `.ok`, `.miss`) |
| `FloatingPetAvatar` | `lib/core/widgets/floating_pet_avatar.dart` | `#pw`, `#cv`, `.hint` |
| `LingoCardWidget` | `lib/features/companion/presentation/lingo_card_widget.dart` | `#cd` (Floating docked dialogue) |
| `PolyPetBottomNav` | `lib/core/widgets/polypet_bottom_nav.dart` | `.tb` (Bottom tab bar with pills) |

---

## 4. Character Asset Mapping

| Character | Pet Key | Species | Model File | Preview Image | Hex Code | Default State |
|:---|:---|:---|:---|:---|:---|:---|
| **Maru** | `fox` | Fox | `assets/characters/maru/models/maru.glb` | `assets/characters/maru/previews/maru.png` | `#C4571C` | Free / Default |
| **Mimi** | `cat` | Cat | `assets/characters/mimi/models/mimi.glb` | `assets/characters/mimi/previews/mimi.png` | `#6A4CC4` | Free |
| **Bun** | `bunny` | Bunny | `assets/characters/bun/models/bun.glb` | `assets/characters/bun/previews/bun.png` | `#C23D7B` | Free |
| **Pano** | `panda` | Panda | `assets/characters/pano/models/pano.glb` | `assets/characters/pano/previews/pano.png` | `#2C6E5E` | Premium |
| **Pip** | `penguin` | Penguin | `assets/characters/pip/models/pip.glb` | `assets/characters/pip/previews/pip.png` | `#2C62C4` | Premium |
| **Leo** | `lion` | Lion | `assets/characters/leo/models/leo.glb` | `assets/characters/leo/previews/leo.png` | `#9A6A06` | Premium |

---

## 5. Required Flutter Packages

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  go_router: ^14.8.1
  google_fonts: ^6.2.1
  supabase_flutter: ^2.8.4
  flutter_secure_storage: ^9.2.4
  http: ^1.2.2
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

---

## 6. Implementation Sequence & Milestones

1. **Phase 2A — Core Foundation & Theme**:
   - Update `pubspec.yaml` with Riverpod, GoRouter, GoogleFonts, Supabase.
   - Configure Fredoka typography, dynamic character color theme system, and asset declarations.
   - Build reusable widgets (`PolyPetCard`, `PolyPetButton`, `PolyPetMicButton`, `CharacterChip`, `KaraokeLyricsView`).
2. **Phase 2B — Main Companion Screen & LingoCard**:
   - Recreate the exact HTML prototype screen `#ph` (`main_companion_screen.dart`).
   - Implement draggable floating pet avatar with hint badge ("Tap me to talk").
   - Implement the docking LingoCard `#cd` with synchronized karaoke illumination, playback speed controls, and mic pulse.
   - Implement the quick settings drawer `#sh`.
3. **Phase 2C — Authentication & Onboarding**:
   - Welcome/Splash screen (`welcome_screen.dart`).
   - Login and Signup screens (`login_screen.dart`, `signup_screen.dart`) wired to Supabase Auth.
   - Language pairing selector (`language_select_screen.dart`).
   - Daily goal and level setup (`goal_setup_screen.dart`).
   - Pet selection showcase (`pet_select_screen.dart`).
4. **Phase 2D — Profile, Progress, Achievements & Subscription**:
   - Profile screen with speech quota progress gauge (`profile_screen.dart`).
   - Learning progress Spaced Repetition cards (`progress_screen.dart`).
   - Milestone badges & streak showcase (`achievements_screen.dart`).
   - Premium subscription pricing comparison (`subscription_screen.dart`).
   - Settings screen (`settings_screen.dart`).
5. **Phase 2E — Verification**:
   - Run `flutter pub get`, `flutter analyze`, and unit/widget tests (`flutter test`).
   - Test responsive layout and interaction behavior.

