import SwiftUI
import AppKit

@MainActor
final class PortStore: ObservableObject {
    @Published var entries: [PortEntry] = []
    @Published var aiProcessesWithoutPort: [AIProcess] = []
    @Published var lastRefresh: Date = Date()
    private var timer: Timer?

    func startAutoRefresh() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        Task.detached(priority: .userInitiated) {
            let scanned = PortScanner.scan()
            let portPids = Set(scanned.map(\.pid))
            let aiOnly = AIProcessScanner.scan(excluding: portPids)
            await MainActor.run {
                self.entries = scanned
                self.aiProcessesWithoutPort = aiOnly
                self.lastRefresh = Date()
            }
        }
    }

    func kill(_ entry: PortEntry) {
        _ = ProcessKiller.terminate(pid: entry.pid)
        refresh()
    }

    func killProcess(pid: Int32) {
        _ = ProcessKiller.terminate(pid: pid)
        refresh()
    }
}

enum PortFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case aiOnly = "AI"
    var id: String { rawValue }
}

// MARK: - Root view

struct PortListView: View {
    @ObservedObject var store: PortStore
    @StateObject private var launchAtLogin = LaunchAtLoginController()
    @StateObject private var pinStore = PinStore()
    @State private var filter: PortFilter = .all
    @State private var searchText: String = ""
    @AppStorage("PorterIA.groupByProject") private var groupByProject: Bool = false

    private var filteredEntries: [PortEntry] {
        let base: [PortEntry]
        switch filter {
        case .all: base = store.entries
        case .aiOnly: base = store.entries.filter { $0.aiTool != nil }
        }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { entry in
            String(entry.port).contains(q)
                || entry.command.lowercased().contains(q)
                || (entry.projectName?.lowercased().contains(q) ?? false)
                || (entry.aiTool?.displayName.lowercased().contains(q) ?? false)
                || entry.bindLabel.lowercased().contains(q)
        }
    }

    private var aiCount: Int {
        store.entries.filter { $0.aiTool != nil }.count
    }

    /// Pinned ports that are currently bound — they get the regular row UI.
    private var activePinnedEntries: [PortEntry] {
        filteredEntries.filter { pinStore.isPinned($0.port) }
            .sorted { $0.port < $1.port }
    }

    /// Pinned ports that are NOT currently bound — rendered as faded placeholder rows.
    private var inactivePinnedPorts: [Int] {
        let active = Set(activePinnedEntries.map(\.port))
        return pinStore.pinned.subtracting(active).sorted()
    }

    /// Everything not pinned.
    private var unpinnedEntries: [PortEntry] {
        filteredEntries.filter { !pinStore.isPinned($0.port) }
    }

    /// Groups of unpinned entries by projectName (when groupByProject is on).
    private var groupedUnpinned: [(name: String, entries: [PortEntry])] {
        guard groupByProject else { return [] }
        var byProject: [String: [PortEntry]] = [:]
        for entry in unpinnedEntries {
            let key = entry.projectName ?? "__OTHER__"
            byProject[key, default: []].append(entry)
        }
        return byProject.map { (key, entries) in
            (name: key == "__OTHER__" ? "Other" : key,
             entries: entries.sorted { $0.port < $1.port })
        }.sorted { lhs, rhs in
            // "Other" always last
            if lhs.name == "Other" { return false }
            if rhs.name == "Other" { return true }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.entries.count > 6 {
                searchBar
            }
            Divider()
            content
            if !store.aiProcessesWithoutPort.isEmpty {
                Divider()
                aiProcessSection
            }
            Divider()
            footer
        }
        .frame(width: 360)
        .background(.background)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tint)
            Text("PorterIA")
                .font(.system(size: 13, weight: .semibold))

