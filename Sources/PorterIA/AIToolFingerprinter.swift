import Foundation

enum AIToolCategory: String, Hashable {
    case llmServer        // Ollama, LM Studio, vLLM
    case aiAgent          // Claude Code, Codex, Aider, Goose, Open Interpreter
    case aiProxy          // LiteLLM
    case ideExtension     // Continue.dev, Copilot, Cursor agent
    case desktopApp       // Claude Desktop
    case notebook         // Jupyter
    case remoteDev        // VS Code Server / tunnel
}

struct AITool: Equatable, Hashable {
    let displayName: String
    let category: AIToolCategory
}

/// Inspects process command lines to identify common AI dev tooling.
/// Patterns are matched as regular expressions against the full
/// `ps -p PID -o args=` output.
enum AIToolFingerprinter {

    /// Ordered catalog. First match wins. More specific patterns should
    /// appear before generic ones.
    static let catalog: [(name: String, category: AIToolCategory, patterns: [String])] = [
        // LLM servers
        ("Ollama",            .llmServer,    [#"\bollama( serve)?\b"#]),
        ("LM Studio",         .llmServer,    [#"LM Studio\.app"#, #"\blms-server\b"#, #"\blmstudio\b"#]),
        ("vLLM",              .llmServer,    [#"vllm\.entrypoints"#, #"-m vllm\b"#]),

        // Agents / CLIs
        ("Claude Code",       .aiAgent,      [#"@anthropic-ai/claude-code"#, #"\.claude/local"#, #"/bin/claude\b"#]),
        ("Codex CLI",         .aiAgent,      [#"@openai/codex"#, #"/bin/codex\b"#]),
        ("Aider",             .aiAgent,      [#"\baider-chat\b"#, #"-m aider\b"#, #"/bin/aider\b"#]),
        ("Goose",             .aiAgent,      [#"block/goose"#, #"\bgoosed\b"#]),
        ("Open Interpreter",  .aiAgent,      [#"open-interpreter"#, #"open_interpreter"#, #"/bin/interpreter\b"#]),

        // IDE extensions / helpers
        ("Continue.dev",      .ideExtension, [#"@continuedev"#, #"continue\.continue"#, #"continuedev/core"#]),
        ("GitHub Copilot",    .ideExtension, [#"copilot-language-server"#, #"copilot-agent"#]),
        ("Cursor",            .ideExtension, [#"Cursor\.app"#, #"cursor-helper"#, #"cursor-agent"#]),
        ("Tabby",             .ideExtension, [#"tabby serve"#, #"tabby-agent"#]),

        // Proxies
        ("LiteLLM",           .aiProxy,      [#"\blitellm\b"#]),

        // Desktop apps
        ("Claude Desktop",    .desktopApp,   [#"Claude\.app/Contents/MacOS/Claude"#]),

        // Notebooks / remote dev
        ("Jupyter",           .notebook,     [#"jupyter-notebook"#, #"jupyter-lab"#, #"jupyter-server"#, #"-m notebook\b"#, #"-m jupyterlab\b"#]),
        ("VS Code Server",    .remoteDev,    [#"code-server\b"#, #"code-tunnel\b"#, #"code-server-tunnel"#]),
    ]

    /// Match a single command line against the catalog.
    static func match(cmdline: String) -> AITool? {
        for entry in catalog {
            for pattern in entry.patterns {
                if cmdline.range(of: pattern, options: .regularExpression) != nil {
                    return AITool(displayName: entry.name, category: entry.category)
                }
            }
        }
        return nil
    }

    /// Batch-fetch full command lines for a set of PIDs.
    /// Returns `[pid: cmdline]`. Single `ps` call, no fan-out.
    static func cmdlines(for pids: Set<Int32>) -> [Int32: String] {
        guard !pids.isEmpty else { return [:] }
        let pidList = pids.map(String.init).joined(separator: ",")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", pidList, "-o", "pid=,args="]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        // See note in PortScanner.runProcess: piping stderr without reading
        // deadlocks if the child writes there. Route to /dev/null.
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return [:]
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }
        return parsePsOutput(output)
    }

    /// Parses the output of `ps -p ... -o pid=,args=`. Each non-empty line
    /// starts with optional whitespace, then the PID, then whitespace, then
    /// the full command. Splits on the FIRST whitespace after the PID.
    static func parsePsOutput(_ output: String) -> [Int32: String] {
        var result: [Int32: String] = [:]
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.drop(while: { $0 == " " || $0 == "\t" })
            guard let firstSpace = line.firstIndex(where: { $0 == " " || $0 == "\t" }) else { continue }
            let pidStr = String(line[..<firstSpace])
            let args = String(line[line.index(after: firstSpace)...])
                .trimmingCharacters(in: .whitespaces)
            if let pid = Int32(pidStr), !args.isEmpty {
                result[pid] = args
            }
        }
        return result
    }
}
