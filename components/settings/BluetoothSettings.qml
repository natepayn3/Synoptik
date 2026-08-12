import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."

ColumnLayout {
    id: root
    spacing: 12

    property bool hasAdapter: false
    property bool isPowered: false
    property bool isScanning: false
    property string activeDeviceName: ""
    property string connectingMac: ""

    opacity: root.hasAdapter ? 1.0 : 0.4
    enabled: root.hasAdapter

    ListModel { id: btModel }

    Component.onCompleted: {
        detectBtAdapterProc.running = true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            implicitWidth: 36; implicitHeight: 36; radius: Config.cornerRadius / 2
            color: root.isPowered && root.hasAdapter ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

            Text {
                anchors.centerIn: parent
                text: !root.hasAdapter ? "bluetooth_disabled" : (root.isPowered ? "bluetooth" : "bluetooth_disabled")
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: root.isPowered && root.hasAdapter ? Config.bgBase : Config.textMuted
            }

            TapHandler {
                enabled: root.hasAdapter
                onTapped: {
                    powerBtProc.command = ["fish", "-c", "bluetoothctl power " + (root.isPowered ? "off" : "on")]
                    powerBtProc.running = true
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { text: "Bluetooth Controller"; font.family: Config.sysFont; font.bold: true; color: Config.textMain; font.pixelSize: Config.size(Config.fontCaption) }
            Text { 
                text: !root.hasAdapter ? "No Controller" : (!root.isPowered ? "Powered Off" : (root.activeDeviceName !== "" ? root.activeDeviceName : "Powered On"))
                font.family: Config.sysFont
                font.bold: root.activeDeviceName !== "" && root.hasAdapter
                color: root.activeDeviceName !== "" && root.hasAdapter ? Config.accent : Config.textMuted
                font.pixelSize: Config.size(Config.fontMicro)
            }
        }

        Rectangle {
            implicitWidth: 28; implicitHeight: 28; radius: 14
            visible: root.isPowered && root.hasAdapter
            color: btScanHover.hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent"

            Text {
                id: btScanIcon
                anchors.centerIn: parent
                text: "refresh"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 16
                color: btScanHover.hovered ? Config.textMain : Config.textMuted

                RotationAnimator { target: btScanIcon; from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: root.isScanning }
            }

            TapHandler { onTapped: root.triggerScan() }
            HoverHandler { id: btScanHover; cursorShape: Qt.PointingHandCursor }
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
            model: btModel

            delegate: Rectangle {
                required property string mac
                required property string name
                required property bool connected
                required property bool paired

                property bool isConnecting: root.connectingMac === mac

                width: ListView.view.width
                implicitHeight: 36
                radius: Config.cornerRadius / 2
                color: connected ? Qt.rgba(255, 255, 255, 0.12) : (bHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 8

                    Text { text: "bluetooth"; font.family: "Material Symbols Outlined"; font.pixelSize: 16; color: connected ? Config.accent : Config.textMuted }
                    Text { text: name; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: connected; color: connected ? Config.accent : Config.textMain; Layout.fillWidth: true; elide: Text.ElideRight }

                    RowLayout {
                        spacing: 4

                        // Connect / Disconnect / Pair Button
                        Rectangle {
                            implicitWidth: 54; implicitHeight: 24; radius: Config.cornerRadius / 2
                            color: actionHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : (connected ? Qt.rgba(255, 255, 255, 0.08) : Config.accent)

                            Text {
                                anchors.centerIn: parent
                                text: isConnecting ? "..." : (connected ? "OFF" : (paired ? "JOIN" : "PAIR"))
                                font.family: Config.sysFont; font.bold: true; font.pixelSize: Config.size(Config.fontMicro)
                                color: actionHover.hovered ? Config.accent : (connected ? Config.textMain : Config.bgBase)
                            }

                            TapHandler {
                                onTapped: {
                                    if (isConnecting || !root.hasAdapter) return
                                    if (connected) {
                                        root.execBtCmd(`bluetoothctl disconnect ${mac}`)
                                    } else if (paired) {
                                        root.execBtCmd(`bluetoothctl connect ${mac}`, mac)
                                    } else {
                                        // Semicolons keep fish happy so trust and connect execute sequentially
                                        root.execBtCmd(`bluetoothctl pair ${mac}; bluetoothctl trust ${mac}; bluetoothctl connect ${mac}`, mac)
                                    }
                                }
                            }
                            HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
                        }

                        // Forget / Remove Paired Profile Button
                        Rectangle {
                            visible: true
                            implicitWidth: 58; implicitHeight: 24; radius: Config.cornerRadius / 2
                            color: forgetHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "FORGET"
                                font.family: Config.sysFont; font.bold: true; font.pixelSize: Config.size(Config.fontMicro)
                                color: forgetHover.hovered ? Config.accent : Config.textMuted
                            }

                            TapHandler {
                                onTapped: {
                                    if (!root.hasAdapter) return
                                    root.execBtCmd(`bluetoothctl disconnect ${mac}; bluetoothctl untrust ${mac}; bluetoothctl remove ${mac}`)
                                }
                            }
                            HoverHandler { id: forgetHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }

                HoverHandler { id: bHover; cursorShape: Qt.PointingHandCursor }
            }
        }
    }

    Timer { 
        interval: 3000; running: root.visible && root.hasAdapter; repeat: true; triggeredOnStart: true; 
        onTriggered: fetchBtStatusProc.running = true 
    }

    Process {
        id: detectBtAdapterProc
        command: ["fish", "-c", "bluetoothctl list | grep -q 'Controller' && echo 'YES' || echo 'NO'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasAdapter = this.text.trim() === "YES"
                if (root.hasAdapter) fetchBtStatusProc.running = true
            }
        }
    }

    Process { id: powerBtProc; running: false; onExited: fetchBtStatusProc.running = true }
    
    Process { 
        id: execBtProc
        running: false
        onExited: {
            root.connectingMac = ""
            fetchBtStatusProc.running = true 
        }
    }

    Process {
        id: fetchBtStatusProc
        command: ["fish", "-c", "bluetoothctl show"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let textStr = this.text
                if (!textStr || textStr.includes("No default controller available") || !root.hasAdapter) {
                    root.isPowered = false
                    root.activeDeviceName = ""
                    btModel.clear()
                } else {
                    root.isPowered = textStr.includes("Powered: yes")
                    if (root.isPowered) {
                        fetchBtDevicesProc.running = true
                    } else {
                        root.activeDeviceName = ""
                        btModel.clear()
                    }
                }
            }
        }
    }

    Process {
        id: fetchBtDevicesProc
        command: ["fish", "-c", "for dev in (bluetoothctl devices); set mac (string match -r '([0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2})' $dev)[1]; if test -n '$mac'; bluetoothctl info $mac; echo '---DEV_END---'; end; end"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let chunks = this.text.trim().split("---DEV_END---")
                let newResults = []
                let seenMacs = {}
                let connectedNames = []

                for (let i = 0; i < chunks.length; i++) {
                    let text = chunks[i].trim()
                    if (!text) continue

                    let macMatch = text.match(/Device ([0-9A-FA-f:]+)/)
                    if (!macMatch) continue
                    let mac = macMatch[1]

                    if (seenMacs[mac]) continue
                    seenMacs[mac] = true

                    let nameMatch = text.match(/Name: (.*)/) || text.match(/Alias: (.*)/)
                    let name = nameMatch ? nameMatch[1].trim() : mac
                    let isConn = text.includes("Connected: yes")

                    if (isConn) {
                        connectedNames.push(name)
                    }

                    newResults.push({
                        mac: mac,
                        name: name,
                        connected: isConn,
                        paired: text.includes("Paired: yes")
                    })
                }

                root.activeDeviceName = connectedNames.length > 0 ? connectedNames.join(", ") : ""

                // Map current indices by MAC
                let existingMap = {}
                for (let idx = 0; idx < btModel.count; idx++) {
                    existingMap[btModel.get(idx).mac] = idx
                }

                let freshMap = {}
                let toAppend = []

                // In-place property updates to prevent layout jumping
                for (let k = 0; k < newResults.length; k++) {
                    let item = newResults[k]
                    freshMap[item.mac] = true

                    if (item.mac in existingMap) {
                        let tIndex = existingMap[item.mac]
                        let cur = btModel.get(tIndex)
                        if (cur.name !== item.name) btModel.setProperty(tIndex, "name", item.name)
                        if (cur.connected !== item.connected) btModel.setProperty(tIndex, "connected", item.connected)
                        if (cur.paired !== item.paired) btModel.setProperty(tIndex, "paired", item.paired)
                    } else {
                        toAppend.push(item)
                    }
                }

                // Append new devices to the end so row positions remain static
                for (let a = 0; a < toAppend.length; a++) {
                    btModel.append(toAppend[a])
                }

                // Remove vanished items from model
                for (let r = btModel.count - 1; r >= 0; r--) {
                    if (!freshMap[btModel.get(r).mac]) {
                        btModel.remove(r)
                    }
                }
            }
        }
    }

    function triggerScan() {
        if (!root.hasAdapter) return
        root.isScanning = true
        scanBtProc.command = ["fish", "-c", "bluetoothctl --timeout 5 scan on"]
        scanBtProc.running = true
    }

    Process { id: scanBtProc; running: false; onExited: { root.isScanning = false; fetchBtStatusProc.running = true } }
    
    function execBtCmd(cmd, mac = "") { 
        if (!root.hasAdapter) return
        root.connectingMac = mac
        execBtProc.command = ["fish", "-c", cmd]
        execBtProc.running = true 
    }
}