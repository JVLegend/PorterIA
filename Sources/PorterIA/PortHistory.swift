import Foundation

/// One historical record of a (port, pid) ownership window. `firstSeen` is
/// when the scanner first observed this exact pid on this port; `lastSeen`
/// is the most recent scan that still saw it.
struct PortHistoryEntry: Identifiable, Hashable {
    let id = UUID()
    let port: Int
    let pid: Int32
    let command: String
    let projectName: String?
    let firstSeen: Date
    let lastSeen: Date

    func timeAgo(now: Date = Date()) -> String {
        let secs = Int(now.timeIntervalSince(lastSeen))
        if secs < 60 { return "\(secs)s ago" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        return "\(secs / 3600)h ago"
    }

    /// How long this owner held the port.
    var duration: TimeInterval { lastSeen.timeIntervalSince(firstSeen) }
}

/// Tracks recent port ownership transitions. Pure in-memory (lost on quit).
/// Used to:
///   - Show "Recently freed" ports (active recently, not bound now)
///   - Display per-row tooltips with previous owners
@MainActor
final class PortHistoryStore: ObservableObject {
    @Published private(set) var history: [Int: [PortHistoryEntry]] = [:]

    private let maxPerPort = 5
    private let maxAge: TimeInterval = 30 * 60       // keep 30 min total
    private let recentWindow: TimeInterval = 5 * 60  // "recently freed" = within 5 min

    /// Call after each scan. Merges current entries into history and prunes old data.
    func observe(_ entries: [PortEntry], now: Date = Date()) {
        for entry in entries {
            recordSighting(
                port: entry.port,
                pid: entry.pid,
                command: entry.command,
                projectName: entry.projectName,
                now: now
            )
        }
        prune(now: now)
    }

    /// Returns ports that had a process within `recentWindow` seconds but
    /// are NOT in `currentlyBound`. Most recently freed first.
    func recentlyFreed(currentlyBound: Set<Int>, now: Date = Date()) -> [PortHistoryEntry] {
        let cutoff = now.addingTimeInterval(-recentWindow)
        var result: [PortHistoryEntry] = []
        for (port, entries) in history where !currentlyBound.contains(port) {
            if let last = entries.last, last.lastSeen >= cutoff {
                result.append(last)
            }
        }
        return result.sorted { $0.lastSeen > $1.lastSeen }
    }

    /// Most-recent-first list of owners for a specific port.
    func entries(for port: Int) -> [PortHistoryEntry] {
        (history[port] ?? []).reversed()
    }

    // MARK: - Internals (also exposed for tests via @testable)

    func recordSighting(
        port: Int,
        pid: Int32,
        command: String,
        projectName: String?,
        now: Date
    ) {
        var list = history[port] ?? []

        if let last = list.last, last.pid == pid {
            // Same owner still bound — just bump lastSeen.
            list[list.count - 1] = PortHistoryEntry(
                port: port,
                pid: pid,
                command: command,
                projectName: projectName ?? last.projectName,
                firstSeen: last.firstSeen,
                lastSeen: now
            )
        } else {
            // New owner (or first sighting for this port).
            list.append(PortHistoryEntry(
                port: port,
                pid: pid,
                command: command,
                projectName: projectName,
                firstSeen: now,
                lastSeen: now
            ))
            // Cap history per port — drop oldest beyond limit.
            if list.count > maxPerPort {
                list.removeFirst(list.count - maxPerPort)
            }
        }
        history[port] = list
    }

    func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-maxAge)
        for (port, entries) in history {
            let kept = entries.filter { $0.lastSeen >= cutoff }
            if kept.isEmpty {
                history.removeValue(forKey: port)
            } else if kept.count != entries.count {
                history[port] = kept
            }
        }
    }
}
