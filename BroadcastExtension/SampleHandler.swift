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
import Photos
import Dependencies

class SampleHandler: RPBroadcastSampleHandler {

    @Dependency(\.defaultFirestore) var defaultFirestore
    
    private var writer: BroadcastWriter?
    private let fileManager: FileManager = .default
    private let nodeURL: URL
    
    override init() {
        // Prepare dependencies
        prepareDependencies {
            try! $0.bootstrapDatabase()
        }
        
        // Setup recording URL
        nodeURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(for: .mpeg4Movie)
        
        if fileManager.fileExists(atPath: nodeURL.path) {
            try? fileManager.removeItem(at: nodeURL)
        }
        
        super.init()
        FileLogger.log("SampleHandler init")
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional. 
        logEvent("broadcastStarted")
        
        let screen: UIScreen = .main
        do {
            writer = try .init(
                outputURL: nodeURL,
                screenSize: screen.bounds.size,
                screenScale: screen.scale
            )
            try writer?.start()
            logEvent("Recording started")
        } catch {
            logEvent("Failed to start recording: \(error)")
            finishBroadcastWithError(error)
        }
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
        logEvent("broadcastPaused")
        writer?.pause()
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
        logEvent("broadcastResumed")
        writer?.resume()
    }
    
    override func broadcastAnnotated(withApplicationInfo applicationInfo: [AnyHashable : Any]) {
        if let bundleID = applicationInfo["RPApplicationInfoBundleIdentifier"] as? String {
            if bundleID != lastBundleID {
                lastBundleID = bundleID
                logEvent("Broadcast Annotated: {\n  \"RPApplicationInfoBundleIdentifier\" : \"\(bundleID)\"\n}")
            }
        }
    }
    
    private var sampleCount = 0
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        logEvent("broadcastFinished. Samples processed: \(sampleCount)")
        
        guard let writer = writer else {
            logEvent("Writer is nil")
            return
        }
        
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        let outputURL: URL
        do {
            outputURL = try writer.finish()
            logEvent("Writer finished. Output URL: \(outputURL.path)")
        } catch {
            logEvent("Writer failure: \(error)")
            dispatchGroup.leave()
            return
        }
        
        // Move to App Group Container
        let appGroupID = "group.halfjew22.swift-sharing-exploration"
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            logEvent("Failed to get App Group container for \(appGroupID)")
            dispatchGroup.leave()
            return
        }
        
        let videosDirectory = containerURL.appendingPathComponent("Videos")
        do {
            if !fileManager.fileExists(atPath: videosDirectory.path) {
                try fileManager.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
            }
            
            let destinationURL = videosDirectory.appendingPathComponent(outputURL.lastPathComponent)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.moveItem(at: outputURL, to: destinationURL)
            logEvent("Video moved to App Group: \(destinationURL.path)")
            
            // Optional: Still try to save to Photos if possible, but the file is safe now.
            // For now, let's just confirm we have the file.
            
        } catch {
            logEvent("Failed to move video to App Group: \(error)")
        }
        
        dispatchGroup.leave()
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        sampleCount += 1
        guard let writer = writer else {
            return
        }
        
        do {
            _ = try writer.processSampleBuffer(sampleBuffer, with: sampleBufferType)
        } catch {
            logEvent("Buffer processing error: \(error)")
        }
        
        // Log app switching events (existing logic)
        if sampleBufferType == .video {
            if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[String: Any]],
               let attachment = attachments.first,
               let bundleID = attachment["RPApplicationInfoBundleIdentifier"] as? String {
                
                // Only log if the bundle ID has changed to avoid spamming
                if bundleID != lastBundleID {
                    lastBundleID = bundleID
                    logEvent("Broadcast Annotated: {\n  \"RPApplicationInfoBundleIdentifier\" : \"\(bundleID)\"\n}")
                }
            }
        }
    }
    
    private var lastBundleID: String?
    
    private func logEvent(_ message: String) {
        let title = message
        let item = Item(id: UUID(), title: title, timestamp: Date())
        
        // Using Firestore directly
        if FirebaseApp.app() != nil {
             do {
                 try! self.defaultFirestore.collection("logs").addDocument(from: item)
                 FileLogger.log("Logged event: \(title)")
             } catch {
                 FileLogger.log("Failed to log event: \(error)")
             }
        } else {
            FileLogger.log("Firebase not configured, skipping upload: \(title)")
        }
    }
}