            if aiCount > 0 {
                Text("\(aiCount) AI")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.purple.opacity(0.85))
                    )
            }

            Spacer()

            Button {
                groupByProject.toggle()
            } label: {
                Image(systemName: groupByProject ? "rectangle.3.group.fill" : "rectangle.3.group")
                    .font(.system(size: 11))
                    .foregroundStyle(groupByProject ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(groupByProject ? "Ungroup" : "Group by project")

            Picker("", selection: $filter) {
                ForEach(PortFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 84)
            .controlSize(.mini)

            Text("\(filteredEntries.count)")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Filter by port, command, project, AI tool…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08))
    }

    private static let rowHeight: CGFloat = 46
    private static let minVisibleRows: CGFloat = 4
    private static let maxVisibleRows: CGFloat = 8

    @ViewBuilder
    private var content: some View {
        if filteredEntries.isEmpty && inactivePinnedPorts.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !activePinnedEntries.isEmpty || !inactivePinnedPorts.isEmpty {
                        sectionHeader("Pinned")
                        ForEach(activePinnedEntries) { entry in
                            PortRowView(
                                entry: entry,
                                isPinned: true,
                                onKill: { store.kill(entry) },
                                onTogglePin: { pinStore.toggle(entry.port) }
                            )
                            Divider().padding(.leading, 12)
                        }
                        ForEach(inactivePinnedPorts, id: \.self) { port in
                            PinnedEmptyRow(port: port) { pinStore.toggle(port) }
                            Divider().padding(.leading, 12)
                        }
                    }

                    if groupByProject {
                        ForEach(groupedUnpinned, id: \.name) { group in
                            sectionHeader(group.name)
                            ForEach(group.entries) { entry in
                                PortRowView(
                                    entry: entry,
                                    isPinned: false,
                                    onKill: { store.kill(entry) },
                                    onTogglePin: { pinStore.toggle(entry.port) }
                                )
                                Divider().padding(.leading, 12)
                            }
                        }
                    } else {
                        ForEach(Array(unpinnedEntries.enumerated()), id: \.element.id) { index, entry in
                            PortRowView(
                                entry: entry,
                                isPinned: false,
                                onKill: { store.kill(entry) },
                                onTogglePin: { pinStore.toggle(entry.port) }
                            )
                            if index < unpinnedEntries.count - 1 {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                }
            }
            .frame(
                minHeight: Self.rowHeight * Self.minVisibleRows,
                maxHeight: Self.rowHeight * Self.maxVisibleRows
            )
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: filter == .aiOnly ? "sparkles" : "checkmark.circle")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text(filter == .aiOnly ? "No AI tools detected" : "No listening TCP ports")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var aiProcessSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(.purple)
                Text("AI tools active (no port)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(store.aiProcessesWithoutPort.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 2)

            ForEach(store.aiProcessesWithoutPort) { proc in
                AIProcessRow(process: proc) { store.killProcess(pid: proc.pid) }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                store.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("r")

            Text(relativeRefreshLabel)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Spacer()

            if launchAtLogin.isManageable {
                Toggle(isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { _ in launchAtLogin.toggle() }
                )) {
                    Text("Start at login")
                        .font(.system(size: 10))
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
            }

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
                .keyboardShortcut("q")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear { launchAtLogin.refresh() }
    }

    private var relativeRefreshLabel: String {
        let seconds = Int(Date().timeIntervalSince(store.lastRefresh))
        if seconds < 2 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        return "\(seconds / 60)m ago"
    }
}

// MARK: - Port row

private struct PortRowView: View {
    let entry: PortEntry
    let isPinned: Bool
    let onKill: () -> Void
    let onTogglePin: () -> Void

    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: 10) {
            Text("\(entry.port)")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if let tool = entry.aiTool {
                        AIBadge(category: tool.category)
                    }
                    Text(entry.primaryLabel)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                HStack(spacing: 6) {
                    Text(entry.secondaryLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let s = entry.stats {
                        StatsChip(stats: s)
                    }
                }
            }

            Spacer(minLength: 4)

            // Pin button — always visible if pinned, hover-only if not
            if isPinned || hovering {
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11))
                        .foregroundStyle(isPinned ? Color.orange : Color.secondary.opacity(0.6))
                        .rotationEffect(.degrees(45))
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin" : "Pin this port")
            }

            Button(action: copyURL) {
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(copied ? Color.green : Color.secondary.opacity(hovering ? 0.8 : 0.5))
            }
            .buttonStyle(.plain)
            .help("Copy http://\(hostForCopy):\(entry.port)")

            Button(action: onKill) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(hovering ? Color.red : Color.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Kill pid \(entry.pid) (SIGTERM)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(hovering ? Color.secondary.opacity(0.08) : Color.clear)
        .onHover { hovering = $0 }
    }

    private var hostForCopy: String {
        switch entry.bindLabel {
        case "localhost", "all interfaces": return "localhost"
        default: return entry.bindLabel
        }
    }

    private func copyURL() {
        let url = "http://\(hostForCopy):\(entry.port)"
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url, forType: .string)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copied = false }
        }
    }
}

// MARK: - Pinned-but-not-bound row

private struct PinnedEmptyRow: View {
    let port: Int
    let onUnpin: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Text("\(port)")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text("(not in use)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("pinned — port is free")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 4)

            Button(action: onUnpin) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.orange)
                    .rotationEffect(.degrees(45))
            }
            .buttonStyle(.plain)
            .help("Unpin")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(hovering ? Color.secondary.opacity(0.06) : Color.clear)
        .onHover { hovering = $0 }
        .opacity(0.75)
    }
}

// MARK: - Stats chip (CPU/MEM)

private struct StatsChip: View {
    let stats: ResourceStats

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "cpu")
                .font(.system(size: 8))
            Text(format(stats.cpuPercent) + "%")
                .font(.system(size: 9, design: .monospaced))
                .monospacedDigit()
        }
        .foregroundStyle(cpuColor)
        .padding(.horizontal, 3)
        .padding(.vertical, 0.5)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(cpuColor.opacity(0.12))
        )
    }

    private var cpuColor: Color {
        switch stats.cpuPercent {
        case 50...: return .red
        case 20..<50: return .orange
        default: return .secondary
        }
    }

    private func format(_ v: Double) -> String {
        v < 10 ? String(format: "%.1f", v) : String(Int(v.rounded()))
    }
}

// MARK: - AI process row (no-port section)

private struct AIProcessRow: View {
    let process: AIProcess
    let onKill: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            AIBadge(category: process.aiTool.category)
            VStack(alignment: .leading, spacing: 0) {
                Text(process.aiTool.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text("\(process.command) · pid \(process.pid)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Button(action: onKill) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(hovering ? Color.red : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Kill pid \(process.pid) (SIGTERM)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(hovering ? Color.secondary.opacity(0.08) : Color.clear)
        .onHover { hovering = $0 }
    }
}

// MARK: - AI badge

private struct AIBadge: View {
    let category: AIToolCategory

    var body: some View {
        Text("AI")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
            )
    }

    private var color: Color {
        switch category {
        case .llmServer:    return .orange
        case .aiAgent:      return .purple
        case .aiProxy:      return .teal
        case .ideExtension: return .blue
        case .desktopApp:   return .green
        case .notebook:     return .pink
        case .remoteDev:    return .gray
        }
    }
}
