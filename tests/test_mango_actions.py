import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).parents[1]
spec = importlib.util.spec_from_file_location("mango_actions", ROOT / "assets/mango-actions.py")
actions = importlib.util.module_from_spec(spec)
spec.loader.exec_module(actions)


class WorkspaceActionsTest(unittest.TestCase):
    def test_slots_and_groups_preserve_current_group_or_slot(self):
        self.assertEqual(actions.workspace_target(24, 31, "slot", 7), 27)
        self.assertEqual(actions.workspace_target(10, 31, "group", 2), 20)
        self.assertEqual(actions.workspace_target(25, 31, "group", 1), 5)
        self.assertEqual(actions.workspace_target(3, 31, "relative", 10), 13)

    def test_mango_boundaries_are_checked(self):
        for current, count, kind, number in [(9, 9, "slot", 10), (31, 31, "relative", 1), (20, 31, "group", 4), (1, 31, "slot", 0)]:
            with self.assertRaises(ValueError):
                actions.workspace_target(current, count, kind, number)

    def test_native_dispatch_uses_one_comma_separated_argument(self):
        with patch.object(actions, "run") as run:
            run.return_value.stdout = '{"success":true}'
            actions.dispatch("resizewin", 550, 700, "client", 12)
            self.assertEqual(run.call_args.args[0], ["mmsg", "dispatch", "resizewin,550,700,client,12"])


if __name__ == "__main__":
    unittest.main()
