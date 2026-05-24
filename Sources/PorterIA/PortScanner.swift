import Foundation

enum PortScanner {
    /// Runs `lsof -i -P -n -sTCP:LISTEN -F pcnLT` and parses entries.
    /// The -F format outputs one field per line, prefixed by a tag.
    static func scan() -> [PortEntry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-i", "-P", "-n", "-sTCP:LISTEN", "-F", "pcnLT"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        return parse(output)
    }

    /// lsof -F output format:
    ///   p<pid>    process record start
    ///   c<command>
    ///   L<user>
    ///   T<protocol/state>  (we filter via -sTCP:LISTEN already)
    ///   n<name>            e.g. *:3000  or  127.0.0.1:5432
    /// Records are separated by the next p<pid>.
    static func parse(_ output: String) -> [PortEntry] {
        var entries: [PortEntry] = []
        var currentPid: Int32?
        var currentCommand = ""
        var currentUser = ""

        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())

            switch tag {
            case "p":
                currentPid = Int32(value)
                currentCommand = ""
                currentUser = ""
            case "c":
                currentCommand = value
            case "L":
                currentUser = value
            case "n":
                guard let pid = currentPid,
                      let port = extractPort(from: value) else { continue }
                entries.append(PortEntry(
                    port: port,
                    pid: pid,
                    command: currentCommand,
                    user: currentUser,
                    bindAddress: value
                ))
            default:
                break
            }
        }

        return dedupe(entries).sorted { $0.port < $1.port }
    }

    /// Extracts the port from an lsof name like "*:3000", "127.0.0.1:5432",
    /// "[::1]:8080", or "localhost:3000".
    static func extractPort(from name: String) -> Int? {
        guard let lastColon = name.lastIndex(of: ":") else { return nil }
        let portPart = name[name.index(after: lastColon)...]
        return Int(portPart)
    }

    /// A single listening socket can appear twice (IPv4 + IPv6). Collapse by (pid, port).
    static func dedupe(_ entries: [PortEntry]) -> [PortEntry] {
        var seen = Set<String>()
        var result: [PortEntry] = []
        for entry in entries {
            let key = "\(entry.pid)-\(entry.port)"
            if seen.insert(key).inserted {
                result.append(entry)
            }
        }
        return result
    }
}

enum ProcessKiller {
    /// Sends SIGTERM to the given PID. Returns true if kill(2) returned 0.
    static func terminate(pid: Int32) -> Bool {
        kill(pid, SIGTERM) == 0
    }
}
