# LingoBoom — Character Asset Audit & 3D Manifest

**Auditor:** Senior 3D Graphics & Flutter Performance Engineer  
**Source Asset Package:** Kenney Cube Pets (v2.0)  
**License:** Creative Commons Zero (CC0 1.0 Universal) — Public Domain  
**Target Roster:** 6 Active Primary Characters

---

## 1. Executive Summary

All 6 primary characters selected for **LingoBoom** have been verified and extracted directly from the verified Kenney Cube Pets package and the reference prototype. Every character model is a valid, lightweight `glTF 2.0 Binary (.glb)` file with **zero missing external textures**, **single-material colormap atlas**, **unskinned node-hierarchy rigging**, and **8 identical baked animation clips**.

Their low polygon count (under 1,600 vertices) and compact binary size (under 175 KB each) make them exceptionally well suited for low-latency, battery-efficient mobile rendering on Android and iOS.

---

## 2. Character Manifest Table

| Character | Animal | Original Filename | Format | Size | Vertices | Groups | Material | Color Code |
|---|---|---|---|---|---|---|---|---|
| **Maru** | Fox | `animal-fox.glb` | glTF 2.0 Binary | 138.6 KB | 993 | 5 | `colormap` | `#C4571C` (Terracotta) |
| **Mimi** | Cat | `animal-cat.glb` | glTF 2.0 Binary | 161.3 KB | 1,204 | 6 | `colormap` | `#6A4CC4` (Purple) |
| **Pano** | Panda | `animal-panda.glb` | glTF 2.0 Binary | 130.5 KB | 1,097 | 4 | `colormap` | `#2C6E5E` (Teal Green) |
| **Bun** | Bunny | `animal-bunny.glb` | glTF 2.0 Binary | 128.5 KB | 1,075 | 4 | `colormap` | `#C23D7B` (Magenta) |
| **Pip** | Penguin | `animal-penguin.glb` | glTF 2.0 Binary | 127.3 KB | 960 | 4 | `colormap` | `#2C62C4` (Royal Blue) |
| **Leo** | Lion | `animal-lion.glb` | glTF 2.0 Binary | 168.9 KB | 1,597 | 5 | `colormap` | `#9A6A06` (Ochre Gold) |

---

## 3. Animation Analysis

Every character contains the exact same 8 pre-rigged animation clips embedded directly in the GLB file. No external BVH or animation files are needed:

| Clip Name | Duration | Loop | Gameplay / AI Mapping | Emotional & Functional Role |
|---|---|---|---|---|
| `idle` | ~1.0 s | Yes | Default Standing State | Calm resting pose; subtle breathing sway. |
| `walk` | ~0.8 s | Yes | Wandering State | Character walks horizontally across screen towards target X. |
| `run` | ~0.6 s | Yes | Dragging / Touch Move | Activated when user drags the pet; fast transit. |
| `eat` | ~1.2 s | No | **Think** (`think`) | AI reasoning / translation in progress. Head nods down/munching. |
| `dance` | ~1.5 s | Yes | **Cheer** (`cheer` / `dance`) | Success celebration, streak milestone, pronunciation match. |
| `gesture-positive` | ~1.0 s | No | **Talk** (`talk`) | Character speaking, pronouncing words, tutoring feedback. |
| `gesture-negative` | ~1.0 s | No | **Oops** (`oops`) | Pronunciation error, recognition failure, or warning. |
| `static` | 0.0 s | No | Neutral T-Pose | Base binding frame. |

---

## 4. Rigging, Mesh & Texture Architecture

1. **Rigging Architecture:**
   - The models do NOT use complex skeletal armatures with skin weights (`skins: 0`).
   - Instead, animations are implemented via **rigid node hierarchy transforms** (translation/rotation tracks targeting individual mesh sub-nodes such as `body`, `head`, `tail`, `leg-front-left`, `leg-front-right`, `wing-left`).
   - **Advantage:** Extremely fast CPU/GPU evaluation. No vertex skinning overhead, zero deformation artifacts, and instantaneous clip cross-fading.
2. **Texture Architecture:**
   - All 6 characters share a single, unified color atlas (`colormap.png`, 128×128 or embedded in the GLB).
   - UVs map directly into solid color blocks on the atlas.
   - **Advantage:** Zero texture thrashing; batch-friendly draw calls; tiny memory footprint (~50 KB texture memory).

---

## 5. Flutter 3D Rendering Strategy Evaluation

To render these GLB models smoothly within Flutter and the floating overlay, we evaluated four technical options:

### Option A: `model_viewer_plus` (WebView + Google `<model-viewer>`)
- **Pros:** Full glTF 2.0 animation support out of the box; supports lighting, cameras, transparent backgrounds; works across Android and iOS.
- **Cons:** Runs an underlying Android WebView/Chromium instance; slightly higher memory footprint (~25–40MB per instance).
- **Suitability for In-App Flutter:** **High** (recommended for character selection screen and onboarding).
- **Suitability for Floating Overlay:** **Medium** (WebView in a small 150×150 WindowManager overlay can be heavier than desired, though technically feasible).

### Option B: Custom Filament / Sceneform Android Native View
- **Pros:** Native Android C++ rendering via Google Filament; zero WebView overhead; tiny memory footprint (< 10MB); full GLB animation control via C++ JNI.
- **Cons:** Requires native Android Kotlin/C++ boilerplate and platform view embedding.
- **Suitability:** Best for long-term production overlay optimization if battery consumption is critical.

### Option C: Flutter `flutter_cube` / `o3d` / Three.js Bridge
- `o3d` wraps web-based Filament/Three.js with fine-grained animation control.
- Allows immediate porting of the exact Three.js camera/lighting setup from `polypet-demo.html`.

### Strategic Recommendation for Phase 3 & 4:
1. **In-App Screens (Main App):** Implement via a dedicated 3D controller widget (using `o3d` or `model_viewer_plus`) matching the Three.js camera angle `(0, 1.3, 4.6)` and lighting setup.
2. **Android Native Overlay:** Evaluate running a lightweight transparent native surface or a headless webview overlay surface with exact parity to `polypet-demo.html`.
3. **Asset Integrity:** Keep the GLB files exactly as provided. Do not convert to Rive or attempt lossy manual re-rigging.

