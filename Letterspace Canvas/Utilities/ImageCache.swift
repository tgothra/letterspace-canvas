#if os(macOS)
import AppKit
typealias PlatformSpecificImage = NSImage
#elseif os(iOS)
import UIKit
typealias PlatformSpecificImage = UIImage
#endif

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, AnyObject>() // Store AnyObject
    private var preloadQueue = DispatchQueue(label: "com.letterspace.imagePreload", qos: .utility)
    #if os(macOS)
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    #endif
    
    private init() {
        // Configure cache limits
        cache.countLimit = 100 // Maximum number of images to keep in memory
        cache.totalCostLimit = 1024 * 1024 * 500 // 500 MB limit
        
        // Set up memory pressure monitoring
        #if os(macOS)
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical])
        memoryPressureSource?.setEventHandler { [weak self] in
            self?.handleMemoryWarning()
        }
        memoryPressureSource?.resume()
        #elseif os(iOS)
        // On iOS, NSCache responds to system memory pressure automatically.
        // We can also observe UIApplication.didReceiveMemoryWarningNotification if needed for more custom handling.
        NotificationCenter.default.addObserver(self, 
                                               selector: #selector(handleMemoryWarningIOS), 
                                               name: UIApplication.didReceiveMemoryWarningNotification, 
                                               object: nil)
        #endif
    }
    
    func image(for key: String) -> PlatformSpecificImage? {
        if let object = cache.object(forKey: key as NSString) {
            return object as? PlatformSpecificImage
        }
        return nil
    }
    
    func setImage(_ image: PlatformSpecificImage, for key: String) {
        let cost: Int
        #if os(macOS)
        cost = Int(image.size.width * image.size.height * 4) // NSImage
        #elseif os(iOS)
        // For UIImage, consider scale factor for more accurate cost
        cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        #endif
        cache.setObject(image as AnyObject, forKey: key as NSString, cost: cost)
    }
    
    func preloadImages(for document: Letterspace_CanvasDocument) {
        preloadQueue.async {
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let documentPath = documentsPath.appendingPathComponent(document.id)
            let imagesPath = documentPath.appendingPathComponent("Images")
            
            // Find all header image elements
            let headerImages = document.elements.filter { $0.type == .headerImage && !$0.content.isEmpty }
            
            for element in headerImages {
                let imageUrl = imagesPath.appendingPathComponent(element.content)
                
                // Skip if already cached
                if self.image(for: element.content) != nil { continue }
                
                // Load and cache image
                #if os(macOS)
                if let image = NSImage(contentsOf: imageUrl) {
                    DispatchQueue.main.async {
                        self.setImage(image, for: element.content)
                    }
                }
                #elseif os(iOS)
                if let image = UIImage(contentsOfFile: imageUrl.path) {
                    DispatchQueue.main.async {
                        self.setImage(image, for: element.content)
                    }
                }
                #endif
            }
        }
    }
    
    func removeImage(for key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
    
    #if os(macOS)
    private func handleMemoryWarning() {
        // Clear half of the cache when receiving memory warning
        cache.totalCostLimit /= 2
        cache.countLimit /= 2
        
        // Also clear some cached images if we're over the new limits
        let currentCount = cache.countLimit
        if currentCount > cache.countLimit {
            clearCache()
        }
        
        // Current NSCache behavior might already evict appropriately, 
        // but this provides more aggressive clearing if needed.
        // Consider just calling cache.removeAllObjects() on critical pressure.
        print("macOS Memory Warning: Halving cache limits.")
    }
    #elseif os(iOS)
    @objc private func handleMemoryWarningIOS() {
        print("iOS Memory Warning: Clearing entire image cache.")
        cache.removeAllObjects()
    }
    #endif
    
    deinit {
        #if os(macOS)
        memoryPressureSource?.cancel()
        #elseif os(iOS)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        #endif
    }
} 