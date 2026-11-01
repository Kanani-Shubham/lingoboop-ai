# LingoBoom — Prototype Analysis (`polypet-demo.html`)

**Reference Artifact:** `product_context/prototype/original/polypet-demo.html`  
**Prototype Title:** PolyPet: floating language buddy  
**Status:** Visual and Interaction Proof-of-Concept (Web/Browser based)

---

## 1. Executive Summary

The HTML prototype is an interactive, browser-based demonstration of the core user experience for a floating language learning pet. It proves that low-poly 3D models with simple gesture animations combined with an adjacent Spotify-style karaoke card create an intuitive, delightful, and engaging language learning companion.

However, the HTML prototype relies exclusively on **Web browser APIs** (WebKit SpeechRecognition, Web SpeechSynthesis, DOM events, and unauthenticated public translation endpoints). For production, all of these client-side mockups must be ported to Flutter widgets, a native Android `WindowManager` overlay service, and a secure backend service integrating the Gnani AI suite.

---

## 2. Visual & Interaction Design Systems

### 2.1. Layout & Responsive Viewport
- **Container Dimensions:** Fixed phone aspect ratio `390px × 780px` (`#ph`) on desktop; fluid `100vw × 100svh` on mobile viewports (< 480px).
- **Surface Elevation:** Nested cards with soft dropshadows (`0 14px 36px rgba(0,0,0,0.2)` on sheets, `0 18px 40px rgba(0,0,0,0.3)` on floating cards).
- **Background:** Dark teal-grey `#13201e` for outer stage; light mint-grey `#eaf0ec` for internal phone backdrop.

### 2.2. Typography System
- **Primary Typeface:** `'Fredoka', ui-rounded, system-ui, sans-serif` loaded via Google Fonts.
- **Weights:** Regular (400), Medium (500), SemiBold (600).
- **Hierarchy:**
  - Header: 30px / 600 weight.
  - Sheet Title: 18px / 600 weight.
  - Translated Lyric (`#lyr`): 25px / 600 weight, line-height 1.22.
  - Spoken Transcript (`#said`): 14px / 500 weight.
  - Note / Status (`#nt`): 13px.

### 2.3. Dynamic Character Palette & Theming
The UI dynamically adapts its accent color `--acc` based on the active character:

| Character | Animal Species | Hex Color | Role / Personality |
|---|---|---|---|
| **Maru** | Fox | `#C4571C` (Terracotta) | Energetic & Inquisitive |
| **Mimi** | Cat | `#6A4CC4` (Purple) | Precise & Elegant |
| **Pano** | Panda | `#2C6E5E` (Teal Green) | Calm & Methodical |
| **Bun** | Bunny | `#C23D7B` (Magenta/Pink) | Cheerful & Playful |
| **Pip** | Penguin | `#2C62C4` (Royal Blue) | Focused & Friendly |
| **Leo** | Lion | `#9A6A06` (Ochre Gold) | Confident & Bold |

---

## 3. Detailed Component Breakdown

### 3.1. Floating 3D Character (`#pw` / `#cv`)
- **Rendering Technology:** Three.js WebGLRenderer with alpha transparency and antialiasing on a `150px × 150px` `<canvas>`.
- **Camera Setup:** PerspectiveCamera(fov: 30°, aspect: 1, near: 0.1, far: 50) positioned at `(0, 1.3, 4.6)`, looking at `(0, 0.62, 0)`.
- **Lighting:** HemisphereLight (`0xffffff`, `0x8899aa`, 0.95 intensity) + DirectionalLight (`0xffffff`, 0.8 intensity) at `(2, 4, 3)`.
- **Character Physics Simulation:**
  - **Floor Snapping:** Smooth lerp towards bottom baseline: `y += (floor() - y) * Math.min(1, dt * 7)`.
  - **Autonomous Wandering:** Randomly transitions between `idle` (2–5s), `walk` (towards random X coordinate with heading angle facing), and `dance` (celebration).
  - **Listening Reaction:** Tilts head `tilt = 0.16` on Z-axis when recording audio.
  - **Pulse / Squish-Stretch:** Spring deformation `H.scale.set(1 - 0.05*pulse, 1 + 0.12*pulse, 1 - 0.05*pulse)` on audio beats or state triggers.
