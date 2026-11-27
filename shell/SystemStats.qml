import QtQuick
import Quickshell.Io
Item {
    id: root
    property string summary: "System"
    property bool active: true
    property string memory: "—"
    property string load: "—"
    property string gpu: "—"
    Process {
        id: proc
        command: ["sh","-c","awk '/^MemTotal:/{t=$2}/^MemAvailable:/{a=$2}END{if(t>0)printf \"%d\\n\",100*(t-a)/t}' /proc/meminfo; cut -d' ' -f1 /proc/loadavg; if command -v nvidia-smi >/dev/null; then nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n1; else echo —; fi"]
        stdout: StdioCollector { onStreamFinished: {
            const lines=text.trim().split("\n"); if(lines.length>=2) {root.memory=lines[0]+"%"; root.load=lines[1];root.gpu=lines.length>2?lines[2]+(lines[2]==="—"?"":"%"):"—";root.summary="RAM "+root.memory+" · Load "+root.load}
        } }
    }
    Timer { interval: 5000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: if(!proc.running)proc.running=true }
}
