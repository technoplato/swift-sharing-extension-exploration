import Foundation
import SQLiteData
import GRDB
import Dependencies

@Table
struct Item: Identifiable, Equatable {
    let id: UUID
    var title: String
    var timestamp: Date
}

extension DatabaseWriter where Self == DatabasePool {
    static var appDatabase: Self {
        let databaseURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.halfjew22.swift-sharing-exploration")!
            .appendingPathComponent("db.sqlite")
            
        var configuration = Configuration()
        configuration.busyMode = .timeout(5.0) // Wait up to 5 seconds for the lock
        
        var databasePool: DatabasePool
        do {
            databasePool = try DatabasePool(path: databaseURL.path, configuration: configuration)
        } catch {
            // Fallback for when App Group is not accessible (e.g. during previews if not configured)
            // or if the directory doesn't exist yet.
            print("Failed to access App Group container: \(error)")
            databasePool = try! DatabasePool(path: databaseURL.path, configuration: configuration)
        }
        
        var migrator = DatabaseMigrator()
        
        // Original migration (kept for history, though we will effectively reset)
        migrator.registerMigration("Create 'items' table") { db in
            try db.create(table: "items") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("timestamp", .datetime).notNull()
            }
        }
        
        // CloudKit compatible migration: Recreate table with correct constraints
        migrator.registerMigration("Recreate 'items' table for CloudKit") { db in
            if try db.tableExists("items") {
                try db.drop(table: "items")
            }
            try db.create(table: "items") { t in
                t.column("id", .text).primaryKey(onConflict: .replace).notNull()
                t.column("title", .text).notNull()
                t.column("timestamp", .datetime).notNull()
            }
        }
        
        try! migrator.migrate(databasePool)
        
        return databasePool
    }
}

extension DependencyValues {
    private static var observer: DatabaseChangeObserver?

    mutating func bootstrapDatabase() throws {
        defaultDatabase = try DatabasePool.appDatabase
        defaultSyncEngine = try SyncEngine(
            for: defaultDatabase,
            tables: Item.self,
            containerIdentifier: "iCloud.com.halfjew22.swift-sharing-exploration"
        )
        Self.observer = DatabaseChangeObserver(database: defaultDatabase)
    }
}

import OSLog

extension Logger {
    static let shared = Logger(subsystem: "com.halfjew22.swift-sharing-exploration", category: "General")
}

struct FileLogger {
    static func log(_ message: String) {
        // Log to system console
        Logger.shared.info("\(message, privacy: .public)")
        
        // Also log to database for persistence (if it works)
        let item = Item(id: UUID(), title: "LOG: \(message)", timestamp: Date())
        do {
            try DatabasePool.appDatabase.write { db in
                try Item.insert { item }.execute(db)
            }
            notifyDatabaseChange()
        } catch {
            Logger.shared.error("Failed to log to database: \(error, privacy: .public)")
        }
    }
}

func notifyDatabaseChange() {
    let notificationName = CFNotificationName("com.halfjew22.swift-sharing-exploration.database_changed" as CFString)
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    CFNotificationCenterPostNotification(center, notificationName, nil, nil, true)
}

final class DatabaseChangeObserver: ObservableObject {
    init(database: DatabaseWriter) {
        let notificationName = "com.halfjew22.swift-sharing-exploration.database_changed" as CFString
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        
        CFNotificationCenterAddObserver(center, Unmanaged.passUnretained(self).toOpaque(), { _, _, _, _, _ in
            Logger.shared.info("Received Darwin notification for database change")
            
            // Bridge to NotificationCenter for SwiftUI views
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("com.halfjew22.swift-sharing-exploration.database_changed"), object: nil)
                
                // Also try to force a database check if possible, but @FetchAll usually needs a write to trigger.
                // We can try a no-op write to the database to force @FetchAll to reload.
                // This is a bit hacky but effective for cross-process triggers with GRDB.
                Task {
                    try? await DatabasePool.appDatabase.write { db in
                        // No-op write to trigger observers
                        try db.execute(sql: "UPDATE items SET id = id WHERE 0")
                    }
                }
            }
        }, notificationName, nil, .deliverImmediately)
    }
}
