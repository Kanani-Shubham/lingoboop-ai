# LingoBoom — Immediate Next Steps for Phase 1 Approval

**Current Phase:** Phase 0 (Workspace Organization, Asset Audit & Technical Analysis) — **COMPLETE**  
**Next Phase:** Phase 1 (Flutter Foundation & Clean Architecture) — **AWAITING USER APPROVAL**

---

## 1. Prerequisites Checklist Before Proceeding to Phase 1

1. **User Sign-Off on Phase 0 Audit:**
   - Confirm satisfaction with the 6 active characters (`Maru`, `Mimi`, `Pano`, `Bun`, `Pip`, `Leo`) and their 8 verified animations.
   - Confirm alignment with the technical architecture: Flutter + Native Kotlin Overlay + FastAPI Backend + Supabase + Gnani AI suite.
   - Confirm subscription pricing model: Free tier vs. ₹9/month and ₹49/year premium tiers.

2. **Backend & Cloud Setup (Preparation for Phase 2 & 6):**
   - Create Supabase project and record `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
   - Acquire Gnani.ai developer account credentials for Prisma v3.0, Timbre, and Evon.
   - Populate local `.env` from `.env.example`.

---

## 2. Action Items for Phase 1 (Once Approved)

Upon explicit user confirmation, Phase 1 will execute the following steps:
1. **Directory Structure Initialization:**
   Create clean architecture directories in `lib/`:
   ```
   lib/
   ├── core/
   │   ├── constants/
   │   ├── network/
   │   ├── platform/
   │   └── utils/
   ├── theme/
   │   ├── app_colors.dart
   │   ├── app_typography.dart
   │   └── character_themes.dart
   ├── router/
   │   └── app_router.dart
   ├── features/
   │   ├── auth/
   │   ├── characters/
   │   ├── overlay/
   │   ├── practice/
   │   └── profile/
   └── main.dart
   ```
2. **Install Core Dependencies in `pubspec.yaml`:**
   - `flutter_riverpod`, `go_router`, `google_fonts`, `flutter_secure_storage`.
3. **Establish Character Dynamic Theming:**
   - Implement `CharacterThemes` provider mapping the 6 active characters (`Maru` #c4571c, `Mimi` #6a4cc4, etc.) to dynamic Material 3 ColorSchemes.
4. **Setup Fredoka Typography:**
   - Configure Google Fonts `Fredoka` font loader matching the prototype typography hierarchy.
5. **Verify Baseline Tests:**
   - Write unit tests for router guards and theme providers.

