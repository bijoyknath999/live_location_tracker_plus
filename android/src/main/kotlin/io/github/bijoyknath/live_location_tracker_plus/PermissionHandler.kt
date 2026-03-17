package io.github.bijoyknath.live_location_tracker_plus

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

/**
 * Handles runtime permission requests for location access on Android.
 */
class PermissionHandler(private val context: Context) {

    companion object {
        const val REQUEST_CODE_FOREGROUND = 1001
        const val REQUEST_CODE_BACKGROUND = 1002
    }

    /**
     * Checks the current location permission status.
     *
     * Returns an int matching the Dart LocationPermissionStatus enum:
     * 0 = notDetermined, 1 = denied, 2 = deniedForever, 3 = whileInUse, 4 = always
     */
    fun checkPermission(): Int {
        val fineGranted = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val coarseGranted = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        if (!fineGranted && !coarseGranted) {
            return 1 // denied
        }

        // Check background permission (Android 10+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val backgroundGranted = ContextCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            return if (backgroundGranted) 4 else 3 // always : whileInUse
        }

        // Pre-Android 10: foreground permission implies background
        return 4 // always
    }

    /**
     * Requests foreground location permission (ACCESS_FINE_LOCATION + ACCESS_COARSE_LOCATION).
     */
    fun requestForegroundPermission(activity: Activity) {
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ),
            REQUEST_CODE_FOREGROUND
        )
    }

    /**
     * Requests background location permission (Android 10+).
     */
    fun requestBackgroundPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                REQUEST_CODE_BACKGROUND
            )
        }
    }

    /**
     * Handles the result of a permission request.
     * Returns the updated permission status as an int.
     */
    fun handlePermissionResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Int {
        if (grantResults.isEmpty()) return 1 // denied

        when (requestCode) {
            REQUEST_CODE_FOREGROUND -> {
                val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                if (!allGranted) {
                    // Check if user selected "Don't ask again"
                    val activity = context as? Activity
                    if (activity != null) {
                        val shouldShowRationale = permissions.any {
                            ActivityCompat.shouldShowRequestPermissionRationale(activity, it)
                        }
                        return if (!shouldShowRationale) 2 else 1 // deniedForever : denied
                    }
                    return 1 // denied
                }
                return 3 // whileInUse
            }
            REQUEST_CODE_BACKGROUND -> {
                val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
                return if (granted) 4 else 3 // always : whileInUse
            }
            else -> return checkPermission()
        }
    }
}
