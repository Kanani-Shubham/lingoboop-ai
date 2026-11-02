# LingoBoop — Final Functional & Architecture Audit Report

**Date:** November 2, 2026  
**Project:** LingoBoop (Flutter + Android Native + FastAPI Backend + Supabase)  
**Target Device:** Android 14 (Physical Test Device: `10BCBF23HT000H7`)

---

## 1. Executive Summary

This comprehensive audit details the root causes and architectural resolutions for the 11 functional and UI issues identified in the LingoBoop companion application. The primary design mandate is to restore the exact visual fidelity and interaction model established in `polypet-demo.html` while delivering real-world production robustness across Flutter, Android WindowManager, and upstream AI services (Gnani Prisma v3.0, Groq GPT-OSS 120B, and Gnani Timbre TTS).

---

## 2. Detailed Root Cause Analysis & Resolutions

### Issue 1: Microphone Permission & Recording Flow
- **Root Cause:** Audio recording was invoked directly without performing an explicit runtime permission check against Android `RECORD_AUDIO`. When denied or unrequested, the recording package would fail silently or produce a 0-byte buffer.
- **Affected Files:** `lib/core/services/speech_service.dart`, `android/app/src/main/AndroidManifest.xml`.
- **Resolution:** Implement a pre-flight runtime permission check via `permission_handler`. If permission is not granted, present a native/modal explanation dialog. If permanently denied, offer direct deep-linking to Android App Settings. Only initiate hardware recording after `Permission.microphone.isGranted` is confirmed.

### Issue 2: Speech Transcription "Could not capture clear speech"
- **Root Cause:** Gnani Prisma v3.0 REST endpoint (`https://api.vachana.ai/stt/v3`) requires linear PCM 16kHz mono WAV format. When recording in AAC/m4a or when ambient silence (<0.4s) was uploaded, the API returned empty transcripts, triggering the fallback warning.
- **Affected Files:** `lib/core/services/speech_service.dart`, `backend/app/providers/stt_provider.py`.
- **Resolution:** Force recording to 16,000 Hz sample rate, 1 channel (mono), 16-bit PCM WAV. Added duration validation (>0.4s) and audio header inspection prior to upload.

### Issue 3: AI Response & Generated Voice Reliability
- **Root Cause:** Backend timeout (formerly 5s) was too short for multi-hop processing (Gnani STT -> Groq GPT-OSS 120B -> Gnani Timbre TTS). When network latency fluctuated, Flutter received a timeout exception.
- **Affected Files:** `backend/app/core/config.py`, `lib/core/services/speech_service.dart`.
- **Resolution:** Configured connection pooling and a resilient 15s timeout on mobile clients. Decoupled translation and TTS generation so transcripts display immediately while TTS buffers.

### Issue 4: Spotify-Style Lyrics Card Opening Behavior
- **Root Cause:** Tap recognition was bound to a specific inner container rather than the complete 150x150 pet bounds. In some views, child WebView or gesture recognizers intercepted touch events before the tap could register.
- **Affected Files:** `lib/core/widgets/floating_pet_avatar.dart`, `lib/features/navigation/presentation/main_navigation_shell.dart`.
- **Resolution:** Wrapped `FloatingPetAvatar` in a unified `RawGestureDetector` / `GestureDetector` that recognizes taps anywhere within the 150x150 logical pixel container, opening `LingoCardWidget` with zero latency.

### Issue 5: Lyrics Card Layout Overflow (`RIGHT OVERFLOWED BY 23 PIXELS`)
- **Root Cause:** Card width is fixed to 232px with 14px padding on each side (204px inner space). The action control strip (Play 36px + Gap 6px + Slow ~52px + Gap 6px + Repeat ~62px + Gap 8px + Mic 50px = 220px) exceeded 204px by 16–23px depending on font metrics.
- **Affected Files:** `lib/features/pet_overlay/poly_card_widget.dart`.
- **Resolution:** Streamlined horizontal button padding (Play: 34px, Slow: 34px/p-8, Repeat: 34px/p-8, Mic: 44px) and wrapped the entire action row in `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft)` to guarantee that no RenderFlex overflow can occur regardless of viewport width or font scaling.

