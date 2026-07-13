# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ghar360** is a Flutter real estate application using GetX for state management with a Bumble-inspired swipe interface design. The app transforms property browsing into an engaging, dating-app-like experience with 360° virtual tours, exact location mapping, and detailed property information.

## Common Development Commands

### Build and Run
```bash
# Run the app in development mode
flutter run

# Run on specific device
flutter run -d ios
flutter run -d android

# Run with specific flavor
flutter run --flavor development
flutter run --flavor production

# Hot reload during development
# Press 'r' in terminal or use IDE hot reload
```

### Code Generation
```bash
# Generate model files (after modifying JSON serializable models)
dart run build_runner build

# Watch for changes and auto-generate
dart run build_runner watch

# Clean generated files
dart run build_runner clean

# Force regenerate with conflict resolution
dart run build_runner build --delete-conflicting-outputs
```

### Testing and Quality
```bash
# Run unit and widget tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage

# Generate coverage report
genhtml coverage/lcov.info -o coverage/html

# Analyze code for issues
flutter analyze

# Fix lint issues automatically
dart fix --apply

# Format code according to Dart style
dart format .

# Check dependencies for updates
flutter pub outdated

# Update dependencies
flutter pub upgrade
```

### Build for Production
```bash
# Build APK for Android
flutter build apk --release

# Build App Bundle for Google Play
flutter build appbundle --release

# Build for iOS
flutter build ios --release

# Build for web
flutter build web
```

### Platform-Specific Setup
```bash
# Clean Flutter build cache
flutter clean

# Get all dependencies (iOS native plugins resolve via Swift Package Manager)
flutter pub get
```

## Architecture Overview

### GetX Clean Architecture Pattern
The app follows a Core vs. Features modular architecture with clear separation of concerns:

```
lib/
├── core/                  # Core infrastructure and shared components
│   ├── bindings/          # Global dependency injection
│   │   └── initial_binding.dart
│   ├── controllers/       # Core business logic controllers
│   │   ├── auth_controller.dart         # Authentication management
│   │   ├── app_update_controller.dart   # App update management
│   │   ├── filter_service.dart          # Filtering and search service
│   │   ├── localization_controller.dart # Multi-language support
│   │   ├── location_controller.dart     # Location services
│   │   ├── offline_queue_service.dart   # Offline request queue
│   │   ├── page_state_service.dart      # Page state management
│   │   └── theme_controller.dart        # Theme management (light/dark)
│   ├── data/
│   │   ├── models/        # Data models with JSON serialization
│   │   ├── providers/     # API clients and data sources
│   │   └── repositories/  # Data access layer
│   ├── middlewares/       # Route guards and interceptors
│   ├── mixins/            # Reusable behavior mixins
│   ├── routes/            # Navigation configuration
│   ├── translations/      # Internationalization
│   ├── utils/             # Theme, constants, helpers, error handling
│   └── widgets/           # Core shared widgets
├── features/              # Feature-based modules
│   ├── auth/              # Authentication and profile completion
│   ├── booking/           # Property booking system
│   ├── dashboard/         # Dashboard feature
│   ├── discover/          # Property discovery and swipe functionality
│   ├── explore/           # Map exploration feature
│   ├── filters/           # Advanced filtering system
│   ├── likes/             # Liked/passed properties management
│   ├── location_search/   # Location search functionality
│   ├── onboarding/        # App onboarding flow
│   ├── profile/           # User profile management
│   ├── property_details/  # Property details view
│   ├── property_details/  # Property details view
│   ├── splash/            # Splash screen
│   ├── tour/              # 360° tour feature
│   └── visits/            # Property visits management
├── widgets/               # Reusable UI components
│   ├── common/            # Common widgets
│   ├── navigation/        # Navigation components
│   ├── property/          # Property-specific widgets
│   └── splash/            # Splash-specific widgets
├── main.dart             # App entry point
└── root.dart             # Root authentication state router
```

### Key Architecture Components

#### 0. Root Authentication Router (`lib/root.dart`)
The app uses a centralized authentication state router that manages the entire app's authentication flow:
- **Root Widget**: Listens to `AuthController.authStatus` and routes users to appropriate screens
- **AuthStatus States**: `initial`, `authenticated`, `unauthenticated`, `requiresProfileCompletion`, `error`
- **Dynamic Controller Registration**: Registers controllers only when needed for performance optimization
- **Error Handling**: Provides retry and logout options for authentication errors

