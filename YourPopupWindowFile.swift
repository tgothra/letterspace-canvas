// Assuming you have a NSWindow or NSPanel for your popup
// Add this when creating/configuring your window
window.appearance = NSAppearance(named: .darkAqua) // For dark mode
// OR
window.appearance = NSAppearance(named: .aqua) // For light mode

// If you're using SwiftUI with NSHostingController
let controller = NSHostingController(rootView: YourContentView())
controller.view.window?.appearance = NSAppearance(named: .darkAqua) // Or .aqua for light 