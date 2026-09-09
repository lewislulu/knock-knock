import SwiftUI

enum ReminderTheme: String, CaseIterable, Identifiable {
    case classic, cat, banner, girl, fbi
    var id: String { rawValue }
    var greeting: String {
        switch self {
        case .classic: return L("Your next meeting")
        case .cat: return L("MEOW. IT'S TIME.")
        case .banner: return L("Got it!")
        case .girl: return L("Your meeting is at the door.")
        case .fbi: return L("Federal Bureau of ... Meetings.")
        }
    }
    var title: String {
        switch self {
        case .classic: return L("Classic")
        case .cat: return L("Pixel Cat")
        case .banner: return L("Pop Banner")
        case .girl: return L("Knock Knock")
        case .fbi: return L("FBI! Meeting!")
        }
    }
    var symbol: String {
        switch self {
        case .classic: return "calendar.badge.clock"
        case .cat: return "cat"
        case .banner: return "rectangle.topthird.inset.filled"
        case .girl: return "door.left.hand.open"
        case .fbi: return "shield.lefthalf.filled"
        }
    }
    var accent: Color {
        switch self {
        case .classic: return Color(red: 0.05, green: 0.46, blue: 0.40)
        case .cat: return Color(red: 0.78, green: 0.20, blue: 0.40)
        case .banner: return Color(red: 0.06, green: 0.43, blue: 0.39)
        case .girl: return Color(red: 0.23, green: 0.37, blue: 0.75)
        case .fbi: return Color(red: 0.68, green: 0.16, blue: 0.13)
        }
    }
    var defaultSound: SoundStyle {
        switch self {
        case .classic, .banner: return .chime
        case .cat: return .meow
        case .girl: return .knock
        case .fbi: return .siren
        }
    }
    var panelSize: CGSize {
        switch self {
        case .classic: return CGSize(width: 780, height: 420)
        case .banner: return CGSize(width: 920, height: 172)
        case .cat: return CGSize(width: 700, height: 480)
        case .girl, .fbi: return CGSize(width: 820, height: 420)
        }
    }
}

enum SoundStyle: String, CaseIterable, Identifiable {
    case theme, chime, arcade, meow, knock, siren, silent
    var id: String { rawValue }
    var title: String {
        switch self {
        case .theme: return L("Match theme")
        case .chime: return L("Soft chime")
        case .arcade: return L("8-bit level up")
        case .meow: return L("Robot meow")
        case .knock: return L("Knock knock knock")
        case .siren: return L("Tiny siren")
        case .silent: return L("Silent")
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", chinese = "zh-Hans", japanese = "ja"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return L("Follow system")
        case .english: return "English"
        case .chinese: return "简体中文"
        case .japanese: return "日本語"
        }
    }
    var resolved: String {
        guard self == .system else { return rawValue }
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("zh") { return "zh-Hans" }
        if preferred.hasPrefix("ja") { return "ja" }
        return "en"
    }
}

enum Localization {
    static var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "system") ?? .system
    }
    static var locale: Locale { Locale(identifier: language.resolved) }
    static func text(_ key: String, language: AppLanguage, resources: Bundle = .main) -> String {
        guard let path = resources.path(forResource: language.resolved, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }
    static func day(_ date: Date, wide: Bool = false) -> String {
        let format = wide ? Date.FormatStyle().weekday(.wide).month(.wide).day() : Date.FormatStyle().weekday(.wide).month(.abbreviated).day()
        return date.formatted(format.locale(locale))
    }
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    let format = Localization.text(key, language: Localization.language)
    return String(format: format, locale: Localization.locale, arguments: arguments)
}

@MainActor
final class DesignPreferences: ObservableObject {
    @Published var theme: ReminderTheme { didSet { save(theme.rawValue, "theme") } }
    @Published var language: AppLanguage { didSet { save(language.rawValue, "language") } }
    @Published var sound: SoundStyle { didSet { save(sound.rawValue, "soundStyle") } }
    @Published var volume: Double { didSet { save(volume, "soundVolume") } }
    @Published var animated: Bool { didSet { save(animated, "animated") } }
    @Published var repeatNudge: Bool { didSet { save(repeatNudge, "repeatNudge") } }
    var onChange: (() -> Void)?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = ReminderTheme(rawValue: defaults.string(forKey: "theme") ?? "cat") ?? .cat
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "system") ?? .system
        sound = SoundStyle(rawValue: defaults.string(forKey: "soundStyle") ?? "theme") ?? .theme
        volume = min(1, max(0, defaults.object(forKey: "soundVolume") as? Double ?? 0.55))
        animated = defaults.object(forKey: "animated") as? Bool ?? true
        repeatNudge = defaults.bool(forKey: "repeatNudge")
    }
    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key); onChange?() }
}

@MainActor
final class ReminderSoundPlayer {
    private var playing: NSSound?
    func stop() { playing?.stop(); playing = nil }
    @discardableResult
    func play(_ preferences: DesignPreferences) -> Bool {
        stop()
        let style = preferences.sound == .theme ? preferences.theme.defaultSound : preferences.sound
        guard style != .silent, preferences.volume > 0 else { return true }
        guard let path = Bundle.main.path(forResource: style.rawValue, ofType: "wav"),
              let sound = NSSound(contentsOfFile: path, byReference: false) else { return false }
        sound.volume = Float(preferences.volume)
        playing = sound
        return sound.play()
    }
}
