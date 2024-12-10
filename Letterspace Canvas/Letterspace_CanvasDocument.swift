import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var exampleText: UTType {
        UTType(importedAs: "com.example.plain-text")
    }
}

struct Letterspace_CanvasDocument: FileDocument, Codable {
    var elements: [DocumentElement]
    var title: String
    
    init(title: String = "", elements: [DocumentElement] = []) {
        self.title = title
        if elements.isEmpty {
            // Create default layout
            self.elements = [
                DocumentElement(type: .headerImage, content: "", placeholder: "Add Header Image"),
                DocumentElement(type: .title, content: "", placeholder: "Untitled")
            ]
        } else {
            self.elements = elements
        }
    }
    
    // Update document title when header content changes
    mutating func updateTitleFromHeader() {
        if let headerElement = elements.first(where: { $0.type == .header }),
           !headerElement.content.isEmpty {
            self.title = headerElement.content
        }
    }
    
    static var readableContentTypes: [UTType] { [.exampleText] }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let document = try? JSONDecoder().decode(Letterspace_CanvasDocument.self, from: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.title = document.title
        self.elements = document.elements
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(self)
        return .init(regularFileWithContents: data)
    }
} 