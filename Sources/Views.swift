import SwiftUI
import ServiceManagement

enum AppPage: String, CaseIterable {
    case upcoming = "Upcoming", playground = "Playground", settings = "Settings"
    var symbol: String {
        switch self { case .upcoming: return "calendar"; case .playground: return "sparkles"; case .settings: return "slider.horizontal.3" }
    }
}
@MainActor final class WindowState: ObservableObject { @Published var page: AppPage = .playground }

struct MainView: View {
    @ObservedObject var monitor: CalendarMonitor
    @ObservedObject var state: WindowState
    @ObservedObject var design: DesignPreferences
    let preview: () -> Void
    let testSound: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    if let url = Bundle.main.url(forResource: "BrandMark", withExtension: "png"),
                       let mark = NSImage(contentsOf: url) {
                        Image(nsImage: mark).resizable().interpolation(.high).frame(width: 40, height: 40)
                    }
                    Text("knock-\nknock").font(.system(size: 19, weight: .bold, design: .rounded)).lineSpacing(0).fixedSize()
                }.padding(.top, 12).padding(.horizontal, 8)
                VStack(spacing: 6) {
                    ForEach(AppPage.allCases, id: \.self) { page in
                        Button { state.page = page } label: {
                            HStack(spacing: 10) {
                                Image(systemName: page.symbol).frame(width: 18)
                                Text(L(page.rawValue))
                            }.font(.system(size: 13, weight: state.page == page ? .semibold : .regular))
                                .foregroundStyle(state.page == page ? KnockUI.accent : .secondary)
                                .frame(maxWidth: .infinity, alignment: .leading).frame(height: 38).padding(.horizontal, 12)
                                .background(state.page == page ? KnockUI.accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Circle().fill(monitor.hasAccess && !monitor.paused ? KnockUI.accent : Color.orange).frame(width: 6, height: 6)
                        Text(L(monitor.paused ? "Reminders paused" : (monitor.hasAccess ? "Reminders on" : "Not connected"))).font(.system(size: 11, weight: .medium))
                    }
                    if !monitor.hasAccess {
                        Button(L("Connect Calendar")) { state.page = .upcoming }.buttonStyle(KnockButtonStyle())
                    }
                    Text(L("knock-knock for Mac")).font(.system(size: 10)).foregroundStyle(.tertiary)
                }.padding(.horizontal, 10).padding(.bottom, 6)
            }.padding(14).frame(width: 184).background(KnockUI.sidebar)
            Rectangle().fill(KnockUI.line).frame(width: 1)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L(state.page.rawValue)).font(.system(size: 23, weight: .semibold))
                        Text(state.page == .upcoming ? Localization.day(Date(), wide: true) : (state.page == .playground ? design.theme.title : L("Reminder preferences")))
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: preview) { Label(L("Preview notice"), systemImage: "play.fill") }
                        .buttonStyle(KnockButtonStyle(primary: true)).help(L("Preview a meeting reminder"))
                }.padding(.horizontal, KnockUI.inset).frame(height: 88)
                Divider()
                switch state.page {
                case .playground: PlaygroundView(monitor: monitor, design: design, preview: preview, testSound: testSound)
                case .settings: SettingsView(monitor: monitor, design: design)
                case .upcoming: if !monitor.hasAccess { connectionView } else { agendaView }
                }
                if let error = monitor.error {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(error).font(.system(size: 12)).textSelection(.enabled)
                        Spacer()
                        Button { monitor.error = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help(L("Dismiss error"))
                    }.padding(16).background(Color.orange.opacity(0.08))
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(nsColor: .textBackgroundColor))
        }.tint(KnockUI.accent).environment(\.locale, Localization.locale).frame(minWidth: 900, minHeight: 620)
    }
    private var connectionView: some View {
        VStack(spacing: 20) {
            Spacer()
            CharacterStage(theme: .cat, animated: design.animated).frame(width: 170, height: 150)
            Text(L("Calendar is not connected")).font(.system(size: 21, weight: .semibold))
            if monitor.authorization == .notDetermined {
                Button(action: monitor.requestAccess) {
                    if monitor.requestingAccess { ProgressView().controlSize(.small).frame(width: 150) }
                    else { Label(L("Connect Calendar"), systemImage: "calendar.badge.plus") }
                }.buttonStyle(KnockButtonStyle(primary: true)).disabled(monitor.requestingAccess)
            } else {
                Text(L(monitor.authorization == .restricted ? "Calendar access is restricted on this Mac." : "Calendar access is off.")).foregroundStyle(.secondary)
                Button(L("Calendar Privacy Settings"), action: monitor.openPrivacySettings).buttonStyle(KnockButtonStyle(primary: true))
            }
            Spacer()
            Text(L("%d min before each event", monitor.leadMinutes)).font(.system(size: 12)).foregroundStyle(.secondary).padding(.bottom, 25)
        }.frame(maxWidth: .infinity)
    }
    private var agendaView: some View {
        VStack(spacing: 0) {
            if monitor.paused {
                HStack {
                    Label(L("Reminders paused"), systemImage: "pause.circle").foregroundStyle(.orange)
                    Spacer(); Button(L("Resume")) { monitor.paused = false }.buttonStyle(KnockButtonStyle())
                }.padding(.horizontal, KnockUI.inset).padding(.vertical, 12).background(Color.orange.opacity(0.05))
                Divider()
            }
            if monitor.meetings.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    CharacterStage(theme: design.theme, animated: design.animated).frame(width: 150, height: 140)
                    Text(L("Nothing coming up")).font(.system(size: 21, weight: .semibold))
                    Text(L("No timed events in the next 7 days.")).font(.system(size: 13)).foregroundStyle(.secondary)
                    Button(L("Open Calendar"), action: openCalendar).buttonStyle(KnockButtonStyle())
                    Spacer()
                }.frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(monitor.meetings.enumerated()), id: \.element.id) { index, meeting in
                            if index == 0 || !Calendar.current.isDate(meeting.start, inSameDayAs: monitor.meetings[index - 1].start) {
                                Text(dayLabel(meeting.start)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).padding(.top, 24).padding(.bottom, 14)
                            }
                            HStack(alignment: .top, spacing: 15) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(Localization.time(meeting.start)).font(.system(size: 13, weight: .medium)).monospacedDigit()
                                    Text(Localization.time(meeting.end)).font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
                                }.frame(width: 80, alignment: .leading)
                                RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: meeting.color)).frame(width: 3, height: 44)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(meeting.title).font(.system(size: 15, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                                    Text(meeting.calendar).font(.system(size: 12)).foregroundStyle(.secondary)
                                    if !meeting.location.isEmpty && !meeting.location.hasPrefix("http") {
                                        Label(meeting.location, systemImage: "mappin").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                }
                                Spacer(minLength: 0)
                                if let url = meeting.joinURL {
                                    Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "video") }.buttonStyle(KnockIconStyle()).help(L("Join meeting"))
                                }
                            }.padding(.vertical, 18)
                            Divider()
                        }
                    }.padding(.horizontal, KnockUI.inset).padding(.bottom, 24)
                }
            }
            Divider()
            HStack {
                Text(L("%d min before each event", monitor.leadMinutes)).foregroundStyle(.secondary)
                Spacer()
                Button(action: monitor.refresh) { Image(systemName: "arrow.clockwise") }.buttonStyle(KnockIconStyle()).help(L("Refresh calendars"))
            }.font(.system(size: 11)).padding(.horizontal, KnockUI.inset).frame(height: 54)
        }
    }
    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return L("TODAY") }
        if Calendar.current.isDateInTomorrow(date) { return L("TOMORROW") }
        return Localization.day(date)
    }
}

