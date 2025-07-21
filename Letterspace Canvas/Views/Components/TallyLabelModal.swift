import SwiftUI

struct TallyLabelModal: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.themeColors) var theme
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Tally Label Header Image
                    Image("Tally Label")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 120)
                        .padding(.top, 20)
                    
                    // App Information
                    VStack(spacing: 20) {
                        // App Title & Version
                        VStack(spacing: 8) {
                            Text("Letterspace Canvas")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(theme.primary)
                            
                            Text("Version 1.0")
                                .font(.subheadline)
                                .foregroundColor(theme.secondary)
                        }
                        
                        // App Description
                        VStack(alignment: .leading, spacing: 16) {
                            Text("About")
                                .font(.headline)
                                .foregroundColor(theme.primary)
                            
                            Text("Letterspace Canvas is a powerful document creation tool designed for pastors, teachers, and content creators. Create beautiful sermons, studies, and presentations with ease.")
                                .font(.body)
                                .foregroundColor(theme.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                            .background(theme.secondary.opacity(0.3))
                        
                        // Developer Information
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Developer")
                                .font(.headline)
                                .foregroundColor(theme.primary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Created with ❤️ by Timothy Gothra")
                                    .font(.body)
                                    .foregroundColor(theme.primary)
                                
                                Text("Designed to empower creative minds and spiritual leaders in their mission to inspire and educate.")
                                    .font(.body)
                                    .foregroundColor(theme.secondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                            .background(theme.secondary.opacity(0.3))
                        
                        // Features
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Features")
                                .font(.headline)
                                .foregroundColor(theme.primary)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                FeatureRow(icon: "doc.text", title: "Rich Document Creation", description: "Create structured documents with powerful editing tools")
                                FeatureRow(icon: "book.closed", title: "Scripture Integration", description: "Seamlessly integrate Bible verses and references")
                                FeatureRow(icon: "sparkles", title: "AI-Powered Tools", description: "Smart suggestions and content generation")
                                FeatureRow(icon: "calendar", title: "Calendar Integration", description: "Schedule and organize your content")
                                FeatureRow(icon: "folder", title: "Organization", description: "Keep your work organized with folders and tags")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("About")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: {
                    #if os(iOS)
                    .navigationBarTrailing
                    #else
                    .primaryAction
                    #endif
                }()) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    @Environment(\.themeColors) var theme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.accent)
                .frame(width: 24, height: 24)
                .background(theme.accent.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.primary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview {
    TallyLabelModal()
}
