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
        
        let deletionResult = DeletionResult(totalReclaimedBytes: 1048576, deletedCategories: [deletionDetail], totalReclaimedSinceInstallBytes: 2097152)
        let deletionData = try encoder.encode(deletionResult)
        let decodedDeletion = try decoder.decode(DeletionResult.self, from: deletionData)
        
        #expect(decodedDeletion.totalReclaimedBytes == 1048576)
        #expect(decodedDeletion.deletedCategories.count == 1)
        #expect(decodedDeletion.deletedCategories.first?.id == "derivedData")
        #expect(decodedDeletion.deletedCategories.first?.reclaimedBytes == 1048576)
        #expect(decodedDeletion.deletedCategories.first?.status == "success")
        #expect(decodedDeletion.deletedCategories.first?.error == nil)
        #expect(decodedDeletion.totalReclaimedSinceInstallBytes == 2097152)
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
    
    @Test("Test threshold size parsing")
    func testThresholdSizeParsing() {
        let cleaner = XcodeJunkCleaner()
        #expect(cleaner.parseSizeThreshold("5GB") == 5368709120)
        #expect(cleaner.parseSizeThreshold("500MB") == 524288000)
        #expect(cleaner.parseSizeThreshold("10KB") == 10240)
        #expect(cleaner.parseSizeThreshold("100B") == 100)
        #expect(cleaner.parseSizeThreshold("1.5GB") == 1610612736)
        #expect(cleaner.parseSizeThreshold("0B") == 0)
        #expect(cleaner.parseSizeThreshold("12345") == 12345)
        #expect(cleaner.parseSizeThreshold("abc") == nil)
        #expect(cleaner.parseSizeThreshold("5XX") == nil)
    }
    
    @Test("Test new CLI flags parsing")
    func testNewCLIFlagsParsing() throws {
        // Test --older-than / -o
        let olderCleaner = try XcodeJunkCleaner.parse(["--older-than", "30"])
        #expect(olderCleaner.olderThan == 30)
        let shortOlderCleaner = try XcodeJunkCleaner.parse(["-o", "15"])
        #expect(shortOlderCleaner.olderThan == 15)
        
        // Test --threshold / -t
        let thresholdCleaner = try XcodeJunkCleaner.parse(["--threshold", "5GB"])
        #expect(thresholdCleaner.threshold == "5GB")
        let shortThresholdCleaner = try XcodeJunkCleaner.parse(["-t", "500MB"])
        #expect(shortThresholdCleaner.threshold == "500MB")
        
        // Test --force / -f
        let forceCleaner = try XcodeJunkCleaner.parse(["--force"])
        #expect(forceCleaner.force)
        let shortForceCleaner = try XcodeJunkCleaner.parse(["-f"])
        #expect(shortForceCleaner.force)
    }
    
    @Test("Test time-based folder filtering logic")
    func testTimeBasedFolderFiltering() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        defer {
            try? fm.removeItem(at: tempDir)
        }
        
        // Let's mock a category folder, say DerivedData
        let mockHome = tempDir
        let mockDerivedDataPath = mockHome.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        try fm.createDirectory(at: mockDerivedDataPath, withIntermediateDirectories: true, attributes: nil)
        
        // Folder 1: Old folder (40 days ago)
        let oldFolder = mockDerivedDataPath.appendingPathComponent("OldProject-abc")
        try fm.createDirectory(at: oldFolder, withIntermediateDirectories: true, attributes: nil)
        
        let fileInOld = oldFolder.appendingPathComponent("build.log")
        try "old data".write(to: fileInOld, atomically: true, encoding: .utf8)
        
        let fortyDaysAgo = Date().addingTimeInterval(-40 * 24 * 60 * 60)
        try fm.setAttributes([.modificationDate: fortyDaysAgo], ofItemAtPath: oldFolder.path)
        try fm.setAttributes([.modificationDate: fortyDaysAgo], ofItemAtPath: fileInOld.path)
        
        // Folder 2: New folder (recent / now)
        let newFolder = mockDerivedDataPath.appendingPathComponent("NewProject-def")
        try fm.createDirectory(at: newFolder, withIntermediateDirectories: true, attributes: nil)
        
        let fileInNew = newFolder.appendingPathComponent("build.log")
        try "new data".write(to: fileInNew, atomically: true, encoding: .utf8)
        
        let oneDayAgo = Date().addingTimeInterval(-1 * 24 * 60 * 60)
        try fm.setAttributes([.modificationDate: oneDayAgo], ofItemAtPath: newFolder.path)
        try fm.setAttributes([.modificationDate: oneDayAgo], ofItemAtPath: fileInNew.path)
        
        // Verify isURLOlderThan helper on JunkCategory
        let category = JunkCategory.derivedData
        #expect(category.isURLOlderThan(url: oldFolder, days: 30) == true)
        #expect(category.isURLOlderThan(url: newFolder, days: 30) == false)
        
        // Test getChildren(home:olderThanDays:)
        let allChildren = category.getChildren(home: mockHome, olderThanDays: nil)
        #expect(allChildren.count == 2)
        
        let oldChildren = category.getChildren(home: mockHome, olderThanDays: 30)
        #expect(oldChildren.count == 1)
        #expect(oldChildren.first?.lastPathComponent == "OldProject-abc")
        
        let totalSize = category.calculateSize(home: mockHome, olderThanDays: nil)
        #expect(totalSize > 0)
        
        let oldSize = category.calculateSize(home: mockHome, olderThanDays: 30)
        #expect(oldSize == Int64("old data".utf8.count))
    }
    
    @Test("Test time-based folder deletion logic")
    func testTimeBasedFolderDeletion() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        defer {
            try? fm.removeItem(at: tempDir)
        }
        
        let mockHome = tempDir
        let mockDerivedDataPath = mockHome.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        try fm.createDirectory(at: mockDerivedDataPath, withIntermediateDirectories: true, attributes: nil)
        
        // Folder 1: Old folder (40 days ago)
        let oldFolder = mockDerivedDataPath.appendingPathComponent("OldProject-abc")
        try fm.createDirectory(at: oldFolder, withIntermediateDirectories: true, attributes: nil)
        let fortyDaysAgo = Date().addingTimeInterval(-40 * 24 * 60 * 60)
        try fm.setAttributes([.modificationDate: fortyDaysAgo], ofItemAtPath: oldFolder.path)
        
        // Folder 2: New folder (1 day ago)
        let newFolder = mockDerivedDataPath.appendingPathComponent("NewProject-def")
        try fm.createDirectory(at: newFolder, withIntermediateDirectories: true, attributes: nil)
        let oneDayAgo = Date().addingTimeInterval(-1 * 24 * 60 * 60)
        try fm.setAttributes([.modificationDate: oneDayAgo], ofItemAtPath: newFolder.path)
        
        // Perform deletion older than 30 days
        let category = JunkCategory.derivedData
        try category.delete(home: mockHome, olderThanDays: 30)
        
        // Old folder should be deleted, new folder should remain
        #expect(!fm.fileExists(atPath: oldFolder.path))
        #expect(fm.fileExists(atPath: newFolder.path))
    }
    
    @Test("Test CLI and file-based exclusion parsing")
    func testExclusionParsing() throws {
        // Test CLI --exclude parsing
        let cleaner = try XcodeJunkCleaner.parse(["--exclude", "derivedData,archives"])
        #expect(cleaner.exclude == "derivedData,archives")
        #expect(cleaner.resolvedExclusions.contains("derivedData"))
        #expect(cleaner.resolvedExclusions.contains("archives"))
        
        // Test .xcode-junk-cleaner-exclude file parsing
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? fm.removeItem(at: tempDir)
        }
        
        let excludeFile = tempDir.appendingPathComponent(".xcode-junk-cleaner-exclude")
        try "spmCaches\n# comment\n\nmyCustomPattern\n".write(to: excludeFile, atomically: true, encoding: .utf8)
        
        var cleanerWithFile = try XcodeJunkCleaner.parse([])
        cleanerWithFile.homeDirectoryOverride = tempDir
        let resolved = cleanerWithFile.resolvedExclusions
        #expect(resolved.contains("spmCaches"))
        #expect(resolved.contains("myCustomPattern"))
        #expect(!resolved.contains("# comment"))
        #expect(!resolved.contains(""))
    }
    
    @Test("Test scan and delete with path-based exclusions")
    func testScanAndDeleteWithExclusions() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        defer {
            try? fm.removeItem(at: tempDir)
        }
        
        let mockHome = tempDir
        let mockDerivedDataPath = mockHome.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        try fm.createDirectory(at: mockDerivedDataPath, withIntermediateDirectories: true, attributes: nil)
        
        // Create ProjA (to exclude)
        let projA = mockDerivedDataPath.appendingPathComponent("ProjA-abc")
        try fm.createDirectory(at: projA, withIntermediateDirectories: true, attributes: nil)
        let fileA = projA.appendingPathComponent("build.log")
        try "dataA".write(to: fileA, atomically: true, encoding: .utf8)
        
        // Create ProjB (to clean)
        let projB = mockDerivedDataPath.appendingPathComponent("ProjB-def")
        try fm.createDirectory(at: projB, withIntermediateDirectories: true, attributes: nil)
        let fileB = projB.appendingPathComponent("build.log")
        try "dataB".write(to: fileB, atomically: true, encoding: .utf8)
        
        let category = JunkCategory.derivedData
        
        // Calculate size with exclusion "ProjA"
        let sizeWithExclusion = category.calculateSize(home: mockHome, exclusions: ["ProjA"])
        #expect(sizeWithExclusion == Int64("dataB".utf8.count))
        
        // Delete with exclusion "ProjA"
        try category.delete(home: mockHome, exclusions: ["ProjA"])
        
        // ProjA should be preserved, ProjB should be deleted
        #expect(fm.fileExists(atPath: projA.path))
        #expect(!fm.fileExists(atPath: projB.path))
    }
    
    @Test("Test scheduler CLI options parsing")
    func testSchedulerCLIOptionsParsing() throws {
        // Test --install-schedule
        let installDaily = try XcodeJunkCleaner.parse(["--install-schedule", "daily"])
        #expect(installDaily.installSchedule == "daily")
        
        let installWeekly = try XcodeJunkCleaner.parse(["--install-schedule", "weekly"])
        #expect(installWeekly.installSchedule == "weekly")
        
        // Test --uninstall-schedule
        let uninstall = try XcodeJunkCleaner.parse(["--uninstall-schedule"])
        #expect(uninstall.uninstallSchedule == true)
    }
    
    @Test("Test Exclusion List CLI Management")
    func testExclusionCLICommands() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? fm.removeItem(at: tempDir)
        }
        
        let excludeFile = tempDir.appendingPathComponent(".xcode-junk-cleaner-exclude")
        
        var cleaner = try XcodeJunkCleaner.parse([])
        cleaner.homeDirectoryOverride = tempDir
        
        // Test list on non-existent file doesn't throw
        try cleaner.listExclusionPatterns()
        
        // Test add pattern
        try cleaner.addExclusionPattern("testPatternA")
        #expect(fm.fileExists(atPath: excludeFile.path))
        let content1 = try String(contentsOf: excludeFile, encoding: .utf8)
        #expect(content1.contains("testPatternA"))
        
        // Test duplicate add does not duplicate
        try cleaner.addExclusionPattern("testPatternA")
        
        // Test add another
        try cleaner.addExclusionPattern("testPatternB")
        let content2 = try String(contentsOf: excludeFile, encoding: .utf8)
        #expect(content2.contains("testPatternA"))
        #expect(content2.contains("testPatternB"))
        
        // Test list
        try cleaner.listExclusionPatterns()
        
        // Test remove
        try cleaner.removeExclusionPattern("testPatternA")
        let content3 = try String(contentsOf: excludeFile, encoding: .utf8)
        #expect(!content3.contains("testPatternA"))
        #expect(content3.contains("testPatternB"))
        
        // Test remove non-existent
        try cleaner.removeExclusionPattern("nonexistent")
    }
    
    @Test("Test History Logs & Stats")
    func testHistoryLogsAndStats() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? fm.removeItem(at: tempDir)
        }
        
        var cleaner = try XcodeJunkCleaner.parse([])
        cleaner.homeDirectoryOverride = tempDir
        
        // Assert initial total is 0
        #expect(cleaner.getHistoricalTotalReclaimedBytes() == 0)
        
        // Log one cleanup run
        cleaner.appendHistoricalCleanup(categories: ["derivedData"], reclaimedBytes: 1024)
        #expect(cleaner.getHistoricalTotalReclaimedBytes() == 1024)
        
        // Log another cleanup run
        cleaner.appendHistoricalCleanup(categories: ["archives", "spmCaches"], reclaimedBytes: 2048)
        #expect(cleaner.getHistoricalTotalReclaimedBytes() == 3072)
        
        // Verify JSON file got created and is valid
        let historyFile = tempDir.appendingPathComponent(".xcode-junk-cleaner-history.json")
        #expect(fm.fileExists(atPath: historyFile.path))
        
        let data = try Data(contentsOf: historyFile)
        let records = try JSONDecoder().decode([HistoricalCleanup].self, from: data)
        #expect(records.count == 2)
        #expect(records[0].categories == ["derivedData"])
        #expect(records[0].reclaimedBytes == 1024)
        #expect(records[1].categories == ["archives", "spmCaches"])
        #expect(records[1].reclaimedBytes == 2048)
    }
    
    @Test("Test Backup Compression")
    func testBackupCompression() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        defer {
            try? fm.removeItem(at: tempDir)
        }
        
        let mockHome = tempDir.appendingPathComponent("home")
        let mockBackupDir = tempDir.appendingPathComponent("backup")
        try fm.createDirectory(at: mockHome, withIntermediateDirectories: true, attributes: nil)
        try fm.createDirectory(at: mockBackupDir, withIntermediateDirectories: true, attributes: nil)
        
        // Create a fake DerivedData folder and project subfolder
        let derivedData = mockHome.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        let projectDir = derivedData.appendingPathComponent("MyProject-abcdef")
        try fm.createDirectory(at: projectDir, withIntermediateDirectories: true, attributes: nil)
        
        let fileURL = projectDir.appendingPathComponent("build.log")
        try "fake build log contents".write(to: fileURL, atomically: true, encoding: .utf8)
        
        // Verify delete with backup works
        let category = JunkCategory.derivedData
        try category.delete(home: mockHome, backupDir: mockBackupDir)
        
        // Target folder should be deleted
        #expect(!fm.fileExists(atPath: projectDir.path))
        
        // Backup directory should contain the zip file
        let backupContents = try fm.contentsOfDirectory(at: mockBackupDir, includingPropertiesForKeys: nil)
        #expect(backupContents.count == 1)
        
        let backupZip = backupContents[0]
        #expect(backupZip.lastPathComponent.hasPrefix("derivedData_DerivedData_"))
        #expect(backupZip.lastPathComponent.hasSuffix(".zip"))
    }
    
    @Test("Test SwiftUI Preview Simulators Parsing")
    func testPreviewSimulatorsParsing() {
        let mockOutputZero = """
        == Devices ==
        -- iOS 17.2 --
            iPhone 15 Pro (UUID) (Shutdown)
        """
        #expect(JunkCategory.previewSimulators.parseSimulatorsCount(from: mockOutputZero) == 1)
        
        let mockOutputMultiple = """
        == Devices ==
        -- iOS 16.0 --
            iPhone 14 (AAAAA) (Shutdown)
            iPhone 14 Pro (BBBBB) (Shutdown)
        -- iOS 17.0 --
            iPhone 15 (12345) (Shutdown)
            iPhone 15 Pro (67890) (Booted)
        """
        #expect(JunkCategory.previewSimulators.parseSimulatorsCount(from: mockOutputMultiple) == 4)
        
        let mockOutputEmpty = ""
        #expect(JunkCategory.previewSimulators.parseSimulatorsCount(from: mockOutputEmpty) == 0)
    }
    
    @Test("Test SwiftUI Previews Cache Path and Size Scan")
    func testSwiftUIPreviewsScan() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? fm.removeItem(at: tempDir)
        }
        
        let mockHome = tempDir
        let previewsCachePath = mockHome.appendingPathComponent("Library/Developer/Xcode/UserData/Previews")
        try fm.createDirectory(at: previewsCachePath, withIntermediateDirectories: true, attributes: nil)
        
        let cacheFile = previewsCachePath.appendingPathComponent("preview-cache-file.bin")
        try "fake cache data".write(to: cacheFile, atomically: true, encoding: .utf8)
        
        let category = JunkCategory.swiftUIPreviews
        #expect(category.isSafe == true)
        
        let size = category.calculateSize(home: mockHome)
        #expect(size == Int64("fake cache data".utf8.count))
    }
}
