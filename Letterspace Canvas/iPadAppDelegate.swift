import SwiftUI
import UIKit

// DocumentCacheManager should be imported if not globally available, or defined in a shared location.
// Assuming Letterspace_CanvasDocument is defined elsewhere.

class iPadAppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("iPadAppDelegate: application didFinishLaunchingWithOptions")
        
        // Preload haptic feedback generators early to avoid first-tap delays
        HapticFeedback.prepareAll()
        
        // Preload user profile asynchronously
        Task.detached(priority: .background) {
            _ = UserProfileManager.shared.userProfile
        }
        
        // Preload Smart Study components to eliminate first-time keyboard delay
        if UIDevice.current.userInterfaceIdiom == .phone {
            // Call dedicated preloading method
            SmartStudyView.preloadForIPhone()
            
            Task.detached(priority: .background) {
                print("🔄 Preloading Smart Study components for iPhone...")
                
                // Initialize UserLibraryService in background
                let _ = UserLibraryService()
                
                // Preload saved QAs data
                if let savedData = UserDefaults.standard.data(forKey: "savedSmartStudyQAs") {
                    let _ = try? JSONDecoder().decode([SmartStudyEntry].self, from: savedData)
                }
                
                // Initialize TokenUsageService
                let _ = TokenUsageService.shared
                
                // Preload any other Smart Study dependencies
                await MainActor.run {
                    print("✅ Smart Study components preloaded for iPhone")
                }
            }
        }
        
        // Preload modal views on iPhone to eliminate first-time delays
        if UIDevice.current.userInterfaceIdiom == .phone {
            // Delay slightly to avoid blocking app launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                Task.detached(priority: .utility) {
                    print("🔄 Preloading iPhone modal data...")
                    
                    // Preload UserDefaults data in background
                    _ = UserDefaults.standard.data(forKey: "SavedFolders")
                    _ = UserDefaults.standard.data(forKey: "FolderDocuments")
                    
                    print("✅ iPhone modal data preloaded")
                }
            }
        }
        
        // checkForTextSubsystemReset() // Removed: macOS-specific AppKit text system reset
        
        // Enable debug visualization for text views if the flag is set (adapt or remove)
        // if UserDefaults.standard.bool(forKey: "com.letterspace.enableDebugBorders") {
        //     enableTextViewDebugging() // Removed: macOS-specific NSTextView debugging
        // }
        
        // Refresh documents after app launch - with slightly longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshDocumentList()
        }
        
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        print("iPadAppDelegate: applicationDidBecomeActive")
        // Add a small delay to ensure the view hierarchy is fully loaded (may not be as critical as on macOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // self.safelyResetTrackingState() // Removed: macOS-specific NSView/NSTableView logic
            
            // Refresh document list when app becomes active
            self.refreshDocumentList()
        }
    }
    
    // Common helper method
    private func refreshDocumentList() {
        // Post notification to refresh document list
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        print("iPadAppDelegate triggered DocumentListDidUpdate notification")
        
        // Also clear any document cache to ensure fresh loading
        DocumentCacheManager.shared.clearCache()
    }
    
    // Scene manifest related methods
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("iPadAppDelegate: configurationForConnecting connectingSceneSession")
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        // If you don't have a SceneDelegate or don't need it for now, you can comment this out.
        // However, for multi-window support on iPad, it's usually needed.
        sceneConfig.delegateClass = SceneDelegate.self 
        return sceneConfig
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        print("iPadAppDelegate: didDiscardSceneSessions")
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
        print("SceneDelegate: scene willConnectTo session")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        print("SceneDelegate: sceneDidDisconnect")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        print("SceneDelegate: sceneDidBecomeActive")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        print("SceneDelegate: sceneWillResignActive")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        print("SceneDelegate: sceneWillEnterForeground")
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        print("SceneDelegate: sceneDidEnterBackground")
    }
} 