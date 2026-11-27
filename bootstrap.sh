#!/usr/bin/env bash
# Kaizo Shell remote installer. Review before running.
set -euo pipefail
[[ $EUID != 0 ]] || { echo 'Run as your normal desktop user.' >&2; exit 1; }
repo=somekindaskid/kaizoshell
channel=beta
args=()
while (($#)); do
  case $1 in
    --channel) shift; channel=${1:?Missing channel};;
    --deps|--yes) args+=("$1");;
    *) echo "Unknown option: $1" >&2; exit 1;;
  esac
  shift
done
case $channel in stable|beta|nightly) ;; *) echo 'Invalid channel' >&2; exit 1;; esac
for c in curl python3 sha256sum; do command -v "$c" >/dev/null || { echo "Missing: $c" >&2; exit 1; }; done
case $(uname -m) in x86_64) arch=amd64;; aarch64) arch=arm64;; *) echo 'Unsupported architecture' >&2; exit 1;; esac
work=$(mktemp -d); trap 'rm -rf -- "$work"' EXIT
cd "$work"
curl --proto '=https' --tlsv1.2 -fsSL --retry 2 --max-time 60 "https://api.github.com/repos/$repo/releases?per_page=100" > releases.json
python3 - "$channel" "$arch" "$repo" <<'PY' > urls
import json,sys
ch,arch,repo=sys.argv[1:]
for r in json.load(open('releases.json')):
    night=r['tag_name'].startswith('nightly-')
    if r['draft'] or not ((ch=='stable' and not r['prerelease'] and not night) or (ch=='beta' and r['prerelease'] and not night) or (ch=='nightly' and r['prerelease'] and night)): continue
    assets={a['name']:a['browser_download_url'] for a in r['assets']}
    names=['kaizo-linux-'+arch,'SHA256SUMS']
    if all(n in assets and assets[n].startswith('https://github.com/'+repo+'/releases/download/') for n in names):
        print(*(assets[n] for n in names),sep='\n'); break
else: sys.exit('No matching published release with binaries and checksums')
PY
mapfile -t urls < urls
curl --proto '=https' --tlsv1.2 -fsSL --retry 2 --max-time 120 "${urls[0]}" -o "kaizo-linux-$arch"
curl --proto '=https' --tlsv1.2 -fsSL --retry 2 --max-time 60 "${urls[1]}" -o SHA256SUMS
python3 - "$arch" <<'PY' > check
import sys,re
name='kaizo-linux-'+sys.argv[1]
for line in open('SHA256SUMS'):
    fields=line.split()
    if len(fields)==2 and fields[1].lstrip('*')==name and re.fullmatch('[0-9a-fA-F]{64}',fields[0]):
        print(fields[0]+'  '+name); break
else: sys.exit('Missing valid checksum')
PY
sha256sum -c check
chmod 700 "kaizo-linux-$arch"
if [[ -t 0 ]]; then ./"kaizo-linux-$arch" install "${args[@]}"; elif [[ -r /dev/tty ]]; then ./"kaizo-linux-$arch" install "${args[@]}" </dev/tty; else echo 'Interactive terminal required.' >&2; exit 1; fi
"$HOME/.local/bin/kaizo" channel "$channel"
