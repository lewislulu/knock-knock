import Foundation
import AppKit

@main struct AgentIntegrationTests {
    static func check(_ condition: @autoclosure () throws -> Bool) rethrows {
        let result = try condition()
        precondition(result)
    }
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("knock-tests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try AgentInbox.prepare(root)
        let now = Date()
        let session = "00000000-0000-4000-8000-000000000001"
        let payload: [String: Any] = ["hook_event_name": "Stop", "session_id": session, "turn_id": "turn-1",
                                     "cwd": "/tmp/demo project", "last_assistant_message": "Done.\nAll tests passed.",
                                     "transcript_path": "/never/read/this", "input-messages": ["PRIVATE PROMPT"]]
        func data(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) }
        let event = try AgentEvent.parse(data(payload), source: .codex, includeSummary: false, now: now)!
        precondition(event.summary.isEmpty && event.project == "demo project")
        let serialized = String(data: try JSONEncoder().encode(event), encoding: .utf8)!
        precondition(!serialized.contains("PRIVATE") && !serialized.contains("transcript") && !serialized.contains("All tests"))
        let withSummary = try AgentEvent.parse(data(payload), source: .codex, includeSummary: true, now: now)!
        precondition(withSummary.summary == "Done. All tests passed.")
        precondition(withSummary.id == event.id)
        var next = payload; next["turn_id"] = "turn-2"
        try check(try AgentEvent.parse(data(next), source: .codex, includeSummary: false)!.id != event.id)
        let legacy = ["type": "agent-turn-complete", "thread-id": session, "turn-id": "turn-1", "cwd": "/tmp/demo project"]
        try check(try AgentEvent.parse(data(legacy), source: .codex, includeSummary: false)!.id == event.id)
        var subagent = payload; subagent["agent_id"] = "child"
        try check(try AgentEvent.parse(data(subagent), source: .codex, includeSummary: false) == nil)
        for eventName in ["PreToolUse", "SubagentStop", "SessionEnd", "StopFailure", "Interrupt"] {
            var input = payload; input["hook_event_name"] = eventName
            try check(try AgentEvent.parse(data(input), source: .claude, includeSummary: false) == nil)
        }
        for bad in [";touch /tmp/pwned", "../session", "--help", "session\nnext", ""] {
            var input = payload; input["session_id"] = bad
            do { _ = try AgentEvent.parse(data(input), source: .codex, includeSummary: false); fatalError("Accepted unsafe session") }
            catch AgentError.invalidPayload { }
        }
        precondition(event.codexURL!.absoluteString == "codex://threads/" + session)
        let tricky = AgentEvent(id: event.id, source: .claude, sessionID: session,
            project: "demo", directory: "/tmp/a'b $(touch nope); spaces", summary: "", createdAt: now)
        precondition(tricky.resumeCommand == "cd -- '/tmp/a'\\''b $(touch nope); spaces' && claude --resume '" + session + "'")
        print("PASS: hook schemas, turn identity, privacy defaults, event filtering, session validation, and quoted resume commands")

        let inbox = root.appendingPathComponent("inbox")
        try AgentInbox.write(event, root: inbox)
        try AgentInbox.write(event, root: inbox)
        try check(try AgentInbox.take(root: inbox, now: now).count == 1)
        try check(try AgentInbox.take(root: inbox, now: now).isEmpty)
        try AgentInbox.write(event, root: inbox)
        try check(try AgentInbox.take(root: inbox, now: now.addingTimeInterval(3601)).isEmpty)
        let target = root.appendingPathComponent("untouched")
        try Data("private".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: inbox.appendingPathComponent("bad.json"), withDestinationURL: target)
        try check(try AgentInbox.take(root: inbox).isEmpty)
        try check(try String(contentsOf: target, encoding: .utf8) == "private")
        let permissions = try FileManager.default.attributesOfItem(atPath: inbox.path)[.posixPermissions] as! Int
        precondition(permissions == 0o700)
        print("PASS: local inbox delivery, duplicate files, consumption, expiration, symlink rejection, and directory permissions")

