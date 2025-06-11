# Fixing the CalendarSection Redeclaration Issue

## Problem
You're seeing this error:
```
Invalid redeclaration of 'CalendarSection'
```

This happens because:
1. You have a `CalendarSection` defined in `HomeView.swift`
2. You're also trying to define or alias `CalendarSection` in `CalendarBridge.swift`

## Solution: Step by Step Guide

### Step 1: Edit HomeView.swift
1. Open `Letterspace Canvas/Views/HomeView.swift`
2. Find the `private struct CalendarSection: View {` declaration (around line 4863)
3. Delete the ENTIRE struct implementation, from this line until the line before `private struct ScheduleListView: View {` (line 5328)
4. Also delete the `ScheduleListView` implementation (from line 5328 to around line 5574)

### Step 2: Add Import at Top of HomeView.swift
Add this import statement at the top of the file, with your other imports:
```swift
import SwiftUI
import PDFKit
import AppKit
import UniformTypeIdentifiers
import CoreGraphics
// Add this line:
// import Modern  (use your actual module name)
```

### Step 3: Update CalendarBridge.swift
1. Open `Letterspace Canvas/Views/Modern/CalendarBridge.swift`
2. Uncomment the typealias line:
```swift
public typealias CalendarSection = ModernCalendarSection
```

### Step 4: Clean and Rebuild
1. In Xcode, select Product > Clean Build Folder (Shift+Command+K)
2. Restart Xcode
3. Rebuild your project

## Alternative Approach
If you prefer not to modify HomeView.swift directly, follow these steps:

1. Rename your Modern module's implementation:
   - Open `ModernCalendarSection.swift`
   - Rename `public struct ModernCalendarSection` to something else like `public struct SermonCalendar`
   - Update all references within the file accordingly

2. In CalendarBridge.swift:
   - Change the typealias to: `public typealias CalendarSection = SermonCalendar`

This way, your new implementation uses a completely different name internally, avoiding conflicts.

## If Issues Persist
If you still face issues after following these steps:

1. Create a brand new Swift file
2. Copy just the basic structure of your app, with imports and minimal code 
3. Add just the ModernCalendarSection implementation
4. Gradually re-introduce your app's functionality
5. This "clean start" approach often resolves complex build conflicts

Don't hesitate to get in touch if you need further assistance. 