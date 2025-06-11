# Fixing "Multiple Commands Produce" Build Errors

## Problem

You encountered an error like:

```
Multiple commands produce '/Users/.../DerivedData/.../ModernCalendarSection.swift.bak'

duplicate output file '/.../ModernCalendarSection.swift.bak' on task: CpResource...
```

## Cause

This error happens when Xcode tries to include the same file multiple times in the build process. In your case, multiple `.bak` files were being included as resources in the build.

## Solution Implemented

1. **Moved Backup Files Out of Project**: 
   - We created a `Backups` directory at `Letterspace Canvas/Backups/`
   - We moved all `.bak` files there:
     ```
     ModernCalendarSection.swift.bak (from Views/Calendar/)
     ModernCalendarSection.swift.bak (from Views/Modern/)
     Calendar.swift.bak
     Calendar_bak.swift
     ModernCalendar.swift.bak
     ```

2. **Removed Duplicated Files**:
   - We ensured that no duplicate files exist in the project structure
   
3. **Created Cleanup Script**:
   - We provided a `clean_build.sh` script that:
     - Removes the DerivedData folder
     - Checks for any remaining problematic files
     - Verifies the SermonCalendar implementation
     
4. **Updated Implementation**:
   - We confirmed that HomeView.swift is now using SermonCalendar directly
   - We updated CalendarBridge.swift with clear deprecation notices

## How to Run the Cleanup

From your project directory, run:

```bash
./clean_build.sh
```

## Build Steps

1. Run the cleanup script: `./clean_build.sh`
2. Open your project in Xcode
3. In Xcode, select Product > Clean Build Folder 
4. Build your project (Command+B)
5. If you still encounter issues, check that no `.bak` files are included in your Xcode project navigator

## Why This Works

The error occurs because Xcode is trying to process the same file twice - either because it's physically in two locations or it's referenced multiple times in your project file.

By moving the backup files out of the project structure and cleaning the build folder, we ensure that Xcode doesn't try to process these files during the build.

## Manual Fix Option

If the error persists, you can try:

1. Open your Xcode project
2. In the Project Navigator, look for any `.bak` files
3. Right-click on each one and select "Delete"
4. Choose "Remove Reference" (not "Move to Trash")
5. Clean and rebuild your project

## Future Prevention Tips

1. Don't include `.bak` files in your Xcode project
2. Keep backup files outside the project's source directories
3. When renaming files, make sure to remove the old references from Xcode 