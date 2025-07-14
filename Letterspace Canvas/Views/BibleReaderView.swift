import SwiftUI

#if os(iOS)
import UIKit
#endif

// Data structures for organizing Bible books
struct BibleSection {
    let testament: String
    let groups: [BibleGroup]
}

struct BibleGroup {
    let name: String
    let books: [(String, Int)] // (book name, chapter count)
}

// Book information structure
struct BookInfo {
    let writers: String
    let timeFrame: String
    let themes: String
    let keyCharacters: String
    let summary: String
}

// Sample book information database
func getBookInfo(for book: String) -> BookInfo {
    let bookInfoMap: [String: BookInfo] = [
        // Pentateuch / Law
        "Genesis": BookInfo(
            writers: "Moses",
            timeFrame: "1446-1406 BC",
            themes: "Creation, Fall, Covenant, Redemption",
            keyCharacters: "Adam, Eve, Noah, Abraham, Isaac, Jacob, Joseph",
            summary: "The book of beginnings - creation, humanity's fall, and God's covenant with Abraham."
        ),
        "Exodus": BookInfo(
            writers: "Moses",
            timeFrame: "1446-1406 BC",
            themes: "Deliverance, Law, Tabernacle",
            keyCharacters: "Moses, Aaron, Pharaoh",
            summary: "God delivers Israel from Egypt and establishes His covenant at Sinai."
        ),
        "Leviticus": BookInfo(
            writers: "Moses",
            timeFrame: "1445-1444 BC",
            themes: "Holiness, Sacrifice, Priesthood",
            keyCharacters: "Moses, Aaron, Nadab, Abihu",
            summary: "Instructions for worship and holy living for God's covenant people."
        ),
        "Numbers": BookInfo(
            writers: "Moses",
            timeFrame: "1444-1406 BC",
            themes: "Wilderness, Wandering, Faith",
            keyCharacters: "Moses, Aaron, Miriam, Balaam",
            summary: "Israel's journey from Sinai to the edge of the Promised Land."
        ),
        "Deuteronomy": BookInfo(
            writers: "Moses",
            timeFrame: "1406 BC",
            themes: "Covenant, Law, Obedience",
            keyCharacters: "Moses, Joshua",
            summary: "Moses's final addresses reviewing the covenant before entering Canaan."
        ),
        
        // Historical Books
        "Joshua": BookInfo(
            writers: "Joshua",
            timeFrame: "1406-1380 BC",
            themes: "Conquest, Land, Faithfulness",
            keyCharacters: "Joshua, Rahab, Achan",
            summary: "Israel conquers and divides the Promised Land under Joshua's leadership."
        ),
        "Judges": BookInfo(
            writers: "Samuel (tradition)",
            timeFrame: "1380-1050 BC",
            themes: "Cycles, Apostasy, Deliverance",
            keyCharacters: "Deborah, Gideon, Samson",
            summary: "Israel experiences cycles of apostasy, oppression, and deliverance."
        ),
        "Ruth": BookInfo(
            writers: "Unknown (possibly Samuel)",
            timeFrame: "1100-1050 BC",
            themes: "Loyalty, Kinsman-Redeemer, Providence",
            keyCharacters: "Ruth, Naomi, Boaz",
            summary: "A foreign woman's loyalty leads to becoming an ancestor of King David."
        ),
        "1 Samuel": BookInfo(
            writers: "Samuel, Nathan, Gad",
            timeFrame: "1100-1010 BC",
            themes: "Transition to Monarchy, Covenant",
            keyCharacters: "Samuel, Saul, David",
            summary: "Israel transitions from judges to kings - Samuel, Saul, and David."
        ),
        "2 Samuel": BookInfo(
            writers: "Nathan, Gad",
            timeFrame: "1010-970 BC",
            themes: "Davidic Kingdom, Covenant",
            keyCharacters: "David, Joab, Bathsheba",
            summary: "David's reign, triumphs, and troubles as king of Israel."
        ),
        
        // New Testament - Gospels
        "Matthew": BookInfo(
            writers: "Matthew (Levi)",
            timeFrame: "AD 50-70",
            themes: "Kingdom, Fulfillment, Discipleship",
            keyCharacters: "Jesus, Twelve Disciples",
            summary: "Jesus as the Messianic King who fulfills Old Testament prophecies."
        ),
        "Mark": BookInfo(
            writers: "John Mark",
            timeFrame: "AD 50-60",
            themes: "Servanthood, Action, Cross",
            keyCharacters: "Jesus, Disciples, Peter",
            summary: "Jesus as the Suffering Servant who came to give His life as a ransom."
        ),
        "Luke": BookInfo(
            writers: "Luke",
            timeFrame: "AD 60-62",
            themes: "Universal Salvation, Poor, Outcasts",
            keyCharacters: "Jesus, John the Baptist, Mary",
            summary: "Carefully researched account of Jesus's life for a Gentile audience."
        ),
        "John": BookInfo(
            writers: "John the Apostle",
            timeFrame: "AD 85-95",
            themes: "Belief, Life, Divinity of Christ",
            keyCharacters: "Jesus, Nicodemus, Lazarus",
            summary: "Jesus as the Son of God written so that readers might believe."
        ),
        
        // New Testament - Epistles
        "Romans": BookInfo(
            writers: "Paul",
            timeFrame: "AD 57",
            themes: "Righteousness, Faith, Salvation",
            keyCharacters: "Paul, Abraham",
            summary: "Paul's comprehensive explanation of the gospel and its implications."
        ),
        "Hebrews": BookInfo(
            writers: "Unknown (possibly Paul)",
            timeFrame: "AD 60-70",
            themes: "Christ's superiority, Faith, Perseverance",
            keyCharacters: "Jesus, Melchizedek, Moses",
            summary: "Jesus Christ is superior to all—therefore hold fast to Him."
        ),
        "Revelation": BookInfo(
            writers: "John the Apostle",
            timeFrame: "AD 90-95",
            themes: "Judgment, Victory, New Creation",
            keyCharacters: "John, Jesus, Angels",
            summary: "Vision of Christ's ultimate victory and the renewal of all things."
        )
    ]
    
    // Return book info if available, otherwise return generic info
    return bookInfoMap[book] ?? BookInfo(
        writers: "Various",
        timeFrame: "Unknown",
        themes: "Faith, Redemption",
        keyCharacters: "Various biblical figures",
        summary: "Part of God's inspired Word."
    )
}

