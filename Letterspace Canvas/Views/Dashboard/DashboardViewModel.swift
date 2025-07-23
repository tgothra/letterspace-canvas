import SwiftUI

// MARK: - Dashboard ViewModel

class DashboardViewModel: ObservableObject {
    @Published var selectedColumn: ListColumn = .name
    @Published var sortAscending = true
    @Published var dateFilterType: DateFilterType = .modified
    @Published var documents: [Letterspace_CanvasDocument] = []
    @Published var selectedDocuments: Set<String> = []
    @Published var pinnedDocuments: Set<String> = []
    @Published var isSelectionMode: Bool = false
    @Published var wipDocuments: Set<String> = []
    @Published var visibleColumns: Set<String> = Set(ListColumn.allColumns.map { $0.id })
    @Published var calendarDocuments: Set<String> = []
    @Published var folders: [Folder] = []
    @Published var selectedTags: Set<String> = []
    @Published var selectedFilterColumn: String? = nil
    @Published var selectedFilterCategory: String = "Filter"
    @Published var showTagManager = false
    @Published var isHoveringInfo = false
    @Published var hoveredTag: String? = nil
    @Published var isViewButtonHovering = false
    @Published var showDetailsCard = false
    @Published var selectedDetailsDocument: Letterspace_CanvasDocument?
    @Published var showShareSheet = false
    @Published var refreshTrigger: Bool = false
    @Published var tableRefreshID = UUID()
    @Published var isLoadingDocuments: Bool = true
    @Published var isSwipeDownNavigation: Bool = false
    @Published var documentToShowInSheet: Letterspace_CanvasDocument?
    @Published var isPinnedExpanded: Bool = false
    @Published var isWIPExpanded: Bool = false
    @Published var isSchedulerExpanded: Bool = false
    @Published var showPinnedModal = false
    @Published var showWIPModal = false
    @Published var showSchedulerModal = false
    @Published var calendarModalData: ModalDisplayData? = nil
    @Published var selectedCarouselIndex: Int = 0
    @Published var carouselOffset: CGFloat = 0
    @Published var dragOffset: CGFloat = 0
    @Published var isReordering: Bool = false
    @Published var reorderDragOffset: CGSize = .zero
    @Published var isFirstLaunch: Bool = true
    @Published var isLandscapeMode: Bool = false
    @Published var shouldShowExpandButtons: Bool = false
    @Published var carouselSections: [(title: String, view: AnyView)] = []
    @Published var draggedCardIndex: Int? = nil
    @Published var draggedCardOffset: CGSize = .zero
    @Published var reorderMode: Bool = false
    
    // Scroll offsets
    @Published var pinnedScrollOffset: CGFloat = 0
    @Published var wipScrollOffset: CGFloat = 0
    @Published var calendarScrollOffset: CGFloat = 0
    @Published var shouldFlashPinnedScroll = false
    
    // MARK: - Methods
    
    func loadDocuments() {
        // Document loading logic
        isLoadingDocuments = false
    }
    
    func refreshDocuments() {
        refreshTrigger.toggle()
        tableRefreshID = UUID()
    }
    
    func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            selectedDocuments.removeAll()
        }
    }
} 