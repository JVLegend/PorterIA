import SwiftUI

@MainActor
final class PortStore: ObservableObject {
    @Published var entries: [PortEntry] = []
    /// AI tools that are running but don't own a listening TCP port
    /// (e.g. Claude Desktop, Codex Desktop using stdio).
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
    @State private var filter: PortFilter = .all

    private var filteredEntries: [PortEntry] {
        switch filter {
        case .all: return store.entries
        case .aiOnly: return store.entries.filter { $0.aiTool != nil }
        }
    }

    private var aiCount: Int {
        store.entries.filter { $0.aiTool != nil }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            if !store.aiProcessesWithoutPort.isEmpty {
                Divider()
                aiProcessSection
            }
            Divider()
            footer
        }
        .frame(width: 340)
        .background(.background)
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

            Picker("", selection: $filter) {
                ForEach(PortFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
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

    private static let rowHeight: CGFloat = 46
    private static let minVisibleRows: CGFloat = 4
    private static let maxVisibleRows: CGFloat = 8

    @ViewBuilder
    private var content: some View {
        let list = filteredEntries
        if list.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { index, entry in
                        PortRowView(entry: entry) { store.kill(entry) }
                        if index < list.count - 1 {
                            Divider().padding(.leading, 12)
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

// MARK: - Row

private struct PortRowView: View {
    let entry: PortEntry
    let onKill: () -> Void

    @State private var hovering = false

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
                Text(entry.secondaryLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

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
}

/// Compact row for AI tools running without a listening TCP port.
/// Lives under the main port list, between the divider and the footer.
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

/// Small colored capsule shown next to the primary label when the row's
/// process matches a known AI tool. Colored per category to make the type
/// scannable at a glance.
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
