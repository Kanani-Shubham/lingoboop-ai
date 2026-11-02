# LingoBoom — Android Native Floating Pet Overlay Specification

## 1. Overview

The LingoBoom floating pet companion is an Android native `WindowManager` overlay system backed by a persistent Foreground Service (`FloatingPetService.kt`). It provides language learners with an interactive 3D character and companion card accessible on top of third-party apps (e.g. WhatsApp, Chrome, YouTube, Instagram).

---

## 2. Architecture & Components

```
[ Flutter Settings UI ]
       │
       │ MethodChannel: "com.lingoboop.app/overlay"
       ▼
[ MainActivity.kt ]
       │
       │ startForegroundService(Intent)
       ▼
[ FloatingPetService.kt ] (Foreground Service)
       │
       ├─► Notification: "LingoBoom Floating Buddy" (ID: 4040, IMPORTANCE_LOW)
       │
       └─► [ FloatingPetWindowManager.kt ]
             │
             ├─► WindowManager (TYPE_APPLICATION_OVERLAY)
             │     ├─► Draggable 3D Pet WebView (`pet_viewer.html`)
             │     └─► Spotify-Style Floating Conversation Panel
             │
             ├─► Physics: ValueAnimator Horizontal Edge Snapping
             │
             └─► EventChannel: "com.lingoboop.app/overlay_events"
                   └─► Broadcasts taps and state back to Flutter
```

---

## 3. Edge-Snapping Physics Implementation

When the user drags the pet and lifts their finger (`MotionEvent.ACTION_UP`):
1. The pet checks its center coordinate against the screen midpoint (`screenWidth / 2`).
2. If on the left half, target X is set to `margin` (12dp).
3. If on the right half, target X is set to `screenWidth - sizePx - margin`.
4. A `ValueAnimator.ofInt(startX, targetX)` interpolates position over **260ms** with `DecelerateInterpolator()`.
5. The final clamped position is saved into `SharedPreferences` (`lingoboom_overlay_prefs`) so the pet restores its position on subsequent launches.

---

## 4. Android 14 (API 34) Foreground Service Compliance

In accordance with Android 14 FGS requirements:
- **Manifest Permissions:**
  ```xml
  <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>
  ```
- **Service Declaration:**
  ```xml
  <service
      android:name=".overlay.FloatingPetService"
      android:enabled="true"
      android:exported="false"
      android:foregroundServiceType="specialUse|microphone">
      <property
          android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
          android:value="Floating language learning companion and speech practice overlay" />
  </service>
  ```
- **Runtime Notification:** Shows a persistent system notification informing the user that the overlay is active, with a direct intent to return to the main app or dismiss the companion.

---

## 5. OS & OEM Background Execution Notes

- While `FloatingPetService` runs as an official Android foreground service, aggressive OEM battery savers (such as Vivo/iQOO Funtouch OS, Xiaomi MIUI/HyperOS, and Samsung OneUI) can sleep background services after prolonged screen-off periods.
- Users can ensure maximum persistence by toggling **App Battery Usage -> Unrestricted** in Android App Settings.

