import Foundation
import SwiftUI

struct DocumentTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: TemplateCategory
    var description: String
    var elements: [TemplateElement]
    var variables: [TemplateVariable]
    var isCustom: Bool
    var dateCreated: Date
    var lastUsed: Date?
    
    enum TemplateCategory: String, Codable, CaseIterable {
        case sermonSeries = "Sermon Series"
        case bibleStudy = "Bible Study"
        case meetingNotes = "Meeting Notes"
        case eventPlanning = "Event Planning"
        case personalStudy = "Personal Study"
        
        var icon: String {
            switch self {
            case .sermonSeries: return "mic"
            case .bibleStudy: return "book"
            case .meetingNotes: return "person.2"
            case .eventPlanning: return "calendar"
            case .personalStudy: return "heart.text.square"
            }
        }
    }
}

struct TemplateElement: Codable, Identifiable {
    var id = UUID()
    var type: ElementType
    var content: String
    var placeholder: String?
    var isRequired: Bool
    var order: Int
    
    enum ElementType: String, Codable {
        case header
        case subheader
        case textBlock
        case scriptureReference
        case bulletPoints
        case numberedPoints
        case notes
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, content, placeholder, isRequired, order
    }
}

struct TemplateVariable: Codable, Identifiable {
    var id = UUID()
    var name: String
    var key: String
    var defaultValue: String?
    var description: String
    var isRequired: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, key, defaultValue, description, isRequired
    }
}

struct TemplateDocumentContent: Codable, Equatable {
    var introduction: String
    var points: [SermonPoint]
    var conclusion: String
    
    struct SermonPoint: Codable, Equatable {
        var title: String
        var explanation: String
        var illustration: String
        var application: String
        
        static func == (lhs: SermonPoint, rhs: SermonPoint) -> Bool {
            lhs.title == rhs.title &&
            lhs.explanation == rhs.explanation &&
            lhs.illustration == rhs.illustration &&
            lhs.application == rhs.application
        }
    }
    
    static func == (lhs: TemplateDocumentContent, rhs: TemplateDocumentContent) -> Bool {
        lhs.introduction == rhs.introduction &&
        lhs.points == rhs.points &&
        lhs.conclusion == rhs.conclusion
    }
    
    static var empty: TemplateDocumentContent {
        TemplateDocumentContent(
            introduction: "",
            points: [
                SermonPoint(title: "", explanation: "", illustration: "", application: ""),
                SermonPoint(title: "", explanation: "", illustration: "", application: ""),
                SermonPoint(title: "", explanation: "", illustration: "", application: "")
            ],
            conclusion: ""
        )
    }
}

extension DocumentElement {
    static func fromTemplateContent(_ content: TemplateDocumentContent) -> [DocumentElement] {
        var elements: [DocumentElement] = []
        
        // Introduction
        elements.append(DocumentElement(type: .header, content: "INTRODUCTION"))
        elements.append(DocumentElement(type: .textBlock, content: content.introduction))
        
        // Points
        for (index, point) in content.points.enumerated() {
            elements.append(DocumentElement(type: .header, content: "\(index + 1). \(point.title)"))
            
            elements.append(DocumentElement(type: .subheader, content: "EXPLANATION"))
            elements.append(DocumentElement(type: .textBlock, content: point.explanation))
            
            elements.append(DocumentElement(type: .subheader, content: "ILLUSTRATION"))
            elements.append(DocumentElement(type: .textBlock, content: point.illustration))
            
            elements.append(DocumentElement(type: .subheader, content: "APPLICATION"))
            elements.append(DocumentElement(type: .textBlock, content: point.application))
        }
        
        // Conclusion
        elements.append(DocumentElement(type: .header, content: "CONCLUSION"))
        elements.append(DocumentElement(type: .textBlock, content: content.conclusion))
        
        return elements
    }
}

