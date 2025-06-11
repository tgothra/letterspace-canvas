#if os(macOS)
import AppKit

extension DocumentTextView {
    // MARK: - Static Properties for Scripture Handling
    // Add a static variable to track the next layout to use
    internal static var nextScriptureLayout: ScriptureLayoutStyle?

    // MARK: - Scripture Insertion and Formatting Methods
    // Helper method to insert scripture
    internal func insertScripture(_ scripture: ScriptureElement) {
        print("📜 Looking up layout to use...")
        
        // Get the layout from the static variable
        let layoutToUse: ScriptureLayoutStyle
        
        if let nextLayout = DocumentTextView.nextScriptureLayout {
            // Use the pre-selected layout
            layoutToUse = nextLayout
            print("📜 Using pre-selected layout: \(layoutToUse), raw value: \(layoutToUse.rawValue)")
            
            // Clear it immediately to avoid reuse
            DocumentTextView.nextScriptureLayout = nil
            print("📜 Layout selection cleared immediately after use")
        } else {
            // Fall back to default
            layoutToUse = .individualVerses
            print("📜 No layout pre-selected, using default: \(layoutToUse), raw value: \(layoutToUse.rawValue)")
        }
        
        // Use the selected layout style
        print("📜 Final layout selection: \(layoutToUse), raw value: \(layoutToUse.rawValue)")
        insertScripture(scripture, layout: layoutToUse)
    }
    
