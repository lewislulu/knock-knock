import Foundation
import CryptoKit

enum AgentSource: String, Codable, CaseIterable, Identifiable {
    case codex, claude
    var id: String { rawValue }
    var title: String { self == .codex ? "Codex" : "Claude Code" }
}

struct AgentEvent: Codable, Equatable, Identifiable {
    let id: String
    let source: AgentSource
    let sessionID: String
    let project: String
    let directory: String
    let summary: String
    let createdAt: Date

    static func validSession(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.range(of: "^[A-Za-z0-9][A-Za-z0-9_-]*$", options: .regularExpression) != nil
    }

    static func parse(_ data: Data, source: AgentSource, includeSummary: Bool, now: Date = Date()) throws -> AgentEvent? {
        guard data.count <= 1_048_576,
              let input = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AgentError.invalidPayload }
        let legacy = source == .codex && input["type"] as? String == "agent-turn-complete"
        guard legacy || input["hook_event_name"] as? String == "Stop" else { return nil }
        // Main-agent completion only. No transcript files or user prompts are read.
        guard input["agent_id"] == nil else { return nil }
        guard let session = input[legacy ? "thread-id" : "session_id"] as? String, validSession(session) else { throw AgentError.invalidPayload }
        let cwd = input["cwd"] as? String ?? ""
        guard cwd.utf8.count <= 4096, !cwd.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              cwd.isEmpty || cwd.hasPrefix("/") else { throw AgentError.invalidPayload }
        let message = input[legacy ? "last-assistant-message" : "last_assistant_message"] as? String ?? ""
        let turn = input[legacy ? "turn-id" : "turn_id"] as? String
        let identity = [source.rawValue, session, turn ?? UUID().uuidString].joined(separator: ":")
        let id = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
        return AgentEvent(id: id, source: source, sessionID: session,
            project: String(URL(fileURLWithPath: cwd).lastPathComponent.prefix(100)), directory: cwd,
            summary: includeSummary ? cleanSummary(message) : "", createdAt: now)
    }

    static func cleanSummary(_ value: String) -> String {
        String(value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) || $0 == "\n" }
            .map(String.init).joined().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").prefix(240))
    }

    var isValid: Bool {
        id.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil && Self.validSession(sessionID)
        && directory.utf8.count <= 4096 && (directory.isEmpty || directory.hasPrefix("/"))
        && !directory.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        && project.count <= 100 && summary.count <= 240
    }

    var codexURL: URL? { source == .codex ? URL(string: "codex://threads/\(sessionID)") : nil }
    static func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    var resumeCommand: String {
        let command = source == .codex ? "codex resume" : "claude --resume"
        let changeDirectory = directory.isEmpty ? "" : "cd -- \(Self.shellQuote(directory)) && "
        return changeDirectory + command + " " + Self.shellQuote(sessionID)
    }

    static func demo(_ source: AgentSource) -> AgentEvent {
        .init(id: String(repeating: source == .codex ? "a" : "b", count: 64), source: source,
              sessionID: "00000000-0000-4000-8000-000000000001", project: "Demo project", directory: "",
              summary: "", createdAt: Date())
    }
}

enum AgentError: Error { case invalidPayload, unsafeFile, invalidConfiguration, missingHelper }

enum AgentInbox {
    static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("knock-knock/AgentInbox", isDirectory: true)
    }
    static func prepare(_ root: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let attrs = try fm.attributesOfItem(atPath: root.path)
        guard attrs[.type] as? FileAttributeType == .typeDirectory,
              attrs[.ownerAccountID] as? UInt32 == getuid() else { throw AgentError.unsafeFile }
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
    }
    static func write(_ event: AgentEvent, root: URL = root) throws {
        guard event.isValid else { throw AgentError.invalidPayload }
        try prepare(root)
        let url = root.appendingPathComponent(event.id + ".json")
        let data = try JSONEncoder().encode(event)
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    static func take(root: URL = root, now: Date = Date()) throws -> [AgentEvent] {
        try prepare(root)
        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var events: [AgentEvent] = []
        for file in files.prefix(100) {
            defer { try? fm.removeItem(at: file) }
            guard let attrs = try? fm.attributesOfItem(atPath: file.path),
                  attrs[.type] as? FileAttributeType == .typeRegular,
                  attrs[.ownerAccountID] as? UInt32 == getuid(),
                  let size = attrs[.size] as? Int, size < 16_384,
                  let data = try? Data(contentsOf: file), let event = try? JSONDecoder().decode(AgentEvent.self, from: data),
                  event.isValid, event.id + ".json" == file.lastPathComponent,
                  now.timeIntervalSince(event.createdAt) >= -60, now.timeIntervalSince(event.createdAt) < 3600 else { continue }
            events.append(event)
        }
        return events.sorted { $0.createdAt < $1.createdAt }
    }
}