// Extension to provide default templates
extension DocumentTemplate {
    static var defaultTemplates: [DocumentTemplate] {
        [
            // Three-Point Sermon Template
            DocumentTemplate(
                id: UUID(),
                name: "Three-Point Sermon",
                category: .sermonSeries,
                description: "Traditional three-point sermon structure with introduction, explanation, illustration, and application for each point",
                elements: [
                    // Introduction Section
                    TemplateElement(type: .header, content: "{{sermon_title}}", placeholder: "Sermon Title", isRequired: true, order: 0),
                    TemplateElement(type: .subheader, content: "{{scripture_reference}}", placeholder: "Main Scripture Reference (e.g., John 3:16)", isRequired: true, order: 1),
                    TemplateElement(type: .textBlock, content: "INTRODUCTION", placeholder: "", isRequired: true, order: 2),
                    TemplateElement(type: .textBlock, content: "{{opening_illustration}}", placeholder: "Start with a relatable story or illustration that introduces your topic...", isRequired: true, order: 3),
                    TemplateElement(type: .textBlock, content: "{{series_context}}", placeholder: "If part of a series, provide context: 'This is part of our [Series Name] series focusing on...'", isRequired: false, order: 4),
                    TemplateElement(type: .textBlock, content: "{{main_question}}", placeholder: "State the main question or problem you'll address in this sermon", isRequired: true, order: 5),

                    // Point 1
                    TemplateElement(type: .header, content: "1. {{point_one_title}}", placeholder: "First Main Point", isRequired: true, order: 6),
                    TemplateElement(type: .subheader, content: "EXPLANATION", placeholder: "", isRequired: true, order: 7),
                    TemplateElement(type: .textBlock, content: "{{point_one_explanation}}", placeholder: "Explain the biblical text and its meaning...", isRequired: true, order: 8),
                    TemplateElement(type: .subheader, content: "ILLUSTRATION", placeholder: "", isRequired: true, order: 9),
                    TemplateElement(type: .textBlock, content: "{{point_one_illustration}}", placeholder: "Provide a story, analogy, or example that illustrates this point...", isRequired: true, order: 10),
                    TemplateElement(type: .subheader, content: "APPLICATION", placeholder: "", isRequired: true, order: 11),
                    TemplateElement(type: .textBlock, content: "{{point_one_application}}", placeholder: "How should this truth change our lives?", isRequired: true, order: 12),

                    // Point 2
                    TemplateElement(type: .header, content: "2. {{point_two_title}}", placeholder: "Second Main Point", isRequired: true, order: 13),
                    TemplateElement(type: .subheader, content: "EXPLANATION", placeholder: "", isRequired: true, order: 14),
                    TemplateElement(type: .textBlock, content: "{{point_two_explanation}}", placeholder: "Explain the biblical text and its meaning...", isRequired: true, order: 15),
                    TemplateElement(type: .subheader, content: "ILLUSTRATION", placeholder: "", isRequired: true, order: 16),
                    TemplateElement(type: .textBlock, content: "{{point_two_illustration}}", placeholder: "Provide a story, analogy, or example that illustrates this point...", isRequired: true, order: 17),
                    TemplateElement(type: .subheader, content: "APPLICATION", placeholder: "", isRequired: true, order: 18),
                    TemplateElement(type: .textBlock, content: "{{point_two_application}}", placeholder: "How should this truth change our lives?", isRequired: true, order: 19),

                    // Point 3
                    TemplateElement(type: .header, content: "3. {{point_three_title}}", placeholder: "Third Main Point", isRequired: true, order: 20),
                    TemplateElement(type: .subheader, content: "EXPLANATION", placeholder: "", isRequired: true, order: 21),
                    TemplateElement(type: .textBlock, content: "{{point_three_explanation}}", placeholder: "Explain the biblical text and its meaning...", isRequired: true, order: 22),
                    TemplateElement(type: .subheader, content: "ILLUSTRATION", placeholder: "", isRequired: true, order: 23),
                    TemplateElement(type: .textBlock, content: "{{point_three_illustration}}", placeholder: "Provide a story, analogy, or example that illustrates this point...", isRequired: true, order: 24),
                    TemplateElement(type: .subheader, content: "APPLICATION", placeholder: "", isRequired: true, order: 25),
                    TemplateElement(type: .textBlock, content: "{{point_three_application}}", placeholder: "How should this truth change our lives?", isRequired: true, order: 26),

                    // Conclusion
                    TemplateElement(type: .header, content: "CONCLUSION", placeholder: "", isRequired: true, order: 27),
                    TemplateElement(type: .textBlock, content: "{{conclusion_summary}}", placeholder: "Recap your main points in a succinct manner...", isRequired: true, order: 28),
                    TemplateElement(type: .textBlock, content: "{{call_to_action}}", placeholder: "End with a specific challenge for people to apply during the week...", isRequired: true, order: 29)
                ],
                variables: [
                    TemplateVariable(name: "Sermon Title", key: "sermon_title", description: "The main title of your sermon", isRequired: true),
                    TemplateVariable(name: "Scripture Reference", key: "scripture_reference", description: "Primary Bible passage", isRequired: true),
                    TemplateVariable(name: "Opening Illustration", key: "opening_illustration", description: "Story or example that introduces your topic", isRequired: true),
                    TemplateVariable(name: "Series Context", key: "series_context", description: "How this sermon fits into the larger series", isRequired: false),
                    TemplateVariable(name: "Main Question", key: "main_question", description: "The central question or problem to be addressed", isRequired: true),
                    TemplateVariable(name: "Point One Title", key: "point_one_title", description: "Title for first main point", isRequired: true),
                    TemplateVariable(name: "Point Two Title", key: "point_two_title", description: "Title for second main point", isRequired: true),
                    TemplateVariable(name: "Point Three Title", key: "point_three_title", description: "Title for third main point", isRequired: true)
                ],
                isCustom: false,
                dateCreated: Date()
            ),
            
            // Expository Sermon Template
            DocumentTemplate(
                id: UUID(),
                name: "Expository Sermon",
                category: .sermonSeries,
                description: "Classic expository sermon structure with scripture analysis and application",
                elements: [
                    TemplateElement(type: .header, content: "{{sermon_title}}", placeholder: "Sermon Title", isRequired: true, order: 0),
                    TemplateElement(type: .subheader, content: "{{scripture_reference}}", placeholder: "Main Scripture Reference", isRequired: true, order: 1),
                    TemplateElement(type: .textBlock, content: "Series: {{series_name}}", placeholder: "Part of Series", isRequired: false, order: 2),
                    TemplateElement(type: .scriptureReference, content: "", placeholder: "Additional Scripture References", isRequired: false, order: 3),
                    TemplateElement(type: .textBlock, content: "Introduction", placeholder: "Set the context and main theme", isRequired: true, order: 4),
                    TemplateElement(type: .numberedPoints, content: "Main Points", placeholder: "Key sermon points", isRequired: true, order: 5),
                    TemplateElement(type: .textBlock, content: "Application", placeholder: "Practical applications", isRequired: true, order: 6),
                    TemplateElement(type: .textBlock, content: "Conclusion", placeholder: "Wrap up and call to action", isRequired: true, order: 7)
                ],
                variables: [
                    TemplateVariable(name: "Sermon Title", key: "sermon_title", description: "The main title of your sermon", isRequired: true),
                    TemplateVariable(name: "Scripture Reference", key: "scripture_reference", description: "Primary Bible passage", isRequired: true),
                    TemplateVariable(name: "Series Name", key: "series_name", description: "Name of the sermon series", isRequired: false)
                ],
                isCustom: false,
                dateCreated: Date()
            ),
            
            // Inductive Bible Study Template
            DocumentTemplate(
                id: UUID(),
                name: "Inductive Bible Study",
                category: .bibleStudy,
                description: "Detailed verse-by-verse study with observation, interpretation, and application",
                elements: [
                    TemplateElement(type: .header, content: "{{passage_title}}", placeholder: "Passage Title", isRequired: true, order: 0),
                    TemplateElement(type: .scriptureReference, content: "{{passage_reference}}", placeholder: "Scripture Passage", isRequired: true, order: 1),
                    TemplateElement(type: .textBlock, content: "Background Context", placeholder: "Historical and literary context", isRequired: true, order: 2),
                    TemplateElement(type: .textBlock, content: "Observation (What does it say?)", placeholder: "Key observations from the text", isRequired: true, order: 3),
                    TemplateElement(type: .textBlock, content: "Interpretation (What does it mean?)", placeholder: "Understanding the meaning", isRequired: true, order: 4),
                    TemplateElement(type: .textBlock, content: "Application (How does it apply?)", placeholder: "Personal and community application", isRequired: true, order: 5),
                    TemplateElement(type: .notes, content: "Additional Notes", placeholder: "Other insights or cross-references", isRequired: false, order: 6)
                ],
                variables: [
                    TemplateVariable(name: "Passage Title", key: "passage_title", description: "Title for this Bible study", isRequired: true),
                    TemplateVariable(name: "Passage Reference", key: "passage_reference", description: "Bible passage being studied", isRequired: true)
                ],
                isCustom: false,
                dateCreated: Date()
            )
        ]
    }
}