#### 1. Controllers (GetX State Management)

**Core Controllers** (`lib/core/controllers/`):
- **AuthController**: User authentication and session management (phone-based login with OTP)
- **LocationController**: Handles location permissions and GPS services
- **LocalizationController**: Multi-language support and localization
- **ThemeController**: Light/dark theme management and user preferences
- **PageStateService**: Manages page state across app navigation

**Feature Controllers** (`lib/features/*/controllers/`):
- **DashboardController**: Manages dashboard data and navigation (`features/dashboard/`)
- **DiscoverController**: Property discovery main interface with integrated swipe mechanics (`features/discover/`)
- **ExploreController**: Map functionality and location-based exploration (`features/explore/`)
- **LikesController**: Manages liked/passed properties and favorites (`features/likes/`)
- **VisitsController**: Property visits and scheduling management (`features/visits/`)
- **ProfileControllers**: Multiple controllers for profile management (`features/profile/`)
- **PhoneEntryController**: Phone number entry logic (`features/auth/`)
- **LoginController**: Phone-based authentication with OTP verification (`features/auth/`)

#### 2. Data Layer (`lib/core/data/`)
- **Models** (`core/data/models/`): JSON serializable with `json_annotation`
  - **PropertyModel**: Complete property data with images, pricing, and features
  - **PropertyImageModel**: Property image metadata and URLs
  - **UserModel**: User authentication and profile details
  - **BookingModel**: Property booking and scheduling data
  - **VisitModel**: Property visit tracking and management
  - **FiltersModel**: Search and filter parameters
  - **SwipeHistoryModel**: User swipe interactions tracking
  - **UnifiedFilterModel**: Advanced filtering system
  - **UnifiedPropertyResponse**: API response wrapper for properties
  - **AppUpdateModel**: App update information
  - **AgentModel**: Real estate agent information
- **Providers** (`core/data/providers/`): 
  - **ApiService**: Primary API integration with error handling and authentication
- **Services** (`core/services/`):
  - **Auth/session tokens**: Managed by the Supabase SDK (`supabase_flutter`) rather than a custom secure-storage manager
  - **DeepLinkService**: Handles deep links and navigation
- **Repositories** (`core/data/repositories/`): Abstraction layer between controllers and data sources
  - **PropertiesRepository**: Property data access, caching, and filtering
  - **SwipesRepository**: Swipe interaction tracking and history
  - **ProfileRepository**: User profile data management and updates
  - **AuthRepository**: Authentication data handling and token management (`features/auth/data/`)
  - **AppUpdateRepository**: App update data access

#### 3. Module Structure
**Core Infrastructure** (`lib/core/`):
```
core/
├── bindings/          # Global dependency injection
├── controllers/       # Core business logic controllers
├── data/             
│   ├── models/        # Shared data models
│   ├── providers/     # API clients and data sources
│   └── repositories/  # Data access layer
├── middlewares/       # Route guards and interceptors
├── mixins/            # Reusable behavior mixins
├── routes/            # Navigation configuration
├── translations/      # Internationalization
├── utils/             # Shared utilities and helpers
└── widgets/           # Core shared widgets
```

**Feature Modules** (`lib/features/<feature_name>/`):
Each feature follows the same pattern:
```
feature_name/
├── bindings/
│   └── feature_binding.dart
├── controllers/
│   └── feature_controller.dart
├── views/
│   └── feature_view.dart
└── widgets/           # Feature-specific widgets (if needed)
    └── feature_widget.dart
```

#### 4. Swipe Mechanics (Bumble-Style)
**Core Implementation**: Located in `lib/features/discover/widgets/`:
- **SwipeStack**: Main swipe container with card stack management
- **PropertySwipeCard**: Individual property cards with swipe gestures
- **DiscoverController**: Handles swipe logic and state management (integrated into main discover controller)

**Swipe Actions**:
- **Swipe Right**: Like property (mark as favorite)
- **Swipe Left**: Pass on property (mark as not interested)  
- **Swipe Up**: Quick view details (navigate to property details)
- **Double Tap**: Super like (priority interest)

