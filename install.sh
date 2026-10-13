#!/usr/bin/env bash
# Build as the login user; let sudo handle authentication at installation time.
set -Eeuo pipefail
trap 'printf "\nInstallation stopped at line %s. Fix the error above and rerun ./install.sh.\n" "$LINENO" >&2' ERR

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
build_dir="$repo_dir/build"
jobs=2
check_only=false

usage() {
    cat <<'EOF'
Usage: ./install.sh [--check] [--jobs N] [--build-dir PATH]

Run from a terminal as your normal user. The installer checks dependencies,
offers Arch package installation, builds the shell, then uses sudo to install.
Sudo prompts for your password directly; this script never reads or saves it.
After installation, optional prompts configure Mango shortcuts, autostart and blur.

  --check           Check prerequisites without installing or changing files
  --jobs N          Parallel build jobs (default: 2)
  --build-dir PATH  Build directory (default: this checkout's build/)
  -h, --help        Show this help
EOF
}

while (($#)); do
    case "$1" in
        --check) check_only=true; shift ;;
        --jobs|--build-dir)
            (($# >= 2)) || { printf 'Missing value for %s\n' "$1" >&2; exit 2; }
            if [[ "$1" == --jobs ]]; then jobs="$2"; else build_dir="$2"; fi
            shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage; exit 2 ;;
    esac
done
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || { printf 'Jobs must be a positive integer.\n' >&2; exit 2; }
if ((EUID == 0)) && ! "$check_only"; then
    printf 'Run ./install.sh as your normal user, without sudo.\n' >&2
    exit 1
fi
if ! "$check_only" && [[ ! -t 0 ]]; then
    printf 'Interactive installation requires a terminal. Use --check for a read-only check.\n' >&2
    exit 1
fi

ask() {
    local reply
    read -r -p "$1 [y/N] " reply
    [[ "$reply" == [yY] || "$reply" == [yY][eE][sS] ]]
}

check_dependencies() {
    local tool module
    missing=()
    for tool in cmake ninja pkg-config c++ python3 qs mango mmsg; do
        command -v "$tool" >/dev/null 2>&1 || missing+=("command: $tool")
    done
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' || missing+=("Python 3.11+")
    fi
    if command -v pkg-config >/dev/null 2>&1; then
        pkg-config --atleast-version=6.9 Qt6Core || missing+=("Qt 6.9+ development files")
        for module in Qt6Qml Qt6Quick Qt6QuickControls2 Qt6ShaderTools Qt6Sql Qt6Network Qt6DBus wayland-client xkbcommon libqalculate libpipewire-0.3 aubio; do
            pkg-config --exists "$module" || missing+=("development library: $module")
        done
        pkg-config --exists libcava || pkg-config --exists cava || missing+=("development library: libcava")
    fi
    if command -v pacman >/dev/null 2>&1; then
        pacman -Q quickshell-git >/dev/null 2>&1 || missing+=("quickshell-git (required instead of stable quickshell)")
        pacman -Q qt6-m3shapes-git >/dev/null 2>&1 || missing+=("qt6-m3shapes-git")
    fi
    if ((${#missing[@]})); then
        printf '\nMissing prerequisites:\n'; printf '  - %s\n' "${missing[@]}"
    else
        printf '\nBuild prerequisites found. CMake will verify remaining headers and libraries.\n'
    fi
    printf '\nFeature dependencies:\n'
    for tool in grim matugen slurp gpu-screen-recorder brightnessctl ddcutil app2unit fish; do
        if command -v "$tool" >/dev/null 2>&1; then printf '  Found %s\n' "$tool";
        else printf '  Missing %s (see README dependencies)\n' "$tool"; fi
    done
    if command -v grim >/dev/null 2>&1; then
        if ! grim -h 2>&1 | grep -q -- '-T'; then
            printf '  Your grim lacks -T; upgrade it for live window previews.\n'
        fi
    fi
}

install_arch_dependencies() {
    local package helper
    local -a repository_packages=() aur_packages=()
    local -a packages=(base-devel cmake ninja pkgconf python wayland libxkbcommon
        qt6-base qt6-declarative qt6-shadertools qt6-imageformats aubio libpipewire
        libqalculate lm_sensors libcava quickshell-git qt6-m3shapes-git networkmanager
        power-profiles-daemon ddcutil brightnessctl app2unit fish bash swappy slurp grim
        matugen gpu-screen-recorder ttf-material-symbols-variable ttf-rubik-vf ttf-cascadia-code-nerd)
    command -v mango >/dev/null 2>&1 || packages+=(mangowc)
    for package in "${packages[@]}"; do
        pacman -Q "$package" >/dev/null 2>&1 && continue
        if pacman -Si "$package" >/dev/null 2>&1; then repository_packages+=("$package");
        else aur_packages+=("$package"); fi
    done
    if ((${#repository_packages[@]})); then
        printf '\nRepository packages: %s\n' "${repository_packages[*]}"
        sudo pacman -S --needed "${repository_packages[@]}"
    fi
    if ((${#aur_packages[@]})); then
        if command -v paru >/dev/null 2>&1; then helper=paru;
        elif command -v yay >/dev/null 2>&1; then helper=yay;
        else
            printf '\nInstall these AUR packages using your preferred helper, then rerun:\n'
            printf '  %s\n' "${aur_packages[@]}"
            return 1
        fi
        printf '\nAUR packages (using %s): %s\n' "$helper" "${aur_packages[*]}"
        "$helper" -S --needed "${aur_packages[@]}"
    fi
}

printf 'Caelestia for Mango — guided installer\nCheckout: %s\n' "$repo_dir"
check_dependencies
if "$check_only"; then
    if ((${#missing[@]} == 0)); then exit 0; else exit 1; fi
fi
command -v sudo >/dev/null 2>&1 || { printf 'Install sudo before continuing.\n' >&2; exit 1; }
if command -v pacman >/dev/null 2>&1 && ask 'Install missing Arch runtime/build packages?'; then
    install_arch_dependencies
    check_dependencies
fi
if ((${#missing[@]})); then
    printf '\nInstall the missing dependencies listed above and in README.md, then rerun.\n' >&2
    exit 1
fi
printf '\nBuild directory: %s\nParallel jobs: %s\n' "$build_dir" "$jobs"
ask 'Configure, build and install Caelestia system-wide?' || exit 0
qml_dir=/usr/lib/qt6/qml
for qtpaths in "$(command -v qtpaths6 || true)" "$(pkg-config --variable=libdir Qt6Core)/qt6/bin/qtpaths" /usr/lib/qt6/bin/qtpaths; do
    if [[ -x "$qtpaths" ]]; then
        qml_dir="$("$qtpaths" --query QT_INSTALL_QML)"
        break
    fi
done
[[ "$qml_dir" == /* ]] || { printf 'Could not determine the Qt 6 QML installation directory.\n' >&2; exit 1; }
cmake -S "$repo_dir" -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ \
    -DINSTALL_LIBDIR=usr/lib/caelestia "-DINSTALL_QMLDIR=$qml_dir" \
    -DINSTALL_QSCONFDIR=etc/xdg/quickshell/caelestia
cmake --build "$build_dir" --parallel "$jobs"
printf '\nInstalling. Sudo may now ask for your password.\n'
sudo cmake --install "$build_dir"

if ask 'Configure Mango shortcuts and/or autostart?'; then
    setup_args=()
    if ask 'Add Caelestia shortcuts (existing conflicts will be reported)?'; then setup_args+=(--keybinds); fi
    if ask 'Start Caelestia automatically when Mango starts?'; then setup_args+=(--autostart); fi
    if ((${#setup_args[@]})); then
        python3 "$repo_dir/scripts/install-mango-config.py" "${setup_args[@]}" ||
            printf 'Automatic setup skipped. Follow README.md for manual configuration.\n'
    fi
fi
if ask 'Set up automatic Mango drawer blur integration?'; then
    python3 "$repo_dir/assets/mango_blur.py" --setup --enabled 0 --alpha 0.85 ||
        printf 'Blur setup needs manual attention; see README.md.\n'
fi
if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v mmsg >/dev/null 2>&1 && ask 'Reload Mango configuration now?'; then
    mmsg dispatch reload_config || printf 'Reload failed; reload Mango manually.\n'
fi
user_shell="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
if [[ -e "$user_shell" || -L "$user_shell" ]]; then
    printf '\nYour user config at %s overrides the installed system copy.\n' "$user_shell"
    printf 'To launch the new system copy explicitly: qs -p /etc/xdg/quickshell/caelestia/shell.qml\n'
fi
printf '\nInstalled successfully. Close the old Caelestia instance, then run: qs -c caelestia\n'
printf 'If another notification daemon is running, choose which shell should own notifications (see README).\n'
