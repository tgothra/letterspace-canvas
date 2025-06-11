import SwiftUI

struct TemplateBrowserView: View {
    @State private var searchText = ""
    @State private var selectedCategory: DocumentTemplate.TemplateCategory?
    @Binding var isPresented: Bool
    @Binding var document: Letterspace_CanvasDocument
    @Binding var sidebarMode: RightSidebar.SidebarMode
    @Binding var isRightSidebarVisible: Bool
    
    private var filteredTemplates: [DocumentTemplate] {
        let templates = DocumentTemplate.defaultTemplates
        if let category = selectedCategory {
            return templates.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            return templates.filter { template in
                template.name.localizedCaseInsensitiveContains(searchText) ||
                template.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        return templates
    }
    
    var body: some View {
        NavigationView {
            // Sidebar with categories
            List(selection: $selectedCategory) {
                Section {
                    ForEach(DocumentTemplate.TemplateCategory.allCases, id: \.self) { category in
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundStyle(.secondary)
                            Text(category.rawValue)
                        }
                        .tag(category)
                    }
                } header: {
                    Text("Categories")
                }
            }
            .frame(minWidth: 200)
            
            // Main content
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search templates...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(.quaternary.opacity(0.5))
                
                // Templates grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)
                    ], spacing: 16) {
                        ForEach(filteredTemplates) { template in
                            TemplateCard(template: template) {
                                useTemplate(template)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Cancel") {
                    isPresented = false
                }
            }
        }
    }
    
    private func useTemplate(_ template: DocumentTemplate) {
        print("Starting template creation process...")
        
        // Create initial template content
        let templateContent = TemplateDocumentContent.empty
        
        // Create the new document
        var newDocument = Letterspace_CanvasDocument(
            title: template.name,  // Use template name as initial title
            subtitle: template.category.rawValue,  // Use category as subtitle
            elements: DocumentElement.fromTemplateContent(templateContent),
            id: UUID().uuidString,
            series: nil,
            createdAt: Date(),
            modifiedAt: Date(),
            isHeaderExpanded: false  // Start with header collapsed by default
        )
        
        // Set template document flag after initialization
        newDocument.isTemplateDocument = true
        
        print("Created new document from template: \(template.name)")
        
        // Save the new document
        newDocument.save()
        
        print("Saved new document, updating UI state...")
        
        // Update UI state
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // Update the current document
            document = newDocument
            
            // Switch to document view mode
            sidebarMode = .details
            isRightSidebarVisible = true
            
            // Close the template browser
            isPresented = false
        }
        
        print("Template creation process completed")
    }
}

struct TemplateCard: View {
    let template: DocumentTemplate
    let action: () -> Void
    @Environment(\.themeColors) var theme
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.headline)
                        Text(template.category.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: template.category.icon)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                
                // Description
                Text(template.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                // Variables preview
                if !template.variables.isEmpty {
                    Text("Required Fields:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ForEach(template.variables.filter(\.isRequired)) { variable in
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundStyle(.secondary)
                            Text(variable.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.secondary.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
            .opacity(isHovering ? 0.8 : 1.0)
            .scaleEffect(isHovering ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }
}

struct TemplateDocumentView: View {
    @Binding var document: Letterspace_CanvasDocument
    @State private var content: TemplateDocumentContent
    @Environment(\.themeColors) var theme
    
    init(document: Binding<Letterspace_CanvasDocument>) {
        self._document = document
        // Initialize content from document or create empty
        self._content = State(initialValue: TemplateDocumentContent.empty)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Introduction Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("INTRODUCTION")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.secondary)
                    
                    TextEditor(text: $content.introduction)
                        .font(.system(size: 16))
                        .frame(minHeight: 100, maxHeight: 200)
                        .padding(12)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onChange(of: content) { _, newValue in
                            updateDocument()
                        }
                }
                
                // Points
                ForEach(content.points.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 12) {
                        // Point Title
                        TextField("Point \(index + 1)", text: $content.points[index].title)
                            .font(.system(size: 18, weight: .semibold))
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        // Sections
                        Group {
                            // Explanation
                            Text("EXPLANATION")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(theme.secondary)
                            TextEditor(text: $content.points[index].explanation)
                                .font(.system(size: 16))
                                .frame(minHeight: 80, maxHeight: 150)
                                .padding(12)
                                .background(theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            // Illustration
                            Text("ILLUSTRATION")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(theme.secondary)
                                .padding(.top, 8)
                            TextEditor(text: $content.points[index].illustration)
                                .font(.system(size: 16))
                                .frame(minHeight: 80, maxHeight: 150)
                                .padding(12)
                                .background(theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            // Application
                            Text("APPLICATION")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(theme.secondary)
                                .padding(.top, 8)
                            TextEditor(text: $content.points[index].application)
                                .font(.system(size: 16))
                                .frame(minHeight: 80, maxHeight: 150)
                                .padding(12)
                                .background(theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .onChange(of: content.points[index]) { _, _ in
                        updateDocument()
                    }
                }
                
                // Conclusion
                VStack(alignment: .leading, spacing: 12) {
                    Text("CONCLUSION")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.secondary)
                    
                    TextEditor(text: $content.conclusion)
                        .font(.system(size: 16))
                        .frame(minHeight: 100, maxHeight: 200)
                        .padding(12)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onChange(of: content.conclusion) { _, _ in
                            updateDocument()
                        }
                }
            }
            .padding(24)
        }
    }
    
    private func updateDocument() {
        // Convert template content to document elements
        document.elements = DocumentElement.fromTemplateContent(content)
        document.save()
    }
} 