**Visual Feedback**:
- **Rotation**: ±12° during drag
- **Scaling**: 0.98x during interaction
- **Color Hints**: Green for like, red for pass
- **Overlay Badges**: LIKE / PASS / DETAILS / SUPER using AppTheme colors
- **Animation**: Spring curve for completion, snap-back on cancel

**Data Integration**:
- Records all swipe actions via `SwipesRepository.logSwipe(propertyId, action)`
- Updates favorites through `LikesController` for like actions
- Navigates to property details for swipe up actions
- Supports undo functionality for last swipe action

### Navigation System
- **GetX routing** with named routes
- **AuthMiddleware** for protected routes (`core/middlewares/auth_middleware.dart`)
- **Bottom navigation** with 5 tabs: **Profile → Explore → Discover → Likes → Visits** (Order: 0, 1, 2, 3, 4)
  - **Profile**: User management and preferences
  - **Explore**: Map view with property markers  
  - **Discover**: Main swipe interface (center/home position)
  - **Likes**: Favorited and passed properties
  - **Visits**: Agent appointments and scheduled tours
- **Route definitions** in `core/routes/app_routes.dart`
- **Page configuration** in `core/routes/app_pages.dart` using `GetPage` with bindings
- **Deep linking** support for sharing properties and direct navigation
- **Localized navigation** with multi-language support
- **Navigation consistency**: Tabs available across primary screens via `lib/widgets/navigation/bottom_nav_bar.dart`

## Theme and Design System

### Bumble-Inspired Color Palette
Defined in `lib/core/utils/theme.dart` and `lib/core/utils/app_colors.dart`:
- **Primary**: `Color(0xFFFFBC05)` (Bumble yellow)
- **Accent**: `Color(0xFFFF6B35)` (Real estate orange), `Color(0xFF4A90E2)` (trust blue), `Color(0xFF50C878)` (success green)
- **Background**: `Color(0xFFFFFFFF)` and `Color(0xFFF8F9FA)`
- **Text**: Dark `Color(0xFF2C2C2C)`, Gray `Color(0xFF666666)`, Light `Color(0xFF999999)`
- **Status**: Success `Color(0xFF28A745)`, Warning `Color(0xFFFFC107)`, Error `Color(0xFFDC3545)`

**IMPORTANT**: Never use hardcoded `Colors.*` - always use `AppTheme`/`AppColors` constants.

### Dark Theme Support
Complete dark theme implementation with:
- **Dark backgrounds**: `Color(0xFF000000)` and `Color(0xFF1C1C1E)`
- **Dark surfaces**: `Color(0xFF2C2C2E)` for cards and components
- **Adaptive text**: `Color(0xFFFFFFFF)` primary, `Color(0xFFE5E5E7)` secondary
- **Consistent accent colors**: Primary yellow maintained across themes

### Typography
- **Google Fonts Inter** integration
- **Responsive text scales** for different screen sizes
- **Consistent spacing** and letter spacing
- **Dark theme aware** text colors

## API Integration

### Backend Services
The app supports multiple backend integrations:
- **Supabase**: Backend as a Service with PostgreSQL database, real-time subscriptions, and authentication
- **Real API**: Production backend with full CRUD operations
- **Development**: Environment-based configuration switching
- **Error Handling**: Centralized error management with user-friendly messages
- **Authentication**: Token-based authentication system with Supabase Auth

### API Service Architecture
Located in `lib/core/data/providers/api_service.dart`:
- Uses Dart's built-in `http` package for HTTP requests
- Centralized error handling with comprehensive exception types (`ApiException`, `ApiAuthException`)
- Response wrapper with type-safe `ApiResponse<T>` and `PaginatedResponse<T>` classes
- Authentication token management integrated with Supabase Auth
- Environment-based endpoint configuration with timeout support
- Comprehensive error mapping and user-friendly error handling

### Supabase Integration
The app uses Supabase as the primary backend service:
- **Database**: PostgreSQL database for property listings, user profiles, and bookings
- **Authentication**: Built-in authentication with social login support
- **Real-time**: Live updates for property availability and new listings
- **Storage**: File storage via Cloudinary (accessed through backend API) for property images and user avatars
- **Row Level Security**: Database-level security policies for data protection

## Environment Configuration

