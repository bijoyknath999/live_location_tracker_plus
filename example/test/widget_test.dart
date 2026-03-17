// Basic Flutter widget test for the example app.

import 'package:flutter_test/flutter_test.dart';

import 'package:live_location_tracker_plus_example/main.dart';

void main() {
  testWidgets('Verify app launches', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LiveLocationTrackerApp());

    // Verify that the app title is displayed.
    expect(find.text('Live Location Tracker+'), findsOneWidget);
  });
}
