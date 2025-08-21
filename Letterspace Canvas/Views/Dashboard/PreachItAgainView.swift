#if os(macOS) || os(iOS)
import SwiftUI

struct PreachItAgainView: View {
    let documents: [Letterspace_CanvasDocument]
    let onSelect: (Letterspace_CanvasDocument) -> Void
    @Environment(\.themeColors) private var theme
    
    var body: some View {
        if documents.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(theme.primary.opacity(0.3))
                Text("No sermons ready to preach again")
                    .font(.custom("InterTight-Medium", size: 16))
                    .foregroundStyle(theme.primary.opacity(0.6))
                Text("Sermons will appear here 6+ months after being preached")
                    .font(.custom("InterTight-Regular", size: 12))
                    .foregroundStyle(theme.primary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(documents, id: \.id) { document in
                        PreachItAgainCard(document: document) {
                            onSelect(document)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .contentMargins(.horizontal, 10, for: .scrollContent)
        }
    }
}
#endif


