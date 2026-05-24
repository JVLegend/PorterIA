import Foundation

enum PortScanner {
    /// Top-level scan: lists listening TCP ports with owner + project + AI tool metadata.
    static func scan() -> [PortEntry] {
        let raw = runLsofListen()
        guard let output = raw else { return [] }
        var entries = parse(output)
        let pidSet = Set(entries.map(\.pid))
        let cwdMap = fetchCwds(for: pidSet)
        let cmdMap = AIToolFingerprinter.cmdlines(for: pidSet)
        entries = entries.map { entry in
            let cwd = cwdMap[entry.pid]
            let (root, name) = cwd.flatMap(ProjectDetector.detect) ?? (nil, nil)
            let aiTool = cmdMap[entry.pid].flatMap(AIToolFingerprinter.match)
            return PortEntry(
                port: entry.port,
                pid: entry.pid,
                command: entry.command,
                user: entry.user,
                bindAddress: entry.bindAddress,
                projectPath: root,
                projectName: name,
                aiTool: aiTool
            )
        }
        return entries
    }

    // MARK: - lsof invocations

    private static func runLsofListen() -> String? {
        runProcess(
            launchPath: "/usr/sbin/lsof",
            arguments: ["-i", "-P", "-n", "-sTCP:LISTEN", "-F", "pcnLT"]
        )
    }

    /// Runs `lsof -p PID1,PID2,... -d cwd -F n` and parses cwd per pid.
    static func fetchCwds(for pids: Set<Int32>) -> [Int32: String] {
        guard !pids.isEmpty else { return [:] }
        let pidList = pids.map(String.init).joined(separator: ",")
        guard let output = runProcess(
            launchPath: "/usr/sbin/lsof",
            arguments: ["-p", pidList, "-d", "cwd", "-F", "n"]
        ) else { return [:] }

        var result: [Int32: String] = [:]
        var currentPid: Int32?
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            switch tag {
            case "p":
                currentPid = Int32(value)
            case "n":
                if let pid = currentPid, result[pid] == nil {
                    result[pid] = value
                }
            default:
                break
            }
        }
        return result
    }

    private static func runProcess(launchPath: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let outPipe = Pipe()
        process.standardOutput = outPipe
        // CRITICAL: send stderr to /dev/null. If we use a Pipe() and never
        // read it, lsof's stderr warnings (denied access to system processes)
        // fill the 64KB buffer, lsof blocks on write(), waitUntilExit deadlocks,
        // and the UI shows zero ports. Caught in production after release.
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        // Read stdout BEFORE waitUntilExit to avoid the same buffer-fill
        // deadlock on stdout for unusually large outputs.
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

    // MARK: - lsof -F parsing for listening sockets

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
                    bindAddress: value,
                    projectPath: nil,
                    projectName: nil
                ))
            default:
                break
            }
        }

        return dedupe(entries).sorted { $0.port < $1.port }
    }

    static func extractPort(from name: String) -> Int? {
        guard let lastColon = name.lastIndex(of: ":") else { return nil }
        let portPart = name[name.index(after: lastColon)...]
        return Int(portPart)
    }

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
    static func terminate(pid: Int32) -> Bool {
        kill(pid, SIGTERM) == 0
    }
}

/// Walks up from a cwd to find the nearest "project root", defined as the
/// first ancestor that contains any of: package.json, pyproject.toml,
/// Cargo.toml, go.mod, Gemfile, or .git.
enum ProjectDetector {
    static let markers = [
        "package.json",
        "pyproject.toml",
        "Cargo.toml",
        "go.mod",
        "Gemfile",
        ".git",
    ]

    /// Returns (projectRoot, displayName) or nil if no marker found within 10 levels up.
    static func detect(cwd: String) -> (String, String)? {
        let fm = FileManager.default
        var url = URL(fileURLWithPath: cwd, isDirectory: true).standardizedFileURL
        for _ in 0..<10 {
            for marker in markers {
                let candidate = url.appendingPathComponent(marker)
                if fm.fileExists(atPath: candidate.path) {
                    let name = readProjectName(at: url, marker: marker) ?? url.lastPathComponent
                    return (url.path, name)
                }
            }
            let parent = url.deletingLastPathComponent().standardizedFileURL
            if parent == url { break } // reached /
            url = parent
        }
        return nil
    }

    /// For package.json, extract "name". Otherwise fall back to directory basename.
    private static func readProjectName(at dir: URL, marker: String) -> String? {
        guard marker == "package.json" else { return nil }
        let pkgURL = dir.appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: pkgURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = obj["name"] as? String,
              !name.isEmpty
        else { return nil }
        return name
    }
}
