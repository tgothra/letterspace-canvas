import SwiftUI

// MARK: - Helper Views
struct EditableField: View {
    let placeholder: String
    @Binding var text: String
    var isDateField: Bool = false
    var isLocationField: Bool = false
    var suggestions: [String] = []
    var onSelect: ((String) -> Void)? = nil
    var isBold: Bool = false
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    // Add local state to track text input
    @State private var localText: String = ""
    @State private var isShowingCalendar = false
    @State private var showSuggestions = false
    @State private var recentLocations: [String] = []
    @State private var selectedDate = Date()
    @FocusState private var isTextFieldFocused: Bool
    
    // Date formatter for displaying date with time
    private let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        return formatter
    }()
    
    // Date formatter for parsing date string
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
    
    // Lazy load documents only when needed for location suggestions
    private var documents: [Letterspace_CanvasDocument] {
        // Only load documents if we're in a location field
        guard isLocationField else {
            return []
        }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return []
        }
        
        let appDirectory = documentsPath.appendingPathComponent("Letterspace Canvas")
        print("📂 Loading documents from directory: \(appDirectory.path)")
        
        do {
            // Create app directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }
            
            print("📂 Found \(fileURLs.count) canvas files")
            
            let loadedDocs = fileURLs.compactMap { url -> Letterspace_CanvasDocument? in
                do {
                    let data = try Data(contentsOf: url)
                    let doc = try JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
                    print("📂 Loaded document: \(doc.title) (ID: \(doc.id))")
                    return doc
                } catch {
                    print("❌ Error loading document at \(url): \(error)")
                    return nil
                }
            }
            
            print("📂 Loaded \(loadedDocs.count) documents total")
            return loadedDocs
        } catch {
            print("❌ Error accessing documents directory: \(error)")
            return []
        }
    }
    
    private func loadRecentLocations() {
        // Get locations from all documents, with their last used date
        let locationsWithDates = documents.flatMap { doc -> [(String, Date)] in
            doc.variations.compactMap { variation -> (String, Date)? in
                guard let location = variation.location, !location.isEmpty else { return nil }
                return (location, doc.modifiedAt)
            }
        }
        
        // Group by location and take the most recent date for each
        let locationDict = Dictionary(grouping: locationsWithDates, by: { $0.0 })
            .mapValues { dates in
                dates.map { $0.1 }.max() ?? Date.distantPast
            }
        
        // Sort by date (most recent first) and take top 4
        recentLocations = locationDict
            .sorted { $0.value > $1.value }
            .prefix(4)
            .map { $0.key }
        
        // Show suggestions with animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            showSuggestions = true  // Show suggestions immediately when loading locations
        }
        
        // Print debug information
        print("📍 Found \(recentLocations.count) recent locations: \(recentLocations)")
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if isDateField {
                HStack {
                    Text(localText.isEmpty ? placeholder : localText)
                        .font(.system(size: 13, weight: isBold ? .medium : .regular))
                        .foregroundStyle(localText.isEmpty ? theme.secondary : theme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondary)
                }
                .padding(8)
                .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                .cornerRadius(6)
                .onTapGesture {
                    // Parse the current text to initialize the date
                    if !localText.isEmpty {
                        if let date = dateFormatter.date(from: localText) {
                            selectedDate = date
                        } else {
                            selectedDate = Date()
                        }
                    } else {
                        selectedDate = Date()
                    }
                    isShowingCalendar = true
                }
                .popover(isPresented: $isShowingCalendar) {
                    OptimizedCalendarPopover(selectedDate: Binding(
                        get: { selectedDate },
                        set: { date in
                            selectedDate = date
                            localText = dateTimeFormatter.string(from: date)
                            text = localText // Update the binding
                            isShowingCalendar = false
                        }
                    ))
                }
                .presentationCompactAdaptation(.popover) // Force popover style
                .presentationBackground(.white) // Set white background for the popover
                .presentationCornerRadius(8) // Match the corner radius
                .interactiveDismissDisabled(true) // Prevent accidental dismissal
            } else if isLocationField {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        TextField(placeholder, text: $localText)
                            .font(.system(size: 13, weight: isBold ? .medium : .regular))
                            .textFieldStyle(.plain)
                            .focused($isTextFieldFocused)
                            .onTapGesture {
                                loadRecentLocations()
                            }
                            .onChange(of: isTextFieldFocused) { oldValue, newValue in
                                if newValue {
                                    loadRecentLocations()
                                } else {
                                    // Don't hide suggestions immediately when losing focus
                                    // This allows clicking on suggestions
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        if !isTextFieldFocused {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                                showSuggestions = false
                                                recentLocations = []
                                            }
                                        }
                                    }
                                }
                            }
                            .onChange(of: localText) { oldValue, newValue in
                                // Sync local text with binding
                                text = newValue
                                print("📝 EditableField location: Text changed from '\(oldValue)' to '\(newValue)'")
                                
                                // Keep suggestions visible while typing
                                if isTextFieldFocused {
                                    showSuggestions = true
                                }
                            }
                            .onSubmit {
                                if !localText.isEmpty {
                                    onSelect?(localText)
                                    showSuggestions = false
                                    isTextFieldFocused = false
                                }
                            }
                            
                        // Add clear button
                        if !localText.isEmpty || showSuggestions {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                    localText = ""
                                    text = ""
                                    showSuggestions = false
                                    isTextFieldFocused = false
                                    onSelect?("")
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(theme.secondary.opacity(0.7))
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                    .cornerRadius(6)
                    .popover(isPresented: Binding<Bool>(
                        get: { showSuggestions },
                        set: {
                            if !$0 {
                                showSuggestions = false
                                // Clear input text if dismissed without selection
                                if isTextFieldFocused {
                                    localText = ""
                                    text = ""
                                    if let onSelectHandler = onSelect {
                                        onSelectHandler("")
                                    }
                                }
                                isTextFieldFocused = false
                            } else {
                                showSuggestions = $0
                            }
                        }
                    ), arrowEdge: .bottom) {
                        VStack(spacing: 0) {
                            LocationSuggestionsPopover(
                                recentLocations: recentLocations,
                                text: $localText,
                                showSuggestions: $showSuggestions,
                                isTextFieldFocused: Binding<Bool>(
                                    get: { isTextFieldFocused },
                                    set: { isTextFieldFocused = $0 }
                                ),
                                onSelect: onSelect
                            )
                        }
                        .frame(minWidth: 300, maxHeight: 250)
                        .padding(8)
                        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white)
                        .cornerRadius(8)
                    }
                    .presentationCompactAdaptation(.popover)
                }
                .zIndex(2)
            } else {
                TextField(placeholder, text: $localText)
                    .font(.system(size: 13, weight: isBold ? .medium : .regular))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95))
                    .cornerRadius(6)
                    .focused($isTextFieldFocused)
                    .onChange(of: localText) { oldValue, newValue in
                        // Immediately update the binding when local text changes
                        if text != newValue {
                            text = newValue
                            print("📝 EditableField: Text changed from '\(oldValue)' to '\(newValue)'")
                        }
                    }
                    .onChange(of: text) { oldValue, newValue in
                        // Keep localText in sync with external changes to binding
                        if localText != newValue {
                            localText = newValue
                            print("📝 EditableField: External text changed from '\(oldValue)' to '\(newValue)'")
                        }
                    }
                    .onSubmit {
                        isTextFieldFocused = false
                    }
            }
        }
        .onTapGesture {
            if !isLocationField {
                showSuggestions = false
                isTextFieldFocused = false
            }
        }
        .onAppear {
            // Ensure localText is synchronized with text binding on appearance
            localText = text
            print("📝 EditableField onAppear: Synced localText with text = '\(text)'")
        }
    }
}