### Environment Files
- **`.env.development` / `.env.production`**: Local-only (gitignored). **Never** package as Flutter assets.
- **Local debug:** `dart run tool/sync_dev_env.dart` then bare `flutter run` (debug map in `lib/core/config/dev_env.g.dart`; do not commit secrets).
- Or inject via `--dart-define` / `--dart-define-from-file` (`./tool/run_with_env.sh` or VS Code `flutterRunAdditionalArgs`).
- Runtime access: `AppConfig.instance` in `lib/core/config/app_config.dart`.

### Required Environment Variables
```bash
# Via dart-define / dart_defines.json (from local .env)
# API Configuration
API_BASE_URL=https://api.360ghar.com
API_TIMEOUT_SECONDS=15  # Optional: override HTTP client timeout

# Supabase Configuration
SUPABASE_URL=your_supabase_project_url_here
SUPABASE_PUBLISHABLE_KEY=your_supabase_publishable_key_here

# Google Places API Key
GOOGLE_PLACES_API_KEY=your_google_places_api_key_here

# App Configuration
DEFAULT_COUNTRY=in
DEBUG_MODE=true
LOG_API_CALLS=true
```

### Platform Support
- **iOS**: Minimum deployment target iOS 14.0
- **Android**: Minimum SDK version 21
- **Web**: Chrome support enabled

## Key Dependencies

### Core Framework
- **flutter**: SDK framework
- **get**: ^4.6.6 - State management and routing
- **json_annotation**: ^4.9.0 / **json_serializable**: ^6.7.1 - Model serialization
- **http**: ^1.2.2 - HTTP client for API calls
- **supabase_flutter**: ^2.10.0 - Backend as a Service integration
- **get_storage**: ^2.1.1 - Local data persistence

### UI/UX
- **google_fonts**: ^6.2.1 - Typography (Inter font family)
- **cached_network_image**: ^3.4.1 - Image caching and optimization
- **flutter_svg**: ^2.0.15+1 - SVG icon support
- **shimmer**: ^3.0.0 - Loading animations and skeletons
- **flutter_rating_bar**: ^4.0.1 - Property ratings
- **cupertino_icons**: ^1.0.2 - iOS-style icons
- **image_network**: ^2.1.2 - Advanced network image handling
- **flutter_cache_manager**: ^3.3.1 - Advanced caching management

### Functionality
- **geolocator**: ^14.0.1 - Location services and GPS
- **geocoding**: ^4.0.0 - Address geocoding
- **flutter_map**: ^8.1.1 - Interactive map integration
- **latlong2**: ^0.9.0 - Latitude/longitude calculations
- **webview_flutter**: ^4.4.2 - 360° tour viewing
- **webview_flutter_web**: ^0.2.2+4 - Web platform support for WebView
- **connectivity_plus**: ^6.1.5 - Network connectivity status
- **flutter_localizations**: Internationalization support
- **intl**: ^0.20.2 - Date/time formatting and localization
- **shared_preferences**: ^2.3.2 - Platform-specific persistent storage
- **logger**: ^2.0.2+1 - Structured logging and debugging
- **url_launcher**: ^6.3.0 - External URL and app launching

## Development Guidelines

**NOTE**: Additional repository guidelines and commit standards are available in `AGENTS.md` in the project root.

### Change Scope and Minimal-Change Policy
- Implement only what is explicitly requested. Avoid opportunistic refactors or UI changes unless asked.
- Make the least necessary edits to achieve the requirement while upholding best practices for Flutter, GetX, and HTTP/Supabase integration.
- Prefer modifying existing code over adding parallel/new implementations. Do not keep legacy code alongside new code; remove obsolete code paths.
- Avoid redundant code intended for backward compatibility. The codebase is in active development; prioritize cleanliness over temporary shims.
- Reuse existing widgets, controllers, repositories, and helpers whenever possible. Do not create duplicates.
- Keep behavior and public APIs stable unless the task requires changes. If APIs change, update all affected call sites and remove the old API.
- Do not introduce new UI components or visual tweaks unless the task requests them. Preserve current UI/UX.
- Keep commits small, focused, and reversible. Include clear rationale in PR descriptions.
- Maintain testability and quality: update or add only the minimal tests needed for the change; fix broken tests caused by removed code instead of adding workarounds.
- Remove dead code and unused assets/imports discovered in the touched areas as part of the edit.

