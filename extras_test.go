package main

import (
	"crypto/sha256"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func TestCalculator(t *testing.T) {
	for expr, want := range map[string]float64{"2*(3+4)": 14, "10/4": 2.5, "-3%2": -1} {
		v, e := evaluate(expr)
		if e != nil || v != want {
			t.Fatal(expr, v, e)
		}
	}
	for _, s := range []string{"1/0", "os.Exit(0)", "2 ** 3", "1e999"} {
		if _, e := evaluate(s); e == nil {
			t.Fatal("accepted", s)
		}
	}
}
func TestWidgetOrder(t *testing.T) {
	testHome(t)
	if e := set("widgetOrder", `["power","clock","stats","tray","sound","inbox"]`); e != nil {
		t.Fatal(e)
	}
	if e := set("widgetOrder", `["clock","clock"]`); e == nil {
		t.Fatal("accepted invalid order")
	}
}
func TestExtensions(t *testing.T) {
	testHome(t)
	p := filepath.Join(home, "widget.json")
	if e := os.WriteFile(p, []byte(`{"id":"focus","kind":"text","label":"Focus","text":"Hello"}`), 0600); e != nil {
		t.Fatal(e)
	}
	if e := extensions([]string{"install", p}); e != nil {
		t.Fatal(e)
	}
	if !exists(extensionPath("focus")) {
		t.Fatal("missing widget")
	}
	if e := extensions([]string{"remove", "focus"}); e != nil {
		t.Fatal(e)
	}
	if exists(extensionPath("focus")) {
		t.Fatal("widget remains")
	}
	os.WriteFile(p, []byte(`{"id":"../evil","kind":"text","label":"Focus","text":"Hello"}`), 0600)
	if e := extensions([]string{"install", p}); e == nil {
		t.Fatal("accepted invalid id")
	}
}
func TestChannels(t *testing.T) {
	testHome(t)
	if currentChannel() != "stable" {
		t.Fatal("bad default")
	}
	if e := channelCommand([]string{"beta"}); e != nil || currentChannel() != "beta" {
		t.Fatal(e)
	}
	rs := []remoteRelease{{Tag: "nightly-1", Pre: true}, {Tag: "v1-beta", Pre: true}, {Tag: "v1"}}
	for ch, want := range map[string]string{"stable": "v1", "beta": "v1-beta", "nightly": "nightly-1"} {
		r, e := chooseRelease(rs, ch)
		if e != nil || r.Tag != want {
			t.Fatal(ch, r, e)
		}
	}
}
func TestChecksum(t *testing.T) {
	b := []byte("test")
	s := fmt.Sprintf("%x  kaizo-linux-amd64\n", sha256.Sum256(b))
	if e := verifyChecksum(s, "kaizo-linux-amd64", b); e != nil {
		t.Fatal(e)
	}
	if e := verifyChecksum(s, "kaizo-linux-amd64", []byte("bad")); e == nil {
		t.Fatal("accepted wrong data")
	}
}
func TestMonitorRule(t *testing.T) {
	if r, e := monitorRule([]string{"DP-1", "1920x1080@144", "-1920x0", "1.25"}); e != nil || r != "DP-1,1920x1080@144,-1920x0,1.25" {
		t.Fatal(r, e)
	}
	if _, e := monitorRule([]string{"DP-1;exec", "preferred", "auto", "1"}); e == nil {
		t.Fatal("accepted invalid output")
	}
}
