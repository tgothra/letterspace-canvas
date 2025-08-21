#if os(macOS) || os(iOS)
import SwiftUI

// MARK: - Curated Content View (Section)
struct CuratedContentView<Card: View>: View {
	let types: [CurationType]
	@ViewBuilder let cardForType: (CurationType) -> Card
	
	@Environment(\.themeColors) private var theme
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			// Section header
			HStack(alignment: .top) {
				VStack(alignment: .leading, spacing: 4) {
					Text("Curated for You")
						.font(.custom("InterTight-Bold", size: 19))
						.foregroundStyle(theme.primary)
					Text("Handpicked sermon tools and insights")
						.font(.custom("InterTight-Regular", size: 12))
						.foregroundStyle(theme.primary.opacity(0.6))
				}
				Spacer()
			}
			// Cards
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 20) {
					ForEach(types, id: \.self) { type in
						cardForType(type)
					}
				}
				.padding(.horizontal, 20)
				.frame(height: 280)
			}
		}
		.padding(.vertical, 20)
	}
}
#endif
