#if os(macOS)
import AVFoundation
import CoreAudio
import Foundation

/// Device-agnostic Core Audio input pipeline shared by app-audio backends.
///
/// Backend wrappers own device discovery and any tap/aggregate lifecycle. This type owns only
/// the IOProc, format conversion, metering, preroll, and staging-file lifecycle for one device.
final class CoreAudioIOProcCapture: @unchecked Sendable {
    struct ResultMetadata: Sendable {
        let deviceID: String
        let deviceName: String
        let captureBackend: CaptureArchiveBackend
        let deviceTransport: AudioDeviceTransport?
    }

    private(set) var isMonitoring = false
    private(set) var isWriting = false
    private(set) var startedAt: Date?

    private let fileManager: FileManager
    private let stagingDirectory: URL
    private let sampleHandlerQueue: DispatchQueue
    private let levelLock = NSLock()

    private var inputLevel: Float = 0
    private var audioDeviceID = AudioDeviceID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var audioFile: AVAudioFile?
    private var stagingURL: URL?
    private var sourceFormat: AVAudioFormat?
    private var writeFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var sourceASBD: AudioStreamBasicDescription?
    private var sourceLabel = "App audio Capture"
    private var filePrefix = "app-audio"
    private var resultMetadata: ResultMetadata?
    private var writeTracker = CaptureWriteTracker()
    /// Set when the *source* format is unusable — fatal for the take regardless of buffer writes.
    private var formatMismatchDetail: String?
    private var prerollBuffers: [AVAudioPCMBuffer] = []
    private var prerollFrames: AVAudioFrameCount = 0
    private var prerollFrameBudget: AVAudioFrameCount = 0

    init(
        stagingDirectory: URL,
        fileManager: FileManager,
        queueLabel: String
    ) {
        self.stagingDirectory = stagingDirectory
        self.fileManager = fileManager
        self.sampleHandlerQueue = DispatchQueue(label: queueLabel)
    }

    func start(
        deviceID: AudioDeviceID,
        sourceASBD: AudioStreamBasicDescription,
        prerollSeconds: TimeInterval,
        sourceLabel: String,
        filePrefix: String,
        resultMetadata: ResultMetadata
    ) throws {
        guard !isMonitoring else { throw AppAudioCaptureError.alreadyMonitoring }
        guard deviceID != kAudioObjectUnknown else {
            throw AppAudioCaptureError.engineFailed("\(sourceLabel) input device is unavailable.")
        }
        guard sourceASBD.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              let sourceFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sourceASBD.mSampleRate,
                channels: max(1, AVAudioChannelCount(sourceASBD.mChannelsPerFrame)),
                interleaved: false
              )
        else {
            throw AppAudioCaptureError.engineFailed("\(sourceLabel) returned an unsupported audio format.")
        }
        guard let writeFormat = CaptureAudioFormat.processingFormat(),
              let converter = CaptureAudioFormat.makeConverter(from: sourceFormat, to: writeFormat)
        else {
            throw AppAudioCaptureError.engineFailed("\(sourceLabel) could not convert to the capture format.")
        }

        self.audioDeviceID = deviceID
        self.sourceASBD = sourceASBD
        self.sourceFormat = sourceFormat
        self.writeFormat = writeFormat
        self.converter = converter
        self.sourceLabel = sourceLabel
        self.filePrefix = filePrefix
        self.resultMetadata = resultMetadata
        self.formatMismatchDetail = nil
        sampleHandlerQueue.sync {
            writeTracker.reset()
            prerollBuffers.removeAll()
            prerollFrames = 0
            prerollFrameBudget = AVAudioFrameCount(max(0, prerollSeconds) * CaptureAudioFormat.sampleRate)
        }
        setInputLevel(0)

        var newIOProcID: AudioDeviceIOProcID?
        let createStatus = AudioDeviceCreateIOProcIDWithBlock(
            &newIOProcID,
            deviceID,
            sampleHandlerQueue
        ) { [weak self] _, inputData, _, _, _ in
            // GCD does not guarantee an autorelease-pool drain per work item on a private queue,
            // and this fires hundreds of times a second allocating AVAudioPCMBuffers. Without an
            // explicit pool the autoreleased temporaries accumulate for as long as capture runs.
            autoreleasepool {
                self?.handleAudioBufferList(inputData)
            }
        }
        guard createStatus == noErr, let newIOProcID else {
            resetConfiguration()
            throw statusError("create \(sourceLabel) IO callback", createStatus)
        }

