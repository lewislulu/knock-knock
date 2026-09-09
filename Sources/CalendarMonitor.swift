import AppKit
import Combine
import EventKit
import ServiceManagement

struct CalendarChoice: Identifiable {
    let id: String
    let title: String
    let source: String
    let color: NSColor
}

struct Meeting: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let calendar: String
    let color: NSColor
    let location: String
    let joinURL: URL?
    var candidate: ReminderCandidate { .init(id: id, start: start, end: end) }

    static var preview: Meeting {
        .init(id: "preview", title: L("Your next meeting"), start: Date().addingTimeInterval(300),
              end: Date().addingTimeInterval(2100), calendar: L("Preview"), color: .systemTeal,
              location: "", joinURL: nil)
    }
}

@MainActor
final class CalendarMonitor: ObservableObject {
    @Published var meetings: [Meeting] = []
    @Published var calendars: [CalendarChoice] = []
    @Published var authorization = EKEventStore.authorizationStatus(for: .event)
    @Published var error: String?
    @Published var requestingAccess = false
    @Published var lastRefresh: Date?
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    @Published var leadMinutes: Int { didSet { defaults.set(leadMinutes, forKey: "leadMinutes"); evaluate() } }
    @Published var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: "soundEnabled") } }
    @Published var paused: Bool { didSet { defaults.set(paused, forKey: "paused"); if !paused { refresh() } } }
    @Published var excludedCalendars: Set<String> {
        didSet { defaults.set(Array(excludedCalendars), forKey: "excludedCalendars"); refresh() }
    }

    var onReminder: (([Meeting]) -> Void)?
    var onRefresh: (() -> Void)?
    private let store = EKEventStore()
    private let defaults: UserDefaults
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var delivered: [String: Date]
    private var snoozed: [String: Date]
    private var refreshing = false
    private var activity: NSObjectProtocol?
    private var screenLocked = false
    var hasAccess: Bool { authorization == .fullAccess }
    var canPresentReminder: Bool { hasAccess && !screenLocked }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedLead = defaults.integer(forKey: "leadMinutes")
        leadMinutes = [1, 3, 5, 10, 15, 30].contains(savedLead) ? savedLead : 5
        soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        paused = defaults.bool(forKey: "paused")
        excludedCalendars = Set(defaults.stringArray(forKey: "excludedCalendars") ?? [])
        delivered = defaults.dictionary(forKey: "delivered") as? [String: Date] ?? [:]
        snoozed = defaults.dictionary(forKey: "snoozed") as? [String: Date] ?? [:]
    }

    func start() {
        // App Nap must not defer a menu-bar-only app's reminder timer.
        activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
                                                        reason: "Check upcoming calendar reminders")
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        observers.append(NotificationCenter.default.addObserver(forName: .EKEventStoreChanged,
                          object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name,
                              object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        for name in ["com.apple.screenIsLocked", "com.apple.screenIsUnlocked"] {
            observers.append(DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name(name), object: nil, queue: .main) { [weak self] note in
                    let locked = note.name.rawValue == "com.apple.screenIsLocked"
                    Task { @MainActor in self?.screenLocked = locked; self?.refresh() }
                })
        }
        refresh()
    }

    func requestAccess() {
        requestingAccess = true
        error = nil
        store.requestFullAccessToEvents { [weak self] _, accessError in
            Task { @MainActor in
                self?.requestingAccess = false
                self?.error = accessError?.localizedDescription
                self?.refresh()
            }
        }
    }

    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false; onRefresh?() }
        authorization = EKEventStore.authorizationStatus(for: .event)
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
        guard hasAccess else { meetings = []; calendars = []; return }
        let sources = store.calendars(for: .event)
        calendars = sources.map {
            CalendarChoice(id: $0.calendarIdentifier, title: $0.title, source: $0.source.title,
                           color: NSColor(cgColor: $0.cgColor) ?? .systemTeal)
        }.sorted { ($0.source, $0.title) < ($1.source, $1.title) }
        let selected = sources.filter { !excludedCalendars.contains($0.calendarIdentifier) }
        let now = Date()
        if selected.isEmpty {
            meetings = []
        } else {
            let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-180),
                end: now.addingTimeInterval(7 * 86400), calendars: selected)
            var seen: Set<String> = []
            meetings = store.events(matching: predicate).compactMap { event -> Meeting? in
                guard !event.isAllDay, event.status != .canceled, event.endDate > now,
                      event.startDate >= now.addingTimeInterval(-180),
                      !(event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false)
                else { return nil }
                let identifier = event.calendarItemIdentifier + ":" + String(Int(event.startDate.timeIntervalSince1970))
                guard seen.insert(identifier).inserted else { return nil }
                return Meeting(id: identifier, title: event.title?.isEmpty == false ? event.title : L("Untitled event"),
                    start: event.startDate, end: event.endDate, calendar: event.calendar.title,
                    color: NSColor(cgColor: event.calendar.cgColor) ?? .systemTeal,
                    location: event.location ?? "", joinURL: Self.meetingURL(event))
            }.sorted { $0.start < $1.start }
        }
        lastRefresh = now
        delivered = delivered.filter { $0.value > now.addingTimeInterval(-7 * 86400) }
        let validIDs = Set(meetings.map(\.id))
        snoozed = snoozed.filter { validIDs.contains($0.key) }
        persist()
        evaluate()
    }

    func evaluate() {
        guard hasAccess, !paused, !screenLocked else { return }
        let now = Date()
        let due = meetings.filter {
            ReminderPolicy.isDue($0.candidate, now: now, leadMinutes: leadMinutes,
                                 delivered: Set(delivered.keys), snoozed: snoozed)
        }
        guard !due.isEmpty, let onReminder else { return }
        for meeting in due { delivered[meeting.id] = now; snoozed.removeValue(forKey: meeting.id) }
        persist()
        onReminder(due)
    }

    func snooze(_ meeting: Meeting) {
        guard let target = ReminderPolicy.snoozeDate(start: meeting.start, now: Date()) else { return }
        snoozed[meeting.id] = target
        persist()
    }

    func setCalendar(_ id: String, enabled: Bool) {
        if enabled { excludedCalendars.remove(id) } else { excludedCalendars.insert(id) }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch { self.error = L("Launch at login") + ": " + error.localizedDescription }
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
    }

    private func persist() {
        defaults.set(delivered, forKey: "delivered")
        defaults.set(snoozed, forKey: "snoozed")
    }

    private static func meetingURL(_ event: EKEvent) -> URL? {
        let text = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }.joined(separator: "\n")
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let providers = ["zoom.us", "zoom.com", "meet.google.com", "teams.microsoft.com", "teams.live.com", "teams.cloud.microsoft", "webex.com", "whereby.com"]
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap(\.url).first { url in
            guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
            return providers.contains { host == $0 || host.hasSuffix("." + $0) }
        }
    }
}
