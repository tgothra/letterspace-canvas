        }
        .glassmorphismBackground(cornerRadius: 12)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: colorScheme == .dark ? .black.opacity(0.17) : .black.opacity(0.07),
            radius: 8,
            x: 0,
            y: 1
        )
        .frame(
            maxWidth: isIPad ? 1200 : 1600
        ) // Fixed width constraint on iPad to ensure corners are visible
        .frame(height: isIPad ? nil : 400)
        .frame(maxHeight: isIPad ? .infinity : 400) // Allow it to fill available space on iPad
        .blur(radius: isSchedulerExpanded || isPinnedExpanded || isWIPExpanded ? 3 : 0)
        .opacity(isSchedulerExpanded || isPinnedExpanded || isWIPExpanded ? 0.7 : 1.0)

                    // All Documents section - centered with proper margins for corner visibility
                    allDocumentsSectionView
                        .padding(.top, 40)
                        .padding(.horizontal, 20) // Proper padding on iPad to show corner radius 