import SwiftUI
import Foundation

struct ElementSettings: View {
    @Binding var selectedElement: UUID?
    @State private var isHovering = false
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 70)
            
            // Header
            HStack {
                Text("Properties")
                    .font(.custom("InterTight-Bold", size: 24))
                    .foregroundStyle(theme.primary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if selectedElement != nil {
                        // STYLE section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("STYLE")
                                .font(.custom("InterTight-Medium", size: 13))
                                .foregroundStyle(theme.secondaryMuted)
                                .padding(.horizontal, 16)
                            
                            VStack(spacing: 8) {
                                StyleOptionButton(title: "Design", icon: "paintbrush")
                                StyleOptionButton(title: "Layout", icon: "square.grid.2x2")
                            }
                        }
                        
                        // DIMENSIONS section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("DIMENSIONS")
                                .font(.custom("InterTight-Medium", size: 13))
                                .foregroundStyle(theme.secondaryMuted)
                                .padding(.horizontal, 16)
                            
                            VStack(spacing: 8) {
                                StyleOptionButton(title: "Size", icon: "arrow.up.left.and.arrow.down.right")
                                StyleOptionButton(title: "Position", icon: "arrow.up.and.down.and.arrow.left.and.right")
                            }
                        }
                        
                        Rectangle()
                            .fill(theme.secondaryMuted.opacity(0.2))
                            .frame(height: 1)
                            .padding(.vertical, 8)
                    }
                    
                    // BLOCKS section (always visible)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("BLOCKS")
                            .font(.custom("InterTight-Medium", size: 13))
                            .foregroundStyle(theme.secondaryMuted)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 8) {
                            BlockButton(icon: "photo", title: "Image")
                            BlockButton(icon: "text.alignleft", title: "Text")
                            BlockButton(icon: "text.quote", title: "Multiline Text")
                            BlockButton(icon: "tablecells", title: "Table")
                            BlockButton(icon: "chevron.down.circle", title: "Dropdown")
                            BlockButton(icon: "calendar", title: "Date")
                            BlockButton(icon: "checklist", title: "Multi Selection")
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
            
            // Close button at bottom
            HStack {
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedElement = nil 
                    }
                }) {
                    Circle()
                        .fill(theme.surface)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Circle()
                                .fill(theme.primary)
                                .opacity(isHovering ? 0.2 : 0)
                        }
                        .overlay {
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.primary)
                        }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isHovering = hovering
                    }
                }
                Spacer()
            }
            .padding(16)
        }
    }
}

struct StyleOptionButton: View {
    let title: String
    let icon: String
    @State private var isHovering = false
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(title)
                    .font(.custom("InterTight-Medium", size: 14))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(theme.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.surface.opacity(isHovering ? 1.0 : 0.0))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

struct BlockButton: View {
    let icon: String
    let title: String
    @State private var isHovering = false
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(title)
                    .font(.custom("InterTight-Medium", size: 14))
                
                Spacer()
            }
            .foregroundStyle(theme.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    ElementSettings(selectedElement: .constant(UUID()))
        .frame(width: 280)
        .background(Color(.sRGB, red: 0.04, green: 0.04, blue: 0.04, opacity: 1.0))
        .withTheme()
} 