struct SuggestionButton: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(theme.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected || isHovered ? theme.accent.opacity(0.1) : .clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct LinkItemView: View {
    let link: DocumentLink
    let onDelete: () -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {
            if let url = URL(string: link.url) {
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #elseif os(iOS)
                UIApplication.shared.open(url)
                #endif
            }
        }) {
            HStack(spacing: 8) {
                // Link icon based on URL type
                Image(systemName: getLinkIcon(for: link.url))
                    .font(.system(size: 14))
                    .foregroundStyle(theme.primary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title)
                        .font(.system(size: 13))
                        .foregroundStyle(theme.primary)
                        .lineLimit(1)
                    
                    Text(link.url)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isHovering {
                    HStack(spacing: 8) {
                        Button(action: {
                            if let url = URL(string: link.url) {
                                #if os(macOS)
                                NSWorkspace.shared.open(url)
                                #elseif os(iOS)
                                UIApplication.shared.open(url)
                                #endif
                            }
                        }) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Open Link")
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Delete Link")
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ?
                        (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.97)) :
                        .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private func getLinkIcon(for url: String) -> String {
        if url.contains("youtube.com") || url.contains("youtu.be") {
            return "play.square"
        } else if url.contains("drive.google.com") {
            return "doc.fill"
        } else if url.contains("dropbox.com") {
            return "folder.fill"
        } else {
            return "link"
        }
    }
}

// Add this helper view for consistent section headers
struct SectionHeader: View {
    let title: String
    let isExpanded: Bool
    let showChevron: Bool
    let icon: String?
    @Environment(\.themeColors) var theme
    @State private var isHovered = false
    
    init(title: String, isExpanded: Bool, showChevron: Bool = true, icon: String? = nil) {
        self.title = title
        self.isExpanded = isExpanded
        self.showChevron = showChevron
        self.icon = icon
    }
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(theme.primary)
            }
            Text(title)
                .font(.custom("Inter-Bold", size: 13))
                .foregroundColor(theme.primary)
            Spacer()
            if showChevron {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(theme.primary)
                    .padding(.trailing, 8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? theme.accent.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .padding(.horizontal, 8)
    }
}

// Add before RightSidebar struct
struct TagView: View {
    let text: String
    let onRemove: () -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var colorManager = TagColorManager.shared
    
    private func tagColor(for tag: String) -> Color {
        return colorManager.color(for: tag)
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(tagColor(for: text))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundColor(tagColor(for: text))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .stroke(tagColor(for: text), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(colorScheme == .dark ? .black : .white).opacity(0.1))
                )
        )
    }
}

struct MarkerRow: View {
    let marker: Marker
    @Environment(\.themeColors) var theme
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            // Navigate to marker
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(markerColor(for: marker.type))
                        .frame(width: 8, height: 8)
                
                Text(marker.title)
                    .font(.system(size: 13))
                    .foregroundColor(theme.primary)
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(theme.accent)
                    .font(.system(size: 16))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? theme.accent.opacity(0.1) : theme.background)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    private func markerColor(for type: String) -> Color {
        switch type {
        case "highlight": return Color(hex: "#22c27d")
        case "comment": return Color(hex: "#FF6B6B")
        case "bookmark": return Color(hex: "#4ECDC4")
        default: return Color(hex: "#96CEB4")
        }
    }
}

