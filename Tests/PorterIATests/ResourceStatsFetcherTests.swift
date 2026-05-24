import XCTest
@testable import PorterIA

final class ResourceStatsFetcherTests: XCTestCase {

    func test_parse_basicThreeColumn() {
        let out = "  1234   2.5   1.1\n  5678   0.0   0.3"
        let result = ResourceStatsFetcher.parse(out)
        XCTAssertEqual(result[1234], ResourceStats(cpuPercent: 2.5, memPercent: 1.1))
        XCTAssertEqual(result[5678], ResourceStats(cpuPercent: 0.0, memPercent: 0.3))
    }

    func test_parse_handlesLargeNumbers() {
        let out = "9999  100.0  45.7"
        let result = ResourceStatsFetcher.parse(out)
        XCTAssertEqual(result[9999]?.cpuPercent, 100.0)
        XCTAssertEqual(result[9999]?.memPercent, 45.7)
    }

    func test_parse_ignoresMalformedLines() {
        let out = """
          1234  2.5  1.1
        garbage line
          5678  0.0
        """
        let result = ResourceStatsFetcher.parse(out)
        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result[1234])
        // 5678 only has 2 columns, should be skipped
        XCTAssertNil(result[5678])
    }

    func test_parse_emptyInput() {
        XCTAssertEqual(ResourceStatsFetcher.parse("").count, 0)
    }
}
