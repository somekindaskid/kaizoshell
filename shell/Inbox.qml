import QtQuick
import QtQuick.Layouts
ColumnLayout {
    id: root
    required property var host
    RowLayout {
        Layout.fillWidth: true
        Text { text: "Notifications"; color: host.fg; font.pixelSize: 26; Layout.fillWidth: true }
        Pill { host: root.host; compact: true; text: "Clear"; onClicked: {for(const n of host.notices)if(n.notification)n.notification.dismiss();host.notices=[]} }
    }
    Pill { host: root.host; text: "Do not disturb"; selected: !!host.cfg.dnd; onClicked: host.change("dnd",!selected) }
    Text { visible: host.notices.length===0; text: "You're all caught up."; color: host.muted; Layout.fillWidth: true }
    ListView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 8; model: host.notices
        delegate: Rectangle {
            id: card
            required property var modelData
            required property int index
            width: ListView.view.width; height: body.implicitHeight+24; radius: 18; color: host.surface
            ColumnLayout {
                id: body; anchors.fill: parent; anchors.margins: 12
                RowLayout {
                    Text { text: card.modelData.app || "Application"; color: host.accent; Layout.fillWidth: true; elide: Text.ElideRight; textFormat: Text.PlainText }
                    Pill { host: root.host; compact: true; text: "×"; onClicked: {if(card.modelData.notification)card.modelData.notification.dismiss();host.notices=host.notices.filter((_,i)=>i!==card.index)} }
                }
                Text { text: card.modelData.summary; color: host.fg; font.bold: true; Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText }
                Text { text: card.modelData.body; color: host.muted; Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText }
                Flow {
                    Layout.fillWidth: true; spacing: 5
                    Repeater {
                        model: card.modelData.notification ? card.modelData.notification.actions : []
                        Pill { required property var modelData; host: root.host; compact: true; text: modelData.text; onClicked: modelData.invoke() }
                    }
                }
            }
        }
    }
}
