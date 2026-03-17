package io.github.bijoyknath.live_location_tracker_plus

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receives BOOT_COMPLETED broadcast to potentially restart tracking after device reboot.
 *
 * For this to work, the app must save tracking state to SharedPreferences
 * before the device reboots.
 */
class BootCompletedReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "BootCompletedReceiver"
        const val PREFS_NAME = "live_location_tracker_prefs"
        const val KEY_WAS_TRACKING = "was_tracking"
        const val KEY_INTERVAL_MS = "interval_ms"
        const val KEY_DISTANCE_FILTER = "distance_filter"
        const val KEY_ACCURACY = "accuracy"
        const val KEY_TRACKING_MODE = "tracking_mode"
        const val KEY_NOTIFICATION_TITLE = "notification_title"
        const val KEY_NOTIFICATION_BODY = "notification_body"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val wasTracking = prefs.getBoolean(KEY_WAS_TRACKING, false)

        if (!wasTracking) {
            Log.d(TAG, "Boot completed: tracking was not active, skipping restart")
            return
        }

        Log.d(TAG, "Boot completed: restarting location tracking service")

        val serviceIntent = Intent(context, LocationService::class.java).apply {
            action = LocationService.ACTION_START
            putExtra(LocationService.EXTRA_INTERVAL_MS,
                prefs.getLong(KEY_INTERVAL_MS, 5000L))
            putExtra(LocationService.EXTRA_DISTANCE_FILTER,
                prefs.getFloat(KEY_DISTANCE_FILTER, 10f))
            putExtra(LocationService.EXTRA_ACCURACY,
                prefs.getInt(KEY_ACCURACY, 2))
            putExtra(LocationService.EXTRA_TRACKING_MODE,
                prefs.getInt(KEY_TRACKING_MODE, 1))
            putExtra(LocationService.EXTRA_SHOW_NOTIFICATION, true)
            putExtra(LocationService.EXTRA_NOTIFICATION_TITLE,
                prefs.getString(KEY_NOTIFICATION_TITLE, "Location Tracking Active"))
            putExtra(LocationService.EXTRA_NOTIFICATION_BODY,
                prefs.getString(KEY_NOTIFICATION_BODY, "Your location is being tracked"))
        }

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
