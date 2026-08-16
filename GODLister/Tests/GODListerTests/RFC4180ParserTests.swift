import XCTest
@testable import GODLister

final class RFC4180ParserTests: XCTestCase {
    func testSimpleFields() {
        let records = RFC4180Parser.parse("a,b,c\n1,2,3\n"[...])
        XCTAssertEqual(records, [["a", "b", "c"], ["1", "2", "3"]])
    }

    func testQuotedFieldWithEmbeddedComma() {
        let records = RFC4180Parser.parse("\"Sugar, Spice and Not So Nice\",x,y\n"[...])
        XCTAssertEqual(records[0][0], "Sugar, Spice and Not So Nice")
        XCTAssertEqual(records[0][1], "x")
        XCTAssertEqual(records[0][2], "y")
    }

    func testEscapedQuoteInsideQuotedField() {
        let records = RFC4180Parser.parse("\"say \"\"hi\"\"\",b\n"[...])
        XCTAssertEqual(records[0][0], "say \"hi\"")
        XCTAssertEqual(records[0][1], "b")
    }

    func testCRLFRecordSeparator() {
        let records = RFC4180Parser.parse("a,b\r\nc,d\r\n"[...])
        XCTAssertEqual(records, [["a", "b"], ["c", "d"]])
    }

    func testQuotedFieldWithEmbeddedNewline() {
        let records = RFC4180Parser.parse("\"line1\nline2\",b\nc,d\n"[...])
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0][0], "line1\nline2")
        XCTAssertEqual(records[1], ["c", "d"])
    }

    func testTrailingRecordWithoutFinalNewline() {
        let records = RFC4180Parser.parse("a,b\nc,d"[...])
        XCTAssertEqual(records, [["a", "b"], ["c", "d"]])
    }

    func testRealDLCCatalogLoadsExpectedVolume() {
        // Sanity check on the real bundled resource, loaded through
        // DLCTitleCatalog (which owns GODLister's own Bundle.module) rather
        // than re-loading the bundle here, since the test target declares
        // no resources of its own. 7153 raw data rows collapse to 6031
        // unique ContentIds under first-occurrence-wins dedup (cross-checked
        // independently with Python's csv module) - assert the exact
        // dedup'd count, not just "some large number", so a future parser
        // regression that drops rows silently is caught.
        XCTAssertEqual(DLCTitleCatalog.map.count, 6031)
    }
}
