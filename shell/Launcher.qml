import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
ColumnLayout {
    id: root
    required property var host
    property string mode: "Apps"
    property var results: []
    property string pending: ""
    property var entries: mode === "Apps" ? DesktopEntries.applications.values.filter(a => !a.noDisplay && (a.name+" "+a.genericName+" "+a.id).toLowerCase().includes(search.text.trim().toLowerCase())).sort((a,b)=>a.name.localeCompare(b.name)) : results
    function refresh() {
        results=[]; list.currentIndex=0
        if (mode === "Apps") return
        if (mode === "Files" && search.text.trim().length<2) return
        if (mode === "Calc" && !search.text.trim()) return
        if (mode === "Clipboard" && !host.cfg.clipboardHistory) return
        if (query.running) { pending="yes"; return }
        pending=""; query.requestMode=mode; query.requestText=search.text
        query.command=mode==="Files"?[host.cli,"files",search.text]:mode==="Calc"?[host.cli,"calc",search.text]:[host.cli,"clipboard","list"]
        query.running=true
    }
    function launch(item) {
        if (item === undefined || item === null) return
        if (mode === "Apps") item.execute()
        else if(mode === "Files") host.action(["xdg-open",item])
        else if(mode === "Calc") host.action(["wl-copy",item])
        else host.action([host.cli,"clipboard","copy",item])
        host.page=""
    }
    Process {
        id: query
        property string requestMode
        property string requestText
        stdout: StdioCollector { onStreamFinished: { if(query.requestMode!==root.mode||query.requestText!==search.text)return; try{root.results=root.mode==="Calc"?(text.trim()?[text.trim()]:[]):JSON.parse(text);list.currentIndex=0}catch(e){root.results=[]} } }
        onExited: if(root.pending!=="") debounce.restart()
    }
    Timer { id: debounce; interval: 220; onTriggered: root.refresh() }
    Text { text: "Find anything."; color: host.fg; font.pixelSize: 30; font.weight: Font.DemiBold }
    RowLayout {
        Repeater { model: ["Apps","Files","Calc","Clipboard"]; Pill { required property string modelData; host: root.host; compact: true; text: modelData; selected: root.mode===modelData; onClicked: {root.mode=modelData;root.refresh();search.forceActiveFocus()} } }
    }
    TextField {
        id: search; Layout.fillWidth: true; placeholderText: root.mode==="Calc"?"2 * (10 + 5)":root.mode==="Files"?"Search your files…":"Search…"; color: host.fg; placeholderTextColor: host.muted; font.pixelSize: 16; padding: 14
        background: Rectangle { color: host.surface; radius: 16 }
        Component.onCompleted: forceActiveFocus()
        onTextChanged: {list.currentIndex=0;debounce.restart()}
        Keys.onDownPressed: list.incrementCurrentIndex()
        Keys.onUpPressed: list.decrementCurrentIndex()
        onAccepted: if(list.currentIndex>=0)root.launch(list.model[list.currentIndex])
    }
    Text { visible: root.mode==="Clipboard"&&!host.cfg.clipboardHistory; text: "Clipboard history is off. Enable it explicitly in Settings."; color: host.muted; wrapMode: Text.Wrap; Layout.fillWidth: true }
    ListView {
        id: list; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6; model: root.mode==="Clipboard"?root.entries.filter(x=>x.toLowerCase().includes(search.text.toLowerCase())):root.entries; currentIndex: 0
        delegate: Rectangle {
            required property var modelData
            required property int index
            width: ListView.view.width; height: 52; radius: 16; color: ListView.isCurrentItem ? host.raised : host.surface
            RowLayout { anchors.fill: parent; anchors.margins: 10
                Image { visible:root.mode==="Apps"; source: visible?Quickshell.iconPath(modelData.icon,"application-x-executable"):""; Layout.preferredWidth:32; Layout.preferredHeight:32 }
                Text { Layout.fillWidth:true; text:root.mode==="Apps"?modelData.name:String(modelData); textFormat:Text.PlainText; color:host.fg; elide:Text.ElideRight }
                Text { text:root.mode==="Calc"?"Copy":"↗"; color:host.muted }
            }
            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: list.currentIndex=index; onClicked:root.launch(modelData) }
        }
    }
    Text { text: list.count+" results · ↑ ↓ navigate · Enter select"; color: host.muted; font.pixelSize: 11 }
}
