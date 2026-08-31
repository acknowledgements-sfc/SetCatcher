import AVFoundation
import Foundation

public enum CaptureServiceError: Error, Equatable, Sendable {
    case permissionDenied
    case deviceMissing
    case diskFull
    case engineFailed(String)
    case alreadyRecording
    case notRecording
}

public struct CaptureResult: Equatable, Sendable {
    public let stagingURL: URL
    public let deviceID: String
    public let deviceName: String
    public let startedAt: Date
    public let endedAt: Date
    public let captureRoute: CaptureArchiveRoute?
    public let captureBackend: CaptureArchiveBackend?
    public let deviceTransport: AudioDeviceTransport?
    public let captureInterrupted: Bool
    public let captureInterruptionReason: String?

    public init(
        stagingURL: URL,
        deviceID: String,
        deviceName: String,
        startedAt: Date,
        endedAt: Date,
        captureRoute: CaptureArchiveRoute? = nil,
        captureBackend: CaptureArchiveBackend? = nil,
        deviceTransport: AudioDeviceTransport? = nil,
        captureInterrupted: Bool = false,
        captureInterruptionReason: String? = nil
    ) {
        self.stagingURL = stagingURL
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.captureRoute = captureRoute
        self.captureBackend = captureBackend
        self.deviceTransport = deviceTransport
        self.captureInterrupted = captureInterrupted
        self.captureInterruptionReason = captureInterruptionReason
    }
}

public final class CaptureService: @unchecked Sendable {
    public private(set) var isRecording = false
    public private(set) var isMonitoring = false
    public private(set) var inputLevel: Float = 0
    public private(set) var startedAt: Date?

    private let fileManager: FileManager
    private let stagingDirectory: URL
    /// Lazy: constructing `AVAudioEngine` triggers CoreAudio HAL bring-up (device graph
    /// negotiation, IO thread setup), which is measurably CPU-heavy for several seconds on
    /// some machines. `CaptureService` is instantiated unconditionally on every launch
    /// regardless of capture mode (default mode is App audio, not Input device), so eagerly
    /// building the engine paid that cost on every launch even when it was never used.
    /// Optional storage (not `lazy var`) so `stopMonitoring()` can no-op when the engine
    /// was never created — dual-route policy calls halt on launch and must not pay HAL cost.
    private var engineStorage: AVAudioEngine?
    private var engine: AVAudioEngine {
        if let engineStorage { return engineStorage }
        let created = AVAudioEngine()
        engineStorage = created
        return created
    }
    private var audioFile: AVAudioFile?
    private var stagingURL: URL?
    private var deviceID = ""
    private var deviceName = ""
    private var boundTransport: AudioDeviceTransport?
    private let levelLock = NSLock()
    private let sampleHandlerQueue = DispatchQueue(label: "app.setcatcher.InputCapture.sample")
    private var writeFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var lastWriteErrorDetail: String?
    private var prerollBuffers: [AVAudioPCMBuffer] = []
    private var prerollFrames: AVAudioFrameCount = 0
    private var prerollFrameBudget: AVAudioFrameCount = 0
    /// Validated REC OUT stereo indexes when the device matches `PioneerRecOutChannelMatrix`.
    private var recOutPair: HardwareStereoChannelPair?

    public init(stagingDirectory: URL = CaptureService.defaultStagingDirectory(), fileManager: FileManager = .default) {
        self.stagingDirectory = stagingDirectory
        self.fileManager = fileManager
    }

    public static func defaultStagingDirectory() -> URL {
        DefaultPathProvider().applicationSupportDirectory()
            .appendingPathComponent("CaptureStaging", isDirectory: true)
    }

    public static func microphonePermissionGranted() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    public static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public func start(device: AudioInputDevice) throws {
        if !isMonitoring {
            try startMonitoring(device: device)
        }
        try beginRecordingFile()
    }

    public func startMonitoring(device: AudioInputDevice, prerollSeconds: TimeInterval = 10) throws {
        guard !isMonitoring else { throw CaptureServiceError.alreadyRecording }
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status != .authorized { throw CaptureServiceError.permissionDenied }

        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        try bindEngineInput(to: device)

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw CaptureServiceError.engineFailed("Input device has no usable audio format.")
        }

