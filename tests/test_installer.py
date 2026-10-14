import importlib.util
import os
from pathlib import Path
import pty
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).parents[1]
spec = importlib.util.spec_from_file_location("installer_config", ROOT / "scripts/install-mango-config.py")
config_helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config_helper)


class MangoSetupTest(unittest.TestCase):
    def test_existing_shortcuts_sources_and_idempotence(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            config = directory / "config.conf"
            source = directory / "bindings.conf"
            source.write_text("bind=LOGO,space,spawn,qs ipc -c caelestia call drawers toggle launcher\n")
            config.write_text("source=bindings.conf\nkey_mode=resize\n")
            config_helper.configure(config, ROOT / "assets/mango-keybinds.conf", True, True)
            first = config.read_text()
            self.assertNotIn("bind=SUPER,space", first)
            self.assertIn("key_mode=resize", first)
            self.assertEqual(first.count("exec_once=qs -c caelestia"), 1)
            self.assertTrue(list(directory.glob("config.conf.before-caelestia-*")))
            config_helper.configure(config, ROOT / "assets/mango-keybinds.conf", True, True)
            self.assertEqual(config.read_text(), first)

    def test_conflict_leaves_config_untouched(self):
        with tempfile.TemporaryDirectory() as folder:
            config = Path(folder) / "config.conf"
            original = "bind=SUPER,space,spawn,another-launcher\n"
            config.write_text(original)
            with self.assertRaisesRegex(ValueError, "conflicts"):
                config_helper.configure(config, ROOT / "assets/mango-keybinds.conf", True, True)
            self.assertEqual(config.read_text(), original)

    def test_managed_configs_are_preserved(self):
        with tempfile.TemporaryDirectory() as folder:
            toml = Path(folder) / "config.toml"
            toml.write_text("[global]\n")
            link = Path(folder) / "config.conf"
            link.symlink_to(toml)
            for config in (toml, link):
                with self.assertRaises(ValueError):
                    config_helper.configure(config, ROOT / "assets/mango-keybinds.conf", True, True)
            self.assertEqual(toml.read_text(), "[global]\n")

    def test_full_profile_replaces_conflicts_preserving_sources_and_mouse_keys(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            source = directory / "defaults.conf"
            source.write_text("bind=SUPER,n,switch_layout\naxisbind=SUPER,DOWN,viewtoright_have_client\nmousebind=SUPER,btn_left,moveresize,curmove\nblur=1\n")
            rules = directory / "blur.conf"
            rules.write_text("layer_rule=layer_name:^caelestia-drawers$,no_blur:1\n")
            config = directory / "config.conf"
            config.write_text("source=defaults.conf\nsource=blur.conf\n")
            original_source = source.read_text()
            profile = ROOT / "assets/mango-keybinds-full.conf"
            with self.assertRaises(ValueError):
                config_helper.configure(config, profile, True, False, dry_run=True)
            config_helper.configure(config, profile, True, False, True, 31)
            text = config.read_text()
            self.assertNotIn("bind=SUPER,n,switch_layout", text)
            self.assertNotIn("viewtoright_have_client", text)
            self.assertIn(f"source={rules}", text)
            self.assertIn("tag_num=31", text)
            self.assertEqual(text.count("mousebind=SUPER,btn_left"), 1)
            self.assertEqual(source.read_text(), original_source)
            config_helper.configure(config, profile, True, False, True, 31)
            self.assertEqual(config.read_text(), text)

    def test_preview_does_not_write_and_common_mode_conflicts_are_detected(self):
        with tempfile.TemporaryDirectory() as folder:
            config = Path(folder) / "config.conf"
            config.write_text("blur=0\n")
            config_helper.configure(config, ROOT / "assets/mango-keybinds.conf", True, dry_run=True)
            self.assertEqual(config.read_text(), "blur=0\n")
            config.write_text("key_mode=common\nbindl=SUPER,d,spawn,other-app\n")
            with self.assertRaises(ValueError):
                config_helper.configure(config, ROOT / "assets/mango-keybinds.conf", True)


class InstallerTest(unittest.TestCase):
    def test_invalid_jobs_and_help(self):
        help_result = subprocess.run(["bash", str(ROOT / "install.sh"), "--help"], capture_output=True, text=True)
        self.assertEqual(help_result.returncode, 0)
        result = subprocess.run(["bash", str(ROOT / "install.sh"), "--jobs", "0"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)

    @unittest.skipIf(os.geteuid() == 0, "installer intentionally refuses root builds")
    def test_guided_build_and_sudo_use_mock_commands(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            log = directory / "commands.log"
            for name in ("cmake", "ninja", "pkg-config", "c++", "qs", "mango", "mmsg", "pacman", "sudo"):
                tool = directory / name
                tool.write_text('#!/bin/bash\nprintf "%s\\n" "$0 $*" >> "$INSTALLER_TEST_LOG"\n')
                tool.chmod(0o755)
            env = os.environ.copy()
            env.update(PATH=str(directory) + ":" + env["PATH"], INSTALLER_TEST_LOG=str(log), XDG_CONFIG_HOME=str(directory / "config"))
            env.pop("WAYLAND_DISPLAY", None)
            master, slave = pty.openpty()
            try:
                process = subprocess.Popen(["bash", str(ROOT / "install.sh"), "--jobs", "1"], stdin=slave,
                                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, text=True)
                os.write(master, b"n\ny\nn\nn\n")
                stdout, stderr = process.communicate(timeout=15)
                self.assertEqual(process.returncode, 0, stdout + stderr)
                commands = log.read_text()
                self.assertIn("cmake --build", commands)
                self.assertIn("--parallel 1", commands)
                self.assertIn("sudo cmake --install", commands)
                self.assertNotIn("sudo cmake -S", commands)
            finally:
                os.close(master)
                os.close(slave)


if __name__ == "__main__":
    unittest.main()
