import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
ScrollView {
    id: root
    required property var host
    required property var status
    property var sink: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    property var mic: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
    property var player: Mpris.players.values.length ? Mpris.players.values[0] : null
    property string network: "Network"
    property string bluetooth: "Bluetooth"
    property int brightness: 50
    property bool hasBrightness: false
    contentWidth: availableWidth
    clip: true
    Process { id: networkPoll; command: ["nmcli","radio","wifi"]; stdout: StdioCollector { onStreamFinished: root.network = text.trim()==="enabled" ? "Wi-Fi on" : "Wi-Fi off" } }
    Process { id: bluePoll; command: ["bluetoothctl","show"]; stdout: StdioCollector { onStreamFinished: root.bluetooth = text.includes("Powered: yes") ? "Bluetooth on" : "Bluetooth off" } }
    Process { id: brightPoll; command: ["brightnessctl","-m"]; stdout: StdioCollector { onStreamFinished: {let m=text.match(/(\d+)%/);root.hasBrightness=!!m;if(m)root.brightness=Number(m[1])} } }
    Timer { interval: 3000; repeat: true; running: root.visible; triggeredOnStart: true; onTriggered: {if(!networkPoll.running)networkPoll.running=true;if(!bluePoll.running)bluePoll.running=true;if(!brightPoll.running)brightPoll.running=true} }
    ColumnLayout {
        width: root.availableWidth; spacing: 12
        Text { text: "Quick settings"; font.pixelSize: 28; font.weight: Font.DemiBold; color: host.fg }
        GridLayout {
            columns: 2; Layout.fillWidth: true; columnSpacing: 8; rowSpacing: 8
            Pill { host: root.host; Layout.fillWidth: true; text: root.network; selected: root.network === "Wi-Fi on"; onClicked: host.action(["nmcli","radio","wifi",selected?"off":"on"]) }
            Pill { host: root.host; Layout.fillWidth: true; text: root.bluetooth; selected: root.bluetooth === "Bluetooth on"; onClicked: host.action(["bluetoothctl","power",selected?"off":"on"]) }
            Pill { host: root.host; Layout.fillWidth: true; text: "Wi-Fi settings"; onClicked: host.action(["nm-connection-editor"]) }
            Pill { host: root.host; Layout.fillWidth: true; text: "Pair devices"; onClicked: host.action(["blueman-manager"]) }
            Pill { host: root.host; Layout.fillWidth: true; text: "Do not disturb"; selected: !!host.cfg.dnd; onClicked: host.change("dnd",!selected) }
            Pill { host: root.host; Layout.fillWidth: true; text: "Dark theme"; selected: !host.light; onClicked: host.change("theme",host.light?"dark":"light") }
            Pill { host: root.host; Layout.fillWidth: true; text: "Gaming mode"; selected: !!host.cfg.gaming; onClicked: host.change("gaming",!selected) }
            Pill { host: root.host; Layout.fillWidth: true; text: "Settings"; onClicked: host.page="settings" }
        }
        Rectangle {
            Layout.fillWidth: true; implicitHeight: audio.implicitHeight+24; radius: 20; color: host.surface
            ColumnLayout {
                id: audio; anchors.fill: parent; anchors.margins: 12
                RowLayout {
                    Text { text: "Volume"; color: host.fg; Layout.fillWidth: true }
                    Pill { host: root.host; compact: true; text: root.sink && root.sink.muted ? "Unmute" : "Mute"; enabled: !!root.sink; onClicked: root.sink.muted=!root.sink.muted }
                }
                Slider { Layout.fillWidth: true; from: 0; to: 1; enabled: !!root.sink; value: root.sink ? root.sink.volume : 0; onMoved: if(root.sink)root.sink.volume=value }
                RowLayout {
                    Text { text: "Microphone"; color: host.fg; Layout.fillWidth: true }
                    Pill { host: root.host; compact: true; enabled: !!root.mic; text: root.mic && root.mic.muted ? "Unmute" : "Mute"; onClicked: root.mic.muted=!root.mic.muted }
                }
                Slider { Layout.fillWidth: true; from: 0; to: 1; enabled: !!root.mic; value: root.mic ? root.mic.volume : 0; onMoved: if(root.mic)root.mic.volume=value }
                Text { text: "Brightness"; color: host.fg; visible: root.hasBrightness }
                Slider { Layout.fillWidth: true; visible: root.hasBrightness; from: 5; to: 100; stepSize: 1; value: root.brightness; onPressedChanged: if(!pressed && root.hasBrightness)host.action(["brightnessctl","set",Math.round(value)+"%"]) }
            }
        }
        Rectangle {
            Layout.fillWidth: true; implicitHeight: media.implicitHeight+24; radius: 20; color: host.surface
            ColumnLayout {
                id: media; anchors.fill: parent; anchors.margins: 12
                Text { text: root.player ? root.player.trackTitle || "Media player" : "No active media"; color: host.fg; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight; textFormat: Text.PlainText }
                Text { text: root.player ? root.player.trackArtist || "" : ""; color: host.muted; Layout.fillWidth: true; elide: Text.ElideRight; textFormat: Text.PlainText }
                RowLayout {
                    Pill { host: root.host; text: "Previous"; compact: true; enabled: !!root.player && root.player.canGoPrevious; onClicked: root.player.previous() }
                    Pill { host: root.host; text: root.player && root.player.isPlaying ? "Pause" : "Play"; compact: true; selected: true; enabled: !!root.player && root.player.canTogglePlaying; onClicked: root.player.togglePlaying() }
                    Pill { host: root.host; text: "Next"; compact: true; enabled: !!root.player && root.player.canGoNext; onClicked: root.player.next() }
                }
            }
        }
        Text { text: "RAM " + status.memory + "   ·   Load " + status.load + "   ·   NVIDIA GPU " + status.gpu; color: host.muted; font.pixelSize: 12 }
    }
}
