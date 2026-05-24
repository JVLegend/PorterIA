import Foundation
import ServiceManagement

/// Wraps SMAppService.mainApp so the user can toggle "Launch at Login"
/// from the menu without leaving the app.
///
/// Requirements (already satisfied by our build pipeline):
/// - App must be signed with a Developer ID Application certificate.
/// - App must live in /Applications (Homebrew Cask installs there).
/// - macOS 13+ (we target 14+).
@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published var isEnabled: Bool = false
    /// True when SMAppService reports a state we cannot toggle from here
    /// (notFound / requiresApproval). UI should hide the toggle in that case.
    @Published var isManageable: Bool = true

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = (status == .enabled)
        isManageable = (status == .enabled || status == .notRegistered)
    }

    func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // Silent — refresh below reflects whatever the real state is.
        }
        refresh()
    }
}
