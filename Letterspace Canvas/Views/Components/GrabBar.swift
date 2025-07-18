import SwiftUI

struct GrabBar: View {
    let width: CGFloat?
    
    init(width: CGFloat? = nil) {
        self.width = width
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color.gray.opacity(0.4))
            .frame(width: width ?? 36, height: 5)
            .padding(.vertical, 8)
    }
}

struct GrabBar_Previews: PreviewProvider {
    static var previews: some View {
        GrabBar()
            .padding()
            .background(Color.white)
    }
} 