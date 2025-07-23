#if os(macOS)
import SwiftUI
import PDFKit
import AppKit

// PDF Document Generator Utility - Shared between preview and export
class PDFDocumentGenerator {
    static func generatePDFData(for document: Letterspace_CanvasDocument, 
                               pageWidth: CGFloat = 8.5 * 72, 
                               pageHeight: CGFloat = 11 * 72,
                               showHeaderImage: Bool = true,
                               showDocumentTitle: Bool = true,
                               showPageNumbers: Bool = true,
                               fontScale: CGFloat = 1.0,
                               includeVerseText: Bool = false,
                               currentPage: Int = 1) -> Data? {
        
        print("Generating PDF data for document: \(document.id)")
        
        let pdfData = NSMutableData()
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        var mediaBox = pageRect
        guard let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!, mediaBox: &mediaBox, nil) else {
            print("Failed to create PDF context")
            return nil
        }
        
        // Start PDF document with first page
        pdfContext.beginPDFPage(nil)
        
        // Draw content - the method now handles adding multiple pages as needed
        let totalPages = drawDocumentContent(in: pdfContext, 
                           pageRect: pageRect, 
                           document: document, 
                           showHeaderImage: showHeaderImage, 
                           showDocumentTitle: showDocumentTitle, 
                           showPageNumbers: showPageNumbers,
                           fontScale: fontScale,
                           includeVerseText: includeVerseText,
                           startPage: 1)
        