// Add this struct for the block buttons
struct BlockTypeButton: View {
    let icon: String
    let title: String
    var isSelected: Bool = false
    let action: () -> Void
    
    @Environment(\.themeColors) var theme
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.custom("Inter", size: 13))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .foregroundColor(isSelected ? theme.accent : (isHovered ? theme.primary : theme.secondary))
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? theme.accent : (isHovered ? theme.secondary.opacity(0.3) : Color.clear), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? theme.accent.opacity(0.1) : (isHovered ? theme.surface : Color.clear))
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct NavigationButton: View {
    var icon: String? = nil
    var label: String? = nil
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.secondary)
                }
                
                if let label = label {
                    Text(label)
                        .font(.custom("Inter", size: 11))
                        .foregroundStyle(theme.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ?
                          (colorScheme == .dark ? Color(.sRGB, white: 0.25) : Color(.sRGB, white: 0.9)) :
                          Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// Add this new component after the EditableField struct
struct LocationSuggestionButton: View {
    let location: String
    var isAdd: Bool = false
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isAdd {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#22c27d"))
                    Text("Add \"\(location)\"")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#22c27d"))
                } else {
                    Circle()
                        .fill(theme.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(location)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.primary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Rectangle()
                    .fill(isHovered ? theme.accent.opacity(0.1) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// Add this component before RightSidebar struct
struct LocationSuggestionsPopover: View {
    let recentLocations: [String]
    @Binding var text: String
    @Binding var showSuggestions: Bool
    // Change parameter to expect a regular binding that we'll create from FocusState
    @Binding var isTextFieldFocused: Bool
    var onSelect: ((String) -> Void)?
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var hoveredLocation: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Matching Locations")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 2)
            
            Divider()
                .padding(.horizontal, 8)
            
            // Location suggestions
            if recentLocations.isEmpty && !text.isEmpty {
                // Show "Add location" if no matches but text exists
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        showSuggestions = false
                        isTextFieldFocused = false
                        onSelect?(text)
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                        Text("Add \"\(text)\"")
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(hoveredLocation == "add" ?
                        (colorScheme == .dark ? Color.blue.opacity(0.15) : Color.blue.opacity(0.05)) :
                        Color.clear)
                }
                .buttonStyle(.plain)
                .onHover(perform: { hovering in
                    hoveredLocation = hovering ? "add" : nil
                })
            } else if recentLocations.isEmpty {
                Text("No recent locations")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(recentLocations.filter { text.isEmpty || $0.localizedCaseInsensitiveContains(text) }, id: \.self) { loc in
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            text = loc
                            showSuggestions = false
                            isTextFieldFocused = false
                            onSelect?(loc)
                        }
                    }) {
                        HStack {
                            Image(systemName: "mappin.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(theme.secondary)
                            Text(loc)
                                .font(.system(size: 13))
                                .foregroundStyle(theme.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(hoveredLocation == loc ?
                            (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95)) :
                            Color.clear)
                    }
                    .buttonStyle(.plain)
                    .onHover(perform: { hovering in
                        hoveredLocation = hovering ? loc : nil
                    })
                    
                    if loc != recentLocations.filter({ text.isEmpty || $0.localizedCaseInsensitiveContains(text) }).last {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
                
                // Option to add new location if it doesn't exist in recent locations
                if !text.isEmpty && !recentLocations.contains(where: { $0.localizedCaseInsensitiveCompare(text) == .orderedSame }) {
                    Divider()
                        .padding(.horizontal, 8)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            showSuggestions = false
                            isTextFieldFocused = false
                            onSelect?(text)
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.blue)
                            Text("Add \"\(text)\"")
                                .font(.system(size: 13))
                                .foregroundStyle(.blue)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(hoveredLocation == "add" ?
                            (colorScheme == .dark ? Color.blue.opacity(0.15) : Color.blue.opacity(0.05)) :
                            Color.clear)
                    }
                    .buttonStyle(.plain)
                    .onHover(perform: { hovering in
                        hoveredLocation = hovering ? "add" : nil
                    })
                }
            }
        }
    }
}

// MARK: - Missing Components for RightSidebar

struct VariationItem: View {
    let title: String
    let date: String
    let isOriginal: Bool
    let action: () -> Void
    let onDelete: () -> Void
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    @State private var showMenu = false
    @State private var isOpenHovered = false
    @State private var isDeleteHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isOriginal ? Color(hex: "#22c27d") : theme.secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primary)
                    Text(date)
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondary)
                }
                Spacer()
                
                // Context menu button that appears on hover
                if isHovered || showMenu {
                    Button(action: { showMenu = true }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showMenu, arrowEdge: .bottom) {
                        VStack(spacing: 0) {
                            Button(action: {
                                action()
                                showMenu = false
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 12))
                                    Text("Open")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(theme.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.93))
                                    .opacity(isOpenHovered ? 1 : 0)
                            )
                            .onHover { isOpenHovered = $0 }
                            
                            if !isOriginal {
                                Divider()
                                
                                Button(action: {
                                    onDelete()
                                    showMenu = false
                                }) {
                                    HStack {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                        Text("Delete")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.93))
                                        .opacity(isDeleteHovered ? 1 : 0)
                                )
                                .onHover { isDeleteHovered = $0 }
                            }
                        }
                        .frame(width: 120)
                        .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : .white)
                        .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill((isHovered || showMenu) ?
                        (colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color(.sRGB, white: 0.93)) :
                        Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct SelectedSeriesView: View {
    let seriesName: String
    let items: [(title: String, date: String, isActive: Bool)]
    @Binding var isDateSortAscending: Bool
    let onRemoveSeries: () -> Void
    let onOpenItem: ((title: String, date: String, isActive: Bool)) -> Void
    
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Series title and remove button
            HStack {
                Text(seriesName)
                    .font(.custom("Inter-Medium", size: 16))
                    .foregroundColor(theme.primary)
                Spacer()
                Button(action: onRemoveSeries) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Column headers
            HStack {
                Text("Name")
                    .font(.custom("Inter-Medium", size: 11))
                    .foregroundColor(theme.secondary)
                Spacer()
                Button(action: {
                    withAnimation {
                        isDateSortAscending.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Presented On")
                            .font(.custom("Inter-Medium", size: 11))
                            .foregroundColor(theme.secondary)
                        Image(systemName: isDateSortAscending ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                            .foregroundColor(theme.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Series items list
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(items, id: \.title) { item in
                        Button(action: {
                            onOpenItem(item)
                        }) {
                            HStack(alignment: .top) {
                                // Document indicator - green for active, black/white for others
                                Circle()
                                    .fill(item.isActive ? Color(hex: "#22c27d") : theme.primary)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 4)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.custom("Inter-Medium", size: 12))
                                        .foregroundColor(theme.primary)
                                        .lineLimit(1)
                                    
                                    if !item.date.isEmpty {
                                        Text(item.date)
                                            .font(.custom("Inter-Regular", size: 12))
                                            .foregroundColor(theme.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(item.isActive)
                    }
                }
            }
        }
    }
}

struct RecentSeriesList: View {
    let recentSeries: [String]
    @Binding var hoveredSeriesItem: String?
    let onSelect: (String) -> Void
    
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Series")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            ForEach(recentSeries.prefix(3), id: \.self) { series in
                let isHovering = hoveredSeriesItem == series
                let backgroundColor = colorScheme == .dark ?
                    Color(.sRGB, white: 0.2, opacity: isHovering ? 1 : 0) :
                    Color(.sRGB, white: 0.95, opacity: isHovering ? 1 : 0)
                
                Button(action: {
                    onSelect(series)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.secondary)
                        Text(series)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(backgroundColor)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredSeriesItem = hovering ? series : nil
                }
            }
        }
    }
}

struct SeriesDropdownView: View {
    let matchingSeries: [String]
    let shouldShowCreateNew: Bool
    let seriesSearchText: String
    let formatSeries: (String) -> String
    @Binding var hoveredSeriesItem: String?
    let onSelect: (String) -> Void
    
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Matching Series")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 2)
            
            Divider()
                .padding(.horizontal, 8)
            
            // Matching series suggestions
            ForEach(matchingSeries.prefix(5), id: \.self) { series in
                Button(action: {
                    onSelect(series)
                }) {
                    HStack {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.secondary)
                        Text(series)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(hoveredSeriesItem == series ?
                        (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95)) :
                        Color.clear)
                }
                .buttonStyle(.plain)
                .onHover(perform: { hovering in
                    hoveredSeriesItem = hovering ? series : nil
                })
                
                if series != matchingSeries.prefix(5).last {
                    Divider()
                        .padding(.leading, 12)
                }
            }
            
            // Option to create a new series if it doesn't exist
            if shouldShowCreateNew {
                Divider()
                    .padding(.horizontal, 8)
                
                Button(action: {
                    let formattedSeries = formatSeries(seriesSearchText)
                    onSelect(formattedSeries)
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Create \"\(formatSeries(seriesSearchText))\"")
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(hoveredSeriesItem == "create" ?
                        (colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color(.sRGB, white: 0.95)) :
                        Color.clear)
                }
                .buttonStyle(.plain)
                .onHover(perform: { hovering in
                    hoveredSeriesItem = hovering ? "create" : nil
                })
            }
        }
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.15) : Color.white)
        .cornerRadius(8)
        .frame(width: 250)
        .fixedSize(horizontal: false, vertical: true)
        // Add shadow to create visual separation instead of a border
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}
