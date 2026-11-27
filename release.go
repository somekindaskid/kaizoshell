package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"time"
)

const upstream = "somekindaskid/kaizoshell"

func channelCommand(a []string) error {
	p := filepath.Join(stateDir(), "channel")
	if len(a) == 0 {
		fmt.Println(currentChannel())
		return nil
	}
	if len(a) != 1 || !(a[0] == "stable" || a[0] == "beta" || a[0] == "nightly") {
		return errors.New("choose stable, beta or nightly")
	}
	return atomic(p, []byte(a[0]), 0600)
}
func currentChannel() string {
	b, _ := os.ReadFile(filepath.Join(stateDir(), "channel"))
	switch string(b) {
	case "stable", "beta", "nightly":
		return string(b)
	}
	return "stable"
}

type releaseAsset struct {
	Name string `json:"name"`
	URL  string `json:"browser_download_url"`
}
type remoteRelease struct {
	Tag    string         `json:"tag_name"`
	Draft  bool           `json:"draft"`
	Pre    bool           `json:"prerelease"`
	Assets []releaseAsset `json:"assets"`
}

var client = &http.Client{Timeout: 90 * time.Second}

func download(ctx context.Context, url string, max int64) ([]byte, error) {
	req, e := http.NewRequestWithContext(ctx, "GET", url, nil)
	if e != nil {
		return nil, e
	}
	req.Header.Set("User-Agent", "kaizo-shell/"+version)
	resp, e := client.Do(req)
	if e != nil {
		return nil, e
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("HTTP %d: release might not be published", resp.StatusCode)
	}
	b, e := io.ReadAll(io.LimitReader(resp.Body, max+1))
	if int64(len(b)) > max {
		return nil, errors.New("download exceeds limit")
	}
	return b, e
}
func chooseRelease(rs []remoteRelease, ch string) (remoteRelease, error) {
	for _, r := range rs {
		if r.Draft {
			continue
		}
		isNight := strings.HasPrefix(r.Tag, "nightly-")
		if (ch == "stable" && !r.Pre && !isNight) || (ch == "beta" && r.Pre && !isNight) || (ch == "nightly" && r.Pre && isNight) {
			return r, nil
		}
	}
	return remoteRelease{}, errors.New("no release published for " + ch)
}
func onlineUpdate(args []string) error {
	if len(args) > 1 || (len(args) == 1 && args[0] != "--check") {
		return errors.New("update [--check]")
	}
	if runtime.GOOS != "linux" {
		return errors.New("Linux only")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	b, e := download(ctx, "https://api.github.com/repos/"+upstream+"/releases?per_page=100", 2<<20)
	if e != nil {
		return e
	}
	var rs []remoteRelease
	if e = json.Unmarshal(b, &rs); e != nil {
		return e
	}
	r, e := chooseRelease(rs, currentChannel())
	if e != nil {
		return e
	}
	fmt.Println("Installed:", version, "Available:", r.Tag, "Channel:", currentChannel())
	if len(args) == 1 || r.Tag == "v"+version {
		return nil
	}
	name := "kaizo-linux-" + runtime.GOARCH
	urls := map[string]string{}
	prefix := "https://github.com/" + upstream + "/releases/download/"
	for _, a := range r.Assets {
		if strings.HasPrefix(a.URL, prefix) {
			urls[a.Name] = a.URL
		}
	}
	if urls[name] == "" || urls["SHA256SUMS"] == "" {
		return errors.New("release is missing binary or checksums")
	}
	if !ask("Download and install " + r.Tag + "? (A different channel may downgrade.)") {
		return errors.New("cancelled")
	}
	s, e := download(ctx, urls["SHA256SUMS"], 64<<10)
	if e != nil {
		return e
	}
	payload, e := download(ctx, urls[name], 64<<20)
	if e != nil {
		return e
	}
	if e = verifyChecksum(string(s), name, payload); e != nil {
		return e
	}
	dir, e := os.MkdirTemp("", "kaizo-update-")
	if e != nil {
		return e
	}
	defer os.RemoveAll(dir)
	p := filepath.Join(dir, "kaizo")
	if e = atomic(p, payload, 0700); e != nil {
		return e
	}
	if e = run(p, "install", "--yes"); e != nil {
		return e
	}
	fmt.Println("Updated. Run kaizo restart.")
	return nil
}
func verifyChecksum(s, name string, b []byte) error {
	h := sha256.Sum256(b)
	for _, line := range strings.Split(s, "\n") {
		f := strings.Fields(line)
		if len(f) == 2 && strings.TrimPrefix(f[1], "*") == name && strings.EqualFold(f[0], hex.EncodeToString(h[:])) {
			return nil
		}
	}
	return errors.New("release checksum mismatch")
}

var monitorName = regexp.MustCompile(`^[A-Za-z0-9_.-]{1,64}$`)
var monitorMode = regexp.MustCompile(`^(preferred|[0-9]{3,5}x[0-9]{3,5}@[0-9]{2,3}(\.[0-9]{1,3})?)$`)
var monitorPosition = regexp.MustCompile(`^(auto|-?[0-9]{1,5}x-?[0-9]{1,5})$`)
var monitorScale = regexp.MustCompile(`^[1-4](\.[0-9]{1,3})?$`)

func monitorRule(a []string) (string, error) {
	if len(a) != 4 || !monitorName.MatchString(a[0]) || !monitorMode.MatchString(a[1]) || !monitorPosition.MatchString(a[2]) || !monitorScale.MatchString(a[3]) {
		return "", errors.New("expected OUTPUT preferred|1920x1080@60 auto|0x0 SCALE (1–4)")
	}
	return strings.Join(a, ","), nil
}
func monitorCommand(a []string) error {
	if len(a) == 0 {
		return errors.New("monitor list|apply|confirm|revert")
	}
	switch a[0] {
	case "list":
		return run("hyprctl", "-j", "monitors", "all")
	case "apply":
		rule, e := monitorRule(a[1:])
		if e != nil {
			return e
		}
		if !has("systemd-run") {
			return errors.New("systemd-run required for automatic recovery")
		} // The temporary change expires unless explicitly confirmed.
		if e = run("systemctl", "--user", "stop", "kaizo-monitor-revert.timer"); e != nil { /* timer may not exist yet */
		}
		if e = run("systemd-run", "--user", "--unit=kaizo-monitor-revert", "--on-active=20s", "hyprctl", "reload"); e != nil {
			return e
		}
		out, e := exec.Command("hyprctl", "keyword", "monitor", rule).CombinedOutput()
		if e != nil || strings.TrimSpace(string(out)) != "ok" {
			_ = run("hyprctl", "reload")
			return fmt.Errorf("monitor rule rejected: %s; this compositor may require Lua configuration", out)
		}
		fmt.Println("Temporary change. Confirm within 20 seconds; otherwise Hyprland config reloads.")
		return nil
	case "confirm":
		return run("systemctl", "--user", "stop", "kaizo-monitor-revert.timer")
	case "revert":
		_ = run("systemctl", "--user", "stop", "kaizo-monitor-revert.timer")
		return run("hyprctl", "reload")
	case "preview":
		rule, e := monitorRule(a[1:])
		if e == nil {
			fmt.Println("monitor = " + rule)
		}
		return e
	}
	return errors.New("unknown monitor action")
}