struct PlaygroundView: View {
    @ObservedObject var monitor: CalendarMonitor
    @ObservedObject var design: DesignPreferences
    let preview: () -> Void
    let testSound: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: L("Reminder style"))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    ForEach(ReminderTheme.allCases) { theme in
                        Button { design.theme = theme } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    CharacterStage(theme: theme, animated: false, compact: true).frame(height: 76)
                                }.frame(height: 76)
                                Text(theme.title).font(.system(size: 11, weight: .medium)).lineLimit(2).multilineTextAlignment(.center)
                                    .frame(height: 28).frame(maxWidth: .infinity)
                            }.padding(8).frame(maxWidth: .infinity)
                                .background(design.theme == theme ? theme.accent.opacity(0.06) : Color.primary.opacity(0.015), in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(design.theme == theme ? theme.accent.opacity(0.8) : KnockUI.line, lineWidth: design.theme == theme ? 1.5 : 1))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel(theme.title).accessibilityValue(design.theme == theme ? L("Selected") : "")
                    }
                }
                HStack(spacing: 28) {
                    CharacterStage(theme: design.theme, animated: design.animated).frame(width: 210, height: 174)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(design.theme.title).font(.system(size: 22, weight: .semibold, design: .rounded))
                        Text(design.theme.greeting).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Button(action: preview) { Label(L("Preview notice"), systemImage: "arrow.up.right") }
                            .buttonStyle(KnockButtonStyle(tint: design.theme.accent)).padding(.top, 4)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.horizontal, 24).frame(maxWidth: .infinity).frame(height: 174)
                    .background(design.theme.accent.opacity(0.045))
                    .overlay(alignment: .top) { Rectangle().fill(KnockUI.line).frame(height: 1) }
                    .overlay(alignment: .bottom) { Rectangle().fill(KnockUI.line).frame(height: 1) }
                SectionTitle(title: L("Sound & motion"))
                VStack(spacing: 0) {
                    HStack {
                        PreferenceLabel(title: L("Sound style"), symbol: "waveform"); Spacer()
                        Picker(L("Sound style"), selection: $design.sound) { ForEach(SoundStyle.allCases) { Text($0.title).tag($0) } }.labelsHidden().frame(width: 194, alignment: .trailing)
                        Button(action: testSound) { Image(systemName: "play.fill") }.buttonStyle(KnockIconStyle()).help(L("Preview sound")).accessibilityLabel(L("Preview sound"))
                            .disabled(!monitor.soundEnabled || design.sound == .silent || design.volume == 0)
                    }.frame(minHeight: 48)
                    Divider()
                    HStack {
                        PreferenceLabel(title: L("Volume"), symbol: "speaker.wave.2"); Spacer()
                        Slider(value: $design.volume, in: 0...1).controlSize(.small).frame(width: 186).accessibilityLabel(L("Volume")).disabled(!monitor.soundEnabled || design.sound == .silent)
                        Text(design.volume.formatted(.percent.precision(.fractionLength(0)).locale(Localization.locale))).monospacedDigit().frame(width: 42, alignment: .trailing)
                    }.frame(minHeight: 48)
                    Divider()
                    HStack(spacing: 20) {
                        preferenceToggle(L("Reminder sound"), symbol: "speaker", binding: $monitor.soundEnabled).frame(maxWidth: .infinity)
                        Divider().frame(height: 26)
                        preferenceToggle(L("Animations"), symbol: "figure.play", binding: $design.animated).frame(maxWidth: .infinity)
                        Divider().frame(height: 26)
                        preferenceToggle(L("Extra nudges"), symbol: "bell.badge", binding: $design.repeatNudge).frame(maxWidth: .infinity)
                    }.padding(.top, 8)
                }.font(.system(size: 13))
            }.padding(KnockUI.inset)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var monitor: CalendarMonitor
    @ObservedObject var design: DesignPreferences
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle(title: L("General")).padding(.bottom, 12)
                HStack {
                    PreferenceLabel(title: L("Language"), symbol: "globe"); Spacer()
                    Picker(L("Language"), selection: $design.language) { ForEach(AppLanguage.allCases) { Text($0.title).tag($0) } }.labelsHidden().frame(width: 210, alignment: .trailing)
                }.frame(minHeight: 52)
                Divider()
                HStack {
                    PreferenceLabel(title: L("Advance notice"), symbol: "clock"); Spacer()
                    Picker(L("Advance notice"), selection: $monitor.leadMinutes) {
                        ForEach([1, 3, 5, 10, 15, 30], id: \.self) { Text(L($0 == 1 ? "%d minute" : "%d minutes", $0)).tag($0) }
                    }.labelsHidden().frame(width: 210, alignment: .trailing)
                }.frame(minHeight: 52)
                Divider()
                preferenceToggle(L("Pause reminders"), symbol: "pause.circle", binding: $monitor.paused)
                Divider()
                preferenceToggle(L("Launch at login"), symbol: "power", binding: Binding(get: { monitor.loginEnabled || monitor.loginNeedsApproval }, set: monitor.setLaunchAtLogin))
                if monitor.loginNeedsApproval {
                    Button(L("Open Login Items Settings")) { SMAppService.openSystemSettingsLoginItems() }.buttonStyle(KnockButtonStyle()).padding(.bottom, 12)
                }
                Divider()
                SectionTitle(title: L("CALENDARS")).padding(.top, 28).padding(.bottom, 16)
                if !monitor.hasAccess {
                    if monitor.authorization == .notDetermined { Button(L("Connect Calendar"), action: monitor.requestAccess).buttonStyle(KnockButtonStyle(primary: true)).disabled(monitor.requestingAccess) }
                    else { Button(L("Calendar Privacy Settings"), action: monitor.openPrivacySettings).buttonStyle(KnockButtonStyle()) }
                } else {
                    ForEach(monitor.calendars) { calendar in
                        HStack(spacing: 12) {
                            Circle().fill(Color(nsColor: calendar.color)).frame(width: 9, height: 9)
                            VStack(alignment: .leading, spacing: 4) { Text(calendar.title); Text(calendar.source).font(.system(size: 11)).foregroundStyle(.secondary) }
                            Spacer()
                            Toggle(calendar.title, isOn: Binding(get: { !monitor.excludedCalendars.contains(calendar.id) }, set: { monitor.setCalendar(calendar.id, enabled: $0) }))
                                .labelsHidden().toggleStyle(.switch).controlSize(.small)
                        }.padding(.vertical, 14)
                        Divider()
                    }
                }
            }.font(.system(size: 13)).padding(KnockUI.inset)
        }
    }
}

func openCalendar() {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") { NSWorkspace.shared.openApplication(at: url, configuration: .init()) }
}
