import Foundation
import SQLiteData
import GRDB

extension Notification.Name {
    static let databaseChanged = Notification.Name("com.halfjew22.swift-sharing-exploration.databaseChanged")
}

func notifyDatabaseChange() {
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    let name = Notification.Name.databaseChanged.rawValue as CFString
    CFNotificationCenterPostNotification(center, name, nil, nil, true)
}

class DatabaseChangeObserver {
    static let shared = DatabaseChangeObserver()
    
    private init() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = Notification.Name.databaseChanged.rawValue as CFString
        
        CFNotificationCenterAddObserver(center, Unmanaged.passUnretained(self).toOpaque(), { _, _, _, _, _ in
            // When Darwin notification is received, post a local notification
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .databaseChanged, object: nil)
            }
        }, name, nil, .deliverImmediately)
    }
}

@Table
struct Item: Identifiable {
    let id: UUID
    var title: String
    var timestamp: Date
}

extension DatabaseWriter where Self == DatabasePool {
    static var appDatabase: Self {
        let databaseURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.halfjew22.swift-sharing-exploration")!
            .appendingPathComponent("db.sqlite")
            
        var databasePool: DatabasePool
        do {
            databasePool = try DatabasePool(path: databaseURL.path)
        } catch {
            // Fallback for when App Group is not accessible (e.g. during previews if not configured)
            // or if the directory doesn't exist yet.
            print("Failed to access App Group container: \(error)")
            databasePool = try! DatabasePool(path: databaseURL.path)
        }
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("Create 'items' table") { db in
            try db.create(table: "items") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("timestamp", .datetime).notNull()
            }
        }
        try! migrator.migrate(databasePool)
        
        return databasePool
    }
}
