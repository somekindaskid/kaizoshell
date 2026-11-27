import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

PanelWindow {
    id: bar
    required property var host
    required property date now
    required property var status
    required property var targetScreen
    screen: targetScreen
    anchors { top: host.cfg.position !== "bottom"; bottom: host.cfg.position === "bottom"; left: true; right: true }
    implicitHeight: host.cfg.barHeight || 44
    visible: !host.cfg.gaming && (!host.cfg.primaryBarOnly || (targetScreen && targetScreen.name === host.primaryBarScreen()))
    color: "transparent"
    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: 16
        color: host.bg
        border.color: host.raised
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 5
            Pill { host: bar.host; compact: true; selected: true; text: "K"; onClicked: host.toggle("launcher",bar.screen.name) }
            Repeater {
                model: [1,2,3,4,5,6,7,8,9,10]
                Pill {
                    required property int modelData
                    host: bar.host; compact: true
                    visible: bar.width >= 1000 || modelData <= 5
                    text: String(modelData)
                    selected: {
                        const m = Hyprland.monitorFor(bar.screen)
                        return m && m.activeWorkspace ? m.activeWorkspace.id === modelData : false
                    }
                    onClicked: Hyprland.dispatch("workspace " + modelData)
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                color: host.muted
                font.pixelSize: 12
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : "Kaizo Shell"
                visible: bar.width >= 800
            }
            Item { Layout.fillWidth: true; visible: bar.width < 800 }
            Repeater {
                model: host.cfg.widgetOrder || ["clock","stats","tray","inbox","sound","power"]
                Loader {
                    required property string modelData
                    active: modelData!=="stats" || host.cfg.showStats!==false
                    visible: modelData === "stats" ? host.cfg.showStats !== false && bar.width > 1250 : modelData === "tray" ? host.cfg.showTray !== false && bar.width > 850 : true
                    sourceComponent: ({clock:clockWidget,stats:statsWidget,tray:trayWidget,inbox:inboxWidget,sound:soundWidget,power:powerWidget})[modelData]
                }
            }
            Repeater { model: bar.host.extensions.slice(0,3); Text { required property var modelData; visible:bar.width>1250; text:modelData.text; textFormat:Text.PlainText; color:host.muted; font.pixelSize:11; elide:Text.ElideRight; Layout.maximumWidth:110 } }

        }
    }

    Component { id:clockWidget; Pill { host: bar.host; compact: true; text: Qt.formatDateTime(bar.now,host.cfg.clock24 === false ? "ddd · h:mm AP" : "ddd · HH:mm"); onClicked: host.toggle("calendar",bar.screen.name) } }
    Component { id:statsWidget; Text { visible: host.cfg.showStats !== false && bar.width > 1250; text: bar.status ? (bar.status.summary || "System") : "System"; color: host.muted; font.pixelSize: 11 } }
    Component { id:trayWidget; Row {
                visible: host.cfg.showTray !== false && bar.width > 850
                spacing: 4
                Repeater {
                    model: SystemTray.items
                    Item {
                        required property var modelData
                        width: 22; height: 24
                        Image { anchors.centerIn: parent; width: 18; height: 18; source: parent.modelData.icon; fillMode: Image.PreserveAspectFit }
                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; onClicked: mouse => {
                            if (mouse.button === Qt.RightButton || parent.modelData.onlyMenu) { if (parent.modelData.hasMenu) parent.modelData.display(bar, Math.round(parent.mapToItem(null,mouse.x,mouse.y).x), Math.round(parent.mapToItem(null,mouse.x,mouse.y).y)) }
                            else if (mouse.button === Qt.MiddleButton) parent.modelData.secondaryActivate()
                            else parent.modelData.activate()
                        } }
                    }
                }
            } }
    Component { id:inboxWidget; Pill { host: bar.host; compact: true; text: host.cfg.dnd ? "DND" : "Inbox " + host.notices.length; onClicked: host.toggle("notifications",bar.screen.name) } }
    Component { id:soundWidget; Pill { host: bar.host; compact: true; text: {const a=Pipewire.defaultAudioSink;return a && a.audio ? (a.audio.muted ? "Mute" : Math.round(a.audio.volume*100)+"%") : "Sound"}
        onClicked: host.toggle("controls",bar.screen.name) } }
    Component { id:powerWidget; Pill { host: bar.host; compact: true; text: "⏻"; onClicked: host.toggle("power",bar.screen.name) } }
}
