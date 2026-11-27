import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    id: root
    property bool opened: false
    property var targetScreen: null
    readonly property var entries: {
        const term = search.text.trim().toLowerCase()
        return DesktopEntries.applications.values.filter(a => !a.noDisplay &&
            ((a.name || "") + " " + (a.genericName || "") + " " + (a.id || "")).toLowerCase().includes(term))
            .sort((a,b) => (a.name || "").localeCompare(b.name || ""))
    }
    function toggle() {
        if (opened) { closeSearch(); return }
        const screens = Array.from(Quickshell.screens)
        targetScreen = screens.find(s => s.name === MonitorPolicy.mainName) ??
            screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? screens[0] ?? null
        if (!targetScreen) return
        search.text = ""
        opened = true
        Qt.callLater(() => search.forceActiveFocus())
    }
    function closeSearch() { opened = false }
    function launch(entry) {
        if (!entry) return
        closeSearch()
        entry.execute()
    }
    screen: targetScreen
    visible: opened && targetScreen !== null
    anchors { top: true }
    margins { top: targetScreen ? Math.max(20, Math.round(targetScreen.height * 0.15)) : 100 }
    implicitWidth: Math.max(1, Math.min(680, targetScreen ? targetScreen.width - 32 : 680))
    implicitHeight: Math.max(1, Math.min(470, targetScreen ? targetScreen.height - 180 : 470))
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "sleepyshell-kaizo-search"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.opened && !Array.from(Quickshell.screens).includes(root.targetScreen))
                root.closeSearch()
        }
    }
    Shortcut { sequence: "Escape"; enabled: root.opened; onActivated: root.closeSearch() }
    Rectangle {
        anchors.fill: parent
        color: Theme.container
        radius: Theme.radiusXl
        border.color: Theme.containerHighest
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12
            Text {
                text: "KAIZO / SEARCH"
                color: Theme.primary
                font.pixelSize: 13
                font.letterSpacing: 2
            }
            TextField {
                id: search
                Layout.fillWidth: true
                placeholderText: "Search applications…"
                color: Theme.fg
                placeholderTextColor: Theme.fgMuted
                font.pixelSize: 20
                padding: 12
                background: Rectangle { color: Theme.surface; radius: Theme.radiusLg }
                onTextChanged: list.currentIndex = list.count > 0 ? 0 : -1
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
                onAccepted: root.launch(root.entries[list.currentIndex])
            }
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 5
                model: root.entries
                currentIndex: count > 0 ? 0 : -1
                onCountChanged: currentIndex = count > 0 ? 0 : -1
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 50
                    radius: Theme.radiusMd
                    color: ListView.isCurrentItem ? Theme.containerHighest : Theme.containerHigh
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        Image {
                            source: Quickshell.iconPath(card.modelData.icon || "application-x-executable", "application-x-executable")
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                        }
                        Text {
                            text: card.modelData.name || card.modelData.id
                            color: Theme.fg
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: list.currentIndex = card.index
                        onClicked: root.launch(card.modelData)
                    }
                }
            }
            Text { text: list.count + " apps  ·  ↑ ↓ Navigate  ·  Enter Open  ·  Esc Close"; color: Theme.fgMuted; font.pixelSize: 12 }
        }
    }
}
