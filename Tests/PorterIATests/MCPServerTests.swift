import XCTest
@testable import PorterIA

final class MCPServerHTTPParserTests: XCTestCase {

    func test_parseHTTPRequest_basicGET() {
        let req = "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let parsed = MCPServer.parseHTTPRequest(Data(req.utf8))
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.method, "GET")
        XCTAssertEqual(parsed?.path, "/health")
        XCTAssertEqual(parsed?.body.count, 0)
    }

    func test_parseHTTPRequest_POSTWithBody() {
        let body = #"{"jsonrpc":"2.0","method":"initialize","id":1}"#
        let req = "POST /mcp HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\n\r\n\(body)"
        let parsed = MCPServer.parseHTTPRequest(Data(req.utf8))
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.method, "POST")
        XCTAssertEqual(parsed?.path, "/mcp")
        XCTAssertEqual(String(data: parsed?.body ?? Data(), encoding: .utf8), body)
    }

    func test_parseHTTPRequest_returnsNilIfBodyIncomplete() {
        // Says Content-Length: 100 but only 5 bytes of body.
        let req = "POST /mcp HTTP/1.1\r\nContent-Length: 100\r\n\r\nhello"
        XCTAssertNil(MCPServer.parseHTTPRequest(Data(req.utf8)))
    }

    func test_parseHTTPRequest_returnsNilIfHeadersIncomplete() {
        let req = "POST /mcp HTTP/1.1\r\nContent-Length: 5"  // no \r\n\r\n
        XCTAssertNil(MCPServer.parseHTTPRequest(Data(req.utf8)))
    }

    func test_httpResponse_formatsStatusAndBody() {
        let resp = MCPServer.httpResponse(status: 200, body: #"{"ok":true}"#)
        let text = String(data: resp, encoding: .utf8) ?? ""
        XCTAssertTrue(text.hasPrefix("HTTP/1.1 200 OK\r\n"))
        XCTAssertTrue(text.contains("Content-Type: application/json"))
        XCTAssertTrue(text.contains(#"Content-Length: 11"#))
        XCTAssertTrue(text.hasSuffix(#"{"ok":true}"#))
    }

    func test_httpResponse_404() {
        let resp = MCPServer.httpResponse(status: 404, body: "x")
        let text = String(data: resp, encoding: .utf8) ?? ""
        XCTAssertTrue(text.hasPrefix("HTTP/1.1 404 Not Found\r\n"))
    }
}
