import Foundation

struct PortEntry: Identifiable, Hashable {
    let id = UUID()
    let port: Int
    let pid: Int32
    let command: String
    let user: String
    /// Raw lsof name, e.g. "*:3000", "127.0.0.1:5432", "[::1]:8080".
    let bindAddress: String
    /// Detected project root, if any (nearest ancestor of cwd containing
    /// a known project marker file).
    let projectPath: String?
    /// Human-friendly project name (basename of projectPath, or the value of
    /// "name" in package.json when available).
    let projectName: String?
    /// Identified AI tool (Ollama, Claude Code, Codex, ...), if the owning
    /// process matches a known fingerprint. Defaults to nil so existing
    /// memberwise initializers (and tests) keep working.
    var aiTool: AITool? = nil

    /// Human-friendly bind label: "all interfaces", "localhost", or the literal host.
    var bindLabel: String {
        guard let lastColon = bindAddress.lastIndex(of: ":") else { return bindAddress }
        let host = String(bindAddress[..<lastColon])
        switch host {
        case "*", "":
            return "all interfaces"
        case "127.0.0.1", "[::1]", "::1":
            return "localhost"
        default:
            return host
        }
    }

    /// Best-effort display title for the row.
    /// Priority: AI tool name > project name > raw command.
    var primaryLabel: String {
        if let tool = aiTool { return tool.displayName }
        return projectName ?? command
    }

    /// Secondary text under the primary label.
    var secondaryLabel: String {
        var parts: [String] = []
        if aiTool != nil || projectName != nil {
            parts.append(command)
        }
        parts.append("pid \(pid)")
        parts.append(bindLabel)
        return parts.joined(separator: " · ")
    }
}
