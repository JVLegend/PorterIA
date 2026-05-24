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

    /// Human-friendly bind label: "all interfaces", "localhost", or the literal host.
    var bindLabel: String {
        // Take everything before the last ':' (which separates host from port).
        // Using lastIndex avoids mangling IPv6 like "[::1]:8080".
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
    /// Example: "next-app" (when project detected) or "node" (fallback).
    var primaryLabel: String { projectName ?? command }

    /// Secondary text under the primary label.
    /// Example: "node · pid 1234 · localhost" when project name is present,
    /// otherwise "pid 1234 · localhost".
    var secondaryLabel: String {
        if projectName != nil {
            return "\(command) · pid \(pid) · \(bindLabel)"
        }
        return "pid \(pid) · \(bindLabel)"
    }
}
