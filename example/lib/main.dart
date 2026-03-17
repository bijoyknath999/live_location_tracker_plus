import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:live_location_tracker_plus/live_location_tracker_plus.dart';

void main() {
  runApp(const LiveLocationTrackerApp());
}

class LiveLocationTrackerApp extends StatelessWidget {
  const LiveLocationTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Location Tracker+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF00E5FF),
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1F36),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0E21),
          elevation: 0,
          centerTitle: true,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFF00E5FF),
          foregroundColor: const Color(0xFF0A0E21),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const MapTrackingPage(),
    );
  }
}

class MapTrackingPage extends StatefulWidget {
  const MapTrackingPage({super.key});

  @override
  State<MapTrackingPage> createState() => _MapTrackingPageState();
}

class _MapTrackingPageState extends State<MapTrackingPage>
    with TickerProviderStateMixin {
  final _tracker = LiveLocationTrackerPlus();

  // Map
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  final Set<Circle> _geofenceCircles = {};
  final List<LatLng> _routePoints = [];

  // State
  bool _isTracking = false;
  bool _isAddingGeofence = false;
  LocationData? _currentLocation;
  LocationPermissionStatus _permissionStatus =
      LocationPermissionStatus.notDetermined;
  TrackingMode _trackingMode = TrackingMode.balanced;
  String _platformVersion = 'Unknown';

  // Streams
  StreamSubscription<LocationData>? _locationSub;
  StreamSubscription<GeofenceEvent>? _geofenceSub;

  // Animation
  late AnimationController _pulseController;

  // Stats
  int _updateCount = 0;
  double _totalDistance = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _initPlugin();
  }

  Future<void> _initPlugin() async {
    final version = await _tracker.getPlatformVersion();
    final permission = await _tracker.checkPermission();
    setState(() {
      _platformVersion = version ?? 'Unknown';
      _permissionStatus = permission;
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _geofenceSub?.cancel();
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Actions
  // ===========================================================================

  Future<void> _requestPermission() async {
    // Step 1: Request foreground location
    var status = await _tracker.requestPermission();
    setState(() => _permissionStatus = status);

    // Step 2: If granted foreground, request background
    if (status == LocationPermissionStatus.whileInUse ||
        status == LocationPermissionStatus.always) {
      if (status != LocationPermissionStatus.always) {
        final bgStatus = await _tracker.requestBackgroundPermission();
        setState(() => _permissionStatus = bgStatus);
      }
    }
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _tracker.stopTracking();
      _locationSub?.cancel();
      _locationSub = null;
      setState(() => _isTracking = false);
      _showSnackBar('🛑 Tracking stopped', Colors.orangeAccent);
    } else {
      // Ensure all permissions are granted
      if (_permissionStatus != LocationPermissionStatus.always) {
        await _requestPermission();
        // Re-check after permission request
        final updatedStatus = await _tracker.checkPermission();
        setState(() => _permissionStatus = updatedStatus);
      }

      if (_permissionStatus == LocationPermissionStatus.denied ||
          _permissionStatus == LocationPermissionStatus.deniedForever) {
        _showSnackBar(
            '❌ Location permission denied. Please enable in Settings.',
            Colors.redAccent);
        return;
      }

      final config = TrackingConfig(
        intervalMs: _trackingMode == TrackingMode.highAccuracy ? 2000 : 5000,
        distanceFilter: _trackingMode == TrackingMode.lowPower ? 50.0 : 10.0,
        accuracy: LocationAccuracy.high,
        trackingMode: _trackingMode,
        notificationTitle: 'Live Location Tracker+',
        notificationBody: 'Tracking your location in real-time',
      );

      final started = await _tracker.startTracking(config);
      if (started) {
        _locationSub = _tracker.locationStream.listen(_onLocationUpdate);
        _geofenceSub ??=
            _tracker.geofenceEventStream.listen(_onGeofenceEvent);
        setState(() => _isTracking = true);
        _showSnackBar('🚀 Tracking started', const Color(0xFF00E5FF));
      }
    }
  }

  void _onLocationUpdate(LocationData location) {
    final newPoint = LatLng(location.latitude, location.longitude);

    if (_routePoints.isNotEmpty) {
      _totalDistance += _calculateDistance(
        _routePoints.last.latitude,
        _routePoints.last.longitude,
        newPoint.latitude,
        newPoint.longitude,
      );
    }

    setState(() {
      _currentLocation = location;
      _updateCount++;
      _routePoints.add(newPoint);

      // Update polyline
      _polylines
        ..clear()
        ..add(Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: const Color(0xFF00E5FF),
          width: 4,
          patterns: [PatternItem.dot, PatternItem.gap(10)],
        ));

      // Update current position marker
      _markers.removeWhere((m) => m.markerId.value == 'current');
      _markers.add(Marker(
        markerId: const MarkerId('current'),
        position: newPoint,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        infoWindow: InfoWindow(
          title: 'Current Location',
          snippet:
              'Accuracy: ${location.accuracy?.toStringAsFixed(1)}m | Speed: ${location.speed?.toStringAsFixed(1)} m/s',
        ),
      ));
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(newPoint, 16),
    );
  }

  void _onGeofenceEvent(GeofenceEvent event) {
    final triggerName = event.triggerType == GeofenceTrigger.enter
        ? 'ENTERED'
        : event.triggerType == GeofenceTrigger.exit
            ? 'EXITED'
            : 'DWELLING';
    _showSnackBar(
      '📍 Geofence $triggerName: ${event.region.id}',
      event.triggerType == GeofenceTrigger.enter
          ? Colors.greenAccent
          : Colors.redAccent,
    );
  }

  void _onMapTap(LatLng position) {
    if (!_isAddingGeofence) return;

    final id = 'geofence_${DateTime.now().millisecondsSinceEpoch}';
    final region = GeofenceRegion(
      id: id,
      latitude: position.latitude,
      longitude: position.longitude,
      radius: 200,
    );

    _tracker.addGeofence(region);

    setState(() {
      _geofenceCircles.add(Circle(
        circleId: CircleId(id),
        center: position,
        radius: 200,
        fillColor: const Color(0xFF00E5FF).withValues(alpha: 0.15),
        strokeColor: const Color(0xFF00E5FF),
        strokeWidth: 2,
      ));
      _markers.add(Marker(
        markerId: MarkerId(id),
        position: position,
        icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow:
            const InfoWindow(title: 'Geofence', snippet: 'Radius: 200m'),
      ));
      _isAddingGeofence = false;
    });

    _showSnackBar(
      '📍 Geofence added at ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
      Colors.purpleAccent,
    );
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final location = await _tracker.getCurrentLocation();
      final latLng = LatLng(location.latitude, location.longitude);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
      setState(() => _currentLocation = location);
    } catch (e) {
      _showSnackBar('❌ Failed to get location', Colors.redAccent);
    }
  }

  // ===========================================================================
  // UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(23.8103, 90.4125), // Default: Dhaka
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController = controller,
            polylines: _polylines,
            markers: _markers,
            circles: _geofenceCircles,
            onTap: _onMapTap,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            mapType: MapType.normal,
          ),

          // Top info bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _buildTopBar(),
          ),

          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(),
          ),

          // Geofence mode indicator
          if (_isAddingGeofence)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    '📍 Tap on map to add geofence',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'myLocation',
            onPressed: _goToCurrentLocation,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'geofence',
            backgroundColor: _isAddingGeofence
                ? Colors.purpleAccent
                : const Color(0xFF1A1F36),
            onPressed: () =>
                setState(() => _isAddingGeofence = !_isAddingGeofence),
            child: const Icon(Icons.radar, color: Colors.white),
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = _isTracking
                  ? 1.0 + (_pulseController.value * 0.05)
                  : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: FloatingActionButton(
              heroTag: 'tracking',
              onPressed: _toggleTracking,
              backgroundColor:
                  _isTracking ? Colors.redAccent : const Color(0xFF00E5FF),
              child: Icon(
                _isTracking ? Icons.stop : Icons.play_arrow,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isTracking ? Colors.greenAccent : Colors.grey,
                boxShadow: _isTracking
                    ? [
                        BoxShadow(
                          color: Colors.greenAccent.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Live Location Tracker+',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  Text(
                    'Platform: $_platformVersion',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            _buildPermissionChip(),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionChip() {
    final (label, color) = switch (_permissionStatus) {
      LocationPermissionStatus.always => ('Always', Colors.greenAccent),
      LocationPermissionStatus.whileInUse =>
        ('When In Use', Colors.orangeAccent),
      LocationPermissionStatus.denied => ('Denied', Colors.redAccent),
      LocationPermissionStatus.deniedForever => ('Blocked', Colors.red),
      LocationPermissionStatus.notDetermined => ('Not Set', Colors.grey),
    };

    return GestureDetector(
      onTap: _requestPermission,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0E21).withValues(alpha: 0),
            const Color(0xFF0A0E21).withValues(alpha: 0.9),
            const Color(0xFF0A0E21),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentLocation != null) _buildLocationCard(),
          const SizedBox(height: 12),
          _buildStatsRow(),
          const SizedBox(height: 12),
          _buildModeSelector(),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final loc = _currentLocation!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.location_on,
                    color: Color(0xFF00E5FF), size: 20),
                const SizedBox(width: 8),
                Text(
                  '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip(Icons.speed,
                    '${loc.speed?.toStringAsFixed(1) ?? "—"} m/s'),
                _buildInfoChip(Icons.gps_fixed,
                    '±${loc.accuracy?.toStringAsFixed(0) ?? "—"}m'),
                _buildInfoChip(Icons.terrain,
                    '${loc.altitude?.toStringAsFixed(0) ?? "—"}m'),
                _buildInfoChip(Icons.explore,
                    '${loc.heading?.toStringAsFixed(0) ?? "—"}°'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('Updates', '$_updateCount'),
        const SizedBox(width: 12),
        _buildStatCard(
            'Distance', '${(_totalDistance / 1000).toStringAsFixed(2)} km'),
        const SizedBox(width: 12),
        _buildStatCard('Points', '${_routePoints.length}'),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F36),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2F46)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        _buildModeButton('⚡ High', TrackingMode.highAccuracy),
        const SizedBox(width: 8),
        _buildModeButton('⚖️ Balanced', TrackingMode.balanced),
        const SizedBox(width: 8),
        _buildModeButton('🔋 Low Power', TrackingMode.lowPower),
      ],
    );
  }

  Widget _buildModeButton(String label, TrackingMode mode) {
    final isSelected = _trackingMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _trackingMode = mode);
          if (_isTracking) {
            _tracker.setTrackingMode(mode);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                : const Color(0xFF1A1F36),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00E5FF)
                  : const Color(0xFF2A2F46),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00E5FF) : Colors.white54,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}
