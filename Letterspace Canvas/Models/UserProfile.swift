import SwiftUI
import Foundation

struct UserProfile: Codable {
    var firstName: String
    var lastName: String
    var email: String
    var profileImageData: Data?
    var iCloudBackupEnabled: Bool
    
    var initials: String {
        let firstInitial = firstName.first.map(String.init) ?? ""
        let lastInitial = lastName.first.map(String.init) ?? ""
        return firstInitial + lastInitial
    }
    
    var fullName: String {
        if firstName.isEmpty && lastName.isEmpty {
            return "User"
        } else if firstName.isEmpty {
            return lastName
        } else if lastName.isEmpty {
            return firstName
        } else {
            return "\(firstName) \(lastName)"
        }
    }
    
    init(firstName: String = "", lastName: String = "", email: String = "", profileImageData: Data? = nil, iCloudBackupEnabled: Bool = false) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.profileImageData = profileImageData
        self.iCloudBackupEnabled = iCloudBackupEnabled
    }
}

class UserProfileManager {
    static let shared = UserProfileManager()
    
    private init() {
        // Set up notification for iCloud account changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudAccountDidChange),
            name: NSNotification.Name.NSUbiquityIdentityDidChange,
            object: nil
        )
        
        // Check iCloud availability on initialization
        checkiCloudAvailability()
    }
    
    // Track iCloud availability
    private var isiCloudAvailable = false
    
    // MARK: - iCloud Integration
    
    @objc private func iCloudAccountDidChange(_ notification: Notification) {
        checkiCloudAvailability()
        
        // If iCloud became available, sync local data to iCloud
        if isiCloudAvailable {
            syncLocalToiCloud()
        }
    }
    
    private func checkiCloudAvailability() {
        // Check for iCloud availability in background to avoid UI freezes
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            // Try to get the iCloud container URL
            if let _ = self.getiCloudContainerURL() {
                DispatchQueue.main.async {
                    self.isiCloudAvailable = true
                    print("☁️ iCloud is available")
                }
            } else {
                DispatchQueue.main.async {
                    self.isiCloudAvailable = false
                    print("📱 iCloud is not available, using local storage only")
                }
            }
        }
    }
    
    private func syncLocalToiCloud() {
        // Get local profile
        let localProfile = loadLocalProfile()
        
        // Save to iCloud if it has any data
        if !localProfile.firstName.isEmpty || !localProfile.lastName.isEmpty || localProfile.profileImageData != nil {
            saveiCloudProfile(localProfile)
        }
    }
    
    // MARK: - URL Helpers
    
    private func getiCloudContainerURL() -> URL? {
        do {
            // Try to get the iCloud container URL with a timeout
            let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)
            
            if let containerURL = containerURL {
                let documentsURL = containerURL.appendingPathComponent("Documents")
                
                // Create Documents directory if it doesn't exist
                if !FileManager.default.fileExists(atPath: documentsURL.path) {
                    try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
                }
                
                return documentsURL
            }
            return nil
        } catch {
            print("❌ Error accessing iCloud container: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func getLocalDocumentsURL() -> URL? {
        do {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let appDirectory = documentsURL.appendingPathComponent("Letterspace Canvas")
            
            if !FileManager.default.fileExists(atPath: appDirectory.path) {
                try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            return appDirectory
        } catch {
            print("❌ Error creating local documents directory: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func getiCloudProfileURL() -> URL? {
        guard let documentsURL = getiCloudContainerURL() else { return nil }
        return documentsURL.appendingPathComponent("user_profile.json")
    }
    
    private func getLocalProfileURL() -> URL? {
        guard let appDirectory = getLocalDocumentsURL() else { return nil }
        return appDirectory.appendingPathComponent("user_profile.json")
    }
    
    // MARK: - UserDefaults Helpers
    
    private func saveToUserDefaults(_ profile: UserProfile) {
        UserDefaults.standard.set(profile.firstName, forKey: "UserProfileFirstName")
        UserDefaults.standard.set(profile.lastName, forKey: "UserProfileLastName")
        UserDefaults.standard.set(profile.email, forKey: "UserProfileEmail")
        
        if let imageData = profile.profileImageData {
            UserDefaults.standard.set(imageData, forKey: "UserProfileImage")
        }
        
        UserDefaults.standard.synchronize()
    }
    
    private func loadFromUserDefaults() -> UserProfile? {
        guard let firstName = UserDefaults.standard.string(forKey: "UserProfileFirstName"),
              let lastName = UserDefaults.standard.string(forKey: "UserProfileLastName"),
              let email = UserDefaults.standard.string(forKey: "UserProfileEmail") else {
            return nil
        }
        
        let imageData = UserDefaults.standard.data(forKey: "UserProfileImage")
        
        return UserProfile(
            firstName: firstName,
            lastName: lastName,
            email: email,
            profileImageData: imageData,
            iCloudBackupEnabled: isiCloudAvailable
        )
    }
    
    // MARK: - Profile Loading & Saving
    
    private func loadiCloudProfile() -> UserProfile? {
        guard let fileURL = getiCloudProfileURL(),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let profile = try JSONDecoder().decode(UserProfile.self, from: data)
            print("☁️ Loaded profile from iCloud")
            return profile
        } catch {
            print("⚠️ Error loading profile from iCloud: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func loadLocalProfile() -> UserProfile {
        // First check UserDefaults for faster access
        if let profile = loadFromUserDefaults() {
            return profile
        }
        
        // Then try local file
        guard let fileURL = getLocalProfileURL(),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return UserProfile()
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let profile = try JSONDecoder().decode(UserProfile.self, from: data)
            print("📱 Loaded profile from local storage")
            return profile
        } catch {
            print("⚠️ Error loading profile from local storage: \(error.localizedDescription)")
            return UserProfile()
        }
    }
    
    private func saveiCloudProfile(_ profile: UserProfile) {
        guard let fileURL = getiCloudProfileURL() else {
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(profile)
            
            // Use a coordinator for proper iCloud file coordination
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinationError: NSError?
            
            coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinationError) { (url) in
                do {
                    try data.write(to: url, options: .atomic)
                    print("☁️ Saved profile to iCloud")
                } catch {
                    print("❌ Error writing profile to iCloud: \(error.localizedDescription)")
                }
            }
            
            if let error = coordinationError {
                print("❌ Coordination error saving to iCloud: \(error.localizedDescription)")
            }
        } catch {
            print("❌ Error encoding profile for iCloud: \(error.localizedDescription)")
        }
    }
    
    private func saveLocalProfile(_ profile: UserProfile) {
        // Save to UserDefaults for immediate access
        saveToUserDefaults(profile)
        
        // Save to local file as backup
        guard let fileURL = getLocalProfileURL() else {
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(profile)
            try data.write(to: fileURL, options: .atomic)
            print("📱 Saved profile to local storage")
        } catch {
            print("❌ Error saving profile to local storage: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public API
    
    var userProfile: UserProfile {
        get {
            // Try to get from iCloud if available
            if isiCloudAvailable, let iCloudProfile = loadiCloudProfile() {
                // Update local copies
                saveLocalProfile(iCloudProfile)
                return iCloudProfile
            }
            
            // Fall back to local storage
            return loadLocalProfile()
        }
        set {
            // Save locally first (fast and reliable)
            saveLocalProfile(newValue)
            
            // Then save to iCloud asynchronously if available
            if isiCloudAvailable {
                DispatchQueue.global(qos: .background).async { [weak self] in
                    self?.saveiCloudProfile(newValue)
                }
            }
        }
    }
    
    #if os(macOS)
    func saveProfileImage(_ image: NSImage) {
        // Ensure we process the image properly before saving
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            print("❌ Failed to convert profile image to JPEG")
            return
        }
        
        // Update the profile
        var profile = userProfile
        profile.profileImageData = jpegData
        
        // Save using the setter which handles both local and iCloud saving
        userProfile = profile
        
        // Post notification that profile image has changed
        DispatchQueue.main.async {
        NotificationCenter.default.post(name: NSNotification.Name("ProfileImageDidChange"), object: nil)
            print("✅ Profile image saved successfully")
        }
    }
    #elseif os(iOS)
    func saveProfileImage(_ image: UIImage) {
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
            print("❌ Failed to convert profile image to JPEG")
            return
        }
        
        // Update the profile
        var profile = userProfile
        profile.profileImageData = jpegData
        
        // Save using the setter which handles both local and iCloud saving
        userProfile = profile
        
        // Post notification that profile image has changed
        DispatchQueue.main.async {
        NotificationCenter.default.post(name: NSNotification.Name("ProfileImageDidChange"), object: nil)
            print("✅ Profile image saved successfully")
        }
    }
    #endif
    
    #if os(macOS)
    func getProfileImage() -> NSImage? {
        // Try UserDefaults first (fastest)
        if let imageData = UserDefaults.standard.data(forKey: "UserProfileImage"),
           let image = NSImage(data: imageData) {
            return image
        }
        
        // Fall back to profile data
        guard let imageData = userProfile.profileImageData else {
            return nil
        }
        return NSImage(data: imageData)
    }
    #elseif os(iOS)
    func getProfileImage() -> UIImage? {
        // Try UserDefaults first (fastest)
        if let imageData = UserDefaults.standard.data(forKey: "UserProfileImage"),
           let image = UIImage(data: imageData) {
            return image
        }
        
        // Fall back to profile data
        guard let imageData = userProfile.profileImageData else {
            return nil
        }
        return UIImage(data: imageData)
    }
    #endif
} 