extension Letterspace_CanvasDocument {
    var isTemplateDocument: Bool {
        get {
            UserDefaults.standard.bool(forKey: "template_document_\(id)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "template_document_\(id)")
        }
    }
    
    var templateContent: TemplateDocumentContent? {
        guard isTemplateDocument else { return nil }
        
        // Convert document elements to template content
        var content = TemplateDocumentContent.empty
        var currentPoint = 0
        var currentSection: String?
        
        for element in elements {
            switch element.type {
            case .header:
                if element.content == "INTRODUCTION" {
                    currentSection = "introduction"
                } else if element.content == "CONCLUSION" {
                    currentSection = "conclusion"
                } else if element.content.hasPrefix("1.") || 
                          element.content.hasPrefix("2.") || 
                          element.content.hasPrefix("3.") {
                    currentPoint = Int(element.content.prefix(1))! - 1
                    content.points[currentPoint].title = String(element.content.dropFirst(3))
                    currentSection = nil
                }
            case .subheader:
                switch element.content {
                case "EXPLANATION": currentSection = "explanation"
                case "ILLUSTRATION": currentSection = "illustration"
                case "APPLICATION": currentSection = "application"
                default: break
                }
            case .textBlock:
                if let section = currentSection {
                    switch section {
                    case "introduction": content.introduction = element.content
                    case "conclusion": content.conclusion = element.content
                    case "explanation": content.points[currentPoint].explanation = element.content
                    case "illustration": content.points[currentPoint].illustration = element.content
                    case "application": content.points[currentPoint].application = element.content
                    default: break
                    }
                }
            default:
                break
            }
        }
        
        return content
    }
} 