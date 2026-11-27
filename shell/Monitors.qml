import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
ColumnLayout {
    id:root
    required property var host
    property var outputs:[]
    property string message:""
    property string selectedName:""
    Process { id:scan; command:[host.cli,"monitor","list"]; stdout:StdioCollector { onStreamFinished:{try{root.outputs=JSON.parse(text);if(root.outputs.length&&!root.selectedName)root.select(0)}catch(e){root.message="Unable to read displays"}} } }
    Process { id:apply; stdout:StdioCollector {onStreamFinished:root.message=text.trim()}
        stderr:StdioCollector {onStreamFinished:if(text.trim())root.message=text.trim()} }
    function select(i) {let m=outputs[i];if(!m)return;selectedName=m.name;mode.model=["preferred",...(m.availableModes||[]).map(x=>x.replace(/Hz$/,""))];mode.currentIndex=0;position.text=m.x+"x"+m.y;scale.text=String(m.scale||1)}
    function invoke(args) { if(!apply.running){apply.command=[host.cli,"monitor",...args];apply.running=true} }
    Component.onCompleted:scan.running=true
    Text {text:"Displays";color:host.fg;font.pixelSize:28;font.weight:Font.DemiBold}
    ComboBox { Layout.fillWidth:true; model:root.outputs.map(m=>m.name); onActivated:i=>root.select(i) }
    Text {text:"Resolution and refresh rate";color:host.muted}
    ComboBox { id:mode; Layout.fillWidth:true; model:["preferred"] }
    Text {text:"Position (e.g. 1920x0)";color:host.muted}
    TextField {id:position;Layout.fillWidth:true;placeholderText:"auto"}
    Text {text:"Scale";color:host.muted}
    TextField {id:scale;Layout.fillWidth:true;text:"1"}
    RowLayout {
        Pill {host:root.host;text:"Preview rule";onClicked:root.invoke(["preview",root.selectedName,mode.currentText,position.text,scale.text])}
        Pill {host:root.host;text:"Test";selected:true;onClicked:root.invoke(["apply",root.selectedName,mode.currentText,position.text,scale.text])}
    }
    RowLayout {
        Pill {host:root.host;text:"Keep";onClicked:root.invoke(["confirm"])}
        Pill {host:root.host;text:"Revert";onClicked:root.invoke(["revert"])}
    }
    Text {text:root.message||"Test changes expire after 20 seconds. Reloading Hyprland restores your saved compositor configuration.";color:host.muted;wrapMode:Text.Wrap;Layout.fillWidth:true}
    Item {Layout.fillHeight:true}
}
