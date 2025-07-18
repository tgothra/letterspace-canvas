import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// Replace SettingsPopupContent with UserProfilePopupContent
struct UserProfilePopupContent: View {
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appearanceController: AppearanceController
    @Binding var activePopup: ActivePopup // Keep if needed for other logic
    @Binding var isPresented: Bool
    @ObservedObject var gradientManager: GradientWallpaperManager  // Changed from let to @ObservedObject
    @State private var userProfile = UserProfileManager.shared.userProfile
    @State private var isImagePickerPresented = false
    @State private var isImageCropperPresented = false
    #if os(macOS)
    @State private var selectedImageForCropper: NSImage? // Keep NSImage for macOS cropper
    #elseif os(iOS)
    @State private var selectedImageForCropper: UIImage? // Use UIImage for potential iOS cropper/display
    #endif
    @State private var isEditingProfile = false
    @State private var isHoveringClose = false // State for close button hover
    
    var body: some View {
        ZStack {
            // Main profile content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                        Text("User Profile")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.primary)
                    
                    Spacer()
                    
                    Button(action: {
                            isPresented = false
                    }) {
                        // Updated close button style
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(isHoveringClose ? Color.red : Color.gray.opacity(0.5)) // Changed hover to solid red
                            )
                    }
                    .buttonStyle(.plain) // Keep plain to remove default button styling
                    .onHover { hovering in
                        isHoveringClose = hovering
                    }
                }
                .padding(.bottom, 8)
                
