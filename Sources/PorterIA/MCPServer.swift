import Foundation
import Network

/// Embedded MCP server exposing PorterIA's port intelligence to AI agents
/// over JSON-RPC 2.0 / HTTP.
///
/// Wire format follows the Model Context Protocol "Streamable HTTP" transport
/// (subset: POST /mcp accepting JSON-RPC requests, returning JSON-RPC responses).
/// Server-initiated SSE messages are NOT implemented — tools are pull-only.
///
/// Configure in Claude Desktop / Codex:
/// ```
/// "mcpServers": {
///   "porteria": { "type": "http", "url": "http://localhost:9876/mcp" }
/// }
/// ```
@MainActor
final class MCPServer: ObservableObject {
    @Published private(set) var isRunning: Bool = false
    @Published var port: UInt16 = 9876
    @Published var lastError: String?

    weak var store: PortStore?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.jvdias.PorterIA.mcp")

    func start() {
        guard !isRunning else { return }
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            lastError = "invalid port \(port)"
            return
        }
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            // Bind to localhost only — never expose to LAN.
            params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: nwPort)
            let l = try NWListener(using: params, on: nwPort)
            l.newConnectionHandler = { [weak self] conn in
                self?.handle(conn)
            }
            l.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.lastError = nil
                    case .failed(let e):
                        self?.isRunning = false
                        self?.lastError = "failed: \(e.localizedDescription)"
                    case .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            l.start(queue: queue)
            listener = l
        } catch {
            lastError = "could not bind :\(port) — \(error.localizedDescription)"
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    // MARK: - Connection handling

    nonisolated private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        receive(on: conn, buffer: Data())
    }

    /// Reads from the connection until we have a complete HTTP request,
    /// dispatches, writes a response, then closes the connection.
    /// Nonisolated because Network.framework callbacks fire on background queues.
    nonisolated private func receive(on conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            var buf = buffer
            if let data = data { buf.append(data) }
            if error != nil { conn.cancel(); return }

            if let (method, path, body) = Self.parseHTTPRequest(buf) {
                Task { @MainActor in
                    let response = self.dispatch(method: method, path: path, body: body)
                    Self.send(response, on: conn)
                }
            } else if isComplete {
                Self.send(Self.httpResponse(status: 400, body: "{}"), on: conn)
            } else {
                self.receive(on: conn, buffer: buf)
            }
        }
    }

    nonisolated static func send(_ data: Data, on conn: NWConnection) {
        conn.send(content: data, completion: .contentProcessed { _ in
            conn.cancel()
        })
    }

    // MARK: - Minimal HTTP parser

    /// Returns (method, path, bodyBytes) if a complete request is buffered.
    /// Looks for "\r\n\r\n" terminator and respects Content-Length.
    nonisolated static func parseHTTPRequest(_ buf: Data) -> (method: String, path: String, body: Data)? {
        guard let headerEnd = buf.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = buf.subdata(in: 0..<headerEnd.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }
        let method = parts[0]
        let path = parts[1]

        // Find Content-Length
        var contentLength = 0
        for line in lines.dropFirst() {
            let lc = line.lowercased()
            if lc.hasPrefix("content-length:") {
                let val = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                contentLength = Int(val) ?? 0
            }
        }

        let bodyStart = headerEnd.upperBound
        let available = buf.count - bodyStart
        guard available >= contentLength else { return nil }
        let body = buf.subdata(in: bodyStart..<(bodyStart + contentLength))
        return (method, path, body)
    }

    nonisolated static func httpResponse(status: Int, body: String) -> Data {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 405: statusText = "Method Not Allowed"
        default:  statusText = "Status \(status)"
        }
        let bodyData = body.data(using: .utf8) ?? Data()
        var header = "HTTP/1.1 \(status) \(statusText)\r\n"
        header += "Content-Type: application/json\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "Content-Length: \(bodyData.count)\r\n"
        header += "Connection: close\r\n\r\n"
        var out = Data(header.utf8)
        out.append(bodyData)
        return out
    }

    // MARK: - JSON-RPC dispatch

    private func dispatch(method httpMethod: String, path: String, body: Data) -> Data {
        // Health check / discovery
        if httpMethod == "GET" && (path == "/" || path == "/health") {
            return Self.httpResponse(
                status: 200,
                body: #"{"name":"porteria","version":"0.9.0","mcp":"http://localhost:\#(port)/mcp"}"#
            )
        }

        guard httpMethod == "POST" && path == "/mcp" else {
            return Self.httpResponse(status: 404, body: #"{"error":"not found"}"#)
        }

        guard let req = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return jsonRpcError(id: nil, code: -32700, message: "parse error")
        }

        let id = req["id"]
        let rpcMethod = req["method"] as? String ?? ""
        let params = req["params"] as? [String: Any] ?? [:]

        switch rpcMethod {
        case "initialize":
            return jsonRpcResult(id: id, result: [
                "protocolVersion": "2024-11-05",
                "capabilities": ["tools": [:]],
                "serverInfo": ["name": "porteria", "version": "0.9.0"]
            ])

        case "notifications/initialized":
            // No-op notification; respond 200 with empty body per spec.
            return Self.httpResponse(status: 200, body: "")

        case "tools/list":
            return jsonRpcResult(id: id, result: ["tools": toolDefinitions()])

        case "tools/call":
            let name = params["name"] as? String ?? ""
            let args = params["arguments"] as? [String: Any] ?? [:]
            return handleToolCall(id: id, name: name, args: args)

        default:
            return jsonRpcError(id: id, code: -32601, message: "method not found: \(rpcMethod)")
        }
    }

    // MARK: - Tool definitions

    private func toolDefinitions() -> [[String: Any]] {
        [
            [
                "name": "list_ports",
                "description": "List all listening TCP ports on this machine. Each entry includes the port number, owning process command and PID, bind address (e.g. localhost, all interfaces), and — when detectable — the project name (from package.json, Cargo.toml, etc.) and the AI tool the process is recognized as (Ollama, Claude Code, Codex, LM Studio, etc.).",
                "inputSchema": ["type": "object", "properties": [:], "required": []]
            ],
            [
                "name": "find_port",
                "description": "Get full details for a specific port if it's currently bound.",
                "inputSchema": [
                    "type": "object",
                    "properties": ["port": ["type": "integer", "description": "Port number to look up (1-65535)."]],
                    "required": ["port"]
                ]
            ],
            [
                "name": "list_ai_tools",
                "description": "List AI dev tools currently active on this machine — both those listening on a port AND desktop apps (Claude Desktop, Codex Desktop) that talk over stdio. Returns the tool name, category (LLM server, agent, IDE extension, etc.), and PID for each.",
                "inputSchema": ["type": "object", "properties": [:], "required": []]
            ],
            [
                "name": "list_recently_freed",
                "description": "List ports that had a process within the last 5 minutes but are not currently bound. Helps spot dev servers that just died or were restarted on a different port.",
                "inputSchema": ["type": "object", "properties": [:], "required": []]
            ],
            [
                "name": "kill_port",
                "description": "Send SIGTERM to the process currently bound to a specific port. Returns success and the killed PID, or an error if no process owns that port.",
                "inputSchema": [
                    "type": "object",
                    "properties": ["port": ["type": "integer", "description": "Port number whose owning process should be killed."]],
                    "required": ["port"]
                ]
            ]
        ]
    }

    // MARK: - Tool implementations

    private func handleToolCall(id: Any?, name: String, args: [String: Any]) -> Data {
        switch name {
        case "list_ports":
            return jsonRpcResult(id: id, result: toolContent(jsonString(portsJSON())))

        case "find_port":
            guard let port = args["port"] as? Int else {
                return jsonRpcError(id: id, code: -32602, message: "missing 'port' argument")
            }
            let entries = store?.entries ?? []
            if let match = entries.first(where: { $0.port == port }) {
                return jsonRpcResult(id: id, result: toolContent(jsonString(portToDict(match))))
            } else {
                return jsonRpcResult(id: id, result: toolContent(jsonString([
                    "port": port,
                    "bound": false,
                    "message": "no process is currently listening on this port"
                ])))
            }

        case "list_ai_tools":
            return jsonRpcResult(id: id, result: toolContent(jsonString(aiToolsJSON())))

        case "list_recently_freed":
            let freed = (store?.recentlyFreed ?? []).map { entry -> [String: Any] in
                [
                    "port": entry.port,
                    "command": entry.command,
                    "project_name": entry.projectName as Any,
                    "seconds_since_freed": Int(Date().timeIntervalSince(entry.lastSeen))
                ]
            }
            return jsonRpcResult(id: id, result: toolContent(jsonString(["recently_freed": freed])))

        case "kill_port":
            guard let port = args["port"] as? Int else {
                return jsonRpcError(id: id, code: -32602, message: "missing 'port' argument")
            }
            let entries = store?.entries ?? []
            if let match = entries.first(where: { $0.port == port }) {
                let ok = ProcessKiller.terminate(pid: match.pid)
                store?.refresh()
                return jsonRpcResult(id: id, result: toolContent(jsonString([
                    "success": ok,
                    "killed_pid": Int(match.pid),
                    "killed_command": match.command,
                    "port": port
                ])))
            } else {
                return jsonRpcResult(id: id, result: toolContent(jsonString([
                    "success": false,
                    "port": port,
                    "error": "no process listening on this port"
                ])))
            }

        default:
            return jsonRpcError(id: id, code: -32602, message: "unknown tool: \(name)")
        }
    }

    private func portsJSON() -> [String: Any] {
        let ports = (store?.entries ?? []).map(portToDict)
        return ["ports": ports, "count": ports.count]
    }

    private func aiToolsJSON() -> [String: Any] {
        let withPort = (store?.entries ?? [])
            .compactMap { entry -> [String: Any]? in
                guard let tool = entry.aiTool else { return nil }
                return [
                    "name": tool.displayName,
                    "category": tool.category.rawValue,
                    "pid": Int(entry.pid),
                    "port": entry.port,
                    "command": entry.command
                ]
            }
        let withoutPort = (store?.aiProcessesWithoutPort ?? []).map { p -> [String: Any] in
            [
                "name": p.aiTool.displayName,
                "category": p.aiTool.category.rawValue,
                "pid": Int(p.pid),
                "port": NSNull(),
                "command": p.command
            ]
        }
        return ["ai_tools": withPort + withoutPort]
    }

    private func portToDict(_ entry: PortEntry) -> [String: Any] {
        var dict: [String: Any] = [
            "port": entry.port,
            "pid": Int(entry.pid),
            "command": entry.command,
            "user": entry.user,
            "bind": entry.bindLabel
        ]
        if let name = entry.projectName { dict["project_name"] = name }
        if let path = entry.projectPath { dict["project_path"] = path }
        if let tool = entry.aiTool {
            dict["ai_tool"] = ["name": tool.displayName, "category": tool.category.rawValue]
        }
        if let stats = entry.stats {
            dict["cpu_percent"] = stats.cpuPercent
            dict["memory_percent"] = stats.memPercent
        }
        return dict
    }

    // MARK: - JSON-RPC helpers

    private func toolContent(_ text: String) -> [String: Any] {
        ["content": [["type": "text", "text": text]]]
    }

    private func jsonString(_ obj: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    private func jsonRpcResult(id: Any?, result: [String: Any]) -> Data {
        var envelope: [String: Any] = ["jsonrpc": "2.0", "result": result]
        if let id = id { envelope["id"] = id }
        return Self.httpResponse(status: 200, body: jsonString(envelope))
    }

    private func jsonRpcError(id: Any?, code: Int, message: String) -> Data {
        var envelope: [String: Any] = [
            "jsonrpc": "2.0",
            "error": ["code": code, "message": message]
        ]
        if let id = id { envelope["id"] = id }
        return Self.httpResponse(status: 200, body: jsonString(envelope))
    }
}
