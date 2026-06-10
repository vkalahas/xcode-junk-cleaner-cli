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
    let totalReclaimedSinceInstallBytes: Int64
    
    enum CodingKeys: String, CodingKey {
        case totalReclaimedBytes = "total_reclaimed_bytes"
        case deletedCategories = "deleted_categories"
        case totalReclaimedSinceInstallBytes = "total_reclaimed_since_install_bytes"
    }
}

struct HistoricalCleanup: Codable {
    let date: Date
    let categories: [String]
    let reclaimedBytes: Int64
}

final class ScanStateManager: @unchecked Sendable {
    private let lock = NSLock()
    private var states: [CategoryState] = []
    private var hasPrinted = false
    
    struct CategoryState {
        let category: JunkCategory
        var size: Int64?
        var animationStep: Int
    }
    
    init(categories: [JunkCategory]) {
        self.states = categories.map { CategoryState(category: $0, size: nil, animationStep: 0) }
    }
    
    func updateSize(for category: JunkCategory, size: Int64) {
        lock.lock()
        defer { lock.unlock() }
        if let index = states.firstIndex(where: { $0.category == category }) {
            states[index].size = size
        }
    }
    
    func incrementAnimation() {
        lock.lock()
        defer { lock.unlock() }
        for i in 0..<states.count {
            if states[i].size == nil {
                states[i].animationStep += 1
            }
        }
    }
    
    func getSnapshot() -> [CategoryState] {
        lock.lock()
        defer { lock.unlock() }
        return states
    }
    
    func setHasPrinted() {
        lock.lock()
        defer { lock.unlock() }
        hasPrinted = true
    }
    
    var didPrint: Bool {
        lock.lock()
        defer { lock.unlock() }
        return hasPrinted
    }
    
    var completedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return states.filter { $0.size != nil }.count
    }
    
    var totalCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return states.count
    }
}

// MARK: - Main Command

@main
struct XcodeJunkCleaner: AsyncParsableCommand {
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
    
    @Flag(name: .long, help: "List all custom exclusion patterns in ~/.xcode-junk-cleaner-exclude.")
    var listExclude: Bool = false
    
    @Option(name: .long, help: "Add a custom exclusion pattern to ~/.xcode-junk-cleaner-exclude.")
    var addExclude: String?
    
    @Option(name: .long, help: "Remove a custom exclusion pattern from ~/.xcode-junk-cleaner-exclude.")
    var removeExclude: String?
    
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
    
    @Option(name: .shortAndLong, help: "Create backup zip archives of directories/files under the specified folder before deletion.")
    var backup: String?
    
    internal var homeDirectoryOverride: URL?
    
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
        let home = homeDirectoryOverride ?? FileManager.default.homeDirectoryForCurrentUser
        let excludeFileURL = home.appendingPathComponent(".xcode-junk-cleaner-exclude")
        if let content = try? String(contentsOf: excludeFileURL, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
                               .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            list.append(contentsOf: lines.filter { !$0.isEmpty && !$0.hasPrefix("#") })
        }
        
