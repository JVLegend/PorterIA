import Foundation
import SwiftUI

/// Persistent set of pinned port numbers. Backed by UserDefaults via
/// @AppStorage. Pinned ports always sort to the top of the list and
/// stay visible (as a "(not in use)" placeholder) even when nothing
/// is currently bound to them.
@MainActor
final class PinStore: ObservableObject {
    private static let storageKey = "PorterIA.pinnedPorts"

    @Published private(set) var pinned: Set<Int> = []

    init() {
        load()
    }

    func isPinned(_ port: Int) -> Bool { pinned.contains(port) }

    func toggle(_ port: Int) {
        if pinned.contains(port) {
            pinned.remove(port)
        } else {
            pinned.insert(port)
        }
        save()
    }

    private func load() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        pinned = Set(raw.split(separator: ",").compactMap { Int($0) })
    }

    private func save() {
        let raw = pinned.sorted().map(String.init).joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: Self.storageKey)
    }
}
