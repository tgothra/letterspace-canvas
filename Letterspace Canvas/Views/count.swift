import Foundation

func countBracesInFile(filePath: String) {
    do {
        let content = try String(contentsOfFile: filePath)
        var openCount = 0
        var closeCount = 0
        for c in content {
            if c == "{" {
                openCount += 1
            } else if c == "}" {
                closeCount += 1
            }
        }
        print("Open braces in \(filePath): \(openCount)")
        print("Close braces in \(filePath): \(closeCount)")
    } catch {
        print("Error reading file \(filePath): \(error)")
    }
}

// Example of how to call the function (you can remove this or modify as needed)
// countBracesInFile(filePath: "HeaderImageSection.swift")
