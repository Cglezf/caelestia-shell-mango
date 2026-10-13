#!/usr/bin/env python3
"""Generate a Caelestia palette without running Matugen templates or hooks."""
import argparse
import json
import re
import subprocess
import sys

VARIANTS = {name: "scheme-" + value for name, value in {
    "tonalspot": "tonal-spot", "vibrant": "vibrant", "expressive": "expressive",
    "fidelity": "fidelity", "content": "content", "fruitsalad": "fruit-salad",
    "rainbow": "rainbow", "neutral": "neutral", "monochrome": "monochrome",
}.items()}


def convert(data, mode, variant):
    colours = {}
    source = data["colors"]
    # Matugen 4 nests modes under each role; older releases nest roles under modes.
    if mode in source:
        source = source[mode]
    for name, value in source.items():
        if isinstance(value, dict):
            value = value.get(mode, value)
        if isinstance(value, dict):
            value = value.get("color")
        if not isinstance(value, str) or not re.fullmatch(r"#?[0-9a-fA-F]{6}", value):
            continue
        role = re.sub(r"_([a-z])", lambda match: match[1].upper(), name)
        # Caelestia retains underscores in palette key roles.
        if name.endswith("_palette_key_color"):
            role = name.removesuffix("_palette_key_color") + "_paletteKeyColor"
        colours[role] = value.removeprefix("#")
    if not {"primary", "surface", "onSurface"}.issubset(colours):
        raise ValueError("Matugen returned an incomplete palette")
    # Success roles are Caelestia extensions, absent from standard Material palettes.
    for role, fallback in {"success": "tertiary", "onSuccess": "onTertiary",
                           "successContainer": "tertiaryContainer", "onSuccessContainer": "onTertiaryContainer"}.items():
        colours[role] = colours[fallback]
    return {"name": "dynamic", "flavour": "default", "mode": mode, "variant": variant, "colours": colours}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image")
    parser.add_argument("--mode", choices=("dark", "light"), default="dark")
    parser.add_argument("--variant", choices=VARIANTS, default="tonalspot")
    args = parser.parse_args()
    result = subprocess.run(["matugen", "--dry-run", "--json", "hex", "--mode", args.mode,
                             "--type", VARIANTS[args.variant], "image", args.image,
                             "--prefer", "saturation"], capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Matugen generation failed")
    print(json.dumps(convert(json.loads(result.stdout), args.mode, args.variant)))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Palette generation failed: {error}", file=sys.stderr)
        sys.exit(1)
