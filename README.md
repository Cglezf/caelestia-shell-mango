<h1 align=center>caelestia-shell (MangoWC Port)</h1>

<div align=center>

![GitHub last commit](https://img.shields.io/github/last-commit/caelestia-dots/shell?style=for-the-badge&labelColor=101418&color=9ccbfb)
![GitHub Repo stars](https://img.shields.io/github/stars/caelestia-dots/shell?style=for-the-badge&labelColor=101418&color=b9c8da)
![GitHub repo size](https://img.shields.io/github/repo-size/caelestia-dots/shell?style=for-the-badge&labelColor=101418&color=d3bfe6)
[![Ko-Fi donate](https://img.shields.io/badge/donate-kofi?style=for-the-badge&logo=ko-fi&logoColor=ffffff&label=ko-fi&labelColor=101418&color=f16061&link=https%3A%2F%2Fko-fi.com%2Fsoramane)](https://ko-fi.com/soramane)
[![Discord invite](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fdiscordapp.com%2Fapi%2Finvites%2FBGDCFCmMBk%3Fwith_counts%3Dtrue&query=approximate_member_count&style=for-the-badge&logo=discord&logoColor=ffffff&label=discord&labelColor=101418&color=96f1f1&link=https%3A%2F%2Fdiscord.gg%2FBGDCFCmMBk)][discord]

</div>

https://github.com/user-attachments/assets/0840f496-575c-4ca6-83a8-87bb01a85c5f

## About This Fork

This is a community port of the beautiful Caelestia shell to work with **MangoWC compositor** instead of Hyprland! 🎉

The original shell was designed exclusively for Hyprland, but through some careful adaptation, it now runs smoothly on MangoWC while maintaining all the core functionality and gorgeous aesthetics that make Caelestia special.

**This is a personal project** that I'm actively maintaining and improving. If you find this port useful and want to support continued development and maintenance, I'd be grateful for any contributions! Beer money is always appreciated 🍺

<details>
<summary>Support via Cryptocurrency</summary>

If you'd like to buy me a beer (or coffee!) for the work on this port, here are my crypto addresses:

- **Bitcoin (BTC)**: `1C1CrcRjPCYXzoXYLtCg8Zu7e1DZ4nyKDL`
- **USDT (TRX)**: `TR4vtxKGmxYJsXQDF2sfLx8W6pztyZKWVT`
- **Ethereum (ETH ERC20)**: `0xeb2031515c8ddacc94e5d0ceba6d22016e6de3da`
- **BINANCE PAY ID**: `765117963`

Every contribution helps keep this project maintained and supports future improvements. Thank you! 🙏

</details>

### What Changed?

- **MangoWC Integration**: Complete rewrite of the compositor backend to use MangoWC's `mmsg` IPC instead of Hyprland's socket protocol
- **Window Management**: Workspace, monitor, and client state comes from persistent `mmsg watch` streams. Mango objects replace Hyprland-specific QML types.
- **Input Masking**: Carefully tuned Region-based input masks to maintain click-through transparency on the desktop while keeping panels and bars interactive
- **Blur Control**: Mango controls compositor blur. Caelestia's automatic Hyprland blur-rule updates are not translated; the no-blur rule below is optional.
- **Feature Adaptation**: Direct `gpu-screen-recorder` integration with MangoWC monitor output, plus native window previews through `grim -T`.

### Recent fixes

- Workspace clicks use `mmsg dispatch view,<tag>` so repeated switches work without a keyboard shortcut resetting combination state.
- Workspace indicators respect the compositor's tag count; window occupancy uses Mango client data.
- Fullscreen notification checks accept Mango monitor objects, and drawer clicks use the current screen state.
- The launcher acquires keyboard focus on open and refocuses search on subsequent opens. Focus requests wait for the Wayland window to be active and skip an already focused field. Mango keybinding examples call Quickshell directly.
- The network password dialog uses the current appearance tokens instead of the removed `Appearance` singleton.
- Missing application icons use a checked theme fallback or bundled application icon, including when `image-missing` itself is unavailable. Network tray icons retain a bundled network fallback.
- A missing `~/.face` keeps the dashboard and lock screen's person icon visible without repeated image warnings.
- First launch saves the built-in colour palette when `scheme.json` is missing. The launcher creates its database directory and falls back to memory if persistent storage cannot be opened.
- Native window previews use Mango's `foreign_toplevel_id` and `grim -T`, refresh while visible, and stop when closed. Hyprland special-workspace click actions remain disabled.

### What Still Works?

The following features are available:

- ✅ All panels (bar, dashboard, utilities, OSD, sidebar)
- ✅ Screen recording (fullscreen & region capture via `gpu-screen-recorder` + `slurp`)
- ✅ Hover detection and auto-hide behaviors
- ✅ Workspaces and window tracking
- ✅ Media controls (MPRIS)
- ✅ Network, battery, brightness, audio controls
- ✅ Launcher with app search
- ✅ Notification system
- ✅ Lock screen
- ✅ System tray
- ✅ Wallpaper management
- ✅ Color scheme switching

### What Doesn't Work (Yet)?

- Live window previews require Mango to expose `foreign_toplevel_id` and a version of `grim` with `-T` support. Older versions retain the preview fallback.
- Hyprland-style special workspaces are not implemented by this adapter.
- The compositor adapter currently uses the focused monitor for every screen. Full per-monitor workspace tracking is still limited.
- Notifications require Caelestia to own `org.freedesktop.Notifications`; another running notification server can prevent registration.

## Components

-   Widgets: [`Quickshell`](https://quickshell.outfoxxed.me)
-   Compositor: [`MangoWC`](https://github.com/mangowm/mango) (originally [`Hyprland`](https://hyprland.org))
-   Original Dots: [`caelestia`](https://github.com/caelestia-dots)

## Special Thanks

**Huge shoutout and massive thanks to [@Soramane](https://github.com/soramane)** and the entire Caelestia project for creating such an incredible, polished, and beautiful shell! This port wouldn't exist without their amazing work. If you love this shell, please consider [supporting them on Ko-Fi](https://ko-fi.com/soramane)! 💙

Also huge thanks to:
- [@outfoxxed](https://github.com/outfoxxed) for creating and maintaining Quickshell
- The MangoWC developers for building a solid wlroots compositor
- The Hyprland discord community for ongoing inspiration and help

## Installation

> [!IMPORTANT]
> This MangoWC port requires manual installation. The AUR package and Nix flake from the original project are **not compatible** with this fork as they're designed for Hyprland.

### Prerequisites for MangoWC

Before installing the shell, make sure you have MangoWC properly set up:

1. **MangoWC Compositor**: Install and configure MangoWC ([GitHub repo](https://github.com/mangowm/mango))
2. **Optional blur rule**: You do not need to disable Mango blur to install or run Caelestia.
   To keep Caelestia surfaces unblurred while retaining blur on other apps, add this to
   `~/.config/mango/config.conf` (or a rules file sourced by it):
   ```ini
   layer_rule=layer_name:caelestia.*,no_blur:1
   ```
   Omit this rule if you want compositor blur on the shell. Mango's `blur` and `blur_layer` settings
   control whether it is enabled; layer rules also support `blur_ignore_alpha` for transparent areas.
   This port does not currently synchronize Caelestia's transparency settings with Mango blur rules.
   See the [Mango layer-rule reference](https://mangowm.github.io/docs/window-management/rules/)
   and [blur settings](https://mangowm.github.io/docs/visuals/effects/).

### Manual Installation (MangoWC)

Dependencies:

-   [`caelestia-cli`](https://github.com/caelestia-dots/cli) (optional but recommended)
-   [`quickshell-git`](https://git.outfoxxed.me/quickshell/quickshell) - **must be the git version**, not the latest tagged version
-   `mangowc` - The MangoWC compositor with `mmsg` IPC support
-   `glibc`
-   `gcc-libs`
-   [`ddcutil`](https://github.com/rockowitz/ddcutil)
-   [`brightnessctl`](https://github.com/Hummer12007/brightnessctl)
-   [`app2unit`](https://github.com/Vladimir-csp/app2unit)
-   [`libcava`](https://github.com/LukashonakV/cava)
-   [`networkmanager`](https://gitlab.freedesktop.org/NetworkManager/NetworkManager)
-   [`lm_sensors`](https://github.com/lm-sensors/lm-sensors)
-   [`aubio`](https://github.com/aubio/aubio)
-   [`libpipewire`](https://github.com/PipeWire/pipewire)
-   [`libqalculate`](https://github.com/Qalculate/libqalculate)
-   [`power-profiles-daemon`](https://gitlab.freedesktop.org/upower/power-profiles-daemon)
-   [`ttf-material-symbols-variable`](https://github.com/google/material-design-icons)
-   [`ttf-rubik-vf`](https://github.com/googlefonts/rubik)
-   [`ttf-cascadia-code-nerd`](https://github.com/ryanoasis/nerd-fonts)
-   `qt6-base`
-   `qt6-declarative`
-   `qt6-imageformats`
-   [`qt6-m3shapes-git`](https://github.com/soramanew/m3shapes)
-   [`swappy`](https://github.com/jtheoof/swappy)
-   [`gpu-screen-recorder`](https://git.dec05eba.com/gpu-screen-recorder/) (for screen recording)
-   [`slurp`](https://github.com/emersion/slurp) (for region selection)
-   [`grim`](https://gitlab.freedesktop.org/emersion/grim) with `-T` support (for live window previews; check `grim -h`)
-   [`fish`](https://github.com/fish-shell/fish-shell)
-   [`bash`](https://www.gnu.org/software/bash)

Build dependencies:

- [`cmake`](https://gitlab.kitware.com/cmake/cmake)
- [`ninja`](https://github.com/ninja-build/ninja)
- `qt6-shadertools`
- `pkgconf` (provides `pkg-config`)

The plugin requires Qt **6.9 or newer** and development files for the libraries above.

### Build and install

Run these commands in a terminal inside your Mango session after installing the dependencies:

```sh
# Download this fork into your home directory.
git clone https://github.com/evoziosk/caelestia-shell-mango.git "$HOME/caelestia-shell-mango"
cd "$HOME/caelestia-shell-mango"

# Configure once, then compile using two jobs to keep memory usage modest.
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/
cmake --build build --parallel 2

# Install the shell and its compiled QML plugins; sudo may ask for your password.
sudo cmake --install build

# Start the installed shell.
qs -c caelestia
```

Already cloned this repository? Start at `cd` using your checkout's actual location and skip `git clone`.
On systems with enough memory, increase `--parallel 2` to build faster. If compilation is killed due to low memory, use `--parallel 1`.

The default install puts the shell in `/etc/xdg/quickshell/caelestia`, QML plugins in
`/usr/lib/qt6/qml`, and helper executables in `/usr/lib/caelestia`. Configure and build as your regular user;
only installation needs sudo. No username substitution or `XDG_CONFIG_HOME` setup is required.

For source changes, install the compiled plugins once, then preview your checkout with:

```sh
qs -p "$HOME/caelestia-shell-mango/shell.qml"
```

Stop the other Caelestia instance before previewing. Changes to C++ plugins require rebuilding,
installing, and restarting Quickshell; editing QML alone can be previewed from the checkout.

> [!TIP]
> CMake also accepts `INSTALL_LIBDIR`, `INSTALL_QMLDIR`, and `INSTALL_QSCONFDIR` to override installation paths.
> If you change `INSTALL_LIBDIR`, set `CAELESTIA_LIB_DIR` to the same absolute directory in your session.
> A config at `${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia` takes precedence over the system config;
> an old copy there can hide newly installed fixes. Use `qs -p /etc/xdg/quickshell/caelestia/shell.qml`
> to explicitly launch the system installation.

## Usage

The shell can be started via `qs -c caelestia` or by launching Quickshell with the config path.

### Starting with MangoWC

To autostart the shell with MangoWC, add this to your MangoWC config:

```
exec_once= qs -c caelestia
```

Or if using caelestia-cli:

```
exec_once= caelestia shell -d
```

### Shortcuts/IPC

> [!NOTE]
> MangoWC doesn't support Hyprland's global shortcuts via DBus. You'll need to configure keybinds directly in your MangoWC config using `mmsg` commands or by invoking the caelestia CLI.

The shell does not automatically register Mango keybindings. Add these to `~/.config/mango/config.conf`:

```ini
# Tap Super to toggle the launcher; Super+Space also works.
bindr=SUPER,Super_L,spawn,qs ipc -c caelestia call drawers toggle launcher
bindr=SUPER,Super_R,spawn,qs ipc -c caelestia call drawers toggle launcher
bind=SUPER,space,spawn,qs ipc -c caelestia call drawers toggle launcher

bind=SUPER,d,spawn,qs ipc -c caelestia call drawers toggle dashboard
bind=SUPER,u,spawn,qs ipc -c caelestia call drawers toggle utilities
bind=SUPER,l,spawn,qs ipc -c caelestia call lock lock
```

These commands use Quickshell directly and do not require `caelestia-cli`. A ready-to-source copy is in
[`assets/mango-keybinds.conf`](assets/mango-keybinds.conf). Remove conflicting bindings for the same keys,
and reload Mango with `mmsg dispatch reload_config`. Super-only bindings run on key release;
see [Mango's modifier-key binding syntax](https://mangowm.github.io/docs/bindings/keys/).
If you prefer only Super+Space, omit the two `bindr` lines.

If you have no user config and Mango uses `/etc/mango/config.conf`, preserve those defaults by starting
`~/.config/mango/config.conf` with `source=/etc/mango/config.conf`, then add the bindings above.
The launcher requests keyboard focus and focuses its search field whenever opened, including through IPC.

All IPC commands can be accessed via `caelestia shell ...` if you have caelestia-cli installed. For example:

```sh
caelestia shell mpris getActive trackTitle
```

You can view the list of available IPC commands by running `caelestia shell -s`.

### PFP/Wallpapers

The dashboard and lock screen read the profile picture from `~/.face`. If it does not exist, they show a person icon. You can set it by clicking it in the dashboard,
or by manually copying or symlinking your image to the path.

The wallpapers for the wallpaper switcher are read from `~/Pictures/Wallpapers`
by default. To change it, modify `paths.wallpaperDir` in `~/.config/caelestia/shell.json`.

To set the wallpaper, you can type `>wallpaper` in the launcher to open the wallpaper switcher.
Alternatively, you can also use `caelestia wallpaper -f <path_to_wallpaper>` to set the wallpaper directly.
Use `caelestia wallpaper -h` for more info about this command.

## Updating

From your checkout, pull updates, reconfigure, rebuild, and install:

```sh
cd "$HOME/caelestia-shell-mango"
git pull --ff-only
cmake -S . -B build
cmake --build build --parallel 2
sudo cmake --install build
```

Reconfiguration keeps your existing installation settings and refreshes build metadata.
If Git reports local changes or divergent history, resolve those before updating.
Stop the running Caelestia instance with Ctrl+C in its terminal, then run `qs -c caelestia` again.
Restart after updates to compiled plugins as well as QML files.

## Configuring

All configuration options belong in `~/.config/caelestia/shell.json`. This file is _not_ created by
default; you must create it manually. Options that you omit from the config file will use their default
values.

### Per-monitor configuration

You can configure per-monitor options in `~/.config/caelestia/monitors/<monitor_name>/shell.json`.
List the names of your available monitors by running:

```sh
mmsg get all-monitors | jq -r '.monitors[].name'
```

Options set in these files will **override** the respective options in the global config. Any options not present in
per-monitor configs will inherit their values from the global config.

For example, to automatically hide the bar on the monitor named `DP-1`:

**`~/.config/caelestia/monitors/DP-1/shell.json`**

```json
{
    "bar": {
        "persistent": false
    }
}
```

> [!NOTE]
> Not all options respect per-monitor overrides. Most notably, the following options will only read
> from the global config, and ignore the respective option in per-monitor config files.
>
> <details><summary>Ignored options</summary>
>
> - `appearance`: `anim.*`, `transparency.*`
> - `bar.tray`: `hiddenIcons`, `iconSubs`
> - `bar.workspaces`: `ignoredTags`, `specialWorkspaceIcons`, `windowIcons`, `workspaceIcons`
> - `dashboard`: `mediaUpdateInterval`, `resourceUpdateInterval`
> - `general`: `apps.*`, `battery.*`, `idle.*`, `logo`
> - `launcher`: `actionPrefix`, `actions`, `enableDangerousActions`, `favouriteApps`, `hiddenApps`, `specialPrefix`, `useFuzzy.*`, `vimKeybinds`
> - `lock`: `enableFprint`, `enableHowdy`, `maxFprintTries`, `maxHowdyTries`, `triggerHowdyOnWake`
> - `nexus`: `networkRescanInterval`
> - `notifs`: `actionOnClick`, `defaultExpireTimeout`, `expire`, `fullscreen`, `fullscreenExpireTimeout`
> - `paths`: `lyricsDir`, `wallpaperDir`
> - `services`: `audioIncrement`, `brightnessIncrement`, `clockFormat`, `dataUnits`, `defaultPlayer`, `gpuType`, `lyricsBackend`, `maxVolume`, `playerAliases`, `sensorUnits`, `smartScheme`, `visualiserBars`, `weatherLocation`, `weatherUnits`
> - `utilities`: `toasts.*`, `vpn.*`
>
> </details>

### Example configuration

> [!WARNING]
> The example configuration includes **ALL** configuration options in `shell.json`. It is
> **not** recommended to copy and paste this entire configuration into `shell.json`,
> as options or their default values may change across updates, resulting in a stale config.
>
> This is meant to serve as a reference of all the available options, and you should
> <ins>only add the ones you want to change</ins> to `shell.json`.

<details><summary>Example config</summary>

```json
{
    "enabled": true,
    "appearance": {
        "deformScale": 1,
        "rounding": {
            "scale": 1
        },
        "spacing": {
            "scale": 1
        },
        "padding": {
            "scale": 1
        },
        "font": {
            "scale": 1,
            "clock": "Rubik",
            "workspaces": "Rubik",
            "headline": {
                "family": "GoogleSansFlex",
                "large": {
                    "size": 32,
                    "weight": 500,
                    "italic": false,
                    "vaxes": { "ROND": 25 }
                },
                "medium": {
                    "size": 28,
                    "weight": 500,
                    "italic": false,
                    "vaxes": { "ROND": 25 }
                },
                "small": {
                    "size": 24,
                    "weight": 500,
                    "italic": false,
                    "vaxes": { "ROND": 25 }
                }
            },
            "title": {
                "family": "GoogleSansFlex",
                "large": {
                    "size": 22,
                    "weight": 500,
                    "italic": false,
                    "vaxes": { "ROND": 25 }
                },
                "medium": {
                    "size": 16,
                    "weight": 500,
                    "italic": false,
                    "vaxes": { "ROND": 25 }
                },
                "small": {
                    "size": 14,
                    "weight": 500,
                    "italic": false,
                    "vaxes": { "ROND": 25 }
                }
            },
            "body": {
                "family": "GoogleSansFlex",
                "large": {
                    "size": 16,
                    "weight": 400,
                    "italic": false,
                    "vaxes": { "ROND": 25 }
                },
                "medium": {
                    "size": 14,
                    "weight": 400,
                    "italic": false,
                    "vaxes": { "ROND": 25 }
                },
                "small": {
                    "size": 12,
                    "weight": 400,
                    "italic": false,
                    "vaxes": { "ROND": 25 }
                }
            },
            "label": {
                "family": "GoogleSansFlex",
                "large": {
                    "size": 14,
                    "weight": 500,
                    "italic": false,
                    "vaxes": { "ROND": 25 }
                },
                "medium": {
                    "size": 12,
                    "weight": 500,
                    "italic": false,
                    "vaxes": { "ROND": 25 }
                },
                "small": {
                    "size": 11,
                    "weight": 400,
                    "italic": false,
                    "vaxes": { "ROND": 25 }
                }
            },
            "mono": {
                "family": "CaskaydiaCove NF",
                "large": {
                    "size": 16,
                    "weight": 400,
                    "italic": false,
                    "vaxes": {}
                },
                "medium": {
                    "size": 14,
                    "weight": 400,
                    "italic": false,
                    "vaxes": {}
                },
                "small": {
                    "size": 12,
                    "weight": 400,
                    "italic": false,
                    "vaxes": {}
                }
            },
            "icon": {
                "family": "Material Symbols Rounded",
                "extraLarge": {
                    "size": 36,
                    "weight": 400,
                    "italic": false,
                    "vaxes": {}
                },
                "large": {
                    "size": 24,
                    "weight": 400,
                    "italic": false,
                    "vaxes": {}
                },
                "medium": {
                    "size": 18,
                    "weight": 400,
                    "italic": false,
                    "vaxes": {}
                },
                "small": {
                    "size": 15,
                    "weight": 400,
                    "italic": false,
                    "vaxes": {}
                }
            }
        },
        "anim": {
            "durations": {
                "scale": 1
            }
        },
        "transparency": {
            "enabled": false,
            "base": 0.85,
            "layers": 0.4
        }
    },
    "general": {
        "logo": "",
        "showOverFullscreen": false,
        "mediaGifSpeedAdjustment": 300,
        "sessionGifSpeed": 0.7,
        "apps": {
            "terminal": ["foot"],
            "audio": ["pwvucontrol"],
            "playback": ["mpv"],
            "explorer": ["thunar"]
        },
        "idle": {
            "lockBeforeSleep": true,
            "inhibitWhenAudio": true,
            "inhibitWhenCharging": false,
            "timeouts": [
                {
                    "timeout": 180,
                    "idleAction": "lock",
                    "inhibitWhenAudio": false,
                    "inhibitWhenCharging": false,
                    "respectInhibitors": true
                },
                {
                    "timeout": 300,
                    "idleAction": "dpms off",
                    "returnAction": "dpms on"
                },
                {
                    "timeout": 600,
                    "idleAction": ["suspendThenHibernate"]
                }
            ]
        },
        "battery": {
            "warnLevels": [
                {
                    "level": 20,
                    "title": "Low battery",
                    "message": "You might want to plug in a charger",
                    "icon": "battery_android_frame_2"
                },
                {
                    "level": 10,
                    "title": "Did you see the previous message?",
                    "message": "You should probably plug in a charger <b>now</b>",
                    "icon": "battery_android_frame_1"
                },
                {
                    "level": 5,
                    "title": "Critical battery level",
                    "message": "PLUG THE CHARGER RIGHT NOW!!",
                    "icon": "battery_android_alert",
                    "critical": true
                }
            ],
            "criticalLevel": 3
        }
    },
    "background": {
        "enabled": true,
        "wallpaperEnabled": true,
        "desktopClock": {
            "enabled": false,
            "scale": 1.0,
            "position": "bottom-right",
            "invertColors": false,
            "background": {
                "enabled": false,
                "opacity": 0.7,
                "blur": true
            },
            "shadow": {
                "enabled": true,
                "opacity": 0.7,
                "blur": 0.4
            }
        },
        "visualiser": {
            "enabled": false,
            "autoHide": true,
            "blur": false,
            "rounding": 1,
            "spacing": 1
        }
    },
    "bar": {
        "persistent": true,
        "showOnHover": true,
        "dragThreshold": 20,
        "scrollActions": {
            "workspaces": true,
            "volume": true,
            "brightness": true
        },
        "popouts": {
            "activeWindow": true,
            "tray": true,
            "statusIcons": true
        },
        "workspaces": {
            "shown": 5,
            "activeIndicator": true,
            "occupiedBg": false,
            "showUnoccupied": true,
            "perMonitor": true,
            "showWindows": true,
            "showWindowsOnSpecialWorkspaces": true,
            "maxWindowIcons": 5,
            "activeTrail": false,
            "displayType": "shapes",
            "specialDisplayType": "icons",
            "label": "  ",
            "occupiedLabel": "󰮯",
            "activeLabel": "󰮯",
            "capitalisation": "preserve",
            "workspaceIcons": [],
            "specialWorkspaceIcons": [
                {
                    "name": "special",
                    "icon": "star"
                },
                {
                    "name": "communication",
                    "icon": "forum"
                },
                {
                    "name": "music",
                    "icon": "music_cast"
                },
                {
                    "name": "todo",
                    "icon": "checklist"
                },
                {
                    "name": "sysmon",
                    "icon": "monitor_heart"
                }
            ],
            "ignoredTags": ["hide_in_bar", "xwl_popup"],
            "windowIcons": [
                {
                    "regex": "steam(_app_(default|[0-9]+))?",
                    "icon": "sports_esports"
                }
            ]
        },
        "activeWindow": {
            "compact": false,
            "inverted": false,
            "showOnHover": true
        },
        "tray": {
            "background": false,
            "recolour": false,
            "compact": false,
            "iconSubs": [],
            "hiddenIcons": []
        },
        "clock": {
            "background": false,
            "showDate": false,
            "showIcon": true
        },
        "statusIcons": [
            {
                "id": "lockStatus",
                "enabled": true
            },
            {
                "id": "audio",
                "enabled": false
            },
            {
                "id": "microphone",
                "enabled": false
            },
            {
                "id": "kbLayout",
                "enabled": false
            },
            {
                "id": "network",
                "enabled": true
            },
            {
                "id": "bluetooth",
                "enabled": true
            },
            {
                "id": "battery",
                "enabled": true
            }
        ],
        "entries": [
            {
                "id": "logo",
                "enabled": true
            },
            {
                "id": "workspaces",
                "enabled": true
            },
            {
                "id": "spacer",
                "enabled": true
            },
            {
                "id": "activeWindow",
                "enabled": true
            },
            {
                "id": "spacer",
                "enabled": true
            },
            {
                "id": "tray",
                "enabled": true
            },
            {
                "id": "clock",
                "enabled": true
            },
            {
                "id": "statusIcons",
                "enabled": true
            },
            {
                "id": "power",
                "enabled": true
            }
        ],
        "excludedScreens": []
    },
    "border": {
        "thickness": 10,
        "rounding": 25,
        "smoothing": 20
    },
    "dashboard": {
        "enabled": true,
        "showOnHover": true,
        "showDashboard": true,
        "showMedia": true,
        "showPerformance": true,
        "showWeather": true,
        "mediaUpdateInterval": 500,
        "resourceUpdateInterval": 1000,
        "dragThreshold": 50,
        "performance": {
            "showBattery": true,
            "showGpu": true,
            "showCpu": true,
            "showMemory": true,
            "showStorage": true,
            "showNetwork": true
        }
    },
    "launcher": {
        "enabled": true,
        "showOnHover": false,
        "maxShown": 7,
        "maxWallpapers": 9,
        "specialPrefix": "@",
        "actionPrefix": ">",
        "enableDangerousActions": false,
        "dragThreshold": 50,
        "vimKeybinds": false,
        "favouriteApps": [],
        "hiddenApps": [],
        "useFuzzy": {
            "apps": false,
            "actions": false,
            "schemes": false,
            "variants": false,
            "wallpapers": false
        },
        "actions": [
            {
                "name": "Calculator",
                "icon": "calculate",
                "description": "Do simple math equations (powered by Qalc)",
                "command": ["autocomplete", "calc"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Scheme",
                "icon": "palette",
                "description": "Change the current colour scheme",
                "command": ["autocomplete", "scheme"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Wallpaper",
                "icon": "image",
                "description": "Change the current wallpaper",
                "command": ["autocomplete", "wallpaper"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Variant",
                "icon": "colors",
                "description": "Change the current scheme variant",
                "command": ["autocomplete", "variant"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Random",
                "icon": "casino",
                "description": "Switch to a random wallpaper",
                "command": ["caelestia", "wallpaper", "-r"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Light",
                "icon": "light_mode",
                "description": "Change the scheme to light mode",
                "command": ["setMode", "light"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Dark",
                "icon": "dark_mode",
                "description": "Change the scheme to dark mode",
                "command": ["setMode", "dark"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Shutdown",
                "icon": "power_settings_new",
                "description": "Shutdown the system",
                "command": ["poweroff"],
                "enabled": true,
                "dangerous": true
            },
            {
                "name": "Reboot",
                "icon": "cached",
                "description": "Reboot the system",
                "command": ["reboot"],
                "enabled": true,
                "dangerous": true
            },
            {
                "name": "Logout",
                "icon": "exit_to_app",
                "description": "Log out of the current session",
                "command": ["logout"],
                "enabled": true,
                "dangerous": true
            },
            {
                "name": "Lock",
                "icon": "lock",
                "description": "Lock the current session",
                "command": ["loginctl", "lock-session"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Sleep",
                "icon": "bedtime",
                "description": "Suspend then hibernate",
                "command": ["suspendThenHibernate"],
                "enabled": true,
                "dangerous": false
            },
            {
                "name": "Settings",
                "icon": "settings",
                "description": "Configure the shell",
                "command": ["caelestia", "shell", "nexus", "open"],
                "enabled": true,
                "dangerous": false
            }
        ]
    },
    "lock": {
        "enabled": true,
        "useWallpaper": false,
        "recolourLogo": true,
        "enableFprint": true,
        "maxFprintTries": 3,
        "enableHowdy": true,
        "maxHowdyTries": 3,
        "triggerHowdyOnWake": true,
        "hideNotifs": false,
        "enableSessionControls": true
    },
    "nexus": {
        "wallpapersPerRow": 4,
        "networkRescanInterval": 15000
    },
    "notifs": {
        "expire": true,
        "fullscreen": "On",
        "defaultExpireTimeout": 5000,
        "fullscreenExpireTimeout": 2000,
        "clearThreshold": 0.3,
        "expandThreshold": 20,
        "actionOnClick": false,
        "groupPreviewNum": 3,
        "openExpanded": false
    },
    "osd": {
        "enabled": true,
        "hideDelay": 2000,
        "enableBrightness": true,
        "enableMicrophone": false
    },
    "services": {
        "weatherLocation": "",
        "weatherUnits": "Auto",
        "sensorUnits": "Celsius",
        "dataUnits": "Binary",
        "clockFormat": "Auto",
        "gpuType": "Auto",
        "visualiserBars": 60,
        "audioIncrement": 0.1,
        "brightnessIncrement": 0.1,
        "maxVolume": 1.0,
        "smartScheme": true,
        "defaultPlayer": "Spotify",
        "playerAliases": [
            { "from": "com.github.th_ch.youtube_music", "to": "YT Music" }
        ],
        "lyricsBackend": "Auto"
    },
    "session": {
        "enabled": true,
        "dragThreshold": 30,
        "vimKeybinds": false,
        "icons": {
            "logout": "logout",
            "shutdown": "power_settings_new",
            "hibernate": "downloading",
            "reboot": "cached"
        },
        "commands": {
            "logout": ["logout"],
            "shutdown": ["poweroff"],
            "hibernate": ["hibernate"],
            "reboot": ["reboot"]
        }
    },
    "sidebar": {
        "enabled": true,
        "showOnHover": false,
        "minHoverThreshold": 200,
        "dragThreshold": 80
    },
    "utilities": {
        "enabled": true,
        "maxToasts": 4,
        "toasts": {
            "fullscreen": "off",
            "configLoaded": true,
            "chargingChanged": true,
            "gameModeChanged": true,
            "dndChanged": true,
            "audioOutputChanged": true,
            "audioInputChanged": true,
            "capsLockChanged": true,
            "numLockChanged": true,
            "kbLayoutChanged": true,
            "kbLimit": true,
            "vpnChanged": true,
            "nowPlaying": false
        },
        "vpn": {
            "enabled": false,
            "provider": [
                {
                    "name": "wireguard",
                    "interface": "your-connection-name",
                    "displayName": "Wireguard (Your VPN)",
                    "enabled": false
                }
            ]
        },
        "quickToggles": [
            {
                "id": "wifi",
                "enabled": true
            },
            {
                "id": "bluetooth",
                "enabled": true
            },
            {
                "id": "mic",
                "enabled": true
            },
            {
                "id": "settings",
                "enabled": true
            },
            {
                "id": "gameMode",
                "enabled": true
            },
            {
                "id": "dnd",
                "enabled": true
            },
            {
                "id": "vpn",
                "enabled": false
            }
        ]
    },
    "paths": {
        "wallpaperDir": "~/Pictures/Wallpapers",
        "lyricsDir": "~/Music/lyrics/",
        "sessionGif": "root:/assets/kurukuru.gif",
        "mediaGif": "root:/assets/bongocat.gif",
        "noNotifsPic": "root:/assets/dino.png",
        "lockNoNotifsPic": "root:/assets/dino.png"
    }
}
```

</details>

### Advanced configuration

> [!CAUTION]
> Do NOT change any of these options unless you know what you are doing. These options control the
> tokens used internally within the shell, and can cause visual issues if modified incorrectly.
> The available options may change or be removed without notice across versions.

A separate `~/.config/caelestia/shell-tokens.json` file allows editing the internal tokens without
touching the source code of the shell. These tokens affect the dimensions and appearance of visual elements,
including individual rounding, spacing, padding, font size, animation durations and curves, and the sizes of
certain components. The appearance scale values in `shell.json` are multiplied against these base
token values to produce the final computed values.

Per-monitor token overrides are also available at
`~/.config/caelestia/monitors/<monitor_name>/shell-tokens.json`.

### Home Manager Module

The following Home Manager example is inherited from upstream. It does not install this Mango fork; the upstream package targets Hyprland. Use the manual build instructions above for this port.

<details><summary><code>home.nix</code></summary>

```nix
programs.caelestia = {
  enable = true;
  systemd = {
    enable = false; # if you prefer starting from your compositor
    target = "graphical-session.target";
    environment = [];
  };
  settings = {
    bar.statusIcons = [
      { id = "lockStatus"; enabled = true; }
      { id = "network"; enabled = true; }
      { id = "bluetooth"; enabled = true; }
      { id = "battery"; enabled = false; }
    ];
    paths.wallpaperDir = "~/Images";
  };
  cli = {
    enable = true; # Also add caelestia-cli to path
    settings = {
      theme.enableGtk = false;
    };
  };
};
```

The upstream module can configure upstream Caelestia and its optional CLI; Mango-specific packaging would need to use this fork.

</details>

## FAQ

### Why MangoWC instead of Hyprland?

Great question! Some folks prefer MangoWC's wlroots-based approach, simpler architecture, or just want to try something different. This port makes Caelestia accessible to the MangoWC community while keeping all the beautiful design intact.

### Can I use this with Hyprland?

Nope! This fork is specifically adapted for MangoWC. If you want to use Hyprland, grab the [original Caelestia shell](https://github.com/caelestia-dots/shell) instead - it's fantastic!

### Window previews don't show live thumbnails!

The bar popout and window-info panel capture the selected window through Mango's standard Wayland capture protocols using `grim -T`. Frames refresh at up to five per second while the preview is visible; capture stops when it closes. This captures window content directly, including content obscured by other windows.

Check that `grim -h` lists `-T`, and that `mmsg get all-clients` includes `foreign_toplevel_id` for clients. Rebuild, install, and restart the shell after updating: the previews use a compiled `Caelestia.Images` component. If capture is unavailable, window titles and metadata still work. Older Mango or grim versions may need an upgrade.

### Notifications say a server is already registered

Only one process can own `org.freedesktop.Notifications`. Check the current owner:

```sh
busctl --user status org.freedesktop.Notifications
```

If it reports `dms.service`, Dank Linux Shell already owns notifications. To use Caelestia as your shell,
stop DMS with `systemctl --user stop dms.service` and remove its autostart entry if you no longer want it.
For other owners such as Mako, Dunst, or SwayNC, stop the corresponding notification daemon.
Quickshell retries registration when the existing owner exits.

### Audio shows only Dummy Output

Check `wpctl status` and `pactl list cards`. If the hardware card exists but its active profile is `off`,
select an available speaker or headphone profile, then select that output as the default.
Caelestia displays the outputs provided by PipeWire; it cannot create missing hardware outputs.
If profile activation fails, check `journalctl --user -u pipewire -u wireplumber` and the login session's
permissions on `/dev/snd`. A previous permission failure can leave the card switched off even after
access has been restored.

### Qt text-input warnings on focus changes

A `qt.qpa.wayland.textinput` warning can still appear when Qt's text-input surface state and keyboard
focus change at different times. The launcher avoids redundant focus requests and has been tested
for automatic typing focus on first open and reopen. The remaining `disableSurface` warning was
reproduced during testing; it has not been eliminated. Do not disable input-method support just to hide it.

### Workspace clicks work only once

Update and reinstall this fork, then restart Caelestia. The adapter now uses `view` for direct switches;
`comboview` retains keyboard-combination state and can accumulate tags across mouse clicks.
See the [Mango dispatcher reference](https://mangowm.github.io/docs/bindings/keys/).

### Updates are installed but the old warnings remain

Check the configuration path printed at launch. A user copy can override the system installation.
Also rebuild and install the C++ plugins, then restart Quickshell; copying QML alone does not update them.

### How does screen recording work?

Screen recording is fully integrated using `gpu-screen-recorder` and `slurp` for region captures. Ensure `gpu-screen-recorder` and `slurp` are installed. Recordings are saved to `~/Videos/Recordings` (configurable via `CAELESTIA_RECORDINGS_DIR`) and can be managed or played back directly from the Utilities drawer.

### My screen is flickering!

Try tweaking MangoWC's refresh rate settings or disabling any compositor effects that might conflict with the shell's layer surfaces.

### I want to make my own changes!

The shell is installed to `/etc/xdg/quickshell/caelestia`. You can edit these files directly (you'll need sudo access) or copy the entire directory to `~/.config/quickshell/caelestia` for user-specific modifications. Quickshell will prefer the user config if it exists.

### I want to disable \_\_\_ feature!

Please read the [configuring](#configuring) section.
If there is no corresponding option, make a [feature request](https://github.com/caelestia-dots/shell/issues/new?template=feature.yml).

### How do I make my colour scheme change to match my wallpaper?

Set a wallpaper via `>wallpaper` in the launcher or `caelestia wallpaper`, and set the scheme to the dynamic scheme via
`>scheme` in the launcher or `caelestia scheme set`, e.g.:

```sh
caelestia wallpaper -f <path_to_wallpaper>
caelestia scheme set -n dynamic
```

Without caelestia-cli, you can use the launcher (Super + Space) to search for wallpapers and schemes!

### My wallpapers aren't showing up in the launcher!

The launcher pulls wallpapers from `~/Pictures/Wallpapers` by default. You can change this in the config. Additionally,
the launcher only shows an odd number of wallpapers at one time. If you only have 2 wallpapers, consider getting more
(or just putting one).

## Credits & Appreciation

### The Real MVPs

**MASSIVE thanks to [@Soramane](https://github.com/soramane)** for creating the original Caelestia shell! This project is absolutely stunning, and it's been an honor to adapt it for MangoWC. Seriously, if you appreciate this work, go [support them on Ko-Fi](https://ko-fi.com/soramane) - they deserve all the love! ❤️

The entire [Caelestia project](https://github.com/caelestia-dots) is a masterclass in design and polish. Check out their work!

### Technology & Community

Huge thanks to:

- **[@outfoxxed](https://github.com/outfoxxed)** for creating and maintaining [Quickshell](https://quickshell.outfoxxed.me), and for patiently implementing features and fixing bugs that make projects like this possible
- **The MangoWC developers** for building a solid wlroots-based compositor
- **[@end_4](https://github.com/end-4)** for their [config](https://github.com/end-4/dots-hyprland) which served as inspiration for the original Caelestia
- **The Hyprland discord community** (especially the homies in #rice-discussion) for all the help, feedback, and ongoing inspiration

### Original Inspirations

The original Caelestia shell took inspiration from:
- [Axenide/Ax-Shell](https://github.com/Axenide/Ax-Shell)

---

> [!NOTE]
> This MangoWC port is a community effort and is **not officially affiliated** with the Caelestia project. For the original, Hyprland-optimized version, please visit [caelestia-dots/shell](https://github.com/caelestia-dots/shell).

## Stonks 📈

<a href="https://www.star-history.com/#caelestia-dots/shell&Date">
    <picture>
        <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=caelestia-dots/shell&type=Date&theme=dark" />
        <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=caelestia-dots/shell&type=Date" />
        <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=caelestia-dots/shell&type=Date" />
    </picture>
</a>

[dots-repo]: https://github.com/caelestia-dots/caelestia
[discord]: https://caelestiashell.com/discord
