#if os(iOS)
import Foundation
import UIKit
import SwiftUI

// MARK: - iOS 26 Enhanced RTF Service with Modern AttributedString
@available(iOS 15.0, *) // Updated to use AttributedString from iOS 15+
class iOS26RTFService: NSObject, ObservableObject {
    static let shared = iOS26RTFService()
    
    @Published var isProcessing = false
    @Published var lastProcessingTime: TimeInterval = 0
    
    // Modern AttributedString processor
    private let modernProcessor = iOS26RTFProcessor()
    
    private override init() {
        super.init()
        print("🚀 Modern AttributedString RTF Service initialized")
    }
    
    // MARK: - iOS 26 Enhanced RTF Creation
    func createEnhancedRTF(from attributedString: NSAttributedString) -> Data? {
        let startTime = CFAbsoluteTimeGetCurrent()
        isProcessing = true
        
        defer {
            isProcessing = false
            lastProcessingTime = CFAbsoluteTimeGetCurrent() - startTime
            print("⚡ iOS 26 RTF creation completed in \(String(format: "%.3f", lastProcessingTime))s")
        }
        
        do {
            // iOS 26 Enhancement: Use enhanced document attributes
            let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
                .documentType: NSAttributedString.DocumentType.rtfd,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            let range = NSRange(location: 0, length: attributedString.length)
            
            // iOS 26 Enhancement: Use enhanced RTFD creation with better attribute preservation
            let rtfData = try attributedString.data(
                from: range,
                documentAttributes: documentAttributes
            )
            
            // iOS 26 Enhancement: Post-process for better compatibility
            return modernProcessor.optimizeRTFData(rtfData)
            
        } catch {
            print("❌ iOS 26 RTF creation error: \(error)")
            
            // Fallback to legacy RTF if RTFD fails
            do {
                let legacyAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
                    .documentType: NSAttributedString.DocumentType.rtf,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ]
                
                let range = NSRange(location: 0, length: attributedString.length)
                let fallbackData = try attributedString.data(
                    from: range,
                    documentAttributes: legacyAttributes
                )
                
                print("🔄 iOS 26: Fallback to legacy RTF successful")
                return fallbackData
                
            } catch {
                print("❌ iOS 26 RTF fallback error: \(error)")
                return nil
            }
        }
    }
    
    // MARK: - iOS 26 Enhanced RTF Reading
    func readEnhancedRTF(from data: Data) -> NSAttributedString? {
        let startTime = CFAbsoluteTimeGetCurrent()
        isProcessing = true
        
        defer {
            isProcessing = false
            lastProcessingTime = CFAbsoluteTimeGetCurrent() - startTime
            print("⚡ iOS 26 RTF reading completed in \(String(format: "%.3f", lastProcessingTime))s")
        }
        
        // iOS 26 Enhancement: Try enhanced RTFD reading first
        if let attributedString = readRTFD(from: data) {
            return modernProcessor.enhanceAttributedString(attributedString)
        }
        
        // Fallback to RTF
        if let attributedString = readRTF(from: data) {
            return modernProcessor.enhanceAttributedString(attributedString)
        }
        
        // Last resort: NSKeyedArchiver (legacy compatibility)
        if let attributedString = readArchivedAttributedString(from: data) {
            return modernProcessor.enhanceAttributedString(attributedString)
        }
        
        print("❌ iOS 26: Failed to read RTF data with all methods")
        return nil
    }
    
    private func readRTFD(from data: Data) -> NSAttributedString? {
        do {
            // iOS 26 Enhancement: Enhanced reading options
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.rtfd,
                .characterEncoding: String.Encoding.utf8.rawValue,
                // iOS 26 Enhancement: Better error handling
                .defaultAttributes: [:]
            ]
            
            let attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            print("✅ iOS 26: Successfully read RTFD - \(attributedString.length) characters")
            return attributedString
            
        } catch {
            print("⚠️ iOS 26: RTFD reading failed: \(error)")
            return nil
        }
    }
    
    private func readRTF(from data: Data) -> NSAttributedString? {
        do {
            // iOS 26 Enhancement: Enhanced RTF reading
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.rtf,
                .characterEncoding: String.Encoding.utf8.rawValue,
                // iOS 26 Enhancement: Better fallback handling
                .defaultAttributes: [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16),
                    NSAttributedString.Key.foregroundColor: UIColor.label
                ]
            ]
            
            let attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            print("✅ iOS 26: Successfully read RTF - \(attributedString.length) characters")
            return attributedString
            
        } catch {
            print("⚠️ iOS 26: RTF reading failed: \(error)")
            return nil
        }
    }
    
    private func readArchivedAttributedString(from data: Data) -> NSAttributedString? {
        do {
            // iOS 26 Enhancement: Secure archived reading
            let attributedString = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSAttributedString.self,
                from: data
            )
            
            if let attributedString = attributedString {
                print("✅ iOS 26: Successfully read archived string - \(attributedString.length) characters")
                return attributedString
            }
            
        } catch {
            print("⚠️ iOS 26: Archived string reading failed: \(error)")
        }
        
        return nil
    }
    
    // MARK: - iOS 26 Format Conversion
    func convertToModernFormat(_ documentElement: DocumentElement) -> DocumentElement {
        guard let rtfData = documentElement.rtfData,
              let modernAttributedString = readEnhancedRTF(from: rtfData) else {
            return documentElement
        }
        
        var modernElement = documentElement
        
        // iOS 26 Enhancement: Update with modern RTF data
        if let modernRTFData = createEnhancedRTF(from: modernAttributedString) {
            modernElement.rtfData = modernRTFData
            modernElement.content = modernAttributedString.string
            
            print("🔄 iOS 26: Converted document element to modern RTF format")
        }
        
        return modernElement
    }
    
    // MARK: - iOS 26 Batch Processing
    func batchConvertDocuments(_ documents: [DocumentElement]) async -> [DocumentElement] {
        return await withTaskGroup(of: DocumentElement.self) { group in
            for document in documents {
                group.addTask { [weak self] in
                    return self?.convertToModernFormat(document) ?? document
                }
            }
            
            var convertedDocuments: [DocumentElement] = []
            for await convertedDocument in group {
                convertedDocuments.append(convertedDocument)
            }
            
            print("🔄 iOS 26: Batch converted \(convertedDocuments.count) documents")
            return convertedDocuments.sorted { $0.id.uuidString < $1.id.uuidString }
        }
    }
    
    // MARK: - iOS 26 Performance Monitoring
    func getPerformanceMetrics() -> RTFPerformanceMetrics {
        return RTFPerformanceMetrics(
            lastProcessingTime: lastProcessingTime,
            isProcessing: isProcessing,
            enhancedFeaturesEnabled: true,
            version: "iOS 26 Enhanced"
        )
    }
}

