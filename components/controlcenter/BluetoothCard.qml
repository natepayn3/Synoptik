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

    // Lock structural footprint to 64px so lower cards in ControlCenter stay static
    implicitHeight: 64
    Layout.preferredHeight: 64
    z: panelExpanded ? 1000 : 1

    property Item controlCenterPanel: null
    property bool panelExpanded: false

    property bool isPowered: false
    property bool isScanning: false
    property bool hasHardware: true
    property string expandedMac: ""
    property string connectingMac: ""
    property string connectedDeviceName: ""

    property bool shouldExpand: panelExpanded

    signal togglePower(bool power)
    signal triggerScan()

    ListModel { id: btModel }

    onHasHardwareChanged: {
        if (hasHardware) {
            fetchBtStatusProc.running = false
            fetchBtStatusProc.running = true
        }
    }

    onVisibleChanged: {
        if (!visible) panelExpanded = false
    }

    onPanelExpandedChanged: {
        if (panelExpanded && hasHardware && isPowered) {
            fetchBtDevicesProc.running = false
            fetchBtDevicesProc.running = true
        }
    }

    // Reactive collapsed position calculations spanning parent hierarchy up to controlCenterPanel (root)
    readonly property real collapsedX: {
        let p0 = cardRoot
        let p1 = p0 ? p0.parent : null
        let p2 = p1 ? p1.parent : null
        let p3 = p2 ? p2.parent : null
        let p4 = p3 ? p3.parent : null
        
        let x0 = p0 ? p0.x : 0
        let x1 = p1 ? p1.x : 0
        let x2 = p2 ? p2.x : 0
        let x3 = p3 ? p3.x : 0
        let x4 = p4 ? p4.x : 0
        
        return x0 + x1 + x2 + x3 + x4
    }

    readonly property real collapsedY: {
        let p0 = cardRoot
        let p1 = p0 ? p0.parent : null
        let p2 = p1 ? p1.parent : null
        let p3 = p2 ? p2.parent : null
        let p4 = p3 ? p3.parent : null
        
        let y0 = p0 ? p0.y : 0
        let y1 = p1 ? p1.y : 0
        let y2 = p2 ? p2.y : 0
        let y3 = p3 ? p3.y : 0
        let y4 = p4 ? p4.y : 0
        
        return y0 + y1 + y2 + y3 + y4
    }

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    // Floating overlay container that expands to fill the entire ControlCenter panel area
    Rectangle {
        id: visualBackground
        parent: controlCenterPanel ? controlCenterPanel : cardRoot.parent.parent.parent
        z: cardRoot.panelExpanded ? 1000 : 100
        clip: true
        
        x: cardRoot.panelExpanded ? cardRoot.cardMargin : cardRoot.collapsedX
        y: cardRoot.panelExpanded ? cardRoot.cardMargin : cardRoot.collapsedY
        width: cardRoot.panelExpanded ? (controlCenterPanel ? (controlCenterPanel.width - (cardRoot.cardMargin * 2)) : 400) : cardRoot.width
        height: cardRoot.panelExpanded ? (controlCenterPanel ? (controlCenterPanel.height - (cardRoot.cardMargin * 2)) : 500) : 64
        
        radius: Config.cornerRadius
        
        color: cardRoot.panelExpanded
            ? Qt.rgba(Config.bgBase.r, Config.bgBase.g, Config.bgBase.b, 1.0)
            : ((cardHover.hovered && cardRoot.hasHardware) ? Qt.rgba(Config.bgBase.r, Config.bgBase.g, Config.bgBase.b, 0.85) : Qt.rgba(0, 0, 0, 0.25))

        opacity: cardRoot.hasHardware ? 1.0 : 0.4
        enabled: cardRoot.hasHardware

        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on color { ColorAnimation { duration: 150 } }

        HoverHandler {
            id: cardHover
            enabled: !cardRoot.panelExpanded
        }

        // Shield overlay: Eat all click and mouse events when panel is expanded so they never leak to items underneath
        MouseArea {
            anchors.fill: parent
            enabled: cardRoot.panelExpanded
            preventStealing: true
            onClicked: {}
        }

        // --- 1. COLLAPSED CARD HEADER VIEW ---
        Item {
            id: collapsedView
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 64
            visible: opacity > 0
            opacity: cardRoot.panelExpanded ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Item {
                anchors.fill: parent
                anchors.margins: 10

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    // Bluetooth Icon Toggle Button (Clicking ONLY icon toggles power)
                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: Config.cornerRadius / 2
                        color: cardRoot.isPowered && cardRoot.hasHardware 
                            ? (iconHover.hovered ? Qt.lighter(Config.accent, 1.1) : Config.accent)
                            : (iconHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08))
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: !cardRoot.hasHardware ? "bluetooth_disabled" : (cardRoot.isPowered ? "bluetooth" : "bluetooth_disabled")
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 24
                            color: cardRoot.isPowered && cardRoot.hasHardware ? Config.bgBase : Config.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: cardRoot.hasHardware ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (cardRoot.hasHardware) cardRoot.execTogglePower(!cardRoot.isPowered)
                            }
                        }
                        HoverHandler { id: iconHover }
                    }

                    // Bluetooth Label & Subtitle
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        clip: true

                        Text {
                            text: "Bluetooth"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: true
                            color: Config.textMain
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: !cardRoot.hasHardware ? "No Controller" : (!cardRoot.isPowered ? "Off" : (cardRoot.connectedDeviceName !== "" ? cardRoot.connectedDeviceName : "On"))
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: cardRoot.connectedDeviceName !== "" && cardRoot.hasHardware
                            color: cardRoot.connectedDeviceName !== "" && cardRoot.hasHardware ? Config.accent : Config.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Chevron visual indicator for panel expansion
                    Text {
                        text: "chevron_right"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 22
                        color: cardHover.hovered ? Config.textMain : Config.textMuted
                        opacity: cardRoot.hasHardware ? 0.7 : 0.2
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                // Click handler for the rest of the card (expands to fill panel)
                MouseArea {
                    anchors.fill: parent
                    anchors.leftMargin: 52 // Exclude icon button
                    cursorShape: cardRoot.hasHardware ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (cardRoot.hasHardware) cardRoot.panelExpanded = true
                    }
                }
            }
        }

        // --- 2. EXPANDED FULL CONTROL CENTER PANEL VIEW ---
        ColumnLayout {
            id: expandedView
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            visible: opacity > 0
            opacity: cardRoot.panelExpanded ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // Panel Header Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Back Button
                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    color: backHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 22
                        color: Config.textMain
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cardRoot.panelExpanded = false
                    }
                    HoverHandler { id: backHover }
                }

                // Title Section
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "BLUETOOTH"
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontTitle)
                        font.bold: true
                        color: Config.textMain
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: !cardRoot.hasHardware ? "No Controller Available" : (cardRoot.connectedDeviceName !== "" ? cardRoot.connectedDeviceName : (cardRoot.isPowered ? "Bluetooth Enabled" : "Bluetooth Disabled"))
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        color: cardRoot.connectedDeviceName !== "" ? Config.accent : Config.textMuted
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Refresh / Scan Button
                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    visible: cardRoot.isPowered && cardRoot.hasHardware
                    color: scanHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: scanIconText
                        anchors.centerIn: parent
                        text: "refresh"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 22
                        color: scanHover.hovered ? Config.textMain : Config.textMuted

                        RotationAnimator {
                            target: scanIconText
                            from: 0; to: 360; duration: 1000
                            loops: Animation.Infinite
                            running: cardRoot.isScanning
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cardRoot.execTriggerScan()
                    }
                    HoverHandler { id: scanHover }
                }

                // Power Toggle Switch Button
                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    visible: cardRoot.hasHardware
                    color: cardRoot.isPowered 
                        ? (pwrHover.hovered ? Qt.lighter(Config.accent, 1.1) : Config.accent)
                        : (pwrHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: cardRoot.isPowered ? "bluetooth" : "bluetooth_disabled"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 22
                        color: cardRoot.isPowered ? Config.bgBase : Config.textMuted
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cardRoot.execTogglePower(!cardRoot.isPowered)
                    }
                    HoverHandler { id: pwrHover }
                }
            }

            // Separator Divider Line
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(255, 255, 255, 0.08)
            }

            // Devices Section Header
            RowLayout {
                Layout.fillWidth: true
                visible: cardRoot.hasHardware && cardRoot.isPowered

                Text {
                    text: "DEVICES"
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                    color: Config.textMuted
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: cardRoot.isScanning ? "Scanning..." : (btModel.count + " available")
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    color: cardRoot.isScanning ? Config.accent : Config.textMuted
                }
            }

            // Full Device List View
            ListView {
                id: fullBtListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: btModel
                spacing: 6
                visible: cardRoot.hasHardware && cardRoot.isPowered && btModel.count > 0

                delegate: Rectangle {
                    id: devDelegate
                    property bool isExpanded: cardRoot.expandedMac === model.mac
                    property bool isConnecting: cardRoot.connectingMac === model.mac

                    width: fullBtListView.width
                    implicitHeight: devDelegateLayout.implicitHeight + 20
                    radius: Config.cornerRadius / 2
                    clip: true

                    color: model.connected 
                        ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.15) 
                        : (devHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2))

                    border.width: model.connected ? 2 : 0
                    border.color: model.connected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.6) : "transparent"

                    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        id: devDelegateLayout
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 10
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 32

                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                Rectangle {
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    radius: 14
                                    Layout.alignment: Qt.AlignVCenter
                                    color: model.connected ? Config.accent : Qt.rgba(255, 255, 255, 0.06)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "bluetooth"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 16
                                        color: model.connected ? Config.bgBase : Config.textMuted
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 1

                                    Text {
                                        text: model.name
                                        color: model.connected ? Config.accent : Config.textMain
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontCaption)
                                        font.bold: model.connected
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: isConnecting ? "Connecting..." : (model.connected ? "Connected" : (model.paired ? "Paired" : "Available"))
                                        color: model.connected ? Config.accent : Config.textMuted
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontMicro)
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                Text {
                                    text: isExpanded ? "expand_less" : "expand_more"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 18
                                    color: Config.textMuted
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cardRoot.expandedMac = (cardRoot.expandedMac === model.mac ? "" : model.mac)
                            }
                        }

                        // Expanded Action Row (Smooth Bidirectional Height & Opacity Animation)
                        Item {
                            id: actionRowContainer
                            Layout.fillWidth: true
                            implicitHeight: isExpanded ? actionLayout.implicitHeight : 0
                            visible: implicitHeight > 0 || opacity > 0
                            opacity: isExpanded ? 1.0 : 0.0
                            clip: true

                            Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            RowLayout {
                                id: actionLayout
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                spacing: 8

                                // Connect / Disconnect / Pair Action
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 32
                                    radius: Config.cornerRadius / 2
                                    color: connBtnMouse.containsMouse 
                                        ? Qt.lighter(model.connected ? Qt.rgba(255,255,255,0.15) : Config.accent, 1.1) 
                                        : (model.connected ? Qt.rgba(255, 255, 255, 0.08) : Config.accent)
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: isConnecting ? "CONNECTING..." : (model.connected ? "DISCONNECT" : (model.paired ? "CONNECT" : "PAIR & CONNECT"))
                                        color: model.connected ? Config.textMain : Config.bgBase
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontMicro)
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: connBtnMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: {
                                            if (isConnecting || !cardRoot.hasHardware) return
                                            if (model.connected) cardRoot.reqDisconnectDevice(model.mac)
                                            else if (model.paired) cardRoot.reqConnectDevice(model.mac)
                                            else cardRoot.reqPairDevice(model.mac)
                                        }
                                    }
                                }

                                // Forget Action
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 32
                                    radius: Config.cornerRadius / 2
                                    visible: model.paired || model.connected
                                    color: forgetBtnMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.06)
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "FORGET"
                                        color: forgetBtnMouse.containsMouse ? Config.accent : Config.textMuted
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontMicro)
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: forgetBtnMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: {
                                            if (!cardRoot.hasHardware) return
                                            cardRoot.reqRemoveDevice(model.mac)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    HoverHandler { id: devHover }
                }
            }

            // Empty State View
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignCenter
                spacing: 12
                visible: cardRoot.hasHardware && cardRoot.isPowered && btModel.count === 0

                Text {
                    text: "bluetooth_searching"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 48
                    color: Config.accent
                    opacity: 0.5
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "No Bluetooth Devices Found"
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.bold: true
                    color: Config.textMain
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Ensure your Bluetooth device is turned on and in pairing mode."
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    color: Config.textMuted
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.maximumWidth: 260
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    implicitWidth: 140
                    implicitHeight: 34
                    radius: 17
                    color: scanEmptyHover.hovered ? Qt.lighter(Config.accent, 1.1) : Config.accent
                    Layout.alignment: Qt.AlignHCenter

                    Text {
                        anchors.centerIn: parent
                        text: cardRoot.isScanning ? "Scanning..." : "Scan for Devices"
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        color: Config.bgBase
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cardRoot.execTriggerScan()
                    }
                    HoverHandler { id: scanEmptyHover }
                }
            }

            // Powered Off State View
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignCenter
                spacing: 12
                visible: cardRoot.hasHardware && !cardRoot.isPowered

                Text {
                    text: "bluetooth_disabled"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 48
                    color: Config.textMuted
                    opacity: 0.5
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Bluetooth is Disabled"
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.bold: true
                    color: Config.textMain
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Turn on Bluetooth to discover and connect to nearby devices."
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    color: Config.textMuted
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.maximumWidth: 260
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    implicitWidth: 140
                    implicitHeight: 34
                    radius: 17
                    color: pwrOffHover.hovered ? Qt.lighter(Config.accent, 1.1) : Config.accent
                    Layout.alignment: Qt.AlignHCenter

                    Text {
                        anchors.centerIn: parent
                        text: "Turn On Bluetooth"
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        color: Config.bgBase
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cardRoot.execTogglePower(true)
                    }
                    HoverHandler { id: pwrOffHover }
                }
            }
        }
    }

    function execTogglePower(turnOn) {
        if (!cardRoot.hasHardware) return
        cardRoot.isPowered = turnOn // Optimistic mutation
        toggleBtProc.command = ["fish", "-c", `bluetoothctl power ${turnOn ? "on" : "off"}`]
        toggleBtProc.running = true
    }

    function execTriggerScan() {
        if (cardRoot.hasHardware && cardRoot.isPowered && !cardRoot.isScanning) {
            scanBtProc.startScan()
        }
    }

    function reqConnectDevice(mac) { if (cardRoot.hasHardware) connectBtProc.connectDevice(mac) }
    function reqDisconnectDevice(mac) { if (cardRoot.hasHardware) disconnectBtProc.disconnect(mac) }
    function reqPairDevice(mac) { if (cardRoot.hasHardware) pairBtProc.pairDevice(mac) }
    function reqRemoveDevice(mac) { if (cardRoot.hasHardware) removeBtProc.removeDevice(mac) }

    Timer {
        interval: 2000
        running: cardRoot.visible && cardRoot.hasHardware && cardRoot.isPowered && (cardHover.hovered || cardRoot.connectedDeviceName !== "" || cardRoot.panelExpanded)
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!fetchBtDevicesProc.running && !toggleBtProc.running) {
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

    Process {
        id: removeBtProc; running: false
        function removeDevice(mac) {
            command = ["fish", "-c", `bluetoothctl disconnect '${mac}'; bluetoothctl untrust '${mac}'; bluetoothctl remove '${mac}'`]
            running = true
        }
        onExited: fetchBtStatusProc.running = true
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
                if (toggleBtProc.running) return

                let text = this.text
                if (!cardRoot.hasHardware || !text || text.includes("No default controller available")) {
                    cardRoot.isPowered = false
                    cardRoot.connectedDeviceName = ""
                    btModel.clear()
                    return
                }

                if (text.includes("Powered: yes")) {
                    cardRoot.isPowered = true
                    fetchBtDevicesProc.running = true
                } else if (text.includes("Powered: no")) {
                    cardRoot.isPowered = false
                    cardRoot.connectedDeviceName = ""
                    btModel.clear()
                }
            }
        }
    }

    Component.onCompleted: fetchBtStatusProc.running = true
}