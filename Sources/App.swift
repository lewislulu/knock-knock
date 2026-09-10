import AppKit
import SwiftUI
import Carbon

final class ReminderPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = CalendarMonitor()
    private let windowState = WindowState()
    private let design = DesignPreferences()
    private let agents = AgentIntegration()
    private let soundPlayer = ReminderSoundPlayer()
    private var nudgeTimer: Timer?
    private var nudgeCount = 0
    private var statusItem: NSStatusItem!
    private var mainWindow: NSWindow?
    private var reminderPanel: ReminderPanel?
    private var queue: [Meeting] = []
    private var previewActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: "knock-knock")
        statusItem.button?.image?.isTemplate = true
        monitor.onReminder = { [weak self] meetings in self?.present(meetings) }
        monitor.onRefresh = { [weak self] in self?.updateMenu(); self?.reconcileReminders() }
        design.onChange = { [weak self] in
            guard let self else { return }
            self.soundPlayer.stop()
            self.installMainMenu()
            self.updateMenu()
            if !self.queue.isEmpty { self.renderReminder(reposition: true) }
        }
        monitor.start()
        agents.canDeliver = { [weak self] in self?.monitor.canPresentAgentReminder == true }
        agents.onEvents = { [weak self] events in
            guard let self else { return }
            self.present(events.map { event in
                Meeting(id: "agent:" + event.id, title: L("%@ reply is ready", event.source.title),
                        start: event.createdAt, end: event.createdAt.addingTimeInterval(3600),
                        calendar: event.source.title, color: .systemTeal, location: "", joinURL: nil, agent: event)
            })
        }
        agents.start()
        agents.onPreferencesChanged = { [weak self] in
            guard let self else { return }
            if !self.agents.enabled { self.queue.removeAll { $0.agent != nil } }
            self.renderReminder()
        }
        agents.onPreview = { [weak self] source in
            guard let self, self.queue.isEmpty || self.previewActive else { return }
            self.previewActive = true
            let event = AgentEvent.demo(source)
            self.queue = [Meeting(id: "agent-preview", title: L("%@ reply is ready", source.title), start: event.createdAt,
                end: event.createdAt, calendar: source.title, color: .systemTeal, location: "", joinURL: nil, agent: event)]
            self.renderReminder(); self.playSound()
        }
        updateMenu()
        let loginLaunch = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if CommandLine.arguments.contains("--agents") { windowState.page = .agents }
        if !loginLaunch && !CommandLine.arguments.contains("--background") { showMain() }
        if CommandLine.arguments.contains("--preview") { showPreview() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMain()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func installMainMenu() {
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("About knock-knock"), action: #selector(showMain), keyEquivalent: "")
        appMenu.addItem(withTitle: L("Settings..."), action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Quit knock-knock"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let item = NSMenuItem(); item.submenu = appMenu; menu.addItem(item)
        let edit = NSMenu(title: L("Edit"))
        edit.addItem(withTitle: L("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem(); editItem.submenu = edit; menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    private func updateMenu() {
        let menu = NSMenu()
        let state = !monitor.hasAccess ? L("Calendar is not connected") : (monitor.paused ? L("Reminders paused") : L("Reminders on · %d min early", monitor.leadMinutes))
        menu.addItem(withTitle: state, action: nil, keyEquivalent: "")
        if let next = monitor.meetings.first {
            let title = String(next.title.prefix(45))
            menu.addItem(withTitle: "\(Localization.time(next.start))  \(title)", action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())
        addMenuItem(menu, "Upcoming", #selector(showUpcoming))
        addMenuItem(menu, "Playground", #selector(showPlayground))
        addMenuItem(menu, "AI Tasks", #selector(showAgents))
        addMenuItem(menu, "Preview Notice", #selector(showPreview))
        addMenuItem(menu, monitor.paused ? "Resume Reminders" : "Pause Reminders", #selector(togglePause))
        addMenuItem(menu, "Settings...", #selector(showSettings), key: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Quit knock-knock"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.toolTip = "knock-knock: \(state)"
        statusItem.button?.appearsDisabled = monitor.paused
    }

    private func addMenuItem(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let item = menu.addItem(withTitle: L(title), action: action, keyEquivalent: key)
        item.target = self
    }

    @objc private func showMain() {
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1020, height: 790),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "knock-knock"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 900, height: 650)
            window.contentView = NSHostingView(rootView: MainView(monitor: monitor, state: windowState, design: design, agents: agents,
                preview: { [weak self] in self?.showPreview() }, testSound: { [weak self] in self?.playSound() }))
            window.center()
            mainWindow = window
        }
        monitor.refresh()
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func showSettings() { windowState.page = .settings; showMain() }
    @objc private func showPlayground() { windowState.page = .playground; showMain() }
    @objc private func showAgents() { windowState.page = .agents; agents.refreshConnections(); showMain() }
    @objc private func showUpcoming() { windowState.page = .upcoming; showMain() }
    @objc private func togglePause() { monitor.paused.toggle(); updateMenu() }

    @objc private func showPreview() {
        guard queue.isEmpty || previewActive else { reminderPanel?.orderFrontRegardless(); return }
        previewActive = true
        queue = [.preview]
        renderReminder()
        reminderPanel?.makeKeyAndOrderFront(nil)
        playSound()
    }

    private func present(_ meetings: [Meeting]) {
        if previewActive { queue = []; previewActive = false }
        let existing = Set(queue.map(\.id))
        queue.append(contentsOf: meetings.filter { !existing.contains($0.id) })
        queue.sort { $0.start < $1.start }
        renderReminder()
        playSound()
        scheduleNudges()
    }

    private func reconcileReminders() {
        guard !previewActive, !queue.isEmpty else { return }
        let current = Dictionary(uniqueKeysWithValues: monitor.meetings.map { ($0.id, $0) })
        let updated = queue.compactMap { $0.agent == nil ? current[$0.id] : $0 }
        if queue != updated { queue = updated; renderReminder() }
    }

    private func renderReminder(reposition: Bool = false) {
        guard let meeting = queue.first else { reminderPanel?.orderOut(nil); nudgeTimer?.invalidate(); soundPlayer.stop(); return }
        if reminderPanel == nil {
            let panel = ReminderPanel(contentRect: .zero, styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false
            panel.isFloatingPanel = true
            panel.isMovableByWindowBackground = true
            panel.hasShadow = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.isReleasedWhenClosed = false
            panel.title = L("knock-knock Reminder")
            reminderPanel = panel
        }
        guard let panel = reminderPanel else { return }
        panel.contentView = NSHostingView(rootView: ReminderView(meeting: meeting, count: queue.count,
            isPreview: previewActive, design: design, dismiss: { [weak self] in self?.advanceReminder(snoozing: false) },
            snooze: { [weak self] in self?.advanceReminder(snoozing: true) },
            showAgentSummary: agents.showSummaries,
            openAgent: { [weak self] in self?.agents.openSession($0) ?? false },
            resumeAgent: { [weak self] in self?.agents.openTerminal($0) ?? false }).ignoresSafeArea())
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let size = design.theme.panelSize
        let width = min(size.width, bounds.width - 40), height = min(size.height, bounds.height - 40)
        if !panel.isVisible || reposition {
            let x = design.theme == .cat ? bounds.maxX - width - 20 : bounds.midX - width / 2
            let y = design.theme == .banner ? bounds.maxY - height - 14 : (design.theme == .cat ? bounds.minY + 20 : bounds.midY - height / 2)
            panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }
        panel.title = L("knock-knock Reminder")
        panel.orderFrontRegardless()
    }

    private func advanceReminder(snoozing: Bool) {
        guard let meeting = queue.first else { return }
        if snoozing && !previewActive && meeting.agent == nil { monitor.snooze(meeting) }
        queue.removeFirst()
        previewActive = false
        renderReminder()
    }

    private func playSound() {
        guard monitor.soundEnabled else { return }
        if !soundPlayer.play(design) { monitor.error = L("Could not play the reminder sound.") }
    }

    private func scheduleNudges() {
        nudgeTimer?.invalidate()
        nudgeCount = 0
        guard !previewActive else { return }
        nudgeTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.queue.isEmpty else { return }
                let allowed = self.queue.first?.agent == nil ? self.monitor.canPresentReminder : self.monitor.canPresentAgentReminder
                guard self.design.repeatNudge, !self.monitor.paused, allowed else { return }
                guard self.nudgeCount < 3 else { self.nudgeTimer?.invalidate(); return }
                self.nudgeCount += 1
                self.playSound()
            }
        }
    }
}

@main
struct KnockKnockApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