        let helper = URL(fileURLWithPath: "/Applications/knock-knock.app/Contents/Resources/knock-notify")
        let existing: [String: Any] = ["other": "keep", "hooks": ["Stop": [["hooks": [["type": "command", "command": "existing-hook"]]]], "SessionStart": []]]
        let configured = try AgentHooks.update(data(existing), source: .codex, helper: helper, install: true)
        let again = try AgentHooks.update(configured, source: .codex, helper: helper, install: true)
        precondition(configured == again)
        let removed = try AgentHooks.update(configured, source: .codex, helper: helper, install: false)
        let restored = try JSONSerialization.jsonObject(with: removed) as! NSDictionary
        precondition(restored == existing as NSDictionary)
        do { _ = try AgentHooks.update(Data("not json".utf8), source: .claude, helper: helper, install: true); fatalError("Overwrote invalid config") } catch { }
        print("PASS: hook merging preserves other settings, installs idempotently, removes only own handler, rejects invalid configuration")

        let suite = "app.knockknock.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let integration = AgentIntegration(defaults: defaults, inbox: inbox)
        var canDeliver = false
        var received: [AgentEvent] = []
        integration.canDeliver = { canDeliver }
        integration.onEvents = { received += $0 }
        try AgentInbox.write(event, root: inbox)
        integration.poll()
        precondition(received.isEmpty)
        precondition(integration.receivedSources == [.codex])
        canDeliver = true
        integration.poll()
        precondition(received.count == 1)
        try AgentInbox.write(event, root: inbox)
        integration.poll()
        precondition(received.count == 1)
        let restarted = AgentIntegration(defaults: defaults, inbox: inbox)
        restarted.canDeliver = { true }; restarted.onEvents = { received += $0 }
        try AgentInbox.write(event, root: inbox); restarted.poll()
        precondition(received.count == 1)
        integration.enabled = false
        try AgentInbox.write(AgentEvent.parse(data(next), source: .codex, includeSummary: false)!, root: inbox)
        integration.poll(); integration.enabled = true; integration.poll()
        precondition(received.count == 1)
        print("PASS: pause/lock gating, deferred delivery, duplicate suppression across restart, and disabled reminders")

        if CommandLine.arguments.count > 1 {
            let executable = URL(fileURLWithPath: CommandLine.arguments[1])
            let config = root.appendingPathComponent("hooks.json")
            try data(existing).write(to: config)
            try AgentHooks.set(.codex, helper: executable, at: config, install: true)
            precondition(AgentHooks.isInstalled(.codex, helper: executable, at: config))
            try AgentHooks.set(.codex, helper: executable, at: config, install: false)
            precondition(!AgentHooks.isInstalled(.codex, helper: executable, at: config))
            let backups = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.pathExtension == "bak" }
            precondition(backups.count == 2)
            for file in backups + [config] {
                try check(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as! Int == 0o600)
            }
            try Data("invalid".utf8).write(to: config)
            do { try AgentHooks.set(.codex, helper: executable, at: config, install: true); fatalError("Replaced invalid config") } catch { }
            try check(try String(contentsOf: config, encoding: .utf8) == "invalid")
            print("PASS: actual config install/disconnect, private backups, file permissions, and malformed-file preservation")
            for source in AgentSource.allCases {
                let process = Process(); process.executableURL = executable; process.arguments = ["--source", source.rawValue]
                process.environment = ProcessInfo.processInfo.environment.merging(["KNOCK_TEST_INBOX": inbox.path]) { _, new in new }
                let input = Pipe(), output = Pipe()
                process.standardInput = input; process.standardOutput = output
                try process.run()
                let encoded = try data(payload)
                // Separate pipe writes exercise streaming input, not only a single read.
                input.fileHandleForWriting.write(encoded.prefix(10))
                input.fileHandleForWriting.write(encoded.dropFirst(10))
                try input.fileHandleForWriting.close()
                process.waitUntilExit()
                precondition(process.terminationStatus == 0)
                let response = output.fileHandleForReading.readDataToEndOfFile()
                try check(try JSONSerialization.jsonObject(with: response) as! NSDictionary == [:])
                let received = try AgentInbox.take(root: inbox)
                precondition(received.count == 1 && received[0].sessionID == session && received[0].source == source)
            }
            print("PASS: both native hook subprocesses deliver JSON through stdin to the inbox and return nonblocking JSON")
        }
    }
}
