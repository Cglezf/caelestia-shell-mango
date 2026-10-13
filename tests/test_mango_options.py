import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("mango_options", Path(__file__).parents[1] / "assets/mango_options.py")
options = importlib.util.module_from_spec(spec)
spec.loader.exec_module(options)


class ConfigOptionsTest(unittest.TestCase):
    def test_sources_cycles_and_overrides(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder / "base.conf").write_text("blur=1\nborder_size=3\nsource=config.conf\n")
            config = folder / "config.conf"
            config.write_text("source=base.conf\nblur=0 # local override\nsource_optional=missing.conf\nsecret=value\nborder_radius=bad\n")
            self.assertEqual(options.read_config(config), {"blur": 0, "border_size": 3})

    def test_toml_sources_and_numeric_options(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder / "base.conf").write_text("blur=1\nanimations=1\n")
            config = folder / "config.toml"
            config.write_text('[global]\nsource=["base.conf"]\nblur=0\ngap_inner_horizontal=7\n')
            self.assertEqual(options.read_config(config), {"blur": 0, "animations": 1, "gap_inner_horizontal": 7})


if __name__ == "__main__":
    unittest.main()
