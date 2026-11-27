#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ $EUID == 0 ]]; then echo 'Run as your normal user, not root.' >&2; exit 1; fi
if [[ -x ./kaizo-linux-amd64 && $(uname -m) == x86_64 ]]; then
  exec ./kaizo-linux-amd64 install "$@"
fi
if ! command -v go >/dev/null; then echo 'Install Go (sudo pacman -S go), then rerun.' >&2; exit 1; fi
build=$(mktemp -d); trap 'rm -rf -- "$build"' EXIT
CGO_ENABLED=0 go build -trimpath -o "$build/kaizo" .
"$build/kaizo" install "$@"
