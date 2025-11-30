import AVFoundation
import ReplayKit

enum BroadcastError: Swift.Error {
    case wrongAssetWriterStatus(AVAssetWriter.Status)
    case selfDeallocated
}

public final class BroadcastWriter {

    private var assetWriterSessionStarted: Bool = false
    private let assetWriterQueue: DispatchQueue
    private let assetWriter: AVAssetWriter

    private lazy var videoInput: AVAssetWriterInput = {
        let videoWidth = screenSize.width * screenScale
        let videoHeight = screenSize.height * screenScale

        let compressionProperties: [String: Any] = [
            AVVideoExpectedSourceFrameRateKey: NSNumber(value: 60),
            AVVideoProfileLevelKey: "HEVC_Main_AutoLevel"
        ]
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: NSNumber(value: videoWidth),
            AVVideoHeightKey: NSNumber(value: videoHeight),
            AVVideoCompressionPropertiesKey: compressionProperties
        ]
        let input: AVAssetWriterInput = .init(
            mediaType: .video,
            outputSettings: videoSettings
        )
        input.expectsMediaDataInRealTime = true
        return input
    }()

    private var audioSampleRate: Double {
        AVAudioSession.sharedInstance().sampleRate
    }
    
    private lazy var audioInput: AVAssetWriterInput = {
        var audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: audioSampleRate
        ]
        let input: AVAssetWriterInput = .init(
            mediaType: .audio,
            outputSettings: audioSettings
        )
        input.expectsMediaDataInRealTime = true
        return input
    }()

    private lazy var microphoneInput: AVAssetWriterInput = {
        let sampleRate = AVAudioSession.sharedInstance().sampleRate

        var audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: audioSampleRate
        ]
        let input: AVAssetWriterInput = .init(
            mediaType: .audio,
            outputSettings: audioSettings
        )
        input.expectsMediaDataInRealTime = true
        return input
    }()

    private lazy var inputs: [AVAssetWriterInput] = [
        videoInput,
        audioInput,
        microphoneInput
    ]

    private let screenSize: CGSize
    private let screenScale: CGFloat

    public init(
        outputURL url: URL,
        assetWriterQueue queue: DispatchQueue = .init(label: "BroadcastSampleHandler.assetWriterQueue"),
        screenSize: CGSize,
        screenScale: CGFloat
    ) throws {
        assetWriterQueue = queue
        assetWriter = try .init(url: url, fileType: .mp4)

        self.screenSize = screenSize
        self.screenScale = screenScale
    }

    public func start() throws {
        try assetWriterQueue.sync {
            let status = assetWriter.status
            guard status == .unknown else {
                throw BroadcastError.wrongAssetWriterStatus(status)
            }
            if let error = assetWriter.error {
                throw error
            }
            inputs
                .lazy
                .filter(assetWriter.canAdd(_:))
                .forEach(assetWriter.add(_:))
            
            if let error = assetWriter.error {
                throw error
            }
            
            assetWriter.startWriting()
            
            if let error = assetWriter.error {
                throw error
            }
        }
    }

    public func processSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        with sampleBufferType: RPSampleBufferType
    ) throws -> Bool {

        guard sampleBuffer.isValid,
              CMSampleBufferDataIsReady(sampleBuffer) else {
            print("sampleBuffer.isValid: \(sampleBuffer.isValid), CMSampleBufferDataIsReady: \(CMSampleBufferDataIsReady(sampleBuffer))")
            return false
        }

        let isWriting = assetWriterQueue.sync {
            assetWriter.status == .writing
        }

        guard isWriting else {
            print("assetWriter.status: \(assetWriter.status.rawValue), error: \(String(describing: assetWriter.error))")
            return false
        }

        assetWriterQueue.sync {
            startSessionIfNeeded(sampleBuffer: sampleBuffer)
        }

        let capture: (CMSampleBuffer) -> Bool
        switch sampleBufferType {
        case .video:
            capture = captureVideoOutput
        case .audioApp:
            capture = captureAudioOutput
        case .audioMic:
            capture = captureMicrophoneOutput
        @unknown default:
            print("Unknown type of sample buffer: \(sampleBufferType)")
            capture = { _ in false }
        }

        return assetWriterQueue.sync {
            capture(sampleBuffer)
        }
    }

    public func pause() {
        // TODO: Pause
    }

    public func resume() {
        // TODO: Resume
    }

    public func finish() throws -> URL {
        return try assetWriterQueue.sync {
            let group: DispatchGroup = .init()

            inputs
                .lazy
                .filter { $0.isReadyForMoreMediaData }
                .forEach { $0.markAsFinished() }

            let status = assetWriter.status
            guard status == .writing else {
                throw BroadcastError.wrongAssetWriterStatus(status)
            }
            group.enter()

            var error: Swift.Error?
            assetWriter.finishWriting { [weak self] in
                defer {
                    group.leave()
                }
                guard let self = self else {
                    error = BroadcastError.selfDeallocated
                    return
                }
                if let e = self.assetWriter.error {
                    error = e
                    return
                }
                let status = self.assetWriter.status
                guard status == .completed else {
                    error = BroadcastError.wrongAssetWriterStatus(status)
                    return
                }
            }
            group.wait()
            if let error = error {
                throw error
            }
            return assetWriter.outputURL
        }
    }
}

private extension BroadcastWriter {

    func startSessionIfNeeded(sampleBuffer: CMSampleBuffer) {
        guard !assetWriterSessionStarted else {
            return
        }

        let sourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        assetWriter.startSession(atSourceTime: sourceTime)
        assetWriterSessionStarted = true
    }

    func captureVideoOutput(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard videoInput.isReadyForMoreMediaData else {
            print("videoInput is not ready")
            return false
        }
        return videoInput.append(sampleBuffer)
    }

    func captureAudioOutput(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard audioInput.isReadyForMoreMediaData else {
            print("audioInput is not ready")
            return false
        }
        return audioInput.append(sampleBuffer)
    }

    func captureMicrophoneOutput(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard microphoneInput.isReadyForMoreMediaData else {
            print("microphoneInput is not ready")
            return false
        }
        return microphoneInput.append(sampleBuffer)
    }
}
