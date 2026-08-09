import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    implicitWidth: mainLayout.implicitWidth + (cardMargin * 2)
    implicitHeight: mainLayout.implicitHeight + (cardMargin * 2)

    // --- State Properties ---
    property string activeVpnName: ""
    property bool showFileBrowser: false
    property string currentBrowserPath: "file://" + Quickshell.env("HOME")

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

    ListModel { id: vpnListModel }
    ListModel { id: graphHistoryModel }

    // Seed history buffer with zeros to maintain fixed layout width from start
    function seedGraphModel() {
        graphHistoryModel.clear()
        for (let i = 0; i < root.maxGraphPoints; i++) {
            graphHistoryModel.append({ "speedValue": 0.0 })
        }
    }

    Component.onCompleted: seedGraphModel()

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
        id: syncVpnTimer
        interval: 3000
        running: Config.showNetwork && !showFileBrowser
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            vpnListPopulator.running = false
            vpnListPopulator.running = true
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

    Process {
        id: bandwidthStreamProc
        command: ["fish", "-c", "
            set dev (ip route show | awk '/default/ {print $5}' | head -n1)
            while true
                cat /proc/net/dev | grep \"$dev\"
                sleep 0.1
            end
        "]
        running: Config.showNetwork
        
        stdout: SplitParser {
            onRead: data => {
                let formatBytes = function(bytes) {
                    if (bytes < 1024) return bytes.toFixed(0) + " B/s"
                    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB/s"
                    return (bytes / 1048576).toFixed(1) + " MB/s"
                }
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
                        let rxSpeed = (rx - root.lastRxBytes) / elapsed
                        let txSpeed = (tx - root.lastTxBytes) / elapsed
                        
                        if (now - root.lastTextUpdateTime >= 1000) {
                            root.downloadSpeed = formatBytes(rxSpeed)
                            root.uploadSpeed = formatBytes(txSpeed)
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

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: root.cardMargin
        spacing: root.cardMargin

        // Dashboard Panel
        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.cardMargin / 2
            visible: !root.showFileBrowser

            // ==========================================
            // CARD 1: NETWORK SPEED & GRAPH
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitWidth: 380
                implicitHeight: speedCardLayout.implicitHeight + (root.cardMargin * 2)
                color: Qt.rgba(255, 255, 255, 0.05)
                radius: Config.cornerRadius

                ColumnLayout {
                    id: speedCardLayout
                    anchors.fill: parent
                    anchors.margins: root.cardMargin
                    spacing: root.cardMargin

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "NETWORK"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontTitle)
                            font.bold: true
                            Layout.fillWidth: true
                        }
                    }

                    // Speeds
                    RowLayout {
                        Layout.fillWidth: true
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: "DOWNLOAD"; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro); color: Config.textMuted; font.bold: true; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                            Text { text: root.downloadSpeed; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontBody); font.bold: true; color: Config.textMain; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: "UPLOAD"; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro); color: Config.textMuted; font.bold: true; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                            Text { text: root.uploadSpeed; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontBody); font.bold: true; color: Config.textMain; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                        }
                    }

                    // Frame-Synchronized Smooth Viewport
                    Item {
                        id: sparklineCanvasWrapper
                        Layout.fillWidth: true
                        height: 44
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

                                // 3. Crisp foreground line pass (removes shadow blur so line retains sharp core)
                                buildLinePath()
                                ctx.shadowBlur = 0
                                ctx.stroke()
                            }
                        }
                    }
                }
            }

            // ==========================================
            // CARD 2: VPN PROFILES
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: vpnCardLayout.implicitHeight + (root.cardMargin * 2)
                color: Qt.rgba(255, 255, 255, 0.05)
                radius: Config.cornerRadius

                ColumnLayout {
                    id: vpnCardLayout
                    anchors.fill: parent
                    anchors.margins: root.cardMargin
                    spacing: root.cardMargin

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "VPN PROFILES"; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro); font.bold: true; color: Config.textMuted; Layout.fillWidth: true }
                        
                        Rectangle {
                            implicitWidth: importText.implicitWidth + 16
                            implicitHeight: 22
                            radius: Config.cornerRadius / 2
                            color: importHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                            Text {
                                id: importText
                                anchors.centerIn: parent
                                text: "+ IMPORT"
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: true
                                color: importHover.hovered ? Config.bgBase : Config.textMain
                            }

                            TapHandler {
                                onTapped: root.showFileBrowser = true
                            }
                            HoverHandler { id: importHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }

                    ListView {
                        id: profileListView
                        Layout.fillWidth: true
                        implicitHeight: Math.min(vpnListModel.count * 52, 160)
                        spacing: 6
                        model: vpnListModel

                        delegate: Rectangle {
                            id: profileItemDelegate
                            property bool isActive: root.activeVpnName === profileName

                            width: profileListView.width
                            implicitHeight: 46
                            radius: Config.cornerRadius / 2.5
                            color: isActive ? Qt.rgba(255, 255, 255, 0.12) : (itemHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.25))
                            border.color: isActive ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                            border.width: 2

                            Behavior on color { ColorAnimation { duration: 150 } }

                            TapHandler {
                                gesturePolicy: TapHandler.WithinBounds
                                onTapped: root.toggleProfileState(profileName, !profileItemDelegate.isActive)
                            }

                            HoverHandler { 
                                id: itemHover
                                cursorShape: Qt.PointingHandCursor 
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                // Left Action Icon Frame
                                Rectangle {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    radius: Config.cornerRadius / 2
                                    color: isActive ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: isActive ? "vpn_key" : "vpn_key_off"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 18
                                        color: isActive ? Config.bgBase : Config.textMuted
                                    }
                                }

                                ColumnLayout {
                                    spacing: 1
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignLeft

                                    Text { 
                                        text: profileName
                                        font.family: Config.sysFont
                                        font.bold: true
                                        font.pixelSize: Config.size(Config.fontCaption)
                                        color: isActive ? Config.accent : Config.textMain
                                        horizontalAlignment: Text.AlignLeft
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    
                                    Text { 
                                        text: isActive ? "Connected" : "Disconnected"
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontMicro)
                                        color: Config.textMuted
                                        horizontalAlignment: Text.AlignLeft
                                        Layout.fillWidth: true
                                    }
                                }

                                // Neutral Delete Icon aligned strictly to the right
                                Rectangle {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    radius: Config.cornerRadius / 2
                                    color: delHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                                    Layout.alignment: Qt.AlignRight

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "delete"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 18
                                        color: delHover.hovered ? Config.accent : Config.textMuted
                                    }

                                    TapHandler {
                                        gesturePolicy: TapHandler.WithinBounds
                                        onTapped: root.deleteProfile(profileName)
                                    }
                                    HoverHandler { id: delHover; cursorShape: Qt.PointingHandCursor }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // CARD 3: FILE BROWSER PANEL
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: browserLayout.implicitHeight + (root.cardMargin * 2)
            color: Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius
            visible: root.showFileBrowser

            ColumnLayout {
                id: browserLayout
                anchors.fill: parent
                anchors.margins: root.cardMargin
                spacing: root.cardMargin

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "SELECT VPN CONFIG"; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontTitle); font.bold: true; color: Config.textMain; Layout.fillWidth: true }
                    
                    Rectangle {
                        implicitWidth: cancelText.implicitWidth + 16
                        implicitHeight: 22
                        radius: Config.cornerRadius / 2
                        color: cancelHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                        Text {
                            id: cancelText
                            anchors.centerIn: parent
                            text: "CANCEL"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            color: cancelHover.hovered ? Config.bgBase : Config.textMuted
                        }

                        TapHandler { onTapped: root.showFileBrowser = false }
                        HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor }
                    }
                }

                Text { text: root.currentBrowserPath.replace("file://", ""); font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); color: Config.textMuted; elide: Text.ElideLeft; Layout.fillWidth: true }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(Math.max(fileListView.contentHeight + 12, 120), 320)
                    color: Qt.rgba(0, 0, 0, 0.15)
                    radius: Config.cornerRadius / 2
                    clip: true

                    ListView {
                        id: fileListView
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2
                        clip: true
                        model: FolderListModel {
                            folder: root.currentBrowserPath
                            showDirsFirst: true
                            showDotAndDotDot: true
                            nameFilters: ["*.conf", "*.ovpn", "*.vpn"] 
                        }

                        delegate: Rectangle {
                            width: fileListView.width
                            implicitHeight: fileName === "." ? 0 : 34
                            visible: fileName !== "."
                            radius: Config.cornerRadius / 2
                            color: fileHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent"

                            RowLayout {
                                spacing: 8
                                anchors.fill: parent
                                anchors.leftMargin: 8

                                Text { text: fileIsDir ? "folder" : "description"; font.family: "Material Symbols Outlined"; font.pixelSize: 16; color: Config.accent }
                                Text { text: fileName; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); color: Config.textMain; Layout.fillWidth: true; elide: Text.ElideRight }
                            }

                            TapHandler {
                                onTapped: {
                                    if (fileIsDir) {
                                        root.currentBrowserPath = fileUrl.toString()
                                    } else {
                                        let urlString = fileUrl.toString()
                                        let parsedPath = urlString.startsWith("file:///") ? urlString.substring(7) : urlString.replace("file://", "")
                                        let isWg = parsedPath.endsWith(".conf")
                                        let typeStr = isWg ? "wireguard" : "openvpn"

                                        vpnImporter.command = ["fish", "-c", `nmcli connection import type ${typeStr} file "${parsedPath}"`]
                                        vpnImporter.running = true
                                        root.showFileBrowser = false
                                    }
                                }
                            }

                            HoverHandler { id: fileHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }
        }
    }

    // Backend Execution Processes
    Process {
        id: vpnListPopulator
        command: ["nmcli", "-g", "TYPE,NAME,STATE", "connection", "show"]
        running: false
        
        stdout: StdioCollector {
            onTextChanged: {
                let cleanText = text.trim()
                if (!cleanText) { vpnListModel.clear(); root.activeVpnName = ""; return }
                let lines = cleanText.split("\n")
                let incomingProfiles = []
                let currentActive = ""

                for (let i = 0; i < lines.length; i++) {
                    let parts = lines[i].trim().split(":")
                    if (parts.length >= 2) {
                        let type = parts[0], name = parts[1], state = parts[2] || ""
                        if (type === "wireguard" || type === "vpn" || type === "tun" || type === "overlay" || type === "connection") {
                            if (state.indexOf("activated") !== -1) currentActive = name
                            if (incomingProfiles.indexOf(name) === -1) incomingProfiles.push(name)
                        }
                    }
                }

                root.activeVpnName = currentActive
                for (let m = vpnListModel.count - 1; m >= 0; m--) {
                    if (incomingProfiles.indexOf(vpnListModel.get(m).profileName) === -1) vpnListModel.remove(m)
                }
                for (let p = 0; p < incomingProfiles.length; p++) {
                    let pName = incomingProfiles[p], found = false
                    for (let m = 0; m < vpnListModel.count; m++) { if (vpnListModel.get(m).profileName === pName) { found = true; break; } }
                    if (!found) vpnListModel.append({ "profileName": pName })
                }
            }
        }
    }

    Process { id: vpnStateExecutor; running: false; onExited: vpnListPopulator.running = true }
    Process { id: vpnImporter; running: false; onExited: vpnListPopulator.running = true }

    function toggleProfileState(profileName, itemChecked) {
        vpnStateExecutor.command = itemChecked 
            ? ["nmcli", "connection", "up", "id", profileName]
            : ["nmcli", "connection", "down", "id", profileName]
        vpnStateExecutor.running = true
    }

    function deleteProfile(profileName) {
        vpnStateExecutor.command = ["nmcli", "connection", "delete", "id", profileName]
        vpnStateExecutor.running = true
    }

    Connections {
        target: Config
        function onShowNetworkChanged() {
            if (Config.showNetwork) {
                seedGraphModel()
                vpnListPopulator.running = true
            }
        }
    }
}