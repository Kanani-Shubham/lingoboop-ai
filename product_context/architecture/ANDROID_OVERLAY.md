# LingoBoom — Android Native Floating Overlay Architecture

**Target Platform:** Android 8.0 (API 26) through Android 15 (API 35+)  
**Native Engine:** Kotlin + Android Native WindowManager + Foreground Service  
**Communication:** Flutter Platform Channels (`MethodChannel` & `EventChannel`)

---

## 1. Architectural Strategy

The hallmark feature of **LingoBoom** is the floating 3D pet and LingoCard interface that hovers over other applications (such as WhatsApp, Chrome, YouTube, or Instagram).

Because Flutter's main UI thread runs inside an Android Activity, minimizing or backgrounding the Flutter app would terminate a standard Flutter view. To achieve a persistent, reliable floating companion, the overlay is implemented as a **Native Android Foreground Service** managing a custom `WindowManager` view hierarchy.

```
       [Android OS WindowManager]
                   ^
                   | (addView / updateViewLayout)
     +-------------------------------+
     |  LingoBoomOverlayService      | <=== (Foreground Service Notification)
     |  (Native Kotlin Service)      |
     +-------------------------------+
        |                         |
        v                         v
 [Floating 3D Pet View]     [Floating LingoCard View]
  - 150x150 dp surface       - Adaptive width (232-280 dp)
  - Drag listener            - Synced karaoke lyrics
  - Physics floor lerp       - Audio controls (Play/Slow/Rep/Mic)
        ^                         ^
        |                         |
        +------------+------------+
                     |
         Platform Channel Bridge
                     |
                     v
      +-----------------------------+
      |  Flutter Engine / Channels  |
      |  com.lingoboom/overlay      |
      +-----------------------------+
```

---

## 2. WindowManager Configuration

### 2.1. Window Layout Parameters
```kotlin
val layoutParams = WindowManager.LayoutParams(
    WindowManager.LayoutParams.WRAP_CONTENT,
    WindowManager.LayoutParams.WRAP_CONTENT,
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
    } else {
        @Suppress("DEPRECATION")
        WindowManager.LayoutParams.TYPE_PHONE
    },
    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
    PixelFormat.TRANSLUCENT
).apply {
    gravity = Gravity.TOP or Gravity.START
    x = initialX
    y = initialY
}
```

### 2.2. Touch Event Routing (Pass-Through vs. Interception)
- **Pet View Touching:** When touching the pet bounding box (150×150 dp), the touch listener intercepts events, computes relative translation deltas (`dX`, `dY`), and moves the window via `windowManager.updateViewLayout(view, layoutParams)`.
- **Pass-Through Outside:** When the card is collapsed, touches anywhere outside the 150×150 pet area pass directly through to underlying applications without interference.
- **Card Input Focus:** When the user taps the text input field inside LingoCard, the service dynamically clears `FLAG_NOT_FOCUSABLE` so the soft keyboard appears, and restores the flag once input completes.

---

## 3. Foreground Service & Lifecycle Management

### 3.1. Android 14+ Foreground Service Policy
Under Android 14 (API 34) and Android 15, foreground services require explicit type declarations in `AndroidManifest.xml`:
```xml
<service
    android:name=".overlay.LingoBoomOverlayService"
    android:exported="false"
    android:foregroundServiceType="specialUse">
    <property
        android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
        android:value="Floating interactive AI language learning companion" />
</service>
```

### 3.2. Ongoing Notification
Android requires an ongoing notification while the foreground service runs:
- **Title:** "LingoBoom is active"
- **Body:** "Maru is ready to practice Gujarati & English"
- **Actions:** Quick action to "Hide Pet" or "Open App".

---

## 4. Platform Channel Protocol

### 4.1. `MethodChannel("com.lingoboom/overlay_channel")`
- `showOverlay()` — Starts the `LingoBoomOverlayService`.
- `hideOverlay()` — Stops the service and removes views from `WindowManager`.
- `switchCharacter(characterId: String)` — Updates the active 3D model and color theme.
- `setLanguagePair(source: String, target: String)` — Updates displayed language configuration.

### 4.2. `EventChannel("com.lingoboom/overlay_events")`
Streams user actions originating from the native overlay into Flutter:
- `{"event": "pet_tapped"}`
- `{"event": "mic_toggled", "active": true}`
- `{"event": "word_repeated", "spoken_text": "..."}`

