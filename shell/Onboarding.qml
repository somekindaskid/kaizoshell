import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
    id: root
    required property var host
    property int step: 0
    Text { text: ["Welcome to Kaizo.","Your desktop, your way.","Privacy by default."][root.step]; font.pixelSize: 27; font.weight: Font.DemiBold; color:host.fg; Layout.fillWidth:true; wrapMode:Text.Wrap }
    Text { text:["A modular Hyprland shell, built for your workflow.","Choose a theme and a desktop profile. You can change them later.","Clipboard history is optional. It can retain sensitive copied text. Kaizo has no telemetry."][root.step]; color:host.muted; Layout.fillWidth:true; wrapMode:Text.Wrap }
    Item { Layout.fillHeight:true }
    RowLayout { visible:root.step===1
        Pill { host:root.host; text:"Dark"; selected:!host.light; onClicked:host.change("theme","dark") }
        Pill { host:root.host; text:"Light"; selected:host.light; onClicked:host.change("theme","light") }
    }
    RowLayout { visible:root.step===1
        Pill { host:root.host; text:"Full"; onClicked:host.action([host.cli,"profile","full"]) }
        Pill { host:root.host; text:"Minimal"; onClicked:host.action([host.cli,"profile","minimal"]) }
    }
    Switch { visible:root.step===2; text:"Enable clipboard history"; checked:!!host.cfg.clipboardHistory; onClicked:host.change("clipboardHistory",checked) }
    Item { Layout.fillHeight:true }
    RowLayout { Layout.fillWidth:true
        Pill { host:root.host; text:"Back"; enabled:root.step>0; onClicked:root.step-- }
        Item { Layout.fillWidth:true }
        Pill { host:root.host; selected:true; text:root.step===2?"Finish":"Continue"; onClicked: {if(root.step<2)root.step++;else{host.change("onboarded",true);host.page=""}} }
    }
}
