import Foundation

struct ReminderCandidate {
    let id: String
    let start: Date
    let end: Date
}

enum ReminderPolicy {
    static func isDue(_ event: ReminderCandidate, now: Date, leadMinutes: Int,
                      delivered: Set<String>, snoozed: [String: Date]) -> Bool {
        guard event.end > now, event.start >= now.addingTimeInterval(-180) else { return false }
        if let until = snoozed[event.id] { return until <= now }
        return !delivered.contains(event.id)
            && event.start <= now.addingTimeInterval(Double(leadMinutes) * 60)
    }

    static func snoozeDate(start: Date, now: Date) -> Date? {
        let target = min(now.addingTimeInterval(60), start)
        return target.timeIntervalSince(now) >= 5 ? target : nil
    }
}
