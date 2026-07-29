import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: cardRoot
    
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.alignment: Qt.AlignTop

    implicitHeight: 64
    Layout.preferredHeight: 64
    z: shouldExpand ? 10 : 1

    property bool isHovered: cardHover.hovered
    property bool isPowered: false
    property bool isScanning: false
    property bool hasHardware: true
    property string expandedMac: ""
    property string connectingMac: ""
    property string connectedDeviceName: ""

    property bool shouldExpand: isHovered && isPowered && hasHardware && btModel.count > 0

    signal togglePower(bool power)
    signal triggerScan()

    ListModel { id: btModel }

    Rectangle {
        id: visualBackground
        parent: cardRoot.parent.parent.parent 
        z: 100
        
        x: cardRoot.parent.parent.x + cardRoot.parent.x + cardRoot.x
        y: cardRoot.parent.parent.y + cardRoot.parent.y + cardRoot.y
        width: cardRoot.width
        
        height: cardRoot.shouldExpand ? (64 + 10 + btListView.targetHeight) : 64
        
        radius: Config.cornerRadius
        color: cardHover.hovered || cardRoot.shouldExpand ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.25)
        
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }

        HoverHandler { id: cardHover }

        Item {
            id: headerContainer
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 64

            Item {
                anchors.fill: parent
                anchors.margins: 10

                TapHandler {
                    gesturePolicy: TapHandler.WithinBounds
                    onTapped: cardRoot.execTogglePower(!cardRoot.isPowered)
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: Config.cornerRadius / 2
                        color: cardRoot.isPowered ? Config.accent : Qt.rgba(255, 255, 255, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: cardRoot.isPowered ? "bluetooth" : "bluetooth_disabled"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            color: cardRoot.isPowered ? Config.bgBase : Config.textMuted
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        clip: true

                        Text {
                            text: "Bluetooth"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: true
                            color: Config.textMain
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: !cardRoot.isPowered ? "Off" : (cardRoot.connectedDeviceName !== "" ? cardRoot.connectedDeviceName : "On")
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            color: cardRoot.connectedDeviceName !== "" ? Config.accent : Config.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        visible: cardRoot.isPowered
                        color: btScanHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: btScanIcon
                            anchors.centerIn: parent
                            text: "refresh"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 14
                            color: btScanHover.hovered ? Config.textMain : Config.textMuted

                            RotationAnimator {
                                target: btScanIcon
                                from: 0; to: 360; duration: 1000
                                loops: Animation.Infinite
                                running: cardRoot.isScanning
                            }
                        }

                        TapHandler { 
                            gesturePolicy: TapHandler.WithinBounds
                            onTapped: cardRoot.execTriggerScan() 
                        }
                        HoverHandler { id: btScanHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }

        ListView {
            id: btListView
            anchors.top: headerContainer.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            
            clip: true
            model: btModel
            spacing: 6

            property real targetHeight: Math.min(contentHeight, 220)
            
            opacity: cardRoot.shouldExpand ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            delegate: Rectangle {
                id: delegateRoot
                property bool isExpanded: cardRoot.expandedMac === model.mac
                property bool isConnecting: cardRoot.connectingMac === model.mac

                width: btListView.width
                implicitHeight: isExpanded ? (expandedBtContent.implicitHeight + 42) : 36
                radius: Config.cornerRadius / 2.5
                color: model.connected ? Qt.rgba(255, 255, 255, 0.12) : (btCardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.25))
                clip: true

                Behavior on implicitHeight { NumberAnimation { duration: 150 } }
                Behavior on color { ColorAnimation { duration: 150 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 24

                        RowLayout {
                            anchors.fill: parent
                            spacing: 6

                            Text {
                                text: "bluetooth"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                                color: model.connected ? Config.accent : Config.textMuted
                            }

                            Text {
                                text: model.name
                                color: model.connected ? Config.accent : Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: model.connected
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.WithinBounds
                            onTapped: cardRoot.expandedMac = (cardRoot.expandedMac === model.mac ? "" : model.mac)
                        }
                        HoverHandler { id: btCardHover; cursorShape: Qt.PointingHandCursor }
                    }

                    ColumnLayout {
                        id: expandedBtContent
                        Layout.fillWidth: true
                        visible: isExpanded
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            // Connect / Disconnect / Pair Button
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 24
                                radius: Config.cornerRadius / 2
                                color: connHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : (model.connected ? Qt.rgba(255, 255, 255, 0.08) : Config.accent)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: isConnecting ? "..." : (model.connected ? "OFF" : (model.paired ? "JOIN" : "PAIR"))
                                    color: connHover.hovered ? Config.accent : (model.connected ? Config.textMain : Config.bgBase)
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: true
                                }

                                TapHandler {
                                    gesturePolicy: TapHandler.WithinBounds
                                    onTapped: {
                                        if (isConnecting) return
                                        if (model.connected) cardRoot.reqDisconnectDevice(model.mac)
                                        else if (model.paired) cardRoot.reqConnectDevice(model.mac)
                                        else cardRoot.reqPairDevice(model.mac)
                                    }
                                }
                                HoverHandler { id: connHover; cursorShape: Qt.PointingHandCursor }
                            }

                            // Forget Button (Always Visible)
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 24
                                radius: Config.cornerRadius / 2
                                color: forgetBtHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "FORGET"
                                    color: forgetBtHover.hovered ? Config.accent : Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: true
                                }

                                TapHandler { 
                                    gesturePolicy: TapHandler.WithinBounds
                                    onTapped: cardRoot.reqRemoveDevice(model.mac) 
                                }
                                HoverHandler { id: forgetBtHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }
            }
        }
    }

    function execTogglePower(turnOn) {
        toggleBtProc.command = ["fish", "-c", `bluetoothctl power ${turnOn ? "on" : "off"}`]
        toggleBtProc.running = true
    }

    function execTriggerScan() {
        if (cardRoot.isPowered && !cardRoot.isScanning) {
            scanBtProc.startScan()
        }
    }

    function reqConnectDevice(mac) { connectBtProc.connectDevice(mac) }
    function reqDisconnectDevice(mac) { disconnectBtProc.disconnect(mac) }
    function reqPairDevice(mac) { pairBtProc.pairDevice(mac) }
    function reqRemoveDevice(mac) { removeBtProc.removeDevice(mac) }

    Timer {
        interval: 2000
        running: cardRoot.isPowered && (cardRoot.isHovered || cardRoot.connectedDeviceName !== "")
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!fetchBtDevicesProc.running) {
                fetchBtDevicesProc.running = true
            }
        }
    }

    Process { id: toggleBtProc; running: false; onExited: fetchBtStatusProc.running = true }
    Process {
        id: scanBtProc; running: false
        function startScan() {
            cardRoot.isScanning = true
            command = ["fish", "-c", "bluetoothctl --timeout 6 scan on"]
            running = true
        }
        onExited: {
            cardRoot.isScanning = false
            fetchBtStatusProc.running = true
        }
    }
    Process {
        id: connectBtProc; running: false
        function connectDevice(mac) {
            cardRoot.connectingMac = mac
            command = ["fish", "-c", `bluetoothctl connect '${mac}'`]
            running = true
        }
        onExited: {
            cardRoot.connectingMac = ""
            fetchBtStatusProc.running = true
        }
    }
    Process {
        id: disconnectBtProc; running: false
        function disconnect(mac) {
            command = ["fish", "-c", `bluetoothctl disconnect '${mac}'`]
            running = true
        }
        onExited: fetchBtStatusProc.running = true
    }
    // Fix 1: Use semicolons for fish compatibility during pairing
    Process {
        id: pairBtProc; running: false
        function pairDevice(mac) {
            cardRoot.connectingMac = mac
            command = ["fish", "-c", `bluetoothctl pair '${mac}'; bluetoothctl trust '${mac}'; bluetoothctl connect '${mac}'`]
            running = true
        }
        onExited: {
            cardRoot.connectingMac = ""
            fetchBtStatusProc.running = true
        }
    }

    // Fix 2: Ensure full cleanup (disconnect + untrust + remove) on forget
    Process {
        id: removeBtProc; running: false
        function removeDevice(mac) {
            command = ["fish", "-c", `bluetoothctl disconnect '${mac}'; bluetoothctl untrust '${mac}'; bluetoothctl remove '${mac}'`]
            running = true
        }
        onExited: fetchBtStatusProc.running = true
    }

    // Fix 3: In-place update with stable position appending
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

                cardRoot.connectedDeviceName = connectedNames.length > 0 ? connectedNames.join(", ") : ""

                let existingMap = {}
                for (let idx = 0; idx < btModel.count; idx++) {
                    existingMap[btModel.get(idx).mac] = idx
                }

                let freshMap = {}
                let toAppend = []

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

                for (let a = 0; a < toAppend.length; a++) {
                    btModel.append(toAppend[a])
                }

                for (let r = btModel.count - 1; r >= 0; r--) {
                    if (!freshMap[btModel.get(r).mac]) btModel.remove(r)
                }
            }
        }
    }
    Process {
        id: fetchBtStatusProc
        command: ["fish", "-c", "bluetoothctl show"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text
                if (!text || text.includes("No default controller available")) {
                    cardRoot.hasHardware = false
                    cardRoot.isPowered = false
                    cardRoot.connectedDeviceName = ""
                    btModel.clear()
                } else {
                    cardRoot.hasHardware = true
                    cardRoot.isPowered = text.includes("Powered: yes")
                    if (cardRoot.isPowered) {
                        fetchBtDevicesProc.running = true
                    } else {
                        cardRoot.connectedDeviceName = ""
                        btModel.clear()
                    }
                }
            }
        }
    }

    Component.onCompleted: fetchBtStatusProc.running = true
}