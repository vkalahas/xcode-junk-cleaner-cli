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
    public func calculateSize() -> Int64 {
        switch self {
        case .orphanedDerivedData:
            return calculateOrphanedDerivedDataSize()
        case .unavailableSimulators:
            return Int64(countUnavailableSimulators())
        case .xcodeDiagnosticReports:
            return calculateDiagnosticReportsSize()
        default:
            break
        }
        
        let path = url.path
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else {
            return 0
        }
        
        if !isDir.boolValue {
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: path)
                return attrs[.size] as? Int64 ?? 0
            } catch {
                return 0
            }
        }
        
        var totalSize: Int64 = 0
        let properties: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: properties,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: Set(properties))
                if let isDirectory = values.isDirectory, !isDirectory {
                    if let fileSize = values.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            } catch {
                // Ignore individual file errors to continue scanning remaining files
            }
        }
        
        return totalSize
    }
    
    /// Deletes the folder and its contents recursively.
    public func delete() throws {
        switch self {
        case .orphanedDerivedData:
            try deleteOrphanedDerivedData()
        case .unavailableSimulators:
            try deleteUnavailableSimulators()
        case .xcodeDiagnosticReports:
            try deleteDiagnosticReports()
        default:
            let fm = FileManager.default
            guard fm.fileExists(atPath: url.path) else { return }
            try fm.removeItem(at: url)
        }
    }
    
    /// Helper to format bytes to human readable string
    public static func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1.0 {
            return String(format: "%.2f KB", kb)
        } else {
            return "\(bytes) B"
        }
    }
    
    // MARK: - Private Helpers for Advanced Cleanups
    
    private func getOrphanedDerivedDataURLs() -> [URL] {
        let fm = FileManager.default
        let derivedDataURL = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/Xcode/DerivedData")
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
    
    private func calculateOrphanedDerivedDataSize() -> Int64 {
        let urls = getOrphanedDerivedDataURLs()
        var total: Int64 = 0
        let properties: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        
        for url in urls {
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: properties,
                options: [.skipsHiddenFiles],
                errorHandler: nil
            ) else {
                continue
            }
            
            for case let fileURL as URL in enumerator {
                if let values = try? fileURL.resourceValues(forKeys: Set(properties)),
                   let isDirectory = values.isDirectory, !isDirectory,
                   let fileSize = values.fileSize {
                    total += Int64(fileSize)
                }
            }
        }
        return total
    }
    
    private func deleteOrphanedDerivedData() throws {
        let urls = getOrphanedDerivedDataURLs()
        for url in urls {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    public func countUnavailableSimulators() -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // Mute standard error
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                let unavailableLines = lines.filter { $0.contains("(unavailable)") }
                return unavailableLines.count
            }
        } catch {
            return 0
        }
        return 0
    }
    
    private func deleteUnavailableSimulators() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "delete", "unavailable"]
        
        try process.run()
        process.waitUntilExit()
    }
    
    private func getDiagnosticReportURLs() -> [URL] {
        let fm = FileManager.default
        let diagURL = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports")
        guard let contents = try? fm.contentsOfDirectory(at: diagURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        
        let prefixes = ["Xcode_", "swift-frontend_", "Simulator_", "ibtool_", "simctl_", "actool_", "lldb-rpc-server_", "swift-connection_"]
        return contents.filter { url in
            let filename = url.lastPathComponent
            return prefixes.contains { prefix in filename.hasPrefix(prefix) }
        }
    }
    
    private func calculateDiagnosticReportsSize() -> Int64 {
        let urls = getDiagnosticReportURLs()
        var total: Int64 = 0
        for url in urls {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }
    
    private func deleteDiagnosticReports() throws {
        let urls = getDiagnosticReportURLs()
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
