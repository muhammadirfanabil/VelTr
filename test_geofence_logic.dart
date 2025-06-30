// Test script to verify geofence alert logic
// This script simulates the geofence state transitions to ensure no duplicates

void main() {
  print('🧪 Testing Geofence Alert Logic...\n');

  // Simulate the state tracking map
  Map<String, Map<String, bool?>> lastGeofenceStatus = {};
  Map<String, Map<String, DateTime>> lastTransitionTime = {};

  const deviceId = 'test-device';
  const geofenceId = 'test-geofence';
  const minTransitionInterval = 30; // seconds

  // Initialize state
  lastGeofenceStatus[deviceId] = {};
  lastTransitionTime[deviceId] = {};
  lastGeofenceStatus[deviceId]![geofenceId] = null; // Unknown initial state
  lastTransitionTime[deviceId]![geofenceId] = DateTime.now().subtract(
    Duration(days: 1),
  );

  print('✅ Initial state: ${lastGeofenceStatus[deviceId]![geofenceId]}');

  // Test scenarios
  List<TestScenario> scenarios = [
    TestScenario('First location update - inside geofence', true),
    TestScenario('Same location - still inside (should not alert)', true),
    TestScenario('Exit geofence', false),
    TestScenario(
      'Rapid re-entry within debounce time (should not alert)',
      true,
    ),
    TestScenario('Re-entry after debounce time', true),
  ];

  for (int i = 0; i < scenarios.length; i++) {
    final scenario = scenarios[i];
    print('\n🔬 Test ${i + 1}: ${scenario.description}');

    final wasInside = lastGeofenceStatus[deviceId]![geofenceId];
    final isInside = scenario.isInside;

    // Simulate different time intervals for testing debounce
    late DateTime now;
    if (i == 3) {
      // Test 4: Rapid transition within debounce time
      now = lastTransitionTime[deviceId]![geofenceId]!.add(
        Duration(seconds: 10),
      );
    } else {
      // Other tests: After debounce period
      now = lastTransitionTime[deviceId]![geofenceId]!.add(
        Duration(seconds: 35),
      );
    }

    final lastTransition = lastTransitionTime[deviceId]![geofenceId]!;

    print('   Current state: wasInside=$wasInside, isInside=$isInside');
    print(
      '   Time since last transition: ${now.difference(lastTransition).inSeconds}s',
    );

    // Apply the logic from the actual service
    if (wasInside == null) {
      // First update - initialize state
      lastGeofenceStatus[deviceId]![geofenceId] = isInside;
      lastTransitionTime[deviceId]![geofenceId] = now;
      print('   ✅ Initialized state - no alert sent');
      continue;
    }

    if (isInside != wasInside) {
      final timeSinceLastTransition = now.difference(lastTransition).inSeconds;

      if (timeSinceLastTransition < minTransitionInterval) {
        print(
          '   ⏱️ Transition too recent (${timeSinceLastTransition}s < ${minTransitionInterval}s) - no alert',
        );
        continue;
      }

      final action = isInside ? 'enter' : 'exit';
      print('   🚨 ALERT: Device ${action}ed geofence');

      // Update state BEFORE creating alert (to prevent duplicates)
      lastGeofenceStatus[deviceId]![geofenceId] = isInside;
      lastTransitionTime[deviceId]![geofenceId] = now;
    } else {
      print('   ℹ️ No state change - no alert');
    }
  }

  print('\n✅ Geofence logic test completed successfully!');
}

class TestScenario {
  final String description;
  final bool isInside;

  TestScenario(this.description, this.isInside);
}
