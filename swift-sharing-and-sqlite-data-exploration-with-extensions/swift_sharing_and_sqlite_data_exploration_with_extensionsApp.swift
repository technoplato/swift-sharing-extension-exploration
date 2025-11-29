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

extension DatabaseWriter where Self == DatabaseQueue {
    static var appDatabase: Self {
        let databaseURL = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("db.sqlite")
            
        let databaseQueue = try! DatabaseQueue(path: databaseURL.path)
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("Create 'items' table") { db in
            try db.create(table: "items") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("timestamp", .datetime).notNull()
            }
        }
        try! migrator.migrate(databaseQueue)
        
        return databaseQueue
    }
}
