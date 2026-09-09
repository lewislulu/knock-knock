import SwiftUI

enum KnockUI {
    static let accent = Color(red: 0.10, green: 0.39, blue: 0.35)
    static let ink = Color(red: 0.15, green: 0.18, blue: 0.20)
    static let line = Color(nsColor: .separatorColor).opacity(0.45)
    static let canvas = Color(nsColor: .textBackgroundColor)
    static let sidebar = Color(nsColor: .windowBackgroundColor)
    static let inset: CGFloat = 28
}

struct KnockButtonStyle: ButtonStyle {
    var primary = false
    var tint: Color = KnockUI.accent
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 14).frame(minHeight: 34)
            .foregroundStyle(primary ? .white : .primary)
            .background(primary ? tint : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(primary ? .clear : KnockUI.line, lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct KnockIconStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium)).frame(width: 32, height: 32)
            .background(configuration.isPressed ? Color.primary.opacity(0.10) : Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(RoundedRectangle(cornerRadius: 6)).opacity(enabled ? 1 : 0.35)
    }
}

struct SectionTitle: View {
    let title: String
    var body: some View {
        Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PreferenceLabel: View {
    let title: String
    let symbol: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 18)
            Text(title).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

func preferenceToggle(_ title: String, symbol: String, binding: Binding<Bool>) -> some View {
    HStack(spacing: 20) {
        PreferenceLabel(title: title, symbol: symbol)
        Spacer(minLength: 12)
        Toggle(title, isOn: binding).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(KnockUI.accent)
    }.frame(minHeight: 48)
}
