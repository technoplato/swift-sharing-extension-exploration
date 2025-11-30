import Foundation
// import SQLiteData
// import GRDB
import Dependencies
import SharingFirestore
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import Sharing

// @Table
// struct Item: Identifiable, Equatable {
//     let id: UUID
//     var title: String
//     var timestamp: Date
// }

struct Item: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var timestamp: Date
}


extension DependencyValues {
    // private static var observer: DatabaseChangeObserver?

    mutating func bootstrapDatabase() throws {
        // ... (commented out code)
        
        // Firestore Setup
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        self.defaultFirestore = Firestore.firestore()
        
        // SharingFirestore requires an authenticated user to listen to queries.
        if Auth.auth().currentUser == nil {
            Task {
                do {
                    try await Auth.auth().signInAnonymously()
                    Logger.shared.info("Signed in anonymously to Firebase")
                } catch {
                    Logger.shared.error("Failed to sign in anonymously: \(error)")
                }
            }
        }
    }
}

import OSLog

extension Logger {
    static let shared = Logger(subsystem: "com.halfjew22.swift-sharing-exploration", category: "General")
}

struct FileLogger {
    // We need to inject the database dependency manually or use the shared instance if available
    // For static context, we might need a workaround or just use Firestore directly
    
    static func log(_ message: String) {
        // Log to system console
        Logger.shared.info("\(message, privacy: .public)")
        
        // Also log to database for persistence (if it works)
        let item = Item(id: UUID(), title: "LOG: \(message)", timestamp: Date())
        
        // Using Firestore directly for static logging
        if FirebaseApp.app() != nil {
             do {
                 try Firestore.firestore().collection("items").addDocument(from: item)
             } catch {
                 Logger.shared.error("Failed to log to Firestore: \(error, privacy: .public)")
             }
        }
    }
}

// func notifyDatabaseChange() {
//     let notificationName = CFNotificationName("com.halfjew22.swift-sharing-exploration.database_changed" as CFString)
//     let center = CFNotificationCenterGetDarwinNotifyCenter()
//     CFNotificationCenterPostNotification(center, notificationName, nil, nil, true)
// }

// final class DatabaseChangeObserver: ObservableObject {
//     init(database: DatabaseWriter) {
//         let notificationName = "com.halfjew22.swift-sharing-exploration.database_changed" as CFString
//         let center = CFNotificationCenterGetDarwinNotifyCenter()
//         
//         CFNotificationCenterAddObserver(center, Unmanaged.passUnretained(self).toOpaque(), { _, _, _, _, _ in
//             Logger.shared.info("Received Darwin notification for database change")
//             
//             // Bridge to NotificationCenter for SwiftUI views
//             DispatchQueue.main.async {
//                 NotificationCenter.default.post(name: Notification.Name("com.halfjew22.swift-sharing-exploration.database_changed"), object: nil)
//                 
//                 // Also try to force a database check if possible, but @FetchAll usually needs a write to trigger.
//                 // We can try a no-op write to the database to force @FetchAll to reload.
//                 // This is a bit hacky but effective for cross-process triggers with GRDB.
//                 Task {
//                     try? await DatabasePool.appDatabase.write { db in
//                         // No-op write to trigger observers
//                         try db.execute(sql: "UPDATE items SET id = id WHERE 0")
//                     }
//                 }
//             }
//         }, notificationName, nil, .deliverImmediately)
//     }
// }
