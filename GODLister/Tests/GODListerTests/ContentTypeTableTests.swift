import XCTest
@testable import GODLister

final class ContentTypeTableTests: XCTestCase {
    func testKnownCodes() {
        XCTAssertEqual(ContentTypeTable.name(for: "00000002"), "DLC / Marketplace Content")
        XCTAssertEqual(ContentTypeTable.name(for: "00007000"), "Games on Demand")
        XCTAssertEqual(ContentTypeTable.name(for: "000B0000"), "Title Update")
        XCTAssertEqual(ContentTypeTable.dlcContentTypeCode, "00000002")
    }

    func testUnknownCode() {
        XCTAssertNil(ContentTypeTable.name(for: "FFFFFFFF"))
    }
}
