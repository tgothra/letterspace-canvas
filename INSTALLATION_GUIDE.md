# Modern Calendar Installation Guide

## Overview

This guide will help you resolve the compilation errors and implement the modern calendar design with horizontal month slider, year picker, and list of active dates.

## Current Issues

You're experiencing several compilation errors due to name conflicts:

1. Multiple declarations of `CalendarSection` struct across files
2. Multiple declarations of `DayInfo` struct causing ambiguity
3. Type inference issues related to the ambiguous types

## Solution: Clean Implementation

We've created a new implementation that avoids these conflicts:

### Step 1: Add the ModernCalendarSection Implementation

1. Make sure the `Letterspace Canvas/Views/Modern` directory exists (create it if needed)
2. Add the `ModernCalendarSection.swift` file to that directory
3. Add the `CalendarBridge.swift` file to that directory

### Step 2: Update HomeView.swift

1. Open `Letterspace Canvas/Views/HomeView.swift`
2. Add the following import at the top of the file:
   ```swift
   import SwiftUI
   import PDFKit
   import AppKit
   import UniformTypeIdentifiers
   import CoreGraphics
   ```

3. Find the `private struct CalendarSection: View {` declaration (around line 4863)
4. Delete the entire implementation of `CalendarSection` up to where `private struct ScheduleListView: View {` begins
5. Delete the entire implementation of `ScheduleListView` as well
6. In place of the deleted code, add:
   ```swift
   // Using the modern calendar implementation from ModernCalendarSection
   ```

### Step 3: Clean Up Conflicting Files

Delete or rename these conflicting files to avoid ambiguity:
- `Letterspace Canvas/Views/Calendar.swift` → Rename to `Letterspace Canvas/Views/Calendar.swift.bak`
- `Letterspace Canvas/Views/ModernCalendar.swift` → Rename to `Letterspace Canvas/Views/ModernCalendar.swift.bak`

### Step 4: Update Your Project

If you're using Xcode, make sure to:
1. Add the new files to your project target
2. Clean and rebuild the project

## Alternative Approach: Simple Typealias

If you prefer a less invasive approach:

1. Keep your existing implementation but rename:
   - `struct CalendarSection` → `struct OriginalCalendarSection` 
   - `struct DayInfo` → `struct OriginalDayInfo`
2. Add a typealias: `typealias CalendarSection = OriginalCalendarSection`

## Testing

After implementing these changes, the application should compile without errors, and the calendar should display with the new modern design.

## Need Help?

If you continue to experience issues, please provide:
1. Any new error messages
2. Which approach you attempted
3. Any modifications you made to the implementation 