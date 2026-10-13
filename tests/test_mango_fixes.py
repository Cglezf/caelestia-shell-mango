"""Structural guards for the mango-fixes branch: they read the QML, no Quickshell needed.

Each test covers a class, not the one line that was fixed: every `mmsg watch`
stream, every QML file that could launch fish, the whole logo decision chain.
"""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).parents[1]
QML_DIRS = ("components", "modules", "services", "utils")


def balanced(text, start, pair="{}"):
    """Text from the bracket at `start` to its match, skipping brackets inside strings."""
    depth, quote, index = 0, None, start
    while index < len(text):
        char = text[index]
        if quote:
            if char == "\\":
                index += 1
            elif char == quote:
                quote = None
        elif char in "\"'`":
            quote = char
        elif char in pair:
            depth += 1 if char == pair[0] else -1
            if depth == 0:
                return text[start:index + 1]
        index += 1
    raise ValueError(f"unbalanced {pair} from offset {start}")


def blocks(text, opener):
    """Bodies of every `opener {` block."""
    return [balanced(text, m.end() - 1) for m in re.finditer(re.escape(opener) + r"\s*\{", text)]


class WatchStreamsTest(unittest.TestCase):
    def test_every_watch_stream_also_reads_stderr(self):
        # mango 0.17.5 writes `mmsg watch` snapshots to stderr: a stream that only
        # reads stdout leaves the bar without tags or windows, with no error.
        text = (ROOT / "services/Mango.qml").read_text()
        watches = [b for b in blocks(text, "Process") if '"watch"' in b]
        self.assertGreaterEqual(len(watches), 2, "expected the all-monitors and all-clients streams")
        for body in watches:
            self.assertIn("stderr: SplitParser", body)
            stderr = body[body.index("stderr: SplitParser"):]
            self.assertIn('startsWith("{")', stderr, "stderr carries errors too: only JSON lines are state")


class NoFishTest(unittest.TestCase):
    def test_no_qml_launches_fish(self):
        offenders = []
        for folder in QML_DIRS:
            for path in (ROOT / folder).rglob("*.qml"):
                for number, line in enumerate(path.read_text().splitlines(), 1):
                    if re.search(r'["\']fish["\']', line):
                        offenders.append(f"{path.relative_to(ROOT)}:{number}")
        self.assertEqual(offenders, [], "the target system has zsh, not fish")


if __name__ == "__main__":
    unittest.main()
