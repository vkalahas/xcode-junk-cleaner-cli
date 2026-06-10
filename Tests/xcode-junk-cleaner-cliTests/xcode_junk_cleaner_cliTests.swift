import Testing
import Foundation
@testable import xcode_junk_cleaner_cli

@Suite("Xcode Junk Cleaner CLI Tests")
struct XcodeJunkCleanerTests {
    
    @Test("Test formatBytes utility")
    func testFormatBytes() {
        #expect(JunkCategory.formatBytes(0) == "0 B")
        #expect(JunkCategory.formatBytes(512) == "512 B")
        #expect(JunkCategory.formatBytes(1024) == "1.00 KB")
        #expect(JunkCategory.formatBytes(1536) == "1.50 KB")
        #expect(JunkCategory.formatBytes(1048576) == "1.00 MB")
        #expect(JunkCategory.formatBytes(1572864) == "1.50 MB")
        #expect(JunkCategory.formatBytes(1073741824) == "1.00 GB")
        #expect(JunkCategory.formatBytes(1610612736) == "1.50 GB")
    }
    
    @Test("Test paths are resolved within the home directory")
    func testPaths() {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        for category in JunkCategory.allCases {
            guard !category.relativePath.isEmpty else { continue }
            let categoryPath = category.url.path
            #expect(categoryPath.hasPrefix(homePath))
            #expect(categoryPath.contains(category.relativePath))
        }
    }
    
    @Test("Test ArgumentParser Parsing")
    func testArgumentParser() throws {
        // Test default arguments
        let defaultCleaner = try XcodeJunkCleaner.parse([])
        #expect(!defaultCleaner.yes)
        #expect(!defaultCleaner.dryRun)
        
        // Test --yes flag
        let yesCleaner = try XcodeJunkCleaner.parse(["--yes"])
        #expect(yesCleaner.yes)
        #expect(!yesCleaner.dryRun)
        
        // Test -y flag
        let shortYesCleaner = try XcodeJunkCleaner.parse(["-y"])
        #expect(shortYesCleaner.yes)
        
        // Test --dry-run flag
        let dryRunCleaner = try XcodeJunkCleaner.parse(["--dry-run"])
        #expect(!dryRunCleaner.yes)
        #expect(dryRunCleaner.dryRun)
        
        // Test -d flag
        let shortDryRunCleaner = try XcodeJunkCleaner.parse(["-d"])
        #expect(shortDryRunCleaner.dryRun)
        
        // Test multiple flags
        let combinedCleaner = try XcodeJunkCleaner.parse(["-y", "-d"])
        #expect(combinedCleaner.yes)
        #expect(combinedCleaner.dryRun)
        
        // Test --safe flag
        let safeCleaner = try XcodeJunkCleaner.parse(["--safe"])
        #expect(safeCleaner.safe)
        
        // Test -s flag
        let shortSafeCleaner = try XcodeJunkCleaner.parse(["-s"])
        #expect(shortSafeCleaner.safe)
        
        // Test --json flag
        let jsonCleaner = try XcodeJunkCleaner.parse(["--json"])
        #expect(jsonCleaner.json)
        
        // Test --quiet flag
        let quietCleaner = try XcodeJunkCleaner.parse(["--quiet"])
        #expect(quietCleaner.quiet)
        
        // Test -q flag
        let shortQuietCleaner = try XcodeJunkCleaner.parse(["-q"])
        #expect(shortQuietCleaner.quiet)
        
        // Test --category option (single)
        let categoryCleaner = try XcodeJunkCleaner.parse(["--category", "derivedData"])
        #expect(categoryCleaner.category == ["derivedData"])
        
        // Test -c option (multiple)
        let multiCategoryCleaner = try XcodeJunkCleaner.parse(["-c", "derivedData", "-c", "archives"])
        #expect(multiCategoryCleaner.category == ["derivedData", "archives"])
    }
    
    @Test("Test Case-Insensitive Category ID Matching")
    func testCaseInsensitiveCategoryMatching() {
        #expect(JunkCategory.from(id: "deriveddata") == .derivedData)
        #expect(JunkCategory.from(id: "DerivedData") == .derivedData)
        #expect(JunkCategory.from(id: "spmcaches") == .spmCaches)
        #expect(JunkCategory.from(id: "spmCACHES") == .spmCaches)
        #expect(JunkCategory.from(id: "nonexistent") == nil)
    }