                // User profile content
                VStack(alignment: .center, spacing: 20) {
                    // Profile image
                    ZStack(alignment: .bottomTrailing) {
                        if let profilePImage = UserProfileManager.shared.getProfileImage() { // Returns PlatformSpecificImage
                            PlatformImageView(platformImage: profilePImage) // Use PlatformImageView
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(theme.secondary.opacity(0.2), lineWidth: 1)
                                )
                        } else {
                            // Initials avatar if no image
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(userProfile.initials)
                                        .font(.system(size: 36, weight: .medium))
                                        .foregroundStyle(Color.blue)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(theme.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        
                        // Edit button
                        Button(action: {
                            isImagePickerPresented = true
                        }) {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "camera.fill")
                    .font(.system(size: 14))
                                        .foregroundStyle(.white)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    
                    // Rest of the user profile content remains the same
                    // User details
                    if isEditingProfile {
                        // Edit mode
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("First Name")
                                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondary)
                
                                TextField("First Name", text: $userProfile.firstName)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black.opacity(0.3), lineWidth: 1)
                                    )
                                    .textFieldStyle(.plain)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Last Name")
                    .font(.system(size: 12))
                                    .foregroundStyle(theme.secondary)
                                
                                TextField("Last Name", text: $userProfile.lastName)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black.opacity(0.3), lineWidth: 1)
                                    )
                                    .textFieldStyle(.plain)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.secondary)
                                
                                TextField("Email", text: $userProfile.email)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black.opacity(0.3), lineWidth: 1)
                                    )
                                    .textFieldStyle(.plain)
                            }
                            
                            HStack {
                                Button("Cancel") {
                                    // Reset to saved values
                                    userProfile = UserProfileManager.shared.userProfile
                                    isEditingProfile = false
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(theme.secondary)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(theme.secondary.opacity(0.1))
                                .cornerRadius(8)
                                
                                Spacer()
                                
                                Button("Save") {
                                    // Save profile changes
                                    UserProfileManager.shared.userProfile = userProfile
                                    isEditingProfile = false
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(theme.accent)
                                .cornerRadius(8)
                            }
                        }
                    } else {
                        // View mode
                        VStack(spacing: 10) {
                            Text(userProfile.fullName)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(theme.primary)
                            
                            if !userProfile.email.isEmpty {
                                Text(userProfile.email)
                                    .font(.system(size: 14))
                                    .foregroundStyle(theme.secondary)
                            }
                            
                            Button("Edit Profile") {
                                isEditingProfile = true
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.accent)
                            .padding(.top, 8)
                        }
                    }
                    
                    // REMOVE the Divider and the iCloud Backup section
                    /*
                    Divider()
                        .padding(.vertical, 8)
                    
                    // iCloud Backup (Coming Soon)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("iCloud Backup")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(theme.primary)
                                
                                Text("Coming Soon")
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.secondary)
                            }
            
                            Spacer()
                            
                            Toggle("", isOn: .constant(false))
                                .disabled(true)
                        }
                        
                        Text("Enable iCloud backup to safely store your documents and settings in the cloud.")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    */
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Dark Mode Toggle (iPhone only)
                    #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: appearanceController.selectedScheme.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(appearanceController.selectedScheme == .dark ? .yellow : 
                                                   appearanceController.selectedScheme == .light ? .orange : .purple)
                                    .frame(width: 20)
                                
                                Text("Color Scheme")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(theme.primary)
                                
                                Spacer()
                                
                                Button(action: {
                                    // Cycle through the color scheme options
                                    let allCases = AppColorScheme.allCases
                                    if let currentIndex = allCases.firstIndex(of: appearanceController.selectedScheme) {
                                        let nextIndex = (currentIndex + 1) % allCases.count
                                        appearanceController.selectedScheme = allCases[nextIndex]
                                    }
                                }) {
                                    Text(appearanceController.selectedScheme.rawValue)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(theme.accent)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(theme.accent.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Text("Toggle between light and dark appearance modes.")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                        
                        Divider()
                            .padding(.vertical, 8)
                    }
                    #endif
                    
                    // Gradient Wallpaper Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Wallpaper")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.primary)
                        
                        // Preview Cards Section
                        HStack(spacing: 20) {
                                Spacer()
                            
                            // Light Mode Preview Card
                            VStack(spacing: 8) {
                                Text("Light Mode Preview")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.secondary)
                                
                                ZStack {
                                    // Full gradient background
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(gradientManager.gradientPresets[gradientManager.selectedLightGradientIndex].lightGradient.asPreviewGradient())
                                        .frame(width: 100, height: 130)
                                    
                                    // Glassmorphism card overlay
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.white.opacity(0.2),
                                                            Color.white.opacity(0.05)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.white.opacity(0.3),
                                                            Color.white.opacity(0.1)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 0.5
                                                )
                                        )
                                        .frame(width: 75, height: 50)
                                }
                                .id("light-preview-\(gradientManager.selectedLightGradientIndex)")
                                .animation(.easeInOut(duration: 0.3), value: gradientManager.selectedLightGradientIndex)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme.secondary.opacity(0.2), lineWidth: 1)
                                        .frame(width: 100, height: 130)
                                )
                            }
                            
                            // Dark Mode Preview Card
                            VStack(spacing: 8) {
                                Text("Dark Mode Preview")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.secondary)
                                
                                ZStack {
                                    // Full gradient background
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(gradientManager.gradientPresets[gradientManager.selectedDarkGradientIndex].darkGradient.asPreviewGradient())
                                        .frame(width: 100, height: 130)
                                    
                                    // Glassmorphism card overlay (darker for dark mode)
                            RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.black.opacity(0.2),
                                                            Color.black.opacity(0.05)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.white.opacity(0.2),
                                                            Color.white.opacity(0.05)
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 0.5
                                                )
                                        )
                                        .frame(width: 75, height: 50)
                                }
                                .id("dark-preview-\(gradientManager.selectedDarkGradientIndex)")
                                .animation(.easeInOut(duration: 0.3), value: gradientManager.selectedDarkGradientIndex)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme.secondary.opacity(0.2), lineWidth: 1)
                                        .frame(width: 100, height: 130)
                                )
                            }
                            
                            Spacer()
                        }
                        
                        // Light Mode Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.yellow)
                                Text("Light Mode")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(theme.primary)
                                Spacer()
                                Text("\(gradientManager.selectedLightGradientIndex + 1) of \(gradientManager.gradientPresets.count)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.secondary)
                            }
                            
                            // Light mode gradient tiles
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(gradientManager.gradientPresets.enumerated()), id: \.offset) { index, preset in
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                        gradientManager.setGradient(
                                            lightIndex: index,
                                            darkIndex: gradientManager.selectedDarkGradientIndex
                                        )
                                    }
                                        }) {
                                            VStack(spacing: 4) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(preset.lightGradient.asTileGradient())
                                                        .frame(width: 70, height: 45)
                                                    
                                                    if gradientManager.selectedLightGradientIndex == index {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.green, lineWidth: 3)
                                                            .frame(width: 70, height: 45)
                                                        
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 10, weight: .bold))
                                                            .foregroundColor(.green)
                                                            .background(
                                                                Circle()
                                                                    .fill(.white)
                                                                    .frame(width: 14, height: 14)
                                                            )
                                                            .offset(x: 20, y: -10)
                                                    } else {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(theme.secondary.opacity(0.3), lineWidth: 1)
                                                            .frame(width: 70, height: 45)
                                                    }
                                                }
                                                
                                                Text(preset.name)
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundStyle(theme.secondary)
                                                    .multilineTextAlignment(.center)
                                                    .frame(width: 70)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        // Dark Mode Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.purple)
                                Text("Dark Mode")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(theme.primary)
                                Spacer()
                                Text("\(gradientManager.selectedDarkGradientIndex + 1) of \(gradientManager.gradientPresets.count)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.secondary)
                            }
                            
                            // Dark mode gradient tiles
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(gradientManager.gradientPresets.enumerated()), id: \.offset) { index, preset in
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                        gradientManager.setGradient(
                                            lightIndex: gradientManager.selectedLightGradientIndex,
                                            darkIndex: index
                                        )
                                    }
                                        }) {
                                            VStack(spacing: 4) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(preset.darkGradient.asTileGradient())
                                                        .frame(width: 70, height: 45)
                                                    
                                                    if gradientManager.selectedDarkGradientIndex == index {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.green, lineWidth: 3)
                                                            .frame(width: 70, height: 45)
                                                        
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 10, weight: .bold))
                                                            .foregroundColor(.green)
                                                            .background(
                                                                Circle()
                                                                    .fill(.white)
                                                                    .frame(width: 14, height: 14)
                                                            )
                                                            .offset(x: 20, y: -10)
                                                    } else {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(theme.secondary.opacity(0.3), lineWidth: 1)
                                                            .frame(width: 70, height: 45)
                                                    }
                                                }
                                                
                                                Text(preset.name)
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundStyle(theme.secondary)
                                                    .multilineTextAlignment(.center)
                                                    .frame(width: 70)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        // Info text
                        Text("Choose beautiful gradient backgrounds that work with the glassmorphism effects throughout the app.")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.secondary.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                                }
                .padding(.horizontal, 8)
                }
                .padding(.bottom, 20)  // Add bottom padding for scroll content
            }
            .frame(width: {
            #if os(iOS)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            return isPhone ? 340 : 500  // Smaller for iPhone, larger for iPad
            #else
            return 400 // macOS default
            #endif
        }(), height: {
            #if os(iOS)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            return isPhone ? 600 : 700  // Constrain height for iPhone
            #else
            return 700 // macOS default
            #endif
        }())  // Responsive size for different devices
        .padding(20)  // Increased padding for modal
        .background(
            Group {
                #if os(macOS)
                Color(NSColor.windowBackgroundColor)
                #elseif os(iOS)
                Color(UIColor.systemBackground)
                #endif
            }
        )
        .cornerRadius(12)
        }
        .overlay {
            // Image cropper overlay
            if isImageCropperPresented, let imageToEdit = selectedImageForCropper {
                ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                ImageCropperView(
                    isPresented: $isImageCropperPresented,
                    image: imageToEdit,
                    onSave: { editedImage in
                        UserProfileManager.shared.saveProfileImage(editedImage)
                        userProfile = UserProfileManager.shared.userProfile
                    }
                )
                }
            }
        }
        .fileImporter(
            isPresented: $isImagePickerPresented,
            allowedContentTypes: [UTType.image],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedFileURL = try result.get().first else { return }
                
                if selectedFileURL.startAccessingSecurityScopedResource() {
                    defer { selectedFileURL.stopAccessingSecurityScopedResource() }
                    
                    #if os(macOS)
                    if let image = NSImage(contentsOf: selectedFileURL) {
                        selectedImageForCropper = image
                        isImageCropperPresented = true
                    }
                    #elseif os(iOS)
                    if let image = UIImage(contentsOfFile: selectedFileURL.path) {
                        selectedImageForCropper = image
                        isImageCropperPresented = true
                    }
                    #endif
                }
            } catch {
                print("Error selecting image: \(error)")
            }
        }
    }
}
