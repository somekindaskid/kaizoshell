import QtQuick
import QtQuick.Layouts
ColumnLayout {
    id: root
    required property var host
    required property date now
    property int offset: 0
    property date month: new Date(now.getFullYear(),now.getMonth()+offset,1)
    Text { text: Qt.formatDateTime(root.now,"HH:mm"); font.pixelSize: 64; color: host.fg; font.weight: Font.Light }
    Text { text: Qt.formatDateTime(root.now,"dddd, d MMMM yyyy"); color: host.muted; font.pixelSize: 16 }
    RowLayout {
        Layout.fillWidth: true
        Pill { host: root.host; compact: true; text: "‹"; onClicked: root.offset-- }
        Text { text: Qt.formatDateTime(root.month,"MMMM yyyy"); color: host.fg; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; font.bold: true }
        Pill { host: root.host; compact: true; text: "›"; onClicked: root.offset++ }
    }
    GridLayout {
        columns: 7; Layout.fillWidth: true
        Repeater { model: ["M","T","W","T","F","S","S"]; Text { required property string modelData; text:modelData; color:host.muted; Layout.fillWidth:true; horizontalAlignment:Text.AlignHCenter } }
        Repeater {
            model: 42
            Rectangle {
                required property int index
                property date day: new Date(root.month.getFullYear(),root.month.getMonth(),index-((root.month.getDay()+6)%7)+1)
                property bool today: day.toDateString()===root.now.toDateString()
                Layout.fillWidth: true; Layout.preferredHeight: 35; radius: 12; color: today ? host.accent : host.surface
                Text { anchors.centerIn: parent; text:parent.day.getDate();color:parent.today?host.accentText:parent.day.getMonth()===root.month.getMonth()?host.fg:host.muted;opacity:parent.day.getMonth()===root.month.getMonth()?1:0.4 }
            }
        }
    }
    Item { Layout.fillHeight: true }
    Pill { host: root.host; text:"Today"; onClicked:root.offset=0 }
}
