import Foundation

public enum JunkCategory: String, CaseIterable {
    case derivedData = "DerivedData"
    case archives = "Archives"
    case iOSDeviceSupport = "iOS DeviceSupport"
    case watchOSDeviceSupport = "watchOS DeviceSupport"
    case tvOSDeviceSupport = "tvOS DeviceSupport"
    case simulatorDevices = "Simulator Devices"
    case simulatorCaches = "Simulator Caches"
    case xcodeCaches = "Xcode Caches"
    case spmCaches = "Swift Package Manager Caches"
    case deviceLogs = "Device Logs"
    case userSimulatorRuntimes = "User Simulator Runtimes"
    case cocoaPodsCache = "CocoaPods Cache"
    case carthageCache = "Carthage Cache"
    case simulatorLogs = "Simulator Logs"
    case playgroundTemp = "Playground Temporary Files"
    case mobileDeviceCrashLogs = "MobileDevice Crash Logs"
    
    // Advanced/Hidden Categories
    case orphanedDerivedData = "Orphaned Derived Data"
    case transporterCache = "Transporter Cache"
    case transporterInstall = "Transporter Installation Cache"
    case unavailableSimulators = "Unavailable Simulators"
    
    // Phase 2 Categories
    case xrOSDeviceSupport = "visionOS (xrOS) DeviceSupport"
    case visionOSDeviceSupport = "visionOS DeviceSupport"
    case interfaceBuilderCache = "Interface Builder Cache"
    case legacyDocSets = "Legacy DocSets"
    case cocoaPodsRepos = "CocoaPods Master Specs Repo"
    case transporterLogs = "Transporter Logs"
    case xcodeDiagnosticReports = "Xcode Diagnostic Reports"
    
    public var displayName: String {
        switch self {
        case .derivedData: return "Derived Data"
        case .archives: return "Archives"
        case .iOSDeviceSupport: return "iOS DeviceSupport"
        case .watchOSDeviceSupport: return "watchOS DeviceSupport"
        case .tvOSDeviceSupport: return "tvOS DeviceSupport"
        case .simulatorDevices: return "Simulator Devices"
        case .simulatorCaches: return "Simulator Caches"
        case .xcodeCaches: return "Xcode Caches"
        case .spmCaches: return "Swift Package Manager Caches"
        case .deviceLogs: return "Device Logs"
        case .userSimulatorRuntimes: return "User Simulator Runtimes"
        case .cocoaPodsCache: return "CocoaPods Cache"
        case .carthageCache: return "Carthage Cache"
        case .simulatorLogs: return "Simulator Logs"
        case .playgroundTemp: return "Playground Temporary Files"
        case .mobileDeviceCrashLogs: return "MobileDevice Crash Logs"
        case .orphanedDerivedData: return "Orphaned Derived Data"
        case .transporterCache: return "Transporter Cache"
        case .transporterInstall: return "Transporter Installation Cache"
        case .unavailableSimulators: return "Unavailable Simulators"
        case .xrOSDeviceSupport: return "visionOS (xrOS) DeviceSupport"
        case .visionOSDeviceSupport: return "visionOS DeviceSupport"
        case .interfaceBuilderCache: return "Interface Builder Cache"
        case .legacyDocSets: return "Legacy DocSets"
        case .cocoaPodsRepos: return "CocoaPods Master Specs Repo"
        case .transporterLogs: return "Transporter Logs"
        case .xcodeDiagnosticReports: return "Xcode Diagnostic Reports"
        }
    }
    
