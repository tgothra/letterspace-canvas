import SwiftUI
import PDFKit
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// PDF View Wrapper for rendering PDF documents
#if os(macOS)
struct PDFViewWrapper: NSViewRepresentable {
    let document: PDFDocument
    let currentPage: Int
    
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.backgroundColor = .white
        
        if document.pageCount > currentPage {
            view.go(to: document.page(at: currentPage)!)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document !== document {
            nsView.document = document
        }
        
        if document.pageCount > currentPage, 
           let page = document.page(at: currentPage),
           nsView.currentPage != page {
            nsView.go(to: page)
        }
    }
}
#elseif os(iOS)
struct PDFViewWrapper: UIViewRepresentable {
    let document: PDFDocument
    let currentPage: Int
    
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.backgroundColor = .white
        
        if document.pageCount > currentPage {
            view.go(to: document.page(at: currentPage)!)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document {
            uiView.document = document
        }
        
        if document.pageCount > currentPage, 
           let page = document.page(at: currentPage),
           uiView.currentPage != page {
            uiView.go(to: page)
        }
    }
}
#endif 