        return list
    }
    
    internal var resolvedBackupURL: URL? {
        guard let backupPath = backup else { return nil }
        return URL(fileURLWithPath: (backupPath as NSString).expandingTildeInPath)
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
    
    private func isSimulatorRunning() -> Bool {
        #if os(macOS)
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.iphonesimulator")
        return !apps.isEmpty
        #else
        return false
        #endif
    }
    private func animatedProgressBar(step: Int, width: Int = 20) -> String {
        let blockWidth = 3
        let maxPos = width - blockWidth
        guard maxPos > 0 else { return "[\(String(repeating: "░", count: width))]" }
        
        let cycle = maxPos * 2
        let posInCycle = step % cycle
        let position = posInCycle < maxPos ? posInCycle : (cycle - posInCycle)
        
        var chars = Array(repeating: "░", count: width)
        for i in 0..<blockWidth {
            chars[position + i] = "█"
        }
        return "[\(chars.joined())]"
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
    
    private func runLaunchctl(arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
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
        let plistPath = plistURL.path
        
        // Unload first just in case
        _ = runLaunchctl(arguments: ["bootout", "gui/\(uid)", plistPath])
        
        let status = runLaunchctl(arguments: ["bootstrap", "gui/\(uid)", plistPath])
        if status != 0 {
            // Fallback to load
            _ = runLaunchctl(arguments: ["load", plistPath])
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
        let plistPath = plistURL.path
        
        let status = runLaunchctl(arguments: ["bootout", "gui/\(uid)", plistPath])
        if status != 0 {
            _ = runLaunchctl(arguments: ["unload", plistPath])
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
    
    internal func getExcludeFileURL() -> URL {
        let home = homeDirectoryOverride ?? FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".xcode-junk-cleaner-exclude")
    }
    
    internal func listExclusionPatterns() throws {
        let fileURL = getExcludeFileURL()
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            print("No custom exclusion patterns configured (exclude file does not exist).")
            return
        }
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
                               .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                               .filter { !$0.isEmpty }
            if lines.isEmpty {
                print("No custom exclusion patterns configured (exclude file is empty).")
            } else {
                print("Custom exclusion patterns:")
                for line in lines {
                    print("  \(line)")
                }
            }
        } catch {
            writeToStderr("[ERROR] Failed to read exclude file: \(error.localizedDescription)")
            throw ExitCode(1)
        }
    }
    
    internal func addExclusionPattern(_ pattern: String) throws {
        let fileURL = getExcludeFileURL()
        let fm = FileManager.default
        var lines: [String] = []
        if fm.fileExists(atPath: fileURL.path) {
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                lines = content.components(separatedBy: .newlines)
                               .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                               .filter { !$0.isEmpty }
            }
        }
        
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            writeToStderr("[ERROR] Exclusion pattern cannot be empty.")
            throw ExitCode(1)
        }
        
        if lines.contains(trimmed) {
            print("Pattern '\(trimmed)' is already in the exclusion list.")
            return
        }
        
        lines.append(trimmed)
        let newContent = lines.joined(separator: "\n") + "\n"
        do {
            try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("[SUCCESS] Added pattern '\(trimmed)' to exclusions.")
        } catch {
            writeToStderr("[ERROR] Failed to write exclude file: \(error.localizedDescription)")
            throw ExitCode(1)
        }
    }
    
    internal func removeExclusionPattern(_ pattern: String) throws {
        let fileURL = getExcludeFileURL()
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            print("No exclusion patterns configured (exclude file does not exist).")
            return
        }
        
        var lines: [String] = []
        if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
            lines = content.components(separatedBy: .newlines)
                           .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                           .filter { !$0.isEmpty }
        }
        
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            writeToStderr("[ERROR] Exclusion pattern cannot be empty.")
            throw ExitCode(1)
        }
        
        guard let index = lines.firstIndex(of: trimmed) else {
            print("Pattern '\(trimmed)' not found in the exclusion list.")
            return
        }
        
        lines.remove(at: index)
        let newContent = lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
        do {
            try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("[SUCCESS] Removed pattern '\(trimmed)' from exclusions.")
        } catch {
            writeToStderr("[ERROR] Failed to write exclude file: \(error.localizedDescription)")
            throw ExitCode(1)
        }
    }
    
    internal func getHistoryFileURL() -> URL {
        let home = homeDirectoryOverride ?? FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".xcode-junk-cleaner-history.json")
    }
    
    internal func getHistoricalTotalReclaimedBytes() -> Int64 {
        let fileURL = getHistoryFileURL()
        guard let data = try? Data(contentsOf: fileURL),
              let history = try? JSONDecoder().decode([HistoricalCleanup].self, from: data) else {
            return 0
        }
        return history.reduce(0) { $0 + $1.reclaimedBytes }
    }
    
    internal func appendHistoricalCleanup(categories: [String], reclaimedBytes: Int64) {
        let fileURL = getHistoryFileURL()
        let fm = FileManager.default
        var history: [HistoricalCleanup] = []
        if fm.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([HistoricalCleanup].self, from: data) {
            history = decoded
        }
        
        let newRecord = HistoricalCleanup(date: Date(), categories: categories, reclaimedBytes: reclaimedBytes)
        history.append(newRecord)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(history) {
            try? data.write(to: fileURL)
        }
    }
    
    func run() async throws {
        // Exclusion CLI Management commands check
        if listExclude {
            try listExclusionPatterns()
            return
        }
        if let patternToAdd = addExclude {
            try addExclusionPattern(patternToAdd)
            return
        }
        if let patternToRemove = removeExclude {
            try removeExclusionPattern(patternToRemove)
            return
        }

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

        // Xcode and Simulator process check
        let xcodeRunning = isXcodeRunning()
        let simulatorRunning = isSimulatorRunning()
        if (xcodeRunning || simulatorRunning) && !force {
            let appNames = [xcodeRunning ? "Xcode" : nil, simulatorRunning ? "Simulator" : nil].compactMap { $0 }.joined(separator: " and ")
            if isInteractiveTerminal && !json && !quiet {
                print("[WARNING] \(appNames) currently running. Cleaning cache files while they are running may cause instability, build failures, or state corruption.".colored(.boldYellow))
                let answer = prompt(message: "Do you want to continue anyway? (y/n)", defaultOption: "n")
                if answer != "y" && answer != "yes" {
                    log("[INFO] Aborted by user because active application(s) are running.")
                    throw ExitCode(4)
                }
            } else {
                writeToStderr("[ERROR] \(appNames) currently running. Close active application(s) or use --force (-f) to bypass this check.")
                throw ExitCode(4)
            }
        }

        // Validate backup directory if specified
        if let backupPath = backup {
            let fm = FileManager.default
            let resolvedURL = URL(fileURLWithPath: (backupPath as NSString).expandingTildeInPath)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: resolvedURL.path, isDirectory: &isDir) {
                if !isDir.boolValue {
                    writeToStderr("[ERROR] Backup path '\(backupPath)' exists but is not a directory.")
                    throw ExitCode(1)
                }
            } else {
                do {
                    try fm.createDirectory(at: resolvedURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    writeToStderr("[ERROR] Failed to create backup directory '\(backupPath)': \(error.localizedDescription)")
                    throw ExitCode(1)
                }
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
        
        if targetCategories.isEmpty {
            if json {
                outputJson(ScanResult(totalBytes: 0, categories: []))
            } else {
                log("No Xcode junk categories selected/matched. Your system is clean.".colored(.boldGreen))
                log("")
            }
            return
        }
        
        var scannedCategories: [(category: JunkCategory, size: Int64)] = []
        var totalBytes: Int64 = 0
        
        let stateManager = ScanStateManager(categories: targetCategories)
        let isSpinnerEnabled = isInteractiveTerminal && !json && !quiet
        
        var spinnerTask: Task<Void, Never>? = nil
        if isSpinnerEnabled {
            spinnerTask = Task {
                let n = targetCategories.count
                while !Task.isCancelled {
                    stateManager.incrementAnimation()
                    let snapshot = stateManager.getSnapshot()
                    
                    var output = ""
                    for state in snapshot {
                        let categoryName = state.category.displayName.padding(toLength: 30, withPad: " ", startingAt: 0)
                        let bar: String
                        let statusText: String
                        if let size = state.size {
                            bar = ("[" + String(repeating: "█", count: 20) + "]").colored(.green)
                            let sizeStr = (state.category == .unavailableSimulators || state.category == .previewSimulators) ? "\(size) devices" : JunkCategory.formatBytes(size)
                            if size > 0 {
                                statusText = sizeStr.colored(.boldYellow)
                            } else {
                                statusText = "0 B (Clean)".colored(.green)
                            }
                        } else {
                            bar = animatedProgressBar(step: state.animationStep).colored(.cyan)
                            statusText = "Analyzing...".colored(.white)
                        }
                        output += "\r\u{001B}[K   Analyzing \(categoryName)... \(bar) \(statusText)\n"
                    }
                    
                    // Move cursor up n lines
                    output += "\u{001B}[\(n)A"
                    
                    print(output, terminator: "")
                    fflush(stdout)
                    stateManager.setHasPrinted()
                    
                    try? await Task.sleep(nanoseconds: 80_000_000)
                }
            }
        }
        
        let targetCategoriesWithIndices = targetCategories.enumerated().map { ($0, $1) }
        let resultsWithIndices = await withTaskGroup(of: (Int, JunkCategory, Int64).self) { group in
            for (index, category) in targetCategoriesWithIndices {
                group.addTask {
                    let size = category.calculateSize(olderThanDays: olderThan, exclusions: exclusions)
                    stateManager.updateSize(for: category, size: size)
                    return (index, category, size)
                }
            }
            
            var list: [(Int, JunkCategory, Int64)] = []
            for await item in group {
                list.append(item)
            }
            return list.sorted { $0.0 < $1.0 }
        }
        
        if let spinnerTask = spinnerTask {
            spinnerTask.cancel()
            _ = await spinnerTask.result
            
            let snapshot = stateManager.getSnapshot()
            var output = ""
            for state in snapshot {
                let categoryName = state.category.displayName.padding(toLength: 30, withPad: " ", startingAt: 0)
                let bar: String
                let statusText: String
                if let size = state.size {
                    bar = ("[" + String(repeating: "█", count: 20) + "]").colored(.green)
                    let sizeStr = (state.category == .unavailableSimulators || state.category == .previewSimulators) ? "\(size) devices" : JunkCategory.formatBytes(size)
                    if size > 0 {
                        statusText = sizeStr.colored(.boldYellow)
                    } else {
                        statusText = "0 B (Clean)".colored(.green)
                    }
                } else {
                    bar = ("[" + String(repeating: "█", count: 20) + "]").colored(.green)
                    statusText = "0 B (Clean)".colored(.green)
                }
                output += "\r\u{001B}[K   Analyzing \(categoryName)... \(bar) \(statusText)\n"
            }
            print(output, terminator: "")
            fflush(stdout)
        }
        
        scannedCategories = resultsWithIndices.map { ($0.1, $0.2) }
        totalBytes = scannedCategories.reduce(0) { $0 + $1.1 }
        
        // Non-spinner fallback text logs for file redirection
        if !isSpinnerEnabled && !quiet && !json {
            for (category, size) in scannedCategories {
                let sizeStr = (category == .unavailableSimulators || category == .previewSimulators) ? "\(size) devices" : JunkCategory.formatBytes(size)
                let displaySize = size > 0 ? sizeStr.colored(.boldYellow) : "0 B (Clean)".colored(.green)
                print("   Analyzing \(category.displayName)... \(displaySize)")
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
                } else if category == .previewSimulators {
                    pathDisplay = "xcrun simctl --set previews delete all"
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
    
    private func runBulkCleanup(categories: [(category: JunkCategory, size: Int64)], cleanAllCategories: Bool) throws {
        let modeName = cleanAllCategories ? "all junk folders" : "all 100% safe (Group A) junk folders"
        log("\nCleaning \(modeName)...")
        
        var totalReclaimed: Int64 = 0
        var details: [DeletionDetail] = []
        
        for (category, size) in categories where size > 0 {
            let shouldClean = cleanAllCategories || category.isSafe
            if shouldClean {
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
        
        if totalReclaimed > 0 {
            let deletedIds = details.filter { $0.reclaimedBytes > 0 }.map { $0.id }
            appendHistoricalCleanup(categories: deletedIds, reclaimedBytes: totalReclaimed)
        }
        
        let historicalTotal = getHistoricalTotalReclaimedBytes()
        
        if json {
            outputJson(DeletionResult(
                totalReclaimedBytes: totalReclaimed,
                deletedCategories: details,
                totalReclaimedSinceInstallBytes: historicalTotal
            ))
        } else {
            log("=========================================================".colored(.cyan))
            log("Done! Reclaimed a total of ".colored(.boldGreen) + JunkCategory.formatBytes(totalReclaimed).colored(.boldGreen))
            log("Total space reclaimed since install: ".colored(.boldGreen) + JunkCategory.formatBytes(historicalTotal).colored(.boldGreen))
            log("")
        }
    }
    
    private func cleanAll(categories: [(category: JunkCategory, size: Int64)]) throws {
        try runBulkCleanup(categories: categories, cleanAllCategories: true)
    }
    
    private func cleanSafe(categories: [(category: JunkCategory, size: Int64)]) throws {
        try runBulkCleanup(categories: categories, cleanAllCategories: false)
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
            } else if category == .previewSimulators {
                print("   Action: xcrun simctl --set previews delete all".colored(.yellow))
                print("   Description: \(category.description)")
                print("   Status: \(size) preview devices found".colored(.boldYellow))
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
        
        if totalReclaimed > 0 {
            let deletedIds = details.filter { $0.reclaimedBytes > 0 }.map { $0.id }
            appendHistoricalCleanup(categories: deletedIds, reclaimedBytes: totalReclaimed)
        }
        
        let historicalTotal = getHistoricalTotalReclaimedBytes()
        
        log("\n" + "=========================================================".colored(.cyan))
        log("Interactive run finished! Total reclaimed: ".colored(.boldGreen) + JunkCategory.formatBytes(totalReclaimed).colored(.boldGreen))
        log("Total space reclaimed since install: ".colored(.boldGreen) + JunkCategory.formatBytes(historicalTotal).colored(.boldGreen))
        log("")
    }
    
    private func deleteCategoryWithResult(_ category: JunkCategory, size: Int64) -> (Int64, String?) {
        log("Cleaning \(category.displayName)... ", terminator: "")
        fflush(stdout)
        
        do {
            try category.delete(olderThanDays: self.olderThan, exclusions: self.resolvedExclusions, backupDir: self.resolvedBackupURL)
            if category == .unavailableSimulators || category == .previewSimulators {
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
