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
    }
}
