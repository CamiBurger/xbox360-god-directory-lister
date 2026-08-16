import XCTest
@testable import GODLister

final class DLCTitleCatalogTests: XCTestCase {
    func testMergedCatalogIncludesBothSources() {
        // 6031 unique IDs from the primary (CamiBurger) source + 4141
        // genuinely new IDs from the No-Intro fallback = 10172. Cross-checked
        // independently with Python's csv module. Assert the exact merged
        // count, not just "some large number", so a future regression in
        // either loader or the merge logic is caught.
        XCTAssertEqual(DLCTitleCatalog.map.count, 10172)
    }

    func testPrimarySourceWinsOnOverlap() {
        // This ID exists in both sources with different naming conventions
        // (primary: clean "Game - Pack Name"; No-Intro: "Game - Pack Name
        // (World) (Addon)"). The primary source must win.
        let id = "C9C1C89EC949BAA3D254DCC301CF36ED64F63D6658"
        XCTAssertEqual(DLCTitleCatalog.map[id], "Novadrome - Bonus Pack")
    }

    func testNoIntroFallbackFillsGenuineGap() {
        // This ID only exists in the No-Intro source, not the primary one.
        let id = "000A4A08D9B32280D0553E8ED93B42B4F4F5BF5545"
        XCTAssertEqual(DLCTitleCatalog.map[id], "Rock Band Network - Aminal - Drag Me Away (World) (Addon)")
    }
}
