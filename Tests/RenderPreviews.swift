import AppKit
import SwiftUI

@main
struct RenderPreviews {
    @MainActor static func main() throws {
        precondition(Bundle.main.bundleIdentifier == "app.knockknock.visualtests")
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        defer { UserDefaults.standard.removePersistentDomain(forName: "app.knockknock.visualtests") }
        UserDefaults.standard.removePersistentDomain(forName: "app.knockknock.visualtests")
        let design = DesignPreferences()
        design.animated = false
        let monitor = CalendarMonitor()
        let state = WindowState()
        let titles = ["en": "Project kickoff: design, engineering, and launch planning",
                      "zh-Hans": "项目启动会：产品设计、工程协作与上线计划，一起对齐下一步",
                      "ja": "プロジェクト開始会議：デザイン・開発・リリース計画のすり合わせ"]
        for language in [AppLanguage.english, .chinese, .japanese] {
            design.language = language
            for theme in ReminderTheme.allCases {
                design.theme = theme
                let meeting = Meeting(id: "layout-test", title: titles[language.rawValue]!, start: Date().addingTimeInterval(300),
                    end: Date().addingTimeInterval(2100), calendar: "Demo calendar", color: .systemTeal,
                    location: "Demo studio", joinURL: URL(string: "https://example.com/meeting"))
                let size = theme.panelSize
                let root = ReminderView(meeting: meeting, count: 2, isPreview: false, design: design, dismiss: {}, snooze: {})
                    .frame(width: size.width, height: size.height)
                let renderer = ImageRenderer(content: root)
                renderer.scale = 1
                guard let image = renderer.nsImage, let data = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: data), let png = bitmap.representation(using: .png, properties: [:])
                else { fatalError("Failed to render \(theme.rawValue) \(language.rawValue)") }
                try png.write(to: output.appendingPathComponent("\(theme.rawValue)-\(language.rawValue).png"))
                precondition(bitmap.pixelsWide == Int(size.width) && bitmap.pixelsHigh == Int(size.height))
                if theme == .cat {
                    precondition((bitmap.colorAt(x: 1, y: 1)?.alphaComponent ?? 1) == 0, "Cat overlay must be transparent outside the art")
                }
                print("Rendered \(theme.rawValue) / \(language.rawValue)")
                for source in AgentSource.allCases {
                    let event = AgentEvent.demo(source)
                    let agentMeeting = Meeting(id: "agent-demo", title: L("%@ reply is ready", source.title),
                        start: event.createdAt, end: event.createdAt, calendar: source.title, color: .systemTeal,
                        location: "", joinURL: nil, agent: event)
                    let agentRoot = ReminderView(meeting: agentMeeting, count: 2, isPreview: false, design: design,
                        dismiss: {}, snooze: {}, openAgent: { _ in true }, resumeAgent: { _ in true })
                        .frame(width: size.width, height: size.height)
                    let agentRenderer = ImageRenderer(content: agentRoot)
                    agentRenderer.scale = 1
                    guard let agentImage = agentRenderer.nsImage, let agentData = agentImage.tiffRepresentation,
                          let agentBitmap = NSBitmapImageRep(data: agentData), let agentPNG = agentBitmap.representation(using: .png, properties: [:]) else { fatalError("Agent render failed") }
                    try agentPNG.write(to: output.appendingPathComponent("agent-\(source.rawValue)-\(theme.rawValue)-\(language.rawValue).png"))
                }
            }
            design.theme = .girl
            monitor.authorization = .fullAccess
            monitor.meetings = [Meeting(id: "agenda-test", title: titles[language.rawValue]!, start: Date().addingTimeInterval(3600),
                end: Date().addingTimeInterval(7200), calendar: "Demo calendar", color: .systemTeal,
                location: "Demo studio", joinURL: URL(string: "https://example.com/meeting"))]
            monitor.calendars = [CalendarChoice(id: "one", title: "Demo calendar", source: "Demo account", color: .systemTeal),
                                 CalendarChoice(id: "two", title: "Demo projects", source: "Demo account", color: .systemPink)]
            for width in [900.0, 1020.0] {
                for page in AppPage.allCases {
                    state.page = page
                    let root = MainView(monitor: monitor, state: state, design: design, preview: {}, testSound: {})
                        .frame(width: width, height: 790)
                    try save(root, to: output.appendingPathComponent("app-\(page.rawValue)-\(language.rawValue)-\(Int(width)).png"))
                }
            }
            state.page = .upcoming
            monitor.meetings = []
            try save(MainView(monitor: monitor, state: state, design: design, preview: {}, testSound: {}).frame(width: 1020, height: 790),
                     to: output.appendingPathComponent("empty-\(language.rawValue).png"))
            monitor.authorization = .notDetermined
            try save(MainView(monitor: monitor, state: state, design: design, preview: {}, testSound: {}).frame(width: 1020, height: 790),
                     to: output.appendingPathComponent("connection-\(language.rawValue).png"))
        }
        let poses = HStack(spacing: 20) {
            ForEach([0.0, 1.0], id: \.self) { phase in
                VStack {
                    SpriteView(sprite: .girl, knockPhase: phase).frame(width: 200, height: 200)
                    SpriteView(sprite: .agent, knockPhase: phase).frame(width: 200, height: 200)
                }
            }
        }.padding(20).background(.white)
        try save(poses, to: output.appendingPathComponent("character-poses.png"))
    }

    @MainActor private static func save<V: View>(_ view: V, to url: URL) throws {
        // ImageRenderer omits AppKit-backed scroll views. Cache an attached native view instead.
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("No bitmap") }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("No PNG") }
        try png.write(to: url)
        window.close()
        print("Rendered \(url.lastPathComponent)")
    }
}
