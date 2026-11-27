package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io"
	"io/fs"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

var widgetIDs = []string{"clock", "stats", "tray", "inbox", "sound", "power"}
var idPattern = regexp.MustCompile(`^[a-zA-Z0-9_-]{1,40}$`)

func stringList(v any) ([]string, error) {
	switch a := v.(type) {
	case []string:
		return a, nil
	case []any:
		out := []string{}
		for _, x := range a {
			s, ok := x.(string)
			if !ok {
				return nil, errors.New("expected strings")
			}
			out = append(out, s)
		}
		return out, nil
	}
	return nil, errors.New("expected array")
}
func validateList(k string, v any) error {
	a, e := stringList(v)
	if e != nil {
		return e
	}
	seen := map[string]bool{}
	for _, s := range a {
		if seen[s] || !idPattern.MatchString(s) {
			return errors.New("duplicate or invalid widget ID")
		}
		seen[s] = true
	}
	if k == "widgetOrder" {
		if len(a) != len(widgetIDs) {
			return errors.New("widgetOrder must include each built-in widget")
		}
		for _, s := range widgetIDs {
			if !seen[s] {
				return errors.New("missing widget " + s)
			}
		}
	}
	if len(a) > 32 {
		return errors.New("too many widgets")
	}
	return nil
}
func jsonOut(v any) error { return json.NewEncoder(os.Stdout).Encode(v) }
func palette(path string) error {
	if path == "" {
		c, e := load()
		if e != nil {
			return e
		}
		path = c["wallpaper"].(string)
	}
	if !filepath.IsAbs(path) {
		return errors.New("choose an absolute image path")
	}
	if st, e := os.Stat(path); e != nil || !st.Mode().IsRegular() {
		return errors.New("image not found")
	}
	// Downsample before clustering to keep memory and processing costs bounded.
	b, e := exec.Command("magick", "-limit", "memory", "128MiB", "-limit", "map", "256MiB", path+"[0]", "-thumbnail", "64x64!", "-colors", "8", "-format", "%c", "histogram:info:-").Output()
	if e != nil {
		return fmt.Errorf("palette: %w", e)
	}
	re := regexp.MustCompile(`(?i)([0-9]+):.*?#([0-9a-f]{6})(?:[0-9a-f]{2})?\b`)
	best := -1.0
	color := "#b7c5ff"
	for _, m := range re.FindAllStringSubmatch(string(b), -1) {
		n, _ := strconv.ParseFloat(m[1], 64)
		rgb, _ := strconv.ParseUint(m[2], 16, 24)
		r, g, bl := float64(rgb>>16), float64((rgb>>8)&255), float64(rgb&255)
		max := math.Max(r, math.Max(g, bl))
		min := math.Min(r, math.Min(g, bl))
		score := n * (0.1 + (max-min)/255)
		if score > best {
			best = score // Lift dark colors for readability on the accent foreground.
			r = 0.55*r + 0.45*255
			g = 0.55*g + 0.45*255
			bl = 0.55*bl + 0.45*255
			color = fmt.Sprintf("#%02x%02x%02x", int(r), int(g), int(bl))
		}
	}
	if best < 0 {
		return errors.New("could not extract image colors")
	}
	return set("accent", color)
}
func evaluate(s string) (float64, error) {
	if len(s) > 256 {
		return 0, errors.New("expression too long")
	}
	x, e := parser.ParseExpr(s)
	if e != nil {
		return 0, e
	}
	var visit func(ast.Expr) (float64, error)
	visit = func(x ast.Expr) (float64, error) {
		switch n := x.(type) {
		case *ast.BasicLit:
			if n.Kind == token.INT || n.Kind == token.FLOAT {
				return strconv.ParseFloat(n.Value, 64)
			}
		case *ast.ParenExpr:
			return visit(n.X)
		case *ast.UnaryExpr:
			v, e := visit(n.X)
			if e != nil {
				return 0, e
			}
			if n.Op == token.SUB {
				return -v, nil
			}
			if n.Op == token.ADD {
				return v, nil
			}
		case *ast.BinaryExpr:
			a, e := visit(n.X)
			if e != nil {
				return 0, e
			}
			b, e := visit(n.Y)
			if e != nil {
				return 0, e
			}
			switch n.Op {
			case token.ADD:
				return a + b, nil
			case token.SUB:
				return a - b, nil
			case token.MUL:
				return a * b, nil
			case token.QUO:
				if b != 0 {
					return a / b, nil
				}
			case token.REM:
				if b != 0 {
					return math.Mod(a, b), nil
				}
			}
		}
		return 0, errors.New("only arithmetic + - * / % and parentheses are supported")
	}
	v, e := visit(x)
	if e == nil && (math.IsInf(v, 0) || math.IsNaN(v)) {
		e = errors.New("non-finite result")
	}
	return v, e
}
func searchFiles(q string) error {
	q = strings.ToLower(strings.TrimSpace(q))
	out := []string{}
	if len(q) < 2 {
		return jsonOut(out)
	}
	count := 0
	deadline := time.Now().Add(2 * time.Second)
	for _, d := range []string{"Documents", "Downloads", "Desktop", "Pictures", "Music", "Videos"} {
		_ = filepath.WalkDir(filepath.Join(home, d), func(p string, entry fs.DirEntry, e error) error {
			if e != nil {
				return nil
			}
			if time.Now().After(deadline) || count > 25000 || len(out) >= 80 {
				return fs.SkipAll
			}
			count++
			if strings.HasPrefix(entry.Name(), ".") {
				if entry.IsDir() {
					return fs.SkipDir
				}
				return nil
			}
			if !entry.IsDir() && strings.Contains(strings.ToLower(entry.Name()), q) {
				out = append(out, p)
			}
			return nil
		})
	}
	return jsonOut(out)
}

