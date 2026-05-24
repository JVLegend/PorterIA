import Foundation

struct PortEntry: Identifiable, Hashable {
    let id = UUID()
    let port: Int
    let pid: Int32
    let command: String
    let user: String
    /// Raw lsof name, e.g. "*:3000", "127.0.0.1:5432", "[::1]:8080".
    let bindAddress: String

    /// Human-friendly bind label: "all interfaces", "localhost", or the literal host.
    var bindLabel: String {
        let host = bindAddress.split(separator: ":").dropLast().joined(separator: ":")
        switch host {
        case "*", "":
            return "all interfaces"
        case "127.0.0.1", "[::1]", "::1":
            return "localhost"
        default:
            return String(host)
        }
    }
}
