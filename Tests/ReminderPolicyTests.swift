import Foundation

@main
struct ReminderPolicyTests {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var passed = 0
        func check(_ condition: Bool, _ name: String) {
            guard condition else { fatalError("FAIL: \(name)") }
            passed += 1
            print("PASS: \(name)")
        }
        func event(_ offset: Double, end: Double = 3600) -> ReminderCandidate {
            .init(id: "event", start: now.addingTimeInterval(offset), end: now.addingTimeInterval(end))
        }
        func due(_ event: ReminderCandidate, delivered: Set<String> = [], snoozed: [String: Date] = [:]) -> Bool {
            ReminderPolicy.isDue(event, now: now, leadMinutes: 5, delivered: delivered, snoozed: snoozed)
        }
        check(!due(event(301)), "No early reminder")
        check(due(event(300)), "Reminder at exact lead boundary")
        check(due(event(20)), "Catch event added shortly before start")
        check(!due(event(200), delivered: ["event"]), "No duplicate after restart")
        check(!due(event(200), delivered: ["event"], snoozed: ["event": now.addingTimeInterval(1)]), "Wait for snooze")
        check(due(event(200), delivered: ["event"], snoozed: ["event": now]), "Snooze overrides delivered state")
        check(due(event(-180)), "Wake catch-up within three minutes")
        check(!due(event(-181)), "No stale alerts after long sleep")
        check(!due(event(-20, end: -1)), "No reminder for ended event")
        check(ReminderPolicy.snoozeDate(start: now.addingTimeInterval(30), now: now) == now.addingTimeInterval(30), "Snooze cannot pass event start")
        check(ReminderPolicy.snoozeDate(start: now.addingTimeInterval(500), now: now) == now.addingTimeInterval(60), "One-minute snooze")
        check(ReminderPolicy.snoozeDate(start: now.addingTimeInterval(4), now: now) == nil, "Disable snooze at start")
        print("\(passed) reminder policy checks passed.")
    }
}
