import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire

ShellRoot {
    id: shell
    property var cfg: ({})
    property string page: ""
    property string displayName: ""
    property var notices: []
    property bool initialConfig: true
    property var extensions: []
    property string toast: ""
    property string toastBody: ""
    property bool light: cfg.theme === "light"
    property color bg: light ? "#e9edf5" : "#111319"
    property color surface: light ? "#ffffff" : "#1c2029"
    property color raised: light ? "#dbe2ef" : "#292e3a"
    property color fg: light ? "#171a22" : "#e7eaf4"
    property color muted: light ? "#505a70" : "#a2acc2"
    property color accent: cfg.accent || "#b7c5ff"
    property color onAccent: "#181c2e"
    property string cli: Quickshell.env("HOME") + "/.local/bin/kaizo"
    property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    function action(args) { Quickshell.execDetached(args) }
    function change(k,v) { action([cli,"config",k,typeof v === "string" ? v : JSON.stringify(v)]) }
    function toggle(p, screenName) {
        let target = screenName || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : ""))
        if (page === p && displayName === target) page = ""
        else { displayName = target; page = p }
    }
    function readConfig() { try { cfg = JSON.parse(config.text()); if (!extensionQuery.running) extensionQuery.running=true; if(initialConfig){initialConfig=false;if(!cfg.onboarded)Qt.callLater(()=>shell.toggle("onboarding",""))} } catch(e) { console.warn("Kaizo configuration: " + e) } }
    Process { id: extensionQuery; command: [shell.cli,"extension","list"]; stdout: StdioCollector { onStreamFinished: {try {shell.extensions=JSON.parse(text)} catch(e) {shell.extensions=[]}} } }
    Process { command: ["wl-paste","--type","text","--watch","cliphist","store"]; running: shell.cfg.clipboardHistory===true }
    Process { command: ["wl-paste","--type","image","--watch","cliphist","store"]; running: shell.cfg.clipboardHistory===true }
    FileView {
        id: config
        path: shell.configHome + "/kaizo/config.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: shell.readConfig()
        printErrors: true
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].filter(x => x !== null && x !== undefined) }
    Loader {
        active: shell.cfg.showNotifications !== false
        sourceComponent: Component {
            NotificationServer {
                id: notificationServer
                bodySupported: true
                actionsSupported: true
                onNotification: n => {
                    n.tracked = true
                    const previous = shell.notices.filter(x => x.notification !== n)
                    if (!n.transient) {
                        for (const old of previous.slice(79)) if (old.notification) old.notification.expire()
                        shell.notices = [{notification:n, summary:n.summary, body:n.body, app:n.appName, stamp:new Date()}, ...previous.slice(0,79)]
                    }
                    if (!shell.cfg.dnd && !shell.cfg.gaming) {
                        shell.toast = n.summary || n.appName || "Notification"
                        shell.toastBody = n.body || ""
                        hideToast.restart()
                    }
                    if (n.transient) n.tracked = false
                }
            }
        }
    }
    Timer { id: hideToast; interval: 4500; onTriggered: shell.toast = "" }
    SystemStats { id: stats; active: shell.cfg.showStats !== false && !shell.cfg.gaming }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Scope {
                id: monitorGroup; required property var modelData
                Bar { host: shell; screen: monitorGroup.modelData; now: clock.date; status: stats }
                Desktop { host: shell; screen: monitorGroup.modelData }
                Overlay { host: shell; screen: monitorGroup.modelData; now: clock.date; status: stats }
                Dock { host: shell; screen: monitorGroup.modelData }
                Toast { host: shell; screen: monitorGroup.modelData }
                Island { host: shell; screen: monitorGroup.modelData }
            }
        }
    }
    IpcHandler {
        target: "kaizo"
        function launcher(): void { shell.toggle("launcher", "") }
        function controls(): void { shell.toggle("controls", "") }
        function notifications(): void { shell.toggle("notifications", "") }
        function settings(): void { shell.toggle("settings", "") }
        function calendar(): void { shell.toggle("calendar", "") }
        function onboarding(): void { shell.toggle("onboarding", "") }
        function monitors(): void { shell.toggle("monitors", "") }
        function studio(): void { shell.toggle("studio", "") }
        function extensions(): void { shell.toggle("extensions", "") }
        function power(): void { shell.toggle("power", "") }
    }
}
