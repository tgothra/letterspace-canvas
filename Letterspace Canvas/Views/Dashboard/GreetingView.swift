#if os(macOS) || os(iOS)
import SwiftUI

// MARK: - Greeting View
struct GreetingView: View {
    @Environment(\.themeColors) var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dashboard")
                .font(.system(size: {
                    #if os(iOS)
                    let screenWidth = UIScreen.main.bounds.width
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    if isPhone {
                        return max(12, min(16, screenWidth * 0.035))
                    } else {
                        return screenWidth * 0.022
                    }
                    #else
                    return 18
                    #endif
                }(), weight: .bold))
                .foregroundStyle(theme.primary.opacity(0.7))
                .padding(.bottom, 2)

            Text(getTimeBasedGreeting())
                .font(.custom("InterTight-Regular", size: {
                    #if os(iOS)
                    let screenWidth = UIScreen.main.bounds.width
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    if isPhone {
                        let calculatedSize = screenWidth * 0.075
                        return max(26, min(33, calculatedSize))
                    } else {
                        let calculatedSize = screenWidth * 0.055
                        return max(40, min(70, calculatedSize))
                    }
                    #else
                    return 52
                    #endif
                }()))
                .tracking(0.5)
                .foregroundStyle(theme.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 40) // Reduced space for floating logo
    }
    
    private func getTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        switch hour {
        case 0..<12: greeting = "Good morning"
        case 12..<17: greeting = "Good afternoon"
        default: greeting = "Good evening"
        }
        
        let firstName = UserDefaults.standard.string(forKey: "UserProfileFirstName") ?? "there"
        
        return "\(greeting), \(firstName)!"
    }
}

#endif
