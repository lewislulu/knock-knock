import SwiftUI

struct AgentSettingsView: View {
    @ObservedObject var agents: AgentIntegration
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle(title: L("Connections")).padding(.bottom, 12)
                ForEach(AgentSource.allCases) { source in
                    HStack(spacing: 14) {
                        Image(systemName: "terminal").font(.system(size: 22)).foregroundStyle(source == .codex ? KnockUI.accent : .pink).frame(width: 36)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(source.title).font(.system(size: 15, weight: .semibold))
                            Text(agents.installed.contains(source)
                                 ? (agents.receivedSources.contains(source) ? L("Events received") : L("Configured; awaiting first event"))
                                 : L("Not connected")).font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { agents.onPreview?(source) } label: { Image(systemName: "play.fill") }
                            .buttonStyle(KnockIconStyle()).help(L("Preview notice"))
                        Button { agents.connect(source) } label: {
                            Label(agents.installed.contains(source) ? L("Disconnect") : L("Connect"), systemImage: agents.installed.contains(source) ? "link.badge.plus" : "link")
                        }.buttonStyle(KnockButtonStyle())
                    }.frame(minHeight: 80)
                    Divider()
                    if source == .codex && agents.installed.contains(.codex) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(L("Codex hook trust"), systemImage: "checkmark.shield")
                                .font(.system(size: 13, weight: .semibold))
                            Text(L("In Codex, enter /hooks and trust only the knock-notify Stop hook. Then reopen your task."))
                                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            Button(action: agents.reviewCodexHook) {
                                Label(L("Review in Terminal"), systemImage: "terminal")
                            }.buttonStyle(KnockButtonStyle())
                        }.padding(.vertical, 16)
                        Divider()
                    }
                }
                SectionTitle(title: L("Notifications")).padding(.top, 28).padding(.bottom, 12)
                preferenceToggle(L("Agent reminders"), symbol: "bell.badge", binding: $agents.enabled)
                Divider()
                preferenceToggle(L("Show reply excerpts"), symbol: "text.alignleft", binding: $agents.showSummaries)
                Divider()
                HStack {
                    PreferenceLabel(title: L("Last event received"), symbol: "clock")
                    Spacer()
                    Text(agents.lastReceived.map { Localization.time($0) } ?? L("No events yet")).foregroundStyle(.secondary)
                }.frame(minHeight: 52)
                if let error = agents.error {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).fixedSize(horizontal: false, vertical: true).padding(.top, 16)
                }
                HStack {
                    Link(destination: URL(string: "https://github.com/lewislulu/knock-knock/blob/feature/agent-completion-reminders/docs/AGENT-INTEGRATIONS.md")!) {
                        Label(L("Connection guide"), systemImage: "arrow.up.right.square")
                    }
                    Spacer()
                    Button(action: agents.refreshConnections) { Image(systemName: "arrow.clockwise") }.buttonStyle(KnockIconStyle()).help(L("Refresh connections"))
                }.padding(.top, 24)
            }.font(.system(size: 13)).padding(KnockUI.inset)
        }
    }
}