    // Helper method to insert scripture with a specific layout
    internal func insertScripture(_ scripture: ScriptureElement, layout: ScriptureLayoutStyle) {
        print("📜 Starting scripture insertion with layout: \(layout)")
        
        // Get the current typing attributes
        let currentAttributes = typingAttributes
        
        // Create scripture attributed string
        let scriptureText = NSMutableAttributedString()
        
        // Create a paragraph style with increased spacing above for the initial line
        let initialStyle = NSMutableParagraphStyle()
        initialStyle.paragraphSpacingBefore = 20 // Increased spacing before scripture
        initialStyle.lineHeightMultiple = 1.3
        
        // Add a single initial line break with increased spacing before
        let initialNewline = NSMutableAttributedString(string: "") // Empty string for initial line with style
        let initialAttributes = currentAttributes.merging([.paragraphStyle: initialStyle]) { (_, new) in new }
        initialNewline.addAttributes(initialAttributes, range: NSRange(location: 0, length: initialNewline.length))
        scriptureText.append(initialNewline)
        
        // Create common paragraph styles
        let headerStyle = NSMutableParagraphStyle()
        headerStyle.lineSpacing = 4
        headerStyle.paragraphSpacing = 12 // Increased spacing after header
        headerStyle.paragraphSpacingBefore = 35 // Increased spacing before header from 12pt to 35pt
        headerStyle.headIndent = 20 // Add indentation to match verse text
        headerStyle.firstLineHeadIndent = 20 // Add indentation to match verse text
        headerStyle.lineHeightMultiple = 1.3 // Updated to match document line height
        headerStyle.minimumLineHeight = 0
        headerStyle.maximumLineHeight = 0
        
        // Add header (reference and translation)
        let referenceString = NSMutableAttributedString(string: scripture.cleanedReference)
        referenceString.addAttributes([
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: headerStyle
        ], range: NSRange(location: 0, length: referenceString.length))
        scriptureText.append(referenceString)
        
        // Add dot separator
        let dotSeparator = NSMutableAttributedString(string: " · ")
        dotSeparator.addAttributes([
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: headerStyle
        ], range: NSRange(location: 0, length: dotSeparator.length))
        scriptureText.append(dotSeparator)
        
        // Add translation
        let translationString = NSMutableAttributedString(string: "King James Version\n")
        translationString.addAttributes([
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: headerStyle
        ], range: NSRange(location: 0, length: translationString.length))
        scriptureText.append(translationString)
        
        // Format the scripture text based on selected layout
        switch layout {
        case .individualVerses:
            formatIndividualVerses(scripture, scriptureText)
        case .paragraph:
            formatParagraph(scripture, scriptureText)
        case .reference:
            formatReference(scripture, scriptureText)
        }
        
        // --- CLEAN UP TRAILING CONTENT ---
        // Trim ALL trailing whitespace including newlines from the scripture text
        while let lastChar = scriptureText.string.last, lastChar.isWhitespace || lastChar.isNewline {
             scriptureText.deleteCharacters(in: NSRange(location: scriptureText.length - 1, length: 1))
        }
        print("✂️ Trimmed trailing whitespace/newlines from scripture")

        // --- APPLY Final Indentation Fix to Last Paragraph ---
        // Find the last paragraph range within the scriptureText itself
        let scriptureTextNSString = scriptureText.string as NSString // Renamed variable
        let lastContentCharIndex = scriptureTextNSString.length - 1 // Exclude potential trailing newline for range calculation
        
        if lastContentCharIndex >= 0 {
            let lastParaRangeInScripture = scriptureTextNSString.paragraphRange(for: NSRange(location: lastContentCharIndex, length: 0))

            if lastParaRangeInScripture.length > 0 && lastParaRangeInScripture.location < scriptureText.length {
                // Get existing paragraph style from this last paragraph within scriptureText
                let existingStyle = scriptureText.attribute(.paragraphStyle, at: lastParaRangeInScripture.location, effectiveRange: nil) as? NSParagraphStyle

                // Create the consistent style, preserving existing spacing and indentation
                let consistentStyle = NSMutableParagraphStyle()
                if let existing = existingStyle {
                    // Preserve all existing paragraph style properties
                    consistentStyle.lineSpacing = existing.lineSpacing
                    consistentStyle.paragraphSpacing = existing.paragraphSpacing
                    consistentStyle.paragraphSpacingBefore = existing.paragraphSpacingBefore
                    consistentStyle.lineHeightMultiple = existing.lineHeightMultiple
                    consistentStyle.minimumLineHeight = existing.minimumLineHeight
                    consistentStyle.maximumLineHeight = existing.maximumLineHeight
                    consistentStyle.tabStops = existing.tabStops
                    consistentStyle.defaultTabInterval = existing.defaultTabInterval
                    consistentStyle.alignment = existing.alignment
                    
                    // Always preserve the existing indentation values regardless of layout style
                    consistentStyle.headIndent = existing.headIndent
                    consistentStyle.firstLineHeadIndent = existing.firstLineHeadIndent
                } else {
                    // Fallback defaults if no style found (should generally not happen here)
                    consistentStyle.lineSpacing = 4
                    consistentStyle.paragraphSpacing = 12
                    consistentStyle.lineHeightMultiple = 1.2
                    
                    // Use appropriate indentation based on layout
                    if layout == .reference {
                        consistentStyle.headIndent = 170
                        consistentStyle.firstLineHeadIndent = 40
                    } else {
                        consistentStyle.headIndent = 20
                        consistentStyle.firstLineHeadIndent = 20
                    }
                }

                // --- SET SPACE AFTER --- Set 40pt space AFTER the last scripture paragraph
                consistentStyle.paragraphSpacing = 40

                // Apply ONLY the corrected paragraph style to the last paragraph range within scriptureText
                scriptureText.addAttribute(.paragraphStyle, value: consistentStyle, range: lastParaRangeInScripture)
                print("✅ Applied final PARAGRAPH STYLE fix AND 40pt spacing after scripture to range: \(lastParaRangeInScripture)")
            }
        }
        // --- End of Final Indentation Fix ---
        
        // --- START: Define Clean Style for Newline --- 
        // Create a completely clean paragraph style for the newline after scripture
        let cleanNewlineStyle = NSMutableParagraphStyle()
        cleanNewlineStyle.headIndent = 0
        cleanNewlineStyle.firstLineHeadIndent = 0
        cleanNewlineStyle.paragraphSpacing = 0
        cleanNewlineStyle.paragraphSpacingBefore = 0
        // Inherit base alignment, line spacing etc. from default, not scripture
        let defaultStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        cleanNewlineStyle.alignment = defaultStyle.alignment
        cleanNewlineStyle.lineSpacing = defaultStyle.lineSpacing
        cleanNewlineStyle.lineHeightMultiple = defaultStyle.lineHeightMultiple
        cleanNewlineStyle.defaultTabInterval = defaultStyle.defaultTabInterval
        cleanNewlineStyle.tabStops = defaultStyle.tabStops
        
        // Create attributes for the newline, using the clean style and default font/color
        let newlineAttributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: cleanNewlineStyle,
            .font: NSFont(name: "Inter-Regular", size: 15) ?? NSFont.systemFont(ofSize: 15), // Use default body font
            .foregroundColor: NSColor.labelColor // Use default text color
        ]
        // Add any other essential default attributes if needed
        // --- END: Define Clean Style for Newline ---

