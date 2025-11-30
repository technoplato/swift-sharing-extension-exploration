import SwiftUI
// import SQLiteData
// import GRDB
import SharingFirestore
import FirebaseCore


@main
struct swift_sharing_and_sqlite_data_exploration_with_extensionsApp: App {
    init() {
        try! prepareDependencies {
            try! $0.bootstrapDatabase()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

