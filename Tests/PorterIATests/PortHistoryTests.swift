import XCTest
@testable import PorterIA

@MainActor
final class PortHistoryTests: XCTestCase {

    func test_sameOwnerBumpsLastSeen_doesNotAppend() {
        let store = PortHistoryStore()
        let t0 = Date()
        store.recordSighting(port: 3000, pid: 1234, command: "node", projectName: "my-app", now: t0)
        store.recordSighting(port: 3000, pid: 1234, command: "node", projectName: "my-app", now: t0.addingTimeInterval(5))

        let entries = store.entries(for: 3000)
        XCTAssertEqual(entries.count, 1, "same pid on same port should not create a new history entry")
        XCTAssertEqual(entries.first?.firstSeen, t0)
        XCTAssertEqual(entries.first?.lastSeen, t0.addingTimeInterval(5))
    }

    func test_ownerChangeAppendsNewEntry() {
        let store = PortHistoryStore()
        let t0 = Date()
        store.recordSighting(port: 3000, pid: 1234, command: "vite", projectName: nil, now: t0)
        store.recordSighting(port: 3000, pid: 5678, command: "next", projectName: nil, now: t0.addingTimeInterval(60))

        let entries = store.entries(for: 3000)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.pid, 5678, "most recent first")
        XCTAssertEqual(entries.last?.pid, 1234)
    }

    func test_capsHistoryPerPort() {
        let store = PortHistoryStore()
        let t0 = Date()
        // Insert 7 distinct owners for the same port; cap is 5.
        for i in 1...7 {
            store.recordSighting(
                port: 3000,
                pid: Int32(1000 + i),
                command: "v\(i)",
                projectName: nil,
                now: t0.addingTimeInterval(Double(i))
            )
        }
        let entries = store.entries(for: 3000)
        XCTAssertEqual(entries.count, 5, "history capped at 5 per port")
        // Oldest two should be evicted; remaining commands are v3..v7
        XCTAssertEqual(entries.first?.command, "v7")
        XCTAssertEqual(entries.last?.command, "v3")
    }

    func test_pruneRemovesEntriesOlderThan30min() {
        let store = PortHistoryStore()
        let now = Date()
        let old = now.addingTimeInterval(-31 * 60)
        store.recordSighting(port: 3000, pid: 1, command: "old", projectName: nil, now: old)
        store.recordSighting(port: 4000, pid: 2, command: "new", projectName: nil, now: now)
        store.prune(now: now)

        XCTAssertNil(store.history[3000], "30m+ old entry should be pruned")
        XCTAssertNotNil(store.history[4000])
    }

    func test_recentlyFreed_returnsPortsActiveWithin5min_butNotCurrentlyBound() {
        let store = PortHistoryStore()
        let now = Date()
        // Port 3000: last seen 2 minutes ago — should appear as recently freed if not bound now.
        store.recordSighting(port: 3000, pid: 1, command: "vite", projectName: "my-app", now: now.addingTimeInterval(-120))
        // Port 4000: last seen 10 minutes ago — outside the 5-min window.
        store.recordSighting(port: 4000, pid: 2, command: "old", projectName: nil, now: now.addingTimeInterval(-600))
        // Port 5000: last seen now AND currently bound — should NOT appear.
        store.recordSighting(port: 5000, pid: 3, command: "active", projectName: nil, now: now)

        let freed = store.recentlyFreed(currentlyBound: Set([5000]), now: now)
        XCTAssertEqual(freed.count, 1)
        XCTAssertEqual(freed.first?.port, 3000)
    }

    func test_observe_acceptsAnArrayOfPortEntries() {
        let store = PortHistoryStore()
        let now = Date()
        let entry = PortEntry(
            port: 3000, pid: 1234, command: "node", user: "u",
            bindAddress: "*:3000", projectPath: nil, projectName: "app"
        )
        store.observe([entry], now: now)
        XCTAssertEqual(store.entries(for: 3000).count, 1)
        XCTAssertEqual(store.entries(for: 3000).first?.projectName, "app")
    }

    func test_timeAgoFormatting() {
        let now = Date()
        let entry = PortHistoryEntry(
            port: 3000, pid: 1, command: "node", projectName: nil,
            firstSeen: now.addingTimeInterval(-90),
            lastSeen: now.addingTimeInterval(-90)
        )
        XCTAssertEqual(entry.timeAgo(now: now), "1m ago")

        let recent = PortHistoryEntry(
            port: 3000, pid: 1, command: "node", projectName: nil,
            firstSeen: now.addingTimeInterval(-30),
            lastSeen: now.addingTimeInterval(-30)
        )
        XCTAssertEqual(recent.timeAgo(now: now), "30s ago")
    }
}
