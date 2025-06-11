#if os(macOS)
import SwiftUI 
import AppKit

// Custom view to use as the popover anchor that doesn't interfere with mouse events
struct PopoverAnchorView: NSViewRepresentable {
    var onFrameChange: (CGRect) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            let frame = nsView.convert(nsView.bounds, to: nil)
            onFrameChange(frame)
        }
    }
}

struct DocumentStatusView: View {
    let document: Letterspace_CanvasDocument
    let pinnedDocuments: Set<String>
    let wipDocuments: Set<String>
    let calendarDocuments: Set<String>
    let onPin: (String) -> Void
    let onWIP: (String) -> Void
    let onCalendar: (String) -> Void
    let onOpen: (Letterspace_CanvasDocument) -> Void
    let onShowDetails: (Letterspace_CanvasDocument) -> Void
    let onCalendarAction: ((String) -> Void)?
    let isHovering: Bool
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var showDetailsPopover = false
    @State private var showCalendarContext: Bool = false
    @State private var pinHover = false
    @State private var wipHover = false
    @State private var calendarHover = false
    @State private var detailsHover = false
    @State private var isPopoverInteracting = false
    @State private var calendarButtonRect: CGRect = .zero
    @State private var reopenSubscription: NSObjectProtocol?
    
    // Helper to check for upcoming scheduled presentations
    private var hasUpcomingSchedule: Bool {
        document.presentations.contains { $0.status == .scheduled && $0.datetime >= Date() }
    }
    
    var body: some View {
        ZStack {
            // Main content
            HStack(spacing: 8) {
                if isHovering || showCalendarContext {
                    HStack(spacing: 6) {
                        Button(action: {
                            onPin(document.id)
                        }) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(pinnedDocuments.contains(document.id) ? .green : (pinHover ? theme.accent : (colorScheme == .dark ? .white : .black)))
                                .scaleEffect(pinHover ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.15), value: pinHover)
                        }
                        .buttonStyle(.plain)
                        .help("Pin to Top")
                        .onHover { hovering in
                            pinHover = hovering
                        }
                        
                        Button(action: {
                            onWIP(document.id)
                        }) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(wipDocuments.contains(document.id) ? .orange : (wipHover ? theme.accent : (colorScheme == .dark ? .white : .black)))
                                .scaleEffect(wipHover ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.15), value: wipHover)
                        }
                        .buttonStyle(.plain)
                        .help("Mark as Work in Progress")
                        .onHover { hovering in
                            wipHover = hovering
                        }
                        
                        Button(action: {
                            // Check if we have the new action, use it if available
                            if let onCalendarAction = onCalendarAction {
                                onCalendarAction(document.id)
                            } else {
                                // Fall back to the original behavior
                                showCalendarContext = true
                            }
                        }) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                // Use hasUpcomingSchedule for blue color, otherwise default hover/theme color
                                .foregroundStyle(hasUpcomingSchedule ? .blue : (calendarHover ? theme.accent : (colorScheme == .dark ? .white : .black)))
                                .scaleEffect(calendarHover ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.15), value: calendarHover)
                        }
                        .buttonStyle(.plain)
                        .help("Add to Calendar")
                        .onHover { hovering in
                            calendarHover = hovering
                        }
                        
                        Button(action: {
                            onShowDetails(document)
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(detailsHover ? theme.accent : (colorScheme == .dark ? .white : .black))
                                .scaleEffect(detailsHover ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.15), value: detailsHover)
                        }
                        .buttonStyle(.plain)
                        .help("View Details")
                        .onHover { hovering in
                            detailsHover = hovering
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    // Removing the capsule background and shadow
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onDisappear {
            showCalendarContext = false
            
            // Remove observer if it exists
            if let subscription = reopenSubscription {
                NotificationCenter.default.removeObserver(subscription)
                reopenSubscription = nil
            }
        }
        .onAppear {
            // Add observer for reopening popover
            reopenSubscription = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ReopenCalendarPopover"),
                object: nil,
                queue: .main
            ) { _ in
                if !showCalendarContext {
                    showCalendarContext = true
                }
            }
        }
    }
}
#endif
