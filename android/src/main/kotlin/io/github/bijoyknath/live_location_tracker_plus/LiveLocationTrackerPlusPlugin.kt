package io.github.bijoyknath.live_location_tracker_plus

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** LiveLocationTrackerPlusPlugin */
class LiveLocationTrackerPlusPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var locationEventChannel: EventChannel
    private lateinit var geofenceEventChannel: EventChannel
    private lateinit var context: Context

    private var activity: Activity? = null
    private var pendingPermissionResult: Result? = null
    private var pendingTrackingCall: MethodCall? = null
    private var pendingTrackingResult: Result? = null

    private var locationStreamHandler: LocationStreamHandler? = null
    private var geofenceStreamHandler: GeofenceStreamHandler? = null

    private var permissionHandler: PermissionHandler? = null
    private var geofenceManager: GeofenceManager? = null
    private var firebaseSyncManager: FirebaseSyncManager? = null

    private var isTrackingActive = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        // Method channel
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "live_location_tracker_plus")
        channel.setMethodCallHandler(this)

        // Location event channel
        locationStreamHandler = LocationStreamHandler()
        locationEventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "live_location_tracker_plus/location_stream"
        )
        locationEventChannel.setStreamHandler(locationStreamHandler)

        // Geofence event channel
        geofenceStreamHandler = GeofenceStreamHandler()
        geofenceEventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "live_location_tracker_plus/geofence_stream"
        )
        geofenceEventChannel.setStreamHandler(geofenceStreamHandler)

        // Managers
        permissionHandler = PermissionHandler(context)
        geofenceManager = GeofenceManager(context, geofenceStreamHandler)
        firebaseSyncManager = FirebaseSyncManager()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${Build.VERSION.RELEASE}")
            }
            "startTracking" -> handleStartTracking(call, result)
            "stopTracking" -> handleStopTracking(result)
            "getCurrentLocation" -> handleGetCurrentLocation(call, result)
            "isTracking" -> result.success(isTrackingActive)
            "addGeofence" -> handleAddGeofence(call, result)
            "removeGeofence" -> handleRemoveGeofence(call, result)
            "getActiveGeofences" -> handleGetActiveGeofences(result)
            "requestPermission" -> handleRequestPermission(result)
            "checkPermission" -> handleCheckPermission(result)
            "requestBackgroundPermission" -> handleRequestBackgroundPermission(result)
            "enableFirebaseSync" -> handleEnableFirebaseSync(call, result)
            "disableFirebaseSync" -> handleDisableFirebaseSync(result)
            "setTrackingMode" -> handleSetTrackingMode(call, result)
            "openLocationSettings" -> handleOpenLocationSettings(result)
            "openAppSettings" -> handleOpenAppSettings(result)
            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------
    // Tracking
    // -------------------------------------------------------------------------

    private fun handleStartTracking(call: MethodCall, result: Result) {
        // Request notification permission on Android 13+ before starting foreground service
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val act = activity
            if (act != null && androidx.core.content.ContextCompat.checkSelfPermission(
                    act, android.Manifest.permission.POST_NOTIFICATIONS
                ) != android.content.pm.PackageManager.PERMISSION_GRANTED
            ) {
                // Save pending call and wait for permission result
                pendingTrackingCall = call
                pendingTrackingResult = result
                androidx.core.app.ActivityCompat.requestPermissions(
                    act,
                    arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                    1003
                )
                return
            }
        }

        doStartTracking(call, result)
    }

    private fun doStartTracking(call: MethodCall, result: Result) {
        val intervalMs = call.argument<Int>("intervalMs") ?: 5000
        val distanceFilter = call.argument<Double>("distanceFilter") ?: 10.0
        val accuracy = call.argument<Int>("accuracy") ?: 2
        val trackingMode = call.argument<Int>("trackingMode") ?: 1
        val showNotification = call.argument<Boolean>("showNotification") ?: true
        val notificationTitle = call.argument<String>("notificationTitle")
            ?: "Location Tracking Active"
        val notificationBody = call.argument<String>("notificationBody")
            ?: "Your location is being tracked in the background"
        val notificationChannelId = call.argument<String>("notificationChannelId")
            ?: "live_location_tracker_channel"
        val notificationIconName = call.argument<String>("notificationIconName")

        val serviceIntent = Intent(context, LocationService::class.java).apply {
            action = LocationService.ACTION_START
            putExtra(LocationService.EXTRA_INTERVAL_MS, intervalMs.toLong())
            putExtra(LocationService.EXTRA_DISTANCE_FILTER, distanceFilter.toFloat())
            putExtra(LocationService.EXTRA_ACCURACY, accuracy)
            putExtra(LocationService.EXTRA_TRACKING_MODE, trackingMode)
            putExtra(LocationService.EXTRA_SHOW_NOTIFICATION, showNotification)
            putExtra(LocationService.EXTRA_NOTIFICATION_TITLE, notificationTitle)
            putExtra(LocationService.EXTRA_NOTIFICATION_BODY, notificationBody)
            putExtra(LocationService.EXTRA_NOTIFICATION_CHANNEL_ID, notificationChannelId)
            putExtra(LocationService.EXTRA_NOTIFICATION_ICON_NAME, notificationIconName)
        }

        LocationService.setLocationStreamHandler(locationStreamHandler)
        LocationService.setFirebaseSyncManager(firebaseSyncManager)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }

        isTrackingActive = true
        result.success(true)
    }

    private fun handleStopTracking(result: Result) {
        val serviceIntent = Intent(context, LocationService::class.java).apply {
            action = LocationService.ACTION_STOP
        }
        context.startService(serviceIntent)
        isTrackingActive = false
        result.success(true)
    }

    private fun handleGetCurrentLocation(call: MethodCall, result: Result) {
        val accuracy = call.argument<Int>("accuracy") ?: 2
        LocationService.getCurrentLocation(context, accuracy) { locationMap ->
            if (locationMap != null) {
                result.success(locationMap)
            } else {
                result.error("LOCATION_ERROR", "Failed to get current location", null)
            }
        }
    }

    private fun handleSetTrackingMode(call: MethodCall, result: Result) {
        val mode = call.argument<Int>("mode") ?: 1
        val serviceIntent = Intent(context, LocationService::class.java).apply {
            action = LocationService.ACTION_UPDATE_MODE
            putExtra(LocationService.EXTRA_TRACKING_MODE, mode)
        }
        context.startService(serviceIntent)
        result.success(true)
    }

    // -------------------------------------------------------------------------
    // Geofencing
    // -------------------------------------------------------------------------

    private fun handleAddGeofence(call: MethodCall, result: Result) {
        val id = call.argument<String>("id") ?: return result.error("INVALID", "id required", null)
        val lat = call.argument<Double>("latitude")
            ?: return result.error("INVALID", "latitude required", null)
        val lng = call.argument<Double>("longitude")
            ?: return result.error("INVALID", "longitude required", null)
        val radius = call.argument<Double>("radius")?.toFloat()
            ?: return result.error("INVALID", "radius required", null)
        val triggers = call.argument<List<Int>>("triggers") ?: listOf(0, 1)
        val loiteringDelayMs = call.argument<Int>("loiteringDelayMs") ?: 0
        val expirationDurationMs = call.argument<Int>("expirationDurationMs")

        geofenceManager?.addGeofence(
            id, lat, lng, radius, triggers, loiteringDelayMs,
            expirationDurationMs?.toLong()
        ) { success ->
            result.success(success)
        }
    }

    private fun handleRemoveGeofence(call: MethodCall, result: Result) {
        val id = call.argument<String>("id")
            ?: return result.error("INVALID", "id required", null)
        geofenceManager?.removeGeofence(id) { success ->
            result.success(success)
        }
    }

    private fun handleGetActiveGeofences(result: Result) {
        val geofences = geofenceManager?.getActiveGeofences() ?: emptyList()
        result.success(geofences)
    }

    // -------------------------------------------------------------------------
    // Permissions
    // -------------------------------------------------------------------------

    private fun handleRequestPermission(result: Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }
        pendingPermissionResult = result
        permissionHandler?.requestForegroundPermission(act)
    }

    private fun handleCheckPermission(result: Result) {
        val status = permissionHandler?.checkPermission() ?: 0
        result.success(status)
    }

    private fun handleRequestBackgroundPermission(result: Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }
        pendingPermissionResult = result
        permissionHandler?.requestBackgroundPermission(act)
    }

    // -------------------------------------------------------------------------
    // Firebase Sync
    // -------------------------------------------------------------------------

    private fun handleEnableFirebaseSync(call: MethodCall, result: Result) {
        val collectionPath = call.argument<String>("collectionPath") ?: "live_locations"
        val userId = call.argument<String>("userId")
            ?: return result.error("INVALID", "userId required", null)
        val syncIntervalMs = call.argument<Int>("syncIntervalMs") ?: 10000

        val success = firebaseSyncManager?.enable(collectionPath, userId, syncIntervalMs.toLong())
            ?: false
        result.success(success)
    }

    private fun handleDisableFirebaseSync(result: Result) {
        firebaseSyncManager?.disable()
        result.success(true)
    }

    // -------------------------------------------------------------------------
    // Settings
    // -------------------------------------------------------------------------

    private fun handleOpenLocationSettings(result: Result) {
        try {
            val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun handleOpenAppSettings(result: Result) {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                data = android.net.Uri.parse("package:${context.packageName}")
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    // -------------------------------------------------------------------------
    // Permission Result Callback
    // -------------------------------------------------------------------------

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == 1003) {
            // Notification permission result — resume pending tracking
            val call = pendingTrackingCall
            val res = pendingTrackingResult
            pendingTrackingCall = null
            pendingTrackingResult = null
            if (call != null && res != null) {
                doStartTracking(call, res)
            }
            return true
        }

        val status = permissionHandler?.handlePermissionResult(requestCode, permissions, grantResults) ?: 0
        pendingPermissionResult?.success(status)
        pendingPermissionResult = null
        return true
    }

    // -------------------------------------------------------------------------
    // ActivityAware
    // -------------------------------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // -------------------------------------------------------------------------
    // Cleanup
    // -------------------------------------------------------------------------

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        // Null out sinks so service doesn't try to send to dead Flutter engine
        locationStreamHandler?.clearSink()
        geofenceStreamHandler?.clearSink()
        locationEventChannel.setStreamHandler(null)
        geofenceEventChannel.setStreamHandler(null)
    }
}

// =============================================================================
// Stream Handlers
// =============================================================================

/** Stream handler for location updates. */
class LocationStreamHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun sendLocation(locationMap: Map<String, Any?>) {
        try {
            eventSink?.success(locationMap)
        } catch (e: Exception) {
            // Flutter engine detached — service keeps running silently
        }
    }

    fun clearSink() {
        eventSink = null
    }
}

/** Stream handler for geofence events. */
class GeofenceStreamHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun sendGeofenceEvent(eventMap: Map<String, Any?>) {
        try {
            eventSink?.success(eventMap)
        } catch (e: Exception) {
            // Flutter engine detached — service keeps running silently
        }
    }

    fun clearSink() {
        eventSink = null
    }
}
