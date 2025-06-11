import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        // Placeholder for the view content
        Text("Home View Content")
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

class HomeViewModel: ObservableObject {
    // Placeholder for the view model
}

class DocumentTable: NSTableView {
    // Placeholder for the document table

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        // ... (existing setup for customTableView) ...

        // Enhanced scroll view configuration
        // ... (existing scrollerStyle, etc.) ...
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true // Keep autohiding or set to false if always visible
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false // Ensure background is clear

        // *** ADD THIS: Set scroller insets ***
        // Reserve 24 points on the right for padding + scroller
        // Use 0 for other sides unless specific insets are needed there
        scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: -24)


        // Configure table view
        // ... (existing tableView setup) ...
        customTableView.headerView?.layer?.backgroundColor = NSColor.clear.cgColor

        // Set up context menu handlers
        // ... (existing context menu setup) ...

        // Configure scroll view documentView
        scrollView.documentView = customTableView

        // Remove legacy scroller style if previously set, rely on insets
        // if let verticalScroller = scrollView.verticalScroller {
        //     verticalScroller.controlSize = .regular
        //     verticalScroller.scrollerStyle = .legacy // Remove or comment out
        // }

        // Set up hover tracking
        // ... (existing hover setup) ...

        // Add notification observer for window resize
        // ... (existing notification setup) ...

        // Initialize column widths after the view is loaded
        // ... (existing dispatch async for updateColumnWidths) ...

        return scrollView
    }

    // ... inside updateNSView ...
    // No changes needed here for this specific fix, but ensure it uses scrollView.bounds.width

    // ... inside DocumentTable.Coordinator ...
    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        // ... existing properties ...

        func updateColumnWidths() {
            // Ensure tableView and scrollView exist
            guard let tableView = tableView, let scrollView = tableView.enclosingScrollView else { return }

            // Defer updates during live resize
            // if scrollView.inLiveResize { ... } // Keep deferral logic

            CATransaction.begin()
            CATransaction.setDisableActions(true)

            // --- Use Content View Bounds ---
            // Use the content view's bounds, which respects scrollerInsets
            let availableContentWidth = scrollView.contentView.bounds.width

            let statusWidth: CGFloat = 110
            // No need to manually subtract scroller or external padding here
            // as availableContentWidth already accounts for the inset area.
            let remainingWidth = max(0, availableContentWidth - statusWidth)

            let visibleColumns = tableView.tableColumns.filter {
                $0.identifier.rawValue != "status" && self.parent.visibleColumns.contains($0.identifier.rawValue)
            }

            if visibleColumns.isEmpty || remainingWidth <= 0 {
                CATransaction.commit()
                return
            }

            // --- Restore Flex Proportion Calculation ---
            let totalFlexProportion: CGFloat = visibleColumns.reduce(0) { sum, column in
                 let columnId = column.identifier.rawValue
                 let listColumn = ListColumn.allColumns.first { $0.id == columnId } ?? ListColumn.name // Default to name flex
                 return sum + listColumn.flexProportion()
            }
            // Avoid division by zero
            guard totalFlexProportion > 0 else {
                CATransaction.commit()
                return
            }
            // --- End Flex Proportion Calculation ---


            // Distribute remaining width efficiently
            let nameColumn = visibleColumns.first { $0.identifier.rawValue == "name" }
            var remainingFlexWidth = remainingWidth

            // Assign widths to non-name columns
            for column in visibleColumns where column.identifier.rawValue != "name" {
                let columnId = column.identifier.rawValue
                guard let listColumn = ListColumn.allColumns.first(where: { $0.id == columnId }) else { continue }
                let proportion = listColumn.flexProportion() / totalFlexProportion
                let calculatedWidth = remainingWidth * proportion
                let newWidth = max(listColumn.width, calculatedWidth) // Use listColumn.width as min

                if abs(column.width - newWidth) > 1 {
                    column.width = newWidth
                }
                remainingFlexWidth -= column.width // Use actual assigned width
            }

            // Assign remaining to name column
            if let nameColumn = nameColumn {
                let minNameWidth: CGFloat = 200
                let newWidth = max(minNameWidth, remainingFlexWidth)
                if abs(nameColumn.width - newWidth) > 1 {
                    nameColumn.width = newWidth
                }
            }

            CATransaction.commit()
        }

        // ... rest of Coordinator ...
    }
    // ... rest of DocumentTable ...
}

class HomeView_Previews: PreviewProvider {
    static var previews: some View {
        // Placeholder for the preview
    }
} 