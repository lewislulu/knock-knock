import array
import json
from pathlib import Path
import re
import unittest
import wave

ROOT = Path(__file__).resolve().parent.parent
CATALOG = json.loads((ROOT / "Resources/Localizations.json").read_text())

class ResourceTests(unittest.TestCase):
    def test_all_translations_and_placeholders(self):
        for key, translations in CATALOG.items():
            self.assertEqual(set(translations), {"zh-Hans", "ja"}, key)
            for value in translations.values():
                self.assertTrue(value.strip(), key)
                self.assertEqual(re.findall(r"%[d@sf]", key), re.findall(r"%[d@sf]", value), key)

    def test_direct_localization_keys_exist(self):
        for file in (ROOT / "Sources").glob("*.swift"):
            for key in re.findall(r'\bL\("([^"\\]+)"', file.read_text()):
                self.assertIn(key, CATALOG, f"{file.name}: {key}")

    def test_dynamic_keys_exist(self):
        keys = ["Upcoming", "Playground", "Settings", "Calendar access is restricted on this Mac.",
                "Calendar access is off.", "Reminders paused", "Reminders on", "Not connected", "%d minute", "%d minutes",
                "Dismiss", "I'm coming!", "KNOCK KNOCK!", "FBI! OPEN UP!", "Your meeting is at the door.",
                "Federal Bureau of ... Meetings.", "Preview Notice", "Resume Reminders", "Pause Reminders"]
        for key in keys:
            self.assertIn(key, CATALOG)

    def test_bundled_languages(self):
        resources = ROOT / "knock-knock.app/Contents/Resources"
        for language in ["en", "zh-Hans", "ja"]:
            text = (resources / (language + ".lproj") / "Localizable.strings").read_text()
            self.assertEqual(len(text.splitlines()), len(CATALOG))
            usage = (resources / (language + ".lproj") / "InfoPlist.strings").read_text()
            self.assertIn("NSCalendarsFullAccessUsageDescription", usage)

    def test_audio_is_short_non_silent_and_not_clipped(self):
        for name in ["chime", "arcade", "meow", "knock", "siren"]:
            with wave.open(str(ROOT / "knock-knock.app/Contents/Resources" / (name + ".wav"))) as sound:
                self.assertEqual((sound.getnchannels(), sound.getsampwidth(), sound.getframerate()), (1, 2, 44100))
                self.assertLessEqual(sound.getnframes() / sound.getframerate(), 1.5)
                samples = array.array("h", sound.readframes(sound.getnframes()))
                peak = max(abs(v) for v in samples)
                self.assertGreater(peak, 10000)
                self.assertLess(peak, 25000)
                self.assertLess(abs(samples[0]), 10)
                self.assertLess(abs(samples[-1]), 100)

if __name__ == "__main__":
    unittest.main(verbosity=2)
