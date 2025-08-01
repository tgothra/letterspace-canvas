import SwiftUI

// MARK: - Modern Skeleton Loading System
struct SkeletonLoadingView: View {
    @State private var isAnimating = false
    @State private var shimmerOffset: CGFloat = -200
    @State private var breathScale: CGFloat = 1.0
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(skeletonBaseColor)
            .frame(width: width, height: height)
            .overlay(
                // Sophisticated shimmer effect
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(shimmerGradient)
                    .mask(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .rotationEffect(.degrees(30))
                            .offset(x: shimmerOffset)
                    )
                    .animation(
                        .easeInOut(duration: 1.8)
                        .repeatForever(autoreverses: false),
                        value: shimmerOffset
                    )
            )
            .scaleEffect(breathScale)
            .animation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true),
                value: breathScale
            )
            .onAppear {
                startAnimations()
            }
    }
    
    private var skeletonBaseColor: Color {
        if colorScheme == .dark {
            return Color(.systemGray5).opacity(0.3)
        } else {
            return Color(.systemGray6).opacity(0.6)
        }
    }
    
    private var shimmerGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    .clear,
                    Color.white.opacity(0.15),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [
                    .clear,
                    Color.white.opacity(0.8),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private func startAnimations() {
        shimmerOffset = (width ?? 200) + 100
        breathScale = 1.02
    }
}

// MARK: - Document Row Skeleton with Natural Variations
struct DocumentRowSkeleton: View {
    @State private var randomWidths: [CGFloat] = []
    
    var body: some View {
        HStack(spacing: 12) {
            // Document icon skeleton with subtle animation
            SkeletonLoadingView(width: 28, height: 28, cornerRadius: 6)
            
            VStack(alignment: .leading, spacing: 6) {
                // Title skeleton with random width for natural look
                SkeletonLoadingView(
                    width: randomWidths.isEmpty ? 140 : randomWidths[0], 
                    height: 16, 
                    cornerRadius: 4
                )
                
                // Subtitle skeleton with different random width
                SkeletonLoadingView(
                    width: randomWidths.count < 2 ? 90 : randomWidths[1], 
                    height: 12, 
                    cornerRadius: 3
                )
            }
            
            Spacer()
            
            // Menu icon skeleton
            SkeletonLoadingView(width: 24, height: 24, cornerRadius: 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .onAppear {
            generateRandomWidths()
        }
    }
    
    private func generateRandomWidths() {
        randomWidths = [
            CGFloat.random(in: 100...180), // Title width
            CGFloat.random(in: 60...120)   // Subtitle width
        ]
    }
}

// MARK: - Enhanced Section Card Skeleton
struct SectionCardSkeleton: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let itemCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Enhanced section header skeleton
            HStack(spacing: 12) {
                SkeletonLoadingView(width: 20, height: 20, cornerRadius: 10)
                SkeletonLoadingView(width: 100, height: 20, cornerRadius: 6)
                Spacer()
                SkeletonLoadingView(width: 50, height: 18, cornerRadius: 9)
            }
            
            // Content items skeleton with staggered animation
            VStack(spacing: 8) {
                ForEach(0..<itemCount, id: \.self) { index in
                    DocumentRowSkeleton()
                        .opacity(0.0)
                        .animation(
                            .easeInOut(duration: 0.4)
                            .delay(Double(index) * 0.1),
                            value: true
                        )
                        .onAppear {
                            withAnimation {
                                // Fade in with stagger
                            }
                        }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: shadowColor, radius: 12, x: 0, y: 4)
    }
    
    private var cardBackground: Color {
        if colorScheme == .dark {
            return Color(.systemGray6).opacity(0.1)
        } else {
            return Color(.systemBackground)
        }
    }
    
    private var shadowColor: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.3)
        } else {
            return Color.black.opacity(0.06)
        }
    }
}

