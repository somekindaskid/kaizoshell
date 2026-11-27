import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
PanelWindow {
    id: win
    required property var host
    property var player: Mpris.players.values.find(p=>p.isPlaying) || Mpris.players.values[0] || null
    visible: host.cfg.showIsland!==false && !host.cfg.gaming && !!player && host.page===""
    anchors { top: host.cfg.position!=="bottom"; bottom: host.cfg.position==="bottom" }
    margins { top:(host.cfg.barHeight||44)+10; bottom:(host.cfg.barHeight||44)+10 }
    implicitWidth: Math.min(440,screen?screen.width-24:440); implicitHeight: 56
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color:"transparent"
    Rectangle {
        anchors.fill:parent; color:host.bg; radius:28; border.color:host.raised
        RowLayout { anchors.fill:parent; anchors.margins:8
            Pill { host:win.host; compact:true; text:"‹"; enabled:!!player&&player.canGoPrevious; onClicked:player.previous() }
            Text { Layout.fillWidth:true; text:player?player.trackTitle||"Media":""; color:host.fg; textFormat:Text.PlainText; elide:Text.ElideRight }
            Pill { host:win.host; compact:true; text:player&&player.isPlaying?"Ⅱ":"▶"; enabled:!!player&&player.canTogglePlaying; onClicked:player.togglePlaying() }
            Pill { host:win.host; compact:true; text:"›"; enabled:!!player&&player.canGoNext; onClicked:player.next() }
        }
    }
}