### When minimal edits require refactor
- If a small, surgical refactor reduces complexity or eliminates duplication in the touched scope, do it; keep it scoped.
- Prefer in-place refactors over broad rewrites. Avoid wide-ranging renames that are not required for the task.

### Code Organization
1. **Follow existing module structure** when adding new features
2. **Use GetX controllers** for all state management
3. **Create reusable widgets** in `lib/widgets/` directory
4. **Implement proper error handling** with user-friendly messages
5. **Add loading states** for all async operations
6. **Module structure**: Place feature code under `lib/features/<feature>/{views,controllers,bindings,widgets}`
7. **Use dependency injection** through bindings instead of `Get.put` in widgets
8. **Apply route guards** with `AuthMiddleware` where needed

### Dart and GetX Coding Standards

#### Naming Conventions
- **Classes/types**: PascalCase
- **Variables, methods, params**: camelCase
- **Constants**: lowerCamelCase (unless part of enums)
- **Prefer meaningful, verbose names** over abbreviations

#### Type Safety and Control Flow
- **Annotate public APIs** and exports; avoid `dynamic`/`var` when type is known
- **Avoid force casts**; handle nullability explicitly with null-aware operators
- **Use guard clauses** to avoid deep nesting; handle errors/edge cases first
- **Handle errors gracefully** with try/catch blocks and proper error mapping

#### GetX State Management Standards
- **Use `.obs` for reactive state**; prefer `GetxController` over `StatefulWidget` for complex state
- **Expose immutable getters** for external read; mutate only inside controller methods
- **Initialize work in `onInit()`**; clean up in `onClose()`
- **Use dependency injection** through bindings instead of `Get.put` in widgets
- **Extend `SafeGetView<T>`** from `lib/core/widgets/safe_get_view.dart` for typed controller access

#### Theme and Styling Standards
- **Never hardcode colors**: Use `AppTheme`/`AppColors` from `lib/core/utils/theme.dart` and `lib/core/utils/app_colors.dart`
- **Use predefined typography**: `AppTheme.headlineLarge`, `AppTheme.titleLarge`, etc.
- **Consistent spacing**: Use standard paddings (8/12/16/24); avoid magic numbers
- **Card styling**: 16px border radius, use `AppTheme.cardShadow` for shadows

#### Internationalization Standards
- **No hardcoded user-facing strings**: Add keys in `lib/core/translations/app_translations.dart`
- **Use localization**: Always use `'translation_key'.tr` for user-facing text
- **Test with multiple languages** to ensure proper text overflow handling

#### Async and Error Handling Standards
- **Wrap async calls** in try/catch blocks
- **Map errors** via `lib/core/utils/error_mapper.dart`
- **Handle errors** with `lib/core/utils/error_handler.dart`
- **Log with DebugLogger**: Use `lib/core/utils/debug_logger.dart` for development logging
- **Follow lint rules**: Adhere to `analysis_options.yaml`; fix lints in files you touch

#### Code Formatting and Analysis Standards
- **Line length**: Maximum 100 characters (configured in `analysis_options.yaml`)
- **Linting**: Uses `package:flutter_lints/flutter.yaml` for standard Flutter lints
- **Formatting**: Run `dart format .` to apply consistent Dart formatting
- **Analysis**: Run `flutter analyze` to catch static analysis issues
- **File naming**: Use `snake_case.dart` for file names (e.g., `property_details_view.dart`)
- **Build generation**: Always run `dart run build_runner build --delete-conflicting-outputs` after model changes

### GetX Best Practices
```dart
// ✅ Reactive variables
final RxList<PropertyModel> properties = <PropertyModel>[].obs;
final RxBool isLoading = false.obs;

// ✅ Proper controller lifecycle
@override
void onInit() {
  super.onInit();
  loadProperties();
}

// ✅ Error handling with proper error mapping
void loadProperties() async {
  try {
    isLoading.value = true;
    properties.value = await repository.getProperties();
  } catch (error, stackTrace) {
    ErrorHandler.handle(ErrorMapper.map(error));
    DebugLogger.error('Failed to load properties', error, stackTrace);
  } finally {
    isLoading.value = false;
  }
}
```

