#if os(iOS)
import SwiftUI
import UIKit

// MARK: - Floating Header Component
@available(iOS 26.0, *)
struct FloatingHeaderComponent: View {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var headerImage: UIImage?
    @Binding var isShowingImagePicker: Bool
    @Binding var isEditingTitle: Bool
    @Binding var isEditingSubtitle: Bool
    @Binding var titleText: String
    @Binding var subtitleText: String
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isSubtitleFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    let paperWidth: CGFloat
    let onScrollToTop: () -> Void
    
    var body: some View {
        ZStack {
            if #available(iOS 26.0, *) {
                // Enhanced liquid glass background for floating state
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear) // No material fill - let glass effect do the work
                    .frame(width: paperWidth - 16, height: 80)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16)) // Pure glass effect without material interference
                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.05), radius: 8, x: 0, y: 4) // Very minimal shadow
            } else {
                // Fallback
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 0.25) : Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95, opacity: 0.25)) // Extremely transparent fallback
                    .frame(width: paperWidth - 16, height: 80)
                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.02), radius: 6, x: 0, y: 2) // Minimal shadow
            }
            
            // Content
            HStack(spacing: 12) {
                // Image thumbnail - tappable for photo selection
                Button(action: {
                    // Trigger photo picker action sheet
                    isShowingImagePicker = true
                }) {
                    if let headerImage = headerImage {
                        Image(uiImage: headerImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    } else {
                        // Placeholder for no image
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            )
                    }
                }
                .buttonStyle(.plain)
                
                // Title and subtitle - tappable for editing
                VStack(alignment: .leading, spacing: 2) {
                    // Title section
                    if isEditingTitle {
                        TextField("Enter title", text: $titleText)
                            .font(.system(size: 18, weight: .semibold))
                            .textFieldStyle(.plain)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .focused($isTitleFocused)
                            .onSubmit {
                                // Save and exit editing
                                document.title = titleText
                                document.save()
                                isEditingTitle = false
                            }
                            .onAppear {
                                titleText = document.title
                                isTitleFocused = true
                            }
                    } else {
                        Button(action: {
                            // Start editing title
                            titleText = document.title
                            isEditingTitle = true
                        }) {
                            Text(document.title.isEmpty ? "Untitled" : document.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Subtitle section
                    if isEditingSubtitle {
                        TextField("Enter subtitle", text: $subtitleText)
                            .font(.system(size: 14, weight: .regular))
                            .textFieldStyle(.plain)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
                            .focused($isSubtitleFocused)
                            .onSubmit {
                                // Save and exit editing
                                document.subtitle = subtitleText
                                document.save()
                                isEditingSubtitle = false
                            }
                            .onAppear {
                                subtitleText = document.subtitle
                                isSubtitleFocused = true
                            }
                    } else if !document.subtitle.isEmpty || isEditingTitle {
                        Button(action: {
                            // Start editing subtitle
                            subtitleText = document.subtitle
                            isEditingSubtitle = true
                        }) {
                            Text(document.subtitle.isEmpty ? "Add subtitle" : document.subtitle)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(document.subtitle.isEmpty ? 
                                    (colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4)) :
                                    (colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7)))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Scroll to top button with enhanced styling
                Button(action: {
                    // Scroll back to top to expand header with smooth animation
                    HapticFeedback.impact(.light)
                    onScrollToTop()
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.15))
                                .overlay(
                                    Circle()
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Preview
@available(iOS 26.0, *)
struct FloatingHeaderComponent_Previews: PreviewProvider {
    static var previews: some View {
        FloatingHeaderComponent(
            document: .constant(Letterspace_CanvasDocument()),
            headerImage: .constant(nil),
            isShowingImagePicker: .constant(false),
            isEditingTitle: .constant(false),
            isEditingSubtitle: .constant(false),
            titleText: .constant("Sample Title"),
            subtitleText: .constant("Sample Subtitle"),
            paperWidth: 400,
            onScrollToTop: {}
        )
    }
}
#endif 