        // End the last PDF page and close
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        print("PDF data generated: \(pdfData.length) bytes with \(totalPages) pages")
        return pdfData as Data
    }
    
    private static func drawDocumentContent(in context: CGContext, 
                                           pageRect: CGRect, 
                                           document: Letterspace_CanvasDocument, 
                                           showHeaderImage: Bool, 
                                           showDocumentTitle: Bool, 
                                           showPageNumbers: Bool, 
                                           fontScale: CGFloat,
                                           includeVerseText: Bool = false,
                                           startPage: Int) -> Int {
        
        print("Starting document drawing")
        
        // IMPORTANT: Rich text formatting is now preserved throughout the document
        // Original attributed content formatting (bold, italics, colors, etc.) is maintained
        // and only default formatting is applied where none exists
        
        // Save graphics state
        context.saveGState()
        
        // Use direct PDF coordinates without flipping
        // PDF coordinates start from bottom-left corner
        
        // Font sizes - apply font scale to all text, except for Scripture Sheet specific text
        let titleFontSize: CGFloat = 24 * fontScale
        let subtitleFontSize: CGFloat = 18 * fontScale
        let contentFontSize: CGFloat = 12 * fontScale
        let _ = 16.0 // Fixed size for Scripture Sheet title (unused)
        let scriptureReferenceSize: CGFloat = 10.5 // Reduced size for Scripture references (reference-only)
        let scriptureReferenceBoldSize: CGFloat = 12.0 // Fixed size for Scripture references when quoted
        let scriptureVerseSize: CGFloat = 10.0 // Fixed size for Scripture verse text
        let scriptureSheetSubtitleFontSize: CGFloat = 13.0 // New size for "Scripture Sheet" as a subtitle
        let pageMargin: CGFloat = 72 // Further increased to standard 1-inch margin for better readability
        let minimumSpaceBeforeNewPage: CGFloat = 50 // Increased minimum space needed before starting new content
        
        // Flag to check if this is a Scripture Sheet (contains "Scripture Sheet" as first text element)
        let isScriptureSheet = document.elements.contains { element in
            return element.type == .textBlock && element.content == "Scripture Sheet"
        }
        
        // Start from top of page (in PDF coordinates, this is the bottom)
        var yPosition: CGFloat = pageRect.height - pageMargin
        var currentPage = startPage
        var isFirstPage = true
        var pageHasHeader = isFirstPage // Track if current page already has a header
        
        // The effective drawing area
        let contentWidth = pageRect.width - (pageMargin * 2)
        let _ = pageRect.height - (pageMargin * 2) // Account for top and bottom margins
        let minYPosition = pageMargin + 20 // Bottom margin limit with extra buffer to prevent cut-off
        
        // Function to start a new page
        func beginNewPage() {
            // End current page
            context.restoreGState()
            context.endPDFPage()
            
            // Start a new page
            context.beginPDFPage(nil)
            context.saveGState()
            
            // Reset position for new page
            yPosition = pageRect.height - pageMargin
            currentPage += 1
            isFirstPage = false
            pageHasHeader = false // Reset header flag for new page
            
            // For Scripture Sheets, we don't add headers to continuation pages
            // since the title is shown at the bottom of the page
            if showDocumentTitle && !isScriptureSheet {
                // Draw compact header for continuation pages
                let headerFont = NSFont.systemFont(ofSize: 12, weight: .medium)
                
                // Create header text
                var headerText = document.title
                if !document.subtitle.isEmpty {
                    headerText += " • " + document.subtitle
                }
                
                // Use plain text with default attributes
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: headerFont,
                    .foregroundColor: NSColor.black
                ]
                let headerString = NSAttributedString(string: headerText, attributes: headerAttributes)
                
                let headerSize = headerString.size()
                
                let headerRect = CGRect(x: pageMargin, y: yPosition - headerSize.height, 
                                     width: contentWidth, 
                                     height: headerSize.height)
                
                // Draw header text
                context.saveGState()
                NSGraphicsContext.saveGraphicsState()
                let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                NSGraphicsContext.current = nsContext
                headerString.draw(in: headerRect)
                NSGraphicsContext.restoreGraphicsState()
                context.restoreGState()
                
                // Update position
                yPosition -= (headerSize.height + 6)
                
                // Draw divider line
                context.setStrokeColor(NSColor.gray.withAlphaComponent(0.3).cgColor)
                context.setLineWidth(0.5)
                context.move(to: CGPoint(x: pageMargin, y: yPosition - 2))
                context.addLine(to: CGPoint(x: pageRect.width - pageMargin, y: yPosition - 2))
                context.strokePath()
                
                // Add space after divider
                yPosition -= 15
                
                // Mark that this page now has a header
                pageHasHeader = true
            }
            
            // Draw page number if enabled (we do this after the header to ensure proper spacing)
            if showPageNumbers {
                drawPageNumber(context: context, pageRect: pageRect, pageMargin: pageMargin, currentPage: currentPage, documentTitle: document.title)
            }
        }
        
        // Function to check if content fits on current page
        func needsNewPage(forHeight height: CGFloat) -> Bool {
            // Calculate space needed with a buffer
            let spaceNeeded = height + minimumSpaceBeforeNewPage
            
            // Would the content extend below the bottom margin?
            return yPosition - spaceNeeded < minYPosition
        }
        
        // 1. HEADER IMAGE - draw first to match actual document layout
        if showHeaderImage {
            let headerElements = document.elements.filter { element in
                element.type == .headerImage && !element.content.isEmpty
            }
            
            if let headerElement = headerElements.first {
                // Try multiple paths for the image
                var imageFound = false
                var loadedImage: NSImage? = nil
                
                // Try the document's images directory
                if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let documentPath = documentsPath.appendingPathComponent("\(document.id)")
                    let imagesPath = documentPath.appendingPathComponent("Images")
                    let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
                    
                    if let image = NSImage(contentsOf: imageUrl) {
                        loadedImage = image
                        imageFound = true
                    }
                }
                
                // Try app support directory if not found
                if !imageFound, let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                    let altPath = appSupportPath.appendingPathComponent("Letterspace Canvas/Documents/\(document.id)/Images/\(headerElement.content)")
                    
                    if let image = NSImage(contentsOf: altPath) {
                        loadedImage = image
                        imageFound = true
                    }
                }
                
                // Try cloud directory if not found
                if !imageFound {
                    let fileManager = FileManager.default
                    let cloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
                    
                    if let cloudURL = cloudURL {
                        let cloudPath = cloudURL.appendingPathComponent("\(document.id)/Images/\(headerElement.content)")
                        
                        if let image = NSImage(contentsOf: cloudPath) {
                            loadedImage = image
                            imageFound = true
                        }
                    }
                }
                
                // Try app bundle for default images if not found
                if !imageFound {
                    let bundlePath = Bundle.main.path(forResource: headerElement.content, ofType: nil)
                    if let path = bundlePath, let image = NSImage(contentsOfFile: path) {
                        loadedImage = image
                        imageFound = true
                    }
                }
                
                // Draw the image if found
                if let image = loadedImage {
                    // Calculate aspect ratio to maintain proportions
                    let imageSize = image.size
                    let aspectRatio = imageSize.width / imageSize.height
                    
                    // Use natural image size, but constrain to page width if needed
                    let maxWidth = contentWidth
                    let imageWidth = min(imageSize.width, maxWidth)
                    let imageHeight = imageWidth / aspectRatio
                    
                    // Center the image horizontally
                    let xPosition = pageMargin + ((contentWidth - imageWidth) / 2)
                    
                    // Position from top (remember, in PDF coordinates this is from bottom)
                    let imageRect = CGRect(x: xPosition, y: yPosition - imageHeight, width: imageWidth, height: imageHeight)
                    
                    // Create a rounded rect path for clipping
                    let cornerRadius: CGFloat = 12
                    let roundedRectPath = CGPath(roundedRect: imageRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                    
                    // Apply the clipping path to create rounded corners
                    context.saveGState()
                    context.addPath(roundedRectPath)
                    context.clip()
                    
                    // Draw the image
                    if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        context.draw(cgImage, in: imageRect)
                    }
                    
                    // Restore clipping context
                    context.restoreGState()
                    
                    // Update position - move down past the image
                    yPosition -= (imageHeight + 20) // Add space after image
                }
            }
        }
        
        // 2. DOCUMENT TITLE
        if showDocumentTitle && !document.title.isEmpty {
            // Draw title directly with Core Graphics
            let titleFont = NSFont.boldSystemFont(ofSize: titleFontSize)
            
            // Since there's no attributed title, use plain text
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: NSColor.black
            ]
            let titleString = NSAttributedString(string: document.title, attributes: titleAttributes)
            
            let titleSize = titleString.size()
            
            // Check if we need a new page
            if needsNewPage(forHeight: titleSize.height) {
                // Start a new page unless we're on the first page
                if !isFirstPage {
                    beginNewPage()
                }
            }
            
            let titleRect = CGRect(x: pageMargin, y: yPosition - titleSize.height, 
                                 width: contentWidth, 
                                 height: titleSize.height)
            
            // Draw the actual title text
            context.saveGState()
            
            // Draw text in PDF coordinates
            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext
            
            titleString.draw(in: titleRect)
            
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
            
            // Update position - move down
            yPosition -= (titleSize.height + 5) // Adjusted to match 5pt spacing with Scripture Sheet
        }
        
        // 3. DOCUMENT SUBTITLE - If available
        if showDocumentTitle && !document.subtitle.isEmpty {
            // Draw subtitle directly with Core Graphics
            let subtitleFont = NSFont.systemFont(ofSize: subtitleFontSize)
            
            // Since there's no attributed subtitle, use plain text
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: NSColor.black
            ]
            let subtitleString = NSAttributedString(string: document.subtitle, attributes: subtitleAttributes)
            
            let subtitleSize = subtitleString.size()
            
            // Check if we need a new page
            if needsNewPage(forHeight: subtitleSize.height) {
                // Start a new page unless we're on the first page
                if !isFirstPage {
                    beginNewPage()
                    
                    // If we have to start a new page for the subtitle, redraw the title
                    if showDocumentTitle && !document.title.isEmpty {
                        // Redraw title on new page
                        let titleFont = NSFont.boldSystemFont(ofSize: titleFontSize)
                        let titleAttributes: [NSAttributedString.Key: Any] = [
                            .font: titleFont,
                            .foregroundColor: NSColor.black
                        ]
                        
                        let titleString = NSAttributedString(string: document.title, attributes: titleAttributes)
                        let titleSize = titleString.size()
                        
                        let titleRect = CGRect(x: pageMargin, y: yPosition - titleSize.height, 
                                             width: contentWidth, 
                                             height: titleSize.height)
                        
                        // Draw the title text
                        context.saveGState()
                        NSGraphicsContext.saveGraphicsState()
                        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                        NSGraphicsContext.current = nsContext
                        titleString.draw(in: titleRect)
                        NSGraphicsContext.restoreGraphicsState()
                        context.restoreGState()
                        
                        // Update position
                        yPosition -= (titleSize.height + 5)
                    }
                }
            }
            
            let subtitleRect = CGRect(x: pageMargin, y: yPosition - subtitleSize.height, 
                                    width: contentWidth, 
                                    height: subtitleSize.height)
            
            // Draw the actual subtitle text
            context.saveGState()
            
            // Draw text in PDF coordinates
            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext
            
            subtitleString.draw(in: subtitleRect)
            
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
            
            // Update position - move down
            yPosition -= subtitleSize.height // Position for next element is immediately after subtitle
            yPosition -= 5                   // Add small fixed gap before "Scripture Sheet" text if it follows
        } else { // No main subtitle
            yPosition -= 10 // Default space if no main subtitle
        }
        
        // NEW: Draw "Scripture Sheet" as a subtitle if applicable
        if isScriptureSheet {
            let scriptureSheetSubtitleFont = NSFont.systemFont(ofSize: scriptureSheetSubtitleFontSize, weight: .regular)
            let scriptureSheetSubtitleColor = NSColor.darkGray

            let scriptureSheetText = "Scripture Sheet"
            let scriptureSheetAttributes: [NSAttributedString.Key: Any] = [
                .font: scriptureSheetSubtitleFont,
                .foregroundColor: scriptureSheetSubtitleColor
            ]
            let scriptureSheetString = NSAttributedString(string: scriptureSheetText, attributes: scriptureSheetAttributes)
            let scriptureSheetSize = scriptureSheetString.size()

            // If no main subtitle was drawn, ensure there's adequate default space before "Scripture Sheet" text
            // The `else { yPosition -= 10 }` from main subtitle handling already provides this.

            let scriptureSheetRect = CGRect(x: pageMargin, y: yPosition - scriptureSheetSize.height,
                                         width: contentWidth,
                                         height: scriptureSheetSize.height)
            
            context.saveGState()
            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext
            scriptureSheetString.draw(in: scriptureSheetRect)
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()

            yPosition -= scriptureSheetSize.height // Account for its height
            
            // Add space after Scripture Sheet subtitle (without drawing separator line)
            yPosition -= 50 // Consolidated spacing to replace separator line and surrounding spaces
            
            // Removed separator line code, replaced with just spacing
            
            // Add Smart Summary if available (for both reference-only and full verse views)
            if let summary = document.summary, !summary.isEmpty {
                // First calculate the total height needed for the summary section to draw the border
                // Create a paragraph style for the summary content
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 4
                paragraphStyle.paragraphSpacing = 8
                paragraphStyle.alignment = .left
                
                // Set up the summary content attributes
                let summaryFont = NSFont.systemFont(ofSize: 11)
                let summaryAttributes: [NSAttributedString.Key: Any] = [
                    .font: summaryFont,
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: paragraphStyle
                ]
                let summaryString = NSAttributedString(string: summary, attributes: summaryAttributes)
                
                // Calculate text size
                let availableWidth = contentWidth - 32 // More padding for the border
                let framesetter = CTFramesetterCreateWithAttributedString(summaryString)
                let textSize = CTFramesetterSuggestFrameSizeWithConstraints(
                    framesetter,
                    CFRange(location: 0, length: summaryString.length),
                    nil,
                    CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude),
                    nil
                )
                
                // Create a label for the Quick Summary section
                let summaryLabelFont = NSFont.boldSystemFont(ofSize: 12)
                let summaryLabelAttributes: [NSAttributedString.Key: Any] = [
                    .font: summaryLabelFont,
                    .foregroundColor: NSColor.black
                ]
                let summaryLabelString = NSAttributedString(string: "Quick Summary:", attributes: summaryLabelAttributes)
                let summaryLabelSize = summaryLabelString.size()
                
                // Calculate total height for border (with padding)
                let totalHeight = summaryLabelSize.height + 5 + textSize.height + 16 // Add padding
                
                // Draw the rounded rectangle border
                let borderRect = CGRect(
                    x: pageMargin + 4,
                    y: yPosition - totalHeight - 8,
                    width: contentWidth - 8,
                    height: totalHeight + 16
                )
                
                // Draw rounded border
                let borderPath = CGPath(roundedRect: borderRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
                context.saveGState()
                context.addPath(borderPath)
                context.setStrokeColor(NSColor.lightGray.withAlphaComponent(0.4).cgColor)
                context.setLineWidth(0.8)
                context.strokePath()
                context.restoreGState()
                
                // Draw the Summary label with adjusted position
                let summaryLabelRect = CGRect(
                    x: pageMargin + 16, // More indent inside border
                    y: yPosition - summaryLabelSize.height,
                    width: contentWidth - 32,
                    height: summaryLabelSize.height
                )
                
                context.saveGState()
                NSGraphicsContext.saveGraphicsState()
                let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                NSGraphicsContext.current = nsContext
                summaryLabelString.draw(in: summaryLabelRect)
                NSGraphicsContext.restoreGraphicsState()
                context.restoreGState()
                
                // Update position after the label
                yPosition -= (summaryLabelSize.height + 5)
                
                // Create the frame rect where we'll draw the text (adjusted for border)
                let summaryRect = CGRect(
                    x: pageMargin + 16, // More indent inside border
                    y: yPosition - textSize.height,
                    width: availableWidth,
                    height: textSize.height
                )
                
                // Draw the summary content
                context.saveGState()
                let textPath = CGPath(rect: summaryRect, transform: nil)
                let frame = CTFramesetterCreateFrame(
                    framesetter,
                    CFRange(location: 0, length: summaryString.length),
                    textPath,
                    nil
                )
                CTFrameDraw(frame, context)
                context.restoreGState()
                
                // Update position after the summary with appropriate spacing
                if !includeVerseText {
                    // More compact spacing for reference-only view
                    yPosition -= (textSize.height + 20)
                } else {
                    // Original spacing for verse view
                    yPosition -= (textSize.height + 30)
                }
                
                // Invisible separator (0 opacity) to maintain layout but not show a line
                let separatorY = yPosition - 10
                context.saveGState()
                context.setStrokeColor(NSColor.clear.cgColor) // Set to clear instead of lightGray
                context.setLineWidth(0.5)
                context.move(to: CGPoint(x: pageMargin + 40, y: separatorY))
                context.addLine(to: CGPoint(x: pageRect.width - pageMargin - 40, y: separatorY))
                context.strokePath()
                context.restoreGState()
                
                // Add more space after the separator
                yPosition -= 35 // Increased from 20 to 35
            }
        }
        
        // 4. DOCUMENT CONTENT - All text elements
        // Filter content elements (excluding header images and the "Scripture Sheet" element itself if isScriptureSheet)
        let contentElements = document.elements.compactMap { element -> (DocumentElement, Bool)? in
            // Skip empty elements and header images
            guard !element.content.isEmpty && element.type != .headerImage else {
                return nil
            }
            
            // If this is a scripture sheet, skip the "Scripture Sheet" title element itself from content processing
            if isScriptureSheet && element.type == .textBlock && element.content == "Scripture Sheet" {
                return nil
            }
            
            // Include all other elements
            let hasAttributed = element.attributedContent != nil
            return (element, hasAttributed)
        }
        
        print("Processing \(contentElements.count) content elements")
        
        if contentElements.isEmpty {
            // Display a message if no content
            let noContentFont = NSFont.systemFont(ofSize: contentFontSize)
            let noContentAttributes: [NSAttributedString.Key: Any] = [
                .font: noContentFont,
                .foregroundColor: NSColor.black
            ]
            
            let noContentString = NSAttributedString(string: "No content in document", attributes: noContentAttributes)
            let noContentSize = noContentString.size()
            
            let noContentRect = CGRect(x: pageMargin, y: yPosition - noContentSize.height, 
                                     width: contentWidth, 
                                     height: noContentSize.height)
            
            // Draw the actual message
            context.saveGState()
            
            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext
            
            noContentString.draw(in: noContentRect)
            
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
        } else {
            // Function to add a title to new page if needed
            func addTitleToNewPage() {
                // Only add a title if:
                // 1. We don't already have a header
                // 2. Document title is available
                // 3. Not a Scripture Sheet OR it's the first page (no title repeats on additional Scripture Sheet pages)
                if !pageHasHeader && showDocumentTitle && !document.title.isEmpty && (!isScriptureSheet || isFirstPage) {
                    // Redraw title on new page (smaller)
                    let titleFont = NSFont.boldSystemFont(ofSize: titleFontSize * 0.75) // Smaller title on content pages
                    let titleAttributes: [NSAttributedString.Key: Any] = [
                        .font: titleFont,
                        .foregroundColor: NSColor.black
                    ]
                    
                    let titleString = NSAttributedString(string: document.title, attributes: titleAttributes)
                    let titleSize = titleString.size()
                    
                    let titleRect = CGRect(x: pageMargin, y: yPosition - titleSize.height, 
                                          width: contentWidth, 
                                          height: titleSize.height)
                    
                    // Draw the title text
                    context.saveGState()
                    NSGraphicsContext.saveGraphicsState()
                    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                    NSGraphicsContext.current = nsContext
                    titleString.draw(in: titleRect)
                    NSGraphicsContext.restoreGraphicsState()
                    context.restoreGState()
                    
                    // Update position
                    yPosition -= (titleSize.height + 8)
                    
                    // Mark that this page now has a header
                    pageHasHeader = true
                }
            }
            
            for (index, (element, hasAttributed)) in contentElements.enumerated() {
                print("Processing element \(index+1) of type \(element.type)")
                
                // Choose font based on element type
                let fontSize: CGFloat
                let font: NSFont
                
                // Special handling for Scripture Sheet elements
                if isScriptureSheet {
                    // Logic for actual scripture references
                    if includeVerseText && element.content.contains("\n") {
                        // This is a reference with text
                        fontSize = scriptureReferenceBoldSize
                        font = NSFont.boldSystemFont(ofSize: fontSize)
                    } else {
                        // Scripture reference without text
                        fontSize = scriptureReferenceSize
                        font = NSFont.systemFont(ofSize: fontSize)
                    }
                } else {
                    // Standard document element formatting
                    switch element.type {
                    case .header:
                        fontSize = 18 * fontScale
                        font = NSFont.boldSystemFont(ofSize: fontSize)
                    case .subheader:
                        fontSize = 16 * fontScale
                        font = NSFont.boldSystemFont(ofSize: fontSize)
                    case .title:
                        fontSize = 20 * fontScale
                        font = NSFont.boldSystemFont(ofSize: fontSize)
                    default:
                        fontSize = 14 * fontScale
                        font = NSFont.systemFont(ofSize: fontSize)
                    }
                }
                
                // Create a strong content attributes dictionary with forced black text
                let contentAttributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor.black
                ]
                
                // Use attributed content if available, or create with forced black color
                let contentString: NSAttributedString
                
                if isScriptureSheet && element.content.contains("\n") && !hasAttributed {
                    // Special handling for Scripture Sheet elements with references and verses
                    let parts = element.content.components(separatedBy: "\n")
                    let reference = parts[0]
                    let verseText = parts.count > 1 ? parts.dropFirst().joined(separator: "\n") : ""
                    
                    let mutableContent = NSMutableAttributedString()
                    
                    // Add the reference with bold styling
                    let referenceAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.boldSystemFont(ofSize: scriptureReferenceBoldSize),
                        .foregroundColor: NSColor.black
                    ]
                    let referenceString = NSAttributedString(string: reference, attributes: referenceAttributes)
                    mutableContent.append(referenceString)
                    
                    // Add a newline with more space
                    mutableContent.append(NSAttributedString(string: "\n\n", attributes: [.font: NSFont.systemFont(ofSize: 4)])) // Add extra space between reference and verse
                    
                    // Add the verse text with smaller font
                    let verseAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: scriptureVerseSize),
                        .foregroundColor: NSColor.black,
                        .paragraphStyle: {
                            let paragraphStyle = NSMutableParagraphStyle()
                            paragraphStyle.lineSpacing = 2.0 // Add line spacing for better readability
                            paragraphStyle.paragraphSpacing = 8.0 // Add paragraph spacing
                            return paragraphStyle
                        }()
                    ]
                    let verseString = NSAttributedString(string: verseText, attributes: verseAttributes)
                    mutableContent.append(verseString)
                    
                    contentString = mutableContent
                } else if hasAttributed, let attributedContent = element.attributedContent {
                    // Create a new mutable attributed string from the original content's plain string.
                    // We will re-apply attributes, scaling fonts as needed.
                    let mutableContent = NSMutableAttributedString(string: attributedContent.string)
                    
                    attributedContent.enumerateAttributes(in: NSRange(location: 0, length: attributedContent.length), options: []) { (originalAttributes, range, _) in
                        var newAttributes = originalAttributes
                        
                        // Font handling:
                        if let existingFont = originalAttributes[.font] as? NSFont {
                            // An NSFont attribute exists, scale its size
                            let scaledSize = existingFont.pointSize * fontScale
                            if let scaledFont = NSFont(descriptor: existingFont.fontDescriptor, size: scaledSize) {
                                newAttributes[.font] = scaledFont
                            } else {
                                // Fallback: if creating font from descriptor fails, use the default scaled font for this element type
                                newAttributes[.font] = font // 'font' is already scaled based on element type and fontScale
                            }
                        } else {
                            // No NSFont attribute in original, so apply the default scaled font for this element type
                            newAttributes[.font] = font // 'font' is already scaled based on element type and fontScale
                        }
                        
                        // Foreground color handling:
                        // If original attributes didn't specify a color, default to black. Otherwise, preserve original color.
                        if originalAttributes[.foregroundColor] == nil {
                            newAttributes[.foregroundColor] = NSColor.black
                        }
                        // (If you always want to force black, uncomment the line below and remove the if-condition)
                        // newAttributes[.foregroundColor] = NSColor.black

                        // Apply the (potentially modified) attributes to the range in our new mutable string
                        mutableContent.addAttributes(newAttributes, range: range)
                    }
                    contentString = mutableContent
                } else {
                    // No attributed content, so create from plain string with default scaled font and black color
                    contentString = NSAttributedString(string: element.content, attributes: contentAttributes) // contentAttributes uses scaled 'font'
                }
                
                // Skip empty content
                if contentString.length == 0 {
                    print("Skipping empty content")
                    continue
                }
                
                print("Text length: \(contentString.length) characters")
                
                // Ensure unlimited pages for content by using a recursive approach
                func drawRemainingText(_ text: NSAttributedString, startY: CGFloat) {
                    // Determine how much fits on current page
                    let availableHeight = startY - minYPosition - 25 // Increased buffer at bottom to prevent cutoff
                    
                    // If no space left, start a new page
                    if availableHeight <= 35 { // Increased minimum space required for text
                        print("No space left on page \(currentPage), creating new page")
                        beginNewPage()
                        // Reset and try again with full page height
                        drawRemainingText(text, startY: yPosition)
                        return
                    }
                    
                    // Create text bounds for measuring
                    let textBounds = CGSize(width: contentWidth - 20, height: availableHeight) // Further reduced width to prevent horizontal cutoff
                    
                    // Create layout manager to calculate text fitting
                    let layoutManager = NSLayoutManager()
                    let textContainer = NSTextContainer(size: textBounds)
                    textContainer.lineFragmentPadding = 10 // Increased padding to prevent text touching edges
                    let textStorage = NSTextStorage(attributedString: text)
                    
                    textStorage.addLayoutManager(layoutManager)
                    layoutManager.addTextContainer(textContainer)
                    
                    // Calculate how much text fits - be more conservative with long text
                    let glyphRange = layoutManager.glyphRange(for: textContainer)
                    let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                    
                    // For longer text, be more cautious about how much we try to fit on a page
                    let fitLength: Int
                    if text.length > 1000 { // For very long passages
                        // Be more conservative, take a little less than what layout manager suggests
                        fitLength = min(charRange.length, Int(Double(charRange.length) * 0.95))
                    } else {
                        fitLength = charRange.length
                    }
                    
                    print("Available height: \(availableHeight), can fit \(fitLength) of \(text.length) characters")
                    
                    if fitLength == 0 && text.length > 0 {
                        print("Warning: Zero characters fit but text remains. Forcing new page.")
                        beginNewPage()
                        drawRemainingText(text, startY: yPosition)
                        return
                    }
                    
                    // Draw what fits on this page
                    let displayText = fitLength > 0 ? text.attributedSubstring(from: NSRange(location: 0, length: min(fitLength, text.length))) : text
                    
                    // Calculate actual height used
                    let usedRect = layoutManager.usedRect(for: textContainer)
                    let textHeight = usedRect.height + 10 // Increased buffer to ensure text isn't cut off
                    
                    // Create drawing rect with more padding
                    let textRect = CGRect(x: pageMargin + 10, y: startY - textHeight, width: contentWidth - 20, height: textHeight) // Increased padding on both sides
                    
                    // Draw text
                    context.saveGState()
                    NSGraphicsContext.saveGraphicsState()
                    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                    NSGraphicsContext.current = nsContext
                    displayText.draw(in: textRect)
                    NSGraphicsContext.restoreGraphicsState()
                    context.restoreGState()
                    
                    // Update position with appropriate spacing based on content type
                    if isScriptureSheet && !includeVerseText {
                        // Further reduced spacing for reference-only view
                        yPosition = startY - textHeight - 7 // Fine-tuned spacing for more compact layout
                    } else {
                        // Standard spacing for other content
                        yPosition = startY - textHeight - 25 // Original spacing
                    }
                    
                    // If there's more text to draw, continue to next page
                    if fitLength < text.length {
                        print("More text remains: \(text.length - fitLength) characters")
                        let remainingRange = NSRange(location: fitLength, length: text.length - fitLength)
                        let remainingText = text.attributedSubstring(from: remainingRange)
                        
                        // If we're near the bottom or have a lot of text remaining, start a new page
                        if yPosition < minYPosition + 50 || remainingText.length > 500 { // Increased threshold for starting new page
                            beginNewPage()
                        }
                        
                        // Draw remaining text (recursive)
                        drawRemainingText(remainingText, startY: yPosition)
                    }
                }
                
                // Start drawing this element's text with unlimited page capacity
                drawRemainingText(contentString, startY: yPosition)
                
                // Add separator between content items if not at bottom of page
                if index < contentElements.count - 1 && yPosition > minYPosition + 20 {
                    if isScriptureSheet { // Covers all cases within a scripture sheet
                        // For reference-only view (no verse text), use more compact spacing
                        if !includeVerseText {
                            // Use smaller, lighter separator with tighter spacing for reference-only view
                            let separatorY = yPosition + 6 // Reduced spacing
                            
                            context.saveGState()
                            context.setStrokeColor(NSColor.lightGray.withAlphaComponent(0.3).cgColor) // More subtle
                            context.setLineWidth(0.5) // Thinner line
                            context.move(to: CGPoint(x: pageMargin + 40, y: separatorY))
                            context.addLine(to: CGPoint(x: pageRect.width - pageMargin - 40, y: separatorY))
                            context.strokePath()
                            context.restoreGState()
                            
                                                         // Apply tighter spacing for reference-only view
                            yPosition -= 4 // Further reduced spacing after separator
                        } else {
                            // Original spacing and separator for verse view
                            let separatorY = yPosition + 10
                            
                            context.saveGState()
                            context.setStrokeColor(NSColor.lightGray.withAlphaComponent(0.4).cgColor)
                            context.setLineWidth(0.8)
                            context.move(to: CGPoint(x: pageMargin + 40, y: separatorY))
                            context.addLine(to: CGPoint(x: pageRect.width - pageMargin - 40, y: separatorY))
                            context.strokePath()
                            context.restoreGState()
                            
                            // Apply consistent spacing after any separator in a scripture sheet with verses
                            yPosition -= 10
                        }
                    } else {
                        // Standard separator for non-scripture sheet documents
                        let separatorY = yPosition + 7.5
                        context.setStrokeColor(NSColor.lightGray.withAlphaComponent(0.3).cgColor)
                        context.setLineWidth(0.5)
                        context.move(to: CGPoint(x: pageMargin + 20, y: separatorY))
                        context.addLine(to: CGPoint(x: pageRect.width - pageMargin - 20, y: separatorY))
                        context.strokePath()
                    }
                }
            }
        }
        
        // 5. PAGE NUMBERS - If enabled, draw on first page (already drawn on subsequent pages)
        if showPageNumbers && isFirstPage {
            drawPageNumber(context: context, pageRect: pageRect, pageMargin: pageMargin, currentPage: currentPage, documentTitle: document.title)
        }
        
        // Restore main graphics state
        context.restoreGState()
        
        return currentPage // Return the total number of pages created
    }
    
    // Helper method to draw text across an unlimited number of pages
    private static func drawTextAcrossPages(
        _ attributedText: NSAttributedString, 
        context: CGContext, 
        pageRect: CGRect, 
        pageMargin: CGFloat, 
        minYPosition: CGFloat, 
        contentWidth: CGFloat,
        documentTitle: String = "",
        documentSubtitle: String = "",
        pageHasHeader: Bool = false
    ) -> Int {
        print("Drawing text across pages, length: \(attributedText.length)")
        
        // We need to handle attributed text carefully to preserve formatting
        var remainingText = NSMutableAttributedString(attributedString: attributedText)
        var yPos = pageRect.height - pageMargin
        var pagesAdded = 0
        var currentPageHasHeader = pageHasHeader
        
        // Draw header on first page if needed
        if !currentPageHasHeader {
            // Add header text
            let headerFont = NSFont.systemFont(ofSize: 12, weight: .medium)
            
            // Create header text with title • subtitle format
            var headerText = documentTitle
            if !documentTitle.isEmpty && !documentSubtitle.isEmpty {
                headerText += " • " + documentSubtitle
            } else if documentTitle.isEmpty && !documentSubtitle.isEmpty {
                headerText = documentSubtitle
            }
            
            if !headerText.isEmpty {
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: headerFont,
                    .foregroundColor: NSColor.black
                ]
                let headerString = NSAttributedString(string: headerText, attributes: headerAttributes)
                
                let headerSize = headerString.size()
                
                let headerRect = CGRect(x: pageMargin, y: yPos - headerSize.height, 
                                     width: contentWidth, 
                                     height: headerSize.height)
                
                // Draw header text
                context.saveGState()
                NSGraphicsContext.saveGraphicsState()
                let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                NSGraphicsContext.current = nsContext
                headerString.draw(in: headerRect)
                NSGraphicsContext.restoreGraphicsState()
                context.restoreGState()
                
                // Update position
                yPos -= (headerSize.height + 6)
                
                // Draw divider line
                context.setStrokeColor(NSColor.gray.withAlphaComponent(0.3).cgColor)
                context.setLineWidth(0.5)
                context.move(to: CGPoint(x: pageMargin, y: yPos - 2))
                context.addLine(to: CGPoint(x: pageRect.width - pageMargin, y: yPos - 2))
                context.strokePath()
                
                // Add space after divider
                yPos -= 15
                
                currentPageHasHeader = true
            }
        }
        
        // Continue until all text is drawn
        while remainingText.length > 0 {
            // Calculate available space on current page
            let availableHeight = yPos - minYPosition
            
            // If no space left, start a new page
            if availableHeight <= 0 {
                context.endPDFPage()
                context.beginPDFPage(nil)
                context.saveGState()
                pagesAdded += 1
                yPos = pageRect.height - pageMargin
                currentPageHasHeader = false
                
                // Add header on new page
                let headerFont = NSFont.systemFont(ofSize: 12, weight: .medium)
                
                // Create header text with title • subtitle format
                var headerText = documentTitle
                if !documentTitle.isEmpty && !documentSubtitle.isEmpty {
                    headerText += " • " + documentSubtitle
                } else if documentTitle.isEmpty && !documentSubtitle.isEmpty {
                    headerText = documentSubtitle
                }
                
                if !headerText.isEmpty {
                    let headerAttributes: [NSAttributedString.Key: Any] = [
                        .font: headerFont,
                        .foregroundColor: NSColor.black
                    ]
                    let headerString = NSAttributedString(string: headerText, attributes: headerAttributes)
                    
                    let headerSize = headerString.size()
                    
                    let headerRect = CGRect(x: pageMargin, y: yPos - headerSize.height, 
                                         width: contentWidth, 
                                         height: headerSize.height)
                    
                    // Draw header text
                    context.saveGState()
                    NSGraphicsContext.saveGraphicsState()
                    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                    NSGraphicsContext.current = nsContext
                    headerString.draw(in: headerRect)
                    NSGraphicsContext.restoreGraphicsState()
                    context.restoreGState()
                    
                    // Update position
                    yPos -= (headerSize.height + 6)
                    
                    // Draw divider line
                    context.setStrokeColor(NSColor.gray.withAlphaComponent(0.3).cgColor)
                    context.setLineWidth(0.5)
                    context.move(to: CGPoint(x: pageMargin, y: yPos - 2))
                    context.addLine(to: CGPoint(x: pageRect.width - pageMargin, y: yPos - 2))
                    context.strokePath()
                    
                    // Add space after divider
                    yPos -= 15
                    
                    currentPageHasHeader = true
                }
                
                continue
            }
            
            // Create a text container that fits the available space
            let textContainer = NSTextContainer(size: CGSize(width: contentWidth, height: availableHeight))
            let layoutManager = NSLayoutManager()
            let textStorage = NSTextStorage(attributedString: remainingText)
            
            textStorage.addLayoutManager(layoutManager)
            layoutManager.addTextContainer(textContainer)
            
            // Determine how much text fits
            let glyphRange = layoutManager.glyphRange(for: textContainer)
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            
            // Create drawing rect
            let textRect = CGRect(x: pageMargin, y: yPos - availableHeight, 
                                width: contentWidth, 
                                height: availableHeight)
            
            // Check if any text fits
            if charRange.length > 0 {
                context.saveGState()
                NSGraphicsContext.saveGraphicsState()
                let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                NSGraphicsContext.current = nsContext
                
                // Draw what fits on this page
                if charRange.length < remainingText.length {
                    // Draw portion that fits
                    let partialText = remainingText.attributedSubstring(from: NSRange(location: 0, length: charRange.length))
                    partialText.draw(in: textRect)
                } else {
                    // Draw all remaining text
                    remainingText.draw(in: textRect)
                }
                
                NSGraphicsContext.restoreGraphicsState()
                context.restoreGState()
            }
            
            // Update position
            yPos = minYPosition
            
            // Check if we need to continue to a new page
            if charRange.length < remainingText.length {
                // Start a new page for remaining text
                context.endPDFPage()
                context.beginPDFPage(nil)
                context.saveGState()
                pagesAdded += 1
                yPos = pageRect.height - pageMargin
                currentPageHasHeader = false
                
                // Add header on new page
                let headerFont = NSFont.systemFont(ofSize: 12, weight: .medium)
                
                // Create header text with title • subtitle format
                var headerText = documentTitle
                if !documentTitle.isEmpty && !documentSubtitle.isEmpty {
                    headerText += " • " + documentSubtitle
                } else if documentTitle.isEmpty && !documentSubtitle.isEmpty {
                    headerText = documentSubtitle
                }
                
                if !headerText.isEmpty {
                    let headerAttributes: [NSAttributedString.Key: Any] = [
                        .font: headerFont,
                        .foregroundColor: NSColor.black
                    ]
                    let headerString = NSAttributedString(string: headerText, attributes: headerAttributes)
                    
                    let headerSize = headerString.size()
                    
                    let headerRect = CGRect(x: pageMargin, y: yPos - headerSize.height, 
                                         width: contentWidth, 
                                         height: headerSize.height)
                    
                    // Draw header text
                    context.saveGState()
                    NSGraphicsContext.saveGraphicsState()
                    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                    NSGraphicsContext.current = nsContext
                    headerString.draw(in: headerRect)
                    NSGraphicsContext.restoreGraphicsState()
                    context.restoreGState()
                    
                    // Update position
                    yPos -= (headerSize.height + 6)
                    
                    // Draw divider line
                    context.setStrokeColor(NSColor.gray.withAlphaComponent(0.3).cgColor)
                    context.setLineWidth(0.5)
                    context.move(to: CGPoint(x: pageMargin, y: yPos - 2))
                    context.addLine(to: CGPoint(x: pageRect.width - pageMargin, y: yPos - 2))
                    context.strokePath()
                    
                    // Add space after divider
                    yPos -= 15
                    
                    currentPageHasHeader = true
                }
                
                // Update remaining text
                if charRange.length > 0 {
                    let newRange = NSRange(location: charRange.length, length: remainingText.length - charRange.length)
                    remainingText = NSMutableAttributedString(attributedString: remainingText.attributedSubstring(from: newRange))
                }
            } else {
                // All text has been drawn
                remainingText = NSMutableAttributedString(string: "")
            }
        }
        
        return pagesAdded
    }
    
    private static func drawPageNumber(context: CGContext, pageRect: CGRect, pageMargin: CGFloat, currentPage: Int, documentTitle: String = "") {
        // For Scripture Sheets, don't show "Page 1" on the first page, but show page numbers on subsequent pages
        // For other documents, continue to show page number on first page
        if currentPage == 1 {
            // Skip drawing page number on first page
            return
        }
        
        // For continuation pages, or if we don't have a title
        if documentTitle.isEmpty {
            let pageNumberFont = NSFont.systemFont(ofSize: 10)
            let pageNumberAttributes: [NSAttributedString.Key: Any] = [
                .font: pageNumberFont,
                .foregroundColor: NSColor.black
            ]
            
            let pageNumberString = NSAttributedString(string: "Page \(currentPage)", attributes: pageNumberAttributes)
            let pageNumberSize = pageNumberString.size()
            
            // Calculate position for page number (centered at bottom)
            let pageNumberRect = CGRect(
                x: (pageRect.width - pageNumberSize.width) / 2,
                y: pageMargin / 2 - pageNumberSize.height / 2,
                width: pageNumberSize.width,
                height: pageNumberSize.height
            )
            
            // Draw page number
            context.saveGState()
            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext
            pageNumberString.draw(in: pageNumberRect)
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
        } else if currentPage > 1 {
            // For continuation pages, right-align the title and page number together
            
            // Create a combined string with: "Sermon Title (semibold) • Page __ (regular)"
            let titleFont = NSFont.systemFont(ofSize: 10, weight: .semibold)
            let regularFont = NSFont.systemFont(ofSize: 10)
            
            // Create a mutable attributed string
            let combinedString = NSMutableAttributedString()
            
            // Add title with bold styling
            let titlePart = NSAttributedString(string: documentTitle, attributes: [
                .font: titleFont,
                .foregroundColor: NSColor.black
            ])
            combinedString.append(titlePart)
            
            // Add separator
            let separatorPart = NSAttributedString(string: " • ", attributes: [
                .font: regularFont,
                .foregroundColor: NSColor.black
            ])
            combinedString.append(separatorPart)
            
            // Add page number with regular styling
            let pagePart = NSAttributedString(string: "Page \(currentPage)", attributes: [
                .font: regularFont,
                .foregroundColor: NSColor.black
            ])
            combinedString.append(pagePart)
            
            // Calculate the total size
            let combinedSize = combinedString.size()
            
            // Calculate position (right-aligned at bottom)
            let combinedRect = CGRect(
                x: pageRect.width - pageMargin - combinedSize.width,
                y: pageMargin / 2 - combinedSize.height / 2,
                width: combinedSize.width,
                height: combinedSize.height
            )
            
            // Draw the combined text
            context.saveGState()
            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext
            combinedString.draw(in: combinedRect)
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
        }
    }
}

