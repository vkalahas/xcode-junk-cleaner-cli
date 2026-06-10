import Foundation
import ArgumentParser

// MARK: - JSON Model Schemas

struct JunkCategoryScanResult: Codable {
    let id: String
    let displayName: String
    let relativePath: String
    let sizeBytes: Int64
    let description: String
    let isSafe: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case relativePath = "relative_path"
        case sizeBytes = "size_bytes"
        case description
        case isSafe = "is_safe"
    }
}

struct ScanResult: Codable {
    let totalBytes: Int64
    let categories: [JunkCategoryScanResult]
    
    enum CodingKeys: String, CodingKey {
        case totalBytes = "total_bytes"
        case categories
    }
}

struct DeletionDetail: Codable {
    let id: String
    let displayName: String
    let reclaimedBytes: Int64
    let status: String // "success", "failed", "skipped"
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case reclaimedBytes = "reclaimed_bytes"
        case status
        case error
    }
}

struct DeletionResult: Codable {
    let totalReclaimedBytes: Int64
    let deletedCategories: [DeletionDetail]
    
    enum CodingKeys: String, CodingKey {
        case totalReclaimedBytes = "total_reclaimed_bytes"
        case deletedCategories = "deleted_categories"
    }
}

// MARK: - Main Command

@main
struct XcodeJunkCleaner: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xcode-cleaner",
        abstract: "A native Swift CLI utility to clean Xcode-related junk and reclaim disk space.",
        version: "1.0.0"
    )
    
    @Flag(name: .shortAndLong, help: "Automatically approve all prompts and delete all junk.")
    var yes: Bool = false
    
    @Flag(name: .shortAndLong, help: "Perform a dry run. Scan and show sizes without deleting.")
    var dryRun: Bool = false
    
    @Flag(name: .shortAndLong, help: "Automatically delete only 100% safe junk folders (Group A) without prompting.")
    var safe: Bool = false
    
    @Flag(name: .long, help: "Output results in JSON format.")
    var json: Bool = false
    
    @Flag(name: .shortAndLong, help: "Silence all standard logging output.")
    var quiet: Bool = false
    
    @Option(name: .shortAndLong, help: "Specify particular categories to scan or clean (comma-separated list of IDs, or repeat the option).")
    var category: [String] = []
    
    // Parsed target category IDs
    private var selectedCategoryIds: Set<String> {
        let items = category.flatMap { $0.components(separatedBy: ",") }
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Set(items.filter { !$0.isEmpty })
    }
    
    private var isInteractiveTerminal: Bool {
        return isatty(STDIN_FILENO) != 0
    }
    
    func run() throws {
        // Banner (silenced in quiet/json modes)
        log("")
        log("Xcode Junk Cleaner CLI v1.0.0".colored(.boldCyan))
        log("=========================================================".colored(.cyan))
        log("Scanning Xcode junk folders...")
        
        // Resolve target categories based on filtering
        let selection = selectedCategoryIds
        let targetCategories: [JunkCategory]
        if !selection.isEmpty {
            let matched = selection.compactMap { JunkCategory.from(id: $0) }
            if matched.isEmpty {
                writeToStderr("Error: None of the specified categories matched valid IDs.")
                throw ExitCode(1)
            }
            targetCategories = matched
        } else {
            targetCategories = JunkCategory.allCases
        }
        
        var scannedCategories: [(category: JunkCategory, size: Int64)] = []
        var totalBytes: Int64 = 0
        
        for category in targetCategories {
            log("   Analyzing \(category.displayName)... ", terminator: "")
            fflush(stdout)
            
            let size = category.calculateSize()
            scannedCategories.append((category, size))
            totalBytes += size
            
            let sizeStr: String
            if category == .unavailableSimulators {
                sizeStr = "\(size) devices"
            } else {
                sizeStr = JunkCategory.formatBytes(size)
            }
            
            if size > 0 {
                log(sizeStr.colored(.boldYellow))
            } else {
                log("0 B (Clean)".colored(.green))
            }
        }
        
        log("=========================================================".colored(.cyan))
        
        // Handle no junk found case
        if totalBytes == 0 {
            if json {
                outputJson(ScanResult(totalBytes: 0, categories: []))
            } else {
                log("No Xcode junk found. Your system is clean.".colored(.boldGreen))
                log("")
            }
            return
        }
        
        // Print Summary Table (if not json/quiet)
        if !json && !quiet {
            let headerCategory = "Category".padding(toLength: 30, withPad: " ", startingAt: 0)
            let headerPath = "Path / Action".padding(toLength: 50, withPad: " ", startingAt: 0)
            let headerSize = String(repeating: " ", count: 12 - "Size".count) + "Size"
            print("\(headerCategory) \(headerPath) \(headerSize)".colored(.bold))
            
            print("----------------------------------------------------------------------------------------------------")
            for (category, size) in scannedCategories where size > 0 {
                let pathDisplay: String
                let sizeDisplay: String
                
                if category == .unavailableSimulators {
                    pathDisplay = "xcrun simctl delete unavailable"
                    sizeDisplay = "\(size) devices"
                } else {
                    pathDisplay = "~/\(category.relativePath)"
                    sizeDisplay = JunkCategory.formatBytes(size)
                }
                
                let categoryCol = category.displayName.padding(toLength: 30, withPad: " ", startingAt: 0)
                let pathCol = pathDisplay.padding(toLength: 50, withPad: " ", startingAt: 0)
                let sizeCol = String(repeating: " ", count: max(0, 12 - sizeDisplay.count)) + sizeDisplay
                
                print("\(categoryCol) \(pathCol) \(sizeCol.colored(.boldYellow))")
            }
            print("----------------------------------------------------------------------------------------------------")
            print("Total potential space to reclaim: ".colored(.bold) + JunkCategory.formatBytes(totalBytes).colored(.boldGreen))
            print("=========================================================".colored(.cyan))
        }
        
        // Handle Dry Run
        if dryRun {
            if json {
                outputScanResult(scannedCategories: scannedCategories, totalBytes: totalBytes)
            } else {
                log("Dry-run mode: no files were deleted.".colored(.boldYellow))
                log("")
            }
            return
        }
        
        fflush(stdout)
        
        // Non-interactive safety fallback
        if !isInteractiveTerminal && !safe && !yes {
            writeToStderr("Warning: Non-interactive terminal detected. Run with --safe or --yes to perform deletions.")
            if json {
                outputScanResult(scannedCategories: scannedCategories, totalBytes: totalBytes)
            }
            throw ExitCode(2)
        }
        
        // Automated cleanups
        if safe {
            try cleanSafe(categories: scannedCategories)
            return
        }
        if yes {
            try cleanAll(categories: scannedCategories)
            return
        }
        
        // Prompt user for global decision (only interactive runs)
        print("Would you like to delete all scanned junk folders at once?")
        let choice = prompt(message: "Options: (y)es / (n)o / (i)nteractive", defaultOption: "i")
        
        if choice == "y" || choice == "yes" {
            try cleanAll(categories: scannedCategories)
        } else if choice == "n" || choice == "no" {
            log("[INFO] Cleaning cancelled. No files were deleted.".colored(.boldYellow))
            log("")
        } else {
            try runInteractive(categories: scannedCategories)
        }
    }
    
    // MARK: - Private Clean Routines
    
    private func cleanAll(categories: [(category: JunkCategory, size: Int64)]) throws {
        log("\nCleaning all junk folders...")
        var totalReclaimed: Int64 = 0
        var details: [DeletionDetail] = []
        
        for (category, size) in categories where size > 0 {
            let (reclaimed, errorMsg) = deleteCategoryWithResult(category, size: size)
            totalReclaimed += reclaimed
            details.append(DeletionDetail(
                id: category.id,
                displayName: category.displayName,
                reclaimedBytes: reclaimed,
                status: reclaimed > 0 ? "success" : "failed",
                error: errorMsg
            ))
        }
        
        if json {
            outputJson(DeletionResult(totalReclaimedBytes: totalReclaimed, deletedCategories: details))
        } else {
            log("=========================================================".colored(.cyan))
            log("Done! Reclaimed a total of ".colored(.boldGreen) + JunkCategory.formatBytes(totalReclaimed).colored(.boldGreen))
            log("")
        }
    }
    
    private func cleanSafe(categories: [(category: JunkCategory, size: Int64)]) throws {
        log("\nCleaning all 100% safe (Group A) junk folders...")
        var totalReclaimed: Int64 = 0
        var details: [DeletionDetail] = []
        
        for (category, size) in categories where size > 0 {
            if category.isSafe {
                let (reclaimed, errorMsg) = deleteCategoryWithResult(category, size: size)
                totalReclaimed += reclaimed
                details.append(DeletionDetail(
                    id: category.id,
                    displayName: category.displayName,
                    reclaimedBytes: reclaimed,
                    status: reclaimed > 0 ? "success" : "failed",
                    error: errorMsg
                ))
            } else {
                details.append(DeletionDetail(
                    id: category.id,
                    displayName: category.displayName,
                    reclaimedBytes: 0,
                    status: "skipped",
                    error: nil
                ))
            }
        }
        
        if json {
            outputJson(DeletionResult(totalReclaimedBytes: totalReclaimed, deletedCategories: details))
        } else {
            log("=========================================================".colored(.cyan))
            log("Done! Reclaimed a total of ".colored(.boldGreen) + JunkCategory.formatBytes(totalReclaimed).colored(.boldGreen))
            log("")
        }
    }
    
    private func runInteractive(categories: [(category: JunkCategory, size: Int64)]) throws {
        log("\nStarting interactive cleaning...")
        var totalReclaimed: Int64 = 0
        var autoApproveRemaining = false
        var details: [DeletionDetail] = []
        
        for (category, size) in categories where size > 0 {
            if autoApproveRemaining {
                let (reclaimed, errorMsg) = deleteCategoryWithResult(category, size: size)
                totalReclaimed += reclaimed
                details.append(DeletionDetail(
                    id: category.id,
                    displayName: category.displayName,
                    reclaimedBytes: reclaimed,
                    status: reclaimed > 0 ? "success" : "failed",
                    error: errorMsg
                ))
                continue
            }
            
            print("\n---------------------------------------------------------")
            print("Category: \(category.displayName)".colored(.boldCyan))
            if category == .unavailableSimulators {
                print("   Action: xcrun simctl delete unavailable".colored(.yellow))
                print("   Description: \(category.description)")
                print("   Status: \(size) unavailable devices found".colored(.boldYellow))
            } else {
                print("   Path: ~/\(category.relativePath)".colored(.yellow))
                print("   Description: \(category.description)")
                print("   Size: " + JunkCategory.formatBytes(size).colored(.boldYellow))
            }
            if !category.isSafe {
                print("   [WARNING] Caution: Deleting this folder resets its state (e.g. simulator runtimes).".colored(.boldRed))
            }
            print("---------------------------------------------------------")
            
            let choice = prompt(message: "Clean this folder? (y)es / (n)o / (a)ll remaining / (q)uit", defaultOption: "n")
            
            if choice == "y" || choice == "yes" {
                let (reclaimed, errorMsg) = deleteCategoryWithResult(category, size: size)
                totalReclaimed += reclaimed
                details.append(DeletionDetail(
                    id: category.id,
                    displayName: category.displayName,
                    reclaimedBytes: reclaimed,
                    status: reclaimed > 0 ? "success" : "failed",
                    error: errorMsg
                ))
            } else if choice == "a" || choice == "all" {
                autoApproveRemaining = true
                let (reclaimed, errorMsg) = deleteCategoryWithResult(category, size: size)
                totalReclaimed += reclaimed
                details.append(DeletionDetail(
                    id: category.id,
                    displayName: category.displayName,
                    reclaimedBytes: reclaimed,
                    status: reclaimed > 0 ? "success" : "failed",
                    error: errorMsg
                ))
            } else if choice == "q" || choice == "quit" {
                log("\nExiting interactive mode.".colored(.boldYellow))
                break
            } else {
                log("[SKIPPED] Skipped \(category.displayName)")
                details.append(DeletionDetail(
                    id: category.id,
                    displayName: category.displayName,
                    reclaimedBytes: 0,
                    status: "skipped",
                    error: nil
                ))
            }
        }
        
        log("\n" + "=========================================================".colored(.cyan))
        log("Interactive run finished! Total reclaimed: ".colored(.boldGreen) + JunkCategory.formatBytes(totalReclaimed).colored(.boldGreen))
        log("")
    }
    
    private func deleteCategoryWithResult(_ category: JunkCategory, size: Int64) -> (Int64, String?) {
        log("Cleaning \(category.displayName)... ", terminator: "")
        fflush(stdout)
        
        do {
            try category.delete()
            if category == .unavailableSimulators {
                log("[SUCCESS] Cleaned \(size) devices".colored(.boldGreen))
                return (0, nil)
            } else {
                log("[SUCCESS] Reclaimed " + JunkCategory.formatBytes(size).colored(.boldGreen))
                return (size, nil)
            }
        } catch {
            log("[ERROR] Failed".colored(.red))
            log("   Error details: \(error.localizedDescription)".colored(.boldRed))
            log("   Note: Please ensure Xcode is closed and you have write permissions to that directory.".colored(.yellow))
            return (0, error.localizedDescription)
        }
    }
    
    // MARK: - Output and Logging Helpers
    
    private func log(_ message: String = "", terminator: String = "\n") {
        guard !quiet && !json else { return }
        print(message, terminator: terminator)
    }
    
    private func writeToStderr(_ text: String) {
        if let data = (text + "\n").data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
    
    private func prompt(message: String, defaultOption: String) -> String {
        print("\(message) [\(defaultOption)]: ", terminator: "")
        fflush(stdout)
        guard let response = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !response.isEmpty else {
            return defaultOption
        }
        return response.lowercased()
    }
    
    private func outputScanResult(scannedCategories: [(category: JunkCategory, size: Int64)], totalBytes: Int64) {
        let scanResult = ScanResult(
            totalBytes: totalBytes,
            categories: scannedCategories.map { item in
                JunkCategoryScanResult(
                    id: item.category.id,
                    displayName: item.category.displayName,
                    relativePath: item.category.relativePath,
                    sizeBytes: item.size,
                    description: item.category.description,
                    isSafe: item.category.isSafe
                )
            }
        )
        outputJson(scanResult)
    }
    
    private func outputJson<T: Encodable>(_ object: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(object),
           let jsonString = String(data: data, encoding: .utf8) {
            print(jsonString)
        }
    }
}