### Widget Development Standards
- **Parameterize components** for reusability
- **Use AppTheme colors** instead of hardcoded values
- **Make widgets responsive** to different screen sizes
- **Follow naming conventions**: PascalCase for classes, camelCase for variables
- **Extend SafeGetView<T>** from `lib/widgets/safe_get_view.dart` for typed controller access
- **Use guard clauses** to avoid deep nesting
- **No hardcoded strings** - use translation keys with `.tr` from `core/translations/app_translations.dart`

### Error Handling
The app uses centralized error handling:
- **ErrorHandler** utility in `lib/core/utils/error_handler.dart`
- **Custom exceptions** for different error types
- **User-friendly error messages** with AppToast
- **DebugLogger** for development logging and debugging (`lib/core/utils/debug_logger.dart`)
- **Graceful fallbacks** for network and API failures

### AppToast - Notification System

**ALWAYS use `AppToast` for all notifications/toasts** - Never use `Get.snackbar()` directly.

Located in `lib/core/utils/app_toast.dart`:
- **Position**: All toasts appear at `SnackPosition.TOP` (never bottom)
- **Minimal styling**: Compact padding, 8px border radius, 3s duration
- **Consistent appearance**: Unified colors via `AppDesign` tokens

#### Usage Examples:
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

#### Migration from Get.snackbar:
```dart
// ❌ DON'T use Get.snackbar directly
Get.snackbar('Error', 'Failed to load', snackPosition: SnackPosition.BOTTOM);

// ✅ DO use AppToast
AppToast.error('Error', 'Failed to load');
```

### Dependency Management
- Prefer constructor injection for repositories (`ApiClient`, datasources).
- Register property/swipe repos via `RepositoryRegistration` so both concrete
  types and core ports (`PropertiesPort`, `SwipesPort`) are available.
- Use GetX bindings for feature controllers; **SafeGetView** for safe disposal.

## Testing

### Test Structure
Currently, the project structure supports testing but test files need to be created:
- **Model tests**: Create `test/models/` for JSON serialization testing  
- **Widget tests**: Create `test/widgets/` for UI component testing
- **Unit tests**: Create `test/controllers/` for business logic testing
- **Integration tests**: Create `test/integration/` for full app flow testing

### Running Tests
```bash
# Run all tests (once test files are created)
flutter test

# Run with coverage
flutter test --coverage

# Generate coverage report (requires lcov installed)
genhtml coverage/lcov.info -o coverage/html

# Create test directory structure
mkdir -p test/{models,widgets,controllers,integration}
```

## Debugging and Development Workflow

### DebugLogger Usage
The app includes a comprehensive debugging system via `lib/core/utils/debug_logger.dart`:
```dart
// In controllers and services
DebugLogger.info('User login initiated');
DebugLogger.success('API call completed successfully'); 
DebugLogger.warning('Location permission denied');
DebugLogger.error('Failed to load properties', error, stackTrace);
DebugLogger.api('🔍 Searching properties with filters');
```

### Development Workflow
1. **Hot reload** for UI changes: `r` in terminal or IDE shortcut
2. **Hot restart** for logic changes: `R` in terminal
3. **Check reactive state**: Use ReactiveStateMonitor for debugging GetX state
4. **Monitor API calls**: Check DebugLogger output for API request/response logging
5. **Location testing**: Use device simulator location or physical device GPS

### GetX DevTools Integration
Monitor GetX state and routing:
```dart
// Enable GetX logging in main.dart (development only)
GetMaterialApp(
  enableLog: true,  // Shows navigation logs
  logWriterCallback: (text, {isError = false}) {
    DebugLogger.debug('GetX: $text');
  },
);
```

## Common Issues and Solutions

### Model Generation
If you modify models with `@JsonSerializable()`, run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### iOS Build Issues
- Ensure Xcode is updated to latest version
- iOS uses Swift Package Manager (no CocoaPods / Podfile). Run `flutter pub get` then
  `flutter build ios --config-only` if packages fail to resolve
- Check iOS deployment target in `ios/Runner.xcodeproj` (currently 15.0)

### Android Build Issues
- Verify Android SDK and build tools are installed
- Check `android/app/build.gradle` for compatibility
- Ensure proper signing configuration

### GetX Controller Issues
- Use `Get.find()` with proper tags
- Ensure controllers are registered in bindings
- Check for duplicate registrations
- Use `Get.delete()` for proper cleanup

## Authentication Flow

