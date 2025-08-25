import Foundation
import AVFoundation
import Speech
import SwiftUI

@MainActor
class VoiceRecordingService: NSObject, ObservableObject {
    static let shared = VoiceRecordingService()
    
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var currentTranscript = ""
    @Published var hasPermission = false
    @Published var permissionStatus: VoicePermissionStatus = .unknown
    
    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    
    enum VoicePermissionStatus {
        case unknown
        case granted
        case denied
        case restricted
        
        var message: String {
            switch self {
            case .unknown: return "Permission needed to record voice memos"
            case .granted: return "Ready to record"
            case .denied: return "Microphone access denied. Please enable in Settings."
            case .restricted: return "Microphone access restricted"
            }
        }
    }
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        Task {
            await requestPermissions()
        }
    }
    
    @MainActor
    private func requestPermissions() async {
        // Request microphone permission
        let micPermission = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        // Request speech recognition permission
        let speechPermission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        let granted = micPermission && speechPermission == .authorized
        
        self.hasPermission = granted
        self.permissionStatus = granted ? .granted : .denied
        
        if granted {
            setupAudioSession()
        }
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    func startRecording() async throws -> URL? {
        guard hasPermission else {
            await requestPermissions()
            return nil
        }
        
        guard !isRecording else { return nil }
        
        // Use the same iCloud container as your app documents, with fallback to local
        var documentsURL: URL
        
        if let iCloudURL = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
            documentsURL = iCloudURL
            print("🎤 Using iCloud Documents directory")
        } else {
            // Fallback to local documents
            documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            print("🎤 Using local Documents directory (iCloud unavailable)")
        }
        
        // Create VoiceMemos subdirectory if it doesn't exist
        var voiceMemosDirURL = documentsURL.appendingPathComponent("VoiceMemos")
        do {
            try FileManager.default.createDirectory(at: voiceMemosDirURL, withIntermediateDirectories: true, attributes: nil)
            print("✅ VoiceMemos directory ready: \(voiceMemosDirURL.path)")
        } catch {
            print("❌ Failed to create VoiceMemos directory: \(error)")
            // Fall back to main documents directory
            voiceMemosDirURL = documentsURL
        }
        
        // Create recording URL
        let timestamp = Int(Date().timeIntervalSince1970)
        let audioFilename = voiceMemosDirURL.appendingPathComponent("voice_memo_\(timestamp).m4a")
        recordingURL = audioFilename
        
        print("🎤 Recording to: \(audioFilename.path)")
        print("🎤 Parent directory exists: \(FileManager.default.fileExists(atPath: voiceMemosDirURL.path))")
        
        // Setup audio recorder with better settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // Start recording and transcription
            let success = audioRecorder?.record() ?? false
            if success {
                isRecording = true
                currentTranscript = ""
                print("✅ Started recording successfully")
                
                // Start live transcription
                try await startSpeechRecognition()
                
                return audioFilename
            } else {
                print("❌ Failed to start audio recording")
                return nil
            }
        } catch {
            print("❌ Failed to create audio recorder: \(error)")
            throw error
        }
    }
    
    func stopRecording() -> (audioURL: URL?, transcript: String) {
        print("🛑 Stopping recording...")
        
        isRecording = false
        isTranscribing = false
        
        audioRecorder?.stop()
        stopSpeechRecognition()
        
        let finalURL = recordingURL
        let finalTranscript = currentTranscript
        
        // Verify file was created
        if let url = finalURL {
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            print("📁 Audio file exists: \(fileExists), size: \(fileSize) bytes")
            print("📁 File path: \(url.path)")
        }
        
        // Clean up
        recordingURL = nil
        audioRecorder = nil
        
        return (audioURL: finalURL, transcript: finalTranscript)
    }
    
    // MARK: - Speech Recognition Implementation
    private func startSpeechRecognition() async throws {
        // Check if iOS 26+ SpeechAnalyzer is available (future implementation)
        if #available(iOS 26.0, *) {
            // Future: Use SpeechAnalyzer for better performance
            try await startLegacySpeechRecognition()
        } else {
            try await startLegacySpeechRecognition()
        }
    }
    
    private func startLegacySpeechRecognition() async throws {
        guard let recognizer = SFSpeechRecognizer() else {
            throw VoiceRecordingError.speechRecognitionUnavailable
        }
        
        guard recognizer.isAvailable else {
            throw VoiceRecordingError.speechRecognitionUnavailable
        }
        
        speechRecognizer = recognizer
        isTranscribing = true
        
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        // Try to use on-device recognition if available
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        try audioEngine.start()
        
        // Start recognition
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let result = result {
                    self.currentTranscript = result.bestTranscription.formattedString
                }
                
                if error != nil {
                    self.stopSpeechRecognition()
                }
            }
        }
    }
    
    private func stopSpeechRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        speechRecognizer = nil
        isTranscribing = false
    }
}

// MARK: - AVAudioRecorderDelegate
extension VoiceRecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("❌ Audio recording failed")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ Audio recording error: \(error?.localizedDescription ?? "Unknown error")")
    }
}

// MARK: - Error Types
enum VoiceRecordingError: LocalizedError {
    case permissionDenied
    case speechRecognitionUnavailable
    case recordingFailed
    case iCloudUnavailable
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required for voice memos"
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available on this device"
        case .recordingFailed:
            return "Failed to start audio recording"
        case .iCloudUnavailable:
            return "iCloud Documents folder is not available"
        }
    }
}