# Application Architecture & Build System Documentation

## Overview

The application follows a clean architecture pattern with clear separation of concerns, layered design, and modular components. The build system supports multiple environments, automated testing, and continuous integration/deployment pipelines.

## Architecture Overview

### Clean Architecture Layers

#### Presentation Layer

- **Screens**: UI screens and navigation
- **Widgets**: Reusable UI components
- **State Management**: UI state and business logic coordination
- **View Models**: Screen-specific business logic

#### Application Layer

- **Services**: Business logic and application services
- **Use Cases**: Specific application operations
- **Repositories**: Data access abstraction
- **DTOs**: Data transfer objects

#### Infrastructure Layer

- **Data Sources**: External data sources (Firebase, APIs, local storage)
- **Models**: Data models and entities
- **Network**: HTTP clients and network utilities
- **Storage**: Local storage and caching mechanisms

### Project Structure

```
lib/
├── main.dart                          # Application entry point
├── app.dart                          # App configuration and routing
├── screens/                          # UI screens
│   ├── auth/                        # Authentication screens
│   ├── device/                      # Device management screens
│   ├── geofence/                    # Geofence management screens
│   ├── maps/                        # Map visualization screens
│   ├── notifications/               # Notification screens
│   ├── users/                       # User management screens
│   └── vehicle/                     # Vehicle management screens
├── widgets/                          # Reusable UI components
│   ├── Common/                      # Common widgets
│   ├── Device/                      # Device-specific widgets
│   ├── Map/                         # Map-related widgets
│   ├── geofence/                    # Geofence widgets
│   └── notifications/               # Notification widgets
├── services/                         # Business logic and data services
│   ├── auth/                        # Authentication services
│   ├── device/                      # Device management services
│   ├── geofence/                    # Geofence services
│   ├── maps/                        # Map and location services
│   ├── notifications/               # Notification services
│   └── vehicle/                     # Vehicle services
├── models/                           # Data models and entities
│   ├── auth/                        # Authentication models
│   ├── device/                      # Device models
│   ├── geofence/                    # Geofence models
│   ├── notifications/               # Notification models
│   └── vehicle/                     # Vehicle models
├── theme/                            # Theme and styling
│   ├── app_colors.dart              # Color palette
│   ├── app_icons.dart               # Icon library
│   └── app_theme.dart               # Theme configuration
├── utils/                            # Utility functions
│   ├── constants.dart               # Application constants
│   ├── helpers.dart                 # Helper functions
│   └── validators.dart              # Validation utilities
└── config/                           # Configuration files
    ├── firebase_config.dart         # Firebase configuration
    ├── api_config.dart              # API configuration
    └── app_config.dart              # Application configuration
```

## Build System

### Environment Configuration

#### Development Environment

```yaml
# pubspec.yaml - development configuration
flutter:
  assets:
    - assets/images/dev/
    - assets/config/dev/
```

#### Production Environment

```yaml
# pubspec.yaml - production configuration
flutter:
  assets:
    - assets/images/prod/
    - assets/config/prod/
```

### Build Scripts

#### Android Build

```bash
# Debug build
flutter build apk --debug --flavor dev

# Release build
flutter build apk --release --flavor prod --obfuscate --split-debug-info=build/debug-info

# App Bundle
flutter build appbundle --release --flavor prod
```

#### iOS Build

```bash
# Debug build
flutter build ios --debug --flavor dev

# Release build
flutter build ios --release --flavor prod --obfuscate --split-debug-info=build/debug-info
```

### CI/CD Pipeline

#### GitHub Actions Configuration

```yaml
name: Build and Test
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test
      - run: flutter analyze

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter build apk --release
```

## Data Architecture

### Firebase Integration

#### Firestore Collections

```
users/                               # User accounts and profiles
├── {userId}/
│   ├── profile: UserProfile       # User profile information
│   ├── preferences: UserPrefs     # User preferences and settings
│   └── devices/                   # User's devices subcollection
│       └── {deviceId}: Device     # Device information
│
devices/                            # Global device registry
├── {deviceId}: Device             # Device metadata and configuration
│
vehicles/                           # Vehicle management
├── {vehicleId}: Vehicle           # Vehicle information and device links
│
geofences/                          # Geofence definitions
├── {geofenceId}: Geofence         # Geofence polygon and settings
│
notifications/                      # User notifications
├── {userId}/
│   └── {notificationId}: Notification # Individual notifications
```

#### Realtime Database Structure

```
devices/                            # Real-time device data
├── {deviceMacAddress}/
│   ├── gps/
│   │   ├── latitude: double       # Current GPS latitude
│   │   ├── longitude: double      # Current GPS longitude
│   │   ├── timestamp: int         # Unix timestamp
│   │   ├── accuracy: double       # GPS accuracy in meters
│   │   └── speed: double          # Speed in km/h
│   └── status/
│       ├── online: boolean        # Online status
│       ├── battery: double        # Battery level (0-100)
│       └── lastSeen: int          # Last communication timestamp
```

### Local Storage

#### SQLite Schema

```sql
-- Local device cache
CREATE TABLE devices (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  mac_address TEXT UNIQUE,
  last_update INTEGER,
  cached_data TEXT,
  sync_status INTEGER DEFAULT 0
);

-- Notification cache
CREATE TABLE notifications (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  is_read INTEGER DEFAULT 0,
  sync_status INTEGER DEFAULT 0
);

-- Geofence cache
CREATE TABLE geofences (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  device_id TEXT NOT NULL,
  polygon_points TEXT NOT NULL,
  is_active INTEGER DEFAULT 1,
  sync_status INTEGER DEFAULT 0
);
```