- **Pointer & Drag Interactions:**
  - Pointer down captures pointer coordinates.
  - Moving > 6px initiates `'drag'` mode, setting the animation to `run`.
  - Dragging clamps to screen bounds `clamp(x, -40, W - 110)` and `clamp(y, 0, H - 160)`.
  - Releasing without drag toggles card open/closed.

### 3.2. Spotify-Style Floating Translation Card ("LingoCard") (`#cd`)
- **Docking Logic:**
  - If the character is on the left half of the screen (`x + 75 < W/2`), the card docks on the **right** (`side = 'r'`), and the character walks to the left edge (`x = -24`).
  - If the character is on the right half, the card docks on the **left** (`side = 'l'`), and the character walks to the right edge (`x = W - 126`).
- **Card Elements:**
  1. **Header Bar:** Active character name (`Maru`), current language pair (`Gujarati → English`), and round close button `✕`.
  2. **Transcript Area (`#said`):** Displays recognized input text (source language).
  3. **Synced Lyric / Word Karaoke (`#lyr`):** Words rendered as individual spans (`.w`).
     - Words illuminate (`.on`, opacity: 1.0) progressively during speech playback.
     - Supports `Intl.Segmenter` for word boundaries.
  4. **Status / Feedback Line (`#nt`):** Real-time feedback ("Listening…", "Translating…", "All words matched. Nicely done!").
  5. **Control Strip:**
     - **Play (`#play`):** Plays audio at 1.0x speed with synchronized word illumination.
     - **Slow (`#slow`):** Plays audio at 0.7x speed for learners dissecting difficult phonetic sounds.
     - **Repeat Practice (`#rep`):** Starts target language microphone capture, matches user speech against expected translation words, and decorates words with `.ok` (green/subtle pill) or `.miss` (wavy underline).
     - **Microphone Button (`#mic`):** Large circular pill button with pulsing concentric ring animation during recording.
  6. **Fallback Text Input (`#tf` / `#ti`):** Text input field for testing without microphone hardware.

### 3.3. Settings & Language Drawer (`#sh`)
- Slips down from top on gear icon click.
- Allows switching source language (`#fs`) and target language (`#ts`).
- Character selection chip list with color badges and active selection borders.

---

## 4. Prototype vs. Production Comparison

| Feature Area | Prototype Implementation | Production Requirement (LingoBoom) |
|---|---|---|
| **Speech-to-Text** | Browser Web Speech API (`webkitSpeechRecognition`) | **Gnani Prisma v3.0** STT via FastAPI streaming WebSocket |
| **Machine Translation** | Public MyMemory API (`mymemory.translated.net`) | **Gnani Evon** LLM / Translation engine with context awareness |
| **Text-to-Speech** | Web SpeechSynthesis API (`speechSynthesis.speak`) | **Gnani Timbre** high-fidelity neural voice synthesis |
| **Karaoke Synchronization** | Synthetic word timer / browser boundary events | Precise millisecond word timestamps returned by Gnani Timbre / Prisma |
| **Pronunciation Evaluation** | Naive substring inclusion (`includes()`) | Phonetic similarity & pronunciation scoring via Gnani Prisma confidence |
| **3D Character Rendering** | Three.js WebGL canvas inside HTML DOM | Flutter GLB renderer (`flutter_cube` / `model_viewer_plus` / Filament / Impeller bridge) |
| **Overlay Window** | In-page `<div>` positioned with CSS `transform` | Native Android `WindowManager` with `TYPE_APPLICATION_OVERLAY` & Foreground Service |
| **Data Persistence** | None (in-memory variables only) | **Supabase PostgreSQL** + Drift local SQLite cache |
| **Authentication** | None | **Supabase Auth** (Email, Google OAuth, Phone) |
| **Subscriptions** | None | Razorpay / Google Play In-App Billing (Free vs. ₹9/mo, ₹49/yr) |

---

## 5. Architectural Recommendations for Flutter & Android Native

1. **Exact Visual Preservation:**
   - Do NOT alter the visual personality, colors, typography, or layout proportions established in the prototype.
   - Use Google Fonts `Fredoka` throughout the Flutter application.
2. **Overlay Separation:**
   - The floating character overlay must run as a native Android Foreground Service using a Kotlin `WindowManager` view.
   - It must communicate bi-directionally with Flutter via `MethodChannel` and `EventChannel`.
3. **AI Pipeline Decoupling:**
   - All external AI calls (Gnani Prisma, Timbre, Evon) must be proxied through the FastAPI backend to protect API keys, meter user credits, and enforce subscription entitlements.

