import SwiftUI

struct PresentationTimeline: View {
    let document: Letterspace_CanvasDocument
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @State private var presentations: [DocumentPresentation] = []
    @State private var showAddPresentation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Presentation Timeline")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.primary)
                
                Spacer()
                
                // Add button
                Button(action: {
                    // Post notification instead of setting local state
                    NotificationCenter.default.post(name: .showPresentationManager, object: nil, userInfo: ["documentId": document.id])
                }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Add")
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(Color.blue)
                }
                .buttonStyle(.plain)
                
                // Close button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if presentations.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.secondary.opacity(0.6))
                        .padding(.bottom, 8)
                    
                    Text("No presentations yet")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.secondary)
                    
                    Text("Add past or future presentations")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 32)
            } else {
                // Timeline with presentations
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Group by whether they're in the future or past, showing upcoming first
                        if !futurePresentations.isEmpty {
                            timelineSection(title: "Upcoming", items: futurePresentations)
                        }
                        
                        if !pastPresentations.isEmpty {
                            timelineSection(title: "Past Presentations", items: pastPresentations)
                        }
                    }
                    .padding(.bottom, 16)
                }
                .frame(maxHeight: 400)
            }
        }
        .padding(16)
        .frame(width: 400)
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.12) : .white)
        .cornerRadius(12)
        .onAppear {
            loadPresentations()
        }
    }
    
    private var pastPresentations: [DocumentPresentation] {
        return presentations
            .filter { $0.status.isPast || $0.datetime < Date() }
            .sorted { $0.datetime > $1.datetime } // Most recent first
    }
    
    private var futurePresentations: [DocumentPresentation] {
        return presentations
            .filter { $0.status.isFuture && $0.datetime >= Date() }
            .sorted { $0.datetime < $1.datetime } // Soonest first
    }
    
    private func timelineSection(title: String, items: [DocumentPresentation]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            ForEach(items) { presentation in
                timelineItem(presentation)
                
                if presentation.id != items.last?.id {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }
    
    private func timelineItem(_ presentation: DocumentPresentation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(Color(hex: presentation.status.color))
                    .frame(width: 20, height: 20)
                
                if presentation.status == .scheduled {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                } else if presentation.status == .presented {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                } else if presentation.status == .canceled {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                } else if presentation.status == .rescheduled {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Date and time
                Text(formatDate(presentation.datetime))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.primary)
                
                // Status text
                HStack {
                    Text(presentation.status.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: presentation.status.color))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: presentation.status.color).opacity(0.1))
                        .cornerRadius(4)
                    
                    if let serviceType = presentation.serviceType {
                        Text(serviceType.rawValue)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                // Location
                if let location = presentation.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.secondary)
                        
                        Text(location)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.secondary)
                    }
                }
                
                // Notes
                if let notes = presentation.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondary.opacity(0.8))
                        .lineLimit(2)
                        .padding(.top, 2)
                }
                
                // Recurrence badge
                if let recurrence = presentation.recurrence, recurrence.isRecurring {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.secondary)
                        
                        switch recurrence {
                        case .weekly(let daysOfWeek):
                            Text("Weekly: \(daysOfWeek.sorted().map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", "))")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.secondary)
                        case .monthly(let dayOfMonth):
                            Text("Monthly on day \(dayOfMonth)")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.secondary)
                        case .yearly(let month, let day):
                            Text("Yearly on \(Calendar.current.monthSymbols[month - 1]) \(day)")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.secondary)
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Action menu
            Menu {
                if presentation.status == .scheduled {
                    Button(action: {
                        markAsPresented(presentation)
                    }) {
                        Label("Mark as Presented", systemImage: "checkmark.circle")
                    }
                    
                    Button(action: {
                        cancelPresentation(presentation)
                    }) {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                    
                    Divider()
                }
                
                Button(action: {
                    removePresentation(presentation)
                }) {
                    Label("Remove", systemImage: "trash")
                        .foregroundColor(.red)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
    
    private func loadPresentations() {
        presentations = document.presentations
    }
    
    private func markAsPresented(_ presentation: DocumentPresentation) {
        var updatedDoc = document
        var updatedPresentation = presentation
        updatedPresentation.status = .presented
        updatedDoc.updatePresentation(updatedPresentation)
        presentations = updatedDoc.presentations
    }
    
    private func cancelPresentation(_ presentation: DocumentPresentation) {
        var updatedDoc = document
        updatedDoc.cancelPresentation(id: presentation.id)
        presentations = updatedDoc.presentations
    }
    
    private func removePresentation(_ presentation: DocumentPresentation) {
        var updatedDoc = document
        updatedDoc.removePresentation(id: presentation.id)
        presentations = updatedDoc.presentations
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        return formatter.string(from: date)
    }
} 