        // Store the length of the scripture content for marking non-editable
        let scriptureContentLength = scriptureText.length
        
        // --- APPLY Non-Editable Attributes FIRST ---
        if scriptureContentLength > 0 { // Only apply if there is actual scripture content
            scriptureText.addAttribute(DocumentTextView.nonEditableAttribute, value: true, range: NSRange(location: 0, length: scriptureContentLength))
            scriptureText.addAttribute(DocumentTextView.isScriptureBlockQuote, value: true, range: NSRange(location: 0, length: scriptureContentLength))
            print("🔒 Applied scripture attributes FIRST to range: 0 to \(scriptureContentLength)")
        }
        // --- End Apply Non-Editable Attributes FIRST ---
        
        // --- APPLY Visual Spacing to Last Paragraph (After Marking Non-Editable) ---
        var lastParaStyle: NSParagraphStyle?
        if scriptureContentLength > 0 {
            let lastContentCharIndex = scriptureContentLength - 1 // Use stored length
            let lastParaRange = (scriptureText.string as NSString).paragraphRange(
                for: NSRange(location: lastContentCharIndex, length: 0))
            
            // Ensure range is valid before accessing attributes
            if lastParaRange.location != NSNotFound && (lastParaRange.location + lastParaRange.length) <= scriptureContentLength {
                lastParaStyle = scriptureText.attribute(.paragraphStyle, at: lastParaRange.location, effectiveRange: nil) as? NSParagraphStyle
                
                // Preserve styling of the last paragraph while just changing paragraph spacing
                let consistentStyle = NSMutableParagraphStyle()
                if let existing = lastParaStyle {
                    // Copy all attributes from the existing style
                    consistentStyle.lineSpacing = existing.lineSpacing
                    consistentStyle.paragraphSpacing = 40 // Set spacing here for visual appearance
                    consistentStyle.paragraphSpacingBefore = existing.paragraphSpacingBefore
                    consistentStyle.lineHeightMultiple = existing.lineHeightMultiple
                    consistentStyle.minimumLineHeight = existing.minimumLineHeight
                    consistentStyle.maximumLineHeight = existing.maximumLineHeight
                    consistentStyle.tabStops = existing.tabStops
                    consistentStyle.defaultTabInterval = existing.defaultTabInterval
                    consistentStyle.alignment = existing.alignment
                    
                    // Preserve the indentation always
                    consistentStyle.headIndent = existing.headIndent
                    consistentStyle.firstLineHeadIndent = existing.firstLineHeadIndent
                } else {
                    // Fallback with reasonable defaults
                    consistentStyle.paragraphSpacing = 40
                    
                    // Use appropriate indentation based on layout
                    if layout == .reference {
                        consistentStyle.headIndent = 170
                        consistentStyle.firstLineHeadIndent = 40
                    } else {
                        consistentStyle.headIndent = 20
                        consistentStyle.firstLineHeadIndent = 20
                    }
                }
                
                scriptureText.addAttribute(.paragraphStyle, value: consistentStyle, range: lastParaRange)
                print("✅ Applied 40pt visual spacing to final paragraph AFTER marking non-editable")
            } else {
                 print("⚠️ Could not apply visual spacing: Invalid last paragraph range \(lastParaRange) for length \(scriptureContentLength)")
            }
        }
        // --- End Apply Visual Spacing ---

        // Add a single linebreak after scripture
        let finalNewline = NSMutableAttributedString(string: "\n")
        
        // Apply the clean attributes to the newline
        finalNewline.addAttributes(newlineAttributes, range: NSRange(location: 0, length: 1))
        scriptureText.append(finalNewline)
        
        print("📏 Scripture content length: \(scriptureContentLength), Total with newline: \(scriptureText.length)")

