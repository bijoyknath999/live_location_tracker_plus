package io.github.bijoyknath.live_location_tracker_plus

import android.util.Log

/**
 * Manages optional Firebase Firestore sync for location data.
 *
 * Firebase Firestore is a compileOnly dependency — it must be included by the host app.
 * This class gracefully handles the case where Firebase is not available.
 */
class FirebaseSyncManager {
    companion object {
        const val TAG = "FirebaseSyncManager"
    }

    private var isEnabled = false
    private var collectionPath = "live_locations"
    private var userId = ""
    private var syncIntervalMs = 10000L
    private var lastSyncTime = 0L

    private var firestore: Any? = null

    /**
     * Enables Firebase sync with the given configuration.
     */
    fun enable(collectionPath: String, userId: String, syncIntervalMs: Long): Boolean {
        this.collectionPath = collectionPath
        this.userId = userId
        this.syncIntervalMs = syncIntervalMs

        return try {
            // Try to get Firestore instance via reflection (since it's compileOnly)
            val firestoreClass = Class.forName("com.google.firebase.firestore.FirebaseFirestore")
            val getInstanceMethod = firestoreClass.getMethod("getInstance")
            firestore = getInstanceMethod.invoke(null)
            isEnabled = true
            Log.d(TAG, "Firebase sync enabled for collection: $collectionPath, user: $userId")
            true
        } catch (e: ClassNotFoundException) {
            Log.w(TAG, "Firebase Firestore not found in classpath. Add firebase-firestore dependency to your app.")
            isEnabled = false
            false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Firebase Firestore", e)
            isEnabled = false
            false
        }
    }

    /**
     * Disables Firebase sync.
     */
    fun disable() {
        isEnabled = false
        firestore = null
        Log.d(TAG, "Firebase sync disabled")
    }

    /**
     * Syncs a location update to Firestore if enabled and sync interval has elapsed.
     */
    fun syncLocation(locationMap: Map<String, Any?>) {
        if (!isEnabled || firestore == null) return

        val now = System.currentTimeMillis()
        if (now - lastSyncTime < syncIntervalMs) return
        lastSyncTime = now

        try {
            val firestoreClass = Class.forName("com.google.firebase.firestore.FirebaseFirestore")

            // firestore.collection(collectionPath).document(userId).collection("locations").add(data)
            val collectionMethod = firestoreClass.getMethod("collection", String::class.java)
            val collectionRef = collectionMethod.invoke(firestore, collectionPath)

            val collRefClass = Class.forName("com.google.firebase.firestore.CollectionReference")
            val documentMethod = collRefClass.getMethod("document", String::class.java)
            val docRef = documentMethod.invoke(collectionRef, userId)

            val docRefClass = Class.forName("com.google.firebase.firestore.DocumentReference")
            val subCollectionMethod = docRefClass.getMethod("collection", String::class.java)
            val locationsRef = subCollectionMethod.invoke(docRef, "locations")

            val addMethod = collRefClass.getMethod("add", Any::class.java)

            val data = HashMap<String, Any?>()
            data.putAll(locationMap)
            data["syncedAt"] = now

            addMethod.invoke(locationsRef, data)

            Log.d(TAG, "Location synced to Firebase")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to sync location to Firebase", e)
        }
    }

    /**
     * Syncs a geofence event to Firestore.
     */
    fun syncGeofenceEvent(eventMap: Map<String, Any?>) {
        if (!isEnabled || firestore == null) return

        try {
            val firestoreClass = Class.forName("com.google.firebase.firestore.FirebaseFirestore")
            val collectionMethod = firestoreClass.getMethod("collection", String::class.java)
            val collectionRef = collectionMethod.invoke(firestore, collectionPath)

            val collRefClass = Class.forName("com.google.firebase.firestore.CollectionReference")
            val documentMethod = collRefClass.getMethod("document", String::class.java)
            val docRef = documentMethod.invoke(collectionRef, userId)

            val docRefClass = Class.forName("com.google.firebase.firestore.DocumentReference")
            val subCollectionMethod = docRefClass.getMethod("collection", String::class.java)
            val eventsRef = subCollectionMethod.invoke(docRef, "geofence_events")

            val addMethod = collRefClass.getMethod("add", Any::class.java)

            val data = HashMap<String, Any?>()
            data.putAll(eventMap)
            data["syncedAt"] = System.currentTimeMillis()

            addMethod.invoke(eventsRef, data)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to sync geofence event to Firebase", e)
        }
    }
}
