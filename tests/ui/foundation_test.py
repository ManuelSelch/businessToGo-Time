import json
import unittest
from pathlib import Path

ASSETS = Path("Common/Sources/UI/Assets.xcassets")


class FoundationColorsTest(unittest.TestCase):
    def color(self, name, appearance):
        data = json.loads((ASSETS / f"{name}.colorset/Contents.json").read_text())
        entry = next(c for c in data["colors"] if bool(c.get("appearances")) == (appearance == "dark"))
        rgb = entry["color"]["components"]
        return tuple(round(float(rgb[channel]) * 255) for channel in ("red", "green", "blue"))

    def test_action_color_adapts_to_appearance(self):
        self.assertEqual(self.color("theme", "light"), (7, 62, 67))
        self.assertEqual(self.color("theme", "dark"), (132, 226, 177))

    def test_action_foreground_contrasts_with_action_color(self):
        self.assertEqual(self.color("themeForeground", "light"), (255, 255, 255))
        self.assertEqual(self.color("themeForeground", "dark"), (7, 62, 67))


if __name__ == "__main__":
    unittest.main()
