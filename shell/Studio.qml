import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
    id:root
    required property var host
    property var order: (host.cfg.widgetOrder||["clock","stats","tray","inbox","sound","power"]).slice()
    function move(from,to) { if(from===to||from<0||to<0||to>=order.length)return;let a=order.slice();a.splice(to,0,a.splice(from,1)[0]);order=a;host.change("widgetOrder",a) }
    Text { text:"Kaizo Studio"; font.pixelSize:28; color:host.fg; font.weight:Font.DemiBold }
    Text { text:"Drag a widget to reorder the right side of the bar."; color:host.muted; Layout.fillWidth:true; wrapMode:Text.Wrap }
    ListView {
        id:list; Layout.fillWidth:true; Layout.fillHeight:true; model:root.order; spacing:6; clip:true
        delegate: Rectangle {
            id:card; required property int index; required property string modelData; width:list.width; height:48; radius:12; color:host.surface
            RowLayout { anchors.fill:parent; anchors.margins:8
                Text { text:"☰"; color:host.muted; font.pixelSize:20 }
                Text { text:card.modelData; color:host.fg; Layout.fillWidth:true }
                Pill { host:root.host; compact:true; text:"↑"; enabled:card.index>0; onClicked:root.move(card.index,card.index-1) }
                Pill { host:root.host; compact:true; text:"↓"; enabled:card.index<root.order.length-1; onClicked:root.move(card.index,card.index+1) }
            }
            MouseArea { width:parent.width-96; height:parent.height; property real startY:0; onPressed:mouse=>startY=mapToItem(list,mouse.x,mouse.y).y; onReleased:mouse=>{let dy=mapToItem(list,mouse.x,mouse.y).y-startY;root.move(card.index,Math.max(0,Math.min(root.order.length-1,card.index+Math.round(dy/54))))} }
        }
    }
    Pill { host:root.host; text:"Restore default order"; onClicked:{root.order=["clock","stats","tray","inbox","sound","power"];host.change("widgetOrder",root.order)} }
}
