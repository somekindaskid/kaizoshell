#!/usr/bin/env python3
"""Apply narrowly scoped Kaizo changes to the pinned, MIT-licensed SleepyShell checkout."""
import pathlib
import sys
import subprocess
import shutil
import argparse

PIN = "c87dfb8c8a4dd6972a0b35188ddbb553ad0669b5"
HERE = pathlib.Path(__file__).resolve().parent

def replace_once(text, old, new, path):
    if text.count(new) == 1:
        return text
    if text.count(old) != 1:
        raise RuntimeError(f"{path}: upstream anchor changed")
    return text.replace(old, new, 1)

def changes(root):
    # Build from Git's immutable pinned version, not from already modified text.
    def original(path):
        return subprocess.check_output(["git", "-C", str(root), "show", f"{PIN}:{path}"], text=True)
    edits = {}
    p = "shell.qml"
    s = original(p)
    s = replace_once(s, "    SettingsServer {}", "    SettingsServer {}\n    KaizoSearch { id: kaizoSearch }", p)
    s = replace_once(s, '            if (what === "toggle" && arg)\n                Popouts.toggle(arg);',
        '            if (what === "toggle" && arg === "kaizo-search")\n                kaizoSearch.toggle();\n            else if (what === "toggle" && arg)\n                Popouts.toggle(arg);', p)
    s = replace_once(s, '    IpcHandler {\n        target: "sleepybar"',
        '    IpcHandler {\n        target: "kaizo"\n        function search(): void { kaizoSearch.toggle(); }\n        function ready(): string { return "Kaizo SleepyShell base"; }\n        function quitShell(): void { Qt.exit(0); }\n    }\n    IpcHandler {\n        target: "sleepybar"', p)
    edits[p] = s
    p = "tools/install.py"
    s = original(p)
    s = replace_once(s, 'BINDS = [\n', 'BINDS = [\n    (["SUPER"], "space", \'hl.bind("SUPER + space", hl.dsp.event("sleepyshell:toggle:kaizo-search"))\', "Kaizo search"),\n', p)
    # Keep matching window rules in sync with the branded settings title.
    s = s.replace('title = "^Sleepysettings$"', 'title = "^Kaizo Settings$"')
    edits[p] = s
    p = "sleepysettings/Sleepysettings.qml"
    s = original(p)
    s = replace_once(s, 'title: "Sleepysettings"', 'title: "Kaizo Settings"', p)
    s = replace_once(s, 'text: "Sleepysettings"', 'text: "Kaizo Settings"', p)
    edits[p] = s
    p = "services/Keybinds.qml"
    s = original(p)
    s = replace_once(s, '"sleepyshell:keybinds": "Toggle the Keybinds window",',
        '"sleepyshell:keybinds": "Toggle the Keybinds window",\n                "sleepyshell:toggle:kaizo-search": "Toggle Kaizo search",', p)
    s = replace_once(s, 'readonly property var shellActions: [', 'readonly property var shellActions: [\n        { event: "sleepyshell:toggle:kaizo-search", label: "Kaizo search", suggested: "SUPER + space" },', p)
    edits[p] = s
    return edits

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("checkout", type=pathlib.Path)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    root = args.checkout.resolve()
    head = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    if head != PIN:
        raise RuntimeError(f"Unexpected upstream commit {head}")
    edits = changes(root)
    # Refuse unrelated user edits; only the exact pinned original or exact Kaizo patch is accepted.
    for p, s in edits.items():
        current = (root / p).read_text()
        original = subprocess.check_output(["git", "-C", str(root), "show", f"{PIN}:{p}"], text=True)
        if current not in (original, s):
            raise RuntimeError(f"Refusing to replace local edits in {p}")
    target = root / "KaizoSearch.qml"
    payload = (HERE / "KaizoSearch.qml").read_text()
    if target.exists() and target.read_text() != payload:
        raise RuntimeError("Refusing to replace a modified KaizoSearch.qml")
    if not args.check:
        for p, s in edits.items():
            (root / p).write_text(s)
        shutil.copyfile(HERE / "KaizoSearch.qml", target)
    print("Kaizo patch anchors verified:", len(edits), "upstream files")

if __name__ == "__main__":
    main()