        ioProcID = newIOProcID
        let startStatus = AudioDeviceStart(deviceID, newIOProcID)
        guard startStatus == noErr else {
            _ = AudioDeviceDestroyIOProcID(deviceID, newIOProcID)
            ioProcID = nil
            resetConfiguration()
            throw statusError("start \(sourceLabel)", startStatus)
        }
        isMonitoring = true
    }

    func stop() {
        guard isMonitoring || ioProcID != nil else { return }
        if isWriting {
            _ = try? endRecordingFile(discard: true)
        }
        if let ioProcID, audioDeviceID != kAudioObjectUnknown {
            _ = AudioDeviceStop(audioDeviceID, ioProcID)
            _ = AudioDeviceDestroyIOProcID(audioDeviceID, ioProcID)
        }
        ioProcID = nil
        isMonitoring = false
        resetConfiguration()
        setInputLevel(0)
    }

    func beginRecordingFile() throws {
        guard isMonitoring else { throw AppAudioCaptureError.notMonitoring }
        guard !isWriting else { throw AppAudioCaptureError.alreadyWriting }

        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        let url = stagingDirectory.appendingPathComponent("\(filePrefix)-\(UUID().uuidString).wav")
        let newAudioFile: AVAudioFile
        do {
            newAudioFile = try AVAudioFile(forWriting: url, settings: CaptureAudioFormat.writeSettings)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOSPC) {
                throw AppAudioCaptureError.diskFull
            }
            throw AppAudioCaptureError.engineFailed(error.localizedDescription)
        }
        let fileFormat = newAudioFile.processingFormat

        sampleHandlerQueue.sync {
            var flushedFrames: AVAudioFrameCount = 0
            if let writeFormat, fileFormat.isEqual(writeFormat) {
                for buffer in prerollBuffers {
                    if CapturePCMWriter.write(buffer: buffer, to: newAudioFile) == nil {
                        flushedFrames += buffer.frameLength
                    }
                }
            }
            prerollBuffers.removeAll()
            prerollFrames = 0
            writeTracker.reset()
            audioFile = newAudioFile
            let prerollDuration = Double(flushedFrames) / CaptureAudioFormat.sampleRate
            startedAt = Date().addingTimeInterval(-prerollDuration)
            isWriting = true
        }
        stagingURL = url
        formatMismatchDetail = nil
    }

    func endRecordingFile(discard: Bool) throws -> CaptureResult? {
        guard isWriting else { throw AppAudioCaptureError.notWriting }
        sampleHandlerQueue.sync {
            audioFile = nil
            isWriting = false
        }
        let endedAt = Date()
        let started = startedAt ?? endedAt
        startedAt = nil
        guard let stagingURL else {
            throw AppAudioCaptureError.engineFailed("Capture staging file is missing.")
        }
        self.stagingURL = nil

        if discard {
            try? fileManager.removeItem(at: stagingURL)
            return nil
        }
        if let detail = formatMismatchDetail {
            try? fileManager.removeItem(at: stagingURL)
            throw AppAudioCaptureError.engineFailed(detail)
        }
        // A take that lost some buffers is gapped but still the user's set: keep it and report.
        // Only a take with no usable audio at all is discarded.
        let writeFailure = sampleHandlerQueue.sync { writeTracker.failure }
        if let writeFailure, writeFailure.isFatal {
            try? fileManager.removeItem(at: stagingURL)
            throw AppAudioCaptureError.engineFailed(writeFailure.summary)
        }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: stagingURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else {
            throw AppAudioCaptureError.engineFailed("Capture staging file is missing.")
        }
        guard let resultMetadata else {
            throw AppAudioCaptureError.engineFailed("Capture source metadata is missing.")
        }
        return CaptureResult(
            stagingURL: stagingURL,
            deviceID: resultMetadata.deviceID,
            deviceName: resultMetadata.deviceName,
            startedAt: started,
            endedAt: endedAt,
            captureRoute: .appAudio,
            captureBackend: resultMetadata.captureBackend,
            deviceTransport: resultMetadata.deviceTransport,
            writeFailure: writeFailure
        )
    }

    func currentInputLevel() -> Float {
        levelLock.lock(); defer { levelLock.unlock() }
        return inputLevel
    }

    private func handleAudioBufferList(_ audioBufferList: UnsafePointer<AudioBufferList>) {
        guard let sourceASBD, let sourceFormat, let writeFormat, let converter else { return }
        let list = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: audioBufferList))
        let isFloat = sourceASBD.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let isInterleaved = sourceASBD.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
        let sourceChannels = max(1, Int(sourceASBD.mChannelsPerFrame))
        guard isFloat else {
            formatMismatchDetail = "\(sourceLabel) received non-float audio buffers. Use ScreenCaptureKit or Input device Capture."
            return
        }

        let frameLength: Int
        if isInterleaved, let first = list.first {
            frameLength = Int(first.mDataByteSize) / max(1, Int(sourceASBD.mBytesPerFrame))
        } else {
            frameLength = list.map { Int($0.mDataByteSize) / MemoryLayout<Float>.size }.max() ?? 0
        }
        guard frameLength > 0,
              let pcm = AVAudioPCMBuffer(
                pcmFormat: sourceFormat,
                frameCapacity: AVAudioFrameCount(frameLength)
              )
        else { return }
        pcm.frameLength = AVAudioFrameCount(frameLength)
        guard let floatChannels = pcm.floatChannelData else { return }

        var meter = CaptureDSP.MeanSquareAccumulator()
        if isInterleaved, let first = list.first, let src = first.mData {
            let interleaved = src.bindMemory(to: Float.self, capacity: frameLength * sourceChannels)
            for channel in 0..<Int(sourceFormat.channelCount) {
                let srcChannel = min(channel, sourceChannels - 1)
                meter.add(
                    meanSquare: CaptureDSP.copyInterleavedChannelAndMeasure(
                        from: interleaved,
                        sourceChannel: srcChannel,
                        sourceChannelCount: sourceChannels,
                        frameCount: frameLength,
                        to: floatChannels[channel]
                    ),
                    count: frameLength
                )
            }
        } else {
            for channel in 0..<Int(sourceFormat.channelCount) {
                let srcIndex = min(channel, list.count - 1)
                guard srcIndex >= 0, let src = list[srcIndex].mData else { continue }
                let count = min(
                    frameLength,
                    Int(list[srcIndex].mDataByteSize) / MemoryLayout<Float>.size
                )
                let samples = src.bindMemory(to: Float.self, capacity: count)
                meter.add(
                    meanSquare: CaptureDSP.copyPlanarChannelAndMeasure(
                        from: samples,
                        count: count,
                        to: floatChannels[channel]
                    ),
                    count: count
                )
            }
        }
        if let level = meter.inputLevel {
            setInputLevel(level)
        }

        let conversion = CapturePCMWriter.convert(
            buffer: pcm,
            converter: converter,
            writeFormat: writeFormat
        )
        if let detail = conversion.error {
            formatMismatchDetail = "\(sourceLabel) \(detail)"
            return
        }
        guard let converted = conversion.buffer else {
            formatMismatchDetail = "\(sourceLabel) could not convert to the capture format."
            return
        }
        if isWriting, let audioFile {
            if let detail = CapturePCMWriter.write(buffer: converted, to: audioFile) {
                writeTracker.recordFailure {
                    "\(sourceLabel) \(detail)"
                        + CapturePCMWriter.formatContext(buffer: converted, file: audioFile)
                }
            } else {
                writeTracker.recordSuccess()
            }
        } else {
            appendPreroll(converted)
        }
    }

    private func appendPreroll(_ buffer: AVAudioPCMBuffer) {
        guard prerollFrameBudget > 0 else { return }
        prerollBuffers.append(buffer)
        prerollFrames += buffer.frameLength
        while prerollFrames > prerollFrameBudget, prerollBuffers.count > 1 {
            let removed = prerollBuffers.removeFirst()
            prerollFrames -= min(prerollFrames, removed.frameLength)
        }
    }

    private func resetConfiguration() {
        audioDeviceID = AudioDeviceID(kAudioObjectUnknown)
        audioFile = nil
        stagingURL = nil
        startedAt = nil
        isWriting = false
        sourceASBD = nil
        sourceFormat = nil
        writeFormat = nil
        converter = nil
        resultMetadata = nil
        formatMismatchDetail = nil
        sampleHandlerQueue.sync {
            writeTracker.reset()
            prerollBuffers.removeAll()
            prerollFrames = 0
            prerollFrameBudget = 0
        }
    }

    private func statusError(_ action: String, _ status: OSStatus) -> AppAudioCaptureError {
        AppAudioCaptureError.engineFailed("\(action) failed (\(status)).")
    }

    private func setInputLevel(_ value: Float) {
        levelLock.lock()
        inputLevel = value
        levelLock.unlock()
    }
}
#endif
