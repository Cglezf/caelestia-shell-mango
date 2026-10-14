import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).parents[1]
spec = importlib.util.spec_from_file_location('keybinding_sheet', ROOT / 'assets/mango_keybindings.py')
sheet = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sheet)


class KeybindingSheetTest(unittest.TestCase):
    def test_sources_overrides_modes_and_release_bindings(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root/'base.conf').write_text('bind=LOGO,slash,spawn,old-command\nbindr=SUPER,Super_L,spawn,qs ipc -c caelestia call drawers toggle launcher\nkey_mode=resize\nbind=NONE,h,resizewin,-50,+0\n')
            path = root/'config.conf'
            path.write_text('source=base.conf\nkey_mode=default\nbind=SUPER,slash,spawn,qs ipc -c caelestia call keybindings toggle\nsource_optional=absent.conf\n')
            values, _ = sheet.read_bindings(path)
            rows = list(values.values())
            self.assertEqual(len(rows), 3)
            self.assertTrue(any(r['keys']=='Super + /' and r['description']=='Keyboard shortcut sheet' for r in rows))
            self.assertTrue(any('release' in r['keys'] for r in rows))
            self.assertTrue(any(r['mode']=='resize' for r in rows))

    def test_toml_sources_and_mouse_bindings(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root/'base.conf').write_text('bind=SUPER,t,spawn,foot\n')
            path=root/'config.toml'
            path.write_text('[global]\nsource=["base.conf"]\n[bind.default]\n"SUPER+slash"="spawn,qs ipc -c caelestia call keybindings toggle"\n[mousebind.default]\n"SUPER+btn_left"="moveresize,curmove"\n')
            values, _ = sheet.read_bindings(path)
            self.assertEqual(len(values), 3)
            self.assertTrue(any(r['keys']=='Super + Left click' for r in values.values()))

    def test_cyclic_source_is_reported(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'config.conf'
            path.write_text('source=config.conf\n')
            with self.assertRaisesRegex(ValueError, 'Cyclic'):
                sheet.read_bindings(path)

    def test_helper_actions_remain_readable_with_user_local_paths(self):
        category, description = sheet.describe('spawn', ['python3 /home/user/.local/share/caelestia/mango-actions.py workspace move slot 3'], '3')
        self.assertEqual(category, 'Workspaces')
        self.assertEqual(description, 'Move window to workspace 3 in current group')

    def test_hardware_keys_have_readable_names(self):
        self.assertEqual(sheet.describe('spawn', ['wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle'], 'XF86AudioMicMute'), ('Hardware', 'Mute / unmute microphone'))


if __name__ == '__main__': unittest.main()
