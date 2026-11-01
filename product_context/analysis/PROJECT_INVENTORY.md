# LingoBoom — Project Inventory & Asset Manifest

**Date:** November 2026  
**Auditor:** Senior Software Architect & Technical Project Lead  
**Scope:** Complete workspace inspection and verification of all files, configurations, tools, and assets.

---

## 1. Executive Summary

A comprehensive recursive scan of the workspace was executed. The project contains:
1. A clean Flutter application template targeting Android, iOS, Web, Windows, macOS, and Linux.
2. An interactive single-file HTML5/Three.js prototype (`polypet-demo.html`) featuring real-time translation, speech recognition, audio synthesis, and interactive 3D character physics.
3. Nine high-resolution reference screenshots capturing user workflows, overlay positioning, and translation states.
4. The complete **Kenney Cube Pets (v2.0)** 3D asset package, containing 24 low-poly animal models in GLB, FBX, and OBJ formats, 192 total animations (8 per character), colormap textures, previews, and documentation.
5. Six primary extracted character models (`Maru`, `Mimi`, `Pano`, `Bun`, `Pip`, `Leo`) configured with complete 8-clip animation sets.
6. A verified Creative Commons Zero (CC0) public domain license covering all 3D assets.

---

## 2. Workspace File Inventory

### 2.1. Application Root Structure (`/`)
- `pubspec.yaml` (89 lines) — Declares project `lingoboop`, Dart SDK `^3.13.5`, `flutter` SDK, `cupertino_icons: ^1.0.8`, `flutter_lints: ^6.0.0`.
- `analysis_options.yaml` (1,585 bytes) — Standard Flutter recommended lint rules.
- `pubspec.lock` (6,086 bytes) — Lockfile for current dependencies.
- `README.md` (2,487 bytes) — Root handoff and architecture documentation.
- `.gitignore` (Updated) — Protects `.env`, keystores, credentials, build caches, and private logs.
- `.env.example` (Created) — Comprehensive configuration template for backend, Supabase, Gnani AI, and payments.

### 2.2. Dart / Flutter Source (`lib/` and `test/`)
- `lib/main.dart` (122 lines) — Initial Flutter counter template (`MyApp`, `MyHomePage`).
- `test/widget_test.dart` (30 lines) — Default Flutter smoke test.

### 2.3. Android Native Source (`android/`)
- Gradle Build System:
  - `android/settings.gradle.kts` — Android Gradle Plugin `9.1.0`, Kotlin `2.4.0`, Flutter Plugin Loader `1.0.0`.
  - `android/build.gradle.kts` — Root project Gradle build script.
  - `android/app/build.gradle.kts` — Target Java 17, JVM target 17, namespace `com.lingoboop.lingoboop`, applicationId `com.lingoboop.lingoboop`.
  - `android/gradle/wrapper/gradle-wrapper.properties` — Gradle distribution wrapper.
- Android Manifests & Java/Kotlin:
  - `android/app/src/main/AndroidManifest.xml` (45 lines) — Main activity manifest. Currently lacks overlay, foreground service, and microphone permissions.
  - `android/app/src/main/kotlin/com/lingoboop/lingoboop/MainActivity.kt` — Standard `FlutterActivity`. No custom Platform Channel methods implemented yet.

### 2.4. Prototype & Reference Artifacts (`product_context/prototype/`)
- `product_context/prototype/original/polypet-demo.html` (1.27 MB) — Self-contained HTML prototype containing embedded Three.js WebGL scene, 6 base64-encoded GLB models, speech pipeline, audio playback, and floating card UI.
- `product_context/prototype/screenshots/` (9 images, 630 KB total):
  - `Screenshot 2026-10-31 162016.png` (36.1 KB) — Character selection and base state.
  - `Screenshot 2026-10-31 162033.png` (71.9 KB) — Floating card active translation.
  - `Screenshot 2026-10-31 162045.png` (68.4 KB) — Settings drawer and language pair selection.
  - `Screenshot 2026-10-31 162053.png` (44.1 KB) — Dragging pet across screen.
  - `Screenshot 2026-10-31 162111.png` (66.7 KB) — Repeat / pronunciation practice scoring.
  - `Screenshot 2026-10-31 230555.png` (88.3 KB) — LingoCard UI details and word highlighting.
  - `Screenshot 2026-10-31 230612.png` (84.9 KB) — Character interaction (dancing/celebrating).
  - `Screenshot 2026-10-31 230624.png` (91.2 KB) — Hindi / Hinglish translation view.
  - `Screenshot 2026-10-31 230636.png` (73.0 KB) — Gujarati to English translation view.

### 2.5. 3D Character Models (`assets/characters/`)
Six active production characters organized with models, previews, and animation manifests:
- `assets/characters/maru/` — Fox (`maru.glb`, 138.6 KB; `maru.png`; `animations.json`).
- `assets/characters/mimi/` — Cat (`mimi.glb`, 161.3 KB; `mimi.png`; `animations.json`).
- `assets/characters/pano/` — Panda (`pano.glb`, 130.5 KB; `pano.png`; `animations.json`).
- `assets/characters/bun/` — Bunny (`bun.glb`, 128.5 KB; `bun.png`; `animations.json`).
- `assets/characters/pip/` — Penguin (`pip.glb`, 127.3 KB; `pip.png`; `animations.json`).
- `assets/characters/leo/` — Lion (`leo.glb`, 168.9 KB; `leo.png`; `animations.json`).

### 2.6. Source Asset Repository (`product_context/original_assets/`)
- `product_context/original_assets/source_documentation/` — Kenney documentation (`Overview.html`, `License.txt`, `Preview.png`).
- `LingoBoom_Antigravity_Starter/kenney_cube-pets_1.0/` — Preserved complete original asset suite (24 animals in GLB, FBX, OBJ, textures, 192 animations).

---

## 3. Toolchain & Environment Verification

| Tool / Runtime | Detected Version | Target Specification | Status |
|---|---|---|---|
| **Flutter SDK** | 3.47.7 (Channel Stable) | 3.47+ | Compatible & Healthy |
| **Dart SDK** | 3.13.5 | ^3.13.5 | Compatible & Healthy |
| **Node.js** | 24.18.0 | LTS (>= 18.0) | Healthy for local tooling |
| **Android Gradle Plugin** | 9.1.0 | AGP 8.x / 9.x | Modern Kotlin DSL |
| **Kotlin Version** | 2.4.0 | 1.9+ / 2.0+ | Modern Kotlin DSL |
| **Java Compatibility** | JavaVersion.VERSION_17 | Java 17 | Aligned with Gradle |

