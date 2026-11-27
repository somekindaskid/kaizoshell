import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
PanelWindow {
    id: win
    required property var host
    required property date now
    required property var status
    visible: host.page !== "" && host.displayName === screen.name
    anchors { top: true; right: host.page !== "launcher"; left: false }
    margins { top: host.cfg.position === "bottom" ? 12 : (host.cfg.barHeight || 44)+8; right: 12 }
    implicitWidth: Math.min(host.page === "launcher" ? 600 : 440, screen ? screen.width-24 : 440)
    implicitHeight: Math.min(host.page === "launcher" ? 530 : 600, screen ? screen.height-100 : 600)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: !visible ? WlrKeyboardFocus.None : host.page === "launcher" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    color: "transparent"
    Rectangle {
        anchors.fill: parent; radius: 26; color: host.bg; border.color: host.raised
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 18; spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Text { text: "KAIZO / " + host.page.toUpperCase(); color: host.accent; font.pixelSize: 12; font.letterSpacing: 2; font.bold: true; Layout.fillWidth: true }
                Pill { host: win.host; compact: true; text: "×"; onClicked: host.page="" }
            }
            Loader {
                id: loader
                Layout.fillWidth: true; Layout.fillHeight: true
                sourceComponent: !win.visible ? null : host.page === "launcher" ? launcher : host.page === "controls" ? controls : host.page === "notifications" ? notifications : host.page === "settings" ? settings : host.page === "calendar" ? calendar : host.page === "onboarding" ? onboarding : host.page === "studio" ? studio : host.page === "monitors" ? monitors : host.page === "extensions" ? extensions : power
            }
        }
        Shortcut { sequence: "Escape"; enabled: win.visible; onActivated: host.page="" }
    }
    Component { id: launcher; Launcher { host: win.host } }
    Component { id: controls; Controls { host: win.host; status: win.status } }
    Component { id: notifications; Inbox { host: win.host } }
    Component { id: settings; Settings { host: win.host } }
    Component { id: calendar; CalendarPanel { host: win.host; now: win.now } }
    Component { id: onboarding; Onboarding { host:win.host } }
    Component { id: studio; Studio { host:win.host } }
    Component { id: monitors; Monitors { host:win.host } }
    Component { id: extensions; Extensions { host:win.host } }
    Component { id: power; PowerPanel { host: win.host } }
}
