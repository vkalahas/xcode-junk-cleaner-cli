import Foundation
import ArgumentParser
#if os(macOS)
import AppKit
#endif

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
        commandName: "xcode-junk-cleaner",
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
    
    @Option(name: .long, help: "Comma-separated list of category IDs or file path patterns to exclude from cleaning.")
    var exclude: String?
    
    @Option(name: .long, help: "Install a LaunchAgent plist to run the cleaner periodically (daily, weekly, monthly).")
    var installSchedule: String?
    
    @Flag(name: .long, help: "Uninstall the LaunchAgent plist schedule.")
    var uninstallSchedule: Bool = false
    
    @Option(name: .shortAndLong, help: "Filters directories, scanning and deleting only folders that have not been modified in the specified number of days.")
    var olderThan: Int?
    
    @Option(name: .shortAndLong, help: "Triggers a threshold warning and exits with exit code 3 if the total scanned junk exceeds the specified size limit (e.g. 5GB, 500MB).")
    var threshold: String?
    
    @Flag(name: .shortAndLong, help: "Bypass the active Xcode process check.")
    var force: Bool = false
    
    // Parsed target category IDs
    private var selectedCategoryIds: Set<String> {
        let items = category.flatMap { $0.components(separatedBy: ",") }
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Set(items.filter { !$0.isEmpty })
    }
    
    internal var resolvedExclusions: [String] {
        var list: [String] = []
        
        // Load from CLI
        if let cliExclude = exclude {
            let items = cliExclude.components(separatedBy: ",")
                                  .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            list.append(contentsOf: items.filter { !$0.isEmpty })
        }
        
        // Load from ~/.xcode-junk-cleaner-exclude
        let home = FileManager.default.homeDirectoryForCurrentUser
        let excludeFileURL = home.appendingPathComponent(".xcode-junk-cleaner-exclude")
        if let content = try? String(contentsOf: excludeFileURL, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
                               .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            list.append(contentsOf: lines.filter { !$0.isEmpty && !$0.hasPrefix("#") })
        }
        
        return list
    }
    
    private var isInteractiveTerminal: Bool {
        return isatty(STDIN_FILENO) != 0
    }
    
    private func isXcodeRunning() -> Bool {
        #if os(macOS)
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dt.Xcode")
        return !apps.isEmpty
        #else
        return false
        #endif
    }
    
    internal func parseSizeThreshold(_ sizeStr: String) -> Int64? {
        let trimmed = sizeStr.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if trimmed.hasSuffix("GB") {
            let numStr = trimmed.dropLast(2).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let val = Double(numStr) else { return nil }
            return Int64(val * 1024 * 1024 * 1024)
        } else if trimmed.hasSuffix("MB") {
            let numStr = trimmed.dropLast(2).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let val = Double(numStr) else { return nil }
            return Int64(val * 1024 * 1024)
        } else if trimmed.hasSuffix("KB") {
            let numStr = trimmed.dropLast(2).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let val = Double(numStr) else { return nil }
            return Int64(val * 1024)
        } else if trimmed.hasSuffix("B") {
            let numStr = trimmed.dropLast(1).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let val = Int64(numStr) else { return nil }
            return val
        } else {
            return Int64(trimmed)
        }
    }
    
    private func installScheduler(interval: String) throws {
        #if !os(macOS)
        writeToStderr("[ERROR] LaunchAgent scheduling is only supported on macOS.")
        throw ExitCode(1)
        #else
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let appSupport = home.appendingPathComponent("Library/Application Support/xcode-junk-cleaner")
        let targetExecutable = appSupport.appendingPathComponent("xcode-junk-cleaner")
        
        try fm.createDirectory(at: appSupport, withIntermediateDirectories: true, attributes: nil)
        
        let currentExecutablePath = CommandLine.arguments[0]
        if fm.fileExists(atPath: targetExecutable.path) {
            try? fm.removeItem(at: targetExecutable)
        }
        do {
            try fm.copyItem(atPath: currentExecutablePath, toPath: targetExecutable.path)
        } catch {
            writeToStderr("[ERROR] Failed to copy executable to '\(targetExecutable.path)': \(error.localizedDescription)")
            throw ExitCode(1)
        }
        
        let label = "com.vkalahas.xcode-junk-cleaner"
        let plistURL = home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
        
        var calendarIntervalPlist = ""
        if interval == "daily" {
            calendarIntervalPlist = """
                    <key>Hour</key>
                    <integer>10</integer>
                    <key>Minute</key>
                    <integer>0</integer>
            """
        } else if interval == "weekly" {
            calendarIntervalPlist = """
                    <key>Hour</key>
                    <integer>10</integer>
                    <key>Minute</key>
                    <integer>0</integer>
                    <key>Weekday</key>
                    <integer>1</integer>
            """
        } else if interval == "monthly" {
            calendarIntervalPlist = """
                    <key>Day</key>
                    <integer>1</integer>
                    <key>Hour</key>
                    <integer>10</integer>
                    <key>Minute</key>
                    <integer>0</integer>
            """
        }
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(targetExecutable.path)</string>
                <string>--safe</string>
                <string>--quiet</string>
            </array>
            <key>StartCalendarInterval</key>
            <dict>
        \(calendarIntervalPlist)
            </dict>
        </dict>
        </plist>
        """
        
        let launchAgentsDir = home.appendingPathComponent("Library/LaunchAgents")
        try fm.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true, attributes: nil)
        
        do {
            try plistContent.write(to: plistURL, atomically: true, encoding: .utf8)
        } catch {
            writeToStderr("[ERROR] Failed to write LaunchAgent plist: \(error.localizedDescription)")
            throw ExitCode(1)
        }
        
        let uid = getuid()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootstrap", "gui/\(uid)", plistURL.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        let unloadProcess = Process()
        unloadProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        unloadProcess.arguments = ["bootout", "gui/\(uid)", plistURL.path]
        unloadProcess.standardOutput = Pipe()
        unloadProcess.standardError = Pipe()
        try? unloadProcess.run()
        unloadProcess.waitUntilExit()
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let loadProcess = Process()
                loadProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                loadProcess.arguments = ["load", plistURL.path]
                loadProcess.standardOutput = Pipe()
                loadProcess.standardError = Pipe()
                try loadProcess.run()
                loadProcess.waitUntilExit()
            }
        } catch {
            // Ignore error
        }
        
        print("[SUCCESS] Scheduled background cleaning task successfully (\(interval)).")
        print("   Binary installed to: \(targetExecutable.path)")
        print("   LaunchAgent plist created at: \(plistURL.path)")
        #endif
    }
    
    private func uninstallScheduler() throws {
        #if !os(macOS)
        writeToStderr("[ERROR] LaunchAgent scheduling is only supported on macOS.")
        throw ExitCode(1)
        #else
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let appSupport = home.appendingPathComponent("Library/Application Support/xcode-junk-cleaner")
        let label = "com.vkalahas.xcode-junk-cleaner"
        let plistURL = home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
        
        let uid = getuid()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "gui/\(uid)", plistURL.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let unloadProcess = Process()
                unloadProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                unloadProcess.arguments = ["unload", plistURL.path]
                unloadProcess.standardOutput = Pipe()
                unloadProcess.standardError = Pipe()
                try unloadProcess.run()
                unloadProcess.waitUntilExit()
            }
        } catch {
            // Ignore error
        }
        
        if fm.fileExists(atPath: plistURL.path) {
            try? fm.removeItem(at: plistURL)
        }
        if fm.fileExists(atPath: appSupport.path) {
            try? fm.removeItem(at: appSupport)
        }
        
        print("[SUCCESS] Unscheduled background cleaning task successfully and removed installed binaries.")
        #endif
    }
    
    func run() throws {
        // Scheduler commands check
        if let schedule = installSchedule {
            let val = schedule.lowercased()
            guard val == "daily" || val == "weekly" || val == "monthly" else {
                writeToStderr("[ERROR] Invalid schedule interval: '\(schedule)'. Choose from: daily, weekly, monthly.")
                throw ExitCode(1)
            }
            try installScheduler(interval: val)
            return
        }
        
        if uninstallSchedule {
            try uninstallScheduler()
            return
        }

        // Xcode process check
        if isXcodeRunning() && !force {
            if isInteractiveTerminal && !json && !quiet {
                print("[WARNING] Xcode is currently running. Cleaning cache files while Xcode is running may cause instability or build failures.".colored(.boldYellow))
                let answer = prompt(message: "Do you want to continue anyway? (y/n)", defaultOption: "n")
                if answer != "y" && answer != "yes" {
                    log("[INFO] Aborted by user because Xcode is running.")
                    throw ExitCode(4)
                }
            } else {
                writeToStderr("[ERROR] Xcode is currently running. Close Xcode or use --force (-f) to bypass this check.")
                throw ExitCode(4)
            }
        }

        // Banner (silenced in quiet/json modes)
        log("")
        log("Xcode Junk Cleaner CLI v1.0.0".colored(.boldCyan))
        log("=========================================================".colored(.cyan))
        log("Scanning Xcode junk folders...")
        
        // Resolve target categories based on filtering
        let selection = selectedCategoryIds
        let exclusions = resolvedExclusions
        let initialCategories: [JunkCategory]
        if !selection.isEmpty {
            let matched = selection.compactMap { JunkCategory.from(id: $0) }
            if matched.isEmpty {
                writeToStderr("Error: None of the specified categories matched valid IDs.")
                throw ExitCode(1)
            }
            initialCategories = matched
        } else {
            initialCategories = JunkCategory.allCases
        }
        
        let targetCategories = initialCategories.filter { category in
            !exclusions.contains { pattern in
                category.id.lowercased() == pattern.lowercased()
            }
        }
        
        var scannedCategories: [(category: JunkCategory, size: Int64)] = []
        var totalBytes: Int64 = 0
        
        for category in targetCategories {
            log("   Analyzing \(category.displayName)... ", terminator: "")
            fflush(stdout)
            
            let size = category.calculateSize(olderThanDays: olderThan, exclusions: exclusions)
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
        
        fflush(stdout)
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
        
        // Threshold check
        if let thresholdStr = threshold {
            guard let limit = parseSizeThreshold(thresholdStr) else {
                writeToStderr("[ERROR] Invalid size threshold format: '\(thresholdStr)'. Please use formats like 5GB, 500MB, 10KB, or raw bytes.")
                throw ExitCode(1)
            }
            if totalBytes > limit {
                fflush(stdout)
                if json {
                    outputScanResult(scannedCategories: scannedCategories, totalBytes: totalBytes)
                } else {
                    writeToStderr("[WARNING] Scanned junk size of \(JunkCategory.formatBytes(totalBytes)) exceeds the threshold of \(thresholdStr).")
                }
                throw ExitCode(3)
            }
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
            try category.delete(olderThanDays: self.olderThan, exclusions: self.resolvedExclusions)
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
