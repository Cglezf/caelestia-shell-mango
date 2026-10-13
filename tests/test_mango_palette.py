import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("mango_palette", Path(__file__).parents[1] / "assets/mango_palette.py")
palette = importlib.util.module_from_spec(spec)
spec.loader.exec_module(palette)


class PaletteTest(unittest.TestCase):
    roles = {"primary": "#112233", "surface": "#223344", "on_surface": "#eeeeee",
             "tertiary": "#445566", "on_tertiary": "#ffffff",
             "tertiary_container": "#334455", "on_tertiary_container": "#dddddd",
             "neutral_variant_palette_key_color": "#667788"}

    def test_legacy_and_current_schemas_match(self):
        old = {"colors": {"dark": self.roles}}
        new = {"colors": {name: {"dark": {"color": value}} for name, value in self.roles.items()}}
        expected = palette.convert(old, "dark", "vibrant")
        self.assertEqual(palette.convert(new, "dark", "vibrant"), expected)
        self.assertEqual(expected["colours"]["neutral_variant_paletteKeyColor"], "667788")
        self.assertEqual(expected["colours"]["success"], "445566")
        self.assertEqual(expected["variant"], "vibrant")

    def test_invalid_or_missing_required_colours_are_rejected(self):
        with self.assertRaises(ValueError):
            palette.convert({"colors": {"primary": "invalid"}}, "dark", "tonalspot")


if __name__ == "__main__":
    unittest.main()