### Phone-Based Login Process
1. User enters phone number in PhoneEntryView/LoginView
2. System sends OTP via SMS for verification
3. AuthController validates OTP and calls AuthRepository
4. Backend handles authentication and returns secure tokens
5. Session tokens are persisted and refreshed by the Supabase SDK (`supabase_flutter`)
6. User redirected to profile completion or home based on setup status

### Profile Completion Flow
- **ProfileCompletionView**: Collects additional user information
- **Progressive disclosure**: Step-by-step profile setup
- **Validation**: Real-time form validation
- **Image upload**: Profile picture selection and upload

### Protected Routes
- **AuthMiddleware**: Checks authentication status for protected routes
- **Automatic redirect**: Redirects to login if not authenticated
- **Route preservation**: Maintains intended route for post-login redirect
- **Session management**: Handles token refresh and expiration

## State Management Patterns

### Controller Communication
- Use GetX's reactive programming for inter-controller communication
- Example: PropertyController listens to UserController favorites
- Avoid direct controller dependencies when possible

### Data Flow
1. View triggers controller action
2. Controller calls repository method
3. Repository uses provider (API/Mock)
4. Data flows back through layers
5. Controller updates reactive state
6. View rebuilds automatically

## Performance Optimizations

### Image Handling
- Use CachedNetworkImage for all remote images
- Implement proper placeholders and error widgets
- Lazy load images in lists
- Optimize image sizes for different screen densities

### List Performance
- Use ListView.builder for long lists
- Implement pagination for property listings
- Add pull-to-refresh functionality
- Cache frequently accessed data

### Memory Management
- Dispose controllers properly with SafeGetView
- Clear image cache periodically
- Use const constructors where possible
- Minimize widget rebuilds with GetX reactivity
- Implement proper controller lifecycle management

## Internationalization

### Multi-Language Support
The app supports multiple languages with complete localization:
- **LocalizationController**: Manages language preferences
- **AppTranslations**: Contains all translation strings
- **Dynamic switching**: Users can change language in preferences
- **Persistent storage**: Language preference saved locally

### Supported Languages
- **English**: Default language
- **Hindi**: Complete Hindi translation
- **RTL Support**: Ready for Arabic/Hebrew if needed

### Adding New Languages
1. Add translation strings to `core/translations/app_translations.dart`
2. Update LocalizationController with new locale
3. Test all screens with new language
4. Ensure proper text overflow handling

## Quick Reference

### Most Used Commands
```bash
flutter run                                              # Start development  
dart run build_runner build --delete-conflicting-outputs # Regenerate models
flutter analyze && dart format .                         # Code quality check
flutter pub get                                          # Deps (iOS via SPM)
```

### Key File Locations  
- **Controllers**: `lib/core/controllers/` and `lib/features/*/controllers/`
- **Models**: `lib/core/data/models/` (with .g.dart generated files)
- **Authentication Models**: `lib/core/models/auth_status.dart`
- **API Service**: `lib/core/data/providers/api_service.dart`
- **Root Router**: `lib/root.dart`
- **Routes**: `lib/core/routes/app_routes.dart` and `app_pages.dart`
- **Theme**: `lib/core/utils/theme.dart` and `app_colors.dart`  
- **Translations**: `lib/core/translations/app_translations.dart`
- **Environment**: `.env.development` and `.env.production`

### Architecture Pattern
```
Root Router → View (SafeGetView) → Controller (GetxController) → Repository → ApiService → Supabase
                                                              (auth/session tokens via Supabase SDK)
```

### Essential GetX Patterns
- Use `Get.find<ControllerType>()` to access controllers
- Reactive variables: `final RxBool isLoading = false.obs;`
- Update UI: `isLoading.value = true;` triggers automatic rebuilds
- Bindings handle dependency injection in `onInit()` methods

## Additional Guidelines

### MCP Integration
The project includes MCP (Model Context Protocol) server integration for Dart/Flutter development tools. Key MCP tools available:
- **Dart analysis**: `mcp__dart__analyze_files` for project-wide error analysis
- **Test running**: `mcp__dart__run_tests` instead of direct `flutter test` commands
- **Hot reload**: `mcp__dart__hot_reload` for development workflow
- **Code generation**: `mcp__dart__dart_format` for consistent formatting

**Important**: Always prefer MCP tools over direct shell commands when available for better integration with the development environment.
