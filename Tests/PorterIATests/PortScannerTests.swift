import XCTest
@testable import PorterIA

final class PortScannerTests: XCTestCase {

    // MARK: - extractPort

    func test_extractPort_fromAllInterfaces() {
        XCTAssertEqual(PortScanner.extractPort(from: "*:3000"), 3000)
    }

    func test_extractPort_fromIPv4() {
        XCTAssertEqual(PortScanner.extractPort(from: "127.0.0.1:5432"), 5432)
    }

    func test_extractPort_fromIPv6() {
        XCTAssertEqual(PortScanner.extractPort(from: "[::1]:8080"), 8080)
    }

    func test_extractPort_invalidReturnsNil() {
        XCTAssertNil(PortScanner.extractPort(from: "no-colon-here"))
        XCTAssertNil(PortScanner.extractPort(from: "*:not-a-number"))
    }

    // MARK: - parse

    func test_parse_fixtureProducesExpectedEntries() throws {
        let url = Bundle.module.url(forResource: "lsof_listen_sample", withExtension: "txt")
        let raw = try String(contentsOf: XCTUnwrap(url), encoding: .utf8)

        let entries = PortScanner.parse(raw)

        // The fixture has node:3344, rapportd:49998 (duplicated IPv4/IPv6 dedup),
        // rapportd:57773, postgres:5432 (duplicated IPv4/IPv6 dedup).
        // After dedupe by (pid, port): 4 entries.
        XCTAssertEqual(entries.count, 4)

        // Sorted by port ascending.
        XCTAssertEqual(entries.map(\.port), [3344, 5432, 49998, 57773])

        let node = try XCTUnwrap(entries.first { $0.port == 3344 })
        XCTAssertEqual(node.command, "node")
        XCTAssertEqual(node.pid, 288)
        XCTAssertEqual(node.user, "iaparamedicos")
        XCTAssertEqual(node.bindAddress, "*:3344")

        let postgres = try XCTUnwrap(entries.first { $0.port == 5432 })
        XCTAssertEqual(postgres.command, "postgres")
        XCTAssertEqual(postgres.pid, 1024)
        // First-seen bind address wins (IPv4 here).
        XCTAssertEqual(postgres.bindAddress, "127.0.0.1:5432")
    }

    func test_parse_emptyInput() {
        XCTAssertEqual(PortScanner.parse("").count, 0)
    }

    // MARK: - dedupe

    func test_dedupe_collapsesSamePidSamePort() {
        let dup1 = PortEntry(
            port: 5432, pid: 1024, command: "postgres", user: "postgres",
            bindAddress: "127.0.0.1:5432", projectPath: nil, projectName: nil
        )
        let dup2 = PortEntry(
            port: 5432, pid: 1024, command: "postgres", user: "postgres",
            bindAddress: "[::1]:5432", projectPath: nil, projectName: nil
        )
        let other = PortEntry(
            port: 3000, pid: 99, command: "node", user: "u",
            bindAddress: "*:3000", projectPath: nil, projectName: nil
        )

        let result = PortScanner.dedupe([dup1, dup2, other])

        XCTAssertEqual(result.count, 2)
        // First occurrence wins.
        XCTAssertEqual(result.first?.bindAddress, "127.0.0.1:5432")
    }
}

// MARK: - PortEntry display labels

final class PortEntryTests: XCTestCase {

    func test_bindLabel_humanizesAllInterfaces() {
        let e = PortEntry(
            port: 3000, pid: 1, command: "node", user: "u",
            bindAddress: "*:3000", projectPath: nil, projectName: nil
        )
        XCTAssertEqual(e.bindLabel, "all interfaces")
    }

    func test_bindLabel_humanizesLocalhostIPv4() {
        let e = PortEntry(
            port: 5432, pid: 1, command: "psql", user: "u",
            bindAddress: "127.0.0.1:5432", projectPath: nil, projectName: nil
        )
        XCTAssertEqual(e.bindLabel, "localhost")
    }

    func test_bindLabel_humanizesLocalhostIPv6() {
        let e = PortEntry(
            port: 8080, pid: 1, command: "x", user: "u",
            bindAddress: "[::1]:8080", projectPath: nil, projectName: nil
        )
        XCTAssertEqual(e.bindLabel, "localhost")
    }

    func test_primaryLabel_fallsBackToCommandWhenNoProject() {
        let e = PortEntry(
            port: 3000, pid: 1, command: "node", user: "u",
            bindAddress: "*:3000", projectPath: nil, projectName: nil
        )
        XCTAssertEqual(e.primaryLabel, "node")
        XCTAssertEqual(e.secondaryLabel, "pid 1 · all interfaces")
    }

    func test_primaryLabel_usesProjectNameWhenPresent() {
        let e = PortEntry(
            port: 3000, pid: 1, command: "node", user: "u",
            bindAddress: "*:3000",
            projectPath: "/Users/x/my-app",
            projectName: "my-app"
        )
        XCTAssertEqual(e.primaryLabel, "my-app")
        XCTAssertEqual(e.secondaryLabel, "node · pid 1 · all interfaces")
    }
}

// MARK: - ProjectDetector

final class ProjectDetectorTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PorterIATests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_detect_findsPackageJsonAndReadsName() throws {
        let projectDir = tempDir.appendingPathComponent("my-cool-app")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        let pkg = #"{"name": "cool-renamed", "version": "1.0.0"}"#
        try pkg.write(to: projectDir.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

        let cwd = projectDir.appendingPathComponent("subdir/nested").path
        try FileManager.default.createDirectory(atPath: cwd, withIntermediateDirectories: true)

        let result = ProjectDetector.detect(cwd: cwd)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0, projectDir.standardizedFileURL.path)
        XCTAssertEqual(result?.1, "cool-renamed")
    }

    func test_detect_fallsBackToDirNameForNonPackageJsonMarker() throws {
        let projectDir = tempDir.appendingPathComponent("rust-thing")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        try "[package]\nname = \"x\"".write(
            to: projectDir.appendingPathComponent("Cargo.toml"),
            atomically: true, encoding: .utf8
        )

        let result = ProjectDetector.detect(cwd: projectDir.path)
        XCTAssertEqual(result?.1, "rust-thing")
    }

    func test_detect_returnsNilWhenNoMarker() {
        let result = ProjectDetector.detect(cwd: tempDir.path)
        XCTAssertNil(result)
    }
}
