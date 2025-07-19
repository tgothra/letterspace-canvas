import SwiftUI
import Foundation

// Struct to store tag color preferences persistently
struct TagColorPreference: Codable {
    let tag: String
    let colorHex: String
}

// Manages the colors associated with tags
class TagColorManager: ObservableObject {
    static let shared = TagColorManager()
    @Published var colorPreferences: [String: Color] = [:]

    private let defaultColors: [Color] = [
        Color(hex: "#dc2626"),  // Crimson
        Color(hex: "#f97316"),  // Tangerine
        Color(hex: "#f59e0b"),  // Amber
        Color(hex: "#10b981"),  // Emerald
        Color(hex: "#0d9488"),  // Teal
        Color(hex: "#2563eb"),  // Cobalt
        Color(hex: "#4f46e5"),  // Indigo
        Color(hex: "#9333ea"),  // Purple
        Color(hex: "#db2777"),  // Magenta
        Color(hex: "#475569"),  // Slate
        Color(hex: "#b45309"),  // Sienna
        Color(hex: "#059669")   // Jade
    ]

    init() {
        loadColorPreferences()
    }

    // Returns the color for a given tag, generating and saving if necessary
    func color(for tag: String) -> Color {
        if let savedColor = colorPreferences[tag] {
            return savedColor
        }

        // Generate a deterministic color based on the tag's hash
        let hash = tag.utf8.reduce(0) { ($0 << 5) &+ Int($1) }
        let color = defaultColors[abs(hash) % defaultColors.count]

        // Save this color preference immediately
        colorPreferences[tag] = color
        saveColorPreferences()

        return color
    }

    // Sets a specific color for a tag and saves preferences
    func setColor(_ color: Color, for tag: String) {
        colorPreferences[tag] = color
        saveColorPreferences()

        // Notify that documents should update to reflect new color
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
    }

    // Loads saved color preferences from UserDefaults
    private func loadColorPreferences() {
        if let data = UserDefaults.standard.data(forKey: "TagColorPreferences"),
           let preferences = try? JSONDecoder().decode([TagColorPreference].self, from: data) {
            colorPreferences = Dictionary(uniqueKeysWithValues: preferences.map { (
                $0.tag,
                Color(hex: $0.colorHex) // Assumes Color(hex:) initializer exists
            )}) 
        }
    }

    // Saves current color preferences to UserDefaults
    private func saveColorPreferences() {
        let preferences = colorPreferences.map { (tag, color) -> TagColorPreference in
            // Assumes Color.toHex() extension exists
            return TagColorPreference(tag: tag, colorHex: color.toHex())
        }

        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "TagColorPreferences")
        }
    }
    
    // TODO: Consider adding a method to remove a tag's color preference when a tag is deleted.
    // func removeColorPreference(for tag: String) { ... }
}