    @Test("Test Orphaned Derived Data Plist Scan")
    func testOrphanedDerivedDataScan() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        defer {
            try? fm.removeItem(at: tempDir)
        }
        
        // Setup mock paths
        let mockHome = tempDir
        let mockDerivedDataPath = mockHome.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        try fm.createDirectory(at: mockDerivedDataPath, withIntermediateDirectories: true, attributes: nil)
        
        // 1. Create a mock active project path
        let activeProjectPath = mockHome.appendingPathComponent("MyActiveProject.xcodeproj")
        try "mock project file".write(to: activeProjectPath, atomically: true, encoding: .utf8)
        
        let activeDerivedDir = mockDerivedDataPath.appendingPathComponent("MyActiveProject-abcdef")
        try fm.createDirectory(at: activeDerivedDir, withIntermediateDirectories: true, attributes: nil)
        
        // Write active plist
        let activePlistPath = activeDerivedDir.appendingPathComponent("info.plist")
        let activePlist: [String: Any] = ["WorkspacePath": activeProjectPath.path]
        let activeData = try PropertyListSerialization.data(fromPropertyList: activePlist, format: .xml, options: 0)
        try activeData.write(to: activePlistPath)
        
        // 2. Create a mock orphaned project (workspace path does not exist)
        let missingProjectPath = mockHome.appendingPathComponent("MyMissingProject.xcodeproj")
        
        let orphanedDerivedDir = mockDerivedDataPath.appendingPathComponent("MyMissingProject-ghijkl")
        try fm.createDirectory(at: orphanedDerivedDir, withIntermediateDirectories: true, attributes: nil)
        
        // Write orphaned plist
        let orphanedPlistPath = orphanedDerivedDir.appendingPathComponent("info.plist")
        let orphanedPlist: [String: Any] = ["WorkspacePath": missingProjectPath.path]
        let orphanedData = try PropertyListSerialization.data(fromPropertyList: orphanedPlist, format: .xml, options: 0)
        try orphanedData.write(to: orphanedPlistPath)
        
