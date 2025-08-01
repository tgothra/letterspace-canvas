#if os(iOS)
import SwiftUI
import Intents
import IntentsUI

// MARK: - iOS 26 Siri Integration Demo View
@available(iOS 26.0, *)
struct SiriIntegrationView: View {
    @State private var siriService = SiriIntentService.shared
    @State private var showVoiceShortcuts = false
    @State private var selectedCommand: String = ""
    @State private var demoResults: [DemoResult] = []
    @State private var isProcessing = false
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                            .padding()
                            .background(
                                Circle()
                                    .fill(.blue.opacity(0.1))
                            )
                        
                        Text("iOS 26 Siri Integration")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Control your app with voice commands")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Status Card
                    StatusCard(isRegistered: siriService.isRegistered)
                    
                    // Voice Commands Section
                    VoiceCommandsSection(
                        onCommandTap: { command in
                            selectedCommand = command
                            simulateVoiceCommand(command)
                        }
                    )
                    
                    // Recent Activity
                    if !demoResults.isEmpty {
                        RecentActivitySection(results: demoResults)
                    }
                    
                    // Setup Section
                    SetupSection(showVoiceShortcuts: $showVoiceShortcuts)
                }
                .padding()
            }
            .navigationTitle("Siri Integration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showVoiceShortcuts) {
            VoiceShortcutsView()
        }
    }
    
    private func simulateVoiceCommand(_ command: String) {
        isProcessing = true
        selectedCommand = command
        
        // iOS 26 Enhancement: Haptic feedback for command recognition
        HapticFeedback.impact(.light, intensity: 0.8)
        
        Task {
            let result = await processVoiceCommand(command)
            
            await MainActor.run {
                demoResults.insert(result, at: 0)
                if demoResults.count > 5 {
                    demoResults.removeLast()
                }
                isProcessing = false
                
                // iOS 26 Enhancement: Success haptic feedback
                HapticFeedback.impact(.medium, intensity: 0.9)
            }
        }
    }
    
    private func processVoiceCommand(_ command: String) async -> DemoResult {
        let timestamp = Date()
        
        switch command {
        case let cmd where cmd.contains("create") && cmd.contains("document"):
            let doc = siriService.handleCreateDocument(type: DocumentType.general)
            return DemoResult(
                command: command,
                result: "Created '\(doc.title)' successfully",
                timestamp: timestamp,
                success: true,
                icon: "doc.fill"
            )
            
        case let cmd where cmd.contains("create") && cmd.contains("sermon"):
            let doc = siriService.handleCreateDocument(type: DocumentType.sermon)
            return DemoResult(
                command: command,
                result: "Created sermon document '\(doc.title)'",
                timestamp: timestamp,
                success: true,
                icon: "book.fill"
            )
            
        case let cmd where cmd.contains("bible verse"):
            let verse = await siriService.handleAddBibleVerse(topic: "faith")
            return DemoResult(
                command: command,
                result: verse.isEmpty ? "Error finding verse" : "Found Bible verse about faith",
                timestamp: timestamp,
                success: !verse.isEmpty,
                icon: "quote.bubble.fill"
            )
            
        case let cmd where cmd.contains("search library"):
            let results = await siriService.handleSearchLibrary(query: "sermon")
            return DemoResult(
                command: command,
                result: "Found \(results.count) items in library",
                timestamp: timestamp,
                success: true,
                icon: "magnifyingglass"
            )
            
        case let cmd where cmd.contains("recent documents"):
            let docs = siriService.handleShowRecentDocuments()
            return DemoResult(
                command: command,
                result: "Showing \(docs.count) recent documents",
                timestamp: timestamp,
                success: true,
                icon: "clock.fill"
            )
            
        default:
            return DemoResult(
                command: command,
                result: "Command not recognized",
                timestamp: timestamp,
                success: false,
                icon: "exclamationmark.triangle.fill"
            )
        }
    }
}

// MARK: - Supporting Views
@available(iOS 26.0, *)
struct StatusCard: View {
    let isRegistered: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isRegistered ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isRegistered ? .green : .orange)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Siri Integration")
                    .font(.headline)
                Text(isRegistered ? "Ready for voice commands" : "Setting up...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

@available(iOS 26.0, *)
struct VoiceCommandsSection: View {
    let onCommandTap: (String) -> Void
    
    private let commands = [
        VoiceCommand(
            title: "Create New Document",
            subtitle: "\"Create a new document\"",
            icon: "doc.fill",
            color: .blue,
            command: "Create a new document"
        ),
        VoiceCommand(
            title: "Create Sermon",
            subtitle: "\"Create a new sermon\"",
            icon: "book.fill", 
            color: .purple,
            command: "Create a new sermon"
        ),
        VoiceCommand(
            title: "Add Bible Verse",
            subtitle: "\"Add Bible verse about faith\"",
            icon: "quote.bubble.fill",
            color: .green,
            command: "Add Bible verse about faith"
        ),
        VoiceCommand(
            title: "Search Library",
            subtitle: "\"Search my library for sermon\"",
            icon: "magnifyingglass",
            color: .orange,
            command: "Search my library for sermon"
        ),
        VoiceCommand(
            title: "Recent Documents",
            subtitle: "\"Show recent documents\"",
            icon: "clock.fill",
            color: .indigo,
            command: "Show recent documents"
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Try Voice Commands")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(commands) { command in
                    VoiceCommandCard(command: command) {
                        onCommandTap(command.command)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

@available(iOS 26.0, *)
struct VoiceCommandCard: View {
    let command: VoiceCommand
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: command.icon)
                    .font(.title2)
                    .foregroundColor(command.color)
                
                VStack(spacing: 4) {
                    Text(command.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                    
                    Text(command.subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

@available(iOS 26.0, *)
struct RecentActivitySection: View {
    let results: [DemoResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(results) { result in
                    RecentActivityRow(result: result)
                }
            }
            .padding(.horizontal)
        }
    }
}

@available(iOS 26.0, *)
struct RecentActivityRow: View {
    let result: DemoResult
    
    var body: some View {
        HStack {
            Image(systemName: result.icon)
                .foregroundColor(result.success ? .green : .red)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.command)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(result.result)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(result.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
    }
}

@available(iOS 26.0, *)
struct SetupSection: View {
    @Binding var showVoiceShortcuts: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Setup")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: {
                showVoiceShortcuts = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    Text("Add Voice Shortcuts")
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
    }
}

@available(iOS 26.0, *)
struct VoiceShortcutsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Voice shortcuts will be available when this feature is fully implemented in iOS 26.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
                
                Text("🎤 Coming Soon!")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .navigationTitle("Voice Shortcuts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types
@available(iOS 26.0, *)
struct VoiceCommand: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let command: String
}

@available(iOS 26.0, *)
struct DemoResult: Identifiable {
    let id = UUID()
    let command: String
    let result: String
    let timestamp: Date
    let success: Bool
    let icon: String
}

#endif 
