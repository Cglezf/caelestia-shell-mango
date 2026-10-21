"""Run real QML services with fake mmsg, without changing the desktop.

Requires Quickshell and built Caelestia modules in build/qml.
Run: python3 tests/check_mango_service.py
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MOCK_MMSG = """#!/usr/bin/python3
import json
import os
import sys
import time

if sys.argv[1] == "dispatch":
    with open(os.environ["MANGO_TEST_LOG"], "a") as stream:
        stream.write(sys.argv[2] + "\\n")
    print(json.dumps({"success": True}), flush=True)
elif sys.argv[1] == "watch":
    time.sleep(30)
else:
    print("{}")
"""


def main():
    with tempfile.TemporaryDirectory(prefix="mango-service-") as folder:
        directory = Path(folder)
        sources = {
            "services": ["Mango.qml", "Hypr.qml", "GameMode.qml"],
            "utils": ["Paths.qml", "MangoModel.js"],
            "assets": ["mango_options.py"],
        }
        for name, files in sources.items():
            (directory / name).mkdir()
            for file in files:
                shutil.copy(ROOT / name / file, directory / name / file)
        (directory / "bin").mkdir()
        mock = directory / "bin/mmsg"
        mock.write_text(MOCK_MMSG)
        mock.chmod(0o755)
        shutil.copy(ROOT / "tests/mango-service-check.qml", directory / "shell.qml")
        environment = {
            **os.environ,
            "PATH": str(directory / "bin") + ":" + os.environ["PATH"],
            "MANGO_TEST_ROOT": str(directory),
            "MANGO_TEST_LOG": str(directory / "dispatch.log"),
            "QML_IMPORT_PATH": str(ROOT / "build/qml"),
            "QT_QPA_PLATFORM": "offscreen",
            "XDG_CONFIG_HOME": str(directory / "config"),
            "XDG_STATE_HOME": str(directory / "state"),
            "XDG_CACHE_HOME": str(directory / "cache"),
            "PYTHONDONTWRITEBYTECODE": "1",
        }
        result = subprocess.run(
            ["qs", "-p", str(directory), "--no-color"], env=environment,
            text=True, capture_output=True, timeout=30, check=True,
        )
        output = result.stdout + result.stderr
        assert "MANGO_SERVICE_PASS" in output and "Error:" not in output, output
        dispatched = (directory / "dispatch.log").read_text().splitlines()
        assert [command for command in dispatched if not command.startswith("setoption,")] == [
            "focusmon,right", "toggle_special_tag", "reload_config",
        ], dispatched
        assert dispatched.count("setoption,animations,0") == 3, dispatched
        print("QML service checks passed: visibility, monitor targeting, reloads and game-mode restoration.")


if __name__ == "__main__":
    main()