type extension struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Kind  string `json:"kind"`
	Text  string `json:"text"`
}

func extensionPath(id string) string { return filepath.Join(dataDir(), "extensions", id+".json") }
func extensions(args []string) error {
	if len(args) == 0 {
		return errors.New("extension list|install FILE|remove ID")
	}
	switch args[0] {
	case "list":
		out := []extension{}
		c, e := load()
		if e != nil {
			return e
		}
		ids, _ := stringList(c["widgets"])
		for _, id := range ids {
			b, e := os.ReadFile(extensionPath(id))
			var x extension
			if e == nil && json.Unmarshal(b, &x) == nil && x.ID == id && x.Kind == "text" {
				out = append(out, x)
			}
		}
		return jsonOut(out)
	case "install":
		if len(args) != 2 {
			return errors.New("provide a JSON manifest")
		}
		f, e := os.Open(args[1])
		if e != nil {
			return e
		}
		defer f.Close()
		var x extension
		dec := json.NewDecoder(io.LimitReader(f, 16385))
		dec.DisallowUnknownFields()
		if e = dec.Decode(&x); e != nil {
			return e
		}
		var extra any
		if dec.Decode(&extra) != io.EOF {
			return errors.New("unexpected trailing data")
		}
		if !idPattern.MatchString(x.ID) || x.Kind != "text" || len(x.Label) > 80 || len(x.Text) > 500 || x.Label == "" {
			return errors.New("invalid text widget manifest")
		}
		c, e := load()
		if e != nil {
			return e
		}
		ids, _ := stringList(c["widgets"])
		found := false
		for _, id := range ids {
			if id == x.ID {
				found = true
			}
		}
		if !found {
			ids = append(ids, x.ID)
		}
		if e = validateList("widgets", ids); e != nil {
			return e
		}
		b, _ := json.Marshal(x)
		if e = atomic(extensionPath(x.ID), b, 0600); e != nil {
			return e
		}
		c["widgets"] = ids
		return save(c)
	case "remove":
		if len(args) != 2 || !idPattern.MatchString(args[1]) {
			return errors.New("provide widget ID")
		}
		c, e := load()
		if e != nil {
			return e
		}
		ids, _ := stringList(c["widgets"])
		out := []string{}
		for _, id := range ids {
			if id != args[1] {
				out = append(out, id)
			}
		}
		c["widgets"] = out
		if e = save(c); e != nil {
			return e
		}
		e = os.Remove(extensionPath(args[1]))
		if os.IsNotExist(e) {
			return nil
		}
		return e
	}
	return errors.New("unknown extension action")
}
func clipboard(args []string) error {
	if len(args) == 0 {
		return errors.New("clipboard list|copy|clear")
	}
	if args[0] == "clear" {
		return run("cliphist", "wipe")
	}
	c, e := load()
	if e != nil {
		return e
	}
	if c["clipboardHistory"] != true {
		return errors.New("clipboard history is disabled")
	}
	switch args[0] {
	case "list":
		b, e := exec.Command("cliphist", "list").Output()
		if e != nil {
			return e
		}
		out := []string{}
		scan := bufio.NewScanner(strings.NewReader(string(b)))
		for scan.Scan() && len(out) < 100 {
			out = append(out, scan.Text())
		}
		return jsonOut(out)
	case "copy":
		if len(args) != 2 {
			return errors.New("provide clipboard entry")
		}
		id := strings.SplitN(args[1], "\t", 2)[0]
		if _, e = strconv.ParseUint(id, 10, 64); e != nil {
			return e
		}
		dec := exec.Command("cliphist", "decode")
		dec.Stdin = strings.NewReader(id + "\n")
		r, e := dec.StdoutPipe()
		if e != nil {
			return e
		}
		cp := exec.Command("wl-copy")
		cp.Stdin = r
		if e = dec.Start(); e != nil {
			return e
		}
		ce := cp.Run()
		de := dec.Wait()
		if ce != nil {
			return ce
		}
		return de
	}
	return errors.New("unknown clipboard action")
}
func extra(a []string) error {
	switch a[0] {
	case "palette":
		p := ""
		if len(a) == 2 {
			p = a[1]
		}
		return palette(p)
	case "calc":
		v, e := evaluate(strings.Join(a[1:], " "))
		if e != nil {
			return e
		}
		fmt.Println(v)
		return nil
	case "files":
		return searchFiles(strings.Join(a[1:], " "))
	case "extension":
		return extensions(a[1:])
	case "clipboard":
		return clipboard(a[1:])
	case "widget-order":
		if len(a) != 2 {
			return errors.New("provide JSON list")
		}
		return set("widgetOrder", a[1])
	case "channel":
		return channelCommand(a[1:])
	case "monitor":
		return monitorCommand(a[1:])
	}
	return errors.New("unknown command")
}
