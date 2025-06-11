#if canImport(AppKit)
import AppKit

extension NSFont {
    var isBold: Bool {
        return NSFontManager.shared.traits(of: self).contains(.boldFontMask)
    }
    
    var isItalic: Bool {
        return NSFontManager.shared.traits(of: self).contains(.italicFontMask)
    }
}
#endif

#if canImport(UIKit)
import UIKit

extension UIFont {
    var isBold: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitBold)
    }
    
    var isItalic: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitItalic)
    }
}
#endif 