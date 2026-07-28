import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import ".."

ColumnLayout {
    id: root
    spacing: 12

    property string activeVpnName: ""
    property bool showFileBrowser: false
    property string currentBrowserPath: "file://" + Quickshell.env("HOME")

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

    Component.onCompleted: {
        seedGraphModel()
    }

    // Frame-synchronized animation loop
    FrameAnimation {
        id: frameGraphSync
        running: root.visible
        onTriggered: {
            let elapsed = Date.now() - root.lastPushTimestamp
            root.scrollProgress = Math.min(elapsed / root.updateInterval, 1.0)
            sparklineCanvas.requestPaint()
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            vpnListPopulator.running = false
            vpnListPopulator.running = true
        }
    }

    // Graph Data Ticker
    Timer {
        interval: root.updateInterval
        running: true
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
        running: true
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

    // MAIN CONTENT STACK
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 12
        visible: !root.showFileBrowser

        // BANDWIDTH MONITOR CARD
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 110
            color: Qt.rgba(255, 255, 255, 0.04)
            radius: Config.cornerRadius / 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 24

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { 
                            text: "DOWNLOAD"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            color: Config.textMuted
                            font.bold: true 
                        }
                        Text { 
                            text: root.downloadSpeed
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: true
                            color: Config.textMain 
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { 
                            text: "UPLOAD"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            color: Config.textMuted
                            font.bold: true 
                        }
                        Text { 
                            text: root.uploadSpeed
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: true
                            color: Config.textMain 
                        }
                    }
                }

                // Frame-Synchronized Smooth Viewport
                Item {
                    id: canvasWrapper
                    Layout.fillWidth: true
                    Layout.fillHeight: true
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

                            // Fill region
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

                            // Line stroke
                            ctx.beginPath()
                            for (let j = 0; j < totalPoints; j++) {
                                let nodeValue = graphHistoryModel.get(j).speedValue
                                let scaleRatio = nodeValue / activePeak
                                let coordX = (j * step) - xOffset
                                let coordY = h - (scaleRatio * (h - 4))
                                if (j === 0) ctx.moveTo(coordX, coordY)
                                else ctx.lineTo(coordX, coordY)
                            }
                            ctx.strokeStyle = Config.accent
                            ctx.lineWidth = 1.5
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.stroke()
                        }
                    }
                }
            }
        }

        // PROFILES HEADER & LIST
        RowLayout {
            Layout.fillWidth: true
            Text { text: "VPN PROFILES"; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: true; color: Config.textMuted; Layout.fillWidth: true }
            
            Rectangle {
                implicitWidth: 80; implicitHeight: 24; radius: Config.cornerRadius / 2
                color: impHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                Text { anchors.centerIn: parent; text: "+ IMPORT"; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro); font.bold: true; color: impHover.hovered ? Config.bgBase : Config.textMain }
                TapHandler { onTapped: root.showFileBrowser = true }
                HoverHandler { id: impHover; cursorShape: Qt.PointingHandCursor }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(0, 0, 0, 0.2)
            radius: Config.cornerRadius / 2
            clip: true

            ListView {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4
                model: vpnListModel

                delegate: Rectangle {
                    required property string profileName
                    readonly property bool isActive: root.activeVpnName === profileName

                    width: ListView.view.width
                    implicitHeight: 46
                    radius: Config.cornerRadius / 2.5
                    color: isActive ? Qt.rgba(255, 255, 255, 0.12) : (pHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.25))
                    border.color: isActive ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        // Key Icon Action Button (Matches Network.qml)
                        Rectangle {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: Config.cornerRadius / 2
                            color: btnHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : (isActive ? Config.accent : Qt.rgba(255, 255, 255, 0.08))

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: isActive ? "vpn_key" : "vpn_key_off"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 18
                                color: isActive ? Config.bgBase : Config.textMuted
                            }

                            TapHandler {
                                gesturePolicy: TapHandler.WithinBounds
                                onTapped: root.toggleProfileState(profileName, !isActive)
                            }
                            HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
                        }

                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true

                            Text { 
                                text: profileName
                                font.family: Config.sysFont
                                font.bold: true
                                font.pixelSize: Config.size(Config.fontCaption)
                                color: isActive ? Config.accent : Config.textMain
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            
                            Text { 
                                text: isActive ? "Connected" : "Disconnected"
                                font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro)
                                color: Config.textMuted
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: Config.cornerRadius / 2
                            color: delHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                            
                            Text { anchors.centerIn: parent; text: "delete"; font.family: "Material Symbols Outlined"; font.pixelSize: 18; color: delHover.hovered ? Config.accent : Config.textMuted }
                            TapHandler {
                                gesturePolicy: TapHandler.WithinBounds
                                onTapped: root.deleteProfile(profileName) 
                            }
                            HoverHandler { id: delHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }

                    HoverHandler { id: pHover; cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }

    // FILE BROWSER
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 8
        visible: root.showFileBrowser

        RowLayout {
            Layout.fillWidth: true
            Text { text: "SELECT CONFIG"; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: true; color: Config.textMain; Layout.fillWidth: true }
            Rectangle {
                implicitWidth: 70; implicitHeight: 24; radius: Config.cornerRadius / 2
                color: cancelHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.08)
                Text { anchors.centerIn: parent; text: "CANCEL"; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro); font.bold: true; color: cancelHover.hovered ? Config.bgBase : Config.textMuted }
                TapHandler { onTapped: root.showFileBrowser = false }
                HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(0, 0, 0, 0.2)
            radius: Config.cornerRadius / 2
            clip: true

            ListView {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2
                model: FolderListModel {
                    folder: root.currentBrowserPath
                    showDirsFirst: true
                    showDotAndDotDot: true
                    nameFilters: ["*.conf", "*.ovpn", "*.vpn"]
                }

                delegate: Rectangle {
                    required property string fileName
                    required property bool fileIsDir
                    required property url fileUrl

                    width: ListView.view.width
                    implicitHeight: fileName === "." ? 0 : 32
                    visible: fileName !== "."
                    radius: Config.cornerRadius / 2
                    color: fHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent"

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8
                        spacing: 8
                        Text { text: fileIsDir ? "folder" : "description"; font.family: "Material Symbols Outlined"; font.pixelSize: 16; color: Config.accent }
                        Text { text: fileName; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); color: Config.textMain; Layout.fillWidth: true; elide: Text.ElideRight }
                    }

                    TapHandler {
                        onTapped: {
                            if (fileIsDir) {
                                root.currentBrowserPath = fileUrl.toString()
                            } else {
                                let parsedPath = fileUrl.toString().replace("file://", "")
                                let typeStr = parsedPath.endsWith(".conf") ? "wireguard" : "openvpn"
                                vpnImporter.command = ["fish", "-c", `nmcli connection import type ${typeStr} file "${parsedPath}"`]
                                vpnImporter.running = true
                                root.showFileBrowser = false
                            }
                        }
                    }
                    HoverHandler { id: fHover; cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }

    Process {
        id: vpnListPopulator
        command: ["nmcli", "-g", "TYPE,NAME,STATE", "connection", "show"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                let cleanText = text.trim()
                if (!cleanText) { vpnListModel.clear(); root.activeVpnName = ""; return }
                let lines = cleanText.split("\n")
                let incoming = [], currentActive = ""
                for (let i = 0; i < lines.length; i++) {
                    let parts = lines[i].trim().split(":")
                    if (parts.length >= 2) {
                        let type = parts[0], name = parts[1], state = parts[2] || ""
                        if (type === "wireguard" || type === "vpn" || type === "tun" || type === "overlay") {
                            if (state.indexOf("activated") !== -1) currentActive = name
                            if (incoming.indexOf(name) === -1) incoming.push(name)
                        }
                    }
                }
                root.activeVpnName = currentActive
                for (let m = vpnListModel.count - 1; m >= 0; m--) {
                    if (incoming.indexOf(vpnListModel.get(m).profileName) === -1) vpnListModel.remove(m)
                }
                for (let p = 0; p < incoming.length; p++) {
                    let pName = incoming[p], found = false
                    for (let m = 0; m < vpnListModel.count; m++) { if (vpnListModel.get(m).profileName === pName) { found = true; break; } }
                    if (!found) vpnListModel.append({ "profileName": pName })
                }
            }
        }
    }

    Process { id: vpnStateExecutor; running: false; onExited: vpnListPopulator.running = true }
    Process { id: vpnImporter; running: false; onExited: vpnListPopulator.running = true }

    function toggleProfileState(profileName, itemChecked) {
        vpnStateExecutor.command = itemChecked ? ["nmcli", "connection", "up", "id", profileName] : ["nmcli", "connection", "down", "id", profileName]
        vpnStateExecutor.running = true
    }

    function deleteProfile(profileName) {
        vpnStateExecutor.command = ["nmcli", "connection", "delete", "id", profileName]
        vpnStateExecutor.running = true
    }
}