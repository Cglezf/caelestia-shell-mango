#!/usr/bin/env python3
"""Load bundled and user-defined palettes without the Caelestia CLI."""
import argparse
import json
import os
from pathlib import Path


def catalog():
    result = json.loads(Path(__file__).with_name("mango-schemes.json").read_text())
    directory = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "caelestia/schemes"
    for path in sorted(directory.glob("*.json")):
        try:
            palette = json.loads(path.read_text())
            result.setdefault(palette["name"], {}).setdefault(palette.get("flavour", "default"), {})[palette["mode"]] = palette["colours"]
        except (ValueError, KeyError, OSError):
            continue
    return result


def select(name, flavour, mode):
    modes = catalog()[name][flavour]
    selected = mode if mode in modes else next(iter(modes))
    return {"name": name, "flavour": flavour, "mode": selected, "variant": "tonalspot", "colours": modes[selected]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("list", "get"))
    parser.add_argument("name", nargs="?")
    parser.add_argument("flavour", nargs="?", default="default")
    parser.add_argument("mode", nargs="?", default="dark")
    args = parser.parse_args()
    if args.action == "get":
        print(json.dumps(select(args.name, args.flavour, args.mode)))
    else:
        result = {name: {flavour: modes.get("dark", next(iter(modes.values()))) for flavour, modes in flavours.items()} for name, flavours in catalog().items()}
        result["dynamic"] = {"default": {}}
        print(json.dumps(result))
