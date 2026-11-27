import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell.Io

Window {
    id: root
    required property var host
    title: "Kaizo Settings"
    width: 1000
    height: 720
    minimumWidth: 640
    minimumHeight: 460
    visible: false
    color: host.bg
    property string section: "appearance"
    property string query: ""
    property string resultText: ""
    property string commandOutput: ""
    readonly property var sections: [
        {id:"appearance", label:"Appearance", desc:"Theme, accent, wallpaper", symbol:"◐"},
        {id:"desktop", label:"Desktop & bar", desc:"Dock, clock, workspace bar", symbol:"▤"},
        {id:"studio", label:"Widget studio", desc:"Reorder bar widgets", symbol:"▦"},
        {id:"monitors", label:"Displays", desc:"Resolution, scaling, monitors", symbol:"▣"},
        {id:"profiles", label:"Profiles", desc:"Work, minimal and gaming", symbol:"◈"},
        {id:"privacy", label:"Privacy & notifications", desc:"Clipboard, notifications, DND", symbol:"◆"},
        {id:"extensions", label:"Extensions", desc:"Local widget manifests", symbol:"⊞"},
        {id:"system", label:"System", desc:"Backup, diagnostics, updates", symbol:"⚙"},
        {id:"about", label:"About", desc:"Version and project", symbol:"ⓘ"}
    ]
    function openSection(name) {
        section = sections.some(s => s.id === name) ? name : "appearance"
        query = ""
        show()
        raise()
        requestActivate()
    }
    function execute(args) {
        if (job.running) return
        resultText = "Running…"
        commandOutput = ""
        job.command = [host.cli].concat(args)
        job.running = true
    }
    Process {
        id: job
        stdout: StdioCollector { onStreamFinished: root.commandOutput += text }
        stderr: StdioCollector { onStreamFinished: root.commandOutput += text }
        onExited: (exitCode, exitStatus) => {
            root.resultText = (exitCode === 0 ? "Completed" : "Failed (exit " + exitCode + ")") + (root.commandOutput.trim() ? "\n" + root.commandOutput.trim() : "")
        }
    }
    FileDialog {
        id: wallpaperPicker
        title: "Choose wallpaper"
        nameFilters: ["Images (*.jpg *.jpeg *.png *.webp *.bmp)"]
        onAccepted: root.execute(["wallpaper", decodeURIComponent(selectedFile.toString().replace(/^file:\/\//,""))])
    }
    FileDialog {
        id: restorePicker
        title: "Select Kaizo configuration backup"
        nameFilters: ["JSON (*.json)"]
        onAccepted: root.execute(["restore", decodeURIComponent(selectedFile.toString().replace(/^file:\/\//,""))])
    }
    Shortcut { sequence: "Escape"; onActivated: root.close() }
    component Heading: Text {
        color: root.host.fg
        font.pixelSize: 24
        font.weight: Font.DemiBold
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }
    component Description: Text {
        color: root.host.muted
        font.pixelSize: 13
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
    }
    component Rule: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: root.host.raised
    }
    component SettingSwitch: Rectangle {
        id: row
        required property string setting
        required property string label
        property string detail: ""
        property bool defaultValue: false
        Layout.fillWidth: true
        implicitHeight: Math.max(68, switchRow.implicitHeight + 24)
        color: root.host.surface
        radius: 14
        RowLayout {
            id: switchRow
            anchors.fill: parent
            anchors.margins: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text { text: row.label; color: root.host.fg; font.pixelSize: 15; font.weight: Font.Medium; Layout.fillWidth: true; wrapMode: Text.Wrap }
                Description { text: row.detail; visible: text.length > 0 }
            }
            Switch {
                checked: root.host.cfg[row.setting] === undefined ? row.defaultValue : !!root.host.cfg[row.setting]
                Accessible.name: row.label
                onClicked: root.host.change(row.setting, checked)
            }
        }
    }
    component SettingsScroll: ScrollView {
        id: sv
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    }
    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            color: root.host.surface
            Layout.preferredWidth: root.width < 800 ? 188 : 258
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                RowLayout {
                    Rectangle {
                        width: 44; height: 44; radius: 14; color: root.host.accent
                        Text { anchors.centerIn: parent; text: "K"; color: root.host.accentText; font.pixelSize: 25; font.bold: true }
                    }
                    ColumnLayout {
                        spacing: 1
                        Text { text: "Kaizo"; font.pixelSize: 22; font.bold: true; color: root.host.fg }
                        Text { text: "SETTINGS"; font.pixelSize: 10; font.letterSpacing: 2; color: root.host.muted }
                    }
                }
                TextField {
                    id: searchBox
                    Layout.fillWidth: true
                    placeholderText: "Search settings"
                    text: root.query
                    onTextEdited: root.query = text
                    color: root.host.fg
                    placeholderTextColor: root.host.muted
                    background: Rectangle { radius: 10; color: root.host.bg; border.color: searchBox.activeFocus ? root.host.accent : root.host.raised }
                }
                ListView {
                    id: nav
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 5
                    model: root.sections.filter(s => (s.label+" "+s.desc).toLowerCase().includes(root.query.toLowerCase()))
                    delegate: Button {
                        id: navButton
                        required property var modelData
                        width: nav.width
                        height: 48
                        Accessible.name: modelData.label
                        onClicked: root.section = modelData.id
                        contentItem: RowLayout {
                            spacing: 9
                            Text { text: navButton.modelData.symbol; font.pixelSize: 19; color: root.section === navButton.modelData.id ? root.host.accentText : root.host.muted }
                            Text { text: navButton.modelData.label; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 13; font.weight: Font.Medium; color: root.section === navButton.modelData.id ? root.host.accentText : root.host.fg }
                        }
                        background: Rectangle { radius: 12; color: root.section === navButton.modelData.id ? root.host.accent : navButton.hovered ? root.host.raised : "transparent" }
                    }
                }
                Description { text: "Local settings · No telemetry" }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 24
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    Text { text: "KAIZO / SETTINGS"; color: root.host.muted; font.pixelSize: 11; font.letterSpacing: 2 }
                    Heading { text: { const s=root.sections.find(x=>x.id===root.section); return s ? s.label : "Settings" } }
                }
                Pill { host: root.host; compact: true; text: "Close"; onClicked: root.close() }
            }
            Rule {}
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: root.visible
                sourceComponent: ({appearance:appearancePage, desktop:desktopPage, studio:studioPage, monitors:monitorsPage, profiles:profilesPage, privacy:privacyPage, extensions:extensionsPage, system:systemPage, about:aboutPage})[root.section] || appearancePage
            }
            Description { visible: root.section !== "system" && root.resultText.length > 0; text: root.resultText.split("\n")[0] }
        }
    }
    Component {
        id: appearancePage
        SettingsScroll {
            id: appearanceScroll
            ColumnLayout {
                width: appearanceScroll.availableWidth
                spacing: 14
                Heading { text: "Colour scheme" }
                Description { text: "Change the entire Kaizo interface. Changes are saved automatically." }
                RowLayout {
                    Layout.fillWidth: true
                    Repeater {
                        model: ["dark","light"]
                        delegate: Button {
                            id: themeCard
                            required property string modelData
                            Layout.fillWidth: true
                            implicitHeight: 116
                            onClicked: root.host.change("theme",modelData)
                            contentItem: ColumnLayout {
                                spacing: 7
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 9
                                    color: themeCard.modelData === "dark" ? "#111319" : "#e9edf5"
                                    Rectangle { x: 10; y: 9; width: parent.width-20; height: 12; radius: 5; color: themeCard.modelData === "dark" ? "#292e3a" : "#cdd5e4" }
                                    Rectangle { x: 12; y: 29; width: Math.max(0,parent.width*0.56-12); height: Math.max(0,parent.height-36); radius: 5; color: root.host.accent }
                                }
                                Text { text: themeCard.modelData === "dark" ? "Dark" : "Light"; color: root.host.fg; font.pixelSize: 14 }
                            }
                            background: Rectangle { color: root.host.surface; radius: 14; border.width: root.host.cfg.theme === themeCard.modelData ? 2 : 0; border.color: root.host.accent }
                        }
                    }
                }
                Heading { text: "Accent colour" }
                Flow {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: ["#b7c5ff","#a5d6c5","#ffc5a9","#e3bcff","#f5d68a","#9ad4f5","#ee9fae","#b8c0cc"]
                        delegate: Button {
                            id: swatch
                            required property string modelData
                            width: 42; height: 42
                            Accessible.name: "Accent " + modelData
                            onClicked: root.host.change("accent",modelData)
                            contentItem: Text { text: root.host.cfg.accent === swatch.modelData ? "✓" : ""; color: "#15171d"; font.pixelSize: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { radius: 21; color: swatch.modelData; border.width: swatch.activeFocus ? 2 : 0; border.color: root.host.fg }
                        }
                    }
                }
                RowLayout {
                    TextField { id: hexInput; Layout.fillWidth: true; placeholderText: "#RRGGBB"; text: root.host.cfg.accent || "#b7c5ff"; color: root.host.fg; validator: RegularExpressionValidator { regularExpression: /^#[0-9a-fA-F]{6}$/ } }
                    Pill { host: root.host; text: "Apply colour"; enabled: hexInput.acceptableInput; onClicked: root.host.change("accent",hexInput.text) }
                }
                SettingSwitch { setting:"dynamicColor"; label:"Dynamic wallpaper colours"; detail:"Extract an accent when choosing a wallpaper." }
                Heading { text: "Wallpaper" }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 160
                    radius: 14
                    color: root.host.surface
                    clip: true
                    Image { anchors.fill: parent; source: root.host.cfg.wallpaper ? "file://" + root.host.cfg.wallpaper : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: status === Image.Ready }
                    Text { anchors.centerIn: parent; text: root.host.cfg.wallpaper ? "Wallpaper preview" : "No wallpaper selected"; color: root.host.muted; visible: !root.host.cfg.wallpaper }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Pill { host:root.host; text:"Choose image"; onClicked:wallpaperPicker.open() }
                    Pill { host:root.host; text:"Extract colours"; enabled:!!root.host.cfg.wallpaper && !job.running; onClicked:root.execute(["palette"]) }
                    Pill { host:root.host; text:"Clear"; onClicked:root.host.change("wallpaper","") }
                }
            }
        }
    }
    Component {
        id: desktopPage
        SettingsScroll {
            id: desktopScroll
            ColumnLayout {
                width: desktopScroll.availableWidth
                spacing: 12
                Heading { text:"Status bar" }
                Rectangle {
                    Layout.fillWidth:true
                    implicitHeight:110
                    radius:14
                    color:root.host.surface
                    Rectangle {
                        anchors.left:parent.left; anchors.right:parent.right; anchors.margins:8
                        y:root.host.cfg.position === "bottom" ? parent.height-height-8 : 8
                        height:root.host.cfg.barHeight || 44
                        radius:10; color:root.host.raised
                        RowLayout {
                            anchors.fill:parent; anchors.margins:8
                            Text { text:"K   1   2   3   4"; color:root.host.fg }
                            Item { Layout.fillWidth:true }
                            Text { text:"12:30   ◉"; color:root.host.accent }
                        }
                    }
                }
                RowLayout {
                    Pill { host:root.host; text:"Top"; selected:root.host.cfg.position!=="bottom"; onClicked:root.host.change("position","top") }
                    Pill { host:root.host; text:"Bottom"; selected:root.host.cfg.position==="bottom"; onClicked:root.host.change("position","bottom") }
                }
                Description { text:"Bar height · " + Math.round(heightSlider.value) + " px" }
                Slider { id:heightSlider; Layout.fillWidth:true; from:32; to:64; stepSize:1; value:root.host.cfg.barHeight || 44; onMoved:heightCommit.restart() }
                Timer { id:heightCommit; interval:250; onTriggered:root.host.change("barHeight",Math.round(heightSlider.value)) }
                SettingSwitch { setting:"showTray"; label:"System tray"; detail:"Show background application icons."; defaultValue:true }
                SettingSwitch { setting:"showStats"; label:"System statistics"; detail:"Show memory usage and system load."; defaultValue:true }
                SettingSwitch { setting:"showDock"; label:"Application dock"; detail:"Show pinned and running applications."; defaultValue:true }
                SettingSwitch { setting:"showIsland"; label:"Kaizo Island"; detail:"Floating media controls."; defaultValue:true }
                SettingSwitch { setting:"clock24"; label:"24-hour clock"; defaultValue:true }
                Pill { host:root.host; text:"Open widget studio"; onClicked:root.section="studio" }
                Heading { text:"Search shortcut" }
                Description { text:"Use Super + Space to open Kaizo search. Configure the shortcut in Hyprland using the matching syntax below; remove any conflicting binding first." }
                TextArea {
                    Layout.fillWidth:true
                    readOnly:true
                    selectByMouse:true
                    wrapMode:TextEdit.Wrap
                    color:root.host.fg
                    font.family:"monospace"
                    text:"Lua:\nhl.bind(\"SUPER + space\", hl.dsp.exec_cmd(os.getenv(\"HOME\") .. \"/.local/bin/kaizo search\"))\n\nLegacy:\nbind = SUPER, SPACE, exec, ~/.local/bin/kaizo search"
                }
                Pill { host:root.host; text:"Open search"; onClicked:{root.close();root.host.toggle("launcher","")} }
            }
        }
    }
    Component { id:studioPage; Studio { host:root.host } }
    Component { id:monitorsPage; Monitors { host:root.host } }
    Component { id:extensionsPage; Extensions { host:root.host } }
    Component {
        id:profilesPage
        SettingsScroll {
            id:profileScroll
            ColumnLayout {
                width:profileScroll.availableWidth
                spacing:10
                Description { text:"Switch between desktop layouts. Profiles may change several shell settings at once." }
                Repeater {
                    model:[{key:"full",label:"Full",detail:"All main desktop modules."},{key:"minimal",label:"Minimal",detail:"Reduce visual clutter."},{key:"work",label:"Work",detail:"A focused everyday desktop."},{key:"gaming",label:"Gaming",detail:"Hide the bar and reduce distractions."}]
                    delegate: Button {
                        id:profileButton
                        required property var modelData
                        Layout.fillWidth:true
                        implicitHeight:78
                        onClicked:root.execute(["profile",modelData.key])
                        enabled:!job.running
                        contentItem:ColumnLayout {
                            Text { text:profileButton.modelData.label+(root.host.cfg.profile===profileButton.modelData.key ? "  ✓" : ""); color:root.host.fg; font.pixelSize:17; font.weight:Font.Medium }
                            Description { text:profileButton.modelData.detail }
                        }
                        background:Rectangle { radius:14; color:root.host.surface; border.width:root.host.cfg.profile===profileButton.modelData.key ? 2 : 0; border.color:root.host.accent }
                    }
                }
                SettingSwitch { setting:"gaming"; label:"Gaming mode"; detail:"Toggle shell distractions without choosing a different profile." }
            }
        }
    }
    Component {
        id:privacyPage
        SettingsScroll {
            id:privacyScroll
            ColumnLayout {
                width:privacyScroll.availableWidth
                spacing:12
                Heading { text:"Notifications" }
                SettingSwitch { setting:"showNotifications"; label:"Kaizo notification server"; detail:"Disable other notification daemons to avoid conflicts."; defaultValue:true }
                SettingSwitch { setting:"dnd"; label:"Do not disturb"; detail:"Suppress notification popups." }
                Heading { text:"Clipboard" }
                SettingSwitch { setting:"clipboardHistory"; label:"Save clipboard history"; detail:"Opt in only. Clipboard history may retain private text and images." }
                Pill { host:root.host; text:"Clear clipboard history"; enabled:!job.running; onClicked:clearDialog.open() }
                Dialog {
                    id:clearDialog
                    title:"Clear clipboard history?"
                    modal:true
                    standardButtons:Dialog.Ok | Dialog.Cancel
                    onAccepted:root.execute(["clipboard","clear"])
                    contentItem:Text { text:"All saved clipboard history will be removed."; wrapMode:Text.Wrap; color:root.host.fg; implicitWidth:280 }
                }
                Description { text:"Kaizo stores its configuration locally and has no built-in telemetry." }
            }
        }
    }
    Component {
        id:systemPage
        ColumnLayout {
            spacing:12
            Heading { text:"Maintenance" }
            Flow {
                Layout.fillWidth:true
                spacing:8
                Pill { host:root.host; text:"Back up settings"; enabled:!job.running; onClicked:root.execute(["backup"]) }
                Pill { host:root.host; text:"Restore backup"; enabled:!job.running; onClicked:restorePicker.open() }
                Pill { host:root.host; text:"Run diagnostics"; enabled:!job.running; onClicked:root.execute(["doctor"]) }
                Pill { host:root.host; text:"Check updates"; enabled:!job.running; onClicked:root.execute(["update","--check"]) }
                Pill { host:root.host; text:"View logs"; enabled:!job.running; onClicked:root.execute(["logs"]) }
                Pill { host:root.host; text:"Setup wizard"; onClicked:{root.close();root.host.toggle("onboarding","")} }
            }
            Description { text:"Install updates or restart the shell from the CLI. This window reports command output and failures." }
            ScrollView {
                Layout.fillWidth:true
                Layout.fillHeight:true
                clip:true
                TextArea { readOnly:true; text:root.resultText || "Command output appears here."; color:root.host.fg; wrapMode:TextEdit.Wrap; font.family:"monospace"; selectByMouse:true }
            }
        }
    }
    Component {
        id:aboutPage
        ColumnLayout {
            Heading { text:"Kaizo Shell" }
            Description { text:"A modular Quickshell desktop environment for Hyprland. Alpha software; features and compatibility are still being tested." }
            RowLayout {
                Pill { host:root.host; text:"GitHub"; onClicked:Qt.openUrlExternally("https://github.com/somekindaskid/kaizoshell") }
                Pill { host:root.host; text:"Version"; enabled:!job.running; onClicked:root.execute(["version"]) }
            }
            Description { text:root.resultText }
            Item { Layout.fillHeight:true }
        }
    }
}
