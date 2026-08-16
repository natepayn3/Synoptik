import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    implicitWidth: mainLayout.implicitWidth + (cardMargin * 2)
    implicitHeight: mainLayout.implicitHeight + (cardMargin * 2)

    // --- State Properties ---
    property string activeVpnName: ""
    property string localIp: ""
    property string interfaceName: ""
    property string ssid: ""

    // --- Live Bandwidth Properties ---
    property string downloadSpeed: "0 B/s"
    property string uploadSpeed: "0 B/s"
    property var lastRxBytes: 0
    property var lastTxBytes: 0
    property var lastTime: 0
    
    property real currentInstantSpeed: 0.0
    property var lastTextUpdateTime: 0
    property int maxGraphPoints: 30
    property int updateInterval: 500

    // Frame sync tracking for jitter-free scrolling
    property real lastPushTimestamp: Date.now()
    property real scrollProgress: 0.0

    // Interpolated peak to prevent jarring Y-axis snapping
    property real smoothPeakSpeed: 1024 * 1024

    Behavior on smoothPeakSpeed {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    ListModel { id: graphHistoryModel }

    function formatRate(bytesPerSec) {
        if (bytesPerSec < 1024) return Math.max(0, bytesPerSec).toFixed(0) + " B/s"
        if (bytesPerSec < 1048576) return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        return (bytesPerSec / 1048576).toFixed(1) + " MB/s"
    }

    function seedGraphModel() {
        graphHistoryModel.clear()
        for (let i = 0; i < root.maxGraphPoints; i++) {
            graphHistoryModel.append({ "speedValue": 0.0 })
        }
    }

    Component.onCompleted: {
        seedGraphModel()
        fetchNetInfoProc.running = false
        fetchNetInfoProc.running = true
    }

    // Frame-synchronized animation loop
    FrameAnimation {
        id: frameGraphSync
        running: Config.showNetwork
        onTriggered: {
            let elapsed = Date.now() - root.lastPushTimestamp
            root.scrollProgress = Math.min(elapsed / root.updateInterval, 1.0)
            sparklineCanvas.requestPaint()
        }
    }

    Timer {
        id: netInfoTimer
        interval: 4000
        running: Config.showNetwork
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            fetchNetInfoProc.running = false
            fetchNetInfoProc.running = true
        }
    }

    // Graph Data Ticker
    Timer {
        id: timelineGraphTicker
        interval: root.updateInterval
        running: Config.showNetwork
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            graphHistoryModel.append({ "speedValue": root.currentInstantSpeed })
            if (graphHistoryModel.count > root.maxGraphPoints) {
                graphHistoryModel.remove(0)
            }

            let currentMax = 1024 * 1024
            for (let i = 0; i < graphHistoryModel.count; i++) {
                let v = graphHistoryModel.get(i).speedValue
                if (v > currentMax) currentMax = v
            }
            root.smoothPeakSpeed = currentMax
            root.lastPushTimestamp = Date.now()
            root.scrollProgress = 0.0
        }
    }

    // Background Bandwidth Stream via /proc/net/dev
    Process {
        id: bandwidthStreamProc
        command: ["python3", "-u", "-c", `
import time, subprocess
try:
    dev = subprocess.check_output("ip route show | awk '/default/ {print $5}' | head -n1", shell=True).decode().strip()
except Exception:
    dev = ""
while True:
    try:
        with open("/proc/net/dev", "r") as f:
            for line in f:
                if dev and dev in line:
                    print(line.strip(), flush=True)
                    break
    except Exception:
        pass
    time.sleep(0.25)
        `]
        running: Config.showNetwork
        
        stdout: SplitParser {
            onRead: data => {
                let textStr = data.trim()
                if (!textStr) return
                
                let rawLineParts = textStr.split(":")
                if (rawLineParts.length < 2) return
                
                let parts = rawLineParts[1].trim().split(/\s+/)
                if (parts.length < 9) return

                let rx = parseInt(parts[0]) 
                let tx = parseInt(parts[8]) 
                let now = Date.now()

                if (root.lastTime > 0) {
                    let elapsed = (now - root.lastTime) / 1000
                    if (elapsed > 0) {
                        let rxSpeed = Math.max(0, (rx - root.lastRxBytes) / elapsed)
                        let txSpeed = Math.max(0, (tx - root.lastTxBytes) / elapsed)
                        
                        if (now - root.lastTextUpdateTime >= 400) {
                            root.downloadSpeed = root.formatRate(rxSpeed)
                            root.uploadSpeed = root.formatRate(txSpeed)
                            root.lastTextUpdateTime = now
                        }

                        root.currentInstantSpeed = rxSpeed + txSpeed
                    }
                }

                root.lastRxBytes = rx
                root.lastTxBytes = tx
                root.lastTime = now
            }
        }
    }

    // Info Process (SSID, Interface, IP, VPN)
    Process {
        id: fetchNetInfoProc
        command: ["fish", "-c", `
            set s (nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1 ~ /yes|true/ {print $2; exit}')
            set d (ip route show 2>/dev/null | awk '/default/ {print $5}' | head -n1)
            set ip ""
            if test -n "$d"
                set ip (ip -4 addr show dev $d 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
            end
            set v (nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | awk -F: '$1 ~ /wireguard|vpn|tun|overlay/ {print $2; exit}')
            echo "$s|$d|$ip|$v"
        `]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let clean = this.text.trim()
                if (!clean) return
                let parts = clean.split("|")
                if (parts.length >= 4) {
                    root.ssid = parts[0] ? parts[0].trim() : ""
                    root.interfaceName = parts[1] ? parts[1].trim() : ""
                    root.localIp = parts[2] ? parts[2].trim() : ""
                    root.activeVpnName = parts[3] ? parts[3].trim() : ""
                }
            }
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: root.cardMargin
        spacing: root.cardMargin / 2

        // ==========================================
        // CARD 1: TITLE, STATUS & SPARKLINE GRAPH
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitWidth: 360
            implicitHeight: topCardContent.implicitHeight + (root.cardMargin * 2)
            radius: Config.cornerRadius
            color: Qt.rgba(1, 1, 1, 0.05)
            clip: true

            // GRAPHIC WATERMARK
            Watermark {
                icon: root.activeVpnName !== "" ? "vpn_key" : Config.getIcon("network")
                iconSize: 150
                seed: 19
            }

            ColumnLayout {
                id: topCardContent
                anchors.fill: parent
                anchors.margins: root.cardMargin
                spacing: root.cardMargin

                // Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: root.activeVpnName !== "" ? "vpn_key" : Config.getIcon("network")
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: Config.size(Config.fontTitle)
                        color: Config.textMain
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item {
                        implicitWidth: netTitleText.implicitWidth
                        implicitHeight: netTitleText.implicitHeight
                        Layout.fillWidth: true

                        Glow {
                            anchors.fill: netTitleText
                            source: netTitleText
                            radius: 8
                            samples: 16
                            color: Config.accent
                            spread: 0.2
                            transparentBorder: true
                            visible: Config.clockShowGlow
                        }

                        Text {
                            id: netTitleText
                            anchors.fill: parent
                            text: "NETWORK"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontTitle)
                            font.bold: true
                            font.italic: true
                        }
                    }

                    // VPN Active Key Badge
                    Rectangle {
                        visible: root.activeVpnName !== ""
                        implicitWidth: vpnBadgeRow.implicitWidth + 12
                        implicitHeight: 22
                        radius: Config.cornerRadius / 2
                        color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2)

                        RowLayout {
                            id: vpnBadgeRow
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "vpn_key"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 12
                                color: Config.accent
                            }

                            Text {
                                text: root.activeVpnName
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: true
                                color: Config.accent
                                elide: Text.ElideRight
                                Layout.maximumWidth: 120
                            }
                        }
                    }
                }

                // Connection Subtitle Track Row (similar to % Available in Battery)
                Text {
                    text: {
                        if (root.ssid && root.localIp) return root.ssid + " • " + root.localIp
                        if (root.ssid) return root.ssid
                        if (root.localIp) return root.localIp + (root.interfaceName ? (" • " + root.interfaceName) : "")
                        return "Connected"
                    }
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontSubhead)
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Frame-Synchronized Smooth Canvas
                Item {
                    id: sparklineCanvasWrapper
                    Layout.fillWidth: true
                    implicitHeight: 44
                    clip: true

                    Canvas {
                        id: sparklineCanvas
                        anchors.fill: parent
                        renderTarget: Canvas.Image
                        renderStrategy: Canvas.Threaded

                        onPaint: {
                            let ctx = getContext("2d")
                            let w = width
                            let h = height
                            ctx.clearRect(0, 0, w, h)

                            let totalPoints = graphHistoryModel.count
                            if (totalPoints < 2) return

                            let activePeak = root.smoothPeakSpeed
                            let step = w / (root.maxGraphPoints - 1)
                            let xOffset = root.scrollProgress * step

                            // 1. Fill region
                            ctx.beginPath()
                            ctx.moveTo(0, h)

                            for (let i = 0; i < totalPoints; i++) {
                                let nodeValue = graphHistoryModel.get(i).speedValue
                                let scaleRatio = nodeValue / activePeak
                                let coordX = (i * step) - xOffset
                                let coordY = h - (scaleRatio * (h - 4))
                                ctx.lineTo(coordX, coordY)
                            }

                            ctx.lineTo(((totalPoints - 1) * step) - xOffset, h)
                            ctx.closePath()
                            ctx.fillStyle = "rgba(255, 255, 255, 0.05)"
                            ctx.fill()

                            // Path helper for line rendering
                            function buildLinePath() {
                                ctx.beginPath()
                                for (let j = 0; j < totalPoints; j++) {
                                    let nodeValue = graphHistoryModel.get(j).speedValue
                                    let scaleRatio = nodeValue / activePeak
                                    let coordX = (j * step) - xOffset
                                    let coordY = h - (scaleRatio * (h - 4))
                                    if (j === 0) ctx.moveTo(coordX, coordY)
                                    else ctx.lineTo(coordX, coordY)
                                }
                            }

                            // 2. Glow pass (blurred background line)
                            buildLinePath()
                            ctx.strokeStyle = Config.accent
                            ctx.lineWidth = 2
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.shadowColor = Config.accent
                            ctx.shadowBlur = 8
                            ctx.stroke()

                            // 3. Crisp foreground line pass
                            buildLinePath()
                            ctx.shadowBlur = 0
                            ctx.stroke()
                        }
                    }
                }
            }
        }

        // ==========================================
        // SUB-STATS CARDS ROW (Matching Battery.qml)
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            spacing: root.cardMargin / 2

            // Card 2: Download Stats Card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 64
                radius: Config.cornerRadius
                color: Qt.rgba(1, 1, 1, 0.05)
                clip: true

                // GRAPHIC WATERMARK
                Watermark {
                    icon: "arrow_downward"
                    iconSize: 80
                    seed: 20
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        text: "DOWNLOAD"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.downloadSpeed
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // Card 3: Upload Stats Card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 64
                radius: Config.cornerRadius
                color: Qt.rgba(1, 1, 1, 0.05)
                clip: true

                // GRAPHIC WATERMARK
                Watermark {
                    icon: "arrow_upward"
                    iconSize: 80
                    seed: 21
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        text: "UPLOAD"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.uploadSpeed
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }

    Connections {
        target: Config
        function onShowNetworkChanged() {
            if (Config.showNetwork) {
                seedGraphModel()
                fetchNetInfoProc.running = false
                fetchNetInfoProc.running = true
            }
        }
    }
}