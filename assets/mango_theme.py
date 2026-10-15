#!/usr/bin/env python3
"""Generate application themes and add backed-up includes to existing configs."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
import tomllib


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text() == text:
        return
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        stream.write(text)
        temporary = Path(stream.name)
    temporary.replace(path)


def update_config(path, transform):
    if not path.exists() or path.is_symlink():
        return
    original = path.read_text()
    updated = transform(original)
    if updated == original:
        return
    backup = path.with_name(path.name + ".before-caelestia-theme")
    if not backup.exists():
        write(backup, original)
    write(path, updated)


def prepend_include(text, target):
    directive = f"include={target}"
    return text if directive in text.splitlines() else directive + "\n" + text


def alacritty_include(text, target):
    data = tomllib.loads(text)
    general = data.get("general", {})
    legacy = "import" in data and "import" not in general
    imports = list(data.get("import", []) if legacy else general.get("import", []))
    if str(target) in imports:
        return text
    imports.append(str(target))
    declaration = "import = " + json.dumps(imports) + "\n"
    # Replace a complete import assignment, including multiline arrays, only
    # within its owning section. Validate the result before touching the file.
    if legacy:
        start = 0
    else:
        match = re.search(r"(?m)^\[general\]\s*$", text)
        if not match:
            result = text.rstrip() + "\n\n[general]\n" + declaration
            tomllib.loads(result)
            return result
        start = match.end()
    following = re.search(r"(?m)^\[", text[start:])
    end = start + following.start() if following else len(text)
    section = text[start:end]
    match = re.search(r"(?ms)^import\s*=\s*\[.*?\][^\n]*\n?", section)
    if match:
        section = section[:match.start()] + declaration + section[match.end():]
    else:
        section = "\n" + declaration + section
    result = text[:start] + section + text[end:]
    tomllib.loads(result)
    return result


def apply_theme(palette, config):
    c = palette["colours"]
    required = {"surface", "onSurface", "primary", "onPrimary", "error", "tertiary", "secondary", "primaryContainer", "onPrimaryContainer", "tertiaryContainer", "surfaceContainer"}
    if not required.issubset(c):
        raise ValueError("Incomplete application theme palette")
    # Validate before rendering text into other applications' config files.
    if any(not re.fullmatch(r"[0-9a-fA-F]{6}", value) for value in c.values()):
        raise ValueError("Invalid theme colour")
    bg, fg, accent = c["surface"], c["onSurface"], c["primary"]
    defaults = [bg, c["error"], c["tertiary"], c["secondary"], accent, c["primaryContainer"], c["tertiaryContainer"], fg]
    # Bright black is the colour of comments and shell suggestions: never the surface itself.
    defaults += [c.get("outline", fg)] + defaults[1:]
    ansi = [c.get(f"term{i}", defaults[i]) for i in range(16)]
    directory = config / "caelestia/themes"
    write(directory / "gtk.css", "\n".join(f"@define-color {name} #{value};" for name, value in {
        "accent_color": accent, "accent_bg_color": accent, "accent_fg_color": c["onPrimary"],
        "window_bg_color": bg, "window_fg_color": fg, "view_bg_color": c["surfaceContainer"], "view_fg_color": fg,
        "theme_bg_color": bg, "theme_fg_color": fg, "theme_selected_bg_color": accent,
        "theme_selected_fg_color": c["onPrimary"],
    }.items()) + "\n")
    names = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
    terminal = f'[colors.primary]\nbackground = "#{bg}"\nforeground = "#{fg}"\n'
    for section in ["normal", "bright"]:
        terminal += f"[colors.{section}]\n" + "".join(f'{name} = "#{value}"\n' for name, value in zip(names, ansi[:8] if section == "normal" else ansi[8:]))
    write(directory / "alacritty.toml", terminal)
    write(directory / "kitty.conf", f"background #{bg}\nforeground #{fg}\ncursor #{accent}\n" + "".join(f"color{i} #{ansi[i]}\n" for i in range(16)))
    write(directory / "foot.ini", f"[colors]\nbackground={bg}\nforeground={fg}\n" + "".join(f"{kind}{i}={value}\n" for kind in ["regular", "bright"] for i, value in enumerate(ansi[:8] if kind == "regular" else ansi[8:])))
    write(directory / "fuzzel.ini", f"[colors]\nbackground={bg}ff\ntext={fg}ff\nmatch={accent}ff\nselection={c['primaryContainer']}ff\nselection-text={c['onPrimaryContainer']}ff\nborder={accent}ff\n")
    write(config / "btop/themes/caelestia.theme", f'theme[main_bg]="#{bg}"\ntheme[main_fg]="#{fg}"\ntheme[title]="#{accent}"\ntheme[hi_fg]="#{accent}"\n')
    # Existing preferences retain precedence; includes only supply palette keys.
    for app in ["gtk-3.0", "gtk-4.0"]:
        css = config / app / "gtk.css"
        css.parent.mkdir(parents=True, exist_ok=True)
        if not css.exists(): write(css, "")
        directive = f'@import url("{directory / "gtk.css"}");'
        update_config(css, lambda text: text if directive in text else directive + "\n" + text)
    for app, filename in [("alacritty", "alacritty.toml"), ("kitty", "kitty.conf"), ("foot", "foot.ini"), ("fuzzel", "fuzzel.ini"), ("btop", "btop.conf")]:
        path = config / app / filename
        if shutil.which(app) and not path.exists() and not path.is_symlink():
            write(path, "")
    update_config(config / "alacritty/alacritty.toml", lambda text: alacritty_include(text, directory / "alacritty.toml"))
    update_config(config / "kitty/kitty.conf", lambda text: text if str(directory / "kitty.conf") in text else text.rstrip() + f"\ninclude {directory / 'kitty.conf'}\n")
    for app in ["foot", "fuzzel"]:
        update_config(config / app / f"{app}.ini", lambda text, app=app: prepend_include(text, directory / f"{app}.ini"))
    update_config(config / "btop/btop.conf", lambda text: re.sub(r'(?m)^color_theme\s*=.*$', 'color_theme = "caelestia"', text) if re.search(r'(?m)^color_theme\s*=', text) else text + '\ncolor_theme = "caelestia"\n')


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scheme_file", nargs="?")
    parser.add_argument("--palette-json")
    args = parser.parse_args()
    apply_theme(json.loads(args.palette_json) if args.palette_json else json.loads(Path(args.scheme_file).read_text()), Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")))
