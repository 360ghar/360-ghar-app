# Repository Guidelines

> **Canonical guide: [CLAUDE.md](./CLAUDE.md).** Read it first for stack, structure, commands, and conventions.

## Project Structure & Module Organization
- `lib/`: Flutter source using feature-first GetX layers with clean architecture.
  - Features: `lib/features/<feature>/{views,controllers,bindings}` (e.g., `discover`, `profile`).
  - Shared: `lib/core/` (`core/data/models`, providers, routing, `core/widgets`).
- `assets/`: images and static files (declare in `pubspec.yaml`).
- Platforms: `android/`, `ios/`, `web/` for configs and builds.
- Config: local `.env.*` (gitignored). For bare `flutter run`, run `dart run tool/sync_dev_env.dart` after env edits. Or use `./tool/run_with_env.sh` / `--dart-define-from-file=.env.development`. Never package env as Flutter assets.
- Lint: `analysis_options.yaml` defines rules used by CI/local.

## Build, Test, and Development Commands
- Install deps: `flutter pub get` — fetches packages.
- Run app: `flutter run -d <device_id>` — launches on simulator/device.
- Analyze: `flutter analyze` — static checks; fix all warnings.
- Format: `dart format .` — apply standard Dart formatting.
- Codegen: `flutter pub run build_runner build --delete-conflicting-outputs` — generates `*.g.dart`.
- Tests: `flutter test` — run unit/widget tests locally.
- Releases: `flutter build apk` / `flutter build ios` — production builds.

## Coding Style & Naming Conventions
- Indentation: 2 spaces; follow `analysis_options.yaml`.
- Files: `snake_case.dart` (e.g., `property_details_view.dart`).
- Classes: `UpperCamelCase` (PascalCase); variables/methods: `lowerCamelCase`.
- Suffixes: `*_view.dart`, `*_controller.dart`, `*_binding.dart`.
- Placement: new screens under `lib/features/<feature>/...`; shared utilities in `lib/core/`.

## Testing Guidelines
- Framework: Flutter/Dart tests.
- Location: `test/` mirrors `lib/` paths; name files `*_test.dart`.
- Types: widget tests for views; unit tests for controllers/services and business logic.
- Run: `flutter test` (use `--plain-name` to filter when needed).

## Commit & Pull Request Guidelines
- Commits: imperative, scope-first (e.g., "Refactor filters: unify models"). Keep them focused.
- Before PR: run `flutter analyze`, `dart format .`, `flutter test`, and regenerate code (`build_runner`).
- PRs: include summary, linked issues, test plan, and screenshots for UI changes. Note any env/config or docs updates. Keep changes minimal.

## Security & Configuration
- Never hardcode secrets; load via `.env.*` or secure stores.
- When adding assets, update `pubspec.yaml` and verify both dev/prod configs.
- Mobile auth/session handling should remain Supabase-native using `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY`.

## UI Guidelines - Notifications & Toasts

**ALWAYS use `AppToast` for all notifications/toasts** - Never use `Get.snackbar()` directly.

Located in `lib/core/utils/app_toast.dart`:
- **Position**: All toasts appear at `SnackPosition.TOP` (never bottom)
- **Minimal styling**: Compact padding, 8px border radius, 3s duration
- **Consistent appearance**: Unified colors via `AppDesign` tokens

### Usage Examples:
```dart
// Success message
AppToast.success('Profile saved', 'Your changes have been saved');

// Error message
AppToast.error('Error', 'Failed to load data');

// Warning message
AppToast.warning('Warning', 'Please check your connection');

// Info message
AppToast.info('Info', 'New features available');

// Custom styling (rarely needed)
AppToast.custom(
  title: 'Custom',
  message: 'Your message here',
  backgroundColor: AppDesign.primaryYellow,
  duration: const Duration(seconds: 2),
);
```

### Migration from Get.snackbar:
```dart
// ❌ DON'T use Get.snackbar directly
Get.snackbar('Error', 'Failed to load', snackPosition: SnackPosition.BOTTOM);

// ✅ DO use AppToast
AppToast.error('Error', 'Failed to load');
```
