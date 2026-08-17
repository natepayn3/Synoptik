import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import ".."

PanelWindow {
    id: sysInfoWindow
    visible: (Config.showDesktopSysInfo !== false) && (screen ? (Config.isSysInfoEnabledForScreen ? Config.isSysInfoEnabledForScreen(screen.name) : true) : true)

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-desktop-sysinfo"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: 0

    mask: Region { item: infoContainer }

    property string hostUser: "---"
    property string kernelVer: "---"
    property string sysUptime: "---"
    property string localIp: "---"
    property string cpuModel: "---"
    property string ramText: "---"
    property real ramPct: 0.0
    property string diskText: "---"
    property real diskPct: 0.0

    Process {
        id: sysInfoProc
        running: false
        command: [
            "fish", "-c",
            "set -l u (whoami); " +
            "set -l h (uname -n); " +
            "set -l k (uname -r); " +
            "set -l upt (uptime -p 2>/dev/null | string replace 'up ' ''); " +
            "set -l ip (ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}'); " +
            "test -z \"$ip\"; and set ip (hostname -I 2>/dev/null | awk '{print $1}'); " +
            "test -z \"$ip\"; and set ip '127.0.0.1'; " +
            "set -l mem (free -b | awk '/Mem:/ {printf \"{\\\"used\\\":%.1f,\\\"total\\\":%.1f,\\\"pct\\\":%.1f}\", $3/1073741824, $2/1073741824, ($3/$2)*100}'); " +
            "set -l disk (df -h / | awk 'NR==2 {gsub(/%/,\"\",$5); printf \"{\\\"used\\\":\\\"%s\\\",\\\"total\\\":\\\"%s\\\",\\\"pct\\\":%s}\", $3, $2, $5}'); " +
            "set -l cpu (grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | string trim | string replace -r '[(][^)]*[)]' '' | string replace -r ' @.*' ''); " +
            "printf '{\"user\":\"%s\",\"host\":\"%s\",\"kernel\":\"%s\",\"uptime\":\"%s\",\"ip\":\"%s\",\"cpu\":\"%s\",\"mem\":%s,\"disk\":%s}\\n' \"$u\" \"$h\" \"$k\" \"$upt\" \"$ip\" \"$cpu\" \"$mem\" \"$disk\""
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text ? this.text.trim() : ""
                if (!txt) return
                try {
                    let d = JSON.parse(txt)
                    sysInfoWindow.hostUser = (d.user && d.host) ? `${d.user}@${d.host}` : "localhost"
                    sysInfoWindow.kernelVer = d.kernel || "Linux"
                    sysInfoWindow.sysUptime = d.uptime || "Just booted"
                    sysInfoWindow.localIp = d.ip || "127.0.0.1"
                    sysInfoWindow.cpuModel = d.cpu || "Generic CPU"
                    
                    if (d.mem) {
                        sysInfoWindow.ramPct = Math.min(100, Math.max(0, d.mem.pct)) / 100.0
                        sysInfoWindow.ramText = `${d.mem.used.toFixed(1)} / ${d.mem.total.toFixed(1)} GB`
                    }
                    if (d.disk) {
                        sysInfoWindow.diskPct = Math.min(100, Math.max(0, parseFloat(d.disk.pct))) / 100.0
                        sysInfoWindow.diskText = `${d.disk.used} / ${d.disk.total}`
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: Config.sysInfoRefreshInterval || 3000
        running: sysInfoWindow.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: sysInfoProc.running = true
    }

    Item {
        id: infoContainer
        
        readonly property real basePadding: 14
        property real currentScale: sysInfoWindow.screen ? Config.getSysInfoScale(sysInfoWindow.screen.name) : 1.0

        implicitWidth: (mainLayout.implicitWidth + (basePadding * 2))
        implicitHeight: (mainLayout.implicitHeight + (basePadding * 2))
        width: implicitWidth
        height: implicitHeight

        property real dragX: 60
        property real dragY: 100
        property bool initialized: false

        x: dragX
        y: dragY

        function restorePosition() {
            if (!sysInfoWindow.screen) return
            let savedPos = Config.getSysInfoPosition ? Config.getSysInfoPosition(sysInfoWindow.screen.name, 60, 100) : null
            if (savedPos && typeof savedPos.x === "number" && typeof savedPos.y === "number") {
                dragX = savedPos.x
                dragY = savedPos.y
                initialized = true
            }
        }

        Connections {
            target: Config
            function onIsLoadedChanged() {
                if (Config.isLoaded) infoContainer.restorePosition()
            }
        }

        Component.onCompleted: {
            if (Config.isLoaded) restorePosition()
        }

        onXChanged: {
            if (initialized && dragArea.drag.active && sysInfoWindow.screen && Config.saveSysInfoPosition) {
                Config.saveSysInfoPosition(sysInfoWindow.screen.name, dragX, dragY)
            }
        }
        onYChanged: {
            if (initialized && dragArea.drag.active && sysInfoWindow.screen && Config.saveSysInfoPosition) {
                Config.saveSysInfoPosition(sysInfoWindow.screen.name, dragX, dragY)
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: Config.sysInfoShowBg !== false
            radius: Config.cornerRadius
            color: Qt.rgba(Config.bgBase.r, Config.bgBase.g, Config.bgBase.b, 0.75)
            border.width: Config.showBorders ? 2 : 1
            border.color: Config.showBorders ? Config.accent : Qt.rgba(255, 255, 255, 0.12)
        }

        ColumnLayout {
            id: mainLayout
            anchors.centerIn: parent
            spacing: 8 * infoContainer.currentScale
            width: 280 * infoContainer.currentScale

            // HEADER ROW
            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * infoContainer.currentScale
                visible: Config.sysInfoShowHost !== false

                Item {
                    implicitWidth: headerIcon.implicitWidth
                    implicitHeight: headerIcon.implicitHeight

                    Glow {
                        anchors.fill: headerIcon
                        source: headerIcon
                        radius: 6
                        samples: 12
                        color: Config.accent
                        spread: 0.2
                        transparentBorder: true
                        visible: Config.sysInfoShowGlow !== false
                    }

                    Text {
                        id: headerIcon
                        text: "terminal"
                        color: Config.accent
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: Config.size(Config.fontTitle) * infoContainer.currentScale
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "SYSTEM SPECIFICATION"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption) * infoContainer.currentScale
                        font.bold: true
                        font.italic: true
                        font.letterSpacing: 1.2
                    }

                    Text {
                        text: sysInfoWindow.hostUser
                        color: Config.accent
                        font.family: "monospace"
                        font.pixelSize: Config.size(Config.fontMicro) * infoContainer.currentScale
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(255, 255, 255, 0.08)
                visible: Config.sysInfoShowHost !== false
            }

            // STATS ROWS
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5 * infoContainer.currentScale

                RowLayout {
                    Layout.fillWidth: true
                    visible: Config.sysInfoShowKernel !== false
                    Text { text: "Kernel"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro) * infoContainer.currentScale; Layout.preferredWidth: 60 * infoContainer.currentScale }
                    Text { text: sysInfoWindow.kernelVer; color: Config.textMain; font.family: "monospace"; font.pixelSize: Config.size(Config.fontMicro) * infoContainer.currentScale; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: Config.sysInfoShowUptime !== false
                    Text { text: "Uptime"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro) * infoContainer.currentScale; Layout.preferredWidth: 60 * infoContainer.currentScale }
                    Text { text: sysInfoWindow.sysUptime; color: Config.textMain; font.family: "monospace"; font.pixelSize: Config.size(Config.fontMicro) * infoContainer.currentScale; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: Config.sysInfoShowIp !== false
                    Text { text: "IPv4"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro) * infoContainer.currentScale; Layout.preferredWidth: 60 * infoContainer.currentScale }
                    Text { text: sysInfoWindow.localIp; color: Config.textMain; font.family: "monospace"; font.pixelSize: Config.size(Config.fontMicro) * infoContainer.currentScale; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: Config.sysInfoShowCpu !== false
                    Text { text: "Processor"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro) * infoContainer.currentScale; Layout.preferredWidth: 60 * infoContainer.currentScale }
                    Text { text: sysInfoWindow.cpuModel; color: Config.textMain; font.family: "monospace"; font.pixelSize: Config.size(Config.fontMicro) * infoContainer.currentScale; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }

            // RESOURCE BARS
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6 * infoContainer.currentScale

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    visible: Config.sysInfoShowRam !== false

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Memory"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro) * infoContainer.currentScale }
                        Item { Layout.fillWidth: true }
                        Text { text: sysInfoWindow.ramText; color: Config.accent; font.family: "monospace"; font.pixelSize: Config.size(Config.fontMicro) * infoContainer.currentScale; font.bold: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 4 * infoContainer.currentScale
                        radius: height / 2
                        color: Qt.rgba(255, 255, 255, 0.08)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * sysInfoWindow.ramPct
                            radius: height / 2
                            color: Config.accent
                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    visible: Config.sysInfoShowDisk !== false

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Root Disk"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro) * infoContainer.currentScale }
                        Item { Layout.fillWidth: true }
                        Text { text: sysInfoWindow.diskText; color: Config.accent; font.family: "monospace"; font.pixelSize: Config.size(Config.fontMicro) * infoContainer.currentScale; font.bold: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 4 * infoContainer.currentScale
                        radius: height / 2
                        color: Qt.rgba(255, 255, 255, 0.08)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * sysInfoWindow.diskPct
                            radius: height / 2
                            color: Config.accent
                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            drag.target: infoContainer
            drag.axis: Drag.XAndYAxis
            cursorShape: Qt.PointingHandCursor

            onPositionChanged: {
                if (drag.active) {
                    infoContainer.dragX = infoContainer.x
                    infoContainer.dragY = infoContainer.y
                }
            }

            onWheel: (wheel) => {
                let step = 0.1
                let newScale = infoContainer.currentScale
                if (wheel.angleDelta.y > 0) {
                    newScale = Math.min(3.0, newScale + step)
                } else {
                    newScale = Math.max(0.5, newScale - step)
                }
                
                if (sysInfoWindow.screen && Config.saveSysInfoScale) {
                    Config.saveSysInfoScale(sysInfoWindow.screen.name, newScale)
                }
            }
        }
    }
}