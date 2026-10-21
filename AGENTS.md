# Repository guidelines

Read [CLAUDE.md](./CLAUDE.md) first for the architecture, commands, native build
requirements, and release rules. Read the workspace guide for the personal GitHub
account requirement. Preserve unrelated uncommitted native/release changes.

## Structure and ownership

`lib/features/<feature>/` contains focused `application`, `data`, and
`presentation` code. Shared models, providers, transport, storage, routing,
localization, design, and widgets live under `lib/core/`. Follow existing paths;
do not create empty layers to match a template.

Use manual Riverpod providers and immutable state. Widgets watch state and call
notifiers. Repositories use constructor injection. Text/focus/form/scroll/animation
controllers remain local to widgets. Register resource cleanup with the owner.
Reject asynchronous results after account/input changes or disposal. Inactive shell
branches can remain mounted and must stop active media and streams explicitly.

Use `MaterialApp.router` / GoRouter and the shared route policy. Presentation code
navigates through its `BuildContext`; state owners do not navigate. Do not add
bindings, global service lookup, navigation timers, or duplicate authoritative state.

## Persistence and failures

`AppDatabase` is the application SQLite owner. It stores preferences, scoped caches,
drafts, and durable actions. Await persistence and expose write failure with retry.
Supabase owns credentials. The legacy GetStorage importer is read-only and is the
only legacy storage boundary. See [persistence.md](./docs/persistence.md).

Disable automatic provider retry. HTTP owns bounded safe read retries. Do not
replay mutations without a verified server contract. Visit creation remains an
explicit reconciliation flow after an ambiguous result. Account changes must
invalidate scope before cleanup and preserve account ownership of pending actions.

## UI and localization

Use `context.design`, theme typography, and `context.l10n.text(...)`. Add English
and Hindi messages together in `app_messages.dart`. Keep data failures typed and
map them to localized safe UI text. Do not show raw exception text.

Use `AppToast` for brief top-of-screen feedback; `AppToastHost` owns the overlay.
Recoverable load, save, and pending-operation errors need persistent inline state
and retry. Preserve form input and usable content during failure or refresh. Check
both themes, 320-pixel width, 2x text, keyboard insets, and reduced motion.

## Commands and checks

1. Resolve dependencies with `flutter pub get`. After resolution or clean, run
   `./tool/verify_ios_release.sh --fix` before Xcode build/archive (iOS uses SPM).
2. Format changed files with `dart format <paths>` and run `flutter analyze`.
3. Run focused `flutter test <paths>`, then the required full suite and coverage.
   Keep the CI 85% coverage gate. Do not bypass layout or runtime assertions.
4. Run `dart run build_runner build --delete-conflicting-outputs` when JSON models
   change. Providers are manual and do not use code generation.
5. Follow [shorebird.md](./docs/shorebird.md) for store release/patch builds.
   Verification does not authorize a release, push, or production write.

Use ProviderContainer/ProviderScope overrides and feature test harnesses. Native
platform fakes complement available native checks; they do not replace them.
Record behavior mappings when removing architecture-specific tests. See the
[migration checklist](./docs/migration/riverpod-checklist.md) for completed verification
and remaining device and credential checks.

## Style and security

Use two spaces, `snake_case.dart` files, `UpperCamelCase` types, and `lowerCamelCase`
members. Keep edits focused. Do not preserve obsolete compatibility wrappers.
Never log tokens, passwords, OTPs, OAuth payloads, profile data, or exact location.
Local `.env.*` files are ignored and never packaged as assets. Use
`dart run tool/sync_dev_env.dart`, `./tool/run_with_env.sh`, or dart defines for local
configuration. Authentication uses the Supabase publishable key.