// View for managing tags (renaming, deleting, changing color)
struct TagManager: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme // Assumes ThemeColors EnvironmentKey is set up
    let allTags: [String]
    @State private var editingTag: String?
    @State private var newName: String = ""
    @State private var tagToDelete: String?
    @State private var showDeleteAlert: Bool = false
    @StateObject private var colorManager = TagColorManager.shared
    @State private var selectedTag: String?
    @State private var hoveredTag: String?
    @State private var hoveredColor: String?
    @State private var showColorPicker: Bool = false
    @State private var hoveredPencil: String? = nil
    @State private var hoveredTrash: String? = nil

    private let colorPalette: [(name: String, color: Color)] = [
        ("Crimson", Color(hex: "#dc2626")),
        ("Tangerine", Color(hex: "#f97316")),
        ("Amber", Color(hex: "#f59e0b")),
        ("Emerald", Color(hex: "#10b981")),
        ("Teal", Color(hex: "#0d9488")),
        ("Cobalt", Color(hex: "#2563eb")),
        ("Indigo", Color(hex: "#4f46e5")),
        ("Purple", Color(hex: "#9333ea")),
        ("Magenta", Color(hex: "#db2777")),
        ("Slate", Color(hex: "#475569")),
        ("Sienna", Color(hex: "#b45309")),
        ("Jade", Color(hex: "#059669"))
    ]

    var body: some View {
        #if os(macOS)
        let mainBackgroundColor = colorScheme == .dark ? Color(.windowBackgroundColor) : .white
        #elseif os(iOS)
        let mainBackgroundColor = colorScheme == .dark ? Color(.systemBackground) : .white
        #endif
        
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tag Manager")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.primary)
                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.bottom, 8)

            // Tag list
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(allTags, id: \.self) { tag in
                        let rowBackgroundOpacity = hoveredTag == tag ? (colorScheme == .dark ? 0.05 : 0.03) : 0.0
                        let rowBackgroundColor = colorScheme == .dark ? Color.white.opacity(rowBackgroundOpacity) : Color.black.opacity(rowBackgroundOpacity)
                        
                        HStack(spacing: 8) {
                            if editingTag == tag {
                                // Editing state: TextField and save/cancel buttons
                                TextField("Tag name", text: $newName)
                                    .font(.system(size: 13))
                                    .textFieldStyle(.plain)
                                    .padding(6)
                                    .background(theme.background)
                                    .cornerRadius(6)
                                    .onSubmit {
                                        renameTag(from: tag, to: newName)
                                        editingTag = nil
                                    }

                                HStack(spacing: 8) {
                                    Button(action: { editingTag = nil; newName = tag }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14)).foregroundStyle(theme.secondary)
                                    }.buttonStyle(.plain)
                                    Button(action: { renameTag(from: tag, to: newName); editingTag = nil }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14)).foregroundStyle(theme.accent)
                                    }.buttonStyle(.plain).disabled(newName.isEmpty || newName == tag)
                                }
                            } else {
                                // Normal state: Color circle and tag name
                                HStack(spacing: 8) {
                                    let circleSize = hoveredTag == tag ? 10.0 : 8.0
                                    let backgroundOpacity = hoveredTag == tag ? (colorScheme == .dark ? 0.1 : 0.05) : 0.0
                                    let backgroundColor = colorScheme == .dark ? Color.white.opacity(backgroundOpacity) : Color.black.opacity(backgroundOpacity)
                                    let circleBaseColor = colorScheme == .dark ? Color.black : Color.white
                                    
                                    Circle()
                                        .stroke(colorManager.color(for: tag), lineWidth: 2)
                                        .background(Circle().fill(circleBaseColor.opacity(0.1)))
                                        .frame(width: circleSize, height: circleSize)
                                        .animation(.spring(response: 0.2), value: hoveredTag)
                                        .background(
                                            Circle()
                                                .fill(backgroundColor)
                                                .frame(width: 20, height: 20)
                                        )
                                        .onTapGesture { selectedTag = tag; showColorPicker = true }

                                    Text(tag).font(.system(size: 13)).foregroundStyle(theme.primary)
                                }
                            }
                            Spacer()
                            // Action buttons (Edit/Delete) on hover
                            if hoveredTag == tag && editingTag != tag {
                                HStack(spacing: 4) {
                                    let pencilBackgroundOpacity = hoveredPencil == tag ? (colorScheme == .dark ? 0.1 : 0.05) : 0.0
                                    let pencilBackgroundColor = colorScheme == .dark ? Color.white.opacity(pencilBackgroundOpacity) : Color.black.opacity(pencilBackgroundOpacity)
                                    
                                    let trashBackgroundOpacity = hoveredTrash == tag ? (colorScheme == .dark ? 0.1 : 0.05) : 0.0
                                    let trashBackgroundColor = colorScheme == .dark ? Color.white.opacity(trashBackgroundOpacity) : Color.black.opacity(trashBackgroundOpacity)
                                    
                                    Button(action: { editingTag = tag; newName = tag }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12)).foregroundStyle(theme.secondary)
                                            .padding(4)
                                            .background(Circle().fill(pencilBackgroundColor))
                                    }.buttonStyle(.plain).onHover { hover in withAnimation(.easeOut(duration: 0.15)) { hoveredPencil = hover ? tag : nil } }

                                    Button(action: { tagToDelete = tag; showDeleteAlert = true }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12)).foregroundStyle(Color(hex: "#ef4444")) // Error color
                                            .padding(4)
                                            .background(Circle().fill(trashBackgroundColor))
                                    }.buttonStyle(.plain).onHover { hover in withAnimation(.easeOut(duration: 0.15)) { hoveredTrash = hover ? tag : nil } }
                                }
                            }
                        }
                        .padding(.vertical, 10).padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 6).fill(rowBackgroundColor))
                        .padding(.horizontal, 10)
                        .contentShape(Rectangle())
                        .onHover { hover in withAnimation(.easeOut(duration: 0.15)) { hoveredTag = hover ? tag : nil } }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(height: {
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    // iPhone: Use most of the screen height, accounting for header, divider, and info message
                    return UIScreen.main.bounds.height * 0.6 // 60% of screen height for scrollable content
                } else {
                    return 250 // iPad: Keep fixed height for popover
                }
                #else
                return 250 // macOS: Keep fixed height for popover
                #endif
            }()) // Responsive height for the scrollable list

            Divider()

            // Info message
            HStack(spacing: 6) {
                Image(systemName: "info.circle").foregroundStyle(theme.secondary.opacity(0.6)).font(.system(size: 11))
                Text("Add tags in Document Details or inside documents").font(.system(size: 11)).foregroundStyle(theme.secondary.opacity(0.6))
                Spacer()
            }
            .padding(.vertical, 8).padding(.horizontal, 16)
        }
        .background(mainBackgroundColor) // Adapts background
        .alert("Delete Tag", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { tagToDelete = nil }
            Button("Delete", role: .destructive) {
                if let tag = tagToDelete { deleteTag(tag); tagToDelete = nil }
            }
        } message: { Text("Are you sure you want to delete this tag? This action cannot be undone.") }
        .popover(isPresented: $showColorPicker, arrowEdge: .leading) { // Color picker popover
            #if os(macOS)
            let popoverBackgroundColor = colorScheme == .dark ? Color(.windowBackgroundColor) : .white
            #elseif os(iOS)
            let popoverBackgroundColor = colorScheme == .dark ? Color(.systemBackground) : .white
            #endif
            
            VStack(spacing: 12) {
                Text("Select Color").font(.system(size: 13, weight: .semibold)).padding(.top, 12)
                VStack(spacing: 8) {
                    ForEach(colorPalette, id: \.name) { colorOption in
                        let colorBackgroundOpacity = hoveredColor == colorOption.name ? (colorScheme == .dark ? 0.05 : 0.03) : 0.0
                        let colorBackgroundColor = colorScheme == .dark ? Color.white.opacity(colorBackgroundOpacity) : Color.black.opacity(colorBackgroundOpacity)
                        let colorPickerBaseColor = colorScheme == .dark ? Color.black : Color.white
                        
                        HStack(spacing: 8) {
                            Circle()
                                .stroke(colorOption.color, lineWidth: 2)
                                .background(Circle().fill(colorPickerBaseColor.opacity(0.1)))
                                .frame(width: 16, height: 16)
                            Text(colorOption.name).font(.system(size: 13)).foregroundStyle(theme.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(colorBackgroundColor))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let tag = selectedTag { colorManager.setColor(colorOption.color, for: tag); showColorPicker = false }
                        }
                        .onHover { hover in hoveredColor = hover ? colorOption.name : nil }
                    }
                }
                .padding(.horizontal, 4).padding(.bottom, 12)
            }
            .frame(width: 160)
            .background(popoverBackgroundColor)
        }
    }

    // Renames a tag across all documents
    private func renameTag(from oldName: String, to newName: String) {
        guard oldName != newName, !newName.isEmpty else { return }
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error: Could not find documents directory.")
            return
        }

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }

            for url in fileURLs {
                // Assumes Letterspace_CanvasDocument struct is defined and Codable
                if let data = try? Data(contentsOf: url),
                   var doc = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data) {
                    if var tags = doc.tags, tags.contains(oldName) {
                        tags = tags.map { $0 == oldName ? newName : $0 }
                        doc.tags = tags
                        // Replace encodeJson call
                        if let updatedData = try? JSONEncoder().encode(doc) {
                            try? updatedData.write(to: url, options: .atomic)
                        }
                    }
                }
            }

            // Update color preference mapping
            if let color = colorManager.colorPreferences[oldName] {
                colorManager.setColor(color, for: newName)
                // Note: Old tag color preference remains. Consider removing it.
                 colorManager.colorPreferences.removeValue(forKey: oldName) // Remove old mapping
                 saveColorPreferences() // Explicitly save after removal
            }

            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        } catch {
            print("Error processing tag rename in documents directory: \(error)")
        }
    }

    // Deletes a tag from all documents
    private func deleteTag(_ tag: String) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error: Could not find documents directory.")
            return
        }

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "canvas" }

            for url in fileURLs {
                 // Assumes Letterspace_CanvasDocument struct is defined and Codable
                if let data = try? Data(contentsOf: url),
                   var doc = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data) {
                    if var tags = doc.tags, tags.contains(tag) {
                        tags.removeAll { $0 == tag }
                        doc.tags = tags.isEmpty ? nil : tags // Set to nil if no tags left
                         // Replace encodeJson call
                        if let updatedData = try? JSONEncoder().encode(doc) {
                            try? updatedData.write(to: url, options: .atomic)
                        }
                    }
                }
            }

            // Remove the color preference for the deleted tag
             colorManager.colorPreferences.removeValue(forKey: tag)
             saveColorPreferences() // Explicitly save after removal

            NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        } catch {
            print("Error processing tag deletion in documents directory: \(error)")
        }
    }

    // Saves preferences after direct modifications in rename/delete
    private func saveColorPreferences() {
        let preferences = colorManager.colorPreferences.map { (tag, color) -> TagColorPreference in
            return TagColorPreference(tag: tag, colorHex: color.toHex())
        }
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "TagColorPreferences")
        }
    }
}

// DELETE Placeholder JSON helpers and Document struct (lines 283-312) 