// Simplified Document preview component for the CustomShareSheet
struct SimplifiedDocumentPreview: View {
    let document: Letterspace_CanvasDocument
    let showHeaderImage: Bool
    let showDocumentTitle: Bool
    let showPageNumbers: Bool
    let fontScale: CGFloat
    @Environment(\.colorScheme) var colorScheme
    @State private var pageCount: Int = 1
    @State private var currentPage: Int = 1
    @State private var pdfDocument: PDFDocument? = nil
    @State private var refreshID = UUID() // Add a refresh ID to force updates
    
    // Standard US Letter dimensions (8.5 x 11 inches) in points
    private let pageWidth: CGFloat = 8.5 * 72
    private let pageHeight: CGFloat = 11 * 72
    
    var body: some View {
        VStack {
            // Page preview with border
            ZStack(alignment: .center) {
                // Page background
                Rectangle()
                    .fill(Color.white)
                    .frame(width: pageWidth * 0.5, height: pageHeight * 0.5)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                // Page content
                if let pdf = pdfDocument, pdf.pageCount > 0 {
                    // PDF preview
                    PDFPreview(document: pdf, currentPage: currentPage - 1)
                        .frame(width: pageWidth * 0.5, height: pageHeight * 0.5)
                        .id(refreshID) // Use the refresh ID to force updates
                        .clipped() // Ensure content stays within bounds
                } else {
                    // Loading indicator
                    VStack {
                        ProgressView()
                        Text("Loading document preview...")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                    .frame(width: pageWidth * 0.5, height: pageHeight * 0.5)
                }
            }
            .frame(width: pageWidth * 0.5, height: pageHeight * 0.5)
            
            // Page navigation controls
            if pageCount > 1 {
                HStack {
                    Button(action: {
                        if currentPage > 1 {
                            currentPage -= 1
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(currentPage > 1 ? .blue : .gray)
                    }
                    .disabled(currentPage <= 1)
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("Page \(currentPage) of \(pageCount)")
                        .font(.system(size: 12))
                    
                    Button(action: {
                        if currentPage < pageCount {
                            currentPage += 1
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(currentPage < pageCount ? .blue : .gray)
                    }
                    .disabled(currentPage >= pageCount)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 8)
            }
            
            // Regenerate button for debugging
            Button("Regenerate PDF") {
                generatePDF()
            }
            .font(.system(size: 12))
            .padding(.top, 4)
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(colorScheme == .dark ? Color(.sRGB, white: 0.2) : Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            print("SimplifiedDocumentPreview appeared")
            generatePDF()
        }
        .onChange(of: document.id) { oldValue, newValue in
            print("Document ID changed from \(oldValue) to \(newValue), regenerating PDF")
            generatePDF()
        }
        .onChange(of: showHeaderImage) { oldValue, newValue in
            print("showHeaderImage changed from \(oldValue) to \(newValue), regenerating PDF")
            generatePDF()
        }
        .onChange(of: showDocumentTitle) { oldValue, newValue in
            print("showDocumentTitle changed from \(oldValue) to \(newValue), regenerating PDF")
            generatePDF()
        }
        .onChange(of: showPageNumbers) { oldValue, newValue in
            print("showPageNumbers changed from \(oldValue) to \(newValue), regenerating PDF")
            generatePDF()
        }
        .onChange(of: fontScale) { oldValue, newValue in
            print("fontScale changed from \(oldValue) to \(newValue), regenerating PDF")
            generatePDF()
        }
    }
    
    // Generate PDF document
    private func generatePDF() {
        print("Generating PDF for document: \(document.id)")
        
        // Clear existing PDF document first
        self.pdfDocument = nil
        
        // Generate new PDF using shared utility
        if let pdfData = PDFDocumentGenerator.generatePDFData(
            for: document,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            showHeaderImage: showHeaderImage,
            showDocumentTitle: showDocumentTitle,
            showPageNumbers: showPageNumbers,
            fontScale: fontScale,
            includeVerseText: false,
            currentPage: currentPage
        ) {
            print("PDF data generated successfully: \(pdfData.count) bytes")
            if let pdf = PDFDocument(data: pdfData) {
                print("PDF document created successfully with \(pdf.pageCount) pages")
                self.pdfDocument = pdf
                self.pageCount = pdf.pageCount
                self.currentPage = 1 // Reset to first page
                self.refreshID = UUID() // Update the refresh ID to force a redraw
            } else {
                print("Failed to create PDF document from data")
            }
        } else {
            print("Failed to generate PDF data")
        }
    }
}

// PDF Preview component
struct PDFPreview: NSViewRepresentable {
    let document: PDFDocument
    let currentPage: Int
    
    func makeNSView(context: Context) -> PDFView {
        print("Creating PDFView for page \(currentPage)")
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.backgroundColor = .white
        
        // Improved scaling for better visibility
        view.scaleFactor = view.scaleFactorForSizeToFit
        view.minScaleFactor = 0.25 // Allow zooming out more
        view.maxScaleFactor = 5.0  // Allow zooming in more
        
        // Important: This ensures the content fits properly in the view
        view.autoScales = true
        
        // Use the documentView instead of contentView and use proper NSView autoresizing mask
        if let documentView = view.documentView {
            documentView.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        }
        
        // Disable page shadow for cleaner appearance
        view.displaysPageBreaks = false
        
        // Ensure content is properly centered
        view.pageBreakMargins = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        // Disable annotations and interactions
        // Note: enableDataDetectors was deprecated in macOS 15.0
        
        // Add a slight delay to ensure the document is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if document.pageCount > currentPage {
                print("Going to page \(currentPage) of \(document.pageCount)")
                if let page = document.page(at: currentPage) {
                    view.go(to: page)
                    // Force layout and refresh
                    view.needsLayout = true
                    view.display()
                }
            } else {
                print("Page \(currentPage) is out of range (document has \(document.pageCount) pages)")
            }
            
            // Ensure proper scaling after navigation
            view.scaleFactor = view.scaleFactorForSizeToFit
        }
        
        return view
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        print("Updating PDFView for page \(currentPage)")
        
        // Set document if different
        if nsView.document !== document {
            nsView.document = document
        }
        
        // Navigate to the correct page if needed
        if document.pageCount > currentPage, 
           let page = document.page(at: currentPage),
           nsView.currentPage != page {
            nsView.go(to: page)
        }
        
        // Ensure proper scaling
        nsView.scaleFactor = nsView.scaleFactorForSizeToFit
        
        // Force layout and refresh
        nsView.needsLayout = true
        nsView.display()
    }
}
#endif 