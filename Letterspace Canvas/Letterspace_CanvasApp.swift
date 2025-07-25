//
//  Letterspace_CanvasApp.swift
//  Letterspace Canvas
//
//  Created by Timothy Gothra on 11/26/24.
//

import SwiftUI

#if os(macOS)
import AppKit
// Add an AppDelegate to handle application lifecycle events
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidBecomeActive(_ notification: Notification) {
        // Add a small delay to ensure the view hierarchy is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.safelyResetTrackingState()
            
            // Refresh document list when app becomes active
            self.refreshDocumentList()
            
            // Hide window buttons that appeared after our changes
            self.hideWindowButtons()
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check for text subsystem reset flag
        checkForTextSubsystemReset()
        
        // Enable debug visualization for text views if the flag is set
        if UserDefaults.standard.bool(forKey: "com.letterspace.enableDebugBorders") {
            enableTextViewDebugging()
        }
        
        // Refresh documents after app launch - with slightly longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshDocumentList()
            
            // Hide window buttons that appeared after our changes
            self.hideWindowButtons()
        }
    }
    
    // Add a method to hide window buttons
    private func hideWindowButtons() {
        NSApp.windows.forEach { window in
            // Only hide buttons for panels and floating windows, not the main app window
            if window.isFloatingPanel || window.level.rawValue > NSWindow.Level.normal.rawValue || window.styleMask.contains(.nonactivatingPanel) {
                window.hideStandardButtons()
            }
        }
    }
    
    // Add a helper method to refresh document list
    private func refreshDocumentList() {
        // Post notification to refresh document list
        NotificationCenter.default.post(name: NSNotification.Name("DocumentListDidUpdate"), object: nil)
        print("AppDelegate triggered DocumentListDidUpdate notification")
        
        // Also clear any document cache to ensure fresh loading
        DocumentCacheManager.shared.clearCache()
    }
    
    private func safelyResetTrackingState() {
        guard let window = NSApp.windows.first(where: { $0.isKeyWindow }),
              let contentView = window.contentView else {
            print("Warning: Could not find key window or content view")
            return
        }
        
        // Search for NSTableView (formerly TrackingTableView)
        if let tableView = findTableView(in: contentView) { // Renamed function for clarity
            // Reset the details popup flag - These properties do not exist on NSTableView
            // tableView.isDetailsPopupOpen = false // TODO: Remove or adapt this logic
            // tableView.isCalendarPopupOpen = false // TODO: Remove or adapt this logic
            
            // Force update tracking areas - This might behave differently or not be needed for NSTableView
            tableView.updateTrackingAreas()
            print("Successfully reset tracking state for NSTableView") // Updated log message
        } else {
            print("No NSTableView found in view hierarchy") // Updated log message
        }
    }
    
    // Helper method to find NSTableView
    private func findTableView(in view: NSView) -> NSTableView? { // Renamed and changed return type
        // Check if the current view is an NSTableView
        if let tableView = view as? NSTableView { // Changed type cast
            return tableView
        }
        
        // Recursively check subviews
        for subview in view.subviews {
            if let found = findTableView(in: subview) { // Recursive call uses new name/type
                return found
            }
        }
        
        return nil
    }
}
#endif

@main
struct Letterspace_CanvasApp: App {
    @State private var document = Letterspace_CanvasDocument()
    private let appearanceController = AppearanceController.shared
    
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Keep the original NSView-based DocumentTableWrapper for macOS
    // It might be defined lower in this file or in another file like HomeView.swift
    #elseif os(iOS)
    @UIApplicationDelegateAdaptor(iPadAppDelegate.self) var appDelegate
    // For iOS, we will need an alternative to DocumentTableWrapper if it was used globally
    // or ensure that views like HomeView use SwiftUI native lists or a UIViewRepresentable for UITableView.
    
    // iOS 26 Enhancement: Initialize Siri integration
    @available(iOS 26.0, *)
    private var siriService: SiriIntentService {
        SiriIntentService.shared
    }
    #endif
    
    init() {
        // Fonts are now automatically loaded via Info.plist UIAppFonts
        
        // Add notification observer for document loading
        #if os(macOS)
        NotificationCenter.default.addObserver(forName: NSNotification.Name("DocumentDidLoad"), object: nil, queue: .main) { _ in
            // Invalidate view caches when a document is loaded
            DispatchQueue.main.async {
                if let window = NSApp.windows.first(where: { $0.isKeyWindow }),
                   let contentView = window.contentView {
                    contentView.invalidateDescendantViewsCache()
                }
            }
        }
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(document: $document)
                // Conditional frame modifiers for macOS
                #if os(macOS)
                .frame(minWidth: 1200, minHeight: 800)
                .frame(idealWidth: 1440, idealHeight: 900)
                #endif
                .withTheme()
                .ignoresSafeArea() // .ignoresSafeArea() is generally fine for both
                // Apply the color scheme preference
                .preferredColorScheme(appearanceController.colorScheme)
                .onAppear {
                    // Set appearance when app first loads
                    appearanceController.setAppearance()
                }
        }
        // Conditional window styling for macOS
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1440, height: 900)
        #endif
    }
}

// Conditionally compile DocumentTableWrapper for macOS only
#if os(macOS)
// This should match the definition in HomeView.swift (or wherever it is)
struct DocumentTableWrapper: NSViewRepresentable {
    @State private var tableViewInstance = NSTableView() // Changed TrackingTableView to NSTableView

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        // Use the State variable instance here
        let tableView = self.tableViewInstance // Changed TrackingTableView to NSTableView (implicitly via tableViewInstance)
        
        // ... (rest of your existing makeNSView setup for tableView and scrollView) ...
        
        // Example setup (replace with your actual column/delegate setup):
        tableView.headerView = NSTableHeaderView()
        tableView.usesAlternatingRowBackgroundColors = true
        // Add columns, set delegate, datasource etc.
        // tableView.delegate = context.coordinator
        // tableView.dataSource = context.coordinator
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        return scrollView
    }

    // Add the required updateNSView function
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Update the NSView based on state changes if necessary.
        // For example, reloading data if documents change and the coordinator handles it:
        // if let tableView = nsView.documentView as? NSTableView {
        //     tableView.reloadData()
        // }
    }

    // Add makeCoordinator if you need delegate/datasource methods
    // func makeCoordinator() -> Coordinator {
    //     Coordinator(self)
    // }
    //
    // class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
    //     var parent: DocumentTableWrapper
    //     init(_ parent: DocumentTableWrapper) {
    //         self.parent = parent
    //     }
    //     // Implement delegate/datasource methods here
    // }

} // Line 106: End of struct - Conformance fixed by adding updateNSView
#endif
