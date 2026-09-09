"""Build native localization bundles and short, original PCM sound effects."""
import array
import json
import math
from pathlib import Path
import random
import sys
import wave

ROOT = Path(__file__).resolve().parent.parent
RATE = 44100
PERMISSION = {
    "en": "knock-knock reads your calendar events to remind you before they start. Your calendar data stays on this Mac. knock-knock does not create, edit, or delete events.",
    "zh-Hans": "knock-knock 读取日历日程，在开始前提醒你。日历数据仅保存在这台 Mac 上。knock-knock 不会创建、修改或删除日程。",
    "ja": "knock-knockは予定の開始前に通知するためカレンダーを読み取ります。カレンダーデータはこのMac内に保存されます。予定の作成・編集・削除は行いません。",
}

def sounds():
    result = {}
    rng = random.Random(51)
    for name, duration in [("chime", 1.25), ("arcade", 0.8), ("meow", 0.95), ("knock", 1.1), ("siren", 1.35)]:
        samples = []
        phase = 0.0
        for index in range(int(RATE * duration)):
            t = index / RATE
            if name == "chime":
                value = sum(math.sin(2 * math.pi * f * t) * math.exp(-t * d) * a
                            for f, d, a in [(660, 4, 0.5), (990, 5, 0.3), (1320, 6, 0.2)])
            elif name == "arcade":
                f = [523.25, 659.25, 783.99, 1046.5][min(3, int(t / 0.16))]
                phase += 2 * math.pi * f / RATE
                envelope = min(1, (t % 0.16) / 0.006) * max(0, 1 - (t % 0.16) / 0.16)
                value = (math.sin(phase) + math.sin(3 * phase) / 3 + math.sin(5 * phase) / 5) * envelope
            elif name == "meow":
                f = 420 + 420 * math.sin(math.pi * min(1, t / 0.85)) + 12 * math.sin(2 * math.pi * 24 * t)
                phase += 2 * math.pi * f / RATE
                value = (math.sin(phase) + 0.35 * math.sin(2 * phase)) * math.sin(math.pi * t / duration)
            elif name == "knock":
                elapsed = t % 0.34
                value = (math.sin(2 * math.pi * 170 * elapsed) + 0.28 * rng.uniform(-1, 1)) * math.exp(-elapsed * 42)
                if t > 0.93:
                    value = 0
            else:
                f = 580 + 180 * math.sin(2 * math.pi * 2.6 * t)
                phase += 2 * math.pi * f / RATE
                value = math.sin(phase) * 0.7 + math.sin(2 * phase) * 0.1
            fade = min(1, t / 0.01, (duration - t) / 0.04)
            samples.append(value * max(0, fade))
        peak = max(abs(v) for v in samples)
        pcm = array.array("h", (round(v / peak * 0.68 * 32767) for v in samples))
        if sys.byteorder != "little":
            pcm.byteswap()
        result[name] = pcm.tobytes()
    return result

def build(destination):
    destination.mkdir(parents=True, exist_ok=True)
    catalog = json.loads((ROOT / "Resources/Localizations.json").read_text())
    for language in PERMISSION:
        folder = destination / (language + ".lproj")
        folder.mkdir(exist_ok=True)
        lines = []
        for key, translations in catalog.items():
            value = key if language == "en" else translations[language]
            lines.append(json.dumps(key, ensure_ascii=False) + " = " + json.dumps(value, ensure_ascii=False) + ";")
        (folder / "Localizable.strings").write_text("\n".join(lines) + "\n")
        usage = json.dumps(PERMISSION[language], ensure_ascii=False)
        (folder / "InfoPlist.strings").write_text(
            '"NSCalendarsFullAccessUsageDescription" = ' + usage + ';\n"NSCalendarsUsageDescription" = ' + usage + ';\n')
    for name, pcm in sounds().items():
        with wave.open(str(destination / (name + ".wav")), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(pcm)
    print(f"Built 3 languages and 5 sounds in {destination}")

if __name__ == "__main__":
    build(Path(sys.argv[1]))
