#!/usr/bin/env bash
set -euo pipefail
[[ $EUID != 0 ]] || { echo 'Do not use sudo' >&2; exit 1; }
command -v git >/dev/null || { echo 'Install git first: sudo pacman -S git' >&2; exit 1; }
dir=$(mktemp -d)
trap 'rm -rf -- "$dir"' EXIT
git clone --depth 1 --branch sleepyshell-base https://github.com/somekindaskid/kaizoshell.git "$dir"
if [[ -t 0 ]]; then bash "$dir/install.sh" "$@"; else bash "$dir/install.sh" "$@" </dev/tty; fi
