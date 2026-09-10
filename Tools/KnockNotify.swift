import Foundation
import AppKit

@main struct KnockNotify {
    static func main() {
        // A notifier must never block the agent's Stop hook or print conversation data.
        defer { print("{}") }
        let args = CommandLine.arguments
        guard args.count >= 3, args[1] == "--source", let source = AgentSource(rawValue: args[2]) else { return }
        do {
            let data: Data
            if args.count == 4 { data = Data(args[3].utf8) }
            else {
                var input = Data()
                while input.count <= 1_048_576 {
                    let part = try FileHandle.standardInput.read(upToCount: min(65536, 1_048_577 - input.count)) ?? Data()
                    if part.isEmpty { break }
                    input.append(part)
                }
                data = input
            }
            #if INTEGRATION_TESTING
            let defaults = UserDefaults(suiteName: "app.knockknock.helper-tests")!
            defaults.removePersistentDomain(forName: "app.knockknock.helper-tests")
            #else
            let defaults = UserDefaults(suiteName: "app.knockknock.mac")!
            #endif
            guard defaults.object(forKey: "agentEnabled") as? Bool ?? true else { return }
            guard let event = try AgentEvent.parse(data, source: source, includeSummary: defaults.bool(forKey: "agentSummaries")) else { return }
            #if INTEGRATION_TESTING
            if let path = ProcessInfo.processInfo.environment["KNOCK_TEST_INBOX"] {
                try AgentInbox.write(event, root: URL(fileURLWithPath: path))
                return
            }
            #endif
            try AgentInbox.write(event)
            guard NSRunningApplication.runningApplications(withBundleIdentifier: "app.knockknock.mac").isEmpty else { return }
            let helper = URL(fileURLWithPath: args[0]).resolvingSymlinksInPath()
            let app = helper.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            guard app.pathExtension == "app" else { return }
            let launch = Process()
            launch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            launch.arguments = ["-g", app.path, "--args", "--background"]
            launch.standardOutput = FileHandle.nullDevice
            launch.standardError = FileHandle.nullDevice
            try launch.run()
        } catch {
            // Fail open: notification delivery must not change an agent's control flow.
        }
    }
}
