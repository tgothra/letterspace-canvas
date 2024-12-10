import SwiftUI

enum ViewMode {
    case normal      // Everything visible
    case minimal     // Just the lips visible
    case focus      // Everything hidden
}

struct SpringyButton: ButtonStyle {
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(isHovering ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
    }
}

struct Logo: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Image(colorScheme == .dark ? "Dark 1 - Logo" : "Light 1 - Logo")
            .resizable()
            .scaledToFit()
            .frame(height: 28)
    }
}

struct SidebarButton: View {
    let icon: String
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(theme.surface)
                .frame(width: 32, height: 32)
                .overlay {
                    Circle()
                        .fill(theme.primary)
                        .opacity(isHovering ? 0.2 : 0)
                }
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.primary)
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

struct SidebarActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.themeColors) var theme
    
    var body: some View {
        Button(action: action) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 20, alignment: .center)
                    Text(title)
                        .font(.custom("InterTight-Medium", size: 16))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(isHovering ? 0.1 : 0))
                )
                .foregroundStyle(theme.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

struct MainLayout: View {
    @Binding var document: Letterspace_CanvasDocument
    @State private var isSidebarCollapsed = false
    @State private var isHovering = false
    @State private var isHoveringSettings = false
    @State private var documentsExpanded = true
    @State private var viewMode: ViewMode = .normal
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var isDarkMode = false
    @State private var transitionOpacity = 1.0
    @State private var isScrolling = false
    @State private var scrollTimer: Timer?
    
    // Increase sidebar width more significantly
    let sidebarWidth: CGFloat = 280
    let settingsWidth: CGFloat = 220
    let collapsedWidth: CGFloat = 48
    
    var body: some View {
        ZStack {
            content
                .opacity(transitionOpacity)
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    var content: some View {
        ZStack {
            Color.clear // Base layer
            
            HStack(spacing: 0) {
                if viewMode != .focus {
                    // Left sidebar area
                    if !isSidebarCollapsed {
                        ZStack {
                            // Base white layer
                            Rectangle()
                                .fill(colorScheme == .light ? .white : Color(.sRGB, red: 0.12, green: 0.12, blue: 0.12, opacity: 1.0))
                                .frame(width: sidebarWidth)
                            
                            VStack(spacing: 0) {
                                // Logo section with padding from top of screen
                                HStack {
                                    Spacer()
                                    Image(colorScheme == .dark ? "Dark 1 - Logo" : "Light 1 - Logo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 40)
                                    Spacer()
                                }
                                .frame(height: 70)
                                .padding(.top, 60)
                                .padding(.bottom, 70)
                                
                                // Actions
                                VStack(spacing: 8) {
                                    SidebarActionButton(title: "Search", icon: "magnifyingglass", action: {})
                                    SidebarActionButton(title: "All Documents", icon: "folder", action: {})
                                    SidebarActionButton(title: "New Document", icon: "plus", action: {})
                                    SidebarActionButton(title: "New Folder", icon: "folder.badge.plus", action: {})
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 32)
                                
                                // Separator
                                Image("Separator_Icon")
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 12)
                                    .foregroundStyle(theme.accent)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 32)
                                    .zIndex(1)
                                
                                // Document folders
                                VStack(spacing: 8) {
                                    DocumentFolderButton(title: "Sermons", icon: "folder")
                                    DocumentFolderButton(title: "Bible Studies", icon: "folder")
                                    DocumentFolderButton(title: "Notes", icon: "folder")
                                    DocumentFolderButton(title: "Archive", icon: "folder")
                                }
                                .padding(.horizontal, 16)
                                
                                Spacer()
                                
                                // Theme toggle and collapse buttons at bottom
                                HStack {
                                    Spacer()
                                    HStack(spacing: 8) {
                                        SidebarButton(icon: "chevron.backward") {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                isSidebarCollapsed.toggle()
                                            }
                                        }
                                        
                                        SidebarButton(icon: isDarkMode ? "sun.max.fill" : "moon.fill") {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                transitionOpacity = 0
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                                    isDarkMode.toggle()
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        transitionOpacity = 1
                                                    }
                                                }
                                            }
                                        }
                                        
                                        SidebarButton(icon: "gearshape.fill") {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                // Settings action here
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                            }
                        }
                        .frame(width: sidebarWidth)
                        .zIndex(1)
                        .transition(.move(edge: .leading))
                    } else {
                        // Collapsed sidebar button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSidebarCollapsed.toggle()
                            }
                        }) {
                            ZStack {
                                // Base white layer
                                Rectangle()
                                    .fill(colorScheme == .light ? .white : Color(.sRGB, red: 0.12, green: 0.12, blue: 0.12, opacity: 1.0))
                                    .frame(width: collapsedWidth)
                                
                                // Sidebar content
                                VStack {
                                    SidebarButton(icon: "sidebar.left") {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isSidebarCollapsed.toggle()
                                        }
                                    }
                                    .padding(8)
                                    .padding(.top, 70)
                                    
                                    Spacer()
                                }
                            }
                            .frame(width: collapsedWidth)
                            .zIndex(1)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isHovering = hovering
                            }
                        }
                        .transition(.move(edge: .leading))
                    }
                }
                
                // Document Area
                ZStack {
                    theme.background
                        .ignoresSafeArea()
                    
                    DocumentArea(
                        document: $document,
                        isScrolling: $isScrolling,
                        scrollTimer: $scrollTimer,
                        isSidebarCollapsed: isSidebarCollapsed,
                        isDistractionFreeMode: viewMode == .focus,
                        viewMode: viewMode,
                        onHeaderClick: {
                            withAnimation(.spring(response: 0.3)) {
                                viewMode = .normal
                            }
                        }
                    )
                    
                    // Custom Scrollbar
                    GeometryReader { geometry in
                        HStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 2)
                                .opacity(isScrolling ? 1 : 0)
                                .animation(.easeInOut(duration: 0.2), value: isScrolling)
                        }
                    }
                    
                    // Floating buttons without overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                if viewMode == .normal {
                                    FloatingToolbar(document: $document)
                                }
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        switch viewMode {
                                        case .normal:
                                            viewMode = .focus  // First click: hide everything
                                            isSidebarCollapsed = true
                                        case .focus:
                                            viewMode = .minimal  // Second click: show lip
                                        case .minimal:
                                            viewMode = .normal  // Third click: show everything
                                            isSidebarCollapsed = false
                                        }
                                    }
                                }) {
                                    Image(systemName: viewModeIcon)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color.white)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(Color.black.opacity(0.8))
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(20)
                        }
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .layoutPriority(1)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
    
    private var viewModeIcon: String {
        switch viewMode {
        case .normal:
            return "arrow.up.left.and.arrow.down.right"  // Expand icon
        case .minimal:
            return "arrow.down.forward.and.arrow.up.backward"  // Mid state icon
        case .focus:
            return "arrow.down.right.and.arrow.up.left"  // Collapse icon
        }
    }
}

struct SidebarView: View {
    @Binding var document: Letterspace_CanvasDocument
    @Binding var isSidebarCollapsed: Bool
    @Binding var viewMode: ViewMode
    
    var body: some View {
        Text("Sidebar")
    }
}
