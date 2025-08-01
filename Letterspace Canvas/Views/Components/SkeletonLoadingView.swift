import SwiftUI

// MARK: - Skeleton Loading System
struct SkeletonLoadingView: View {
    @State private var isAnimating = false
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
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.1),
                        Color.gray.opacity(0.3)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.4),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: height)
                    .offset(x: isAnimating ? (width ?? 200) : -(width ?? 200))
                    .animation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Document Row Skeleton
struct DocumentRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Document icon skeleton
            SkeletonLoadingView(width: 24, height: 24, cornerRadius: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                // Title skeleton
                SkeletonLoadingView(width: 120, height: 16, cornerRadius: 4)
                
                // Subtitle skeleton
                SkeletonLoadingView(width: 80, height: 12, cornerRadius: 3)
            }
            
            Spacer()
            
            // Menu icon skeleton
            SkeletonLoadingView(width: 20, height: 20, cornerRadius: 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Section Card Skeleton
struct SectionCardSkeleton: View {
    let title: String
    let itemCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header skeleton
            HStack {
                SkeletonLoadingView(width: 16, height: 16, cornerRadius: 8)
                SkeletonLoadingView(width: 80, height: 18, cornerRadius: 4)
                Spacer()
                SkeletonLoadingView(width: 40, height: 16, cornerRadius: 8)
            }
            
            // Content items skeleton
            VStack(spacing: 12) {
                ForEach(0..<itemCount, id: \.self) { _ in
                    DocumentRowSkeleton()
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - App Launch Skeleton
struct AppLaunchSkeleton: View {
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(spacing: 24) {
            // Header skeleton
            VStack(spacing: 16) {
                // Logo skeleton
                SkeletonLoadingView(width: 120, height: 40, cornerRadius: 8)
                
                // Greeting skeleton
                SkeletonLoadingView(width: 200, height: 24, cornerRadius: 4)
            }
            
            // Pinned section skeleton
            SectionCardSkeleton(title: "Pinned", itemCount: 2)
            
            // Filter buttons skeleton
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonLoadingView(width: 80, height: 32, cornerRadius: 16)
                }
            }
            
            // All documents section skeleton
            SectionCardSkeleton(title: "All Documents", itemCount: 5)
            
            Spacer()
        }
        .padding(20)
        .background(theme.background)
    }
}

// MARK: - Dashboard Skeleton
struct DashboardSkeleton: View {
    @Environment(\.themeColors) var theme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header skeleton
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SkeletonLoadingView(width: 100, height: 20, cornerRadius: 4)
                        Spacer()
                        SkeletonLoadingView(width: 60, height: 20, cornerRadius: 4)
                    }
                    
                    SkeletonLoadingView(width: 180, height: 28, cornerRadius: 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Pinned section skeleton
                SectionCardSkeleton(title: "Pinned", itemCount: 1)
                    .padding(.horizontal, 20)
                
                // Filter buttons skeleton
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonLoadingView(width: 80, height: 36, cornerRadius: 18)
                    }
                }
                .padding(.horizontal, 20)
                
                // All documents section skeleton
                SectionCardSkeleton(title: "All Documents", itemCount: 6)
                    .padding(.horizontal, 20)
            }
        }
        .background(theme.background)
    }
}

// MARK: - Floating Action Button Skeleton
struct FloatingActionButtonSkeleton: View {
    var body: some View {
        SkeletonLoadingView(width: 56, height: 56, cornerRadius: 28)
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // Individual skeleton
        SkeletonLoadingView(width: 200, height: 20, cornerRadius: 4)
        
        // Document row skeleton
        DocumentRowSkeleton()
        
        // Section card skeleton
        SectionCardSkeleton(title: "Pinned", itemCount: 2)
        
        // App launch skeleton
        AppLaunchSkeleton()
    }
    .padding()
} 