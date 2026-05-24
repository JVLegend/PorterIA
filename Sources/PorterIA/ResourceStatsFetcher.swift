import Foundation

/// CPU and memory percentages for a given PID, parsed from `ps`.
struct ResourceStats: Equatable, Hashable {
    let cpuPercent: Double
    let memPercent: Double
}

enum ResourceStatsFetcher {
    /// Batched fetch via `ps -p PID1,PID2,... -o pid=,%cpu=,%mem=`.
    /// One call covers every pid we care about. Returns `[pid: stats]`.
    static func fetch(for pids: Set<Int32>) -> [Int32: ResourceStats] {
        guard !pids.isEmpty else { return [:] }
        let pidList = pids.map(String.init).joined(separator: ",")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", pidList, "-o", "pid=,%cpu=,%mem="]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return [:]
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }
        return parse(output)
    }

    /// Each line: `   PID  %CPU  %MEM` (whitespace-separated, leading spaces).
    static func parse(_ output: String) -> [Int32: ResourceStats] {
        var result: [Int32: ResourceStats] = [:]
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = rawLine
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
            guard parts.count >= 3,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let mem = Double(parts[2])
            else { continue }
            result[pid] = ResourceStats(cpuPercent: cpu, memPercent: mem)
        }
        return result
    }
}
