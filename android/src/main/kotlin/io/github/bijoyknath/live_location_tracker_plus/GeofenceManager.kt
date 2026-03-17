package io.github.bijoyknath.live_location_tracker_plus

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices

/**
 * Manages geofence registration and event handling using Google Play Services.
 */
class GeofenceManager(
    private val context: Context,
    private val geofenceStreamHandler: GeofenceStreamHandler?
) {
    companion object {
        const val TAG = "GeofenceManager"
        private var staticStreamHandler: GeofenceStreamHandler? = null
        val pendingGeofenceEvents = mutableListOf<Map<String, Any?>>()

        fun getStreamHandler(): GeofenceStreamHandler? = staticStreamHandler
    }

    private val geofencingClient: GeofencingClient =
        LocationServices.getGeofencingClient(context)

    // Cache active geofences for getActiveGeofences()
    private val activeGeofences = mutableMapOf<String, Map<String, Any?>>()

    init {
        staticStreamHandler = geofenceStreamHandler
    }

    /**
     * Adds a circular geofence.
     */
    fun addGeofence(
        id: String,
        latitude: Double,
        longitude: Double,
        radius: Float,
        triggers: List<Int>,
        loiteringDelayMs: Int,
        expirationDurationMs: Long?,
        callback: (Boolean) -> Unit
    ) {
        var transitionTypes = 0
        for (trigger in triggers) {
            transitionTypes = transitionTypes or when (trigger) {
                0 -> Geofence.GEOFENCE_TRANSITION_ENTER
                1 -> Geofence.GEOFENCE_TRANSITION_EXIT
                2 -> Geofence.GEOFENCE_TRANSITION_DWELL
                else -> 0
            }
        }

        val geofence = Geofence.Builder()
            .setRequestId(id)
            .setCircularRegion(latitude, longitude, radius)
            .setExpirationDuration(expirationDurationMs ?: Geofence.NEVER_EXPIRE)
            .setTransitionTypes(transitionTypes)
            .setLoiteringDelay(loiteringDelayMs)
            .build()

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofence(geofence)
            .build()

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.e(TAG, "Location permission not granted for geofencing")
            callback(false)
            return
        }

        geofencingClient.addGeofences(request, getGeofencePendingIntent())
            .addOnSuccessListener {
                activeGeofences[id] = mapOf(
                    "id" to id,
                    "latitude" to latitude,
                    "longitude" to longitude,
                    "radius" to radius.toDouble(),
                    "triggers" to triggers
                )
                Log.d(TAG, "Geofence added: $id")
                callback(true)
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to add geofence: $id", e)
                callback(false)
            }
    }

    /**
     * Removes a geofence by ID.
     */
    fun removeGeofence(id: String, callback: (Boolean) -> Unit) {
        geofencingClient.removeGeofences(listOf(id))
            .addOnSuccessListener {
                activeGeofences.remove(id)
                Log.d(TAG, "Geofence removed: $id")
                callback(true)
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to remove geofence: $id", e)
                callback(false)
            }
    }

    /**
     * Returns all currently tracked geofences.
     */
    fun getActiveGeofences(): List<Map<String, Any?>> {
        return activeGeofences.values.toList()
    }

    private fun getGeofencePendingIntent(): PendingIntent {
        val intent = Intent(context, GeofenceBroadcastReceiver::class.java)
        return PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
    }
}
