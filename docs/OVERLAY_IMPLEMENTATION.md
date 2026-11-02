# LingoBoop — Android Floating Overlay Implementation & Architecture

**Date:** November 2, 2026  
**Component:** Native Android WindowManager Floating Pet & Mutual Exclusivity Lifecycle

---

## 1. Overview & Architecture

LingoBoop operates across two distinct rendering environments:
1. **Flutter In-App Stage:** An embedded, interactive 3D companion rendered via Three.js in a hardware-accelerated WebView inside a root-level `Stack` in `MainNavigationShell`.
2. **Android System Overlay:** A persistent `FloatingPetService` (Android `FOREGROUND_SERVICE_SPECIAL_USE`) that manages a native `WindowManager` overlay floating above external applications (WhatsApp, YouTube, Chrome).

---

## 2. Mutual Exclusivity Lifecycle (Eliminating Duplicate Pets)

Previously, when the user enabled the overlay, the native WindowManager view remained active even while the Flutter app was in the foreground, resulting in two side-by-side pets on the screen.

### Lifecycle State Machine

```mermaid
stateDiagram-v2
    [*] --> InAppForeground: User Launches LingoBoop
    InAppForeground --> Backgrounded: User presses Home / switches apps
    Backgrounded --> InAppForeground: User taps pet / switches back

    state InAppForeground {
        FlutterPet: VISIBLE (Interactive, Tap & Drag)
        NativeOverlay: GONE / HIDDEN (WindowManager View Hidden)
    }

    state Backgrounded {
        FlutterPet: GONE (App Paused)
        NativeOverlay: VISIBLE (if overlay_enabled == true)
    }
```

### Implementation Details:

1. **`MainActivity.onResume()`:**
   - Marks `MainActivity.isAppInForeground = true`.
   - Sends `FloatingPetService.ACTION_HIDE_OVERLAY`.
   - `FloatingPetWindowManager.setOverlayVisibility(false)` sets `petView.visibility = View.GONE`, hides any open panel, and pauses autonomous roaming.

2. **`MainActivity.onPause()`:**
   - Marks `MainActivity.isAppInForeground = false`.
   - If `FloatingPetService.isRunning`, sends `FloatingPetService.ACTION_SHOW_OVERLAY`.
   - `FloatingPetWindowManager.setOverlayVisibility(true)` sets `petView.visibility = View.VISIBLE` and resumes roaming.

3. **`FloatingPetService.onStartCommand()`:**
   - When started from the Settings toggle while the user is inside the app, checks `MainActivity.isAppInForeground`.
   - If the app is foregrounded, it immediately calls `setOverlayVisibility(false)` so the overlay remains hidden until the user backgrounds the application.

---

## 3. Gesture Handling & Smooth Edge Snapping

In `FloatingPetWindowManager.kt`:
- **Touch Interception:** Overrides `onInterceptTouchEvent` on the parent `FrameLayout` to return `true`, preventing the embedded Three.js `WebView` from consuming `ACTION_MOVE` touch gestures.
- **Drag vs. Tap Discrimination:** Uses `hypot(dx, dy)`. If the movement is less than `dpToPx(12)`, it is classified as a tap.
- **Tap Action (Over External Apps):**
  - Directly opens the native WindowManager conversation card overlay (`togglePanel()`) directly over the host app (WhatsApp, Chrome, YouTube).
  - Does **NOT** launch or bring `MainActivity` to the foreground.
  - The currently running application remains active in the foreground.
  - Tapping the `×` button closes the conversation card (`closePanel()`) while keeping the floating pet visible.
  - Tapping outside the card (`ACTION_OUTSIDE`) automatically dismisses the conversation card.
  - Tapping the floating pet again toggles the card open/closed.
- **AI Tutoring & Translation:**
  - The native overlay card asynchronously connects to the live FastAPI backend (`/api/ai/tutor`).
  - Text input or recognized speech is evaluated by Groq `openai/gpt-oss-120b`, returning live translations and tutoring feedback directly into the overlay card.
- **Edge Snapping:**
  - Upon release (`ACTION_UP`), if `totalDist >= dpToPx(12)`, a `ValueAnimator` interpolates `curParams.x` to the closest screen margin (`dpToPx(8)` on the left, or `screenWidth - sizePx - dpToPx(8)` on the right) over 200ms using `DecelerateInterpolator`.
  - Coordinates are stored in `SharedPreferences` and persisted as normalized values to Supabase.

