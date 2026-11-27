#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
pin=c87dfb8c8a4dd6972a0b35188ddbb553ad0669b5
upstream=https://github.com/nninkovic95/sleepyshell.git
cfg=${XDG_CONFIG_HOME:-$HOME/.config}
data=${XDG_DATA_HOME:-$HOME/.local/share}/kaizo
state=${XDG_STATE_HOME:-$HOME/.local/state}/kaizo
engine="$data/sleepyshell-engine"
[[ $EUID != 0 ]] || { echo 'Run as your normal desktop user' >&2; exit 1; }
[[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -n "${WAYLAND_DISPLAY:-}" ]] || { echo 'Run inside Hyprland' >&2; exit 1; }
[[ -f "$cfg/hypr/hyprland.lua" ]] || { echo 'The new base needs Hyprland 0.55+ with Lua config' >&2; exit 1; }
for cmd in git python3 systemctl; do command -v "$cmd" >/dev/null || { echo "Missing $cmd" >&2; exit 1; }; done
dry=0
args=()
for arg in "$@"; do
    case "$arg" in
        --dry-run) dry=1; args+=("$arg");;
        --plain) args+=("$arg");;
        *) echo "Unknown option $arg (supported: --plain --dry-run)" >&2; exit 2;;
    esac
done
if [[ $dry == 0 && ( -e "$cfg/quickshell/sleepyshell" || -L "$cfg/quickshell/sleepyshell" ) ]]; then
    [[ -L "$cfg/quickshell/sleepyshell" && "$(readlink -f "$cfg/quickshell/sleepyshell")" == "$engine" ]] || {
        echo 'Existing independent SleepyShell installation found. Refusing to replace it.' >&2; exit 1;
    }
fi
mkdir -p "$data" "$state"
if [[ ! -e "$engine" ]]; then
    staging=$(mktemp -d "$data/.engine.XXXXXX")
    trap 'rm -rf -- "$staging"' EXIT
    git -C "$staging" init -q
    git -C "$staging" remote add origin "$upstream"
    git -C "$staging" fetch --depth=1 origin "$pin"
    git -C "$staging" checkout --detach FETCH_HEAD
    python3 "$here/patch.py" "$staging"
    mv -T -- "$staging" "$engine"
    trap - EXIT
else
    [[ -d "$engine/.git" && ! -L "$engine" ]] || { echo 'Unrecognised engine folder' >&2; exit 1; }
    [[ "$(git -C "$engine" remote get-url origin)" == "$upstream" ]] || { echo 'Unrecognised engine origin' >&2; exit 1; }
    python3 "$here/patch.py" "$engine"
fi
old="$HOME/.local/bin/kaizo"
if [[ $dry == 1 ]]; then
    exec bash "$engine/install.sh" "${args[@]}"
fi
backup="$state/migration-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -m 700 "$backup"
[[ ! -e "$old" ]] || cp -a -- "$old" "$backup/kaizo-previous"
old_active=0
if systemctl --user is-active --quiet kaizo-shell.service; then
    old_active=1
    systemctl --user stop kaizo-shell.service
fi
success=0
cleanup() {
    if [[ $success == 0 && $old_active == 1 ]]; then
        # Stop only this engine's new instance, if its own IPC is available.
        bash "$here/kaizo" stop >/dev/null 2>&1 || true
        systemctl --user start kaizo-shell.service || true
    fi
}
trap cleanup EXIT
echo 'Kaizo uses the upstream installer: review its package and configuration changes.'
bash "$engine/install.sh" "${args[@]}"
[[ -L "$cfg/quickshell/sleepyshell" && "$(readlink -f "$cfg/quickshell/sleepyshell")" == "$engine" ]] || { echo 'Installer did not link the new engine' >&2; exit 1; }
bash "$here/kaizo" start
mkdir -p "$HOME/.local/bin"
tmp=$(mktemp "$HOME/.local/bin/.kaizo.XXXXXX")
install -m 755 "$here/kaizo" "$tmp"
mv -fT "$tmp" "$old"
success=1
echo "Kaizo migrated. Previous CLI saved in $backup if it existed."
echo 'Use kaizo settings. Display and Keybinds are managed in the upstream settings app.'
echo 'If Super+Space is occupied, the installer preserves it; select the shortcut in Keybinds.'
