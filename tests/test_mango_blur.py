import importlib.util
from pathlib import Path
import unittest
import tempfile

spec = importlib.util.spec_from_file_location("mango_blur", Path(__file__).parents[1] / "assets/mango_blur.py")
blur = importlib.util.module_from_spec(spec)
spec.loader.exec_module(blur)


class BlurRulesTest(unittest.TestCase):
    def test_enabled_disabled_and_alpha_capability(self):
        self.assertIn("no_blur:0", blur.rule_text(True, 0.8))
        self.assertIn("no_blur:1", blur.rule_text(False, 0.8))
        self.assertNotIn("blur_ignore_alpha", blur.rule_text(True, 0.8))
        self.assertIn("blur_ignore_alpha:0.7700", blur.rule_text(True, 0.8, True))
        self.assertIn("blur_ignore_alpha:0.0000", blur.rule_text(True, 0.01, True))
        self.assertIn("blur_ignore_alpha:1.0000", blur.rule_text(True, 2, True))

    def test_unchanged_rules_do_not_rewrite_or_reload(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state/blur.conf"
            self.assertTrue(blur.atomic_write(path, blur.rule_text(True, 0.8)))
            timestamp = path.stat().st_mtime_ns
            self.assertFalse(blur.atomic_write(path, blur.rule_text(True, 0.5)))
            self.assertEqual(path.stat().st_mtime_ns, timestamp)
            self.assertTrue(blur.atomic_write(path, blur.rule_text(False, 0.5)))
            self.assertIn("no_blur:1", path.read_text())


if __name__ == "__main__":
    unittest.main()
