import Foundation
import ArgumentParser

@main
struct XcodeJunkCleaner: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xcode-cleaner",
        abstract: "A premium CLI tool to clean Xcode-related junk and reclaim disk space.",
        version: "1.0.0"
    )
    
    @Flag(name: .shortAndLong, help: "Automatically approve all prompts and delete all junk.")
    var yes: Bool = false
    
    @Flag(name: .shortAndLong, help: "Perform a dry run. Scan and show sizes without deleting.")
    var dryRun: Bool = false
    
    func run() throws {
        // Banner
        print("")
        print(Colorizer.color("🚀 Xcode Junk Cleaner CLI v1.0.0", .boldCyan))
        print(Colorizer.color("=========================================================", .cyan))
        
        // Step 1: Scan
        print("🔍 Scanning Xcode junk folders...")
        
        var scannedCategories: [(category: JunkCategory, size: Int64)] = []
        var totalBytes: Int64 = 0
        
        for category in JunkCategory.allCases {
            print("   Analyzing \(category.displayName)... ", terminator: "")
            fflush(stdout)
            
            let size = category.calculateSize()
            scannedCategories.append((category, size))
            totalBytes += size
            
            let sizeStr = JunkCategory.formatBytes(size)
            if size > 0 {
                print(Colorizer.color(sizeStr, .boldYellow))
            } else {
                print(Colorizer.color("0 B (Clean)", .green))
            }
        }
        
        print(Colorizer.color("=========================================================", .cyan))
        
        // If everything is already clean
        if totalBytes == 0 {
            print(Colorizer.color("✨ No Xcode junk found! Your system is clean.", .boldGreen))
            print("")
            return
        }
        
        // Print Summary Table
        let headerCategory = "Category".padding(toLength: 30, withPad: " ", startingAt: 0)
        let headerPath = "Path".padding(toLength: 50, withPad: " ", startingAt: 0)
        let headerSize = String(repeating: " ", count: 12 - "Size".count) + "Size"
        print("\(headerCategory) \(headerPath) \(headerSize)".colored(.bold))
        
        print("----------------------------------------------------------------------------------------------------")
        for (category, size) in scannedCategories where size > 0 {
            let pathDisplay = "~/\(category.relativePath)"
            let sizeDisplay = JunkCategory.formatBytes(size)
            
            let categoryCol = category.displayName.padding(toLength: 30, withPad: " ", startingAt: 0)
            let pathCol = pathDisplay.padding(toLength: 50, withPad: " ", startingAt: 0)
            let sizeCol = String(repeating: " ", count: max(0, 12 - sizeDisplay.count)) + sizeDisplay
            
            print("\(categoryCol) \(pathCol) \(sizeCol.colored(.boldYellow))")
        }
        print("----------------------------------------------------------------------------------------------------")
        print("Total potential space to reclaim: ".colored(.bold) + JunkCategory.formatBytes(totalBytes).colored(.boldGreen))
        print(Colorizer.color("=========================================================", .cyan))
        
        if dryRun {
            print("ℹ️ Dry-run mode: no files were deleted.".colored(.boldYellow))
            print("")
            return
        }
        
        // Handle direct approval
        if yes {
            try cleanAll(categories: scannedCategories)
            return
        }
        
        // Prompt user for global decision
        print("Would you like to delete ALL Xcode junk folders at once?")
        let choice = prompt(message: "Options: (y)es / (n)o / (i)nteractive", defaultOption: "i")
        
        if choice == "y" || choice == "yes" {
            try cleanAll(categories: scannedCategories)
        } else if choice == "n" || choice == "no" {
            print("❌ Cleaning cancelled. No files were deleted.".colored(.boldYellow))
            print("")
        } else {
            // Interactive mode
            try runInteractive(categories: scannedCategories)
        }
    }
    
    // Prompt helper
    private func prompt(message: String, defaultOption: String) -> String {
        print("\(message) [\(defaultOption)]: ", terminator: "")
        fflush(stdout)
        guard let response = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !response.isEmpty else {
            return defaultOption
        }
        return response.lowercased()
    }
    
    // Clean all categories with files
    private func cleanAll(categories: [(category: JunkCategory, size: Int64)]) throws {
        print("\n🧹 Cleaning all junk folders...")
        var totalReclaimed: Int64 = 0
        
        for (category, size) in categories where size > 0 {
            totalReclaimed += deleteCategory(category, size: size)
        }
        
        print(Colorizer.color("=========================================================", .cyan))
        print("🎉 Done! Reclaimed a total of ".colored(.boldGreen) + JunkCategory.formatBytes(totalReclaimed).colored(.boldGreen))
        print("")
    }
    
    // Run category by category interactive flow
    private func runInteractive(categories: [(category: JunkCategory, size: Int64)]) throws {
        print("\n👇 Starting interactive cleaning...")
        var totalReclaimed: Int64 = 0
        var autoApproveRemaining = false
        
        for (category, size) in categories where size > 0 {
            if autoApproveRemaining {
                totalReclaimed += deleteCategory(category, size: size)
                continue
            }
            
            print("\n---------------------------------------------------------")
            print("📂 \(category.displayName)".colored(.boldCyan))
            print("   Path: " + "~/\(category.relativePath)".colored(.yellow))
            print("   Description: \(category.description)")
            print("   Size: " + JunkCategory.formatBytes(size).colored(.boldYellow))
            if !category.isSafe {
                print("   ⚠️  " + "Caution: Deleting this folder resets its state (e.g. simulator runtimes).".colored(.boldRed))
            }
            print("---------------------------------------------------------")
            
            let choice = prompt(message: "Clean this folder? (y)es / (n)o / (a)ll remaining / (q)uit", defaultOption: "n")
            
            if choice == "y" || choice == "yes" {
                totalReclaimed += deleteCategory(category, size: size)
            } else if choice == "a" || choice == "all" {
                autoApproveRemaining = true
                totalReclaimed += deleteCategory(category, size: size)
            } else if choice == "q" || choice == "quit" {
                print("\n❌ Exiting interactive mode.".colored(.boldYellow))
                break
            } else {
                print("⏭️  Skipped \(category.displayName)")
            }
        }
        
        print("\n" + Colorizer.color("=========================================================", .cyan))
        print("🎉 Interactive run finished! Total reclaimed: ".colored(.boldGreen) + JunkCategory.formatBytes(totalReclaimed).colored(.boldGreen))
        print("")
    }
    
    // Deletes category and returns reclaimed bytes
    private func deleteCategory(_ category: JunkCategory, size: Int64) -> Int64 {
        print("🧹 Deleting \(category.displayName)... ", terminator: "")
        fflush(stdout)
        
        do {
            try category.delete()
            print("✅ Reclaimed ".colored(.green) + JunkCategory.formatBytes(size).colored(.boldGreen))
            return size
        } catch {
            print("❌ Failed".colored(.red))
            print("   ⚠️  Error details: \(error.localizedDescription)".colored(.boldRed))
            print("   💡 Note: Please ensure Xcode is closed and you have write permissions to that directory.".colored(.yellow))
            return 0
        }
    }
}
