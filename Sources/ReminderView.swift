import SwiftUI

struct ReminderView: View {
    let meeting: Meeting
    let count: Int
    let isPreview: Bool
    @ObservedObject var design: DesignPreferences
    let dismiss: () -> Void
    let snooze: () -> Void
    var showAgentSummary: Bool = false
    var openAgent: ((AgentEvent) -> Bool)? = nil
    var resumeAgent: ((AgentEvent) -> Bool)? = nil
    @State private var actionFailed = false
    private var theme: ReminderTheme { design.theme }
    private var title: String { isPreview && meeting.agent == nil ? L("Your next meeting") : meeting.title }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Group {
                switch theme {
                case .classic: classic(now: timeline.date)
                case .cat: cat(now: timeline.date)
                case .banner: banner(now: timeline.date)
                case .girl, .fbi: knocking(now: timeline.date)
                }
            }.tint(theme.accent).environment(\.locale, Localization.locale)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label(isPreview ? L("KNOCK-KNOCK / PREVIEW") : "KNOCK-KNOCK", systemImage: theme.symbol)
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if count > 1 { Text(L("%d reminders", count)).font(.system(size: 11)).foregroundStyle(.secondary) }
            Button(action: dismiss) { Image(systemName: "xmark") }.buttonStyle(KnockIconStyle())
                .help(L("Dismiss reminder")).accessibilityLabel(L("Dismiss reminder"))
        }.frame(height: 32)
    }

    private func countdown(_ now: Date) -> String {
        if meeting.agent != nil { return L("REPLY READY") }
        let seconds = meeting.start.timeIntervalSince(now)
        if seconds <= 0 { return L("STARTING NOW") }
        if seconds <= 60 { return L("STARTING IN LESS THAN A MINUTE") }
        return L("STARTING IN %d MINUTES", Int(ceil(seconds / 60)))
    }

    private func timing(_ now: Date) -> some View {
        HStack(spacing: 6) {
            Circle().fill(theme.accent).frame(width: 5, height: 5)
            Text(countdown(now)).font(.system(size: 10, weight: .semibold)).foregroundStyle(theme.accent)
        }
    }

    private var eventTime: some View {
        HStack(spacing: 8) {
            Text(meeting.agent == nil ? Localization.time(meeting.start) + " – " + Localization.time(meeting.end) : Localization.time(meeting.start)).monospacedDigit().fixedSize()
            Circle().fill(Color(nsColor: meeting.color)).frame(width: 5, height: 5)
            Text(meeting.agent.map { $0.project.isEmpty ? $0.source.title : $0.project } ?? (isPreview ? L("Preview") : meeting.calendar)).lineLimit(1).truncationMode(.middle)
            if let agent = meeting.agent { Text(String(agent.sessionID.prefix(8))).font(.system(size: 10, design: .monospaced)).lineLimit(1) }
        }.font(.system(size: 12)).foregroundStyle(.secondary)
    }

    private var location: some View {
        Group {
            if let agent = meeting.agent, showAgentSummary, !agent.summary.isEmpty {
                Text(agent.summary).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
            }
            if actionFailed { Text(L("Could not open the session.")).font(.system(size: 11)).foregroundStyle(.red) }
            if !meeting.location.isEmpty && !meeting.location.hasPrefix("http") {
                Label(meeting.location, systemImage: "mappin").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).help(meeting.location)
            }
        }
    }

    private var primaryAction: some View {
        Button {
            if let agent = meeting.agent {
                if openAgent?(agent) == true { dismiss() } else { actionFailed = true }
                return
            }
            if let url = meeting.joinURL { NSWorkspace.shared.open(url) }
            dismiss()
        } label: {
            if let agent = meeting.agent {
                Label(L(agent.source == .codex ? "Open in Codex" : "Resume in Terminal"), systemImage: agent.source == .codex ? "arrow.up.right.square" : "terminal")
            } else {
                Label(L(meeting.joinURL != nil ? "Join meeting" : (theme == .classic ? "Dismiss" : "I'm coming!")),
                      systemImage: meeting.joinURL == nil ? "checkmark" : "video.fill")
            }
        }.buttonStyle(KnockButtonStyle(primary: true, tint: theme.accent)).disabled(isPreview && meeting.agent != nil)
    }

    private func actions(now: Date) -> some View {
        HStack(spacing: 10) {
            primaryAction
            if let agent = meeting.agent {
                if agent.source == .codex {
                    Button { if resumeAgent?(agent) == true { dismiss() } else { actionFailed = true } } label: { Image(systemName: "terminal") }
                        .buttonStyle(KnockIconStyle()).help(L("Resume in Terminal")).disabled(isPreview)
                }
                Button {
                    NSPasteboard.general.clearContents(); NSPasteboard.general.setString(agent.resumeCommand, forType: .string)
                } label: { Image(systemName: "doc.on.doc") }.buttonStyle(KnockIconStyle()).help(L("Copy resume command")).disabled(isPreview)
            } else {
                Button(action: snooze) { Label(L("Snooze 1 min"), systemImage: "clock.arrow.circlepath") }
                .buttonStyle(KnockButtonStyle()).disabled(ReminderPolicy.snoozeDate(start: meeting.start, now: now) == nil)
            }
            Spacer(minLength: 0)
            if meeting.agent == nil {
                Button(action: openCalendar) { Image(systemName: "calendar") }.buttonStyle(KnockIconStyle()).help(L("Open Calendar")).accessibilityLabel(L("Open Calendar"))
            }
        }
    }

    private func footer(now: Date) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(KnockUI.line).frame(height: 1)
            actions(now: now).padding(.horizontal, 28).frame(height: 70)
        }
    }

    private func classic(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, 28).padding(.top, 16)
            VStack(alignment: .leading, spacing: 14) {
                timing(now)
                Text(title).font(.system(size: 34, weight: .semibold)).lineLimit(3).minimumScaleFactor(0.7).help(title)
                eventTime
                location
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(.horizontal, 28).padding(.vertical, 20)
            footer(now: now)
        }.background(KnockUI.canvas).clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(KnockUI.line, lineWidth: 1))
    }

    private func cat(now: Date) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                header
                HStack(alignment: .center, spacing: 12) {
                    Text(meeting.agent == nil ? L("MEOW. IT'S TIME.") : L("MEOW. ALL DONE.")).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(theme.accent)
                    Spacer(minLength: 0)
                    timing(now)
                }.padding(.top, 4)
                Text(title).font(.system(size: 26, weight: .semibold, design: .rounded)).lineLimit(2).minimumScaleFactor(0.75).help(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                eventTime
                location
                Spacer(minLength: 2)
                actions(now: now).padding(.top, 4)
            }.padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 38).frame(height: 310)
                .background(PixelBubble().fill(Color(red: 1, green: 0.975, blue: 0.985)))
                .overlay(PixelBubble().strokeBorder(Color(red: 0.35, green: 0.30, blue: 0.34), lineWidth: 1.5))
            HStack {
                Spacer()
                CharacterStage(theme: .cat, animated: design.animated).frame(width: 200, height: 150)
            }.padding(.trailing, 26)
        }.padding(10).foregroundStyle(KnockUI.ink).preferredColorScheme(.light)
    }

    private func banner(now: Date) -> some View {
        HStack(spacing: 20) {
            Image(systemName: "megaphone.fill").font(.system(size: 35)).foregroundStyle(theme.accent).frame(width: 52)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    timing(now)
                    if isPreview { Text(L("Preview")).font(.system(size: 10)).foregroundStyle(.secondary) }
                    if count > 1 { Text(L("%d reminders", count)).font(.system(size: 10)).foregroundStyle(.secondary) }
                }
                Text(title).font(.system(size: 22, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.75).help(title)
                eventTime
                if let agent = meeting.agent, showAgentSummary, !agent.summary.isEmpty {
                    Text(agent.summary).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                if actionFailed { Text(L("Could not open the session.")).font(.system(size: 11)).foregroundStyle(.red) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 12) {
                Button(action: dismiss) { Image(systemName: "xmark") }.buttonStyle(KnockIconStyle()).help(L("Dismiss reminder")).accessibilityLabel(L("Dismiss reminder"))
                HStack(spacing: 8) {
                    primaryAction
                    if let agent = meeting.agent {
                        Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(agent.resumeCommand, forType: .string) }
                            label: { Image(systemName: "doc.on.doc") }.buttonStyle(KnockIconStyle()).help(L("Copy resume command")).disabled(isPreview)
                    } else {
                    Button(action: snooze) { Image(systemName: "clock.arrow.circlepath") }.buttonStyle(KnockIconStyle())
                        .help(L("Snooze 1 min")).accessibilityLabel(L("Snooze 1 min"))
                        .disabled(ReminderPolicy.snoozeDate(start: meeting.start, now: now) == nil)
                    }
                }
            }
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.945, green: 0.985, blue: 0.965)).foregroundStyle(KnockUI.ink)
            .overlay(alignment: .leading) { Rectangle().fill(theme.accent).frame(width: 4) }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.accent.opacity(0.25), lineWidth: 1))
            .preferredColorScheme(.light)
    }

    private func knocking(now: Date) -> some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 28).padding(.top, 16)
            HStack(spacing: 26) {
                CharacterStage(theme: theme, animated: design.animated).frame(width: 224, height: 220)
                VStack(alignment: .leading, spacing: 12) {
                    Text(L(theme == .girl ? "KNOCK KNOCK!" : "FBI! OPEN UP!"))
                        .font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundStyle(theme.accent)
                    Text(meeting.agent == nil ? theme.greeting : L("Your agent is at the door.")).font(.system(size: 11)).foregroundStyle(.secondary)
                    timing(now).padding(.top, 2)
                    Text(title).font(.system(size: 26, weight: .semibold, design: .rounded)).lineLimit(3).minimumScaleFactor(0.75).help(title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    eventTime
                    location
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.horizontal, 28).frame(maxHeight: .infinity).padding(.vertical, 12)
            footer(now: now)
            if theme == .fbi { CautionStripe().frame(height: 6) }
        }.foregroundStyle(KnockUI.ink).background(Color(red: 0.985, green: 0.99, blue: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.accent.opacity(0.20), lineWidth: 1))
            .preferredColorScheme(.light)
    }
}

