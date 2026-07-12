# 360Ghar - Flutter Real Estate App

![Flutter](https://img.shields.io/badge/Flutter-3.44+-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.12+-blue?logo=dart)
![GetX](https://img.shields.io/badge/State%20Management-GetX-orange)
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
-   **State Management:** [GetX](https://pub.dev/packages/get) (for state, dependency, and route management)
-   **Backend:** [Supabase](https://supabase.io/) (Authentication, Database) + [Cloudinary](https://cloudinary.com/) (Storage)
-   **Mapping:** [flutter_map](https://pub.dev/packages/flutter_map)
-   **Code Generation:** [json_serializable](https://pub.dev/packages/json_serializable) for type-safe models
-   **Local Storage:** [get_storage](https://pub.dev/packages/get_storage)
-   **UI:** [Google Fonts](https://pub.dev/packages/google_fonts), [CachedNetworkImage](https://pub.dev/packages/cached_network_image), [Shimmer](https://pub.dev/packages/shimmer)

### Architecture

The codebase is structured using a **GetX Clean Architecture** pattern, separating the application into two main parts:

-   `lib/core`: Contains shared application logic, infrastructure, and base components. This includes API services, data models, repositories, global controllers (Auth, Theme), routing, and common widgets.
-   `lib/features`: Each distinct feature of the app (e.g., `discover`, `explore`, `profile`) is a self-contained module with its own views, controllers, and bindings.

```
lib/
├── core/                  # Core infrastructure and shared components
│   ├── bindings/          # Global dependency injection
│   ├── controllers/       # Core business logic (Auth, Location, Theme)
│   ├── data/              # Models, Providers, Repositories
│   ├── routes/            # App navigation configuration
│   └── ...
├── features/              # Feature-based modules
│   ├── auth/              # Authentication and profile completion
│   ├── discover/          # Property discovery and swipe functionality
│   ├── explore/           # Map exploration feature
│   ├── likes/             # Liked/passed properties management
│   └── ...
└── main.dart              # App entry point
```

## 🚀 Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

-   Flutter SDK (version 3.x or higher)
-   Dart SDK (version 3.x or higher)
-   An editor like VS Code or Android Studio

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/360ghar-flutter.git
    cd 360ghar-flutter
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

-   **Profile:** User management, settings, and preferences.
-   **Explore:** Map view with property markers for geographical discovery.
-   **Discover (Home):** The main swipe interface for liking or passing on properties.
-   **Likes:** A gallery of your favorited and passed properties.
-   **Visits:** Manage agent appointments and scheduled property tours.

## 🔔 iOS Push Troubleshooting

If iOS logs show APNS/FCM token issues (for example `apns-token-not-set`), follow:

- `docs/ios_push_debug.md`

## 🤝 Contributing

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