### Issue 6: In-App Pet Dragging & Repositioning
- **Root Cause:** Pet coordinates were being overridden by an autonomous wandering ticker that did not check whether a custom position had been assigned by user dragging.
- **Affected Files:** `lib/features/navigation/presentation/main_navigation_shell.dart`, `lib/core/widgets/floating_pet_avatar.dart`.
- **Resolution:** Added `_isCustomPositioned` flag. When the user drags the pet, autonomous roaming and gravity floor-pulling are disabled, and the pet stays anchored exactly where released. The sticky card maintains a dynamic relative offset (`_side == 'r' ? petPos.dx + 132 : petPos.dx - 232`).

### Issue 7 & 8: Duplicate Pets & Android Overlay Management
- **Root Cause:** `FloatingPetService` was rendering the native Android WindowManager view even while `MainActivity` was in the foreground. Because `MainNavigationShell` simultaneously rendered the in-app Flutter pet, two pets appeared side-by-side.
- **Affected Files:** `android/app/src/main/kotlin/com/lingoboop/lingoboop/MainActivity.kt`, `android/app/src/main/kotlin/com/lingoboop/lingoboop/overlay/FloatingPetService.kt`, `android/app/src/main/kotlin/com/lingoboop/lingoboop/overlay/FloatingPetWindowManager.kt`.
- **Resolution:** Enforced strict mutual exclusivity:
  - `MainActivity.onResume()` dispatches `ACTION_HIDE_OVERLAY` to immediately set native WindowManager view visibility to `GONE`.
  - `MainActivity.onPause()` dispatches `ACTION_SHOW_OVERLAY` only if the overlay preference is enabled.
  - `FloatingPetService.onStartCommand()` verifies `MainActivity.isAppInForeground` before making the overlay visible.

### Issue 9: Floating Pet Position & Edge Snapping
- **Root Cause:** In the native Android WindowManager, release (`ACTION_UP`) saved the coordinates but lacked smooth edge snapping, occasionally leaving the pet stranded in awkward screen regions.
- **Affected Files:** `android/app/src/main/kotlin/com/lingoboop/lingoboop/overlay/FloatingPetWindowManager.kt`.
- **Resolution:** Implemented `ValueAnimator` on `ACTION_UP` that smoothly interpolates the pet's X coordinate to the nearest screen edge (left margin or right margin) with `DecelerateInterpolator`.

### Issue 10: Overlay Preferences Synchronization with Supabase
- **Root Cause:** The `user_preferences` table lacked columns for `overlay_enabled` and normalized positions (`overlay_position_x`, `overlay_position_y`). Local toggle switches did not persist to the database.
- **Affected Files:** `supabase/migrations/`, `lib/core/services/user_data_service.dart`, `lib/features/settings/presentation/settings_screen.dart`.
- **Resolution:** Created SQL migration `20261102000100_overlay_preferences_and_pet_position.sql` adding `overlay_enabled BOOLEAN NOT NULL DEFAULT FALSE` and normalized coordinates `NUMERIC(5,4)` bounded `[0.0, 1.0]`. Integrated debounce persistence in `UserDataService`.

### Issue 11: Pipeline Latency & Speed
- **Root Cause:** Sequential HTTP round-trips without keep-alive and duplicate TTS generation upon re-listening.
- **Affected Files:** `backend/app/providers/`, `lib/core/services/speech_service.dart`.
- **Resolution:** Implemented client-side audio memory caching for the active session, persistent HTTP/2 connection pooling with `httpx`, and immediate UI optimistic state rendering.

---

## 3. Verification Matrix

| Area | Component | Target Status |
|---|---|---|
| Flutter UI | In-App Pet Dragging & Tap | Fully Verified across all 4 navigation tabs |
| Flutter UI | Sticky PolyCard & Layout | Responsive, zero RenderFlex overflow |
| Native Android | Floating WindowManager Pet | Edge snapping, smooth touch, no duplicate |
| Permissions | Microphone & Overlay Flow | Explanatory dialogues, runtime verification |
| Database | Supabase Migration & Sync | Added `overlay_enabled` & `overlay_position_x/y` |
| Voice Pipeline | Gnani STT + Groq + Gnani TTS | Real 16kHz audio, live LLM tutoring, live voice |

