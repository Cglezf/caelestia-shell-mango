#!/usr/bin/env python3
"""Add optional Mango installation settings without replacing existing bindings."""
import argparse
import os
from pathlib import Path
import re
import sys
import tempfile
import time

DEFAULT_BINDINGS = Path("/etc/xdg/quickshell/caelestia/assets/mango-keybinds.conf")


def binding_key(kind, value, mode):
    parts = value.split(",")
    if len(parts) < 3:
        return None
    aliases = {"CTRL": "CONTROL", "SUPER": "LOGO", "MOD4": "LOGO", "ALT": "MOD1", "NONE": ""}
    modifiers = sorted(filter(None, (aliases.get(m.upper(), m.upper()) for m in parts[0].strip().split("+"))))
    family = "bindr" if kind.startswith("bind") and "r" in kind[4:] else "bind" if kind.startswith("bind") else "mousebind" if kind.startswith("mousebind") else "axisbind"
    return mode, family, "+".join(modifiers), parts[1].strip().lower()


def is_binding(kind):
    return kind.startswith(("bind", "mousebind", "axisbind"))


def lookup(bindings, key):
    return bindings.get(key) or bindings.get(("common", *key[1:]))


def snapshot_without_bindings(path, desired, mode="default", stack=None):
    """Expand plain-conf sources into a local snapshot, removing only profile keys."""
    stack = set() if stack is None else stack
    path = path.expanduser().resolve()
    if path in stack or path.suffix == ".toml":
        raise ValueError(f"Cannot snapshot cyclic or TOML source: {path}")
    stack.add(path)
    lines = []
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if "=" not in line:
            lines.append(raw)
            continue
        kind, value = (part.strip() for part in line.split("=", 1))
        if kind == "key_mode":
            mode = value
        if kind in ("source", "source_optional"):
            child = Path(os.path.expandvars(value.strip('"\''))).expanduser()
            child = child if child.is_absolute() else path.parent / child
            if not child.exists() and kind == "source_optional":
                continue
            if child.suffix == ".toml":
                raise ValueError(f"TOML sources need declarative migration: {child}")
            found, _, child_mode = scan(child, mode=mode)
            affected = any(key in desired or (key[0] == "common" and ("default", *key[1:]) in desired) for key in found)
            if affected:
                content, mode = snapshot_without_bindings(child, desired, mode, stack)
                lines += [f"# Snapshot of {child}", content]
            else:
                # Keep dynamic rule fragments and unrelated sources live.
                if not child.is_file():
                    raise ValueError(f"Missing source: {child}")
                lines.append(f"{kind}={child.resolve()}")
                mode = child_mode
        elif is_binding(kind):
            key = binding_key(kind, value, mode)
            match = ("default", *key[1:]) if key and key[0] == "common" else key
            if match not in desired:
                lines.append(raw)
        else:
            lines.append(raw)
    stack.remove(path)
    return "\n".join(lines), mode


def scan(path, seen=None, mode="default"):
    seen = set() if seen is None else seen
    path = path.expanduser().resolve()
    if path in seen or not path.is_file():
        return {}, False, mode
    seen.add(path)
    bindings, autostart = {}, False
    for number, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if "=" not in line:
            continue
        kind, value = (part.strip() for part in line.split("=", 1))
        if kind == "key_mode":
            mode = value
        elif kind in ("source", "source_optional"):
            child = Path(os.path.expandvars(value.strip('"\''))).expanduser()
            found, started, mode = scan(child if child.is_absolute() else path.parent / child, seen, mode)
            bindings.update(found)
            autostart |= started
        elif is_binding(kind):
            key = binding_key(kind, value, mode)
            if key:
                action = [part.strip() for part in value.split(",")[2:]]
                while action and not action[-1]:
                    action.pop()
                bindings[key] = (",".join(action), path, number)
        elif kind == "exec_once" and re.search(r"\bqs\s+-c\s+caelestia\b|\bcaelestia\s+shell\b", value):
            autostart = True
    return bindings, autostart, mode


