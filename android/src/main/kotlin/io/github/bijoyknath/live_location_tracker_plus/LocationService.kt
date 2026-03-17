package io.github.bijoyknath.live_location_tracker_plus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.ServiceCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

/**
 * Android foreground service for continuous background location tracking.
 *
 * Uses FusedLocationProviderClient for battery-efficient location updates.
 */
class LocationService : Service() {

    companion object {
        const val TAG = "LocationService"
        const val NOTIFICATION_ID = 12345
        const val DEFAULT_CHANNEL_ID = "live_location_tracker_channel"

        const val ACTION_START = "ACTION_START_TRACKING"
        const val ACTION_STOP = "ACTION_STOP_TRACKING"
        const val ACTION_UPDATE_MODE = "ACTION_UPDATE_MODE"

        const val EXTRA_INTERVAL_MS = "intervalMs"
        const val EXTRA_DISTANCE_FILTER = "distanceFilter"
        const val EXTRA_ACCURACY = "accuracy"
        const val EXTRA_TRACKING_MODE = "trackingMode"
        const val EXTRA_SHOW_NOTIFICATION = "showNotification"
        const val EXTRA_NOTIFICATION_TITLE = "notificationTitle"
        const val EXTRA_NOTIFICATION_BODY = "notificationBody"
        const val EXTRA_NOTIFICATION_CHANNEL_ID = "notificationChannelId"
        const val EXTRA_NOTIFICATION_ICON_NAME = "notificationIconName"

        private var locationStreamHandler: LocationStreamHandler? = null
        private var firebaseSyncManager: FirebaseSyncManager? = null

        fun setLocationStreamHandler(handler: LocationStreamHandler?) {
            locationStreamHandler = handler
        }

        fun setFirebaseSyncManager(manager: FirebaseSyncManager?) {
            firebaseSyncManager = manager
        }

        /**
         * Gets the current location as a single shot using FusedLocationProviderClient.
         */
        fun getCurrentLocation(
            context: Context,
            accuracy: Int,
            callback: (Map<String, Any?>?) -> Unit
        ) {
            val client = LocationServices.getFusedLocationProviderClient(context)
            val priority = mapAccuracyToPriority(accuracy)

            try {
                client.getCurrentLocation(priority, null)
                    .addOnSuccessListener { location ->
                        if (location != null) {
                            callback(locationToMap(location, false))
                        } else {
                            callback(null)
                        }
                    }
                    .addOnFailureListener {
                        Log.e(TAG, "getCurrentLocation failed", it)
                        callback(null)
                    }
            } catch (e: SecurityException) {
                Log.e(TAG, "SecurityException in getCurrentLocation", e)
                callback(null)
            }
        }

        private fun mapAccuracyToPriority(accuracy: Int): Int {
            return when (accuracy) {
                0 -> Priority.PRIORITY_LOW_POWER          // low
                1 -> Priority.PRIORITY_BALANCED_POWER_ACCURACY  // balanced
                2 -> Priority.PRIORITY_HIGH_ACCURACY      // high
                3 -> Priority.PRIORITY_HIGH_ACCURACY      // best
                else -> Priority.PRIORITY_HIGH_ACCURACY
            }
        }

        private fun locationToMap(
            location: android.location.Location,
            isBackground: Boolean
        ): Map<String, Any?> {
            return mapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "altitude" to location.altitude,
                "speed" to location.speed.toDouble(),
                "heading" to location.bearing.toDouble(),
                "accuracy" to location.accuracy.toDouble(),
                "timestamp" to location.time,
                "isFromBackground" to isBackground
            )
        }
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private var locationCallback: LocationCallback? = null
    private var isRunning = false

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val intervalMs = intent.getLongExtra(EXTRA_INTERVAL_MS, 5000L)
                val distanceFilter = intent.getFloatExtra(EXTRA_DISTANCE_FILTER, 10f)
                val accuracy = intent.getIntExtra(EXTRA_ACCURACY, 2)
                val trackingMode = intent.getIntExtra(EXTRA_TRACKING_MODE, 1)
                val showNotification = intent.getBooleanExtra(EXTRA_SHOW_NOTIFICATION, true)
                val title = intent.getStringExtra(EXTRA_NOTIFICATION_TITLE)
                    ?: "Location Tracking Active"
                val body = intent.getStringExtra(EXTRA_NOTIFICATION_BODY)
                    ?: "Your location is being tracked in the background"
                val channelId = intent.getStringExtra(EXTRA_NOTIFICATION_CHANNEL_ID)
                    ?: DEFAULT_CHANNEL_ID
                val iconName = intent.getStringExtra(EXTRA_NOTIFICATION_ICON_NAME)

