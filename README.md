# Kaizo Shell — SleepyShell foundation (preview)

This migration branch uses [SleepyShell](https://github.com/nninkovic95/sleepyshell) at commit `c87dfb8c8a4dd6972a0b35188ddbb553ad0669b5` as its actual QML/Python desktop engine, not a visual imitation. Upstream is MIT-licensed; the original licence and credits remain in the checkout and in LICENSE. This is a derivative project, not an official upstream release.

The original Kaizo Alpha remains on main. This branch contains Kaizo's installer, compatibility CLI and narrowly scoped patches rather than duplicating the upstream source and large assets. The installer fetches the exact upstream commit into the user's XDG data directory, verifies it, and applies the Kaizo overlay. Upstream's installer handles Arch dependencies, settings, Hyprland startup, backups and consent. No configuration file is deleted to resolve dual Lua/conf installations.

## Install

Requires Arch or Arch-based Linux, a running Hyprland 0.55+ Lua session, Git and Python. Review the installer before running. In a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/somekindaskid/kaizoshell/sleepyshell-base/bootstrap.sh | bash
```

The upstream installer is interactive: it asks before modifying existing config or enabling services. `--plain` selects plain prompts; `--dry-run` stages the source and previews the upstream changes without installing them. The old CLI is backed up before migration; old settings are preserved but not converted into upstream TOML. The old systemd service is stopped during migration, and restarted on failure when it was previously running. Review upstream install reports for any partially applied config changes; this is not a comprehensive system rollback.

## Kaizo additions

- Native, themed application search on the configured primary display; Super+Space is added by the installer when free, otherwise configure the existing key or choose a different one in Keybinds.
- Kaizo-branded settings title, upstream display policy, bar, notifications, control centre, lock, power, wallpaper and settings UI.
- Compatibility CLI: `kaizo start`, `kaizo search`, `kaizo settings`, `kaizo monitors`, `kaizo doctor`, `kaizo logs`.
- Internal names intentionally remain sleepyshell to keep upstream IPC, modules and paths compatible. The old Alpha's file search, calculator and extension format have not been ported yet.

No graphical runtime validation has been completed for this migration. Existing SleepyShell installations are not overwritten.
