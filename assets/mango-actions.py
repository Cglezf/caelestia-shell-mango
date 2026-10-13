#!/usr/bin/env python3
"""Native Mango actions used by the optional Caelestia keybinding profile."""
import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import time


def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def query(name):
    return json.loads(subprocess.check_output(["mmsg", "get", name], text=True, timeout=5))


def dispatch(action, *args):
    result = run(["mmsg", "dispatch", ",".join([action, *map(str, args)])], capture_output=True, text=True, timeout=5)
    payload = json.loads(result.stdout)
    if not payload.get("success"):
        raise ValueError(payload.get("error", "Mango rejected the action"))


def workspace_target(current, count, kind, value):
    if kind not in ("slot", "group", "relative") or (kind != "relative" and not 1 <= value <= 10):
        raise ValueError("Workspace slots/groups must be 1–10")
    if kind == "slot":
        target = ((current - 1) // 10) * 10 + value
    elif kind == "group":
        target = (value - 1) * 10 + (current - 1) % 10 + 1
    else:
        target = current + value
    if not 1 <= target <= count:
        raise ValueError(f"Tag {target} is outside the configured 1–{count} range; adjust tag_num in Mango")
    return target


def active_monitor():
    monitors = query("all-monitors")["monitors"]
    return next(m for m in monitors if m.get("active"))


def active_client():
    return next(c for c in query("all-clients")["clients"] if c.get("is_focused"))


def ipc(target, action, *args):
    run(["qs", "ipc", "-c", "caelestia", "call", target, action, *args])


def clipboard(delete=False, latest=False):
    entries = subprocess.check_output(["cliphist", "list"])
    if not entries.strip():
        return
    if latest:
        chosen = entries.splitlines()[0] + b"\n"
    else:
        result = subprocess.run(["fuzzel", "--dmenu", "--prompt", "Delete > " if delete else "Clipboard > "], input=entries, capture_output=True)
        if result.returncode or not result.stdout.strip():
            return
        chosen = result.stdout
    if delete:
        run(["cliphist", "delete"], input=chosen)
        return
    decoded = subprocess.check_output(["cliphist", "decode"], input=chosen)
    run(["wl-copy"], input=decoded)
    if latest:
        time.sleep(0.25)
        # Real paste key event preserves multiline/binary clipboard contents.
        run(["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("workspace", "special-out", "group-toggle", "normalize", "pip", "screenshot", "clipboard", "clipboard-delete", "clipboard-latest", "emoji", "colour", "app", "restart", "kill"))
    parser.add_argument("args", nargs="*")
    options = parser.parse_args()
    action, args = options.action, options.args
    if action == "workspace":
        operation, kind, number = args
        monitor = active_monitor()
        current = next((t for t in monitor.get("active_tags", []) if t > 0), 1)
        target = workspace_target(current, monitor.get("tag_num", 9), kind, int(number))
        dispatch("tag" if operation == "move" else "view", target)
    elif action == "group-toggle":
        client = active_client()
        grouped = client.get("is_group")
        dispatch("groupleave" if grouped else "groupjoin", *([] if grouped else ["right"]), "client", client["id"])
    elif action == "special-out":
        client = active_client()
        if 0 in client.get("tags", []):
            dispatch("tag_special_tag", "client", client["id"])
    elif action in ("normalize", "pip"):
        client, monitor = active_client(), active_monitor()
        if not client.get("is_floating"):
            dispatch("togglefloating", "client", client["id"])
        width = int(monitor["width"] * (0.3 if action == "pip" else 0.55))
        height = int(monitor["height"] * (0.3 if action == "pip" else 0.7))
        dispatch("resizewin", width, height, "client", client["id"])
        if action == "pip":
            if not client.get("is_global"):
                dispatch("toggleglobal", "client", client["id"])
            dispatch("movewin", monitor["x"] + monitor["width"] - width - 24, monitor["y"] + monitor["height"] - height - 24, "client", client["id"])
        else:
            dispatch("centerwin", "client", client["id"])
    elif action == "screenshot":
        folder = Path(os.environ.get("CAELESTIA_SCREENSHOTS_DIR", Path.home() / "Pictures/Screenshots"))
        folder.mkdir(parents=True, exist_ok=True)
        image = subprocess.check_output(["grim", "-o", active_monitor()["name"], "-"])
        destination = folder / f"screenshot_{time.time_ns()}.png"
        destination.write_bytes(image)
        run(["wl-copy", "--type", "image/png"], input=image)
    elif action.startswith("clipboard"):
        clipboard(delete=action == "clipboard-delete", latest=action == "clipboard-latest")
    elif action == "emoji":
        # CLI emoji picker has no compositor dependency and ships the searchable data.
        run(["caelestia", "emoji", "-p"])
    elif action == "colour":
        result = subprocess.run(["hyprpicker", "--format", "hex"], capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip():
            run(["wl-copy"], input=result.stdout.strip(), text=True)
    elif action == "app":
        defaults = {"terminal": "foot", "browser": "firefox", "editor": "codium", "files": "thunar", "audio": "pwvucontrol"}
        command = shlex.split(os.environ.get("CAELESTIA_APP_" + args[0].upper(), defaults[args[0]]))
        if not command or not shutil.which(command[0]):
            raise ValueError(f"Install {command[0] if command else args[0]} or set CAELESTIA_APP_{args[0].upper()}")
        os.execvp(command[0], command)
    elif action in ("kill", "restart"):
        instances = subprocess.run(["qs", "list", "-c", "caelestia", "--json"], capture_output=True, text=True)
        data = json.loads(instances.stdout) if instances.stdout.lstrip().startswith("[") else []
        for instance in data:
            run(["qs", "kill", "-c", "caelestia", "--pid", str(instance["pid"])])
        if action == "restart":
            for _ in range(50):
                if all(not Path(f"/proc/{instance['pid']}").exists() for instance in data):
                    break
                time.sleep(0.1)
            else:
                raise ValueError("Old shell is still shutting down; restart cancelled")
            run(["qs", "-c", "caelestia", "-d", "-n"])


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, StopIteration, subprocess.SubprocessError) as error:
        message = str(error) or "No active window/monitor"
        print(f"Caelestia keybinding: {message}", file=sys.stderr)
        # Local shell feedback for optional tools that are not installed.
        if shutil.which("qs"):
            try:
                subprocess.run(["qs", "ipc", "-c", "caelestia", "call", "toaster", "warn", "Shortcut unavailable", message, "keyboard"], check=False, timeout=5)
            except (OSError, subprocess.TimeoutExpired):
                pass
        sys.exit(1)