        // CRITICAL: Mark ONLY the scripture content as non-editable, EXCLUDING the final newline
        // **This section might now be redundant but kept for safety**
        if scriptureContentLength < scriptureText.length {
            let nonScriptureRange = NSRange(location: scriptureContentLength, length: scriptureText.length - scriptureContentLength)
            // Remove any lingering scripture/non-editable attributes from the final newline
            scriptureText.removeAttribute(DocumentTextView.nonEditableAttribute, range: nonScriptureRange)
            scriptureText.removeAttribute(DocumentTextView.isScriptureBlockQuote, range: nonScriptureRange)
            // Apply the clean attributes to the newline itself to be sure
            scriptureText.setAttributes(newlineAttributes, range: nonScriptureRange)
            print("🧹 Explicitly cleared scripture attributes and applied clean style to final newline")
        }

        // Insert at current position
        let selectedRangeValue = self.selectedRange()
        let mutableContent = NSMutableAttributedString(attributedString: self.attributedString())
        mutableContent.replaceCharacters(in: selectedRangeValue, with: scriptureText)
        
        // Replace entire text content to ensure consistent rendering
        self.textStorage?.beginEditing()
        self.textStorage?.setAttributedString(mutableContent)
        self.textStorage?.endEditing()
        
        // Update cursor position - position cursor AFTER the scripture block
        self.setSelectedRange(NSRange(location: selectedRangeValue.location + scriptureText.length, length: 0))
        
        // Ensure we have consistent formatting for new text after the scripture
        // Set typing attributes to the clean style we defined for the newline
        self.typingAttributes = newlineAttributes
        print("🧹 Set typing attributes to clean style after scripture insertion")
        
