package main

import (
	"bufio"
	"crypto/sha256"
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

//go:embed shell/*
var assets embed.FS

const version = "0.2.0-alpha.1"
const unit = "kaizo-shell.service"

var home, _ = os.UserHomeDir()

func xdg(k, fallback string) string {
	if v := os.Getenv(k); filepath.IsAbs(v) {
		return v
	}
	return filepath.Join(home, fallback)
}
func configDir() string  { return filepath.Join(xdg("XDG_CONFIG_HOME", ".config"), "kaizo") }
func dataDir() string    { return filepath.Join(xdg("XDG_DATA_HOME", ".local/share"), "kaizo") }
func stateDir() string   { return filepath.Join(xdg("XDG_STATE_HOME", ".local/state"), "kaizo") }
func configPath() string { return filepath.Join(configDir(), "config.json") }
func shellPath() string {
	return filepath.Join(xdg("XDG_CONFIG_HOME", ".config"), "quickshell", "kaizo")
}
func binPath() string      { return filepath.Join(home, ".local/bin/kaizo") }
func unitPath() string     { return filepath.Join(xdg("XDG_CONFIG_HOME", ".config"), "systemd/user", unit) }
func exists(p string) bool { _, e := os.Lstat(p); return e == nil }
func has(c string) bool    { _, e := exec.LookPath(c); return e == nil }
func run(c string, a ...string) error {
	x := exec.Command(c, a...)
	x.Stdin = os.Stdin
	x.Stdout = os.Stdout
	x.Stderr = os.Stderr
	return x.Run()
}
func atomic(p string, b []byte, m fs.FileMode) error {
	if e := os.MkdirAll(filepath.Dir(p), 0700); e != nil {
		return e
	}
	f, e := os.CreateTemp(filepath.Dir(p), ".kaizo-")
	if e != nil {
		return e
	}
	defer os.Remove(f.Name())
	if e = f.Chmod(m); e == nil {
		_, e = f.Write(b)
	}
	if e == nil {
		e = f.Sync()
	}
	ce := f.Close()
	if e == nil {
		e = ce
	}
	if e != nil {
		return e
	}
	return os.Rename(f.Name(), p)
}
func defaults() map[string]any {
	return map[string]any{"theme": "dark", "accent": "#b7c5ff", "position": "top", "primaryMonitor": "", "primaryBarOnly": false, "barHeight": 44, "showTray": true, "showStats": true, "showDock": true, "showNotifications": true, "dnd": false, "gaming": false, "wallpaper": "", "profile": "full", "clock24": true, "dynamicColor": false, "showIsland": true, "onboarded": false, "clipboardHistory": false, "widgetOrder": []string{"clock", "stats", "tray", "inbox", "sound", "power"}, "widgets": []string{}, "pinned": []string{"org.mozilla.firefox", "org.kde.dolphin", "org.gnome.Nautilus"}}
}
func load() (map[string]any, error) {
	c := defaults()
	b, e := os.ReadFile(configPath())
	if os.IsNotExist(e) {
		return c, nil
	}
	if e != nil {
		return nil, e
	}
	var raw map[string]any
	if e = json.Unmarshal(b, &raw); e != nil {
		return nil, e
	}
	if raw == nil {
		return nil, errors.New("config must be an object")
	}
	for k, v := range raw {
		if e = validate(k, v); e != nil {
			return nil, e
		}
		c[k] = v
	}
	return c, nil
}
func save(c map[string]any) error {
	b, e := json.MarshalIndent(c, "", "  ")
	if e != nil {
		return e
	}
	return atomic(configPath(), append(b, '\n'), 0600)
}
func validate(k string, v any) error {
	switch k {
	case "theme":
		if s, ok := v.(string); ok && (s == "dark" || s == "light") {
			return nil
		}
	case "position":
		if s, ok := v.(string); ok && (s == "top" || s == "bottom") {
			return nil
		}
	case "profile":
		if s, ok := v.(string); ok && (s == "full" || s == "minimal" || s == "work" || s == "gaming") {
			return nil
		}
	case "accent":
		if s, ok := v.(string); ok && len(s) == 7 && s[0] == '#' {
			if _, e := strconv.ParseUint(s[1:], 16, 24); e == nil {
				return nil
			}
		}
	case "barHeight":
		switch n := v.(type) {
		case float64:
			if n >= 32 && n <= 64 && n == float64(int(n)) {
				return nil
			}
		case int:
			if n >= 32 && n <= 64 {
				return nil
			}
		}
	case "primaryBarOnly", "dynamicColor", "showIsland", "onboarded", "clipboardHistory", "showTray", "showStats", "showDock", "showNotifications", "dnd", "gaming", "clock24":
		if _, ok := v.(bool); ok {
			return nil
		}
	case "primaryMonitor":
		if s, ok := v.(string); ok && len(s) <= 128 && !strings.ContainsAny(s, "\n\r\x00/") {
			return nil
		}
	case "wallpaper":
		if s, ok := v.(string); ok && (s == "" || filepath.IsAbs(s)) && !strings.ContainsAny(s, "\n\r\x00") {
			return nil
		}
	case "widgetOrder", "widgets":
		return validateList(k, v)
	case "pinned":
		switch a := v.(type) {
		case []any:
			for _, s := range a {
				if _, ok := s.(string); !ok {
					return errors.New("pinned must contain strings")
				}
			}
			return nil
		case []string:
			return nil
		}
	}
	return fmt.Errorf("invalid setting %s", k)
}
func set(k, s string) error {
	var v any
	switch k {
	case "theme", "position", "accent", "wallpaper", "profile", "primaryMonitor":
		v = s
	default:
		if e := json.Unmarshal([]byte(s), &v); e != nil {
			return e
		}
	}
	if e := validate(k, v); e != nil {
		return e
	}
	c, e := load()
	if e != nil {
		return e
	}
	c[k] = v
	return save(c)
}
func profile(p string) error {
	c, e := load()
	if e != nil {
		return e
	}
	switch p {
	case "minimal", "full", "work", "gaming":
	default:
		return errors.New("choose full, minimal, work or gaming")
	}
	c["profile"] = p
	c["gaming"] = p == "gaming"
	c["dnd"] = p == "gaming"
	c["showStats"] = p != "minimal"
	c["showTray"] = true
	c["showDock"] = p == "full"
	c["showNotifications"] = true
	return save(c)
}

var input = bufio.NewReader(os.Stdin)

func ask(q string) bool {
	fmt.Print(q + " [y/N] ")
	s, _ := input.ReadString('\n')
	return strings.EqualFold(strings.TrimSpace(s), "y") || strings.EqualFold(strings.TrimSpace(s), "yes")
}

var packages = []string{"quickshell", "hyprlock", "hypridle", "pipewire", "wireplumber", "networkmanager", "bluez-utils", "brightnessctl", "playerctl", "libnotify", "wl-clipboard", "cliphist", "xdg-utils", "network-manager-applet", "blueman", "hyprpaper", "ttf-dejavu", "imagemagick", "curl", "git"}

func deps() error {
	if !has("pacman") {
		return errors.New("automatic dependency installation is Arch-only")
	}
	fmt.Println("Packages:", strings.Join(packages, " "))
	if !ask("Install dependencies with pacman (sudo)?") {
		return errors.New("dependency installation cancelled")
	}
	return run("sudo", append([]string{"pacman", "-S", "--needed"}, packages...)...)
}
func backup() (string, error) {
	b, e := os.ReadFile(configPath())
	if e != nil {
		return "", e
	}
	p := filepath.Join(dataDir(), "backups", time.Now().UTC().Format("20060102T150405.000000000Z")+".json")
	return p, atomic(p, b, 0600)
}
func restore(p string) error {
	b, e := os.ReadFile(p)
	if e != nil {
		return e
	}
	var c map[string]any
	if e = json.Unmarshal(b, &c); e != nil {
		return e
	}
	if c == nil {
		return errors.New("not a config object")
	}
	for k, v := range c {
		if e = validate(k, v); e != nil {
			return e
		}
	}
	if exists(configPath()) {
		if _, e = backup(); e != nil {
			return e
		}
	}
	return save(c)
}
func linkAtomic(p, target string) error {
	if e := os.MkdirAll(filepath.Dir(p), 0700); e != nil {
		return e
	}
	d, e := os.MkdirTemp(filepath.Dir(p), ".kaizo-link-")
	if e != nil {
		return e
	}
	defer os.RemoveAll(d)
	tmp := filepath.Join(d, "link")
	if e = os.Symlink(target, tmp); e != nil {
		return e
	}
	return os.Rename(tmp, p)
}
func managedLink() (string, error) {
	p := shellPath()
	s, e := os.Readlink(p)
	if os.IsNotExist(e) {
		return "", nil
	}
	if e != nil {
		return "", fmt.Errorf("refusing to replace unmanaged %s", p)
	}
	if filepath.Dir(s) != filepath.Join(dataDir(), "releases") {
		return "", errors.New("unmanaged shell symlink")
	}
	return s, nil
}
func release() (string, error) {
	h := sha256.New()
	entries, e := fs.ReadDir(assets, "shell")
	if e != nil {
		return "", e
	}
	for _, f := range entries {
		b, e := assets.ReadFile("shell/" + f.Name())
		if e != nil {
			return "", e
		}
		h.Write([]byte(f.Name()))
		h.Write(b)
	}
	return filepath.Join(dataDir(), "releases", fmt.Sprintf("%s-%x", version, h.Sum(nil)[:6])), nil
}
func deploy() error {
	old, e := managedLink()
	if e != nil {
		return e
	}
	p, e := release()
	if e != nil {
		return e
	}
	if e = os.MkdirAll(p, 0700); e != nil {
		return e
	}
	entries, _ := fs.ReadDir(assets, "shell")
	for _, f := range entries {
		b, e := assets.ReadFile("shell/" + f.Name())
		if e != nil {
			return e
		}
		if e = atomic(filepath.Join(p, f.Name()), b, 0600); e != nil {
			return e
		}
	}
	if old != "" && old != p {
		if e = atomic(filepath.Join(stateDir(), "previous"), []byte(old), 0600); e != nil {
			return e
		}
	}
	return linkAtomic(shellPath(), p)
}
func install(args []string) error {
	if os.Geteuid() == 0 {
		return errors.New("run as your normal desktop user, not root")
	}
	yes := false
	for _, a := range args {
		switch a {
		case "--yes":
			yes = true
		case "--deps":
			if e := deps(); e != nil {
				return e
			}
		default:
			return fmt.Errorf("unknown install option %s", a)
		}
	}
	fmt.Println("KAIZO /", version, "\nUser-only installation; existing Hyprland config stays untouched.")
	if !yes && !ask("Install or update Kaizo?") {
		return errors.New("cancelled")
	}
	if !has("quickshell") && !has("qs") {
		fmt.Println("Warning: Quickshell missing; run kaizo deps before starting.")
	}
	if _, e := managedLink(); e != nil {
		return e
	}
	if exists(unitPath()) {
		b, e := os.ReadFile(unitPath())
		if e != nil || !strings.HasPrefix(string(b), "# Managed by Kaizo\n") {
			return errors.New("refusing to replace unmanaged systemd unit")
		}
	}
	if exists(binPath()) {
		b, e := os.ReadFile(binPath())
		if e != nil {
			return e
		}
		if !strings.Contains(string(b), "kaizo-shell") {
			return errors.New("refusing to replace unrelated executable")
		}
	}
	if !exists(configPath()) {
		if e := save(defaults()); e != nil {
			return e
		}
	} else {
		if _, e := load(); e != nil {
			return e
		}
		if _, e := backup(); e != nil {
			return e
		}
	}
	exe, e := os.Executable()
	if e != nil {
		return e
	}
	b, e := os.ReadFile(exe)
	if e != nil {
		return e
	}
	if prior, err := managedLink(); err == nil && prior != "" && exists(binPath()) && !exists(filepath.Join(prior, "kaizo.bin")) {
		if old, err := os.ReadFile(binPath()); err == nil {
			if err = atomic(filepath.Join(prior, "kaizo.bin"), old, 0755); err != nil {
				return err
			}
		}
	}
	if e = deploy(); e != nil {
		return e
	}
	current, e := managedLink()
	if e != nil {
		return e
	}
	if e = atomic(filepath.Join(current, "kaizo.bin"), b, 0755); e != nil {
		return e
	}
	if e = atomic(binPath(), b, 0755); e != nil {
		return e
	}
	service := "# Managed by Kaizo\n[Unit]\nDescription=Kaizo Shell\nPartOf=graphical-session.target\n[Service]\nType=simple\nExecStart=%h/.local/bin/kaizo run\nRestart=on-failure\nRestartSec=3\n"
	if e = atomic(unitPath(), []byte(service), 0600); e != nil {
		return e
	}
	if has("systemctl") {
		if e = run("systemctl", "--user", "daemon-reload"); e != nil {
			fmt.Println("Warning: user systemd not available; use kaizo run.")
		}
	}
	fmt.Println("Installed:", binPath(), "\nRun kaizo start from Hyprland. See kaizo autostart for configuration snippets.")
	return nil
}
func qs() string {
	if has("quickshell") {
		return "quickshell"
	}
	return "qs"
}
func systemctl(a ...string) error { return run("systemctl", append([]string{"--user"}, a...)...) }
func start() error {
	if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") == "" || os.Getenv("WAYLAND_DISPLAY") == "" {
		return errors.New("run inside your Hyprland session")
	}
	vars := []string{"import-environment"}
	for _, k := range []string{"WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "QT_QPA_PLATFORM"} {
		if os.Getenv(k) != "" {
			vars = append(vars, k)
		}
	}
	if e := systemctl(vars...); e != nil {
		return e
	}
	return systemctl("start", unit)
}
func ipc(fn string) error { return run(qs(), "-c", "kaizo", "ipc", "call", "kaizo", fn) }
func rollback() error {
	b, e := os.ReadFile(filepath.Join(stateDir(), "previous"))
	if e != nil {
		return e
	}
	p := string(b)
	if filepath.Dir(p) != filepath.Join(dataDir(), "releases") || !exists(filepath.Join(p, "shell.qml")) {
		return errors.New("invalid previous release")
	}
	old, e := managedLink()
	if e != nil {
		return e
	}
	if e = linkAtomic(shellPath(), p); e != nil {
		return e
	}
	// Keep the current management CLI so older configuration schemas cannot break recovery.
	fmt.Println("Shell switched to:", filepath.Base(p), "(management CLI retained)")
	return atomic(filepath.Join(stateDir(), "previous"), []byte(old), 0600)
}
func uninstall() error {
	if !ask("Remove Kaizo shell and CLI? Config and backups will be preserved.") {
		return errors.New("cancelled")
	}
	p, e := managedLink()
	if e != nil {
		return e
	}
	if exists(unitPath()) {
		b, e := os.ReadFile(unitPath())
		if e != nil || !strings.HasPrefix(string(b), "# Managed by Kaizo\n") {
			return errors.New("unmanaged unit")
		}
		_ = systemctl("stop", unit)
		if e = os.Remove(unitPath()); e != nil {
			return e
		}
		_ = systemctl("daemon-reload")
	}
	if p != "" {
		if e = os.Remove(shellPath()); e != nil {
			return e
		}
	}
	if exists(binPath()) {
		b, e := os.ReadFile(binPath())
		if e != nil || !strings.Contains(string(b), "kaizo-shell") {
			return errors.New("unmanaged CLI")
		}
		if e = os.Remove(binPath()); e != nil {
			return e
		}
	}
	fmt.Println("Removed. Config and release history retained; remove any optional Hyprland snippets you added.")
	return nil
}
func doctor() error {
	fmt.Println("KAIZO DOCTOR", version)
	for _, c := range []string{"quickshell", "hyprctl", "systemctl", "wpctl", "nmcli", "bluetoothctl", "brightnessctl", "playerctl", "hyprlock", "hypridle", "hyprpaper", "cliphist", "wl-copy"} {
		s := "missing"
		if has(c) || (c == "quickshell" && has("qs")) {
			s = "OK"
		}
		fmt.Printf("%-18s %s\n", c, s)
	}
	for _, c := range []string{"waybar", "dunst", "mako"} {
		if exec.Command("pgrep", "-x", c).Run() == nil {
			fmt.Println("Possible conflict:", c)
		}
	}
	if _, e := load(); e != nil {
		return e
	}
	fmt.Println("Config: valid; Hyprland session:", os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") != "")
	return nil
}
func help() {
	fmt.Println(`KAIZO SHELL / ` + version + `
install [--yes] [--deps]  Install embedded shell and CLI
setup                    Interactive maintenance menu
deps                     Install Arch dependencies
start | stop | restart | reload | run | status | logs
launcher | search | controls | notifications | settings | calendar | power
config [KEY VALUE]       Show or change JSON settings
theme dark|light         profile full|minimal|work|gaming
gamemode toggle          lock             wallpaper /absolute/path
backup | restore FILE | reset
update [--check]         Download selected release channel
repair                   Redeploy embedded release
channel [stable|beta|nightly]
onboarding | studio | monitors | extensions
palette [IMAGE] | calc EXPR | files QUERY
clipboard list|copy|clear | monitor list|apply|confirm|revert
extension list|install FILE|remove ID | widget-order JSON
rollback                 Switch to previous shell release, then restart
uninstall | doctor | autostart | version | help`)
}
func configLock() (func(), error) {
	if e := os.MkdirAll(configDir(), 0700); e != nil {
		return nil, e
	}
	f, e := os.OpenFile(filepath.Join(configDir(), ".lock"), os.O_CREATE|os.O_RDWR, 0600)
	if e != nil {
		return nil, e
	}
	if e = syscall.Flock(int(f.Fd()), syscall.LOCK_EX); e != nil {
		f.Close()
		return nil, e
	}
	return func() { _ = syscall.Flock(int(f.Fd()), syscall.LOCK_UN); _ = f.Close() }, nil
}
func command(a []string) error {
	if len(a) == 0 {
		help()
		return nil
	}
	switch a[0] {
	case "config", "theme", "wallpaper", "profile", "gamemode", "restore", "reset", "install", "repair", "rollback", "uninstall", "extension", "palette", "channel", "widget-order":
		unlock, e := configLock()
		if e != nil {
			return e
		}
		defer unlock()
	}
	switch a[0] {
	case "help", "--help", "-h":
		help()
	case "version", "--version":
		fmt.Println(version)
	case "install":
		return install(a[1:])
	case "deps":
		return deps()
	case "setup":
		fmt.Println("1 Install/update  2 Doctor  3 Backup  4 Restore  5 Uninstall  6 Exit")
		fmt.Print("Select: ")
		s, _ := input.ReadString('\n')
		switch strings.TrimSpace(s) {
		case "1":
			return install(nil)
		case "2":
			return doctor()
		case "3":
			return command([]string{"backup"})
		case "4":
			return errors.New("use kaizo restore /path/to/backup.json")
		case "5":
			return uninstall()
		case "6":
			return nil
		default:
			return errors.New("invalid selection")
		}
	case "start":
		return start()
	case "stop", "restart", "status":
		return systemctl(a[0], unit)
	case "run":
		if p, e := managedLink(); e != nil {
			return e
		} else if p == "" {
			return errors.New("Kaizo is not installed")
		}
		return run(qs(), "-c", "kaizo")
	case "logs":
		return run("journalctl", "--user", "-u", unit, "-n", "100", "--no-pager")
	case "reload":
		return systemctl("restart", unit)
	case "search":
		return ipc("launcher")
	case "launcher", "controls", "notifications", "settings", "calendar", "power", "onboarding", "monitors", "studio", "extensions":
		return ipc(a[0])
	case "config":
		if len(a) == 1 {
			c, e := load()
			if e != nil {
				return e
			}
			b, _ := json.MarshalIndent(c, "", "  ")
			fmt.Println(string(b))
			return nil
		}
		if len(a) == 3 {
			return set(a[1], a[2])
		}
		return errors.New("usage: kaizo config [KEY VALUE]")
	case "theme", "wallpaper":
		if len(a) != 2 {
			return errors.New("provide a value")
		}
		if a[0] == "wallpaper" {
			if st, e := os.Stat(a[1]); e != nil || !st.Mode().IsRegular() {
				return errors.New("wallpaper must be an existing image file")
			}
		}
		if e := set(a[0], a[1]); e != nil {
			return e
		}
		if a[0] == "wallpaper" {
			c, e := load()
			if e == nil && c["dynamicColor"] == true {
				return palette(a[1])
			}
		}
		return nil
	case "profile":
		if len(a) != 2 {
			return errors.New("provide a profile")
		}
		return profile(a[1])
	case "gamemode":
		if len(a) != 2 || a[1] != "toggle" {
			return errors.New("usage: kaizo gamemode toggle")
		}
		c, e := load()
		if e != nil {
			return e
		}
		c["gaming"] = !c["gaming"].(bool)
		return save(c)
	case "lock":
		return run("hyprlock")
	case "backup":
		p, e := backup()
		if e == nil {
			fmt.Println(p)
		}
		return e
	case "restore":
		if len(a) != 2 {
			return errors.New("provide a backup file")
		}
		return restore(a[1])
	case "reset":
		if !ask("Back up settings and restore defaults?") {
			return errors.New("cancelled")
		}
		if exists(configPath()) {
			if _, e := backup(); e != nil {
				return e
			}
		}
		return save(defaults())
	case "update", "upgrade":
		return onlineUpdate(a[1:])
	case "repair":
		return deploy()
	case "channel", "extension", "palette", "files", "clipboard", "calc", "monitor", "widget-order":
		return extra(a)
	case "rollback":
		return rollback()
	case "uninstall":
		return uninstall()
	case "doctor":
		return doctor()
	case "autostart":
		fmt.Print(`Legacy hyprland.conf (review existing bindings first):
exec-once = ~/.local/bin/kaizo start
bind = SUPER, SPACE, exec, ~/.local/bin/kaizo search
bind = SUPER, N, exec, ~/.local/bin/kaizo notifications
bind = SUPER, L, exec, ~/.local/bin/kaizo lock
bind = SUPER SHIFT, G, exec, ~/.local/bin/kaizo gamemode toggle
Lua-based Hyprland (replace conflicting binding if present):
hl.bind("SUPER + space", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/kaizo search"))
`)
	default:
		return fmt.Errorf("unknown command: %s", a[0])
	}
	return nil
}
func main() {
	if e := command(os.Args[1:]); e != nil {
		fmt.Fprintln(os.Stderr, "kaizo:", e)
		os.Exit(1)
	}
}
