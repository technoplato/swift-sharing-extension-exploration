//
//  SampleHandler.swift
//  BroadcastExtension
//
//  Created by Michael Lustig on 11/29/25.
//

import ReplayKit
import SQLiteData
import GRDB

class SampleHandler: RPBroadcastSampleHandler {

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast.
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
        logEvent("Broadcast Finished")
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
        do {
            try DatabasePool.appDatabase.write { db in
                try Item.insert { item }.execute(db)
            }
            notifyDatabaseChange()
        } catch {
            print("Failed to log event: \(error)")
        }
    }
}