// MARK: - iOS 26 RTF Processor
@available(iOS 26.0, *)
private class iOS26RTFProcessor {
    
    func optimizeRTFData(_ data: Data) -> Data {
        // iOS 26 Enhancement: Optimize RTF data for better performance and compatibility
        
        // Convert to string for processing
        guard let rtfString = String(data: data, encoding: .utf8) else {
            return data
        }
        
        var optimizedString = rtfString
        
        // iOS 26 Enhancement: Optimize font table
        optimizedString = optimizeFontTable(optimizedString)
        
        // iOS 26 Enhancement: Optimize color table
        optimizedString = optimizeColorTable(optimizedString)
        
        // iOS 26 Enhancement: Remove redundant formatting
        optimizedString = removeRedundantFormatting(optimizedString)
        
        return optimizedString.data(using: .utf8) ?? data
    }
    
    func enhanceAttributedString(_ attributedString: NSAttributedString) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        
        // iOS 26 Enhancement: Ensure proper font fallbacks
        ensureFontFallbacks(mutableString)
        
        // iOS 26 Enhancement: Optimize paragraph styles
        optimizeParagraphStyles(mutableString)
        
        // iOS 26 Enhancement: Enhance link attributes
        enhanceLinkAttributes(mutableString)
        
        return mutableString
    }
    
    private func optimizeFontTable(_ rtfString: String) -> String {
        // iOS 26 Enhancement: Optimize font references for better compatibility
        var optimized = rtfString
        
        // Replace deprecated font names with modern equivalents
        let fontReplacements = [
            "Helvetica": "HelveticaNeue",
            "Times": "TimesNewRomanPSMT",
            "Courier": "CourierNewPSMT"
        ]
        
        for (old, new) in fontReplacements {
            optimized = optimized.replacingOccurrences(of: old, with: new)
        }
        
        return optimized
    }
    
    private func optimizeColorTable(_ rtfString: String) -> String {
        // iOS 26 Enhancement: Ensure color table compatibility
        var optimized = rtfString
        
        // Ensure proper color definitions
        if !optimized.contains("\\colortbl;") {
            // Add basic color table if missing
            let colorTable = "\\colortbl;\\red0\\green0\\blue0;\\red255\\green255\\blue255;"
            optimized = optimized.replacingOccurrences(of: "\\rtf1", with: "\\rtf1" + colorTable)
        }
        
        return optimized
    }
    
    private func removeRedundantFormatting(_ rtfString: String) -> String {
        // iOS 26 Enhancement: Remove redundant RTF commands
        var optimized = rtfString
        
        // Remove redundant font resets
        optimized = optimized.replacingOccurrences(
            of: "\\f0\\f0",
            with: "\\f0",
            options: .regularExpression
        )
        
        // Remove redundant paragraph resets
        optimized = optimized.replacingOccurrences(
            of: "\\par\\par\\par",
            with: "\\par\\par",
            options: .regularExpression
        )
        
        return optimized
    }
    
    private func ensureFontFallbacks(_ attributedString: NSMutableAttributedString) {
        let range = NSRange(location: 0, length: attributedString.length)
        
        attributedString.enumerateAttribute(.font, in: range) { value, range, _ in
            guard let font = value as? UIFont else { return }
            
            // iOS 26 Enhancement: Ensure modern font fallbacks
            let descriptor = font.fontDescriptor
            if descriptor.fontAttributes[.family] as? String == "Helvetica" {
                let newFont = UIFont(name: "HelveticaNeue", size: font.pointSize) ?? font
                attributedString.addAttribute(.font, value: newFont, range: range)
            }
        }
    }
    
    private func optimizeParagraphStyles(_ attributedString: NSMutableAttributedString) {
        let range = NSRange(location: 0, length: attributedString.length)
        
        attributedString.enumerateAttribute(.paragraphStyle, in: range) { value, range, _ in
            guard let paragraphStyle = value as? NSParagraphStyle else { return }
            
            // iOS 26 Enhancement: Optimize paragraph style properties
            let mutableParagraphStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
            
            // Ensure reasonable line spacing
            if mutableParagraphStyle.lineSpacing == 0 {
                mutableParagraphStyle.lineSpacing = 1.2
            }
            
            attributedString.addAttribute(.paragraphStyle, value: mutableParagraphStyle, range: range)
        }
    }
    
    private func enhanceLinkAttributes(_ attributedString: NSMutableAttributedString) {
        let range = NSRange(location: 0, length: attributedString.length)
        
        attributedString.enumerateAttribute(.link, in: range) { value, range, _ in
            guard value != nil else { return }
            
            // iOS 26 Enhancement: Ensure links have proper visual styling
            if attributedString.attribute(.foregroundColor, at: range.location, effectiveRange: nil) == nil {
                attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
            }
            
            if attributedString.attribute(.underlineStyle, at: range.location, effectiveRange: nil) == nil {
                attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
    }
}

// MARK: - Supporting Types
struct RTFPerformanceMetrics {
    let lastProcessingTime: TimeInterval
    let isProcessing: Bool
    let enhancedFeaturesEnabled: Bool
    let version: String
}

// MARK: - DocumentElement Extension for iOS 26
extension DocumentElement {
    
    @available(iOS 26.0, *)
    var enhancedAttributedContent: NSAttributedString? {
        get {
            guard let data = rtfData else { return nil }
            return iOS26RTFService.shared.readEnhancedRTF(from: data)
        }
        set {
            guard let newValue = newValue else {
                rtfData = nil
                return
            }
            
            rtfData = iOS26RTFService.shared.createEnhancedRTF(from: newValue)
            content = newValue.string
        }
    }
    
    @available(iOS 26.0, *)
    mutating func convertToiOS26Format() {
        self = iOS26RTFService.shared.convertToModernFormat(self)
    }
}

#endif 