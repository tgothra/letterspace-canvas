#if os(macOS) || os(iOS)
import SwiftUI

extension DashboardView {
    // Content sheet for a curated category
    @ViewBuilder
    func curatedCategoryContent(_ type: CurationType) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                curatedContentViewFor(type)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 12)
        }
        .navigationTitle(type.rawValue)
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if type == .todaysDocuments {
                        // Liquid glass grouped controls
                        HStack(spacing: 8) {
                            // Add Section Header (left)
                            Button {
                                showAddHeaderSheet = true
                            } label: {
                                Image(systemName: "text.badge.plus")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .accessibilityLabel("Add Section Header")

                            // Add Documents (right)
                            Button {
                                showTodayPicker = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .accessibilityLabel("Add Documents")
                        }
                    }

                    Button("Done") { activeSheet = nil }
                }
            }
        }
        #else
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                HStack(spacing: 12) {
                    if type == .todaysDocuments {
                        // Liquid glass grouped controls (macOS)
                        HStack(spacing: 8) {
                            // Add Section Header (left)
                            Button {
                                showAddHeaderSheet = true
                            } label: {
                                Image(systemName: "text.badge.plus")
                            }
                            .help("Add Section Header")

                            // Add Documents (right)
                            Button {
                                showTodayPicker = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .help("Add Documents")
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    Button("Done") { activeSheet = nil }
                }
            }
        }
        #endif
        .onAppear {
            selectedCurationType = type
        }
        .sheet(isPresented: $showTodayPicker) {
            TodayDocumentsPicker(
                allDocuments: documents,
                initiallySelected: todayDocumentIds,
                onDone: { selection in
                    // Update Today selection
                    todayDocumentIds = selection
                    UserDefaults.standard.set(Array(todayDocumentIds), forKey: "TodayDocumentIds")

                    // Ensure the List data source (structure) is immediately in sync
                    // Preserve any existing header assignment/order where possible
                    let existing = todayStructureDocuments
                    let mapped: [TodayStructureDocument] = Array(selection).enumerated().map { index, docId in
                        if let found = existing.first(where: { $0.id == docId }) {
                            return TodayStructureDocument(id: found.id, headerId: found.headerId, order: index)
                        } else {
                            return TodayStructureDocument(id: docId, headerId: nil, order: index)
                        }
                    }
                    todayStructureDocuments = mapped
                    saveTodayStructure()

                    showTodayPicker = false
                },
                onCancel: { showTodayPicker = false }
            )
            #if os(macOS)
            .frame(width: 500, height: 650)
            #endif
        }
        .sheet(isPresented: $showAddHeaderSheet) {
            AddHeaderSheet(
                onAdd: { title in
                    let newHeader = TodaySectionHeader(
                        id: UUID().uuidString,
                        title: title,
                        order: todayStructure.count
                    )
                    todayStructure.append(newHeader)
                    saveTodayStructure()
                    showAddHeaderSheet = false
                },
                onCancel: { showAddHeaderSheet = false }
            )
            #if os(macOS)
            .frame(width: 400, height: 300)
            #endif
        }
    }

    // Explicit variant to render for a provided type (avoids stale selected type on first open)
    @ViewBuilder
    func curatedContentViewFor(_ type: CurationType) -> some View {
        switch type {
        case .todaysDocuments:
            todaysDocumentsSection
        case .sermonJournal:
            sermonJournalSection
        case .preachItAgain:
            preachItAgainSection
        case .statistics:
            StatisticsView(
                documents: documents,
                onSelectDocument: onSelectDocument,
                onShowStatistics: { }
            )
        case .recent, .trending:
            EmptyView()
        }
    }

    // Card for a curated category
    @ViewBuilder
    func curatedCategoryCard(_ type: CurationType) -> some View {
        switch type {
        case .sermonJournal:
            sermonJournalSection
                .frame(width: 250, height: 260)
        default:
            Button {
                activeSheet = .curatedCategory(type)
            } label: {
                switch type {
                case .todaysDocuments:
                    VStack(alignment: .leading, spacing: 12) {
                        // Colored section
                        VStack(alignment: .leading, spacing: 8) {
                            // Override: Today's Docs uses black text/pills for readability when gradients are on
                            let isGradient = colorTheme.hasGradients
                            let useWhite = (!isGradient) && (colorTheme.currentTheme.id == "punchy")
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(useWhite ? .white : .black)
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Today's Docs")
                                    .font(.custom("InterTight-Bold", size: 17))
                                    .foregroundStyle(useWhite ? .white : .black)
                                Spacer()
                            }
                            
                            Text("Curate what you'll use today")
                                .font(.custom("InterTight-Regular", size: 14))
                                .foregroundStyle(useWhite ? .white.opacity(0.9) : .black.opacity(0.7))
                                .lineLimit(2)
                            
                            Spacer()
                            
                            // Pills showing current status
                            HStack(spacing: 6) {
                                let count = documents.filter { todayDocumentIds.contains($0.id) }.count
                                if count > 0 {
                                    Text("\(count) Selected")
                                        .font(.custom("InterTight-Medium", size: 11))
                                        .foregroundStyle(useWhite ? .white : .black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background((useWhite ? Color.white.opacity(0.22) : Color.black.opacity(0.1)), in: Capsule())
                                } else {
                                    Text("Empty")
                                        .font(.custom("InterTight-Medium", size: 11))
                                        .foregroundStyle(useWhite ? .white : .black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background((useWhite ? Color.white.opacity(0.22) : Color.black.opacity(0.1)), in: Capsule())
                                }
                                Spacer()
                            }
                        }
                        .padding(16)
                        .frame(height: 190)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                Color.white
                                if let gradients = colorTheme.gradients {
                                    Rectangle().fill(gradients.todaysDocsGradient)
                                } else {
                                    Rectangle().fill(colorTheme.currentTheme.curatedCards.todaysDocs)
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Explore button below colored section
                        HStack {
                            Text("Explore")
                                .font(.custom("InterTight-Medium", size: 14))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(16)
                    .background(colorScheme == .dark ? {
                        #if os(iOS)
                        return Color(.systemGray6)
                        #else
                        return Color(.controlBackgroundColor)
                        #endif
                    }() : {
                        #if os(iOS)
                        return Color(.systemBackground)
                        #else
                        return Color(.windowBackgroundColor)
                        #endif
                    }())
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke({
                                #if os(iOS)
                                return Color(.separator)
                                #else
                                return Color(.separatorColor)
                                #endif
                            }(), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 8, x: 0, y: 2)
                    .frame(width: 250, height: 260)

                case .preachItAgain:
                    VStack(alignment: .leading, spacing: 12) {
                        // Colored section
                        VStack(alignment: .leading, spacing: 8) {
                            let isPunchy = colorTheme.currentTheme.id == "punchy"
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise.circle")
                                    .foregroundStyle(isPunchy ? .white : .black)
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Preach it Again")
                                    .font(.custom("InterTight-Bold", size: 17))
                                    .foregroundStyle(isPunchy ? .white : .black)
                                Spacer()
                            }
                            
                            Text("Sermons ready for another delivery")
                                .font(.custom("InterTight-Regular", size: 14))
                                .foregroundStyle(isPunchy ? .white.opacity(0.9) : .black.opacity(0.7))
                                .lineLimit(2)
                            
                            Spacer()
                            
                            // Pills showing current status
                            HStack(spacing: 6) {
                                let count = documents.filter { doc in
                                    let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
                                    return doc.variations.contains { v in (v.datePresented ?? .distantFuture) <= sixMonthsAgo }
                                }.count
                                if count > 0 {
                                    Text("\(count) Ready")
                                        .font(.custom("InterTight-Medium", size: 11))
                                        .foregroundStyle(isPunchy ? .white : .black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background((isPunchy ? Color.white.opacity(0.22) : Color.black.opacity(0.1)), in: Capsule())
                                } else {
                                    Text("None Ready")
                                        .font(.custom("InterTight-Medium", size: 11))
                                        .foregroundStyle(isPunchy ? .white : .black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background((isPunchy ? Color.white.opacity(0.22) : Color.black.opacity(0.1)), in: Capsule())
                                }
                                Spacer()
                            }
                        }
                        .padding(16)
                        .frame(height: 190)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                Color.white
                                if let gradients = colorTheme.gradients {
                                    Rectangle().fill(gradients.preachItAgainGradient)
                                } else {
                                    Rectangle().fill(colorTheme.currentTheme.curatedCards.preachItAgain)
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Explore button below colored section
                        HStack {
                            Text("Explore")
                                .font(.custom("InterTight-Medium", size: 14))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(16)
                    .background(colorScheme == .dark ? {
                        #if os(iOS)
                        return Color(.systemGray6)
                        #else
                        return Color(.controlBackgroundColor)
                        #endif
                    }() : {
                        #if os(iOS)
                        return Color(.systemBackground)
                        #else
                        return Color(.windowBackgroundColor)
                        #endif
                    }())
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke({
                                #if os(iOS)
                                return Color(.separator)
                                #else
                                return Color(.separatorColor)
                                #endif
                            }(), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 8, x: 0, y: 2)
                    .frame(width: 250, height: 260)

                case .statistics:
                    StatisticsView(
                        documents: documents,
                        onSelectDocument: onSelectDocument,
                        onShowStatistics: {
                            // TODO: Show statistics detail view
                        }
                    )

                case .recent:
                    VStack(alignment: .leading, spacing: 12) {
                        // Colored section
                        VStack(alignment: .leading, spacing: 8) {
                            let isPunchy = colorTheme.currentTheme.id == "punchy"
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .foregroundStyle(isPunchy ? .white : .black)
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Recently Opened")
                                    .font(.custom("InterTight-Bold", size: 17))
                                    .foregroundStyle(isPunchy ? .white : .black)
                                Spacer()
                            }
                            
                            Text("Your latest document activity")
                                .font(.custom("InterTight-Regular", size: 14))
                                .foregroundStyle(isPunchy ? .white.opacity(0.9) : .black.opacity(0.7))
                                .lineLimit(2)
                            
                            Spacer()
                            
                            // Pills showing recent activity
                            HStack(spacing: 6) {
                                let recentCount = min(documents.count, 5)
                                if recentCount > 0 {
                                    Text("\(recentCount) Recent")
                                        .font(.custom("InterTight-Medium", size: 11))
                                        .foregroundStyle(isPunchy ? .white : .black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background((isPunchy ? Color.white.opacity(0.22) : Color.black.opacity(0.1)), in: Capsule())
                                } else {
                                    Text("No Activity")
                                        .font(.custom("InterTight-Medium", size: 11))
                                        .foregroundStyle(isPunchy ? .white : .black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background((isPunchy ? Color.white.opacity(0.22) : Color.black.opacity(0.1)), in: Capsule())
                                }
                                Spacer()
                            }
                        }
                        .padding(16)
                        .frame(height: 190)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                Color.white
                                if let gradients = colorTheme.gradients {
                                    Rectangle().fill(gradients.recentlyOpenedGradient)
                                } else {
                                    Rectangle().fill(colorTheme.currentTheme.curatedCards.recentlyOpened)
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Explore button below colored section
                        HStack {
                            Text("Explore")
                                .font(.custom("InterTight-Medium", size: 14))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(16)
                    .background(colorScheme == .dark ? {
                        #if os(iOS)
                        return Color(.systemGray6)
                        #else
                        return Color(.controlBackgroundColor)
                        #endif
                    }() : {
                        #if os(iOS)
                        return Color(.systemBackground)
                        #else
                        return Color(.windowBackgroundColor)
                        #endif
                    }())
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke({
                                #if os(iOS)
                                return Color(.separator)
                                #else
                                return Color(.separatorColor)
                                #endif
                            }(), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 8, x: 0, y: 2)
                    .frame(width: 250, height: 260)

                case .trending:
                    VStack(alignment: .leading, spacing: 12) {
                        // Colored section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Meetings")
                                .font(.custom("InterTight-Bold", size: 18))
                                .foregroundStyle(.black)
                            
                            Text("Recent and upcoming meetings")
                                .font(.custom("InterTight-Regular", size: 14))
                                .foregroundStyle(.black.opacity(0.7))
                                .lineLimit(2)
                            
                            Spacer()
                            
                            // Pills showing meeting info
                            HStack(spacing: 6) {
                                Text("Team")
                                    .font(.custom("InterTight-Medium", size: 11))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.black.opacity(0.1), in: Capsule())
                                
                                Text("This Week")
                                    .font(.custom("InterTight-Medium", size: 11))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.black.opacity(0.1), in: Capsule())
                                Spacer()
                            }
                        }
                        .padding(16)
                        .frame(height: 190)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                Color.white
                                if let gradients = colorTheme.gradients {
                                    Rectangle().fill(gradients.meetingsGradient)
                                } else {
                                    Rectangle().fill(colorTheme.currentTheme.curatedCards.meetings)
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Explore button below colored section
                        HStack {
                            Text("Explore")
                                .font(.custom("InterTight-Medium", size: 14))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(16)
                    .background(colorScheme == .dark ? {
                        #if os(iOS)
                        return Color(.systemGray6)
                        #else
                        return Color(.controlBackgroundColor)
                        #endif
                    }() : {
                        #if os(iOS)
                        return Color(.systemBackground)
                        #else
                        return Color(.windowBackgroundColor)
                        #endif
                    }())
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke({
                                #if os(iOS)
                                return Color(.separator)
                                #else
                                return Color(.separatorColor)
                                #endif
                            }(), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 8, x: 0, y: 2)
                    .frame(width: 250, height: 260)

                default:
                    EmptyView()
                }
            }
            .buttonStyle(.plain)
        }
    }
}

#endif


