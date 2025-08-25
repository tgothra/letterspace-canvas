import SwiftUI
import AVFoundation

struct VoiceRecordingButton: View {
    @Binding var text: String
    let placeholder: String
    var onAudioSaved: ((URL, String) -> Void)? = nil // Optional callback for saving audio
    
    @StateObject private var voiceService = VoiceRecordingService.shared
    @State private var isThisButtonRecording = false // Individual recording state
    @State private var showingPermissionAlert = false
    @State private var recordingStartTime: Date?
    @State private var recordingTimer: Timer?
    @State private var recordingDuration: TimeInterval = 0
    @State private var savedAudioURL: URL?
    
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            // Main recording interface
            recordingInterface
            
            // Saved audio playback (only show after recording is complete)
            if !isThisButtonRecording, let audioURL = savedAudioURL {
                savedAudioView(url: audioURL)
            }
        }
    }
    
    private var recordingInterface: some View {
        HStack(spacing: 12) {
            // Recording button
            Button(action: {
                if isThisButtonRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isThisButtonRecording ? Color.red : theme.accent)
                        .frame(width: 44, height: 44)
                    
                    if isThisButtonRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!voiceService.hasPermission)
            
            VStack(alignment: .leading, spacing: 2) {
                if isThisButtonRecording {
                    HStack(spacing: 6) {
                        Text("Recording")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                        
                        // Pulsing dot
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                            .scaleEffect(isThisButtonRecording ? 1.2 : 0.8)
                            .animation(.easeInOut(duration: 0.8).repeatForever(), value: isThisButtonRecording)
                        
                        Spacer()
                        
                        Text(formatDuration(recordingDuration))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.secondary)
                            .monospacedDigit()
                    }
                    
                    Text("Voice memo will be transcribed when you stop")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondary)
                } else {
                    Text(voiceService.permissionStatus.message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(voiceService.hasPermission ? theme.primary : theme.secondary)
                    
                    if !voiceService.hasPermission {
                        Text("Tap to request access")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondary)
                    } else {
                        Text("Tap to record voice memo")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isThisButtonRecording ? Color.red.opacity(0.05) : Color.gray.opacity(0.05))
                .stroke(isThisButtonRecording ? Color.red.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func savedAudioView(url: URL) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                // Play/pause audio
                AudioPlaybackService.shared.playAudio(url: url)
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Voice Memo Saved")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.primary)
                
                Text("Tap to play recording")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondary)
            }
            
            Spacer()
            
            Button(action: {
                // Delete audio
                deleteAudio(url: url)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.05))
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func startRecording() {
        guard voiceService.hasPermission else {
            showingPermissionAlert = true
            return
        }
        
        // Stop any other recording first
        if voiceService.isRecording {
            voiceService.stopRecording()
        }
        
        isThisButtonRecording = true
        recordingStartTime = Date()
        recordingDuration = 0
        
        // Start duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let startTime = recordingStartTime {
                recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
        
        Task {
            do {
                savedAudioURL = try await voiceService.startRecording()
            } catch {
                print("❌ Failed to start recording: \(error)")
                isThisButtonRecording = false
            }
        }
    }
    
    private func stopRecording() {
        isThisButtonRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        let result = voiceService.stopRecording()
        
        // Update the bound text with transcript
        if !result.transcript.isEmpty {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                text = result.transcript
            } else {
                text += "\n\n" + result.transcript
            }
        }
        
        // Save audio URL for playback
        savedAudioURL = result.audioURL
        
        // Notify parent if callback provided
        if let audioURL = result.audioURL, let callback = onAudioSaved {
            callback(audioURL, result.transcript)
        }
    }
    
    private func deleteAudio(url: URL) {
        try? FileManager.default.removeItem(at: url)
        savedAudioURL = nil
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Playback Service
class AudioPlaybackService: NSObject, ObservableObject {
    static let shared = AudioPlaybackService()
    
    private var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    
    override init() {
        super.init()
    }
    
    func playAudio(url: URL) {
        do {
            // Setup audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            
            // Try different path resolution strategies
            var fileURL = url
            var fileExists = FileManager.default.fileExists(atPath: url.path)
            
            print("🎵 Original URL: \(url)")
            print("🎵 Original path exists: \(fileExists)")
            
            if !fileExists {
                // Try resolving relative to current documents directory
                let filename = url.lastPathComponent
                
                // Try iCloud documents first
                if let iCloudURL = Letterspace_CanvasDocument.getAppDocumentsDirectory() {
                    let iCloudVoiceURL = iCloudURL.appendingPathComponent("VoiceMemos").appendingPathComponent(filename)
                    if FileManager.default.fileExists(atPath: iCloudVoiceURL.path) {
                        fileURL = iCloudVoiceURL
                        fileExists = true
                        print("🎵 Found in iCloud VoiceMemos: \(iCloudVoiceURL.path)")
                    } else {
                        let iCloudDirectURL = iCloudURL.appendingPathComponent(filename)
                        if FileManager.default.fileExists(atPath: iCloudDirectURL.path) {
                            fileURL = iCloudDirectURL
                            fileExists = true
                            print("🎵 Found in iCloud root: \(iCloudDirectURL.path)")
                        }
                    }
                }
                
                // If still not found, try local documents
                if !fileExists {
                    let localDocuments = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let localVoiceURL = localDocuments.appendingPathComponent("VoiceMemos").appendingPathComponent(filename)
                    if FileManager.default.fileExists(atPath: localVoiceURL.path) {
                        fileURL = localVoiceURL
                        fileExists = true
                        print("🎵 Found in local VoiceMemos: \(localVoiceURL.path)")
                    } else {
                        let localDirectURL = localDocuments.appendingPathComponent(filename)
                        if FileManager.default.fileExists(atPath: localDirectURL.path) {
                            fileURL = localDirectURL
                            fileExists = true
                            print("🎵 Found in local root: \(localDirectURL.path)")
                        }
                    }
                }
            }
            
            // Check if file exists after path resolution
            guard fileExists else {
                print("❌ Audio file not found after trying all paths")
                print("❌ Searched for filename: \(url.lastPathComponent)")
                return
            }
            
            // Stop current playback if any
            if let currentPlayer = audioPlayer, currentPlayer.isPlaying {
                currentPlayer.stop()
            }
            
            // Create and configure audio player
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            let success = audioPlayer?.play() ?? false
            if success {
                isPlaying = true
                print("✅ Started playing audio from: \(fileURL.path)")
            } else {
                print("❌ Failed to start audio playback")
            }
            
        } catch {
            print("❌ Failed to play audio: \(error)")
            print("❌ Final URL attempted: \(url)")
        }
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        isPlaying = false
        print("⏹️ Stopped audio playback")
    }
}

extension AudioPlaybackService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
        if flag {
            print("✅ Audio finished playing successfully")
        } else {
            print("❌ Audio playback finished with error")
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
        print("❌ Audio decode error: \(error?.localizedDescription ?? "Unknown error")")
    }
}

#Preview {
    VStack(spacing: 20) {
        @State var text = ""
        @State var text2 = "This is some existing text in the field..."
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Empty Text Field")
                .font(.headline)
            
            VoiceRecordingButton(
                text: $text,
                placeholder: "Speak your thoughts..."
            )
        }
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Text Field with Content")
                .font(.headline)
            
            VoiceRecordingButton(
                text: $text2,
                placeholder: "Add more thoughts..."
            )
        }
        
        Spacer()
    }
    .padding()
}