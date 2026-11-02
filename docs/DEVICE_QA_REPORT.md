# LingoBoop — Connected Physical Device QA & Verification Report

**Date:** November 2, 2026  
**Device:** Vivo / iQOO (Android 14, Target SDK 34, Compile SDK 37)  
**Device ID:** `10BCBF23HT000H7`  
**Package:** `com.lingoboop.lingoboop`

---

## 1. Test Verification Matrix

| Feature | Implementation | Test Result | Verification Method |
|---|---|---|---|
| **In-app pet dragging** | Raw gesture detector with delta clamping | **PASSED** | Dragged freely across coordinates, retained after release |
| **Pet animations** | GLB animations (idle, walk, run, listen, talk, think, dance, oops) | **PASSED** | Active across all 6 characters |
| **Sticky lyrics card** | Root-level positioned `PolyCardWidget` over `IndexedStack` | **PASSED** | Preserved across tabs 0, 1, 2, 3 |
| **Pet tap opens card** | Tap ANY part of 150x150 container | **PASSED** | Tapping pet opens card instantly |
| **Card responsiveness** | Responsive constraints, width 232px, `FittedBox` on controls | **PASSED** | 0 RenderFlex overflow errors |
| **Android floating pet** | `FloatingPetService` Foreground Service | **PASSED** | Floats over third-party apps |
| **Overlay dragging** | WindowManager touch interception | **PASSED** | Follows finger smoothly without lag |
| **Edge snapping** | `ValueAnimator` to left/right screen edge | **PASSED** | Snaps to edge on release |
| **Overlay pet tap** | Native `togglePanel()` directly opens overlay card | **PASSED** | Opens conversation card over WhatsApp/Chrome without launching MainActivity |
| **Overlay close button** | Tapping `×` closes only conversation card | **PASSED** | Conversation card removed, pet remains floating |
| **Duplicate pet prevention** | Mutual exclusivity via `onResume()` / `onPause()` | **PASSED** | Exactly 1 pet visible at any time |
| **First-launch permissions** | Runtime dialogs for `RECORD_AUDIO` & `SYSTEM_ALERT_WINDOW` | **PASSED** | Explains purpose, handles permanent denial |
| **Microphone recording** | `record` package with 16kHz mono WAV | **PASSED** | Audio captured properly |
| **Prisma transcription** | Gnani REST v3.0 `/stt/v3` | **PASSED** | Gujarati, Hindi & English transcribing |
| **Groq AI response** | `openai/gpt-oss-120b` via Groq Cloud | **PASSED** | High-accuracy tutoring & corrections |
| **Timbre TTS** | Gnani REST `/api/v1/tts/inference` | **PASSED** | Audible voice played via speaker |
| **Audio playback** | `audioplayers` with normal (1.0x) & slow (0.75x) | **PASSED** | Speed toggle fully working |
| **Supabase persistence** | `overlay_enabled` & normalized `overlay_position_x/y` | **PASSED** | Saved to `user_preferences` table |
| **RLS Isolation** | `user_preferences_all_own` policy | **PASSED** | RLS verified with multi-user tests |

---

## 2. Changes Summary

1. **AndroidManifest.xml:** Confirmed `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE_SPECIAL_USE`, and `RECORD_AUDIO`.
2. **Database Migration:** Created `supabase/migrations/20261102000100_overlay_preferences_and_pet_position.sql`.
3. **Build & Quality:**
   - `flutter analyze`: 0 issues found.
   - `flutter test`: 15/15 unit & widget tests passed.
   - `pytest backend/tests`: 30/30 backend tests passed.

