import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
PanelWindow {
    id: win
    required property var host
    visible: host.toast !== "" && !host.cfg.dnd && !host.cfg.gaming && (!Hyprland.focusedMonitor || Hyprland.focusedMonitor.name === screen.name)
    anchors { top: true; right: true }
    margins { top: 54; right: 12 }
    implicitWidth: 350; implicitHeight: 110
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    Rectangle {
        anchors.fill: parent; radius: 22; color: host.bg; border.color: host.raised
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 16
            Text { text: host.toast; color: host.fg; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight; textFormat: Text.PlainText }
            Text { text: host.toastBody; color: host.muted; Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.PlainText }
            Pill { host: win.host; compact: true; text: "Open inbox"; onClicked: {host.toast="";host.toggle("notifications",win.screen.name)} }
        }
    }
}
