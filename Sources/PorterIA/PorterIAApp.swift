import SwiftUI

@main
struct PorterIAApp: App {
    @StateObject private var store = PortStore()

    var body: some Scene {
        MenuBarExtra("PorterIA", systemImage: "network") {
            PortListView(store: store)
                .onAppear { store.startAutoRefresh() }
        }
        .menuBarExtraStyle(.window)
    }
}
