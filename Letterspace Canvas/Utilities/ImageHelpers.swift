import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
func loadHeaderImage(for document: Letterspace_CanvasDocument) -> NSImage? {
    guard let headerElement = document.elements.first(where: { $0.type == .headerImage }), !headerElement.content.isEmpty, let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else { return nil }
    let documentPath = appDirectory.appendingPathComponent("\(document.id)")
    let imagesPath = documentPath.appendingPathComponent("Images")
    let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
    return NSImage(contentsOf: imageUrl)
}
#else
func loadHeaderImage(for document: Letterspace_CanvasDocument) -> UIImage? {
    guard let headerElement = document.elements.first(where: { $0.type == .headerImage }), !headerElement.content.isEmpty, let appDirectory = Letterspace_CanvasDocument.getAppDocumentsDirectory() else { return nil }
    let documentPath = appDirectory.appendingPathComponent("\(document.id)")
    let imagesPath = documentPath.appendingPathComponent("Images")
    let imageUrl = imagesPath.appendingPathComponent(headerElement.content)
    return UIImage(contentsOfFile: imageUrl.path)
}
#endif
