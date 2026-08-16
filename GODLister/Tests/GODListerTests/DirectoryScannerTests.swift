import XCTest
@testable import GODLister

final class DirectoryScannerTests: XCTestCase {
    // MARK: isGodTitleID

    func testValidGodTitleID() {
        XCTAssertTrue(DirectoryScanner.isGodTitleID("465307D3"))
        XCTAssertTrue(DirectoryScanner.isGodTitleID("abcdef12"))
    }

    func testWrongLength() {
        XCTAssertFalse(DirectoryScanner.isGodTitleID("465307D"))
        XCTAssertFalse(DirectoryScanner.isGodTitleID("465307D33"))
    }

    func testNonHexCharacters() {
        XCTAssertFalse(DirectoryScanner.isGodTitleID("465307ZZ"))
    }

    func testFullwidthDigitsAreNotAsciiHex() {
        // Unicode fullwidth digits (U+FF10 etc.) are 3 bytes each in UTF-8 and
        // are NOT ASCII hex digits, even though Swift's Unicode-aware
        // Character.isHexDigit would accept them - this must return false to
        // match the original Rust byte/ASCII semantics.
        let fullwidth = "\u{FF10}\u{FF11}\u{FF12}\u{FF13}\u{FF14}\u{FF15}\u{FF16}\u{FF17}"
        XCTAssertEqual(fullwidth.count, 8) // 8 grapheme clusters
        XCTAssertFalse(DirectoryScanner.isGodTitleID(fullwidth))
    }

    // MARK: labelFor precedence

    func testContentTypeLabelWhenParentIsGodIDAndBothRecognitionOn() {
        let counters = ScanCounters()
        let label = DirectoryScanner.labelFor(
            name: "00007000",
            parentName: "465307D3",
            godRecognition: true,
            contentTypeRecognition: true,
            godTitles: [:],
            dlcTitles: [:],
            counters: counters
        )
        XCTAssertEqual(label, "00007000 (Games on Demand)")
        XCTAssertEqual(counters.contentTypeMatches, 1)
    }

    func testDlcNameLabelWhenParentIsDlcContentTypeCode() {
        let counters = ScanCounters()
        let label = DirectoryScanner.labelFor(
            name: "ABCDEF",
            parentName: "00000002",
            godRecognition: true,
            contentTypeRecognition: true,
            godTitles: [:],
            dlcTitles: ["ABCDEF": "Some DLC Pack"],
            counters: counters
        )
        XCTAssertEqual(label, "ABCDEF - Some DLC Pack")
        XCTAssertEqual(counters.dlcMatches, 1)
    }

    func testGodTitleLabelWhenOnlyGodRecognitionOn() {
        let counters = ScanCounters()
        let label = DirectoryScanner.labelFor(
            name: "465307D3",
            parentName: "SomeParent",
            godRecognition: true,
            contentTypeRecognition: false,
            godTitles: ["465307D3": "Some Game"],
            dlcTitles: [:],
            counters: counters
        )
        XCTAssertEqual(label, "465307D3 - Some Game")
        XCTAssertEqual(counters.godMatches, 1)
    }

    func testContentTypeAndDlcLookupsGatedByBothFlags() {
        // Even though parent looks like a GOD ID, content-type recognition
        // being off must prevent the content-type/DLC branches from firing -
        // this guard has to live in the scanner, not just the UI.
        let counters = ScanCounters()
        let label = DirectoryScanner.labelFor(
            name: "00007000",
            parentName: "465307D3",
            godRecognition: true,
            contentTypeRecognition: false,
            godTitles: [:],
            dlcTitles: [:],
            counters: counters
        )
        XCTAssertEqual(label, "00007000")
        XCTAssertEqual(counters.contentTypeMatches, 0)
    }

    func testRawNameWhenNoRecognitionMatches() {
        let counters = ScanCounters()
        let label = DirectoryScanner.labelFor(
            name: "regular-folder",
            parentName: "parent",
            godRecognition: true,
            contentTypeRecognition: true,
            godTitles: [:],
            dlcTitles: [:],
            counters: counters
        )
        XCTAssertEqual(label, "regular-folder")
    }

    // MARK: collectEntries (real filesystem)

    func testCollectEntriesRespectsDepthAndSortsChildren() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: root.appendingPathComponent("bravo"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("alpha"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("alpha/nested"), withIntermediateDirectories: true)

        var entries: [(depth: Int, label: String)] = []
        let counters = ScanCounters()
        DirectoryScanner.collectEntries(
            dir: root,
            depth: 1,
            maxDepth: 1,
            godRecognition: false,
            contentTypeRecognition: false,
            godTitles: [:],
            dlcTitles: [:],
            counters: counters,
            into: &entries
        )

        XCTAssertEqual(entries.map(\.label), ["alpha", "bravo"])
        XCTAssertEqual(entries.map(\.depth), [1, 1])
    }

    func testCollectEntriesUnlimitedDepthRecursesFully() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: root.appendingPathComponent("a/b/c"), withIntermediateDirectories: true)

        var entries: [(depth: Int, label: String)] = []
        let counters = ScanCounters()
        DirectoryScanner.collectEntries(
            dir: root,
            depth: 1,
            maxDepth: nil,
            godRecognition: false,
            contentTypeRecognition: false,
            godTitles: [:],
            dlcTitles: [:],
            counters: counters,
            into: &entries
        )

        XCTAssertEqual(entries.map(\.label), ["a", "b", "c"])
        XCTAssertEqual(entries.map(\.depth), [1, 2, 3])
    }

    func testUnreadableDirectoryIsSkippedNotFatal() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let blocked = root.appendingPathComponent("blocked")
        try fm.createDirectory(at: blocked, withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("readable"), withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: blocked.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: blocked.path) }

        var entries: [(depth: Int, label: String)] = []
        let counters = ScanCounters()
        DirectoryScanner.collectEntries(
            dir: root,
            depth: 1,
            maxDepth: nil,
            godRecognition: false,
            contentTypeRecognition: false,
            godTitles: [:],
            dlcTitles: [:],
            counters: counters,
            into: &entries
        )

        // Both entries listed at depth 1; "blocked" contributes an extra
        // placeholder line (from recursing into it) rather than aborting.
        XCTAssertTrue(entries.contains { $0.label == "blocked" })
        XCTAssertTrue(entries.contains { $0.label == "readable" })
        XCTAssertTrue(entries.contains { $0.label.hasPrefix("(couldn't read this folder:") })
        XCTAssertEqual(counters.unreadableCount, 1)
    }
}
