import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
ScrollView {
    id: root
    required property var host
    contentWidth: availableWidth; clip: true
    FileDialog { id: picker; title: "Choose wallpaper"; nameFilters: ["Images (*.jpg *.jpeg *.png *.webp *.bmp)"]; onAccepted: host.action([host.cli,"wallpaper",decodeURIComponent(selectedFile.toString().replace(/^file:\/\//,""))]) }
    ColumnLayout {
        width: root.availableWidth; spacing: 12
        Text { text: "Make it yours."; color: host.fg; font.pixelSize: 28; font.weight: Font.DemiBold }
        Text { text: "Appearance"; color: host.muted; font.bold: true }
        RowLayout {
            Pill { host: root.host; text: "Dark"; selected: !host.light; onClicked: host.change("theme","dark") }
            Pill { host: root.host; text: "Light"; selected: host.light; onClicked: host.change("theme","light") }
        }
        RowLayout {
            Repeater {
                model: ["#b7c5ff","#a5d6c5","#ffc5a9","#e3bcff","#f5d68a"]
                Rectangle {
                    required property string modelData
                    color: modelData; width: 38; height: 38; radius: 19; border.width: host.cfg.accent===modelData ? 3 : 0; border.color: host.fg
                    MouseArea { anchors.fill: parent; onClicked: host.change("accent",parent.modelData) }
                }
            }
        }
        Text { text: "Bar position and height"; color: host.muted; font.bold: true }
        RowLayout {
            Pill { host: root.host; text: "Top"; selected: host.cfg.position!=="bottom"; onClicked: host.change("position","top") }
            Pill { host: root.host; text: "Bottom"; selected: host.cfg.position==="bottom"; onClicked: host.change("position","bottom") }
        }
        Slider { Layout.fillWidth: true; from:32; to:64; stepSize: 1; value: host.cfg.barHeight || 44; onPressedChanged: if(!pressed)host.change("barHeight",Math.round(value)) }
        Repeater {
            model: [{key:"showTray",label:"System tray"},{key:"showStats",label:"System statistics"},{key:"showDock",label:"Dock"},{key:"clock24",label:"24-hour clock"},{key:"showNotifications",label:"Notification server"}]
            Switch {
                required property var modelData
                text: modelData.label; checked: modelData.key === "showDock" ? !!host.cfg[modelData.key] : host.cfg[modelData.key] !== false
                palette.windowText: host.fg; onClicked: host.change(modelData.key,checked)
            }
        }
        Text { text: "Profiles"; color: host.muted; font.bold: true }
        GridLayout {
            columns: 2; Layout.fillWidth: true
            Repeater {
                model: ["minimal","full","work","gaming"]
                Pill { required property string modelData; host: root.host; Layout.fillWidth: true; text: modelData; selected: host.cfg.profile===modelData; onClicked: host.action([host.cli,"profile",modelData]) }
            }
        }
        RowLayout {
            Pill { host:root.host; text:"Studio"; onClicked:host.page="studio" }
            Pill { host:root.host; text:"Displays"; onClicked:host.page="monitors" }
            Pill { host:root.host; text:"Extensions"; onClicked:host.page="extensions" }
        }
        Switch { text:"Dynamic wallpaper accent"; checked:!!host.cfg.dynamicColor; onClicked:host.change("dynamicColor",checked) }
        Switch { text:"Kaizo Island"; checked:host.cfg.showIsland!==false; onClicked:host.change("showIsland",checked) }
        Switch { text:"Clipboard history (may retain sensitive text)"; checked:!!host.cfg.clipboardHistory; onClicked:host.change("clipboardHistory",checked) }
        RowLayout {
            Pill { host:root.host; text:"Clear clipboard history"; onClicked:host.action([host.cli,"clipboard","clear"]) }
            Pill { host:root.host; text:"Setup"; onClicked:host.page="onboarding" }
        }
        Text { text: "Wallpaper"; color: host.muted; font.bold: true }
        RowLayout {
            Pill { host: root.host; text: "Choose image"; onClicked: picker.open() }
            Pill { host: root.host; text: "Clear"; onClicked: host.change("wallpaper","") }
            Pill { host: root.host; text: "Extract colours"; enabled:!!host.cfg.wallpaper; onClicked:host.action([host.cli,"palette"]) }
        }
        Text { text: "Kaizo Shell • 0.2 alpha\nAll settings stored locally."; color: host.muted; font.pixelSize: 12 }
    }
}
