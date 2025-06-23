# Vehicle Selector Component

A reusable Flutter component that provides a vehicle selection interface similar to shipping address selectors (like "Dikirim ke" in e-commerce apps). This component includes a provider for state management and integrates seamlessly with your GPS tracking app.

## 🎯 Features

- **Modern UI Design**: Similar to shipping address selectors with card-based layout
- **Bottom Sheet Selection**: Modal bottom sheet with smooth animations
- **State Management**: Global vehicle selection state using Provider pattern
- **Real-time Updates**: Automatically syncs with Firestore vehicle data
- **Error Handling**: Comprehensive error states and loading indicators
- **Flexible Integration**: Easy to integrate into existing screens

## 📁 File Structure

```
lib/
├── providers/
│   └── vehicle_provider.dart          # State management
├── components/
│   └── vehicle_selector.dart          # Main selector component
├── screens/
│   ├── vehicle/
│   │   └── vehicle_selector_example.dart  # Usage example
│   └── home/
│       └── enhanced_home_screen.dart      # Integration example
└── main.dart                          # Provider integration
```

## 🚀 Installation

### 1. Add Dependencies

Ensure these packages are in your `pubspec.yaml`:

```yaml
dependencies:
  provider: ^6.1.2
  cloud_firestore: ^5.6.9
  firebase_auth: ^5.6.0
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Provider Integration

Add the VehicleProvider to your app's main.dart:

```dart
import 'package:provider/provider.dart';
import 'providers/vehicle_provider.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => VehicleProvider()..initialize(),
        ),
      ],
      child: MaterialApp(
        // Your app configuration
      ),
    );
  }
}
```

## 📖 Usage

### Basic Implementation

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/vehicle_selector.dart';
import '../providers/vehicle_provider.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Vehicle Selector Component
          VehicleSelector(
            title: 'Current Vehicle',
            emptyMessage: 'Select a vehicle to track',
            onVehicleChanged: () {
              // Called when vehicle selection changes
              print('Vehicle selection changed!');
            },
          ),

          // Content based on selected vehicle
          Consumer<VehicleProvider>(
            builder: (context, vehicleProvider, child) {
              if (!vehicleProvider.hasSelectedVehicle) {
                return Text('No vehicle selected');
              }

              final vehicle = vehicleProvider.selectedVehicle!;
              return Text('Selected: ${vehicle.name}');
            },
          ),
        ],
      ),
    );
  }
}
```

### Advanced Integration

```dart
// Access selected vehicle globally
final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);

// Check if vehicle is selected
if (vehicleProvider.hasSelectedVehicle) {
  final vehicle = vehicleProvider.selectedVehicle!;
  // Use vehicle data for API calls, navigation, etc.
}

// Programmatically select a vehicle
vehicleProvider.selectVehicle(someVehicle);

// Clear selection
vehicleProvider.clearSelection();
```

## 🎨 Customization

### Component Properties

```dart
VehicleSelector(
  title: 'Tracking Vehicle',           // Selector title
  emptyMessage: 'Choose vehicle',      // Empty state message
  padding: EdgeInsets.all(16),         // Custom padding
  showDeviceInfo: true,                // Show device ID and plate number
  onVehicleChanged: () {               // Callback when selection changes
    // Your custom logic
  },
)
```

### Styling

The component automatically adapts to your app's theme. You can customize colors by modifying your app's `ThemeData`:

```dart
ThemeData(
  primarySwatch: Colors.blue,
  cardTheme: CardTheme(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
)
```

## 🔧 Integration Examples

### 1. Map Screen Integration

