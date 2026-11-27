import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
ColumnLayout {
    id:root
    required property var host
    FileDialog { id:picker; title:"Import a local widget manifest"; nameFilters:["JSON (*.json)"]; onAccepted:host.action([host.cli,"extension","install",decodeURIComponent(selectedFile.toString().replace(/^file:\/\//,""))]) }
    Text { text:"Extensions"; color:host.fg; font.pixelSize:28; font.weight:Font.DemiBold }
    Text { text:"Local, declarative text widgets. No downloaded code is executed."; color:host.muted; Layout.fillWidth:true; wrapMode:Text.Wrap }
    ListView { Layout.fillWidth:true; Layout.fillHeight:true; model:host.extensions; spacing:8; clip:true
        delegate: Rectangle { required property var modelData; width:ListView.view.width; height:64; radius:12; color:host.surface
            RowLayout { anchors.fill:parent; anchors.margins:8
                ColumnLayout { Layout.fillWidth:true; Text {text:modelData.label;color:host.fg;textFormat:Text.PlainText} Text {text:modelData.text;color:host.muted;textFormat:Text.PlainText;elide:Text.ElideRight;Layout.fillWidth:true} }
                Pill { host:root.host; compact:true; text:"Remove"; onClicked:host.action([host.cli,"extension","remove",modelData.id]) }
            }
        }
    }
    Pill { host:root.host; text:"Import widget"; onClicked:picker.open() }
}