// Wrapper to make book names identifiable
struct IdentifiableBook: Identifiable, Equatable {
    let id: String  // id is the book name
    let name: String
    let chapterCount: Int
    
    static func == (lhs: IdentifiableBook, rhs: IdentifiableBook) -> Bool {
        return lhs.id == rhs.id
    }
}

// Book information section with proper state handling
struct BookInfoSection: View {
    let bookInfo: BookInfo
    @State private var showBookInfo = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Custom fully clickable header button
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.25)) { 
                    showBookInfo.toggle() 
                } 
            }) {
                HStack {
                    Text("Book Information")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: showBookInfo ? "chevron.down" : "chevron.right")
                        .foregroundColor(.blue)
                        .font(.system(size: 10))
                        .animation(.easeInOut(duration: 0.2), value: showBookInfo)
                }
                .padding(.vertical, 8)
                .background(Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content with smooth height animation
            VStack(alignment: .leading, spacing: 0) {
                if showBookInfo {
                    // Info fields
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Text("Writer(s):")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(bookInfo.writers)
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                        }
                        
                        HStack(alignment: .top) {
                            Text("Time:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(bookInfo.timeFrame)
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                        }
                        
                        HStack(alignment: .top) {
                            Text("Themes:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(bookInfo.themes)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .foregroundColor(.primary)
                        }
                        
                        HStack(alignment: .top) {
                            Text("Characters:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(bookInfo.keyCharacters)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .foregroundColor(.primary)
                        }
                        
                        HStack(alignment: .top) {
                            Text("Summary:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(bookInfo.summary)
                                .font(.system(size: 11))
                                .lineLimit(2)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                }
            }
            .clipped()
            .animation(.easeInOut(duration: 0.25), value: showBookInfo)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// Bookmark model
struct BibleBookmark: Identifiable, Codable, Equatable {
    let id: UUID
    let book: String
    let chapter: Int
    let verse: Int
    let translation: String
    let dateAdded: Date
    let notes: String
    
    init(book: String, chapter: Int, verse: Int = 1, translation: String, notes: String = "") {
        self.id = UUID()
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.translation = translation
        self.dateAdded = Date()
        self.notes = notes
    }
}

// Data to manage bookmarks
class BibleReaderData: ObservableObject {
    @Published var bookmarks: [BibleBookmark] = []
    @Published var lastReadBook: String = "Genesis"
    @Published var lastReadChapter: Int = 1
    @Published var lastReadTranslation: String = "KJV"
    
    private let bookmarksKey = "bible_reader_bookmarks"
    private let lastReadKey = "bible_reader_last_read"
    
    init() {
        loadBookmarks()
        loadLastRead()
    }
    
    func addBookmark(book: String, chapter: Int, verse: Int = 1, translation: String, notes: String = "") {
        let newBookmark = BibleBookmark(book: book, chapter: chapter, verse: verse, translation: translation, notes: notes)
        bookmarks.append(newBookmark)
        saveBookmarks()
    }
    
    func removeBookmark(at index: Int) {
        guard index < bookmarks.count else { return }
        bookmarks.remove(at: index)
        saveBookmarks()
    }
    
    func saveLastRead(book: String, chapter: Int, translation: String) {
        lastReadBook = book
        lastReadChapter = chapter
        lastReadTranslation = translation
        
        let data: [String: Any] = [
            "book": book,
            "chapter": chapter,
            "translation": translation
        ]
        
        UserDefaults.standard.set(data, forKey: lastReadKey)
    }
    
    private func loadLastRead() {
        if let data = UserDefaults.standard.dictionary(forKey: lastReadKey) {
            lastReadBook = data["book"] as? String ?? "Genesis"
            lastReadChapter = data["chapter"] as? Int ?? 1
            lastReadTranslation = data["translation"] as? String ?? "KJV"
        }
    }
    
    private func saveBookmarks() {
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(encoded, forKey: bookmarksKey)
        }
    }
    
    private func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: bookmarksKey),
           let decoded = try? JSONDecoder().decode([BibleBookmark].self, from: data) {
            bookmarks = decoded
        }
    }
}

// Modified BibleReaderView struct with additional state variables
struct BibleReaderView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.themeColors) var theme
    @StateObject private var readerData = BibleReaderData()
    @State private var selectedBook = "Genesis"
    @State private var selectedChapter = 1
    @State private var chapterData: ChapterResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var maxChapters = 50 // Default, will be updated based on book
    @State private var popoverBook: IdentifiableBook? = nil // Currently showing popover for this book
    @State private var hoveredBook: String? = nil // Track which book is being hovered
    @State private var selectedTranslation = "KJV" // Selected translation abbreviation
    @State private var showingTranslationSelector = false // Translation selector popover
    @State private var showingSplashPage = true // Show splash page by default
    @State private var showingAddBookmarkSheet = false // Sheet for adding bookmark with notes
    @State private var bookmarkNotes = "" // For new bookmark notes
    @State private var currentVerseForBookmark = 1 // Current verse for bookmarking
    @State private var isBookSelectorSidebarVisible: Bool = true // For iPad sidebar toggle
    
    // Available Bible translations
    private let availableTranslations = [
        ("KJV", "King James Version"),
        ("ESV", "English Standard Version"),
        ("NIV", "New International Version"),
        ("NASB", "New American Standard Bible"),
        ("NKJV", "New King James Version"),
        ("NLT", "New Living Translation"),
        ("CSB", "Christian Standard Bible"),
        ("MSG", "The Message"),
        ("AMP", "Amplified Bible"),
        ("NCV", "New Century Version")
    ]
    
    // Get full translation name from abbreviation
    private var selectedTranslationName: String {
        availableTranslations.first(where: { $0.0 == selectedTranslation })?.1 ?? "King James Version"
    }
    
    // Organized Bible books with testament and group headers
    private let bibleStructure = [
        // OLD TESTAMENT
        BibleSection(testament: "OLD TESTAMENT", groups: [
            BibleGroup(name: "THE LAW", books: [
                ("Genesis", 50), ("Exodus", 40), ("Leviticus", 27), ("Numbers", 36), ("Deuteronomy", 34)
            ]),
            BibleGroup(name: "HISTORY", books: [
                ("Joshua", 24), ("Judges", 21), ("Ruth", 4), ("1 Samuel", 31), ("2 Samuel", 24),
                ("1 Kings", 22), ("2 Kings", 25), ("1 Chronicles", 29), ("2 Chronicles", 36),
                ("Ezra", 10), ("Nehemiah", 13), ("Esther", 10)
            ]),
            BibleGroup(name: "WISDOM LITERATURE", books: [
                ("Job", 42), ("Psalms", 150), ("Proverbs", 31), ("Ecclesiastes", 12), ("Song of Solomon", 8)
            ]),
            BibleGroup(name: "MAJOR PROPHETS", books: [
                ("Isaiah", 66), ("Jeremiah", 52), ("Lamentations", 5), ("Ezekiel", 48), ("Daniel", 12)
            ]),
            BibleGroup(name: "MINOR PROPHETS", books: [
                ("Hosea", 14), ("Joel", 3), ("Amos", 9), ("Obadiah", 1), ("Jonah", 4),
                ("Micah", 7), ("Nahum", 3), ("Habakkuk", 3), ("Zephaniah", 3), ("Haggai", 2),
                ("Zechariah", 14), ("Malachi", 4)
            ])
        ]),
        // NEW TESTAMENT
        BibleSection(testament: "NEW TESTAMENT", groups: [
            BibleGroup(name: "GOSPELS", books: [
                ("Matthew", 28), ("Mark", 16), ("Luke", 24), ("John", 21)
            ]),
            BibleGroup(name: "EARLY CHURCH HISTORY", books: [
                ("Acts", 28)
            ]),
            BibleGroup(name: "LETTERS", books: [
                ("Romans", 16), ("1 Corinthians", 16), ("2 Corinthians", 13), ("Galatians", 6),
                ("Ephesians", 6), ("Philippians", 4), ("Colossians", 4), ("1 Thessalonians", 5),
                ("2 Thessalonians", 3), ("1 Timothy", 6), ("2 Timothy", 4), ("Titus", 3),
                ("Philemon", 1), ("Hebrews", 13), ("James", 5), ("1 Peter", 5), ("2 Peter", 3),
                ("1 John", 5), ("2 John", 1), ("3 John", 1), ("Jude", 1)
            ]),
            BibleGroup(name: "PROPHECY", books: [
                ("Revelation", 22)
            ])
        ])
    ]
    
    // Flattened list for easy lookup
    private var allBooks: [(String, Int)] {
        bibleStructure.flatMap { section in
            section.groups.flatMap { group in
                group.books
            }
        }
    }
    
    var onDismiss: () -> Void
    
    var body: some View {
        #if os(iOS)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        #endif
        
        Group {
            #if os(iOS)
            if isPhone {
                // iPhone: Wrap in ScrollView for content that might overflow
                ScrollView {
                    VStack(spacing: 0) {
                        bibleReaderBody
                    }
                    .padding(.bottom, 20)  // Add bottom padding for scroll content
                }
                .clipped() // Prevent content from expanding beyond bounds
            } else {
                // iPad: Use regular VStack
                VStack(spacing: 0) {
                    bibleReaderBody
                }
            }
            #else
            // macOS: Use regular VStack
            VStack(spacing: 0) {
                bibleReaderBody
            }
            #endif
        }
        .modifier(BibleReaderFrameModifier())
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
        .animation(.none) // Disable all layout animations
        .onAppear {
            // Load last read position
            selectedBook = readerData.lastReadBook
            selectedChapter = readerData.lastReadChapter
            selectedTranslation = readerData.lastReadTranslation
            
            // Update maxChapters based on book
            if let bookChapters = allBooks.first(where: { $0.0 == selectedBook })?.1 {
                maxChapters = bookChapters
            }
            
            // Load the content in the background while showing splash page
            // For iPhone, preload content immediately to prevent layout changes
            #if os(iOS)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            if isPhone {
                // Preload content without showing loading state
                Task {
                    do {
                        let result = try await BibleAPI.fetchChapter(
                            book: selectedBook,
                            chapter: selectedChapter,
                            translation: selectedTranslation,
                            focusedVerses: []
                        )
                        
                        await MainActor.run {
                            chapterData = result
                            // Don't change isLoading state to prevent layout changes
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            } else {
                loadCurrentChapter()
            }
            #else
            loadCurrentChapter()
            #endif
        }
        .sheet(isPresented: $showingAddBookmarkSheet) {
            addBookmarkView
        }
    }
    
    private var bibleReaderBody: some View {
        Group {
            // Header with navigation
            headerView
            
            Divider()
            
            // Main content
            HStack(spacing: 0) {
                // Left sidebar with book selection - Hide on iPhone due to space constraints
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    if isBookSelectorSidebarVisible {
                bookSelectorSidebar
                            .transition(.move(edge: .leading))
                Divider()
                    }
                }
                // iPhone: Hide sidebar completely due to 340pt width constraint
                #else // macOS
                // On macOS, sidebar is always present
                bookSelectorSidebar
                Divider()
                #endif
                
                // Main reading area with splash page overlay
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                if isPhone {
                    // iPhone: Use conditional rendering instead of ZStack to prevent layout changes
                    Group {
                        if showingSplashPage {
                            splashPageView
                                .background(theme.surface)
                        } else {
                            readingArea
                        }
                    }
                } else {
                    // iPad: Use ZStack overlay
                    ZStack {
                        readingArea
                        
                        if showingSplashPage {
                            splashPageView
                                .background(theme.surface)
                        }
                    }
                }
                #else
                // macOS: Use ZStack overlay
                ZStack {
                    readingArea
                    
                    if showingSplashPage {
                        splashPageView
                            .background(theme.surface)
                    }
                }
                #endif
            }
        }
    }
    
    private var headerView: some View {
        Group {
            #if os(iOS)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            
            if isPhone {
                // iPhone: Separate title and navigation layout
                VStack(spacing: 12) {
                    // Title section
                    HStack {
                        Text("Bible Reader")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Spacer()
                        
                        // Close button - removed for iPhone, only show on iPad/macOS
                    }
                    
                    // Navigation section
                    if !showingSplashPage {
                        HStack(spacing: 8) {
                            // Book selector
                            Menu {
                                ForEach(allBooks, id: \.0) { book, chapterCount in
                                    Button(book) {
                                        selectedBook = book
                                        maxChapters = chapterCount
                                        selectedChapter = 1
                                        loadCurrentChapter()
                                    }
                                }
                            } label: {
                                Text(selectedBook)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(height: 32)
                                    .padding(.horizontal, 12)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            // Chapter selector
                            Menu {
                                ForEach(1...maxChapters, id: \.self) { chapter in
                                    Button("\(chapter)") {
                                        selectedChapter = chapter
                                        loadCurrentChapter()
                                    }
                                }
                            } label: {
                                Text("\(selectedChapter)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(width: 32, height: 32)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            Spacer()
                            
                            // Navigation arrows - centered
                            HStack(spacing: 8) {
                                Button(action: loadPreviousChapter) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.blue)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(Color.blue.opacity(0.1)))
                                        .contentShape(Circle())
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: loadNextChapter) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.blue)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(Color.blue.opacity(0.1)))
                                        .contentShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer()
                            
                            // Action buttons - right aligned
                            HStack(spacing: 8) {
                                Button(action: {
                                    bookmarkNotes = ""
                                    currentVerseForBookmark = 1
                                    showingAddBookmarkSheet = true
                                }) {
                                    Image(systemName: "bookmark")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(Color.blue.opacity(0.1)))
                                        .contentShape(Circle())
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    readerData.saveLastRead(book: selectedBook, chapter: selectedChapter, translation: selectedTranslation)
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showingSplashPage = true
                                    }
                                }) {
                                    Image(systemName: "house")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(Color.blue.opacity(0.1)))
                                        .contentShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .padding(.top, 4) // Add breathing room at the top for iPhone
                .background(theme.surface)
            } else {
                // iPad: Original layout
                iPadHeaderLayout
            }
            #else
            // macOS: Original layout
            macOSHeaderLayout
            #endif
        }
    }
    
    private var iPadHeaderLayout: some View {
        HStack {
            // Add a button to toggle sidebar visibility only on iPad
            Button(action: {
                withAnimation(.easeInOut) {
                    isBookSelectorSidebarVisible.toggle()
                }
            }) {
                Image(systemName: isBookSelectorSidebarVisible ? "sidebar.left" : "sidebar.squares.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)

            Text("Bible Reader")
                .font(.system(size: 24, weight: .semibold))
            
            Spacer()
            
            if !showingSplashPage {
                // Centered navigation section
                HStack(spacing: 16) {
                    Button(action: loadPreviousChapter) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Previous Chapter")
                    
                    VStack(spacing: 2) {
                        Text("\(selectedBook) \(selectedChapter)")
                            .font(.system(size: 16, weight: .bold))
                        
                        // Clickable translation selector
                        Button(action: {
                            showingTranslationSelector = true
                        }) {
                            HStack(spacing: 4) {
                                Text(selectedTranslationName)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Change Bible Translation")
                        .popover(isPresented: $showingTranslationSelector) {
                            translationSelectorPopover
                        }
                    }
                    
                    Button(action: loadNextChapter) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Next Chapter")
                }
                
                Spacer()
                
                // Right side buttons
                HStack(spacing: 12) {
                    // Bookmark button
                    Button(action: {
                        bookmarkNotes = ""
                        currentVerseForBookmark = 1
                        showingAddBookmarkSheet = true
                    }) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Bookmark this chapter")
                    
                    // Home button
                    Button(action: {
                        readerData.saveLastRead(book: selectedBook, chapter: selectedChapter, translation: selectedTranslation)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSplashPage = true
                        }
                    }) {
                        Image(systemName: "house")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Return to home")
                }
            } else {
                Spacer()
            }
            
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.gray.opacity(0.5)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(theme.surface)
    }
    
    private var macOSHeaderLayout: some View {
        HStack {
            Text("Bible Reader")
                .font(.system(size: 24, weight: .semibold))
            
            Spacer()
            
            if !showingSplashPage {
                // Centered navigation section
                HStack(spacing: 16) {
                    Button(action: loadPreviousChapter) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Previous Chapter")
                    
                    VStack(spacing: 2) {
                        Text("\(selectedBook) \(selectedChapter)")
                            .font(.system(size: 16, weight: .bold))
                        
                        // Clickable translation selector
                        Button(action: {
                            showingTranslationSelector = true
                        }) {
                            HStack(spacing: 4) {
                                Text(selectedTranslationName)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Change Bible Translation")
                        .popover(isPresented: $showingTranslationSelector) {
                            translationSelectorPopover
                        }
                    }
                    
                    Button(action: loadNextChapter) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Next Chapter")
                }
                
                Spacer()
                
                // Right side buttons
                HStack(spacing: 12) {
                    // Bookmark button
                    Button(action: {
                        bookmarkNotes = ""
                        currentVerseForBookmark = 1
                        showingAddBookmarkSheet = true
                    }) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Bookmark this chapter")
                    
                    // Home button
                    Button(action: {
                        readerData.saveLastRead(book: selectedBook, chapter: selectedChapter, translation: selectedTranslation)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSplashPage = true
                        }
                    }) {
                        Image(systemName: "house")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Return to home")
                }
            } else {
                Spacer()
            }
            
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.gray.opacity(0.5)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(theme.surface)
    }
    
    private var bookSelectorSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(Array(bibleStructure.enumerated()), id: \.offset) { testamentIndex, section in
                        Section {
                            // Groups within this testament
                            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                                ForEach(Array(section.groups.enumerated()), id: \.offset) { groupIndex, group in
                                    Section {
                                        // Books in this group
                                        ForEach(group.books, id: \.0) { book, chapterCount in
                                            bookRowView(book: book, chapterCount: chapterCount)
                                        }
                                    } header: {
                                        groupHeaderView(for: group.name, testament: section.testament)
                                    }
                                }
                            }
                        } header: {
                            testamentHeaderView(for: section.testament)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .frame(width: 220)
        .background(theme.surface)
    }
    

    
    private func testamentHeaderView(for testament: String) -> some View {
        HStack {
            Text(testament)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: testament == "OLD TESTAMENT" ? 
                    [Color(.systemBlue), Color(.systemBlue).opacity(0.8)] :
                    [Color(.systemOrange), Color(.systemOrange).opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    private func groupHeaderView(for groupName: String, testament: String) -> some View {
        HStack {
            Text(groupName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: groupHeaderColors(for: testament, group: groupName),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    private func bookRowView(book: String, chapterCount: Int) -> some View {
        Button(action: {
            popoverBook = IdentifiableBook(id: book, name: book, chapterCount: chapterCount)
            maxChapters = chapterCount // Update the chapter count for this book
        }) {
            HStack {
                Text(book)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(chapterCount)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(bookRowBackgroundColor(for: book))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredBook = isHovering ? book : nil
        }
        // Add book-specific popover
        .popover(item: Binding(
            get: { 
                // Only returns a value if this specific book is selected for popover
                let identifiableBook = IdentifiableBook(id: book, name: book, chapterCount: chapterCount)
                let isCurrentBookSelected = popoverBook == identifiableBook
                return isCurrentBookSelected ? popoverBook : nil
            },
            set: { (newValue: IdentifiableBook?) in
                // When dismissed, clear the popover for this book
                if newValue == nil {
                    popoverBook = nil
                }
            }
        ), attachmentAnchor: .rect(.bounds), arrowEdge: .leading) { book in
            // Get chapter count for this book
            let bookChapters = book.chapterCount
            
            // Chapter selector view for this specific book
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text(book.name)
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Text("\(bookChapters) chapters")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                Divider()
                
                // Book information section with guaranteed full-width clickable row
                let bookInfo = getBookInfo(for: book.name)
                
                BookInfoSection(bookInfo: bookInfo)
                
                Divider()
                
                // Chapter grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(1...bookChapters, id: \.self) { chapter in
                            let isSelectedChapter = selectedBook == book.name && selectedChapter == chapter
                            let chapterButtonColor = isSelectedChapter ? Color.blue : Color.blue.opacity(0.1)
                            let chapterTextColor = isSelectedChapter ? Color.white : Color.blue
                            
                            Button(action: {
                                selectedBook = book.name
                                selectedChapter = chapter
                                maxChapters = bookChapters
                                loadCurrentChapter()
                                popoverBook = nil // Dismiss popover
                                
                                // Dismiss splash screen when a chapter is selected
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingSplashPage = false
                                }
                            }) {
                                Text("\(chapter)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(chapterTextColor)
                                    .frame(width: 40, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(chapterButtonColor)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                Divider()
            }
            .frame(width: 300, height: 400) // Fixed height prevents popover container from resizing
            .background(theme.surface)
        }
    }
    
    private func bookRowBackgroundColor(for book: String) -> Color {
        if selectedBook == book {
            return Color.blue.opacity(0.2)
        } else if hoveredBook == book {
            return Color.blue.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    // Helper function to get gradient colors for group headers
    private func groupHeaderColors(for testament: String, group: String) -> [Color] {
        if testament == "OLD TESTAMENT" {
            switch group {
            case "THE LAW":
                return [Color(.systemIndigo), Color(.systemIndigo).opacity(0.7)]
            case "HISTORY":
                return [Color(.systemTeal), Color(.systemTeal).opacity(0.7)]
            case "WISDOM LITERATURE":
                return [Color(.systemPurple), Color(.systemPurple).opacity(0.7)]
            case "MAJOR PROPHETS":
                return [Color(.systemBlue), Color(.systemBlue).opacity(0.7)]
            case "MINOR PROPHETS":
                return [Color(.systemCyan), Color(.systemCyan).opacity(0.7)]
            default:
                return [Color(.systemBlue), Color(.systemBlue).opacity(0.7)]
            }
        } else {
            switch group {
            case "GOSPELS":
                return [Color(.systemRed), Color(.systemRed).opacity(0.7)]
            case "EARLY CHURCH HISTORY":
                return [Color(.systemOrange), Color(.systemOrange).opacity(0.7)]
            case "LETTERS":
                return [Color(.systemYellow), Color(.systemYellow).opacity(0.7)]
            case "PROPHECY":
                return [Color(.systemPink), Color(.systemPink).opacity(0.7)]
            default:
                return [Color(.systemOrange), Color(.systemOrange).opacity(0.7)]
            }
        }
    }
    
    private var translationSelectorPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Bible Translation")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            Divider()
            
            // Translation list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(availableTranslations, id: \.0) { abbreviation, fullName in
                        Button(action: {
                            selectedTranslation = abbreviation
                            showingTranslationSelector = false
                            // Reload current chapter with new translation
                            loadCurrentChapter()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(abbreviation)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text(fullName)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedTranslation == abbreviation {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTranslation == abbreviation ? Color.blue.opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 320, height: 400)
        .background(theme.surface)
    }
    
    private var readingArea: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                // iPhone: Use regular VStack to prevent lazy loading layout changes
                if isPhone {
                    VStack(alignment: .leading, spacing: 0) {
                        iPhoneReadingContent
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        iPadReadingContent
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                }
                #else
                LazyVStack(alignment: .leading, spacing: 0) {
                    macOSReadingContent
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                #endif
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
    }
    
    // iPhone-specific content with no loading states
    @ViewBuilder
    private var iPhoneReadingContent: some View {
        if let chapter = chapterData {
            // iPhone: Always show verses if data is available
            ForEach(chapter.verses) { verse in
                iPhoneVerseView(verse)
            }
        } else if let errorMessage = errorMessage {
            // Error state
            VStack(spacing: 12) {
                Spacer().frame(height: 20)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                Text("Error loading chapter")
                    .font(.system(size: 16, weight: .medium))
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 20)
        } else {
            // Placeholder
            VStack(spacing: 12) {
                Spacer().frame(height: 20)
                Image(systemName: "book.closed")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                Text("Select a chapter to read")
                    .font(.system(size: 16, weight: .medium))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 20)
        }
    }
    
    // iPad-specific content with loading states
    @ViewBuilder
    private var iPadReadingContent: some View {
        if isLoading {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Loading \(selectedBook) \(selectedChapter)...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.05))
        }
        
        if let chapter = chapterData, !isLoading {
            ForEach(chapter.verses) { verse in
                verseView(verse)
                    .animation(.none, value: verse.id)
            }
        } else if let errorMessage = errorMessage {
            VStack(spacing: 16) {
                Spacer().frame(height: 30)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                Text("Error loading chapter")
                    .font(.system(size: 16, weight: .medium))
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 40)
        } else if !isLoading {
            VStack(spacing: 16) {
                Spacer().frame(height: 30)
                Image(systemName: "book.closed")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                Text("Select a chapter to read")
                    .font(.system(size: 16, weight: .medium))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 40)
        }
    }
    
    // macOS-specific content with loading states
    @ViewBuilder
    private var macOSReadingContent: some View {
        if isLoading {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Loading \(selectedBook) \(selectedChapter)...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.05))
        }
        
        if let chapter = chapterData, !isLoading {
            ForEach(chapter.verses) { verse in
                verseView(verse)
                    .animation(.none, value: verse.id)
            }
        } else if let errorMessage = errorMessage {
            VStack(spacing: 16) {
                Spacer().frame(height: 30)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                Text("Error loading chapter")
                    .font(.system(size: 16, weight: .medium))
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 40)
        } else if !isLoading {
            VStack(spacing: 16) {
                Spacer().frame(height: 30)
                Image(systemName: "book.closed")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                Text("Select a chapter to read")
                    .font(.system(size: 16, weight: .medium))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 40)
        }
    }
    
    // iPhone-specific verse view with ultra-compact spacing
    private func iPhoneVerseView(_ verse: BibleVerse) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Verse number
            Text("\(extractVerseNumber(from: verse.reference))")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue.opacity(0.12)))
            
            // Verse text
            Text(verse.text)
                .font(.system(size: 14))
                .lineSpacing(-1)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }
    
    private func verseView(_ verse: BibleVerse) -> some View {
        HStack(alignment: .top, spacing: {
            #if os(iOS)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            return isPhone ? 4 : 12 // Ultra-small spacing for iPhone
            #else
            return 12 // macOS default
            #endif
        }()) {
            // Verse number
            Text("\(extractVerseNumber(from: verse.reference))")
                .font(.system(size: {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    return isPhone ? 10 : 12 // Smaller font for iPhone
                    #else
                    return 12 // macOS default
                    #endif
                }(), weight: .medium))
                .foregroundColor(.blue)
                .frame(width: {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    return isPhone ? 20 : 24 // Smaller circle for iPhone
                    #else
                    return 24 // macOS default
                    #endif
                }(), height: {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    return isPhone ? 20 : 24 // Smaller circle for iPhone
                    #else
                    return 24 // macOS default
                    #endif
                }())
                .background(Circle().fill(Color.blue.opacity(0.12)))
            
            // Verse text
            Text(verse.text)
                .font(.system(size: {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    return isPhone ? 14 : 16 // Smaller font for iPhone
                    #else
                    return 16 // macOS default
                    #endif
                }()))
                .lineSpacing({
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    return isPhone ? -4 : 2 // More negative spacing for iPhone to compress lines
                    #else
                    return 2 // macOS default
                    #endif
                }())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
                        .padding(.vertical, {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    return isPhone ? 1 : 8 // Ultra-small vertical padding for iPhone
                    #else
                    return 8 // macOS default
                    #endif
                }())
        .padding(.horizontal, {
            #if os(iOS)
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            return isPhone ? 4 : 16 // Smaller padding for iPhone
            #else
            return 16 // macOS default
            #endif
        }())
    }
    
    // MARK: - Navigation Functions
    
    private func loadCurrentChapter() {
        // Ensure maxChapters is correct for the current book
        if let bookChapters = allBooks.first(where: { $0.0 == selectedBook })?.1 {
            maxChapters = bookChapters
        }
        loadChapter(book: selectedBook, chapter: selectedChapter)
        
        // Save current position whenever a chapter is loaded
        readerData.saveLastRead(book: selectedBook, chapter: selectedChapter, translation: selectedTranslation)
    }
    
    private func loadPreviousChapter() {
        if selectedChapter > 1 {
            selectedChapter -= 1
            loadCurrentChapter()
        }
    }
    
    private func loadNextChapter() {
        if selectedChapter < maxChapters {
            selectedChapter += 1
            loadCurrentChapter()
        }
    }
    
    private func loadChapter(book: String, chapter: Int) {
        // Don't show loading if we're just switching books but staying in the same chapter
        let shouldShowLoading = chapterData == nil || 
                              (chapterData?.book != book || chapterData?.chapter != chapter)
        
        // For iPhone, never show loading state to prevent layout changes
        #if os(iOS)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        if shouldShowLoading && !isPhone {
            isLoading = true
        }
        #else
        if shouldShowLoading {
            isLoading = true
        }
        #endif
        
        errorMessage = nil
        
        Task {
            do {
                let result = try await BibleAPI.fetchChapter(
                    book: book,
                    chapter: chapter,
                    translation: selectedTranslation,
                    focusedVerses: []
                )
                
                await MainActor.run {
                    chapterData = result
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    if !isPhone {
                        isLoading = false
                    }
                    #else
                    isLoading = false
                    #endif
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    if !isPhone {
                        isLoading = false
                    }
                    #else
                    isLoading = false
                    #endif
                }
            }
        }
    }
    
    private func extractVerseNumber(from reference: String) -> Int {
        let components = reference.split(separator: ":")
        if components.count > 1 {
            return Int(components[1]) ?? 1
        }
        return 1
    }
    
    private var splashPageView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                return isPhone ? 12 : 30 // Better spacing for iPhone
                #else
                return 30 // macOS default
                #endif
            }()) {
            // Header
            VStack(spacing: {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                return isPhone ? 6 : 12 // Better header spacing for iPhone
                #else
                return 12 // macOS default
                #endif
            }()) {
                Text("Bible Reader")
                    .font(.system(size: {
                        #if os(iOS)
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        return isPhone ? 28 : 36 // Slightly larger title for iPhone
                        #else
                        return 36 // macOS default
                        #endif
                    }(), weight: .bold))
                
                Text("Study God's Word")
                    .font(.system(size: {
                        #if os(iOS)
                        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                        return isPhone ? 16 : 18 // Slightly larger subtitle for iPhone
                        #else
                        return 18 // macOS default
                        #endif
                    }()))
                    .foregroundColor(.secondary)
            }
            .padding(.top, {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                return isPhone ? 20 : 50 // Better top padding for iPhone
                #else
                return 50 // macOS default
                #endif
            }())
            
            Spacer()
                .frame(minHeight: {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    return isPhone ? 40 : 0 // Add more breathing room for iPhone
                    #else
                    return 0 // macOS default
                    #endif
                }())
            
            // Reading options
            VStack(spacing: {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                return isPhone ? 16 : 20 // Better button spacing for iPhone
                #else
                return 20 // macOS default
                #endif
            }()) {
                // Continue reading button
                Button(action: {
                    // Continue from last reading position
                    selectedBook = readerData.lastReadBook
                    selectedChapter = readerData.lastReadChapter
                    selectedTranslation = readerData.lastReadTranslation
                    
                    // Update maxChapters based on book
                    if let bookChapters = allBooks.first(where: { $0.0 == selectedBook })?.1 {
                        maxChapters = bookChapters
                    }
                    
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    if !isPhone {
                        loadCurrentChapter()
                    }
                    // For iPhone, content is already preloaded, just dismiss splash
                    #else
                    loadCurrentChapter()
                    #endif
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSplashPage = false
                    }
                }) {
                    HStack {
                        Image(systemName: "book.fill")
                            .font(.system(size: 16))
                        Text("Continue Reading")
                            .font(.system(size: 16, weight: .medium))
                        Text("\(readerData.lastReadBook) \(readerData.lastReadChapter)")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue)
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                // Start fresh button
                Button(action: {
                    selectedBook = "Genesis"
                    selectedChapter = 1
                    selectedTranslation = "KJV"
                    maxChapters = 50 // Genesis has 50 chapters
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    if !isPhone {
                        loadCurrentChapter()
                    } else {
                        // For iPhone, load Genesis content without showing loading state
                        Task {
                            do {
                                let result = try await BibleAPI.fetchChapter(
                                    book: "Genesis",
                                    chapter: 1,
                                    translation: "KJV",
                                    focusedVerses: []
                                )
                                
                                await MainActor.run {
                                    chapterData = result
                                }
                            } catch {
                                await MainActor.run {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }
                    #else
                    loadCurrentChapter()
                    #endif
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSplashPage = false
                    }
                }) {
                    Text("Start from Genesis")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
                .frame(minHeight: {
                    #if os(iOS)
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    return isPhone ? 30 : 0 // Add breathing room between sections for iPhone
                    #else
                    return 0 // macOS default
                    #endif
                }())
            
            // Bookmarks section
            VStack(alignment: .leading, spacing: {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                return isPhone ? 8 : 15 // Better bookmarks spacing for iPhone
                #else
                return 15 // macOS default
                #endif
            }()) {
                Text("Your Bookmarks")
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if readerData.bookmarks.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: {
                            #if os(iOS)
                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                            return isPhone ? 8 : 10 // Better empty state spacing for iPhone
                            #else
                            return 10 // macOS default
                            #endif
                        }()) {
                            Image(systemName: "bookmark.slash")
                                .font(.system(size: {
                                    #if os(iOS)
                                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                                    return isPhone ? 28 : 32 // Better icon size for iPhone
                                    #else
                                    return 32 // macOS default
                                    #endif
                                }()))
                                .foregroundColor(.secondary)
                            Text("No bookmarks yet")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, {
                            #if os(iOS)
                            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                            return isPhone ? 20 : 30 // Better empty state padding for iPhone
                            #else
                            return 30 // macOS default
                            #endif
                        }())
                        Spacer()
                    }
                } else {
                    VStack(spacing: 8) {
                        ForEach(readerData.bookmarks.indices, id: \.self) { index in
                            let bookmark = readerData.bookmarks[index]
                            Button(action: {
                                // Load the bookmarked chapter
                                selectedBook = bookmark.book
                                selectedChapter = bookmark.chapter
                                selectedTranslation = bookmark.translation
                                
                                // Update max chapters
                                if let bookChapters = allBooks.first(where: { $0.0 == selectedBook })?.1 {
                                    maxChapters = bookChapters
                                }
                                
                                loadCurrentChapter()
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingSplashPage = false
                                }
                            }) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(bookmark.book) \(bookmark.chapter):\(bookmark.verse)")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        if !bookmark.notes.isEmpty {
                                            Text(bookmark.notes)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                                .lineLimit(nil)
                                        }
                                        
                                        Text(formattedDate(bookmark.dateAdded))
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Delete bookmark button
                                    Button(action: {
                                        readerData.removeBookmark(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(colorScheme == .dark ? Color(.darkGray).opacity(0.3) : Color.white)
                                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                return isPhone ? 8 : 60 // Much smaller padding for iPhone
                #else
                return 60 // macOS default
                #endif
            }())
            
            Spacer(minLength: {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                return isPhone ? 12 : 40 // Better bottom spacing for iPhone
                #else
                return 40 // macOS default
                #endif
            }())
            }
            .padding(.horizontal, {
                #if os(iOS)
                let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                return isPhone ? 16 : 30 // Better outer padding for iPhone
                #else
                return 30 // macOS default
                #endif
            }())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var addBookmarkView: some View {
        VStack(spacing: 20) {
            // Header
            Text("Add Bookmark")
                .font(.system(size: 20, weight: .bold))
            
            // Current selection info
            VStack(alignment: .leading, spacing: 8) {
                Text("Reference:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("\(selectedBook) \(selectedChapter):\(currentVerseForBookmark)")
                    .font(.system(size: 18, weight: .medium))
                
                HStack {
                    Text("Verse:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("Verse", selection: $currentVerseForBookmark) {
                        // Use chapter data to get available verses, if available
                        if let chapter = chapterData {
                            ForEach(1...chapter.verses.count, id: \.self) { verse in
                                Text("\(verse)").tag(verse)
                            }
                        } else {
                            // Fallback to 30 verses if chapter data isn't loaded yet
                            ForEach(1...30, id: \.self) { verse in
                                Text("\(verse)").tag(verse)
                            }
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 100)
                }
            }
            .padding(.vertical, 8)
            
            // Notes field
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (optional):")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextEditor(text: $bookmarkNotes)
                    .font(.system(size: 14))
                    .frame(height: 120)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Buttons
            HStack(spacing: 16) {
                Button(action: {
                    showingAddBookmarkSheet = false
                }) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    // Add the bookmark
                    readerData.addBookmark(
                        book: selectedBook,
                        chapter: selectedChapter,
                        verse: currentVerseForBookmark,
                        translation: selectedTranslation,
                        notes: bookmarkNotes
                    )
                    showingAddBookmarkSheet = false
                }) {
                    Text("Add Bookmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
    
    // Helper function for formatting dates
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Frame Modifier for Platform-Specific Sizing
    private struct BibleReaderFrameModifier: ViewModifier {
        func body(content: Content) -> some View {
            #if os(macOS)
            content.frame(width: 1000, height: 700)
            #else // For iOS
            if UIDevice.current.userInterfaceIdiom == .pad {
                // Check orientation for iPad
                let screenWidth = UIScreen.main.bounds.width
                let screenHeight = UIScreen.main.bounds.height
                let isLandscape = screenWidth > screenHeight
                
                if isLandscape {
                    // iPad Landscape: Wider but shorter, leaving blue background visible
                    content.frame(idealWidth: 1000, maxWidth: 1100, idealHeight: 700, maxHeight: 800)
                } else {
                    // iPad Portrait: Original sizing
                content.frame(idealWidth: 800, maxWidth: 900, idealHeight: 1000, maxHeight: 1150)
                }
            } else { // For iPhone
                // iPhone: Better width utilization for text content
                content.frame(width: 380, height: 600)
            }
            #endif
        }
    }
}

// Extension for better text styling
extension Text {
    func lineHeight(_ lineHeight: CGFloat) -> some View {
        #if os(iOS)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let baseFontSize: CGFloat = isPhone ? 14 : 16 // Match the actual font size used
        #else
        let baseFontSize: CGFloat = 16
        #endif
        return self.lineSpacing(lineHeight * baseFontSize - baseFontSize)
    }
}

#Preview {
    BibleReaderView(onDismiss: {})
} 