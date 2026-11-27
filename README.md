# Kaizo Shell

Independent, local-first Hyprland desktop shell built with Quickshell / Qt Quick and Go. Version **0.2.0-alpha.1**. This is an alpha: the Go backend is tested, but the graphical runtime has not been tested on a real Hyprland session.

## Install on Arch Linux

Extract the ZIP, then as your normal user inside Hyprland:

```bash
cd kaizo-shell
./install.sh --deps
~/.local/bin/kaizo start
```

For a local installation, `./install.sh --yes` skips the install confirmation without installing system dependencies. The x86_64 binary is bundled; other architectures can compile from source with Go 1.22+. Update Arch normally before installing packages (avoid partial upgrades). Dependencies are installed only with your consent using pacman. Kaizo does not enable NetworkManager or Bluetooth, change your Hyprland config, or stop another shell. Use `kaizo doctor` to detect conflicts. `kaizo run` is a foreground alternative to the user-systemd service.

Add `~/.local/bin` to PATH if needed. All commands below assume that directory is on PATH.

## Remote installation (after public release publication)

The repository and release are not published yet. The following is the intended URL, not a working link today. Safer method: download and inspect the script first.

```bash
curl -fL https://raw.githubusercontent.com/somekindaskid/kaizoshell/main/bootstrap.sh -o /tmp/kaizo-install.sh
less /tmp/kaizo-install.sh
bash /tmp/kaizo-install.sh --channel beta --deps
```

The bootstrap checks SHA-256 against the release manifest, uses HTTPS, and prompts before installing. Checksums guard against transfer corruption; they are not independent cryptographic signatures or a security audit. It needs curl, Python 3, sha256sum, and an interactive terminal. No telemetry or online account is required.

## Desktop features

- Multi-monitor bar, workspaces, window title, system tray, calendar, notification centre, quick settings, dock, wallpaper, media controls and power menu.
- First-run graphical onboarding: appearance, profile and optional clipboard history.
- Launcher tabs: apps, file names, arithmetic, clipboard. File search is bounded to common home folders, skips hidden entries, and stops after 2 seconds / 25,000 entries / 80 results. It is not a full-disk indexer.
- Wallpaper accents via ImageMagick. Enable dynamic colours before choosing a wallpaper or select Extract colours. Accent only, not a full Material You palette.
- Media Island: floating pill for MPRIS media players, including paused playback. No download progress integration yet.
- Studio: drag or use up/down buttons to reorder the six built-in right-side bar widgets. Workspace and launcher placement are fixed.
- Extensions: local JSON text-only widget manifests; no execution of external QML or scripts. Import from Settings or CLI. First three extensions display on wide bars. No online marketplace.
- Display manager: connected monitor enumeration, resolution, refresh rate, scale, position and rule preview. Experimental live apply uses legacy `hyprctl keyword monitor` with 20-second user-systemd reload recovery. On Lua-only Hyprland releases, the live command may be unsupported. No persistent compositor config editing, disable/enable toggles or per-monitor wallpapers yet.
- Clipboard history is OFF by default. Enabling it starts cliphist watchers that may retain sensitive information. Disabling stops new capture; clear explicitly with `kaizo clipboard clear`.

## CLI

```text
kaizo setup                      Terminal maintenance menu
kaizo install [--yes] [--deps]   Local install
kaizo deps                       Prompt for Arch dependencies
kaizo start | stop | restart | reload | status | logs | run
kaizo doctor | version | help
kaizo launcher | controls | notifications | settings | calendar | power
kaizo onboarding | studio | monitors | extensions
kaizo config [KEY VALUE]         JSON settings
kaizo theme dark                 dark or light
kaizo profile gaming             full, minimal, work, gaming
kaizo gamemode toggle
kaizo wallpaper /absolute/path/to/image.png
kaizo palette [IMAGE]            Generate wallpaper accent
kaizo files QUERY                JSON search results
kaizo calc '2*(3+4)'              Arithmetic without code evaluation
kaizo clipboard list|copy|clear
kaizo extension list|install FILE|remove ID
kaizo widget-order '["clock","stats","tray","inbox","sound","power"]'
kaizo monitor list
kaizo monitor preview DP-1 1920x1080@144 0x0 1
kaizo monitor apply DP-1 preferred auto 1
kaizo monitor confirm|revert
kaizo lock                       Uses real Hyprlock; configure it separately
kaizo backup | restore FILE | reset
kaizo channel stable|beta|nightly
kaizo update --check             Fetch public GitHub release metadata
kaizo update                     Download and verify selected release binary
kaizo repair                     Redeploy embedded shell files locally
kaizo rollback                   Switch previous release, restart afterwards
kaizo uninstall                  Preserve settings and history
kaizo autostart                  Print optional compositor integration
```

Example extension: `kaizo extension install examples/text-widget.json`. Removal: `kaizo extension remove focus`.

### Monitor caution

Live testing requires user systemd and Hyprland IPC. Test a display setting, then confirm within 20 seconds if usable. If not confirmed, the timer runs `hyprctl reload`, restoring the compositor's saved configuration (and discarding other temporary runtime overrides). Keeping a change cancels the timer but does not persist it across compositor reloads. Preview is safe and does not alter your display. Do not assume the legacy command works on newer Lua-only Hyprland versions.

### Startup / lock / recovery

`kaizo autostart` prints legacy Hyprland configuration suggestions; review conflicts and translate to your installed compositor's syntax as needed. Configure Hyprlock/PAM and test locally before enabling Hypridle. Sample files are in packaging/. Kaizo does not implement its own authentication, overwrite system settings, or automatically enable idle services.

Local installation retains existing config and creates a backup. Prior shell releases and their CLI binaries are retained when available. Rollback switches to the previous QML while retaining the current CLI so older CLI versions cannot reject newer settings. Archived binaries are retained for manual recovery. `kaizo repair` restores embedded shell files. These are individually atomic file operations, not a guaranteed whole-system transaction. Use a backup or rerun the installer if interrupted. Restart after updates or rollback. Uninstall retains config and release history. If upgrading from alpha 0.1, the configuration automatically receives missing new defaults.

## Publishing

The GitHub Actions workflow `.github/workflows/release.yml` tests and builds x86_64 and ARM64 assets; version tags publish release artifacts, with hyphenated tags marked prerelease. For nightly releases, use `nightly-...` tags. No workflow has run on GitHub yet. AUR packaging is in `packaging/aur/`: the template requires an explicit licence choice and real source checksum before submission. AUR installation has not been tested. Do not mix AUR-managed and self-updated CLI versions.

## Test

```bash
go test -v ./...
go vet ./...
bash tests/smoke.sh
```

See `docs/STATUS.md` for limitations. Live testing on Arch with Quickshell, Hyprland, PipeWire, notification D-Bus ownership, actual monitors and lock authentication is required before a stable release.

### Automatic Hyprland integration

Installation from a running Hyprland session adds a backed-up managed startup and Super+Space block, reloads and checks the config, and starts Kaizo. Existing conflicting shortcuts are preserved unless explicitly replaced in Settings > Desktop & bar. Use `kaizo integration enable|replace|remove|status`. Symlinked or ambiguous configs are not edited. If validation fails, the original config is restored. Backups are under the XDG state directory in `kaizo/hyprland-backups`.
