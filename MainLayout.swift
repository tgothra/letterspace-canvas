                        FloatingSidebarButton(
                            icon: "rectangle.3.group",
                            title: "Dashboard",
                            action: {
                                sidebarMode = .allDocuments
                                isRightSidebarVisible = false
                                viewMode = .normal
                            }
                        )
                        
                        FloatingSidebarButton(
                            icon: "magnifyingglass",
                            title: "Search Documents",
                            action: {
                                searchFieldFocused = true
                            }
                        )
                        
                        FloatingSidebarButton(
                            icon: "square.and.pencil",
                            title: "Create New Document",
                            action: {
                                let docId = UUID().uuidString
                                var d = Letterspace_CanvasDocument(
                                    title: "Untitled", 
                                    subtitle: "", 
                                    elements: [DocumentElement(type: .textBlock, content: "", placeholder: "Start typing...")], 
                                    id: docId, 
                                    markers: [], 
                                    series: nil, 
                                    variations: [],
                                    isVariation: false, 
                                    parentVariationId: nil, 
                                    createdAt: Date(), 
                                    modifiedAt: Date(), 
                                    tags: nil, 
                                    isHeaderExpanded: false, 
                                    isSubtitleVisible: true, 
                                    links: []
                                )
                                d.save()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    document = d
                                    sidebarMode = .details
                                    #if os(macOS)
                                    isRightSidebarVisible = true  // Only auto-show on macOS
                                    #endif
                                    activePopup = .none
                                }
                            }
                        )
                        
                        FloatingSidebarButton(
                            icon: "folder",
                            title: "Folders",
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showFoldersModal = true
                                }
                            }
                        )
                        
                        FloatingSidebarButton(
                            icon: "sparkles",
                            title: "Smart Study",
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSmartStudyModal = true
                                }
                            }
                        )
                        
                        FloatingSidebarButton(
                            icon: "book.closed",
                            title: "Bible Reader",
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showBibleReaderModal = true
                                }
                            }
                        )
                        
                        FloatingSidebarButton(
                            icon: isDarkMode ? "sun.max.fill" : "moon.fill",
                            title: "Toggle Dark Mode",
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    transitionOpacity = 0
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                        isDarkMode.toggle()
                                        UserDefaults.standard.set(isDarkMode, forKey: "prefersDarkMode")
                                        UserDefaults.standard.synchronize()
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            transitionOpacity = 1
                                        }
                                    }
                                }
                            }
                        )
                        
                        FloatingSidebarButton(
                            icon: "trash",
                            title: "Recently Deleted",
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showRecentlyDeletedModal = true
                                }
                            }
                        )
                        
                        Divider()
                            .padding(.horizontal, 32)
                            .padding(.vertical, 4)
                        
                        FloatingSidebarButton(
                            icon: "person.crop.circle.fill",
                            title: "User Profile",
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showUserProfileModal = true
                                }
                            }
                        ) 

                        // Conditional background: solid white for default gradients, glassmorphism for custom gradients
                        ZStack {
                            let useGlassmorphism = colorScheme == .dark ? 
                                gradientManager.selectedDarkGradientIndex != 0 :
                                gradientManager.selectedLightGradientIndex != 0
                            
                            if useGlassmorphism {
                                // Glassmorphism effect for custom gradients
                                Rectangle()
                                    .fill(.ultraThinMaterial)
                                
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        theme.background.opacity(0.3),
                                        theme.background.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                // Solid background for default gradients
                                Rectangle()
                                    .fill(colorScheme == .light ? Color.white : Color(red: 0.11, green: 0.11, blue: 0.12))
                            }
                        }            ZStack {                let useGlassmorphism = colorScheme == .dark ?                     gradientManager.selectedDarkGradientIndex != 0 :                    gradientManager.selectedLightGradientIndex != 0                                if useGlassmorphism {                    // Glassmorphism effect for custom gradients                    Rectangle()                        .fill(.ultraThinMaterial)                                        LinearGradient(                        gradient: Gradient(colors: [                            theme.background.opacity(0.3),                            theme.background.opacity(0.1)                        ]),                        startPoint: .topLeading,                        endPoint: .bottomTrailing                    )                } else {                    // Solid background for default gradients                    Rectangle()                        .fill(colorScheme == .light ? Color.white : Color(red: 0.11, green: 0.11, blue: 0.12))                }            }            ZStack {                let useGlassmorphism = colorScheme == .dark ?                     gradientManager.selectedDarkGradientIndex != 0 :                    gradientManager.selectedLightGradientIndex != 0                                if useGlassmorphism {                    // Glassmorphism effect for custom gradients                    Rectangle()                        .fill(.ultraThinMaterial)                                        LinearGradient(                        gradient: Gradient(colors: [                            theme.background.opacity(0.3),                            theme.background.opacity(0.1)                        ]),                        startPoint: .topLeading,                        endPoint: .bottomTrailing                    )                } else {                    // Solid background for default gradients                    Rectangle()                        .fill(colorScheme == .light ? Color.white : Color(red: 0.11, green: 0.11, blue: 0.12))                }            }