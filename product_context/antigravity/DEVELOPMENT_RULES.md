# LingoBoom — Engineering Standards & Development Rules

**Status:** Mandatory for all engineering contributions across all phases.

---

## 1. Architectural Guardrails

1. **Clean Architecture Separation:**
   Code must follow strict layer separation:
   - `presentation/` — Widgets, screens, state notifiers, animation controllers.
   - `domain/` — Pure Dart business entities, value objects, and repository interfaces (zero external SDK dependencies).
   - `data/` — API clients, Drift database DAOs, Supabase queries, and DTO mappers.
2. **State Management Protocol (Riverpod):**
   - Use `AsyncNotifierProvider` / `NotifierProvider` from `flutter_riverpod`.
   - Never perform side effects or network requests directly inside widget `build()` methods.
3. **Provider Secret Safety (NON-NEGOTIABLE):**
   - NEVER embed Gnani API keys, Supabase service-role keys, or Razorpay secrets in Flutter client code or Git repository.
   - All external AI calls must route through the FastAPI backend.
4. **Android Overlay Independence:**
   - The native Kotlin overlay service must handle its own lifecycle gracefully.
   - If the main Flutter app is killed by the system, the overlay service must continue functioning or cleanly tear down without crashing.
5. **Preservation of Design Integrity:**
   - The visual style established in `polypet-demo.html` (palette, Fredoka typography, floating docking logic, synced word highlights) is the gold standard. Do not improvise unapproved visual overhauls.

---

## 2. Coding Conventions

- **Dart:** Strict linting enforced by `flutter_lints`. All public classes, methods, and providers must have concise documentation comments.
- **Kotlin:** Idiomatic Kotlin with coroutines, null-safety, and standard Android lifecycle bindings.
- **Python (Backend):** Python 3.11+ type hints, Pydantic v2 data models, async route handlers, Ruff linting.
- **Git Commits:** Conventional commits format (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`).

