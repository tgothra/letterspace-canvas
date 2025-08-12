import SwiftUI

struct HeaderImageMenuView: View {
    let onFilesSelected: () -> Void
    let onPhotoLibrarySelected: () -> Void
    let onIconSelected: (String) -> Void
    let onCancel: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    
    // 10 predefined SF Symbol icons for header images with modern colors
    private let predefinedIcons: [(icon: String, color: Color)] = [
        ("book.fill", .indigo),
        ("cross.fill", .purple),
        ("heart.fill", .pink),
        ("star.fill", .orange),
        ("flame.fill", .red),
        ("leaf.fill", .green),
        ("mountain.2.fill", .teal),
        ("sun.max.fill", .yellow),
        ("moon.fill", .blue),
        ("hands.sparkles.fill", .mint)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Modern Header
                VStack(spacing: 20) {
                    // Title with emoji
                    HStack {
                        Image(systemName: "photo.artframe")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(theme.accent)
                        Text("Header Image")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    // Source selection cards
                    VStack(spacing: 14) {
                        // Files Card
                        Button(action: onFilesSelected) {
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.blue.gradient)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Browse Files")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("Import from Files app")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Photo Library Card
                        Button(action: onPhotoLibrarySelected) {
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.green.gradient)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "photo.fill")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Photo Library")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("Choose from photos")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 28)
                
                // Modern Divider
                HStack {
                    Rectangle()
                        .fill(.secondary.opacity(0.5))
                        .frame(height: 1)
                    Text("OR")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                    Rectangle()
                        .fill(.secondary.opacity(0.5))
                        .frame(height: 1)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                
                // Icons Section with modern styling
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.purple)
                        Text("Choose an Icon")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                    // Modern Icon Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 5), spacing: 16) {
                        ForEach(predefinedIcons, id: \.icon) { iconData in
                            Button(action: {
                                onIconSelected(iconData.icon)
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(iconData.color.gradient.opacity(0.15))
                                        .stroke(iconData.color.opacity(0.3), lineWidth: 1.5)
                                        .frame(width: 56, height: 56)
                                    
                                    Image(systemName: iconData.icon)
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundStyle(iconData.color.gradient)
                                }
                            }
                            .buttonStyle(.plain)
                            .scaleEffect(1.0)
                            .animation(.easeInOut(duration: 0.15), value: false)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            // Modern cancel button
            VStack {
                Spacer()
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        )
        .frame(maxWidth: 380, maxHeight: 600)
    }
}

// Preview
#Preview {
    HeaderImageMenuView(
        onFilesSelected: {},
        onPhotoLibrarySelected: {},
        onIconSelected: { _ in },
        onCancel: {}
    )
    .frame(maxHeight: 600)
    .background(Color.black.opacity(0.1))
}