// MARK: - Beautiful App Launch Skeleton
struct AppLaunchSkeleton: View {
    @Environment(\.themeColors) var theme
    @State private var logoScale: CGFloat = 0.9
    
    var body: some View {
        VStack(spacing: 32) {
            // Header skeleton with breathing logo
            VStack(spacing: 20) {
                // Animated logo skeleton
                SkeletonLoadingView(width: 140, height: 50, cornerRadius: 12)
                    .scaleEffect(logoScale)
                    .animation(
                        .easeInOut(duration: 2.5)
                        .repeatForever(autoreverses: true),
                        value: logoScale
                    )
                
                // Greeting skeleton
                SkeletonLoadingView(width: 220, height: 28, cornerRadius: 6)
            }
            .onAppear {
                logoScale = 1.05
            }
            
            // Pinned section skeleton
            SectionCardSkeleton(title: "Pinned", itemCount: 2)
            
            // Enhanced filter buttons skeleton
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { index in
                    SkeletonLoadingView(
                        width: CGFloat.random(in: 70...100), 
                        height: 36, 
                        cornerRadius: 18
                    )
                    .animation(
                        .easeInOut(duration: 1.5)
                        .delay(Double(index) * 0.2)
                        .repeatForever(autoreverses: true),
                        value: true
                    )
                }
            }
            
            // All documents section skeleton
            SectionCardSkeleton(title: "All Documents", itemCount: 4)
            
            Spacer()
        }
        .padding(24)
        .background(theme.background)
    }
}

// MARK: - Enhanced Dashboard Skeleton
struct DashboardSkeleton: View {
    @Environment(\.themeColors) var theme
    @State private var headerAnimation: Bool = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Enhanced header skeleton
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        SkeletonLoadingView(width: 120, height: 24, cornerRadius: 6)
                            .scaleEffect(headerAnimation ? 1.02 : 0.98)
                        Spacer()
                        SkeletonLoadingView(width: 70, height: 24, cornerRadius: 12)
                    }
                    
                    SkeletonLoadingView(width: 200, height: 32, cornerRadius: 8)
                        .animation(
                            .easeInOut(duration: 2.2)
                            .repeatForever(autoreverses: true),
                            value: headerAnimation
                        )
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .onAppear {
                    headerAnimation = true
                }
                
                // Pinned section skeleton
                SectionCardSkeleton(title: "Pinned", itemCount: 1)
                    .padding(.horizontal, 24)
                
                // Enhanced filter buttons skeleton
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { index in
                        SkeletonLoadingView(
                            width: CGFloat.random(in: 75...110), 
                            height: 40, 
                            cornerRadius: 20
                        )
                        .animation(
                            .easeInOut(duration: 1.8)
                            .delay(Double(index) * 0.15)
                            .repeatForever(autoreverses: true),
                            value: true
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                // All documents section skeleton
                SectionCardSkeleton(title: "All Documents", itemCount: 5)
                    .padding(.horizontal, 24)
                
                // Extra spacing for natural feel
                Rectangle()
                    .fill(.clear)
                    .frame(height: 60)
            }
        }
        .background(theme.background)
    }
}

// MARK: - Enhanced Floating Action Button Skeleton
struct FloatingActionButtonSkeleton: View {
    @State private var glowIntensity: Double = 0.3
    @Environment(\.themeColors) var theme
    
    var body: some View {
        SkeletonLoadingView(width: 56, height: 56, cornerRadius: 28)
            .shadow(color: theme.accent.opacity(glowIntensity), radius: 16, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
            .animation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true),
                value: glowIntensity
            )
            .onAppear {
                glowIntensity = 0.7
            }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 24) {
        // Individual skeleton
        SkeletonLoadingView(width: 200, height: 20, cornerRadius: 6)
        
        // Document row skeleton
        DocumentRowSkeleton()
        
        // Section card skeleton
        SectionCardSkeleton(title: "Pinned", itemCount: 2)
        
        Spacer()
    }
    .padding()
    .background(Color(.systemBackground))
} 