```dart
class MapScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('GPS Tracking')),
      body: Column(
        children: [
          // Vehicle selector at the top
          VehicleSelector(
            onVehicleChanged: () {
              // Refresh map data for new vehicle
              _refreshMapData();
            },
          ),

          // Map view
          Expanded(
            child: Consumer<VehicleProvider>(
              builder: (context, vehicleProvider, child) {
                return MapWidget(
                  vehicleId: vehicleProvider.selectedVehicle?.id,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

### 2. Navigation Integration

```dart
// Navigate with selected vehicle context
void navigateToHistory() {
  final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);

  if (vehicleProvider.hasSelectedVehicle) {
    Navigator.pushNamed(
      context,
      '/drive-history',
      arguments: {
        'vehicleId': vehicleProvider.selectedVehicle!.id,
        'vehicleName': vehicleProvider.selectedVehicle!.name,
      },
    );
  } else {
    // Show vehicle selection prompt
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please select a vehicle first')),
    );
  }
}
```

### 3. Data Fetching Integration

```dart
class VehicleDataWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, child) {
        if (!vehicleProvider.hasSelectedVehicle) {
          return EmptyStateWidget();
        }

        final vehicleId = vehicleProvider.selectedVehicle!.id;

        return StreamBuilder<GpsData>(
          stream: FirebaseDatabase.instance
              .ref('devices/$vehicleId/gps')
              .onValue,
          builder: (context, snapshot) {
            // Display real-time GPS data
            return GpsDataWidget(data: snapshot.data);
          },
        );
      },
    );
  }
}
```

## 🎯 Provider Methods

### VehicleProvider

```dart
// Properties
vehicle? selectedVehicle;           // Currently selected vehicle
List<vehicle> vehicles;             // All user vehicles
bool isLoading;                     // Loading state
String? error;                      // Error message
bool hasSelectedVehicle;            // Convenience getter

// Methods
Future<void> initialize();          // Initialize provider
Future<void> loadVehicles();        // Load vehicles from Firestore
void selectVehicle(vehicle);        // Select a vehicle
void clearSelection();              // Clear selection
vehicle? getVehicleById(String id); // Get vehicle by ID
```

## 🚨 Error Handling

The component includes comprehensive error handling:

- **Network Errors**: Automatic retry with user feedback
- **Authentication Errors**: Redirect to login if needed
- **Empty States**: User-friendly empty state messages
- **Loading States**: Smooth loading indicators

## 🔄 State Persistence

To persist vehicle selection across app restarts, uncomment the SharedPreferences code in `vehicle_provider.dart`:

```dart
// Add this dependency to pubspec.yaml
shared_preferences: ^2.2.0

// Uncomment the persistence methods in VehicleProvider
```

## 📱 Screenshots

### Vehicle Selector Closed State

```
┌─────────────────────────────────────┐
│ 🚗  Current Vehicle                 │
│     Toyota Camry 2020               │
│     B 1234 ABC                      │
│                              ⌄      │
└─────────────────────────────────────┘
```

### Vehicle Selector Bottom Sheet

```
┌─────────────────────────────────────┐
│ Select Vehicle                    ✕ │
├─────────────────────────────────────┤
│ 🚗  Toyota Camry 2020            ✓  │
│     B 1234 ABC                      │
├─────────────────────────────────────┤
│ 🚗  Honda Civic 2019                │
│     B 5678 DEF                      │
├─────────────────────────────────────┤
│ 🚗  Yamaha NMAX 2021                │
│     B 9012 GHI                      │
└─────────────────────────────────────┘
```

## 🎉 Complete Example

Check out these files for complete implementation examples:

1. **`screens/vehicle/vehicle_selector_example.dart`** - Basic usage example
2. **`screens/home/enhanced_home_screen.dart`** - Advanced integration with dashboard
3. **`components/vehicle_selector.dart`** - Component source code
4. **`providers/vehicle_provider.dart`** - State management implementation

## 📞 Support

For questions or issues, please refer to the existing vehicle management code in your app:

- `lib/models/vehicle/vehicle.dart`
- `lib/services/vehicle/vehicleService.dart`
- `lib/screens/vehicle/`

## 🔧 Next Steps

1. **Hot restart** your Flutter app after adding the provider
2. **Add the VehicleSelector** to your desired screens
3. **Test vehicle selection** and verify data flow
4. **Customize styling** to match your app's design
5. **Add persistence** if you want to remember selection across restarts

The vehicle selector is now ready to be used throughout your GPS tracking app! 🚀