                // ALWAYS call startForeground — required by Android for foreground services
                // Without this, the OS kills the service after ~5 seconds in background
                val notification = createNotification(title, body, channelId, iconName)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    ServiceCompat.startForeground(
                        this,
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }

                // Save tracking state for restart after reboot/swipe
                getSharedPreferences("live_location_tracker_prefs", MODE_PRIVATE)
                    .edit()
                    .putBoolean("was_tracking", true)
                    .putLong("interval_ms", intervalMs)
                    .putFloat("distance_filter", distanceFilter)
                    .putInt("accuracy", accuracy)
                    .putInt("tracking_mode", trackingMode)
                    .putString("notification_title", title)
                    .putString("notification_body", body)
                    .apply()

                startLocationUpdates(intervalMs, distanceFilter, accuracy, trackingMode)
            }
            ACTION_STOP -> {
                stopLocationUpdates()
                // Clear tracking state
                getSharedPreferences("live_location_tracker_prefs", MODE_PRIVATE)
                    .edit()
                    .putBoolean("was_tracking", false)
                    .apply()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            ACTION_UPDATE_MODE -> {
                val trackingMode = intent.getIntExtra(EXTRA_TRACKING_MODE, 1)
                updateTrackingMode(trackingMode)
            }
        }
        return START_STICKY
    }

    private fun startLocationUpdates(
        intervalMs: Long,
        distanceFilter: Float,
        accuracy: Int,
        trackingMode: Int
    ) {
        if (isRunning) {
            stopLocationUpdates()
        }

        val effectiveInterval = when (trackingMode) {
            0 -> intervalMs                  // highAccuracy: use configured interval
            1 -> intervalMs                  // balanced: use configured
            2 -> maxOf(intervalMs, 30000L)   // lowPower: at least 30s
            else -> intervalMs
        }

        val priority = mapAccuracyToPriority(accuracy)

        val locationRequest = LocationRequest.Builder(priority, effectiveInterval)
            .setMinUpdateDistanceMeters(distanceFilter)
            .setMinUpdateIntervalMillis(effectiveInterval / 2)
            .setWaitForAccurateLocation(accuracy >= 2)
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let { location ->
                    val locationMap = locationToMap(location, true)

                    // Send to Flutter stream
                    locationStreamHandler?.sendLocation(locationMap)

                    // Sync to Firebase if enabled
                    firebaseSyncManager?.syncLocation(locationMap)
                }
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback!!,
                Looper.getMainLooper()
            )
            isRunning = true
            Log.d(TAG, "Location updates started (interval: ${effectiveInterval}ms)")
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException starting location updates", e)
        }
    }

    private fun stopLocationUpdates() {
        locationCallback?.let {
            fusedLocationClient.removeLocationUpdates(it)
        }
        locationCallback = null
        isRunning = false
        Log.d(TAG, "Location updates stopped")
    }

    private fun updateTrackingMode(trackingMode: Int) {
        // Re-request with updated mode (restarts with new parameters)
        if (isRunning) {
            val interval = when (trackingMode) {
                0 -> 2000L   // highAccuracy
                1 -> 5000L   // balanced
                2 -> 30000L  // lowPower
                else -> 5000L
            }
            val accuracy = when (trackingMode) {
                0 -> 3  // best
                1 -> 2  // high
                2 -> 0  // low
                else -> 2
            }
            startLocationUpdates(interval, 5f, accuracy, trackingMode)
        }
    }

    private fun createNotification(
        title: String,
        body: String,
        channelId: String,
        iconName: String?
    ): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notification for background location tracking"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val iconResId = if (iconName != null) {
            resources.getIdentifier(iconName, "drawable", packageName).takeIf { it != 0 }
                ?: resources.getIdentifier("ic_launcher", "mipmap", packageName)
        } else {
            resources.getIdentifier("ic_launcher", "mipmap", packageName)
        }

        // Create pending intent to open the app when notification is tapped
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = if (launchIntent != null) {
            PendingIntent.getActivity(
                this, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(iconResId)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Foreground service stays alive when app is swiped away.
        // No restart needed — START_STICKY + foreground notification keeps it running.
        Log.d(TAG, "Task removed — foreground service continues running")
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        stopLocationUpdates()
        super.onDestroy()
    }
}
