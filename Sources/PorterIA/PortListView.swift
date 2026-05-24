import SwiftUI

@MainActor
final class PortStore: ObservableObject {
    @Published var entries: [PortEntry] = []
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
            await MainActor.run {
                self.entries = scanned
                self.lastRefresh = Date()
            }
        }
    }

    func kill(_ entry: PortEntry) {
        _ = ProcessKiller.terminate(pid: entry.pid)
        refresh()
    }
}

// MARK: - Root view

struct PortListView: View {
    @ObservedObject var store: PortStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 340)
        .background(.background)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tint)
            Text("PorterIA")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("\(store.entries.count)")
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

    /// Approximate height of one PortRowView (padding 8+8 + content ~30).
    private static let rowHeight: CGFloat = 46
    private static let minVisibleRows: CGFloat = 4
    private static let maxVisibleRows: CGFloat = 8

    @ViewBuilder
    private var content: some View {
        if store.entries.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                        PortRowView(entry: entry) { store.kill(entry) }
                        if index < store.entries.count - 1 {
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
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text("No listening TCP ports")
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

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
                .keyboardShortcut("q")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
                Text(entry.command)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("pid \(entry.pid) · \(entry.bindLabel)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
