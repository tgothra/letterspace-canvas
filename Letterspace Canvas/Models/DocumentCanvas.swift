import Foundation
import SwiftUI

// Represents a block in the continuous canvas
enum CanvasBlockType: Equatable {
    case text(NSAttributedString)  // For continuous text flow
    case element(DocumentElement)   // For existing block types
    
    static func == (lhs: CanvasBlockType, rhs: CanvasBlockType) -> Bool {
        switch (lhs, rhs) {
        case (.text(let lhs), .text(let rhs)):
            return lhs.string == rhs.string
        case (.element(let lhs), .element(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

// Represents a section in the document
enum DocumentSection: Identifiable, Equatable {
    case fixed(DocumentElement)
    case canvas([CanvasBlock])
    
    var id: UUID {
        switch self {
        case .fixed(let element):
            return element.id
        case .canvas:
            return UUID()
        }
    }
}

// Represents a block in the canvas
struct CanvasBlock: Identifiable, Equatable {
    let id = UUID()
    var type: CanvasBlockType
    var position: Int  // Position in the continuous flow
    
    static func == (lhs: CanvasBlock, rhs: CanvasBlock) -> Bool {
        lhs.id == rhs.id && lhs.position == rhs.position && lhs.type == rhs.type
    }
}

// Main document canvas structure
class DocumentCanvas: ObservableObject {
    @Published var sections: [DocumentSection] = []
    
    // Helper to get fixed elements (header image and title)
    var fixedElements: [DocumentElement] {
        sections.compactMap { section in
            if case .fixed(let element) = section {
                return element
            }
            return nil
        }
    }
    
    // Helper to get canvas blocks
    var canvasBlocks: [CanvasBlock] {
        sections.compactMap { section in
            if case .canvas(let blocks) = section {
                return blocks
            }
            return []
        }.flatMap { $0 }
    }
    
    // Initialize from existing document
    init(from document: Letterspace_CanvasDocument) {
        // Separate fixed elements (header image and title)
        let fixedElements = document.elements.filter { 
            $0.type == .headerImage || $0.type == .title 
        }.map { DocumentSection.fixed($0) }
        
        // Convert remaining elements to canvas blocks
        let canvasBlocks = document.elements
            .filter { $0.type != .headerImage && $0.type != .title }
            .enumerated()
            .map { index, element in
                if element.type == .textBlock {
                    return CanvasBlock(
                        type: .text(NSAttributedString(
                            string: element.content,
                            attributes: [
                                .font: NSFont.systemFont(ofSize: 16),
                                .foregroundColor: NSColor.textColor
                            ]
                        )),
                        position: index
                    )
                } else {
                    return CanvasBlock(
                        type: .element(element),
                        position: index
                    )
                }
            }
        
        sections = fixedElements + [.canvas(canvasBlocks)]
    }
    
    // Convert back to original document format
    func toDocument() -> Letterspace_CanvasDocument {
        let elements = fixedElements + canvasBlocks.compactMap { block in
            switch block.type {
            case .text(let attributedString):
                var element = DocumentElement(type: .textBlock)
                element.content = attributedString.string
                element.attributedContent = attributedString
                return element
            case .element(let element):
                return element
            }
        }
        
        return Letterspace_CanvasDocument(
            title: fixedElements.first { $0.type == .title }?.content ?? "Untitled",
            elements: elements
        )
    }
    
    // MARK: - Block Movement
    
    func moveBlock(from sourceIndex: Int, to destinationIndex: Int) {
        let canvasSection = sections.first(where: { 
            if case .canvas = $0 { return true }
            return false
        })
        
        guard case .canvas(var blocks) = canvasSection else { return }
        
        // Get the block to move
        let block = blocks.remove(at: sourceIndex)
        
        // Insert at new position
        blocks.insert(block, at: destinationIndex)
        
        // Update positions
        for i in 0..<blocks.count {
            blocks[i].position = i
        }
        
        // Update the section
        if let sectionIndex = sections.firstIndex(where: { section in
            if case .canvas = section { return true }
            return false
        }) {
            sections[sectionIndex] = .canvas(blocks)
        }
    }
    
    // MARK: - Block Operations
    
    func splitBlock(at position: Int) {
        let canvasSection = sections.first(where: { 
            if case .canvas = $0 { return true }
            return false
        })
        
        guard case .canvas(var blocks) = canvasSection else { return }
        
        // Find the block containing the split position
        if let blockIndex = blocks.firstIndex(where: { _ in true }) {
            if case .text(let text) = blocks[blockIndex].type {
                // Split the text
                let firstHalf = NSAttributedString(attributedString: text.attributedSubstring(from: NSRange(location: 0, length: position)))
                let secondHalf = NSAttributedString(attributedString: text.attributedSubstring(from: NSRange(location: position, length: text.length - position)))
                
                // Create two new blocks
                blocks[blockIndex].type = .text(firstHalf)
                blocks.insert(
                    CanvasBlock(type: .text(secondHalf), position: blocks[blockIndex].position + 1),
                    at: blockIndex + 1
                )
                
                // Update positions
                for i in (blockIndex + 2)..<blocks.count {
                    blocks[i].position += 1
                }
                
                // Update the section
                if let sectionIndex = sections.firstIndex(where: { section in
                    if case .canvas = section { return true }
                    return false
                }) {
                    sections[sectionIndex] = .canvas(blocks)
                }
            }
        }
    }
    
    func mergeBlocks(at firstIndex: Int, with secondIndex: Int) {
        let canvasSection = sections.first(where: { 
            if case .canvas = $0 { return true }
            return false
        })
        
        guard case .canvas(var blocks) = canvasSection else { return }
        
        guard firstIndex >= 0 && secondIndex < blocks.count,
              case .text(let firstText) = blocks[firstIndex].type,
              case .text(let secondText) = blocks[secondIndex].type else {
            return
        }
        
        // Combine the text
        let mutableText = NSMutableAttributedString(attributedString: firstText)
        mutableText.append(secondText)
        
        // Update the first block and remove the second
        blocks[firstIndex].type = .text(mutableText)
        blocks.remove(at: secondIndex)
        
        // Update positions
        for i in secondIndex..<blocks.count {
            blocks[i].position -= 1
        }
        
        // Update the section
        if let sectionIndex = sections.firstIndex(where: { section in
            if case .canvas = section { return true }
            return false
        }) {
            sections[sectionIndex] = .canvas(blocks)
        }
    }
    
    func updateText(_ attributedString: NSAttributedString, at position: Int) {
        if let sectionIndex = sections.firstIndex(where: { section in
            if case .canvas = section { return true }
            return false
        }) {
            if case .canvas(var blocks) = sections[sectionIndex] {
                if let blockIndex = blocks.firstIndex(where: { $0.position == position }) {
                    blocks[blockIndex].type = .text(attributedString)
                    sections[sectionIndex] = .canvas(blocks)
                }
            }
        }
    }
    
    func insertBlock(_ block: CanvasBlock, at position: Int) {
        let canvasSection = sections.first(where: { 
            if case .canvas = $0 { return true }
            return false
        })
        
        guard case .canvas(var blocks) = canvasSection else { return }
        
        blocks.insert(block, at: position)
        
        // Update positions
        for i in position..<blocks.count {
            blocks[i].position = i
        }
        
        if let sectionIndex = sections.firstIndex(where: { section in
            if case .canvas = section { return true }
            return false
        }) {
            sections[sectionIndex] = .canvas(blocks)
        }
    }
    
    func insertNewBlock(_ type: ElementType, at index: Int) {
        let canvasSection = sections.first(where: { 
            if case .canvas = $0 { return true }
            return false
        })
        
        guard case .canvas(var blocks) = canvasSection else { return }
        
        // Create new element
        let element = DocumentElement(type: type)
        let block = CanvasBlock(type: .element(element), position: index)
        
        // Insert block
        blocks.insert(block, at: index)
        
        // Update positions
        for i in index..<blocks.count {
            blocks[i].position = i
        }
        
        // Update the section
        if let sectionIndex = sections.firstIndex(where: { section in
            if case .canvas = section { return true }
            return false
        }) {
            withAnimation {
                sections[sectionIndex] = .canvas(blocks)
                objectWillChange.send()
            }
        }
        
        // Notify observers of the change
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("DocumentCanvasDidUpdate"), object: nil)
        }
    }
} 