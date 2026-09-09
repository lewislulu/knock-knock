import AppKit

@main
struct NativeResourceTests {
    @MainActor static func main() {
        let app = URL(fileURLWithPath: CommandLine.arguments[1])
        guard let bundle = Bundle(url: app) else { fatalError("App bundle missing") }
        for (language, expected) in [(AppLanguage.english, "Playground"), (.chinese, "搞怪实验室"), (.japanese, "あそびば")] {
            precondition(Localization.text("Playground", language: language, resources: bundle) == expected)
            precondition(Localization.text("missing-key", language: language, resources: bundle) == "missing-key")
            print("PASS: native localization and fallback for \(language.rawValue)")
        }
        for name in ["chime", "arcade", "meow", "knock", "siren"] {
            guard let path = bundle.path(forResource: name, ofType: "wav"),
                  let sound = NSSound(contentsOfFile: path, byReference: false) else { fatalError("Cannot decode \(name)") }
            precondition(sound.duration > 0 && sound.duration < 1.6)
            print("PASS: NSSound decodes \(name)")
        }
        for sprite in [PixelSprite.cat, .girl, .agent] {
            precondition(sprite.rows.count == 20)
            precondition(sprite.rows.allSatisfy { $0.count == 20 })
            precondition(sprite.rows.allSatisfy { $0.allSatisfy { $0 == "." || sprite.palette[$0] != nil } })
        }
        print("PASS: all pixel sprites have valid dimensions and palettes")
        let suite = "app.knockknock.mac.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DesignPreferences(defaults: defaults)
        preferences.theme = .fbi
        preferences.language = .chinese
        preferences.sound = .knock
        preferences.volume = 0.25
        preferences.animated = false
        preferences.repeatNudge = true
        let restored = DesignPreferences(defaults: defaults)
        precondition(restored.theme == .fbi && restored.language == .chinese && restored.sound == .knock)
        precondition(restored.volume == 0.25 && !restored.animated && restored.repeatNudge)
        print("PASS: theme, language, sound, volume, motion, and nudges survive relaunch")
    }
}