        // CRITICAL FIX: Trigger the standard text change notification
        // This will cause the Coordinator's textDidChange method to save the document properly
        if let coordinator = self.coordinator {
            // Manually notify the coordinator of the text change
            coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: self))
            print("💾 Triggered text change notification to save document")
        } else {
            // Fallback if coordinator is not available
            NotificationCenter.default.post(name: NSText.didChangeNotification, object: self)
            print("💾 Posted text change notification directly")
        }
        
        // Force a layout refresh to ensure everything is properly displayed
        self.layoutManager?.ensureLayout(for: self.textContainer!)
        self.needsDisplay = true
    }
    
    // Format scripture as individual verses (each verse on its own line with reference)
    internal func formatIndividualVerses(_ scripture: ScriptureElement, _ scriptureText: NSMutableAttributedString) {
        // Split the text into verses
        let verses = scripture.cleanedText.components(separatedBy: "\n")
        let isSingleVerse = verses.count == 1
        
        // Create fonts using Inter family for consistency
        let verseRefFont = NSFont(name: "Inter-Medium", size: 12) ?? NSFont.systemFont(ofSize: 12, weight: .medium)
        let verseTextFont = NSFont(name: "Inter-Regular", size: 13) ?? NSFont.systemFont(ofSize: 13)
        
        // Create paragraph style for verse references (only needed for multiple verses)
        let verseRefStyle = NSMutableParagraphStyle()
        if !isSingleVerse {
        verseRefStyle.lineSpacing = 4
        verseRefStyle.paragraphSpacing = 2
            verseRefStyle.headIndent = 20      // Add indentation to match verse text
            verseRefStyle.firstLineHeadIndent = 20 // Add indentation to match verse text
            verseRefStyle.lineHeightMultiple = 1.2
            verseRefStyle.minimumLineHeight = 0
            verseRefStyle.maximumLineHeight = 0
        }
        
        // Create paragraph style for verse text with added indentation
        let verseTextStyle = NSMutableParagraphStyle()
        verseTextStyle.lineSpacing = 4
        verseTextStyle.paragraphSpacing = 12 // Add space after the verse text
        verseTextStyle.headIndent = 20       // Add left margin to all lines in verse text
        verseTextStyle.firstLineHeadIndent = 20 // Match the head indent for first line
        verseTextStyle.lineHeightMultiple = 1.2
        verseTextStyle.minimumLineHeight = 0
        verseTextStyle.maximumLineHeight = 0
        
        // Extract book and chapter from reference for constructing references
        let baseRefParts = scripture.cleanedReference.components(separatedBy: ":")
        let bookChapter = baseRefParts.first ?? ""
        
        // Keep track of verse fragments that need to be merged with previous content
        var previousVerseText: String? = nil
        var pendingVerseNumber: String? = nil
        
        // Process each verse
        for (index, verse) in verses.enumerated() {
            if verse.isEmpty { continue }
            
            // Extract verse number and text if possible
            var verseNumber = ""
            var verseText = verse
            
            if let regex = try? NSRegularExpression(pattern: #"\[(\d+)\]\s*(.*)"#),
               let match = regex.firstMatch(in: verse, range: NSRange(verse.startIndex..., in: verse)),
               let verseNumRange = Range(match.range(at: 1), in: verse),
               let verseTextRange = Range(match.range(at: 2), in: verse) {
                verseNumber = String(verse[verseNumRange])
                verseText = String(verse[verseTextRange])
            } else {
                // If regex fails, try to handle other cases
                if verse.hasPrefix("Acts ") || verse.hasPrefix("Genesis ") || verse.hasPrefix("Exodus ") || verse.hasPrefix("Psalm ") || verse.contains(":") {
                    // This appears to be a reference line, not text content
                    
                    // Extract possible verse number
                    let parts = verse.components(separatedBy: ":")
                    if parts.count > 1 {
                        verseNumber = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Check if this is a verse fragment (like "Acts 2:")
                        if verseNumber.isEmpty {
                            // This is a fragment reference with no number, store for next iteration
                            pendingVerseNumber = "fragment"
                            continue
                        }
                        
                        // Normal verse with number, clear pending state
                        pendingVerseNumber = nil
                        previousVerseText = nil
                    } else {
                        // Can't extract a verse number, use index
                        verseNumber = "\(index + 1)"
                    }
                    
                    // No text content on this line, skip rendering
                    if parts.count <= 1 || parts[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        continue
                    }
                } else if pendingVerseNumber != nil {
                    // This is text content for a fragment verse
                    if previousVerseText != nil {
                        // Append to previous content with a space
                        previousVerseText! += " " + verse
                        continue
                    } else {
                        // Start collecting content for this fragment
                        previousVerseText = verse
                        
                        // Use a default verse number if we can't determine one
                        if verseNumber.isEmpty {
                            // Try to use the last verse number + 1
                            let lastVerseIndex = index > 0 ? index - 1 : 0
                            if lastVerseIndex < verses.count {
                                let lastVerse = verses[lastVerseIndex]
                                if let regex = try? NSRegularExpression(pattern: #"\[(\d+)\]"#),
                                   let match = regex.firstMatch(in: lastVerse, range: NSRange(lastVerse.startIndex..., in: lastVerse)),
                                   let lastVerseNumRange = Range(match.range(at: 1), in: lastVerse) {
                                    let lastVerseNum = String(lastVerse[lastVerseNumRange])
                                    if let lastNum = Int(lastVerseNum) {
                                        verseNumber = "\(lastNum + 1)"
                                    } else {
                                        verseNumber = "\(index + 1)"
                                    }
                                } else {
                                    verseNumber = "\(index + 1)"
                                }
                            } else {
                                verseNumber = "\(index + 1)"
                            }
                        }
                    }
                } else if isSingleVerse {
                    // For single verse, use the verse number from the reference
                    if let lastPart = scripture.cleanedReference.components(separatedBy: ":").last {
                        verseNumber = lastPart.trimmingCharacters(in: .whitespacesAndNewlines)
                        if verseNumber.isEmpty {
                            verseNumber = "1" // Default for empty verse number
                        }
                    }
                } else {
                    // Can't determine verse number, use index
                    verseNumber = "\(index + 1)"
                }
            }
            
            // If this was a fragment verse, use the collected text
            if pendingVerseNumber != nil && previousVerseText != nil {
                verseText = previousVerseText!
                pendingVerseNumber = nil
                previousVerseText = nil
            }
            
            // Only add the verse reference line if there are multiple verses
            if !isSingleVerse {
                let verseRefString = NSMutableAttributedString(string: "\(bookChapter):\(verseNumber)\n")
                verseRefString.addAttributes([
                    .font: verseRefFont,
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: verseRefStyle,
                    .kern: 0.0 // Explicit kerning to ensure consistent character spacing
                ], range: NSRange(location: 0, length: verseRefString.length))
                scriptureText.append(verseRefString)
            }
            
            // If this is the last verse, make sure to apply the correct paragraph style
            if index == verses.count - 1 {
                // Create a special style for the last verse to ensure consistent indentation
                let lastVerseStyle = NSMutableParagraphStyle()
                lastVerseStyle.lineSpacing = 4
                lastVerseStyle.paragraphSpacing = 12 
                lastVerseStyle.headIndent = 20       // Ensure indentation is consistent
                lastVerseStyle.firstLineHeadIndent = 20 // Ensure indentation is consistent
                lastVerseStyle.lineHeightMultiple = 1.2
                lastVerseStyle.minimumLineHeight = 0
                lastVerseStyle.maximumLineHeight = 0
                
                // Add verse text with special formatting for last verse
                let verseTextString = NSMutableAttributedString(
                    string: verseText + (isSingleVerse ? "" : "\n"),
                    attributes: [
                        .font: verseTextFont,
                        .foregroundColor: NSColor.labelColor,
                        .paragraphStyle: lastVerseStyle,
                        .kern: 0.0 // Explicit kerning to ensure consistent character spacing
                    ]
                )
                scriptureText.append(verseTextString)
            } else {
                // Add verse text for non-last verses
            let verseTextString = NSMutableAttributedString(
                string: verseText + (isSingleVerse ? "" : "\n"),
                attributes: [
                    .font: verseTextFont,
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: verseTextStyle,
                    .kern: 0.0 // Explicit kerning to ensure consistent character spacing
                ]
            )
            scriptureText.append(verseTextString)
            }
        }
    }
    
    // Format scripture as continuous paragraph with verse numbers in brackets
    internal func formatParagraph(_ scripture: ScriptureElement, _ scriptureText: NSMutableAttributedString) {
        // Create font using Inter family for consistency
        let paragraphFont = NSFont(name: "Inter-Regular", size: 13) ?? NSFont.systemFont(ofSize: 13)
        
        // Create paragraph style for the text with indentation
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8
        paragraphStyle.headIndent = 20       // Add indentation to match other formats
        paragraphStyle.firstLineHeadIndent = 20 // Add indentation to match other formats
        paragraphStyle.lineHeightMultiple = 1.2  // Explicitly set line height multiple
        paragraphStyle.minimumLineHeight = 0     // Allow natural line height
        paragraphStyle.maximumLineHeight = 0     // Allow natural line height
        
        // Special style for the last paragraph to ensure consistent indentation
        let lastParagraphStyle = NSMutableParagraphStyle()
        lastParagraphStyle.lineSpacing = 4
        lastParagraphStyle.paragraphSpacing = 8
        lastParagraphStyle.headIndent = 20       // Ensure indentation is consistent for last line
        lastParagraphStyle.firstLineHeadIndent = 20 // Ensure indentation is consistent for last line
        lastParagraphStyle.lineHeightMultiple = 1.2
        lastParagraphStyle.minimumLineHeight = 0
        lastParagraphStyle.maximumLineHeight = 0
        
        // Process the text to ensure verse numbers are in brackets
        let verses = scripture.cleanedText.components(separatedBy: "\n")
        var formattedVerses: [String] = []
        
        for (index, verse) in verses.enumerated() {
            if verse.isEmpty { continue }
            
            // Extract verse number and text if possible
            var verseNumber = "\(index + 1)"
            var verseText = verse
            
            if let regex = try? NSRegularExpression(pattern: #"\[(\d+)\]\s*(.*)"#),
               let match = regex.firstMatch(in: verse, range: NSRange(verse.startIndex..., in: verse)),
               let verseNumRange = Range(match.range(at: 1), in: verse),
               let verseTextRange = Range(match.range(at: 2), in: verse) {
                verseNumber = String(verse[verseNumRange])
                verseText = String(verse[verseTextRange])
            }
            
            // Format each verse with brackets
            formattedVerses.append("[\(verseNumber)] \(verseText)")
        }
        
        // Join verses into a single paragraph
        let formattedText = formattedVerses.joined(separator: " ")
        
        // Add to scripture text
        let textString = NSMutableAttributedString(string: formattedText)
        
        // Use lastParagraphStyle for consistent indentation
        textString.addAttributes([
            .font: paragraphFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: lastParagraphStyle,
            .kern: 0.0 // Explicit kerning to ensure consistent character spacing
        ], range: NSRange(location: 0, length: textString.length))
        scriptureText.append(textString)
    }
    
    // Format scripture in two-column layout with references on left
    internal func formatReference(_ scripture: ScriptureElement, _ scriptureText: NSMutableAttributedString) {
        // Create fonts using Inter family for consistency
        let referenceFont = NSFont(name: "Inter-Medium", size: 13) ?? NSFont.systemFont(ofSize: 13, weight: .medium)
        let textFont = NSFont(name: "Inter-Regular", size: 13) ?? NSFont.systemFont(ofSize: 13)
        
        // Split the text into verses
        let verses = scripture.cleanedText.components(separatedBy: "\n")
        
        // Extract book name and chapter number from reference (e.g. "Acts 2:38-43")
        let parts = scripture.cleanedReference.components(separatedBy: ":")
        let bookAndChapter = parts.first?.components(separatedBy: " ") ?? []
        
        let bookName: String
        let chapterNumber: String
        
        if bookAndChapter.count >= 2 {
            bookName = bookAndChapter[0]
            chapterNumber = bookAndChapter[1]
        } else {
            bookName = "Acts"
            chapterNumber = "2"
        }
        
        // Create a consistent paragraph style for all lines including the last line
        let referenceLayoutStyle = NSMutableParagraphStyle()
        referenceLayoutStyle.lineSpacing = 6 // Decreased from 8
        referenceLayoutStyle.paragraphSpacing = 12 // Increased from 8 to add more space between verses
        referenceLayoutStyle.headIndent = 170        // Increased to accommodate more spacing after separator
        referenceLayoutStyle.firstLineHeadIndent = 40 // Increased to indent the entire line including reference
        referenceLayoutStyle.lineHeightMultiple = 1.2  // Explicitly set line height multiple
        referenceLayoutStyle.minimumLineHeight = 0     // Allow natural line height
        referenceLayoutStyle.maximumLineHeight = 0     // Allow natural line height
        
        // Create tab stops for all lines - adjusted to add more space between separator and content
        let referenceTab = NSTextTab(textAlignment: .right, location: 140, options: [:])
        let separatorTab = NSTextTab(textAlignment: .center, location: 150, options: [:])
        let contentTab = NSTextTab(textAlignment: .left, location: 170, options: [:])  // Increased from 160 to 170
        referenceLayoutStyle.tabStops = [referenceTab, separatorTab, contentTab]
        
        // Process each verse
        for (index, verse) in verses.enumerated() {
            // Skip empty verses
            if verse.isEmpty { continue }
            
            // Extract verse number and text if possible
            var verseNumber = "\(index + 1)"
            var verseText = verse
            
            if let regex = try? NSRegularExpression(pattern: #"\[(\d+)\]\s*(.*)"#),
               let match = regex.firstMatch(in: verse, range: NSRange(verse.startIndex..., in: verse)),
               let verseNumRange = Range(match.range(at: 1), in: verse),
               let verseTextRange = Range(match.range(at: 2), in: verse) {
                verseNumber = String(verse[verseNumRange])
                verseText = String(verse[verseTextRange])
            }
            
            // Format with proper reference style and extra spacing after the separator
            let formattedLine = "\(bookName) \(chapterNumber):\(verseNumber)\t|\t\t\(verseText)\n"
            
            let lineString = NSMutableAttributedString(string: formattedLine)
            
            // Apply consistent font and paragraph style for all lines
            lineString.addAttributes([
                .font: textFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: referenceLayoutStyle,
                .kern: 0.0 // Explicit kerning to ensure consistent character spacing
            ], range: NSRange(location: 0, length: lineString.length))
            
            // Make the reference bold
            if let rangeOfTab = formattedLine.range(of: "\t") {
                let referenceLength = formattedLine.distance(from: formattedLine.startIndex, to: rangeOfTab.lowerBound)
                lineString.addAttributes([
                    .font: referenceFont,
                    .kern: 0.0 // Maintain consistent kerning in the reference part
                ], range: NSRange(location: 0, length: referenceLength))
            }
            
            scriptureText.append(lineString)
        }
    }

    // MARK: - Scripture Attribute Restoration

    internal func restoreScriptureAttributes() {
        // TODO: User - Please find the original implementation of this method
        // from version control and paste it here. This is crucial for
        // ensuring scripture blocks are correctly identified and protected
        // when a document is loaded or updated.
        print("⚠️ restoreScriptureAttributes() is currently a stub. Please implement it.")
    }
}
#endif 