#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
go test -v ./...
go vet ./...
bash -n install.sh
CGO_ENABLED=0 go build -trimpath -o kaizo-linux-amd64 .
./kaizo-linux-amd64 version
./kaizo-linux-amd64 help
