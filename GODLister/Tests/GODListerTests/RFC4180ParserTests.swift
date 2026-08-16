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
}
