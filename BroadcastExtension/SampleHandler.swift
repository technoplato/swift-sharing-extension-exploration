//
//  SampleHandler.swift
//  BroadcastExtension
//
//  Created by Michael Lustig on 11/29/25.
//

import ReplayKit
// import SQLiteData
// import GRDB
import SharingFirestore
import FirebaseCore
import FirebaseFirestore
import Dependencies

class SampleHandler: RPBroadcastSampleHandler {

    override init() {
        super.init()
        FileLogger.log("SampleHandler init")
        do {
            try prepareDependencies {
                try! $0.bootstrapDatabase()
            }
            FileLogger.log("Dependencies prepared")
        } catch {
            FileLogger.log("Failed to prepare dependencies: \(error)")
        }
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast.
        FileLogger.log("broadcastStarted")
        logEvent("Broadcast Started")
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        FileLogger.log("broadcastFinished")
        logEvent("Broadcast Finished")
        
        // Give SyncEngine a moment to push changes
        Thread.sleep(forTimeInterval: 1.0)
    }
    
    override func broadcastAnnotated(withApplicationInfo applicationInfo: [AnyHashable : Any]) {
        // Log application info
        if let jsonData = try? JSONSerialization.data(withJSONObject: applicationInfo, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            logEvent("Broadcast Annotated: \(jsonString)")
        } else {
            logEvent("Broadcast Annotated: \(applicationInfo)")
        }
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            // Handle video sample buffer
            break
        case RPSampleBufferType.audioApp:
            // Handle audio sample buffer for app audio
            break
        case RPSampleBufferType.audioMic:
            // Handle audio sample buffer for mic audio
            break
        @unknown default:
            // Handle other sample buffer types
            fatalError("Unknown type of sample buffer")
        }
    }
    
    private func logEvent(_ title: String) {
        let item = Item(id: UUID(), title: title, timestamp: Date())
        
        // Using Firestore directly
        if FirebaseApp.app() != nil {
             do {
                 try Firestore.firestore().collection("items").addDocument(from: item)
                 FileLogger.log("Logged event: \(title)")
             } catch {
                 FileLogger.log("Failed to log event: \(error)")
             }
        } else {
             FileLogger.log("Firebase not configured, cannot log event: \(title)")
        }
    }
}
