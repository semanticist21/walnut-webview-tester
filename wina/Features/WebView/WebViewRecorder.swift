//
//  WebViewRecorder.swift
//  wina
//
//  Screen recorder using ReplayKit for high-fps capture.
//

import AVFoundation
import Photos
import ReplayKit
import UIKit

// MARK: - Recording Types

enum RecordingResult {
    case success
    case permissionDenied
    case failed(String)
}

enum RecordingState: Sendable {
    case idle
    case recording
    case finishing
}

// MARK: - WebView Recorder

private final class WriterState {
    var assetWriter: AVAssetWriter?
    var videoInput: AVAssetWriterInput?
    var audioInput: AVAssetWriterInput?
    var sessionStarted = false
    var firstSampleTime: CMTime?
    var isRecording = false

    func reset() {
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        sessionStarted = false
        firstSampleTime = nil
        isRecording = false
    }

    func markInputsFinished() {
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
    }

    func processVideoSample(_ sampleBuffer: CMSampleBuffer, outputURL: URL?) {
        if assetWriter == nil {
            guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
            let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            let videoSize = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))

            guard setupAssetWriter(videoSize: videoSize, outputURL: outputURL) else { return }
        }

        guard let writer = assetWriter, let input = videoInput else { return }

        if !sessionStarted {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startSession(atSourceTime: presentationTime)
            firstSampleTime = presentationTime
            sessionStarted = true
        }

        if input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }
    }

    func processAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard sessionStarted else { return }
        guard let input = audioInput, input.isReadyForMoreMediaData else { return }

        input.append(sampleBuffer)
    }

    private func setupAssetWriter(videoSize: CGSize, outputURL: URL?) -> Bool {
        guard let url = outputURL else { return false }

        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
        } catch {
            return false
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: 30
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]

        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true

        guard let writer = assetWriter,
              let vInput = videoInput,
              let aInput = audioInput else { return false }

        if writer.canAdd(vInput) {
            writer.add(vInput)
        } else {
            return false
        }

        if writer.canAdd(aInput) {
            writer.add(aInput)
        }

        writer.startWriting()
        return true
    }
}

@Observable
@MainActor
final class WebViewRecorder {
    private(set) var state: RecordingState = .idle
    private(set) var recordingDuration: TimeInterval = 0

    var isRecording: Bool { state == .recording }

    /// Computed duration for real-time display (used with TimelineView)
    var currentDuration: TimeInterval {
        guard let start = startTime, state == .recording else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // Recording state (main actor isolated)
    private var startTime: Date?
    private var outputURL: URL?

    // Duration update timer
    private var durationTimer: Timer?

    // Dedicated queue for AVAssetWriter operations (thread-safe)
    private let writerQueue = DispatchQueue(label: "com.wina.assetwriter", qos: .userInitiated)

    // Writer state (accessed only on writerQueue)
    private let writerState = WriterState()

    // MARK: - Recording Control

    func startRecording() async -> Bool {
        guard state == .idle else { return false }

        // Check photo library permission
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard status == .authorized || status == .limited else {
            return false
        }

        // Check ReplayKit availability
        let recorder = RPScreenRecorder.shared()
        guard recorder.isAvailable else {
            return false
        }

        // Setup output URL
        let fileName = "ScreenRecording_\(Date().timeIntervalSince1970).mov"
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        outputURL = documentsPath.appendingPathComponent(fileName)

        // Remove existing file if any
        if let url = outputURL {
            try? FileManager.default.removeItem(at: url)
        }

        // Reset state
        let url = outputURL
        let writerState = writerState
        writerQueue.sync {
            writerState.reset()
            writerState.isRecording = true
        }

        startTime = Date()
        recordingDuration = 0

        // Start ReplayKit capture
        do {
            try await startReplayKitCapture(outputURL: url)
            state = .recording

            // Start duration timer on main actor
            startDurationTimer()

            return true
        } catch {
            cleanupWriter()
            return false
        }
    }

    func stopRecording() {
        guard state == .recording else { return }
        state = .finishing

        let writerState = writerState
        writerQueue.async {
            writerState.isRecording = false
        }

        // Stop duration timer
        durationTimer?.invalidate()
        durationTimer = nil

        // Stop ReplayKit capture
        RPScreenRecorder.shared().stopCapture { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.finishRecording()
            }
        }
    }

    // MARK: - ReplayKit Capture

    private func startReplayKitCapture(outputURL: URL?) async throws {
        let recorder = RPScreenRecorder.shared()

        let writerState = writerState
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            recorder.startCapture(handler: { [weak self] sampleBuffer, sampleBufferType, _ in
                guard let self else { return }

                // Process sample buffer on dedicated queue (nonisolated)
                self.writerQueue.async {
                    guard writerState.isRecording else { return }

                    switch sampleBufferType {
                    case .video:
                        writerState.processVideoSample(sampleBuffer, outputURL: outputURL)
                    case .audioApp:
                        writerState.processAudioSample(sampleBuffer)
                    case .audioMic:
                        break
                    @unknown default:
                        break
                    }
                }
            }, completionHandler: { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    // MARK: - Duration Timer

    private func startDurationTimer() {
        // Use Timer on main RunLoop explicitly for @MainActor context
        durationTimer = Timer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(handleDurationTick),
            userInfo: nil,
            repeats: true
        )
        if let durationTimer {
            RunLoop.main.add(durationTimer, forMode: .common)
        }
    }

    @objc private func handleDurationTick() {
        guard let start = startTime else { return }
        recordingDuration = Date().timeIntervalSince(start)
    }

    // MARK: - Finish Recording

    private func finishRecording() async {
        let writerState = writerState
        let writer = writerQueue.sync { writerState.assetWriter }

        guard let writer else {
            state = .idle
            return
        }

        // Mark inputs as finished on writer queue
        writerQueue.sync {
            writerState.markInputsFinished()
        }

        // Finish writing
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting {
                continuation.resume()
            }
        }

        if writer.status == .completed, let url = outputURL {
            await saveToPhotos(url: url)
        }

        cleanupWriter()
        state = .idle
    }

    private func saveToPhotos(url: URL) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
            }
            // Clean up temp file after saving
            try? FileManager.default.removeItem(at: url)
        } catch {
            // Keep file on error for debugging
        }
    }

    private func cleanupWriter() {
        let writerState = writerState
        writerQueue.sync {
            writerState.reset()
        }
    }

    private func cleanup() {
        cleanupWriter()
        startTime = nil
        durationTimer?.invalidate()
        durationTimer = nil
    }
}

#if DEBUG
extension WebViewRecorder {
    func test_setStartTime(_ date: Date?) {
        startTime = date
    }

    func test_handleDurationTick() {
        handleDurationTick()
    }
}
#endif
