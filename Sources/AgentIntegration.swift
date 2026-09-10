import AppKit
import Combine

enum AgentHooks {
    static func configURL(_ source: AgentSource) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        if source == .codex {
            let root = ProcessInfo.processInfo.environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent(".codex")
            return root.appendingPathComponent("hooks.json")
        }
        let root = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"].map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent(".claude")
        return root.appendingPathComponent("settings.json")
    }

    static func command(_ source: AgentSource, helper: URL) -> String {
        AgentEvent.shellQuote(helper.path) + " --source " + source.rawValue
    }

    static func update(_ data: Data?, source: AgentSource, helper: URL, install: Bool) throws -> Data {
        var object: [String: Any] = [:]
        if let data {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AgentError.invalidConfiguration }
            object = parsed
        }
        guard object["hooks"] == nil || object["hooks"] is [String: Any] else { throw AgentError.invalidConfiguration }
        var hooks = object["hooks"] as? [String: Any] ?? [:]
        guard hooks["Stop"] == nil || hooks["Stop"] is [[String: Any]] else { throw AgentError.invalidConfiguration }
        var groups = hooks["Stop"] as? [[String: Any]] ?? []
        let cmd = command(source, helper: helper)
        groups = groups.compactMap { group in
            guard let handlers = group["hooks"] as? [[String: Any]] else { return group }
            let remaining = handlers.filter { ($0["command"] as? String) != cmd }
            guard !remaining.isEmpty else { return nil }
            var result = group; result["hooks"] = remaining; return result
        }
        if install { groups.append(["hooks": [["type": "command", "command": cmd, "timeout": 5]]]) }
        if groups.isEmpty { hooks.removeValue(forKey: "Stop") } else { hooks["Stop"] = groups }
        object["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    static func isInstalled(_ source: AgentSource, helper: URL, at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = object["hooks"] as? [String: Any], let groups = hooks["Stop"] as? [[String: Any]] else { return false }
        return groups.contains { group in
            (group["hooks"] as? [[String: Any]] ?? []).contains { $0["command"] as? String == command(source, helper: helper) }
        }
    }

    static func set(_ source: AgentSource, helper: URL, at url: URL, install: Bool) throws {
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: helper.path) else { throw AgentError.missingHelper }
        let exists = fm.fileExists(atPath: url.path)
        if exists {
            let attrs = try fm.attributesOfItem(atPath: url.path)
            guard attrs[.type] as? FileAttributeType == .typeRegular else { throw AgentError.unsafeFile }
        }
        let old = exists ? try Data(contentsOf: url) : nil
        let updated = try update(old, source: source, helper: helper, install: install)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        if let old {
            let backup = url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + ".knock-knock-" + UUID().uuidString + ".bak")
            try old.write(to: backup, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        }
        try updated.write(to: url, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

@MainActor final class AgentIntegration: ObservableObject {
    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "agentEnabled"); onPreferencesChanged?() } }
    @Published var showSummaries: Bool { didSet { defaults.set(showSummaries, forKey: "agentSummaries"); onPreferencesChanged?() } }
    @Published var installed: Set<AgentSource> = []
    @Published var lastReceived: Date?
    @Published var error: String?
    var onEvents: (([AgentEvent]) -> Void)?
    var onPreview: ((AgentSource) -> Void)?
    var onPreferencesChanged: (() -> Void)?
    var canDeliver: (() -> Bool)?
    private let defaults: UserDefaults
    private var timer: Timer?
    private var delivered: [String: Date]
    private var waiting: [AgentEvent] = []
    private let inbox: URL
    var helper: URL? { Bundle.main.url(forResource: "knock-notify", withExtension: nil) }

    init(defaults: UserDefaults = .standard, inbox: URL = AgentInbox.root) {
        self.defaults = defaults
        self.inbox = inbox
        enabled = defaults.object(forKey: "agentEnabled") as? Bool ?? true
        showSummaries = defaults.bool(forKey: "agentSummaries")
        delivered = defaults.dictionary(forKey: "agentDelivered") as? [String: Date] ?? [:]
    }
    func start() {
        refreshConnections()
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }
    func refreshConnections() {
        guard let helper else { return }
        installed = Set(AgentSource.allCases.filter { AgentHooks.isInstalled($0, helper: helper, at: AgentHooks.configURL($0)) })
    }
    func connect(_ source: AgentSource) {
        guard let helper else { error = L("Integration helper is missing."); return }
        do {
            try AgentHooks.set(source, helper: helper, at: AgentHooks.configURL(source), install: !installed.contains(source))
            refreshConnections(); error = nil
        } catch { self.error = L("Could not update agent hooks. Check the configuration file and its permissions.") }
    }
    func poll() {
        do {
            let incoming = try AgentInbox.take(root: inbox)
            if !incoming.isEmpty { lastReceived = Date() }
            delivered = delivered.filter { Date().timeIntervalSince($0.value) < 86400 }
            for event in incoming where delivered[event.id] == nil {
                delivered[event.id] = Date()
                if enabled { waiting.append(event) }
            }
            defaults.set(delivered, forKey: "agentDelivered")
            waiting = Array(waiting.filter { Date().timeIntervalSince($0.createdAt) < 3600 }.suffix(30))
            guard enabled else { waiting.removeAll(); return }
            guard canDeliver?() == true, !waiting.isEmpty else { return }
            let batch = waiting; waiting.removeAll(); onEvents?(batch)
        } catch { self.error = L("Could not read local agent reminders.") }
    }

    func openSession(_ event: AgentEvent) -> Bool {
        if let url = event.codexURL, NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
            if NSWorkspace.shared.open(url) { return true }
        }
        return openTerminal(event)
    }
    func openTerminal(_ event: AgentEvent) -> Bool {
        guard event.isValid else { return false }
        do {
            let root = AgentInbox.root.deletingLastPathComponent().appendingPathComponent("Resume", isDirectory: true)
            try AgentInbox.prepare(root)
            let fm = FileManager.default
            let oldFiles = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey])
                .filter { $0.pathExtension == "command" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            for file in oldFiles.dropLast(29) { try? fm.removeItem(at: file) }
            let url = root.appendingPathComponent(event.id + ".command")
            let script = "#!/bin/zsh -l\n" + event.resumeCommand + "\n"
            try Data(script.utf8).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
            guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return false }
            NSWorkspace.shared.open([url], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
            return true
        } catch { return false }
    }
}