        let channelCount = Int(inputFormat.channelCount)
        switch PioneerRecOutChannelMatrix.resolvedPair(
            forDeviceName: device.name,
            channelCount: channelCount
        ) {
        case .success(let pair):
            recOutPair = pair
        case .failure(let error):
            throw CaptureServiceError.engineFailed(error.message)
        }

        let converterSourceFormat: AVAudioFormat
        if recOutPair != nil {
            guard let stereoSource = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: inputFormat.sampleRate,
                channels: 2,
                interleaved: false
            ) else {
                throw CaptureServiceError.engineFailed("Could not build a stereo processing format for REC OUT channel extract.")
            }
            converterSourceFormat = stereoSource
        } else {
            converterSourceFormat = inputFormat
        }
        guard let processingFormat = CaptureAudioFormat.processingFormat(),
              let audioConverter = CaptureAudioFormat.makeConverter(from: converterSourceFormat, to: processingFormat)
        else {
            throw CaptureServiceError.engineFailed(
                "Could not convert \(Int(inputFormat.sampleRate)) Hz input to 16-bit / 48 kHz. Choose another device, or use App audio Capture / folder Protection."
            )
        }

        deviceID = device.id
        deviceName = device.name
        boundTransport = device.transportType
        inputLevel = 0
        sampleHandlerQueue.sync {
            writeFormat = processingFormat
            converter = audioConverter
            lastWriteErrorDetail = nil
            prerollBuffers.removeAll()
            prerollFrames = 0
            prerollFrameBudget = AVAudioFrameCount(max(0, prerollSeconds) * CaptureAudioFormat.sampleRate)
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.sampleHandlerQueue.sync {
                self.processInputBuffer(buffer)
            }
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            recOutPair = nil
            throw CaptureServiceError.engineFailed(error.localizedDescription)
        }
        isMonitoring = true
    }

    public func beginRecordingFile() throws {
        guard isMonitoring else { throw CaptureServiceError.notRecording }
        guard !isRecording else { throw CaptureServiceError.alreadyRecording }

        let url = stagingDirectory.appendingPathComponent("capture-\(UUID().uuidString).wav")
        let newAudioFile: AVAudioFile
        do {
            newAudioFile = try AVAudioFile(forWriting: url, settings: CaptureAudioFormat.writeSettings)
        } catch {
            if Self.isDiskFullError(error, stagingDirectory: stagingDirectory) {
                throw CaptureServiceError.diskFull
            }
            throw CaptureServiceError.engineFailed(error.localizedDescription)
        }
        var flushedFrames: AVAudioFrameCount = 0
        sampleHandlerQueue.sync {
            if let writeFormat, newAudioFile.processingFormat.isEqual(writeFormat) {
                for buffer in prerollBuffers {
                    if CapturePCMWriter.write(buffer: buffer, to: newAudioFile) == nil {
                        flushedFrames += buffer.frameLength
                    }
                }
            }
            prerollBuffers.removeAll()
            prerollFrames = 0
            audioFile = newAudioFile
            stagingURL = url
            lastWriteErrorDetail = nil
            startedAt = Date().addingTimeInterval(-Double(flushedFrames) / CaptureAudioFormat.sampleRate)
            isRecording = true
        }
    }

    public func endRecordingFile(discard: Bool) throws -> CaptureResult? {
        var wasRecording = false
        var finalizedURL: URL?
        var writeError: String?
        var recordingStart: Date?
        sampleHandlerQueue.sync {
            wasRecording = isRecording
            audioFile = nil
            isRecording = false
            finalizedURL = stagingURL
            writeError = lastWriteErrorDetail
            recordingStart = startedAt
            stagingURL = nil
            startedAt = nil
        }
        guard wasRecording else { throw CaptureServiceError.notRecording }
        let endedAt = Date()
        let started = recordingStart ?? endedAt
        guard let stagingURL = finalizedURL else { throw CaptureServiceError.engineFailed("Capture staging file is missing.") }
        if let detail = writeError {
            try? fileManager.removeItem(at: stagingURL)
            throw CaptureServiceError.engineFailed(detail)
        }
        if discard {
            try? fileManager.removeItem(at: stagingURL)
            return nil
        }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: stagingURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw CaptureServiceError.engineFailed("Capture staging file is missing.")
        }
        let result = CaptureResult(
            stagingURL: stagingURL,
            deviceID: deviceID,
            deviceName: deviceName,
            startedAt: started,
            endedAt: endedAt,
            captureRoute: .inputDevice,
            captureBackend: nil,
            deviceTransport: boundTransport
        )
        return result
    }

    public func stopMonitoring() {
        // Dual-route policy calls this on launch even when Input Capture was never started.
        // Touching `engine` would construct AVAudioEngine and block on the Core Audio HAL.
        if let engine = engineStorage {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        var abandonedURL: URL?
        sampleHandlerQueue.sync {
            if isRecording { abandonedURL = stagingURL }
            audioFile = nil
            converter = nil
            writeFormat = nil
            isRecording = false
            stagingURL = nil
            startedAt = nil
            lastWriteErrorDetail = nil
            prerollBuffers.removeAll()
            prerollFrames = 0
            prerollFrameBudget = 0
        }
        if let abandonedURL { try? fileManager.removeItem(at: abandonedURL) }
        isMonitoring = false
        inputLevel = 0
        recOutPair = nil
    }

    public func stop() throws -> CaptureResult {
        let result = try endRecordingFile(discard: false)
        stopMonitoring()
        guard let result else { throw CaptureServiceError.engineFailed("Capture staging file is missing.") }
        return result
    }

    public func currentInputLevel() -> Float {
        levelLock.lock(); defer { levelLock.unlock() }
        return inputLevel
    }

    public func currentStagingByteCount() -> Int64? {
        guard let stagingURL = sampleHandlerQueue.sync(execute: { stagingURL }) else { return nil }
        return (try? stagingURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
    }

    /// AVAudioEngine's input node follows the system default unless we pin the device.
    private func bindEngineInput(to device: AudioInputDevice) throws {
        guard let coreAudioID = AudioInputDeviceCatalog.audioDeviceID(forUID: device.id) else {
            throw CaptureServiceError.deviceMissing
        }
        if engine.isRunning {
            engine.stop()
        }
        do {
            try engine.inputNode.auAudioUnit.setDeviceID(coreAudioID)
        } catch {
            throw CaptureServiceError.engineFailed("Could not select \(device.name): \(error.localizedDescription)")
        }
    }

    private static func isDiskFullError(_ error: Error, stagingDirectory: URL) -> Bool {
        var current: NSError? = error as NSError
        var seen: Set<Int> = []
        while let ns = current, seen.insert(ns.hash).inserted {
            if ns.domain == NSPOSIXErrorDomain && ns.code == Int(ENOSPC) { return true }
            if ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError { return true }
            current = ns.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        if let capacity = try? stagingDirectory.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity,
           capacity < 4096 {
            return true
        }
        return false
    }

    private func processInputBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converter, let writeFormat else { return }
        let sourceBuffer: AVAudioPCMBuffer
        if let pair = recOutPair {
            guard let stereo = CaptureChannelPairExtractor.extractStereo(from: buffer, pair: pair) else {
                lastWriteErrorDetail = "Capture could not extract REC OUT pair \(pair.oneBasedLabel)."
                return
            }
            sourceBuffer = stereo
        } else {
            sourceBuffer = buffer
        }
        if let channelData = sourceBuffer.floatChannelData {
            var meter = CaptureDSP.MeanSquareAccumulator()
            for channel in 0..<Int(sourceBuffer.format.channelCount) {
                meter.add(samples: channelData[channel], count: Int(sourceBuffer.frameLength))
            }
            if let level = meter.inputLevel {
                levelLock.lock(); inputLevel = level; levelLock.unlock()
            }
        }
        let conversion = CapturePCMWriter.convert(
            buffer: sourceBuffer,
            converter: converter,
            writeFormat: writeFormat
        )
        if let detail = conversion.error {
            lastWriteErrorDetail = "Capture \(detail)"
        } else if let converted = conversion.buffer {
            if isRecording, let audioFile {
                lastWriteErrorDetail = CapturePCMWriter.write(buffer: converted, to: audioFile).map { "Capture \($0)" }
            } else {
                appendPreroll(converted)
                lastWriteErrorDetail = nil
            }
        } else {
            lastWriteErrorDetail = "Capture could not convert to the capture format."
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
}
