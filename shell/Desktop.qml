import QtQuick
import Quickshell
import Quickshell.Wayland
PanelWindow {
    id: win
    required property var host
    visible: !!host.cfg.wallpaper
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    mask: Region {}
    Image { anchors.fill: parent; source: host.cfg.wallpaper ? "file://" + host.cfg.wallpaper.split("/").map(encodeURIComponent).join("/") : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false }
}
