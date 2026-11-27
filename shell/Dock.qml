import QtQuick
import Quickshell
import Quickshell.Wayland
PanelWindow {
    id: win
    required property var host
    visible: host.cfg.showDock === true && !host.cfg.gaming
    anchors.bottom: true
    margins.bottom: host.cfg.position === "bottom" ? (host.cfg.barHeight || 44)+8 : 8
    implicitHeight: 56
    implicitWidth: dock.implicitWidth + 22
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    Rectangle {
        anchors.fill: parent; radius: 22; color: host.bg; border.color: host.raised
        Row {
            id: dock; anchors.centerIn: parent; spacing: 8
            Repeater {
                model: host.cfg.pinned || []
                Pill {
                    required property string modelData
                    property var app: DesktopEntries.byId(modelData)
                    host: win.host; compact: true
                    visible: !!app
                    text: app ? app.name.slice(0,2).toUpperCase() : ""
                    onClicked: if(app) app.execute()
                }
            }
            Pill { host: win.host; text: "+"; compact: true; onClicked: host.toggle("launcher",win.screen.name) }
        }
    }
}
