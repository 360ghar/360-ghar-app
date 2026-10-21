# 360Ghar - Flutter Real Estate App

![Flutter](https://img.shields.io/badge/Flutter-3.44+-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.12+-blue?logo=dart)
![Riverpod](https://img.shields.io/badge/State%20Management-Riverpod-blue)
![Supabase](https://img.shields.io/badge/Backend-Supabase-green?logo=supabase)

**360Ghar** is a modern Flutter real estate application that revolutionizes property discovery with a **Bumble-inspired swipe interface**. It offers an engaging, intuitive way for users to find their dream homes, complete with 360° virtual tours, detailed property information, and seamless agent communication.

## ✨ Features

-   **Bumble-Style Swiping:** Like or pass on properties with a simple swipe.
-   **360° Virtual Tours:** Immerse yourself in properties with integrated virtual tours.
-   **Advanced Filtering:** Narrow down searches by price, location, property type, amenities, and more.
-   **Map Exploration:** Discover properties visually on an interactive map.
-   **User Authentication:** Secure sign-up, login, and profile management powered by Supabase.
-   **Likes & History:** Keep track of liked and passed properties.
-   **Visit Scheduling:** Schedule property visits directly through the app.
-   **Detailed Property Views:** Access comprehensive information, images, and amenities for each listing.
-   **Clean Architecture:** Organized into `core` and `features` modules for scalability and maintainability.
-   **Light & Dark Mode:** Beautifully crafted themes for user preference.
-   **Localization:** Multi-language support (English & Hindi).

## 🛠️ Tech Stack & Architecture

This project is built with a modern, scalable technology stack and follows a clean, feature-first architecture.

-   **Framework:** [Flutter](https://flutter.dev/)
-   **State Management:** [Riverpod](https://pub.dev/packages/flutter_riverpod) with manual providers and immutable state
-   **Navigation:** [GoRouter](https://pub.dev/packages/go_router) with five stateful shell branches
-   **Backend:** [Supabase](https://supabase.io/) (Authentication, Database) + [Cloudinary](https://cloudinary.com/) (Storage)
-   **Mapping:** [MapLibre](https://pub.dev/packages/maplibre_gl)
-   **Code Generation:** [json_serializable](https://pub.dev/packages/json_serializable) for type-safe models
-   **Transport:** [http](https://pub.dev/packages/http) through injected API and SSE clients
-   **Local Storage:** SQLite through `AppDatabase`, with scoped caches, drafts, and durable pending actions
-   **UI:** Bundled fonts, Flutter localization for English and Hindi, shared design tokens, [CachedNetworkImage](https://pub.dev/packages/cached_network_image), and [Shimmer](https://pub.dev/packages/shimmer)

### Architecture

The app uses a feature-first structure. Riverpod owns shared state and dependencies. Widgets own local form, focus, scroll, animation, and media presentation state.

-   `lib/core`: Shared models, repository contracts, providers, transport, storage, routing, localization, and widgets.
-   `lib/features`: Feature application state, injected repositories and datasources, views, and widgets. Existing `presentation/controllers` directories contain manual Riverpod Notifiers.

```
lib/
├── core/                  # Core infrastructure and shared components
│   ├── providers/         # Database, network, and authentication composition
│   ├── controllers/       # Session, settings, and durable queue owners
│   ├── data/              # Shared models and injected repository contracts
│   ├── storage/           # AppDatabase and read-only legacy preference import
│   ├── routes/            # GoRouter and redirect/link policy
│   └── ...
├── features/              # Feature-based modules
│   ├── auth/              # Authentication and profile completion
│   ├── discover/          # Property discovery and swipe functionality
│   ├── explore/           # Map exploration feature
│   ├── likes/             # Liked/passed properties management
│   └── ...
└── main.dart              # App entry point
```

Use `ProviderScope`, constructor injection, and manual `Provider`, `NotifierProvider`, or `AsyncNotifierProvider` declarations. Dispose owned resources with the provider or widget lifecycle. Provider retries are disabled at the root; the transport owns bounded retries for safe reads. Mutations require an explicit replay contract.

Keep existing content during refresh or pagination errors. Return typed failures from data boundaries and translate them in presentation code with `context.l10n`. Capture the account scope before asynchronous work and reject stale results after account or input changes.

See [CLAUDE.md](CLAUDE.md) for contributor conventions, [the persistence policy](docs/persistence.md) for cache and migration rules, and [the migration checklist](docs/migration/riverpod-checklist.md) for verification status. Tests use provider overrides and injected fakes; storage and queue tests use SQLite fixtures. Run `flutter analyze` and `flutter test --coverage`; keep the 85% coverage gate.

## 🚀 Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

-   Flutter SDK (version 3.x or higher)
-   Dart SDK (version 3.x or higher)
-   An editor like VS Code or Android Studio

### Installation

1.  **Clone the repository:**
    ```bash
    git clone git@github.com:360ghar/360-ghar-app.git
    cd 360-ghar-app
    ```

2.  **Set up environment variables:**
    Create a gitignored `.env.development` from the template (local only — **not** packaged into the app):
    ```bash
    cp .env.development.example .env.development
    # optional for release builds:
    cp .env.production.example .env.production
    ```
    Fill in Supabase, API, Places, and other values. **Do not commit these files.**

    `.env` files are **not** Flutter assets (shipping them in the APK/IPA is a secret leak).

3.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

4.  **Sync local env into debug config (once, and after editing `.env*`):**
    ```bash
    dart run tool/sync_dev_env.dart
    ```
    This fills a debug-only map so bare `flutter run` works. Do **not** commit
    secrets in `lib/core/config/dev_env.g.dart` (pre-commit blocks it).

5.  **Run code generation:**
    The project uses `json_serializable` for data models. Run the build runner to generate the necessary files:
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```
    If you plan to modify models, run the watcher:
    ```bash
    dart run build_runner watch --delete-conflicting-outputs
    ```

6.  **Run the application:**
    ```bash
    # Plain run (debug uses synced .env.development)
    flutter run

    # Or inject defines explicitly:
    ./tool/run_with_env.sh
    # flutter run --dart-define-from-file=.env.development
    ```

Notes:
- Secrets must never be committed. `.env.*` and `.dart_defines*.json` are git-ignored.
- VS Code / Cursor pass `--dart-define-from-file=.env.development` via workspace settings.
- Restrict Google Places API keys by Android package/SHA and iOS bundle ID in Google Cloud.

## 📱 Bottom Navigation

The app features a 5-tab bottom navigation bar for easy access to key features:

-   **Discover (Home):** The main swipe interface for liking or passing on properties.
-   **Explore:** Map view with property markers for geographical discovery.
-   **Saved:** Liked and passed properties, with controls for pending actions.
-   **Visits:** Manage agent appointments and scheduled property tours.
-   **Profile:** User management, settings, and preferences.

Assistant is available from labeled entries in Discover and Profile. Each primary destination preserves its own navigation history.

## 🔔 iOS Push Troubleshooting

If iOS logs show APNS/FCM token issues (for example `apns-token-not-set`), follow:

- `docs/ios_push_debug.md`

## 🤝 Contributing

For optional web research while developing the app, see the
[Parallel Search MCP setup guide](docs/parallel_research.md).

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## 🔧 Code Style & Quality

This project enforces consistent formatting and linting across all environments.

### Formatter & Lint Configuration

- **Formatter**: `dart format` with page width of 100 characters
- **Linter**: `flutter_lints` with additional rules:
  - `directives_ordering`: Import organization
  - `require_trailing_commas`: Consistent trailing commas
  - `avoid_print`: Use logging instead
  - `prefer_const_constructors`: Use const where possible
  - `prefer_single_quotes`: Use single quotes for strings

### Setup Instructions

1. **FVM (Flutter Version Manager)**:
   ```bash
   dart pub global activate fvm
   fvm install
   ```

2. **Pre-commit hooks**:
   ```bash
   pip install pre-commit
   pre-commit install
   ```

#### Cross-Platform Hooks (Windows/macOS/Linux)

Pre-commit hooks run via a Python wrapper to ensure they work the same on all systems:

- Entry point: `hooks/flutter_tools.py` (no bash required)
- Format: runs `fvm dart format` → `dart format` → `flutter format` (first available)
- Analyze/Test: runs `fvm flutter` → `flutter` (first available)
- Run on demand: `pre-commit run --all-files`

Notes:
- Ensure Python 3 is installed (required by pre-commit).
- FVM is optional but recommended for consistent Flutter/Dart versions.
- Line endings are normalized via `.gitattributes` and a pre-commit mixed-line-ending hook (Windows scripts keep CRLF; shell scripts use LF).

3. **VS Code**:
   - Format on save is enabled
   - Line endings set to LF
   - Ruler at 100 characters

### CI/CD

- GitHub Actions runs on every PR and push
- Checks formatting (`dart format --set-exit-if-changed`)
- Runs static analysis (`flutter analyze`)
- Executes tests (`flutter test`)

### Manual Commands

```bash
# Format code
dart format .

# Check formatting
dart format -o none --set-exit-if-changed .

# Analyze code
flutter analyze

# Apply automatic fixes
dart fix --apply
```

## 📄 License

This project is licensed under the MIT License - see the `LICENSE` file for details.

---
