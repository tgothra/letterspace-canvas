import Foundation

// Assuming Letterspace_CanvasDocument is defined elsewhere and accessible
// For example, in your Models directory.
// If it's not Codable or not defined, this won't compile until that's resolved.
// struct Letterspace_CanvasDocument: Codable { /* ... properties ... */ }

// Document Cache Manager - Singleton for document caching
class DocumentCacheManager {
    static let shared = DocumentCacheManager()
    
    private init() {}
    
    // Ensure Letterspace_CanvasDocument is defined and accessible here
    private var cache: [String: (document: Letterspace_CanvasDocument, timestamp: Date)] = [:]
    
    func getDocument(id: String) -> Letterspace_CanvasDocument? {
        // Check cache only if it's not empty to avoid unnecessary date calculations
        if let cachedItem = cache[id], !cache.isEmpty {
            // Cache for 5 seconds - adjust as needed
            if Date().timeIntervalSince(cachedItem.timestamp) < 5 {
                return cachedItem.document
            } else {
                // Remove stale item
                cache.removeValue(forKey: id)
                return nil
            }
        }
        return nil
    }
    
    func cacheDocument(id: String, document: Letterspace_CanvasDocument) {
        print("Caching document with ID: \(id)")
        cache[id] = (document, Date())
    }
    
    func clearCache() {
        print("Clearing document cache. Current count: \(cache.count)")
        cache = [:]
    }
    
    func removeDocument(id: String) {
        print("Removing document from cache with ID: \(id)")
        cache.removeValue(forKey: id)
    }
    
    // Optional: Method to get cache count for debugging
    func count() -> Int {
        return cache.count
    }
} 