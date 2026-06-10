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
}