## State Management

### Architecture Pattern

- **Provider Pattern**: State management using Provider package
- **Repository Pattern**: Data access through repository interfaces
- **Service Locator**: Dependency injection using GetIt
- **Event-Driven**: Event bus for loose coupling between components

### State Management Structure

```dart
// Service registration
void setupServiceLocator() {
  GetIt.I.registerLazySingleton<AuthService>(() => AuthService());
  GetIt.I.registerLazySingleton<DeviceService>(() => DeviceService());
  GetIt.I.registerLazySingleton<GeofenceService>(() => GeofenceService());
}

// Provider setup
class AppProviders extends StatelessWidget {
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MyApp(),
    );
  }
}
```

## Security Architecture

### Authentication & Authorization

- **Firebase Authentication**: User authentication with email/password and Google OAuth
- **JWT Tokens**: Secure API communication with JSON Web Tokens
- **Role-Based Access**: User roles and permissions for feature access
- **Device Association**: Secure device-user relationship management

### Data Security

- **Encryption at Rest**: Local database encryption using SQLCipher
- **Encryption in Transit**: HTTPS/TLS for all network communications
- **API Security**: Authenticated API calls with proper authorization headers
- **Input Validation**: Comprehensive input validation and sanitization

### Privacy Protection

- **Data Minimization**: Collect only necessary user data
- **Consent Management**: User consent for data collection and processing
- **Data Retention**: Automatic data purging based on retention policies
- **Anonymization**: GPS data anonymization for analytics

## Performance Architecture

### Optimization Strategies

- **Lazy Loading**: On-demand loading of screens and data
- **Connection Pooling**: Efficient database connection management
- **Caching Strategy**: Multi-level caching (memory, disk, network)
- **Background Processing**: Non-blocking background operations

### Memory Management

```dart
// Proper disposal of resources
class DeviceProvider extends ChangeNotifier {
  StreamSubscription? _deviceSubscription;

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    super.dispose();
  }
}
```

### Network Optimization

- **Request Batching**: Batch multiple API requests
- **Compression**: Data compression for network requests
- **Offline Support**: Comprehensive offline functionality
- **Connection Management**: Intelligent connection handling

## Testing Architecture

### Testing Strategy

- **Unit Tests**: Comprehensive unit testing for business logic
- **Widget Tests**: UI component testing
- **Integration Tests**: End-to-end testing of user flows
- **Performance Tests**: Performance and memory usage testing

### Test Structure

```
test/
├── unit/
│   ├── services/              # Service layer tests
│   ├── models/                # Model tests
│   └── utils/                 # Utility function tests
├── widget/
│   ├── screens/               # Screen widget tests
│   └── widgets/               # Component widget tests
└── integration/
    ├── auth_flow_test.dart    # Authentication flow tests
    ├── device_management_test.dart # Device management tests
    └── geofence_creation_test.dart # Geofence creation tests
```

## Development Guidelines

### Code Quality Standards

- **Linting**: Strict linting rules with flutter_lints package
- **Code Formatting**: Consistent code formatting with dartfmt
- **Documentation**: Comprehensive code documentation
- **Type Safety**: Strong typing throughout the application

### Development Workflow

1. **Feature Branches**: Feature development in separate branches
2. **Code Review**: Mandatory code review for all changes
3. **Automated Testing**: All tests must pass before merge
4. **Documentation**: Update documentation with changes

### Error Handling

```dart
// Centralized error handling
class ErrorHandler {
  static void handleError(Object error, StackTrace stackTrace) {
    // Log error
    logger.error('Error occurred: $error', error, stackTrace);

    // Report to crash analytics
    FirebaseCrashlytics.instance.recordError(error, stackTrace);

    // Show user-friendly message
    showErrorSnackbar(getErrorMessage(error));
  }
}
```

## Deployment Architecture

### Release Process

1. **Version Increment**: Update version numbers in pubspec.yaml
2. **Testing**: Run comprehensive test suite
3. **Build**: Generate release builds for Android and iOS
4. **Code Signing**: Sign builds with proper certificates
5. **Store Upload**: Upload to Google Play Store and Apple App Store

### Environment Management

- **Development**: Local development environment
- **Staging**: Pre-production testing environment
- **Production**: Live production environment

### Monitoring & Analytics

- **Crash Reporting**: Firebase Crashlytics for crash monitoring
- **Performance Monitoring**: Firebase Performance for app performance
- **Usage Analytics**: Firebase Analytics for user behavior
- **Custom Metrics**: Custom performance and business metrics

## Future Architecture Improvements

### Planned Enhancements

- **Microservices**: Migration to microservices architecture
- **GraphQL**: GraphQL API implementation for efficient data fetching
- **Event Sourcing**: Event sourcing for audit trails and data history
- **CQRS**: Command Query Responsibility Segregation for better scalability

### Technical Debt

- **Legacy Code**: Refactor legacy components to modern architecture
- **Testing Coverage**: Increase automated testing coverage
- **Documentation**: Complete architecture documentation
- **Performance**: Optimize critical performance bottlenecks
