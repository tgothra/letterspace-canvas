# Fixing Syntax Errors in HomeView.swift

## Problem

After our previous fix for the "Multiple commands produce" error, we encountered a series of syntax errors in the HomeView.swift file:

```
Expressions are not allowed at the top level
Cannot find 'date' in scope
Cannot find 'theme' in scope
Extraneous '}' at top level
...and many more
```

## Cause

The issue was caused by an improper removal of the `CalendarSection` implementation from HomeView.swift. When we attempted to replace `CalendarSection` with `SermonCalendar`, we didn't correctly remove the entire `CalendarSection` struct implementation, which resulted in code fragments being left at the top level of the file.

## Solution Implemented

We created a properly fixed version of HomeView.swift by:

1. **Creating a Clean Extract**:
   - We started with a clean backup of HomeView.swift
   - We extracted everything up to line 4862 (just before the `CalendarSection` definition)
   - We skipped over the entire `CalendarSection` and `ScheduleListView` implementations
   - We added everything from the `CalendarNavigationButton` definition onwards (line 5678)
   
2. **Replacing CalendarSection with SermonCalendar**:
   - We replaced the call to `CalendarSection(` with `SermonCalendar(` around line 757
   
3. **Adding Descriptive Comments**:
   - We added comments at the top of the file to clarify the use of `SermonCalendar`
   - The comment explains that the original implementation has been replaced

## How to Verify

1. Open the project in Xcode
2. Check that there are no syntax errors in HomeView.swift
3. Verify that the `SermonCalendar` implementation is being used correctly
4. Confirm that no fragments of the original `CalendarSection` implementation remain

## Why This Works

By completely removing the `CalendarSection` and `ScheduleListView` implementations and replacing the reference with `SermonCalendar`, we've ensured that there are no syntax errors or misplaced code fragments. The solution maintains the structure of the original file while cleanly integrating the new calendar implementation.

## Future Prevention Tips

1. When replacing large sections of code, make sure to identify the exact start and end points of the code to be removed
2. Use version control to track changes and make it easier to revert if needed
3. Consider using a script or tool to automate the replacement process for complex changes 