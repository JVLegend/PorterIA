import Foundation

/// A running process recognized as an AI tool, *regardless* of whether
/// it owns a listening TCP port. Used to surface apps like Claude Desktop
/// or Codex Desktop that talk over stdio / HTTPS and never listen externally.
struct AIProcess: Identifiable, Hashable {
    let id = UUID()
    let pid: Int32
    let command: String
    let aiTool: AITool
}

enum AIProcessScanner {

    /// Scans ALL running processes via `ps -A -o pid=,args=`, fingerprints
    /// each against the AI catalog, and returns unique tools detected.
    ///
    /// Deduplication: when multiple PIDs match the same AI tool (e.g. three
    /// Codex Helper subprocesses), only the lowest PID is kept. This avoids
    /// drowning the UI in Electron helper noise while still surfacing the
    /// fact that the tool is running.
    static func scan() -> [AIProcess] {
        guard let output = runPsAll() else { return [] }
        let allMatches = parseAndMatch(output)
        return dedupeByTool(allMatches)
    }

    /// Same as `scan()` but excludes processes whose PID already appears
    /// in the given set (i.e. they're already shown in the port list).
    static func scan(excluding portPids: Set<Int32>) -> [AIProcess] {
        scan().filter { !portPids.contains($0.pid) }
    }

    // MARK: - Internals

    private static func runPsAll() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-A", "-o", "pid=,args="]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

    static func parseAndMatch(_ psOutput: String) -> [AIProcess] {
        var result: [AIProcess] = []
        let parsed = AIToolFingerprinter.parsePsOutput(psOutput)
        for (pid, cmd) in parsed {
            guard let tool = AIToolFingerprinter.match(cmdline: cmd) else { continue }
            // command displayed in the row = first word of args (the binary name).
            let displayCmd = cmd.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? cmd
            let basename = (displayCmd as NSString).lastPathComponent
            result.append(AIProcess(pid: pid, command: basename, aiTool: tool))
        }
        return result
    }

    static func dedupeByTool(_ matches: [AIProcess]) -> [AIProcess] {
        var seen = Set<String>()
        var result: [AIProcess] = []
        // Sort by pid ascending so the "main" / lowest pid wins.
        for entry in matches.sorted(by: { $0.pid < $1.pid }) {
            if seen.insert(entry.aiTool.displayName).inserted {
                result.append(entry)
            }
        }
        return result
    }
}
