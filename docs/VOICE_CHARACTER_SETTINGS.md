# LingoBoop — Voice Character Settings & Synchronization

## 1. Overview

LingoBoop decouples visual companions (the 3D animated pets: Maru the Fox, Mimi the Cat, Bun the Bunny, Pano the Panda, Pip the Penguin, and Leo the Lion) from the audio voice characters (the synthesized voices powered by Gnani Timbre v3.0).

Users can select their preferred visual companion without restricting their voice selection, and choose any voice character without affecting their chosen 3D companion model.

---

## 2. Voice Character Catalog

Available voice options in **Settings > Voice Character**:

### Female Voices:
1. **Shivani (Default):** Natural, warm, and highly expressive. Suitable for everyday conversational tutoring.
2. **Chetana:** Bright, articulate, and cheerful. Ideal for energetic learners.
3. **Kalpana:** Soothing, gentle, and melodic.
4. **Lakshmi:** Clear, classic, and professional.
5. **Riyaa:** Lively, playful, and enthusiastic.
6. **Tarika:** Crisp, modern, and pleasant.
7. **Vasudha:** Rich, melodic, and comforting.

### Male Voices:
8. **Avinash:** Warm, friendly, and confident.
9. **Devansh:** Youthful, energetic, and bright.
10. **Prakash:** Clear, mature, and reassuring.
11. **Shubham:** Natural, casual, and conversational.
12. **Yashraj:** Expressive and dynamic.
13. **Harshad:** Deep, authoritative, and calm.

---

## 3. Architecture & Data Flow

```
[SettingsScreen: User Selects Voice]
         │
         ▼
[CompanionNotifier.setTtsVoice(voiceId)]
         │
         ├──► [UserDataService.saveSelectedVoice(voiceId)]
         │        ├─ SharedPreferences / FlutterSecureStorage ('selected_tts_voice')
         │        └─ Supabase ('user_preferences.tts_voice')
         │
         ├──► [CompanionState.selectedVoice updated]
         │        └─ Used for in-app TTS: SpeechService.synthesizeTTS(voice: state.selectedVoice)
         │
         └──► [OverlayService.updateVoice(voiceId)]
                  └─ MethodChannel('com.lingoboop.app/overlay', 'updateVoice')
                           │
                           ▼
                  [MainActivity.kt -> FloatingPetService]
                           │
                           ▼
                  [FloatingPetWindowManager.updateVoice(voice)]
                           │
                           ├─ SharedPreferences ('selected_tts_voice')
                           └─ Injected into floating PolyCard TTS synthesis requests
```

---

## 4. In-App Settings User Experience

- **Voice Character Section:** Displays all verified voices with their gender badges and tonal descriptions.
- **Visual Radio/Checkmark:** Displays the currently active voice.
- **Language Selector:** Users can select preview phrases in English (`en-IN`), Gujarati (`gu-IN`), or Hindi (`hi-IN`).
- **Interactive "Play Demo" Button:** Synthesizes the sample phrase in real-time, displays a circular loading spinner while fetching, and plays with an active playing badge that can be toggled to stop mid-playback.
- **Strict Independence:** Switching the companion pet in the Companion/Language modal does not touch `selectedVoice`. Switching the voice in Settings does not touch `activePet`.
