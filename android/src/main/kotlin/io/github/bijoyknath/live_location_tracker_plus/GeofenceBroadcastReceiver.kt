package io.github.bijoyknath.live_location_tracker_plus

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

/**
 * Receives geofence transition broadcasts from the system.
 *
 * Processes enter, exit, and dwell events and forwards them to the
 * GeofenceStreamHandler for delivery to the Flutter side.
 */
class GeofenceBroadcastReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "GeofenceBroadcastRecv"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val geofencingEvent = GeofencingEvent.fromIntent(intent) ?: return

        if (geofencingEvent.hasError()) {
            Log.e(TAG, "Geofence error: ${geofencingEvent.errorCode}")
            return
        }

        val transition = geofencingEvent.geofenceTransition
        val triggerType = when (transition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> 0
            Geofence.GEOFENCE_TRANSITION_EXIT -> 1
            Geofence.GEOFENCE_TRANSITION_DWELL -> 2
            else -> return
        }

        val triggeringGeofences = geofencingEvent.triggeringGeofences ?: return
        val triggeringLocation = geofencingEvent.triggeringLocation

        for (geofence in triggeringGeofences) {
            val eventMap = mapOf<String, Any?>(
                "region" to mapOf(
                    "id" to geofence.requestId,
                    "latitude" to (triggeringLocation?.latitude ?: 0.0),
                    "longitude" to (triggeringLocation?.longitude ?: 0.0),
                    "radius" to 0.0,
                    "triggers" to listOf(triggerType)
                ),
                "triggerType" to triggerType,
                "timestamp" to System.currentTimeMillis(),
                "location" to if (triggeringLocation != null) mapOf(
                    "latitude" to triggeringLocation.latitude,
                    "longitude" to triggeringLocation.longitude,
                    "altitude" to triggeringLocation.altitude,
                    "speed" to triggeringLocation.speed.toDouble(),
                    "heading" to triggeringLocation.bearing.toDouble(),
                    "accuracy" to triggeringLocation.accuracy.toDouble(),
                    "timestamp" to triggeringLocation.time,
                    "isFromBackground" to true
                ) else null
            )

            Log.d(TAG, "Geofence event: ${geofence.requestId} transition=$triggerType")

            // Send to Flutter on main thread
            Handler(Looper.getMainLooper()).post {
                GeofenceManager.getStreamHandler()?.sendGeofenceEvent(eventMap)
            }
        }
    }
}
