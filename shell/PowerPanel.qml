import QtQuick
import QtQuick.Layouts
ColumnLayout {
    id: root
    required property var host
    property string pending: ""
    Text { text: "Session"; color: host.fg; font.pixelSize: 28 }
    Pill { host: root.host; Layout.fillWidth: true; text: "Lock screen"; onClicked: {host.page="";host.action([host.cli,"lock"])} }
    Repeater {
        model: ["Suspend","Restart","Shut down","Log out"]
        Pill { required property string modelData; host: root.host; Layout.fillWidth: true; text:modelData; selected:root.pending===modelData; onClicked:root.pending=modelData }
    }
    Rectangle {
        visible: root.pending!==""; Layout.fillWidth:true; implicitHeight:90; radius:18; color:host.surface
        ColumnLayout {
            anchors.fill:parent;anchors.margins:10
            Text { text:root.pending+" now? Save your work first."; color:host.fg }
            RowLayout {
                Pill { host:root.host; text:"Cancel"; compact:true; onClicked:root.pending="" }
                Pill { host:root.host; text:"Confirm"; compact:true; selected:true; onClicked:{let a=root.pending;host.page="";if(a==="Log out")host.action(["hyprctl","dispatch","exit"]);else host.action(["systemctl",a==="Restart"?"reboot":a==="Shut down"?"poweroff":"suspend"])} }
            }
        }
    }
    Item { Layout.fillHeight:true }
}
