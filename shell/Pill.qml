import QtQuick
import QtQuick.Controls
Button {
    id: b
    required property var host
    property bool selected: false
    property bool compact: false
    implicitHeight: compact ? 30 : 42
    implicitWidth: Math.max(compact ? 32 : 90, label.implicitWidth + (compact ? 18 : 28))
    padding: compact ? 6 : 12
    contentItem: Text {
        id: label
        text: b.text
        font.pixelSize: b.compact ? 12 : 14
        font.weight: Font.Medium
        color: b.selected ? b.host.onAccent : b.host.fg
        opacity: b.enabled ? 1 : 0.45
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: b.compact ? 12 : 18
        color: b.selected ? b.host.accent : b.down || b.hovered ? b.host.raised : b.host.surface
        border.width: b.activeFocus ? 1 : 0
        border.color: b.host.accent
        Behavior on color { ColorAnimation { duration: 130 } }
    }
}
