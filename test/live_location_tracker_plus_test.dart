import 'package:flutter_test/flutter_test.dart';
import 'package:live_location_tracker_plus/live_location_tracker_plus.dart';
import 'package:live_location_tracker_plus/live_location_tracker_plus_platform_interface.dart';
import 'package:live_location_tracker_plus/live_location_tracker_plus_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockLiveLocationTrackerPlusPlatform
    with MockPlatformInterfaceMixin
    implements LiveLocationTrackerPlusPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> startTracking(TrackingConfig config) => Future.value(true);

  @override
  Future<bool> stopTracking() => Future.value(true);

  @override
  Future<LocationData> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) =>
      Future.value(LocationData(
        latitude: 23.8103,
        longitude: 90.4125,
        timestamp: DateTime.now(),
      ));

  @override
  Stream<LocationData> getLocationStream() => const Stream.empty();

  @override
  Future<bool> isTracking() => Future.value(false);

  @override
  Future<bool> addGeofence(GeofenceRegion region) => Future.value(true);

  @override
  Future<bool> removeGeofence(String id) => Future.value(true);

  @override
  Future<List<GeofenceRegion>> getActiveGeofences() => Future.value([]);

  @override
  Stream<GeofenceEvent> getGeofenceEventStream() => const Stream.empty();

  @override
  Future<LocationPermissionStatus> requestPermission() =>
      Future.value(LocationPermissionStatus.always);

  @override
  Future<LocationPermissionStatus> checkPermission() =>
      Future.value(LocationPermissionStatus.always);

  @override
  Future<LocationPermissionStatus> requestBackgroundPermission() =>
      Future.value(LocationPermissionStatus.always);

  @override
  Future<bool> enableFirebaseSync(FirebaseConfig config) => Future.value(true);

  @override
  Future<bool> disableFirebaseSync() => Future.value(true);

  @override
  Future<bool> setTrackingMode(TrackingMode mode) => Future.value(true);

  @override
  Future<bool> openLocationSettings() => Future.value(true);

  @override
  Future<bool> openAppSettings() => Future.value(true);
}

void main() {
  final LiveLocationTrackerPlusPlatform initialPlatform =
      LiveLocationTrackerPlusPlatform.instance;

  test('$MethodChannelLiveLocationTrackerPlus is the default instance', () {
    expect(initialPlatform,
        isInstanceOf<MethodChannelLiveLocationTrackerPlus>());
  });

  test('getPlatformVersion', () async {
    LiveLocationTrackerPlus liveLocationTrackerPlusPlugin =
        LiveLocationTrackerPlus();
    MockLiveLocationTrackerPlusPlatform fakePlatform =
        MockLiveLocationTrackerPlusPlatform();
    LiveLocationTrackerPlusPlatform.instance = fakePlatform;

    expect(await liveLocationTrackerPlusPlugin.getPlatformVersion(), '42');
  });
}
