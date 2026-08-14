import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls
import ".."

Item {
    id: cardRoot
    
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.alignment: Qt.AlignTop

    implicitHeight: 64
    Layout.preferredHeight: 64
    z: panelExpanded ? 1000 : 1

    property Item controlCenterPanel: null
    property bool panelExpanded: false

    property bool hasAdapter: true
    property bool wifiPowered: false
    property bool wifiScanning: false
    property string activeSsid: ""
    property string expandedSsid: ""
    property string connectingSsid: ""
    property string disconnectingSsid: ""
    property string errorSsid: ""
    property string connectionError: ""
    property var knownNetworks: ({})
    property var wifiModel

    property bool shouldExpand: panelExpanded
    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    readonly property string displaySsid: {
        if (connectionError !== "" && errorSsid !== "") return connectionError
        if (connectingSsid !== "") return connectingSsid
        if (disconnectingSsid !== "") return "Disconnecting..."
        return activeSsid
    }

    signal togglePower(bool power)
    signal triggerScan()
    signal connectTo(string ssid, string password, bool isKnown)
    signal disconnectSsid(string ssid)
    signal forgetSsid(string ssid)

    Timer {
        id: cardScanTimeoutTimer
        interval: 1500
        repeat: false
        onTriggered: cardRoot.wifiScanning = false
    }

    property bool isTogglingPower: false

    Timer {
        id: powerToggleTimeout
        interval: 4000
        repeat: false
        onTriggered: cardRoot.isTogglingPower = false
    }

    onWifiPoweredChanged: {
        isTogglingPower = false
        powerToggleTimeout.stop()
    }

    function reqTogglePower(turnOn) {
        if (!cardRoot.hasAdapter) return
        cardRoot.isTogglingPower = true
        powerToggleTimeout.restart()
        cardRoot.togglePower(turnOn)
    }

    function reqForget(ssid) {
        if (!cardRoot.hasAdapter) return
        
        if (cardRoot.knownNetworks && cardRoot.knownNetworks[ssid] !== undefined) {
            let updated = Object.assign({}, cardRoot.knownNetworks)
            delete updated[ssid]
            cardRoot.knownNetworks = updated
        }
        
        cardRoot.connectingSsid = "" 
        cardRoot.forgetSsid(ssid)
    }

    onActiveSsidChanged: {
        if (activeSsid !== "") {
            connectingSsid = ""
        }
    }

    onErrorSsidChanged: {
        if (errorSsid !== "") {
            connectingSsid = ""
        }
    }

    onConnectionErrorChanged: {
        if (connectionError !== "") {
            connectingSsid = ""
        }
    }

    onVisibleChanged: {
        if (!visible) panelExpanded = false
    }

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
            : ((cardHover.hovered && cardRoot.hasAdapter) ? Qt.rgba(Config.bgBase.r, Config.bgBase.g, Config.bgBase.b, 0.85) : Qt.rgba(0, 0, 0, 0.25))

        opacity: cardRoot.hasAdapter ? 1.0 : 0.4
        enabled: cardRoot.hasAdapter

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

                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: Config.cornerRadius / 2
                        color: (cardRoot.wifiPowered || cardRoot.isTogglingPower) && cardRoot.hasAdapter
                            ? (iconHover.hovered ? Qt.lighter(Config.accent, 1.1) : Config.accent)
                            : (iconHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08))
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: !cardRoot.hasAdapter ? "signal_wifi_off" : ((cardRoot.wifiPowered || cardRoot.isTogglingPower) ? "wifi" : "signal_wifi_off")
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            color: (cardRoot.wifiPowered || cardRoot.isTogglingPower) && cardRoot.hasAdapter ? Config.bgBase : Config.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: cardRoot.hasAdapter ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: cardRoot.reqTogglePower(!cardRoot.wifiPowered)
                        }
                        HoverHandler { id: iconHover }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        clip: true

                        Text {
                            text: "Wifi"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: true
                            color: Config.textMain
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: !cardRoot.hasAdapter 
                                ? "No Adapter" 
                                : (cardRoot.isTogglingPower 
                                    ? "..." 
                                    : (!cardRoot.wifiPowered 
                                        ? "Off" 
                                        : (cardRoot.connectionError !== "" 
                                            ? cardRoot.connectionError 
                                            : (cardRoot.displaySsid !== "" ? cardRoot.displaySsid : "Disconnected"))))
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: cardRoot.hasAdapter && (cardRoot.isTogglingPower || cardRoot.connectionError !== "" || (cardRoot.wifiPowered && cardRoot.displaySsid !== ""))
                            color: cardRoot.hasAdapter && (cardRoot.isTogglingPower || (cardRoot.wifiPowered && (cardRoot.displaySsid !== "" || cardRoot.connectionError !== ""))) ? (cardRoot.connectionError !== "" ? "#ff6b6b" : Config.accent) : Config.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: "chevron_right"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 20
                        color: cardHover.hovered ? Config.textMain : Config.textMuted
                        opacity: cardRoot.hasAdapter ? 0.7 : 0.2
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.leftMargin: 52
                    cursorShape: cardRoot.hasAdapter ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (cardRoot.hasAdapter) cardRoot.panelExpanded = true
                    }
                }
            }
        }

        // --- 2. EXPANDED FULL CONTROL CENTER PANEL VIEW ---
        Item {
            id: expandedView
            anchors.fill: parent
            anchors.margins: 14
            visible: opacity > 0
            opacity: cardRoot.panelExpanded ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            RowLayout {
                id: expHeaderRow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 44
                spacing: 10

                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 18
                    Layout.alignment: Qt.AlignVCenter
                    color: backHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 20
                        color: Config.textMain
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cardRoot.panelExpanded = false
                    }
                    HoverHandler { id: backHover }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    Item {
                        implicitWidth: wifiExpTitleText.implicitWidth
                        implicitHeight: wifiExpTitleText.implicitHeight
                        Layout.fillWidth: true

                        Text {
                            id: wifiExpTitleText
                            text: "WIFI"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontTitle)
                            font.bold: true
                            font.italic: true
                            elide: Text.ElideRight
                        }

                        Glow {
                            anchors.fill: wifiExpTitleText
                            source: wifiExpTitleText
                            radius: 6
                            samples: 12
                            color: Config.accent
                            spread: 0.2
                            transparentBorder: true
                            visible: Config.clockShowGlow
                        }
                    }

                    Text {
                        text: !cardRoot.hasAdapter 
                            ? "No Adapter Available" 
                            : (cardRoot.isTogglingPower 
                                ? "..." 
                                : (!cardRoot.wifiPowered 
                                    ? "Wi-Fi Disabled" 
                                    : (cardRoot.connectionError !== "" 
                                        ? cardRoot.connectionError 
                                        : (cardRoot.displaySsid !== "" ? cardRoot.displaySsid : "Disconnected"))))
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        color: cardRoot.hasAdapter && (cardRoot.isTogglingPower || (cardRoot.wifiPowered && (cardRoot.displaySsid !== "" || cardRoot.connectionError !== ""))) ? (cardRoot.connectionError !== "" ? "#ff6b6b" : Config.accent) : Config.textMuted
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 18
                    visible: cardRoot.wifiPowered && cardRoot.hasAdapter
                    color: scanHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: scanIconText
                        anchors.centerIn: parent
                        text: "refresh"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 18
                        color: scanHover.hovered ? Config.textMain : Config.textMuted

                        RotationAnimator {
                            target: scanIconText
                            from: 0; to: 360; duration: 1000
                            loops: Animation.Infinite
                            running: cardRoot.wifiScanning
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!cardRoot.wifiScanning) {
                                cardRoot.wifiScanning = true
                                cardScanTimeoutTimer.restart()
                                cardRoot.triggerScan()
                            }
                        }
                    }
                    HoverHandler { id: scanHover }
                }

                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 18
                    visible: cardRoot.hasAdapter
                    color: (cardRoot.wifiPowered || cardRoot.isTogglingPower) 
                        ? (pwrHover.hovered ? Qt.lighter(Config.accent, 1.1) : Config.accent)
                        : (pwrHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: (cardRoot.wifiPowered || cardRoot.isTogglingPower) ? "wifi" : "signal_wifi_off"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 18
                        color: (cardRoot.wifiPowered || cardRoot.isTogglingPower) ? Config.bgBase : Config.textMuted
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cardRoot.reqTogglePower(!cardRoot.wifiPowered)
                    }
                    HoverHandler { id: pwrHover }
                }
            }

            Rectangle {
                id: expDividerLine
                anchors.top: expHeaderRow.bottom
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(255, 255, 255, 0.08)
            }

            Item {
                anchors.top: expDividerLine.bottom
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    visible: cardRoot.hasAdapter && cardRoot.wifiPowered && cardRoot.wifiModel && cardRoot.wifiModel.count > 0

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "NETWORKS"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            color: Config.textMuted
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: cardRoot.wifiScanning ? "Scanning..." : ((cardRoot.wifiModel ? cardRoot.wifiModel.count : 0) + " available")
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            color: cardRoot.wifiScanning ? Config.accent : Config.textMuted
                        }
                    }

                    ListView {
                        id: fullWifiListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: cardRoot.wifiModel
                        spacing: 6

                        delegate: Rectangle {
                            id: wifiDelegate
                            property bool isCurrentActive: cardRoot.activeSsid === model.ssid && model.ssid !== ""
                            property bool isExpanded: cardRoot.expandedSsid === model.ssid
                            property bool isConnecting: cardRoot.connectingSsid === model.ssid
                            property bool isDisconnecting: cardRoot.disconnectingSsid === model.ssid
                            // Cache fallback ensures disconnecting doesn't visually dump you back to the password screen
                            property bool isKnown: (model.isSaved === true) || (cardRoot.knownNetworks && cardRoot.knownNetworks[model.ssid] === true)
                            property bool hasError: cardRoot.errorSsid === model.ssid && cardRoot.connectingSsid !== model.ssid && cardRoot.activeSsid !== model.ssid

                            // Instantly wipe password and update local known networks dictionary on successful connection
                            onIsCurrentActiveChanged: {
                                if (isCurrentActive) {
                                    passInput.text = ""
                                    
                                    let updated = Object.assign({}, cardRoot.knownNetworks)
                                    updated[model.ssid] = true
                                    cardRoot.knownNetworks = updated
                                }
                            }

                            width: fullWifiListView.width
                            implicitHeight: isExpanded ? wifiItemColumn.implicitHeight + 16 : 48
                            radius: Config.cornerRadius / 2
                            clip: true

                            color: hasError 
                                ? Qt.rgba(255, 80, 80, 0.15) 
                                : (isCurrentActive 
                                    ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.15) 
                                    : (wifiItemHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2)))

                            border.width: (isCurrentActive || hasError) ? 1 : 0
                            border.color: hasError ? "#ff5555" : (isCurrentActive ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.6) : "transparent")

                            Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            ColumnLayout {
                                id: wifiItemColumn
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.topMargin: 8
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
                                            color: hasError ? Qt.rgba(255, 80, 80, 0.2) : (isCurrentActive ? Config.accent : Qt.rgba(255, 255, 255, 0.06))

                                            Text {
                                                anchors.centerIn: parent
                                                text: model.isSecure ? "wifi_lock" : "wifi"
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 16
                                                color: hasError ? "#ff5555" : (isCurrentActive ? Config.bgBase : Config.textMuted)
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 1

                                            Text {
                                                text: model.ssid !== "" ? model.ssid : "Hidden Network"
                                                color: hasError ? "#ff6b6b" : (isCurrentActive ? Config.accent : Config.textMain)
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontCaption)
                                                font.bold: isCurrentActive || hasError
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: hasError
                                                    ? cardRoot.connectionError
                                                    : (isConnecting 
                                                        ? "Connecting..." 
                                                        : (isDisconnecting 
                                                            ? "Disconnecting..." 
                                                            : (isCurrentActive 
                                                                ? "Connected" 
                                                                : (isKnown ? "Saved Network" : (model.isSecure ? "Secured" : "Open Network")))))
                                                color: hasError ? "#ff6b6b" : (isCurrentActive ? Config.accent : Config.textMuted)
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontMicro)
                                                font.bold: hasError
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

                                    TapHandler {
                                        onTapped: (point) => {
                                            if (cardRoot.expandedSsid !== model.ssid) {
                                                cardRoot.expandedSsid = model.ssid
                                            } else {
                                                cardRoot.expandedSsid = ""
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    id: wifiControlsLayout
                                    visible: isExpanded
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        visible: hasError && cardRoot.connectionError !== ""
                                        text: cardRoot.connectionError
                                        color: "#ff6b6b"
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontMicro)
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    RowLayout {
                                        visible: !isCurrentActive && model.isSecure && (!isKnown || hasError)
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 32
                                            radius: Config.cornerRadius / 2
                                            color: Qt.rgba(0, 0, 0, 0.4)
                                            border.width: passInput.activeFocus ? 2 : 1
                                            border.color: passInput.activeFocus ? Config.accent : (hasError ? "#ff5555" : Qt.rgba(255, 255, 255, 0.12))

                                            TextInput {
                                                id: passInput
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: Config.textMain
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontMicro)
                                                echoMode: TextInput.Password
                                                selectByMouse: true

                                                Text {
                                                    text: "Enter Wi-Fi password..."
                                                    color: Config.textMuted
                                                    font.family: Config.sysFont
                                                    font.pixelSize: Config.size(Config.fontMicro)
                                                    visible: passInput.text === "" && !passInput.activeFocus
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                onAccepted: {
                                                    if (!isConnecting && !isDisconnecting && cardRoot.hasAdapter) {
                                                        if (model.isSecure && passInput.text.trim() === "") {
                                                            cardRoot.errorSsid = model.ssid
                                                            cardRoot.connectionError = "Password Required"
                                                            return
                                                        }
                                                        
                                                        cardRoot.connectingSsid = model.ssid
                                                        cardRoot.connectTo(model.ssid, passInput.text, false)
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            implicitWidth: 70
                                            implicitHeight: 32
                                            radius: Config.cornerRadius / 2
                                            color: joinHover.hovered ? Qt.lighter(Config.accent, 1.1) : Config.accent
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: isConnecting ? "..." : "JOIN"
                                                font.family: Config.sysFont
                                                font.bold: true
                                                font.pixelSize: Config.size(Config.fontMicro)
                                                color: Config.bgBase
                                            }

                                            TapHandler {
                                                enabled: !isConnecting && !isDisconnecting && cardRoot.hasAdapter
                                                onTapped: {
                                                    if (model.isSecure && passInput.text.trim() === "") {
                                                        cardRoot.errorSsid = model.ssid
                                                        cardRoot.connectionError = "Password Required"
                                                        return
                                                    }
                                                    
                                                    cardRoot.connectingSsid = model.ssid
                                                    cardRoot.connectTo(model.ssid, passInput.text, false)
                                                }
                                            }
                                            HoverHandler { id: joinHover; cursorShape: Qt.PointingHandCursor }
                                        }
                                    }

                                    RowLayout {
                                        visible: isCurrentActive || (isKnown && !hasError) || !model.isSecure
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Rectangle {
                                            visible: isCurrentActive
                                            Layout.fillWidth: true
                                            implicitHeight: 32
                                            radius: Config.cornerRadius / 2
                                            color: discHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: isDisconnecting ? "DISCONNECTING..." : "DISCONNECT"
                                                font.family: Config.sysFont
                                                font.bold: true
                                                font.pixelSize: Config.size(Config.fontMicro)
                                                color: discHover.hovered ? Config.accent : Config.textMain
                                            }

                                            TapHandler {
                                                enabled: !isDisconnecting && !isConnecting && cardRoot.hasAdapter
                                                onTapped: cardRoot.disconnectSsid(model.ssid)
                                            }
                                            HoverHandler { id: discHover; cursorShape: Qt.PointingHandCursor }
                                        }

                                        Rectangle {
                                            visible: !isCurrentActive && (isKnown && !hasError || !model.isSecure)
                                            Layout.fillWidth: true
                                            implicitHeight: 32
                                            radius: Config.cornerRadius / 2
                                            color: connHover.hovered ? Qt.lighter(Config.accent, 1.1) : Config.accent
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: isConnecting ? "CONNECTING..." : "CONNECT"
                                                font.family: Config.sysFont
                                                font.bold: true
                                                font.pixelSize: Config.size(Config.fontMicro)
                                                color: Config.bgBase
                                            }

                                            TapHandler {
                                                enabled: !isConnecting && !isDisconnecting && cardRoot.hasAdapter
                                                onTapped: {
                                                    cardRoot.connectingSsid = model.ssid
                                                    cardRoot.connectTo(model.ssid, "", true)
                                                }
                                            }
                                            HoverHandler { id: connHover; cursorShape: Qt.PointingHandCursor }
                                        }

                                        Rectangle {
                                            visible: isKnown || isCurrentActive 
                                            Layout.fillWidth: true
                                            implicitHeight: 32
                                            radius: Config.cornerRadius / 2
                                            color: forgetWifiHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.06)
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "FORGET"
                                                font.family: Config.sysFont
                                                font.bold: true
                                                font.pixelSize: Config.size(Config.fontMicro)
                                                color: forgetWifiHover.hovered ? Config.accent : Config.textMuted
                                            }

                                            TapHandler {
                                                enabled: !isConnecting && !isDisconnecting && cardRoot.hasAdapter
                                                onTapped: cardRoot.reqForget(model.ssid)
                                            }
                                            HoverHandler { id: forgetWifiHover; cursorShape: Qt.PointingHandCursor }
                                        }
                                    }
                                }
                            }
                            HoverHandler { id: wifiItemHover }
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: cardRoot.hasAdapter && cardRoot.wifiPowered && (!cardRoot.wifiModel || cardRoot.wifiModel.count === 0)

                    Text {
                        text: "signal_wifi_off"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 48
                        color: Config.accent
                        opacity: 0.5
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "No Wi-Fi Networks Found"
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                        color: Config.textMain
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Ensure Wi-Fi is enabled and nearby networks are in range."
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
                            text: cardRoot.wifiScanning ? "Scanning..." : "Scan for Networks"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            color: Config.bgBase
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!cardRoot.wifiScanning) {
                                    cardRoot.wifiScanning = true
                                    cardScanTimeoutTimer.restart()
                                    cardRoot.triggerScan()
                                }
                            }
                        }
                        HoverHandler { id: scanEmptyHover }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: cardRoot.hasAdapter && !cardRoot.wifiPowered

                    Text {
                        text: "signal_wifi_off"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 48
                        color: Config.textMuted
                        opacity: 0.5
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Wi-Fi is Disabled"
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                        color: Config.textMain
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Turn on Wi-Fi to scan and connect to wireless networks."
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
                            text: "Turn On Wi-Fi"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            color: Config.bgBase
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cardRoot.reqTogglePower(true)
                        }
                        HoverHandler { id: pwrOffHover }
                    }
                }
            }
        }
    }
}