import XCTest
@testable import PorterIA

final class AIProcessScannerTests: XCTestCase {

    // MARK: - parseAndMatch — real Claude Desktop / Codex Desktop layouts

    func test_parseAndMatch_claudeDesktopMain() {
        let ps = "60429 /Applications/Claude.app/Contents/MacOS/Claude"
        let result = AIProcessScanner.parseAndMatch(ps)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].pid, 60429)
        XCTAssertEqual(result[0].command, "Claude")
        XCTAssertEqual(result[0].aiTool.displayName, "Claude Desktop")
        XCTAssertEqual(result[0].aiTool.category, .desktopApp)
    }

    func test_parseAndMatch_claudeDesktopIgnoresHelpers() {
        // Renderer / GPU helpers should NOT be tagged as Claude Desktop.
        // Their main executable is "Claude Helper", path goes through Frameworks/.
        let ps = """
        60435 /Applications/Claude.app/Contents/Frameworks/Claude Helper.app/Contents/MacOS/Claude Helper --type=gpu-process --user-data-dir=/foo
        60443 /Applications/Claude.app/Contents/Frameworks/Claude Helper (Renderer).app/Contents/MacOS/Claude Helper (Renderer) --type=renderer
        """
        let result = AIProcessScanner.parseAndMatch(ps)
        XCTAssertEqual(result.count, 0, "Electron helpers should not match Claude Desktop")
    }

    func test_parseAndMatch_claudeCodeInsideClaudeDesktop() {
        // The disclaimer wrapper spawned by Claude.app to host Claude Code.
        let ps = """
        37305 /Applications/Claude.app/Contents/Helpers/disclaimer /Users/jv/Library/Application Support/Claude/claude-code/2.1.149/claude.app/Contents/MacOS/claude --output-format stream-json
        """
        let result = AIProcessScanner.parseAndMatch(ps)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].aiTool.displayName, "Claude Code")
    }

    func test_parseAndMatch_codexDesktopAppServer() {
        let ps = "20905 /Applications/Codex.app/Contents/Resources/codex app-server --listen stdio://"
        let result = AIProcessScanner.parseAndMatch(ps)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].aiTool.displayName, "Codex Desktop")
    }

    func test_parseAndMatch_codexDesktopNodeRepl() {
        let ps = "20869 /Applications/Codex.app/Contents/Resources/node_repl"
        let result = AIProcessScanner.parseAndMatch(ps)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].aiTool.displayName, "Codex Desktop")
    }

    func test_parseAndMatch_codexCliVsDesktop() {
        // Standalone CLI (npm global install) should be "Codex CLI", NOT Desktop.
        let cliPs = "5555 node /opt/homebrew/lib/node_modules/@openai/codex/dist/cli.js"
        let cliResult = AIProcessScanner.parseAndMatch(cliPs)
        XCTAssertEqual(cliResult.first?.aiTool.displayName, "Codex CLI")
    }

    // MARK: - dedupeByTool

    func test_dedupeByTool_keepsLowestPidPerTool() {
        let claude1 = AIProcess(
            pid: 100, command: "Claude",
            aiTool: AITool(displayName: "Claude Desktop", category: .desktopApp)
        )
        let claude2 = AIProcess(
            pid: 50, command: "Claude",
            aiTool: AITool(displayName: "Claude Desktop", category: .desktopApp)
        )
        let codex = AIProcess(
            pid: 200, command: "codex",
            aiTool: AITool(displayName: "Codex Desktop", category: .desktopApp)
        )

        let result = AIProcessScanner.dedupeByTool([claude1, claude2, codex])

        XCTAssertEqual(result.count, 2)
        let claudeRow = result.first { $0.aiTool.displayName == "Claude Desktop" }
        XCTAssertEqual(claudeRow?.pid, 50, "should keep lowest pid for repeats")
    }

    func test_dedupeByTool_emptyInput() {
        XCTAssertEqual(AIProcessScanner.dedupeByTool([]).count, 0)
    }

    // MARK: - Ollama exception (already in port list, shouldn't double-show)

    func test_parseAndMatch_ollamaMatchesButIsFilteredByExcluding() {
        // The scanner itself matches Ollama (it's in the catalog).
        // The CALLER uses scan(excluding:) to strip PIDs already in port list.
        let ps = "1234 /opt/homebrew/bin/ollama serve"
        let matches = AIProcessScanner.parseAndMatch(ps)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].aiTool.displayName, "Ollama")
        // Caller is expected to filter pid=1234 if it's in the port list.
    }
}
