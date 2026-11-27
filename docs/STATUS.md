# 0.2.0-alpha.1 status

Implemented: bounded local filename search, safe arithmetic evaluator, opt-in clipboard capture and history, wallpaper accent extraction (ImageMagick), MPRIS Island, widget order editing, local declarative text extensions, first-run setup, monitor list/preview and legacy live apply with timed reload, GitHub release channel selection and checksummed downloads, remote bootstrap, CI build/release workflow, Arch PKGBUILD template.

Verification: Go unit tests, static analysis, shell syntax, local install/upgrade/rollback/uninstall smoke checks. Graphical runtime, Arch package installation, monitor live changes, clipboard Wayland integration, media integration and network update publication are not verified in this environment.

Limitations: AUR listing and public repository/releases do not exist or are not accessible from this session. AUR template requires licence and checksum. Online updater is code-ready, not end-to-end verified. No independent signatures. No arbitrary extension code/marketplace. Island supports media only. Studio reorders right-side widgets only. Legacy live monitor rules may not work on Lua-only Hyprland; no persistent monitor editing/disable or per-monitor wallpaper. No full-disk indexed file search. No guarantee of zero defects.
