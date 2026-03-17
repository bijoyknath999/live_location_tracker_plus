import Foundation

/// Optional Firebase Firestore sync manager for iOS.
///
/// Since Firebase is an optional dependency, this class checks for its
/// availability at runtime. If Firebase Firestore is not included in the
/// host app, sync operations are silently skipped.
///
/// To use Firebase sync, the host app must include FirebaseFirestore in
/// its Podfile and initialize Firebase before enabling sync.
class LLTFirebaseSyncManager {

    private var isEnabled = false
    private var collectionPath = "live_locations"
    private var userId = ""
    private var syncIntervalMs = 10000
    private var lastSyncTime: Int64 = 0

    // MARK: - Public API

    /// Enables Firebase sync.
    /// Returns true if Firebase Firestore is available and sync was enabled.
    func enable(collectionPath: String, userId: String, syncIntervalMs: Int) -> Bool {
        self.collectionPath = collectionPath
        self.userId = userId
        self.syncIntervalMs = syncIntervalMs

        // Check if Firestore class is available at runtime
        guard NSClassFromString("FIRFirestore") != nil else {
            NSLog("LiveLocationTracker: Firebase Firestore not found. Add FirebaseFirestore to your Podfile.")
            isEnabled = false
            return false
        }

        isEnabled = true
        NSLog("LiveLocationTracker: Firebase sync enabled for \(collectionPath)/\(userId)")
        return true
    }

    /// Disables Firebase sync.
    func disable() {
        isEnabled = false
        NSLog("LiveLocationTracker: Firebase sync disabled")
    }

    /// Syncs a location update to Firestore if enabled and interval has elapsed.
    func syncLocation(_ locationMap: [String: Any?]) {
        guard isEnabled else { return }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        if now - lastSyncTime < Int64(syncIntervalMs) { return }
        lastSyncTime = now

        // Build the document data
        var data = locationMap.compactMapValues { $0 }
        data["syncedAt"] = now

        // Use NSClassFromString + NSSelectorFromString to call Firestore dynamically
        guard let firestoreClass = NSClassFromString("FIRFirestore") as? NSObject.Type else {
            return
        }

        let firestoreSel = NSSelectorFromString("firestore")
        guard firestoreClass.responds(to: firestoreSel) else { return }

        // Get Firestore instance
        let result = firestoreClass.perform(firestoreSel)
        guard let firestore = result?.takeUnretainedValue() as? NSObject else { return }

        // firestore.collection(collectionPath)
        let collSel = NSSelectorFromString("collectionWithPath:")
        guard firestore.responds(to: collSel) else { return }
        guard let collRef = firestore.perform(collSel, with: collectionPath)?.takeUnretainedValue() as? NSObject else { return }

        // collRef.document(userId)
        let docSel = NSSelectorFromString("documentWithPath:")
        guard collRef.responds(to: docSel) else { return }
        guard let docRef = collRef.perform(docSel, with: userId)?.takeUnretainedValue() as? NSObject else { return }

        // docRef.collection("locations")
        guard let locCollRef = docRef.perform(collSel, with: "locations")?.takeUnretainedValue() as? NSObject else { return }

        // locCollRef.addDocument(data:)
        let addSel = NSSelectorFromString("addDocumentWithData:completion:")
        if locCollRef.responds(to: addSel) {
            locCollRef.perform(addSel, with: data, with: nil)
            NSLog("LiveLocationTracker: Location synced to Firebase")
        }
    }
}
