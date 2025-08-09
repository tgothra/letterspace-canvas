import SwiftUI

struct PreachItAgainDetailsView: View {
    let document: Letterspace_CanvasDocument
    let onDismiss: () -> Void
    let onOpenDocument: (Letterspace_CanvasDocument) -> Void
    
    @Environment(\.themeColors) var theme
    @State private var showingDocumentDetails = false
    @State private var showingJournalEntries = false
    
    private var preachingHistory: [DocumentVariation] {
        document.variations.filter { $0.datePresented != nil }
            .sorted { ($0.datePresented ?? Date.distantPast) > ($1.datePresented ?? Date.distantPast) }
    }
    
    private var lastPreachedDate: Date? {
        preachingHistory.first?.datePresented
    }
    
    private var timeSinceLastPreached: String {
        guard let date = lastPreachedDate else { return "Never preached" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private var totalTimesPreached: Int {
        preachingHistory.count
    }
    
    private var whyPreachAgainReasons: [String] {
        var reasons: [String] = []
        
        // Time-based reason
        if let lastDate = lastPreachedDate {
            let monthsAgo = Calendar.current.dateComponents([.month], from: lastDate, to: Date()).month ?? 0
            if monthsAgo >= 12 {
                reasons.append("Over a year since last preached - fresh for current congregation")
            } else if monthsAgo >= 6 {
                reasons.append("Sufficient time has passed for a fresh delivery")
            }
        }
        
        // Content-based reasons
        if document.title.lowercased().contains("love") || document.title.lowercased().contains("grace") {
            reasons.append("Timeless message that speaks to every generation")
        }
        
        if totalTimesPreached >= 3 {
            reasons.append("Proven impact - has been well-received multiple times")
        }
        
        if document.subtitle.lowercased().contains("christmas") || document.subtitle.lowercased().contains("easter") {
            reasons.append("Seasonal relevance makes this perfect timing")
        }
        
        // Default reasons if none specific
        if reasons.isEmpty {
            reasons = [
                "Strong biblical foundation worth revisiting",
                "Relevant themes for current times",
                "Opportunity to reach new congregation members"
            ]
        }
        
        return reasons
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header section with sermon summary
                    headerSection
                    
                    // Why preach again section
                    whyPreachAgainSection
                    
                    // Preaching history
                    preachingHistorySection
                    
                    // Action buttons
                    actionButtonsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Preach It Again")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done", action: onDismiss)
                }
            }
            #endif
        }
        .sheet(isPresented: $showingDocumentDetails) {
            // This would show the document details card
            Text("Document Details View")
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingJournalEntries) {
            // This would show journal entries for this sermon
            Text("Journal Entries View")
                .presentationDetents([.medium, .large])
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sermon title and info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Text("READY TO PREACH")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.orange.opacity(0.1))
                        )
                }
                
                Text(document.title)
                    .font(.title2.bold())
                    .foregroundColor(theme.primary)
                
                if !document.subtitle.isEmpty {
                    Text(document.subtitle)
                        .font(.headline)
                        .foregroundColor(theme.secondary)
                }
            }
            
            // Quick stats
            HStack(spacing: 24) {
                statItem("Last Preached", timeSinceLastPreached, "clock.fill", .blue)
                statItem("Times Preached", "\(totalTimesPreached)", "repeat.circle.fill", .green)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func statItem(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(theme.secondary)
            }
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(theme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var whyPreachAgainSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                
                Text("Why Preach This Again?")
                    .font(.headline.bold())
                    .foregroundColor(theme.primary)
            }
            
            VStack(spacing: 12) {
                ForEach(Array(whyPreachAgainReasons.enumerated()), id: \.offset) { index, reason in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(.yellow)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        
                        Text(reason)
                            .font(.subheadline)
                            .foregroundColor(theme.primary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.yellow.opacity(0.05))
                .stroke(.yellow.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var preachingHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Preaching History")
                    .font(.headline.bold())
                    .foregroundColor(theme.primary)
                
                Spacer()
                
                Button(action: { showingJournalEntries = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "book.pages")
                            .font(.caption)
                        Text("Journal Entries")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.purple.opacity(0.1))
                    )
                }
            }
            
            if preachingHistory.isEmpty {
                Text("No preaching history available")
                    .font(.subheadline)
                    .foregroundColor(theme.secondary)
                    .italic()
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(preachingHistory.enumerated()), id: \.element.id) { index, variation in
                        preachingHistoryItem(variation, isRecent: index == 0)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.purple.opacity(0.05))
                .stroke(.purple.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func preachingHistoryItem(_ variation: DocumentVariation, isRecent: Bool) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isRecent ? .purple : .purple.opacity(0.5))
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let date = variation.datePresented {
                        Text(date, style: .date)
                            .font(.subheadline.bold())
                            .foregroundColor(theme.primary)
                    }
                    
                    if isRecent {
                        Text("MOST RECENT")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.purple)
                            )
                    }
                    
                    Spacer()
                }
                
                if let location = variation.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.caption)
                        Text(location)
                            .font(.caption)
                    }
                    .foregroundColor(theme.secondary)
                }
                
                if let notes = variation.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(theme.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Primary action - open document
            Button(action: {
                onOpenDocument(document)
            }) {
                HStack {
                    Image(systemName: "doc.text.fill")
                    Text("Open Sermon Document")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            // Secondary actions
            HStack(spacing: 12) {
                Button(action: { showingDocumentDetails = true }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("View Details")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                
                Button(action: { showingJournalEntries = true }) {
                    HStack {
                        Image(systemName: "book.pages")
                        Text("Journal Entries")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
                }
            }
        }
    }
}

#Preview {
    PreachItAgainDetailsView(
        document: Letterspace_CanvasDocument(
            title: "The Power of Grace",
            subtitle: "Understanding God's Unmerited Favor",
            elements: [],
            id: "preview"
        ),
        onDismiss: {},
        onOpenDocument: { _ in }
    )
}