    public var relativePath: String {
        switch self {
        case .derivedData:
            return "Library/Developer/Xcode/DerivedData"
        case .archives:
            return "Library/Developer/Xcode/Archives"
        case .iOSDeviceSupport:
            return "Library/Developer/Xcode/iOS DeviceSupport"
        case .watchOSDeviceSupport:
            return "Library/Developer/Xcode/watchOS DeviceSupport"
        case .tvOSDeviceSupport:
            return "Library/Developer/Xcode/tvOS DeviceSupport"
        case .simulatorDevices:
            return "Library/Developer/CoreSimulator/Devices"
        case .simulatorCaches:
            return "Library/Developer/CoreSimulator/Caches"
        case .xcodeCaches:
            return "Library/Caches/com.apple.dt.Xcode"
        case .spmCaches:
            return "Library/Caches/org.swift.swiftpm"
        case .deviceLogs:
            return "Library/Developer/Xcode/DeviceLogs"
        case .userSimulatorRuntimes:
            return "Library/Developer/Developer/CoreSimulator/Profiles/Runtimes"
        case .cocoaPodsCache:
            return "Library/Caches/CocoaPods"
        case .carthageCache:
            return "Library/Caches/org.carthage.CarthageKit"
        case .simulatorLogs:
            return "Library/Logs/CoreSimulator"
        case .playgroundTemp:
            return "Library/Developer/Xcode/UserData/PlaygroundTemp"
        case .mobileDeviceCrashLogs:
            return "Library/Logs/CrashReporter/MobileDevice"
        case .orphanedDerivedData:
            return "Library/Developer/Xcode/DerivedData"
        case .transporterCache:
            return "Library/Caches/com.apple.amp.itmstransporter"
        case .transporterInstall:
            return ".itmstransporter"
        case .unavailableSimulators:
            return ""
        case .xrOSDeviceSupport:
            return "Library/Developer/Xcode/xrOS DeviceSupport"
        case .visionOSDeviceSupport:
            return "Library/Developer/Xcode/visionOS DeviceSupport"
        case .interfaceBuilderCache:
            return "Library/Caches/com.apple.dt.InterfaceBuilder"
        case .legacyDocSets:
            return "Library/Developer/Shared/Documentation/DocSets"
        case .cocoaPodsRepos:
            return ".cocoapods/repos"
        case .transporterLogs:
            return "Library/Logs/com.apple.amp.itmstransporter"
        case .xcodeDiagnosticReports:
            return "Library/Logs/DiagnosticReports"
        }
    }
    
    public var description: String {
        switch self {
        case .derivedData:
            return "Build output, indexes, and intermediate files. Xcode will rebuild them."
        case .archives:
            return "App store distribution builds. You will lose historical archives (used for crash symbolication)."
        case .iOSDeviceSupport:
            return "Debugging symbols for iOS devices. Xcode regenerates them when devices connect."
        case .watchOSDeviceSupport:
            return "Debugging symbols for watchOS devices."
        case .tvOSDeviceSupport:
            return "Debugging symbols for tvOS devices."
        case .simulatorDevices:
            return "Simulated device files. Resets simulator settings and deletes app documents/states."
        case .simulatorCaches:
            return "Cache files generated by active or past simulator sessions."
        case .xcodeCaches:
            return "Xcode internal caches and temporary files."
        case .spmCaches:
            return "SPM dependency clones and checkout caches. Swift builds will re-fetch them."
        case .deviceLogs:
            return "Synced crash logs from connected physical devices."
        case .userSimulatorRuntimes:
            return "Downloaded OS runtimes. Deleting will remove these OS versions from simulator options."
        case .cocoaPodsCache:
            return "Cached CocoaPods library downloads and repository specifications."
        case .carthageCache:
            return "Carthage dependency downloads and pre-built binaries."
        case .simulatorLogs:
            return "Developer log files produced by iOS simulators."
        case .playgroundTemp:
            return "Xcode Swift Playground temporary execution cache."
        case .mobileDeviceCrashLogs:
            return "Crash reports synced from connected physical devices."
        case .orphanedDerivedData:
            return "Derived Data folders referencing projects or workspaces that no longer exist on your disk."
        case .transporterCache:
            return "Temporary files, uploads caches, and token logs created by the iTunes Transporter utility."
        case .transporterInstall:
            return "Cached transporter engine binaries, runtime downloads, and package updates."
        case .unavailableSimulators:
            return "Simulator devices that are no longer supported by your current Xcode install."
        case .xrOSDeviceSupport:
            return "Debugging symbols for visionOS (xrOS) AVP devices. Safe to delete."
        case .visionOSDeviceSupport:
            return "Debugging symbols for Apple Vision Pro (visionOS) devices. Safe to delete."
        case .interfaceBuilderCache:
            return "Cached storyboard/xib rendering results and Interface Builder state."
        case .legacyDocSets:
            return "Legacy downloaded Xcode developer documentation sets."
        case .cocoaPodsRepos:
            return "Local Git clone of the CocoaPods master spec repository (can grow to several gigabytes)."
        case .transporterLogs:
            return "Upload log files created during App Store Connect delivery."
        case .xcodeDiagnosticReports:
            return "Diagnostic logs and crash reports related to Xcode, Simulator, SourceKit, or Swift compiler failures."
        }
    }
    
    public var isSafe: Bool {
        switch self {
        case .archives, .simulatorDevices, .userSimulatorRuntimes:
            return false // Deleting these requires caution / resets simulator setups or runtimes
        default:
            return true
        }
    }
    
