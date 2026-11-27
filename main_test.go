package main

import (
	"os"
	"path/filepath"
	"testing"
)

func testHome(t *testing.T) {
	t.Helper()
	old := home
	home = t.TempDir()
	t.Cleanup(func() { home = old })
	for _, k := range []string{"XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME"} {
		t.Setenv(k, "")
	}
}
func TestConfigValidation(t *testing.T) {
	testHome(t)
	if err := save(defaults()); err != nil {
		t.Fatal(err)
	}
	for _, x := range [][2]string{{"theme", "light"}, {"barHeight", "56"}, {"accent", "#123abc"}, {"gaming", "true"}, {"pinned", `["firefox"]`}} {
		if err := set(x[0], x[1]); err != nil {
			t.Fatal(err)
		}
	}
	c, e := load()
	if e != nil || c["theme"] != "light" || c["barHeight"] != float64(56) || c["gaming"] != true {
		t.Fatalf("%v %v", c, e)
	}
	for _, x := range [][2]string{{"theme", "purple"}, {"barHeight", "999"}, {"accent", "#fff"}, {"gaming", "1"}, {"bogus", "true"}, {"pinned", `[1]`}} {
		if err := set(x[0], x[1]); err == nil {
			t.Fatalf("accepted %v", x)
		}
	}
}
func TestBackupRestore(t *testing.T) {
	testHome(t)
	if e := save(defaults()); e != nil {
		t.Fatal(e)
	}
	p, e := backup()
	if e != nil {
		t.Fatal(e)
	}
	if e = set("theme", "light"); e != nil {
		t.Fatal(e)
	}
	if e = restore(p); e != nil {
		t.Fatal(e)
	}
	c, e := load()
	if e != nil || c["theme"] != "dark" {
		t.Fatal(c, e)
	}
	if e = os.WriteFile(p, []byte(`{"theme":[]}`), 0600); e != nil {
		t.Fatal(e)
	}
	if e = restore(p); e == nil {
		t.Fatal("accepted invalid backup")
	}
}
func TestDeployAndRollback(t *testing.T) {
	testHome(t)
	old := filepath.Join(dataDir(), "releases", "old")
	if e := atomic(filepath.Join(old, "shell.qml"), []byte("old"), 0600); e != nil {
		t.Fatal(e)
	}
	if e := linkAtomic(shellPath(), old); e != nil {
		t.Fatal(e)
	}
	if e := deploy(); e != nil {
		t.Fatal(e)
	}
	cur, e := managedLink()
	if e != nil || cur == old {
		t.Fatal(cur, e)
	}
	if e = rollback(); e != nil {
		t.Fatal(e)
	}
	if p, e := managedLink(); e != nil || p != old {
		t.Fatal(p, e)
	}
	if e = rollback(); e != nil {
		t.Fatal(e)
	}
	if p, e := managedLink(); e != nil || p != cur {
		t.Fatal(p, e)
	}
}
func TestUnmanagedPath(t *testing.T) {
	testHome(t)
	if e := os.MkdirAll(shellPath(), 0700); e != nil {
		t.Fatal(e)
	}
	if e := deploy(); e == nil {
		t.Fatal("overwrote unrelated shell")
	}
}
func TestProfile(t *testing.T) {
	testHome(t)
	if e := profile("gaming"); e != nil {
		t.Fatal(e)
	}
	c, e := load()
	if e != nil || c["gaming"] != true || c["dnd"] != true {
		t.Fatal(c, e)
	}
	if e = profile("work"); e != nil {
		t.Fatal(e)
	}
	c, e = load()
	if e != nil || c["gaming"] != false || c["dnd"] != false {
		t.Fatal(c, e)
	}
}