private struct PixelBubble: InsettableShape {
    var amount: CGFloat = 0
    func inset(by amount: CGFloat) -> PixelBubble { PixelBubble(amount: self.amount + amount) }
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: amount, dy: amount)
        let b = r.maxY - 18, tail = r.maxX - 117
        var p = Path()
        p.move(to: CGPoint(x: r.minX + 8, y: r.minY))
        p.addLines([CGPoint(x: r.minX + 8, y: r.minY), CGPoint(x: r.maxX - 8, y: r.minY), CGPoint(x: r.maxX - 8, y: r.minY + 4),
                    CGPoint(x: r.maxX, y: r.minY + 4), CGPoint(x: r.maxX, y: b - 8),
                    CGPoint(x: r.maxX - 4, y: b - 8), CGPoint(x: r.maxX - 4, y: b),
                    CGPoint(x: tail + 20, y: b), CGPoint(x: tail + 20, y: r.maxY),
                    CGPoint(x: tail + 10, y: r.maxY), CGPoint(x: tail + 10, y: b + 8),
                    CGPoint(x: tail, y: b + 8), CGPoint(x: tail, y: b),
                    CGPoint(x: r.minX + 8, y: b), CGPoint(x: r.minX + 8, y: b - 4),
                    CGPoint(x: r.minX, y: b - 4), CGPoint(x: r.minX, y: r.minY + 8),
                    CGPoint(x: r.minX + 8, y: r.minY + 8)])
        p.closeSubpath()
        return p
    }
}

private struct CautionStripe: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.98, green: 0.79, blue: 0.25)))
            for x in stride(from: -12.0, to: size.width + 12, by: 24) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x + 12, y: 0))
                path.addLine(to: CGPoint(x: x + 6, y: size.height)); path.addLine(to: CGPoint(x: x - 6, y: size.height)); path.closeSubpath()
                context.fill(path, with: .color(KnockUI.ink))
            }
        }.accessibilityHidden(true)
    }
}