        // Check getOrphanedDerivedDataURLs
        let orphanedURLs = JunkCategory.derivedData.getOrphanedDerivedDataURLs(home: mockHome)
        #expect(orphanedURLs.count == 1)
        #expect(orphanedURLs.first?.lastPathComponent == "MyMissingProject-ghijkl")
    }

    @Test("Test Diagnostic Reports Filtering")
    func testDiagnosticReportsFilter() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        defer {
            try? fm.removeItem(at: tempDir)
        }
        
        // Setup mock path
        let mockHome = tempDir
        let mockDiagPath = mockHome.appendingPathComponent("Library/Logs/DiagnosticReports")
        try fm.createDirectory(at: mockDiagPath, withIntermediateDirectories: true, attributes: nil)
        
        // Create files
        let matchingFiles = [
            "Xcode_2026-06-10-120000.crash",
            "swift-frontend_2026-06-10-120000.crash",
            "Simulator_2026-06-10-120000.crash",
            "ibtool_2026-06-10-120000.crash"
        ]
        
        let nonMatchingFiles = [
            "Safari_2026-06-10-120000.crash",
            "WindowServer_2026-06-10-120000.diag",
            "Finder_2026-06-10-120000.crash"
        ]
        
        for file in matchingFiles + nonMatchingFiles {
            let filePath = mockDiagPath.appendingPathComponent(file)
            try "crash data".write(to: filePath, atomically: true, encoding: .utf8)
        }
        
        // Run getDiagnosticReportURLs
        let matchedURLs = JunkCategory.xcodeDiagnosticReports.getDiagnosticReportURLs(home: mockHome)
        #expect(matchedURLs.count == matchingFiles.count)
        
        let matchedNames = Set(matchedURLs.map { $0.lastPathComponent })
        for file in matchingFiles {
            #expect(matchedNames.contains(file))
        }
        for file in nonMatchingFiles {
            #expect(!matchedNames.contains(file))
        }
    }
    
    @Test("Test JSON Round-Trip Serialization")
    func testJSONRoundTrip() throws {
        let categoryResult = JunkCategoryScanResult(
            id: "derivedData",
            displayName: "Derived Data",
            relativePath: "Library/Developer/Xcode/DerivedData",
            sizeBytes: 1048576,
            description: "Build output",
            isSafe: true
        )
        
        let scanResult = ScanResult(totalBytes: 1048576, categories: [categoryResult])
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(scanResult)
        let decoded = try decoder.decode(ScanResult.self, from: data)
        
        #expect(decoded.totalBytes == 1048576)
        #expect(decoded.categories.count == 1)
        #expect(decoded.categories.first?.id == "derivedData")
        #expect(decoded.categories.first?.displayName == "Derived Data")
        #expect(decoded.categories.first?.relativePath == "Library/Developer/Xcode/DerivedData")
        #expect(decoded.categories.first?.sizeBytes == 1048576)
        #expect(decoded.categories.first?.description == "Build output")
        #expect(decoded.categories.first?.isSafe == true)
        
        // Test Deletion Result
        let deletionDetail = DeletionDetail(
            id: "derivedData",
            displayName: "Derived Data",
            reclaimedBytes: 1048576,
            status: "success",
            error: nil
        )
        
        let deletionResult = DeletionResult(totalReclaimedBytes: 1048576, deletedCategories: [deletionDetail])
        let deletionData = try encoder.encode(deletionResult)
        let decodedDeletion = try decoder.decode(DeletionResult.self, from: deletionData)
        
        #expect(decodedDeletion.totalReclaimedBytes == 1048576)
        #expect(decodedDeletion.deletedCategories.count == 1)
        #expect(decodedDeletion.deletedCategories.first?.id == "derivedData")
        #expect(decodedDeletion.deletedCategories.first?.reclaimedBytes == 1048576)
        #expect(decodedDeletion.deletedCategories.first?.status == "success")
        #expect(decodedDeletion.deletedCategories.first?.error == nil)
    }

    @Test("Test simctl Output Parsing")
    func testSimctlOutputParsing() {
        let mockOutputZero = """
        == Devices ==
        -- iOS 17.0 --
            iPhone 15 (12345) (Shutdown) 
            iPhone 15 Pro (67890) (Booted)
        """
        #expect(JunkCategory.unavailableSimulators.parseUnavailableSimulatorsCount(from: mockOutputZero) == 0)
        
        let mockOutputMultiple = """
        == Devices ==
        -- iOS 16.0 --
            iPhone 14 (AAAAA) (Shutdown) (unavailable)
            iPhone 14 Pro (BBBBB) (Shutdown) (unavailable)
        -- iOS 17.0 --
            iPhone 15 (12345) (Shutdown) 
            iPhone 15 Pro (67890) (Booted) (unavailable)
        """
        #expect(JunkCategory.unavailableSimulators.parseUnavailableSimulatorsCount(from: mockOutputMultiple) == 3)
        
        let mockOutputEmpty = ""
        #expect(JunkCategory.unavailableSimulators.parseUnavailableSimulatorsCount(from: mockOutputEmpty) == 0)
    }

    @Test("Test formatBytes Boundary Values")
    func testFormatBytesBoundaries() {
        // Test negative value
        #expect(JunkCategory.formatBytes(-100) == "-100 B")
        
        // Test Terabyte scale (1024 GB)
        let oneTB: Int64 = 1099511627776 // 1024 * 1024 * 1024 * 1024
        #expect(JunkCategory.formatBytes(oneTB) == "1024.00 GB")
        
        // Test Petabyte scale (defaults to GB as per formatting limits)
        let onePB: Int64 = 1125899906842624
        #expect(JunkCategory.formatBytes(onePB) == "1048576.00 GB")
    }

    @Test("Test Recursive Directory Deletion")
    func testRecursiveDirectoryDeletion() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        defer {
            try? fm.removeItem(at: tempDir)
        }
        
        // Add subfolders and files
        let subDir = tempDir.appendingPathComponent("SubFolder")
        try fm.createDirectory(at: subDir, withIntermediateDirectories: true, attributes: nil)
        
        let file1 = tempDir.appendingPathComponent("file1.txt")
        let file2 = subDir.appendingPathComponent("file2.txt")
        
        try "data1".write(to: file1, atomically: true, encoding: .utf8)
        try "data2".write(to: file2, atomically: true, encoding: .utf8)
        
        #expect(fm.fileExists(atPath: file1.path))
        #expect(fm.fileExists(atPath: file2.path))
        
        // Perform deletion
        try fm.removeItem(at: tempDir)
        
        #expect(!fm.fileExists(atPath: tempDir.path))
        #expect(!fm.fileExists(atPath: file1.path))
        #expect(!fm.fileExists(atPath: file2.path))
    }
}
