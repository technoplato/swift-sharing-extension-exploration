import Foundation
import SQLiteData
import GRDB

@Table
struct Item: Identifiable {
    let id: UUID
    var title: String
    var timestamp: Date
}

extension DatabaseWriter where Self == DatabaseQueue {
    static var appDatabase: Self {
        let databaseURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.halfjew22.swift-sharing-exploration")!
            .appendingPathComponent("db.sqlite")
            
        var databaseQueue: DatabaseQueue
        do {
            databaseQueue = try DatabaseQueue(path: databaseURL.path)
        } catch {
            // Fallback for when App Group is not accessible (e.g. during previews if not configured)
            // or if the directory doesn't exist yet.
            print("Failed to access App Group container: \(error)")
            databaseQueue = try! DatabaseQueue(path: databaseURL.path)
        }
        
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
