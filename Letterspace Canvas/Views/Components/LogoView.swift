import SwiftUI

struct Logo: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Image(colorScheme == .dark ? "Dark 1 - Logo" : "Light 1 - Logo")
            .resizable()
            .scaledToFit()
            .frame(height: 28)
    }
}
