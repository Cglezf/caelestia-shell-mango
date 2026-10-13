#!/usr/bin/env python3
"""Read numeric Mango config options needed for shell geometry and game mode."""
import json
import os
from pathlib import Path
import tomllib

KEYS = {"animations", "layer_animations", "blur", "blur_layer", "shadows", "layer_shadows", "gap_inner_horizontal", "gap_inner_vertical", "gap_outer_horizontal", "gap_outer_vertical", "border_size", "border_radius", "allow_tearing"}


def read_config(path, seen=None):
    seen = set() if seen is None else seen
    path = path.expanduser().resolve()
    if path in seen or len(seen) > 50 or not path.is_file():
        return {}
    seen.add(path)
    result = {}
    if path.suffix == ".toml":
        options = tomllib.loads(path.read_text()).get("global", {})
        entries = list(options.items())
    else:
        entries = []
        for line in path.read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if "=" in line:
                entries.append(tuple(part.strip() for part in line.split("=", 1)))
    for key, value in entries:
        if key in ("source", "source_optional"):
            for source in value if isinstance(value, list) else [value]:
                child = Path(os.path.expandvars(str(source).strip('"\''))).expanduser()
                result.update(read_config(child if child.is_absolute() else path.parent / child, seen))
        elif key in KEYS:
            try:
                result[key] = float(value)
            except (TypeError, ValueError):
                pass
    return result


if __name__ == "__main__":
    folder = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "mango"
    path = Path(os.environ["CAELESTIA_MANGO_CONFIG"]).expanduser() if os.environ.get("CAELESTIA_MANGO_CONFIG") else next(
        (p for p in [folder / "config.conf", folder / "config.toml", Path("/etc/mango/config.conf")] if p.exists()), None)
    print(json.dumps(read_config(path) if path else {}))