    public var url: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(relativePath)
    }
    
    public var exists: Bool {
        switch self {
        case .unavailableSimulators:
            return countUnavailableSimulators() > 0
        case .xcodeDiagnosticReports:
            return !getDiagnosticReportURLs().isEmpty
        default:
            return FileManager.default.fileExists(atPath: url.path)
        }
    }
    
    /// Calculates directory size recursively in bytes.
    private func getURLSize(url: URL, fm: FileManager) -> Int64 {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        
        if !isDir.boolValue {
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }
        
        let properties: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: properties,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: Set(properties)),
               let isDirectory = values.isDirectory, !isDirectory,
               let fileSize = values.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        return totalSize
    }

    public func calculateSize(home: URL = FileManager.default.homeDirectoryForCurrentUser, olderThanDays: Int? = nil, exclusions: [String] = []) -> Int64 {
        if self == .unavailableSimulators {
            return Int64(countUnavailableSimulators())
        }
        
        let fm = FileManager.default
        let urls = getChildren(home: home, olderThanDays: olderThanDays, exclusions: exclusions)
        var totalSize: Int64 = 0
        
        for url in urls {
            totalSize += getURLSize(url: url, fm: fm)
        }
        
        return totalSize
    }
    
    private func runBackup(url: URL, category: JunkCategory, backupDir: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return true }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        
        let zipName = "\(category.id)_\(url.lastPathComponent)_\(timestamp).zip"
        let destURL = backupDir.appendingPathComponent(zipName)
        
        print("   [BACKUP] Archiving to \(destURL.path)... ", terminator: "")
        fflush(stdout)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", url.path, destURL.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                print("[DONE]")
                fflush(stdout)
                return true
            } else {
                print("[FAILED]")
                fflush(stdout)
                return false
            }
        } catch {
            print("[FAILED]")
            fflush(stdout)
            return false
        }
    }

    /// Deletes the folder and its contents recursively.
    public func delete(home: URL = FileManager.default.homeDirectoryForCurrentUser, olderThanDays: Int? = nil, exclusions: [String] = [], backupDir: URL? = nil) throws {
        let fm = FileManager.default
        
        switch self {
        case .unavailableSimulators:
            try deleteUnavailableSimulators()
            return
        default:
            break
        }
        
        if olderThanDays == nil && exclusions.isEmpty {
            if self == .simulatorDevices {
                try eraseAllSimulators()
            } else {
                let targetURL = home.appendingPathComponent(relativePath)
                guard fm.fileExists(atPath: targetURL.path) else { return }
                if let bDir = backupDir {
                    guard runBackup(url: targetURL, category: self, backupDir: bDir) else {
                        throw NSError(domain: "JunkCategory", code: 1, userInfo: [NSLocalizedDescriptionKey: "Backup failed for \(targetURL.lastPathComponent)"])
                    }
                }
                try fm.removeItem(at: targetURL)
            }
        } else {
            let urls = getChildren(home: home, olderThanDays: olderThanDays, exclusions: exclusions)
            for url in urls {
                if let bDir = backupDir {
                    if runBackup(url: url, category: self, backupDir: bDir) {
                        try? fm.removeItem(at: url)
                    } else {
                        print("   [WARNING] Skipping deletion of \(url.lastPathComponent) due to backup failure.")
                    }
                } else {
                    try? fm.removeItem(at: url)
                }
            }
        }
    }
    
    /// Helper to format bytes to human readable string
    public static func formatBytes(_ bytes: Int64) -> String {
        let isNegative = bytes < 0
        let absoluteBytes = abs(bytes)
        
        let kb = Double(absoluteBytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        
        let prefix = isNegative ? "-" : ""
        
        if gb >= 1.0 {
            return String(format: "%@%.2f GB", prefix, gb)
        } else if mb >= 1.0 {
            return String(format: "%@%.2f MB", prefix, mb)
        } else if kb >= 1.0 {
            return String(format: "%@%.2f KB", prefix, kb)
        } else {
            return "\(prefix)\(absoluteBytes) B"
        }
    }
    
    // MARK: - Private / Internal Helpers for Advanced Cleanups
    
    internal func isURLOlderThan(url: URL, days: Int) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return false
        }
        let thresholdDate = Date().addingTimeInterval(TimeInterval(-days * 24 * 60 * 60))
        return modDate < thresholdDate
    }
    
    internal func getChildren(home: URL = FileManager.default.homeDirectoryForCurrentUser, olderThanDays: Int? = nil, exclusions: [String] = []) -> [URL] {
        let fm = FileManager.default
        
        var urls: [URL]
        if self == .unavailableSimulators {
            urls = []
        } else if self == .orphanedDerivedData {
            urls = getOrphanedDerivedDataURLs(home: home)
        } else if self == .xcodeDiagnosticReports {
            urls = getDiagnosticReportURLs(home: home)
        } else {
            let targetURL = home.appendingPathComponent(relativePath)
            urls = (try? fm.contentsOfDirectory(at: targetURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        }
        
        if let days = olderThanDays {
            urls = urls.filter { isURLOlderThan(url: $0, days: days) }
        }
        
        if !exclusions.isEmpty {
            urls = urls.filter { url in
                let path = url.path
                return !exclusions.contains { pattern in
                    path.lowercased().contains(pattern.lowercased())
                }
            }
        }
        
        return urls
    }
    
    internal func getOrphanedDerivedDataURLs(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        let fm = FileManager.default
        let derivedDataURL = home.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        guard let contents = try? fm.contentsOfDirectory(at: derivedDataURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        
        var orphanedURLs: [URL] = []
        for folderURL in contents {
            let plistURL = folderURL.appendingPathComponent("info.plist")
            guard fm.fileExists(atPath: plistURL.path) else { continue }
            
            if let plistData = try? Data(contentsOf: plistURL),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
               let workspacePath = plist["WorkspacePath"] as? String {
                // Check if the source workspace / project file still exists on disk
                if !fm.fileExists(atPath: workspacePath) {
                    orphanedURLs.append(folderURL)
                }
            }
        }
        return orphanedURLs
    }
    
    internal func getDiagnosticReportURLs(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        let fm = FileManager.default
        let diagURL = home.appendingPathComponent("Library/Logs/DiagnosticReports")
        guard let contents = try? fm.contentsOfDirectory(at: diagURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        
        let prefixes = ["Xcode_", "swift-frontend_", "Simulator_", "ibtool_", "simctl_", "actool_", "lldb-rpc-server_", "swift-connection_"]
        return contents.filter { url in
            let filename = url.lastPathComponent
            return prefixes.contains { prefix in filename.hasPrefix(prefix) }
        }
    }
    
    private func runSimctl(arguments: [String], captureOutput: Bool = false) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + arguments
        
        let pipe = Pipe()
        if captureOutput {
            process.standardOutput = pipe
        } else {
            process.standardOutput = Pipe()
        }
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            if captureOutput {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)
            }
        } catch {
            return nil
        }
        return nil
    }

    public func countUnavailableSimulators() -> Int {
        if let output = runSimctl(arguments: ["list", "devices"], captureOutput: true) {
            return parseUnavailableSimulatorsCount(from: output)
        }
        return 0
    }
    
    internal func parseUnavailableSimulatorsCount(from output: String) -> Int {
        let lines = output.components(separatedBy: .newlines)
        let unavailableLines = lines.filter { $0.contains("(unavailable)") }
        return unavailableLines.count
    }
    
    private func deleteUnavailableSimulators() throws {
        _ = runSimctl(arguments: ["delete", "unavailable"])
    }
    
    private func eraseAllSimulators() throws {
        _ = runSimctl(arguments: ["erase", "all"])
    }
    
    public var id: String {
        switch self {
        case .derivedData: return "derivedData"
        case .archives: return "archives"
        case .iOSDeviceSupport: return "iOSDeviceSupport"
        case .watchOSDeviceSupport: return "watchOSDeviceSupport"
        case .tvOSDeviceSupport: return "tvOSDeviceSupport"
        case .simulatorDevices: return "simulatorDevices"
        case .simulatorCaches: return "simulatorCaches"
        case .xcodeCaches: return "xcodeCaches"
        case .spmCaches: return "spmCaches"
        case .deviceLogs: return "deviceLogs"
        case .userSimulatorRuntimes: return "userSimulatorRuntimes"
        case .cocoaPodsCache: return "cocoaPodsCache"
        case .carthageCache: return "carthageCache"
        case .simulatorLogs: return "simulatorLogs"
        case .playgroundTemp: return "playgroundTemp"
        case .mobileDeviceCrashLogs: return "mobileDeviceCrashLogs"
        case .orphanedDerivedData: return "orphanedDerivedData"
        case .transporterCache: return "transporterCache"
        case .transporterInstall: return "transporterInstall"
        case .unavailableSimulators: return "unavailableSimulators"
        case .xrOSDeviceSupport: return "xrOSDeviceSupport"
        case .visionOSDeviceSupport: return "visionOSDeviceSupport"
        case .interfaceBuilderCache: return "interfaceBuilderCache"
        case .legacyDocSets: return "legacyDocSets"
        case .cocoaPodsRepos: return "cocoaPodsRepos"
        case .transporterLogs: return "transporterLogs"
        case .xcodeDiagnosticReports: return "xcodeDiagnosticReports"
        }
    }
    
    public static func from(id: String) -> JunkCategory? {
        return JunkCategory.allCases.first { $0.id.lowercased() == id.lowercased() }
    }
}