def write_backup(path, text):
    if path.exists() and path.read_text() == text:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        backup = path.with_name(f"{path.name}.before-caelestia-{time.time_ns()}")
        with os.fdopen(os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w") as stream:
            stream.write(path.read_text())
        print(f"Backup: {backup}")
    # Replace atomically so Mango never reads a partially written configuration.
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, prefix=f".{path.name}.caelestia-", delete=False) as stream:
        stream.write(text)
        temporary = Path(stream.name)
    try:
        if path.exists():
            temporary.chmod(path.stat().st_mode & 0o777)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def configure(config, bindings_file, keybinds=False, autostart=False, replace_conflicts=False, tags=None, dry_run=False):
    if config.is_symlink() or config.suffix == ".toml":
        raise ValueError("Managed/symlink or TOML config: add shortcuts and autostart declaratively; see README.md")
    existing, started, mode = scan(config)
    original = config.read_text() if config.exists() else "source=/etc/mango/config.conf\n"
    # When creating a config, check system defaults that the new source will inherit.
    if not config.exists():
        existing, started, mode = scan(Path("/etc/mango/config.conf"))
    additions = []
    if keybinds:
        desired, _, _ = scan(bindings_file)
        if not desired:
            raise ValueError(f"No installed bindings found in {bindings_file}")
        conflicts = [key for key, action in desired.items() if lookup(existing, key) and lookup(existing, key)[0] != action[0]]
        if conflicts and not replace_conflicts:
            details = [f"{key[2]}+{key[3]} ({key[1]}, mode {key[0]}) at {lookup(existing, key)[1]}:{lookup(existing, key)[2]}" for key in conflicts]
            raise ValueError("Existing key conflicts; no configuration was changed:\n  " + "\n  ".join(details))
        if conflicts:
            original, mode = snapshot_without_bindings(config if config.exists() else Path("/etc/mango/config.conf"), desired)
            existing = {key: action for key, action in existing.items() if key not in desired and ("default", *key[1:]) not in desired}
        for raw in bindings_file.read_text().splitlines():
            if "=" not in raw:
                continue
            kind, value = (part.strip() for part in raw.split("=", 1))
            if is_binding(kind) and not lookup(existing, binding_key(kind, value, "default")):
                additions.append(raw)
        if additions:
            additions = ["key_mode=default", *additions, f"key_mode={mode}"]
    if autostart and not started:
        additions.append("exec_once=qs -c caelestia")
    if tags is not None:
        counts = re.findall(r"^tag_num\s*=\s*(\d+)\s*$", original, re.MULTILINE)
        if not counts or int(counts[-1]) != tags:
            additions.append(f"tag_num={tags}")
    if additions:
        if dry_run:
            print(f"Would update {config}; no files changed.")
            return
        write_backup(config, original.rstrip() + "\n\n# Caelestia installer additions\n" + "\n".join(additions) + "\n")
        print(f"Updated: {config}")
    else:
        print("Requested Mango settings are already configured.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keybinds", action="store_true")
    parser.add_argument("--autostart", action="store_true")
    parser.add_argument("--bindings-file", type=Path, default=DEFAULT_BINDINGS)
    parser.add_argument("--replace-conflicts", action="store_true", help="Back up config and snapshot its sources, replacing only selected profile keys")
    parser.add_argument("--tags", type=int, choices=range(1, 32), help="Set Mango tag count (1–31)")
    parser.add_argument("--check", action="store_true", help="Report conflicts/planned changes without writing files")
    args = parser.parse_args()
    folder = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "mango"
    config = Path(os.environ["CAELESTIA_MANGO_CONFIG"]).expanduser() if os.environ.get("CAELESTIA_MANGO_CONFIG") else next(
        (p for p in [folder / "config.conf", folder / "config.toml"] if p.exists()), folder / "config.conf")
    configure(config, args.bindings_file, args.keybinds, args.autostart, args.replace_conflicts, args.tags, args.check)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        print(f"Mango setup: {error}", file=sys.stderr)
        sys.exit(1)
