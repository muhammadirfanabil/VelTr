# GPS Tracking Application

A comprehensive Flutter-based GPS tracking application with real-time device monitoring, geofence management, vehicle tracking, and intelligent notifications.

## Features

- 📍 **Real-time GPS Tracking**: Live location monitoring with high accuracy
- 🗺️ **Interactive Geofences**: Create and manage geographic boundaries with map-based tools
- 🚗 **Vehicle Management**: Complete vehicle lifecycle and fleet management
- 🔔 **Smart Notifications**: Unified notification system with intelligent grouping
- 📱 **Cross-platform**: Native iOS and Android applications
- 🔐 **Secure Authentication**: Firebase-based authentication with Google OAuth
- 📊 **Analytics & History**: Comprehensive tracking history and usage analytics

## Quick Start

### Prerequisites
- Flutter SDK (3.0+)
- Firebase account and project setup
- Android Studio / Xcode for platform development

### Installation
```bash
# Clone the repository
git clone <repository-url>
cd gps-app

# Install dependencies
flutter pub get

# Run the application
flutter run
```

### Configuration
1. Set up Firebase project with Firestore and Realtime Database
2. Configure Firebase authentication providers
3. Update Firebase configuration files for iOS and Android
4. Configure map services and location permissions

## Documentation

📚 **Comprehensive documentation is available in the [`docs/`](./docs/) directory:**

- **[Complete Documentation Index](./docs/README.md)** - Start here for full documentation overview
- **[Geofence Management](./docs/geofence-management.md)** - Geofence creation, editing, and monitoring
- **[Device Management](./docs/device-management.md)** - Device registration and real-time tracking  
- **[Vehicle Management](./docs/vehicle-management.md)** - Fleet management and vehicle tracking
- **[Notifications System](./docs/notifications-system.md)** - Alert delivery and notification management
- **[UI/UX System](./docs/ui-ux-system.md)** - Design system and user experience guidelines
- **[Architecture & Build](./docs/architecture-build.md)** - Application architecture and build system
- **[Testing & QA](./docs/testing-qa.md)** - Testing procedures and quality assurance

## Architecture

The application follows a clean architecture pattern with clear separation of concerns:

- **Presentation Layer**: Flutter widgets and screens
- **Business Logic Layer**: Services and use cases  
- **Data Layer**: Firebase integration and local storage
- **Infrastructure**: Platform-specific implementations

## Technology Stack

- **Frontend**: Flutter / Dart
- **Backend**: Firebase (Firestore, Realtime Database, Cloud Messaging)
- **Authentication**: Firebase Auth
- **Maps**: OpenStreetMap with flutter_map
- **State Management**: Provider pattern
- **Local Storage**: SQLite / Hive
- **Push Notifications**: Firebase Cloud Messaging

## Development

### Project Structure
```
lib/
├── screens/          # Application screens
├── widgets/          # Reusable UI components  
├── services/         # Business logic and data services
├── models/           # Data models and entities
├── theme/            # Theme and styling
├── utils/            # Utility functions
└── config/           # Configuration files
```

### Development Guidelines
- Follow Flutter best practices and conventions
- Use centralized theme system for consistent styling
- Implement comprehensive error handling
- Maintain test coverage above 80%
- Document all public APIs

## Testing

```bash
# Run unit tests
flutter test

# Run integration tests  
flutter drive --target=test_driver/app.dart

# Generate coverage report
flutter test --coverage
```

## Contributing

1. Read the [documentation](./docs/) to understand the system
2. Follow the established architecture patterns
3. Write tests for new features
4. Update documentation for changes
5. Submit pull requests with clear descriptions

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For technical questions and support:
- Check the [documentation](./docs/) for detailed guides
- Review existing issues before creating new ones
- Follow the bug report template for issue submissions
