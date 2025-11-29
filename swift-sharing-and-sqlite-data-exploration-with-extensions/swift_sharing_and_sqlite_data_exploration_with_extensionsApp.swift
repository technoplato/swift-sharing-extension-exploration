import SwiftUI
import SQLiteData
import GRDB

@main
struct swift_sharing_and_sqlite_data_exploration_with_extensionsApp: App {
    init() {
        prepareDependencies {
            $0.defaultDatabase = .appDatabase
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

