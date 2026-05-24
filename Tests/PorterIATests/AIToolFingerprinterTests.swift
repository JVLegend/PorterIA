import XCTest
@testable import PorterIA

final class AIToolFingerprinterTests: XCTestCase {

    // MARK: - match — LLM servers

    func test_match_ollama() {
        let cmd = "/opt/homebrew/bin/ollama serve"
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.displayName, "Ollama")
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.category, .llmServer)
    }

    func test_match_lmStudio_appBundle() {
        let cmd = "/Applications/LM Studio.app/Contents/MacOS/LM Studio"
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.displayName, "LM Studio")
    }

    func test_match_vllm() {
        let cmd = "python -m vllm.entrypoints.openai.api_server --model meta-llama/Llama-3-8B"
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.displayName, "vLLM")
    }

    // MARK: - match — Agents / CLIs

    func test_match_claudeCode_npmGlobal() {
        let cmd = "node /opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.displayName, "Claude Code")
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.category, .aiAgent)
    }

    func test_match_claudeCode_localInstall() {
        let cmd = "node /Users/jv/.claude/local/node_modules/@anthropic-ai/claude-code/cli.js"
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.displayName, "Claude Code")
    }

    func test_match_codex() {
        let cmd = "node /opt/homebrew/lib/node_modules/@openai/codex/dist/cli.js"
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.displayName, "Codex CLI")
    }

    func test_match_aider() {
        let cmd = "python -m aider.main --model gpt-4o"
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.displayName, "Aider")
    }

    // MARK: - match — IDE extensions

    func test_match_continueDev() {
        let cmd = "node /Users/jv/.vscode/extensions/continue.continue/core/index.js"
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.displayName, "Continue.dev")
    }

    func test_match_copilot() {
        let cmd = "node copilot-language-server --stdio"
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.displayName, "GitHub Copilot")
    }

    func test_match_cursor() {
        let cmd = "/Applications/Cursor.app/Contents/MacOS/Cursor"
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.displayName, "Cursor")
    }

    // MARK: - match — Proxies / desktop / notebooks / remote

    func test_match_litellm() {
        let cmd = "python -m litellm --port 4000 --model gpt-4o"
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.displayName, "LiteLLM")
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.category, .aiProxy)
    }

    func test_match_claudeDesktop() {
        let cmd = "/Applications/Claude.app/Contents/MacOS/Claude"
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.displayName, "Claude Desktop")
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.category, .desktopApp)
    }

    func test_match_jupyter() {
        let cmd = "/opt/homebrew/Cellar/python@3.12/bin/jupyter-lab --port 8888"
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.displayName, "Jupyter")
    }

    func test_match_vscodeServer() {
        let cmd = "node /Users/jv/.vscode-server/bin/abc123/out/server-main.js code-server --port 8080"
        XCTAssertEqual(AIToolFingerprinter.match(cmdline: cmd)?.displayName, "VS Code Server")
    }

    // MARK: - match — negative cases

    func test_match_noMatchForRegularNode() {
        let cmd = "node /Users/jv/my-app/server.js"
        XCTAssertNil(AIToolFingerprinter.match(cmdline: cmd))
    }

    func test_match_noMatchForPostgres() {
        let cmd = "postgres -D /opt/homebrew/var/postgres"
        XCTAssertNil(AIToolFingerprinter.match(cmdline: cmd))
    }

    // MARK: - parsePsOutput

    func test_parsePsOutput_singleLine() {
        let out = "  1234 /opt/homebrew/bin/ollama serve"
        let parsed = AIToolFingerprinter.parsePsOutput(out)
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[1234], "/opt/homebrew/bin/ollama serve")
    }

    func test_parsePsOutput_multipleLines() {
        let out = """
          1234 /opt/homebrew/bin/ollama serve
         5678 node /Users/jv/app/server.js
        99999 postgres -D /opt/homebrew/var/postgres
        """
        let parsed = AIToolFingerprinter.parsePsOutput(out)
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[1234], "/opt/homebrew/bin/ollama serve")
        XCTAssertEqual(parsed[5678], "node /Users/jv/app/server.js")
        XCTAssertEqual(parsed[99999], "postgres -D /opt/homebrew/var/postgres")
    }

    func test_parsePsOutput_ignoresMalformedLines() {
        let out = """
          1234 valid line
        garbage with no pid
          5678 another valid one
        """
        let parsed = AIToolFingerprinter.parsePsOutput(out)
        XCTAssertEqual(parsed[1234], "valid line")
        XCTAssertEqual(parsed[5678], "another valid one")
        XCTAssertNil(parsed[0])
    }

    func test_parsePsOutput_empty() {
        XCTAssertEqual(AIToolFingerprinter.parsePsOutput("").count, 0)
    }
}
