import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."

Item {
    id: cardRoot
    
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.alignment: Qt.AlignTop

    // Lock structural footprint to 64px so lower cards in ControlCenter stay static
    implicitHeight: 64
    Layout.preferredHeight: 64
    z: shouldExpand ? 100 : 1

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

    // Sticky expansion: Stay open on hover OR while a specific network row is expanded
    property bool shouldExpand: hasAdapter && (cardHover.hovered || expandedSsid !== "") && wifiPowered && wifiModel && wifiModel.count > 0

    signal togglePower(bool power)
    signal triggerScan()
    signal connectTo(string ssid, string password, bool isKnown)
    signal disconnectSsid(string ssid)
    signal forgetSsid(string ssid)

    Timer {
        id: cardScanTimeoutTimer
        interval: 3500
        repeat: false
        onTriggered: cardRoot.wifiScanning = false
    }

    // Floating overlay that reparents to the main ControlCenter layout tree
    Rectangle {
        id: visualBackground
        parent: cardRoot.parent.parent.parent
        z: 100
        
        x: cardRoot.parent.parent.x + cardRoot.parent.x + cardRoot.x
        y: cardRoot.parent.parent.y + cardRoot.parent.y + cardRoot.y
        width: cardRoot.width
        
        height: cardRoot.shouldExpand ? (64 + 10 + wifiListView.targetHeight) : 64
        
        radius: Config.cornerRadius
        
        color: cardRoot.shouldExpand || (cardHover.hovered && cardRoot.hasAdapter) 
            ? Qt.rgba(Config.bgBase.r, Config.bgBase.g, Config.bgBase.b, 1.0) 
            : Qt.rgba(0, 0, 0, 0.25)

        // Dim container bounds when adapter is missing
        opacity: cardRoot.hasAdapter ? 1.0 : 0.4
        enabled: cardRoot.hasAdapter

        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }

        // HoverHandler spans the ENTIRE reparented floating container bounds
        HoverHandler { id: cardHover }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header Row (Fixed 64px)
            Item {
                id: headerContainer
                Layout.fillWidth: true
                implicitHeight: 64

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
                            color: cardRoot.wifiPowered && cardRoot.hasAdapter ? Config.accent : Qt.rgba(255, 255, 255, 0.08)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: !cardRoot.hasAdapter ? "signal_wifi_off" : (cardRoot.wifiPowered ? "wifi" : "signal_wifi_off")
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 22
                                color: cardRoot.wifiPowered && cardRoot.hasAdapter ? Config.bgBase : Config.textMuted
                            }
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
                                text: !cardRoot.hasAdapter ? "No Adapter" : (!cardRoot.wifiPowered ? "Off" : (cardRoot.activeSsid !== "" ? cardRoot.activeSsid : "Disconnected"))
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                color: cardRoot.activeSsid !== "" && cardRoot.hasAdapter ? Config.accent : Config.textMuted
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Item {
                            implicitWidth: 24
                            implicitHeight: 24
                            visible: cardRoot.wifiPowered && cardRoot.hasAdapter

                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: wifiScanHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Text {
                                id: wifiScanIcon
                                anchors.centerIn: parent
                                text: "refresh"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                                color: wifiScanHover.hovered ? Config.textMain : Config.textMuted

                                NumberAnimation on rotation {
                                    from: 0; to: 360; duration: 1000
                                    loops: Animation.Infinite
                                    running: cardRoot.wifiScanning
                                }
                            }

                            TapHandler {
                                enabled: cardRoot.hasAdapter && cardRoot.wifiPowered && !cardRoot.wifiScanning
                                onTapped: {
                                    cardRoot.wifiScanning = true
                                    cardScanTimeoutTimer.restart()
                                    cardRoot.triggerScan()
                                }
                            }
                            HoverHandler { id: wifiScanHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }

                    // Power Toggle Tap Target
                    Item {
                        anchors.fill: parent
                        anchors.rightMargin: 32
                        
                        TapHandler {
                            enabled: cardRoot.hasAdapter
                            onTapped: cardRoot.togglePower(!cardRoot.wifiPowered)
                        }
                        HoverHandler { cursorShape: cardRoot.hasAdapter ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    }
                }
            }

            // Expanded WiFi List View
            ListView {
                id: wifiListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.bottomMargin: 10
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                
                clip: true
                model: cardRoot.wifiModel
                spacing: 6
                
                property real targetHeight: Math.min(contentHeight, 260)

                opacity: cardRoot.shouldExpand ? 1.0 : 0.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                delegate: Rectangle {
                    id: wifiItemDelegate
                    property bool isExpanded: cardRoot.expandedSsid === model.ssid
                    property bool isKnown: model.isSaved !== undefined ? model.isSaved : (cardRoot.knownNetworks[model.ssid] === true)
                    property bool isConnecting: cardRoot.connectingSsid === model.ssid
                    property bool isDisconnecting: cardRoot.disconnectingSsid === model.ssid
                    property bool hasError: cardRoot.errorSsid === model.ssid

                    width: wifiListView.width
                    implicitHeight: isExpanded ? (hasError ? 96 : 76) : 36
                    radius: Config.cornerRadius / 2.5
                    clip: true

                    color: hasError 
                        ? Qt.rgba(255, 80, 80, 0.15) 
                        : (model.connected ? Qt.rgba(255, 255, 255, 0.12) : (wifiItemHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.15)))
                    border.color: hasError ? "#ff5555" : "transparent"
                    border.width: hasError ? 1 : 0

                    Behavior on implicitHeight { NumberAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        id: delegateLayout
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: model.ssid
                                color: model.connected ? Config.accent : Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: model.connected
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: model.isSecure ? "lock" : "wifi"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 12
                                color: model.connected ? Config.accent : Config.textMuted
                            }
                        }

                        ColumnLayout {
                            visible: isExpanded
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                visible: hasError
                                text: cardRoot.connectionError
                                color: "#ff6b6b"
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: true
                            }

                            // Password Panel (Unsaved & Secure)
                            RowLayout {
                                visible: !model.connected && model.isSecure && !isKnown
                                Layout.fillWidth: true
                                spacing: 4

                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 26; radius: Config.cornerRadius / 2
                                    color: Qt.rgba(0, 0, 0, 0.4)
                                    border.color: passInput.activeFocus ? Config.accent : (hasError ? "#ff5555" : "transparent")
                                    border.width: 1

                                    TextInput {
                                        id: passInput
                                        anchors.fill: parent; anchors.margins: 4
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: Config.textMain; font.family: Config.sysFont; font.pixelSize: 10
                                        echoMode: TextInput.Password
                                        enabled: !isConnecting && !isDisconnecting
                                        selectByMouse: true
                                        onAccepted: if (!isConnecting && cardRoot.hasAdapter) cardRoot.connectTo(model.ssid, passInput.text, false)
                                        onTextChanged: {
                                            if (hasError) {
                                                cardRoot.errorSsid = ""
                                                cardRoot.connectionError = ""
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    implicitWidth: 60; implicitHeight: 26; radius: Config.cornerRadius / 2
                                    color: joinNewHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Config.accent
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: isConnecting ? "..." : "JOIN"
                                        font.family: Config.sysFont; font.bold: true; font.pixelSize: Config.size(Config.fontMicro)
                                        color: joinNewHover.hovered ? Config.accent : Config.bgBase
                                    }

                                    TapHandler {
                                        enabled: !isConnecting && !isDisconnecting && cardRoot.hasAdapter
                                        onTapped: cardRoot.connectTo(model.ssid, passInput.text, false)
                                    }
                                    HoverHandler { id: joinNewHover; cursorShape: Qt.PointingHandCursor }
                                }
                            }

                            // Controls Panel (Connected, Saved, or Unsecured)
                            RowLayout {
                                visible: model.connected || isKnown || !model.isSecure
                                Layout.fillWidth: true
                                spacing: 6

                                // Disconnect Button
                                Rectangle {
                                    visible: model.connected
                                    Layout.fillWidth: true; implicitHeight: 26; radius: Config.cornerRadius / 2
                                    color: discHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: isDisconnecting ? "..." : "OFF"
                                        font.family: Config.sysFont; font.bold: true; font.pixelSize: Config.size(Config.fontMicro)
                                        color: discHover.hovered ? Config.accent : Config.textMain
                                    }
                                    TapHandler {
                                        enabled: !isDisconnecting && !isConnecting && cardRoot.hasAdapter
                                        onTapped: cardRoot.disconnectSsid(model.ssid)
                                    }
                                    HoverHandler { id: discHover; cursorShape: Qt.PointingHandCursor }
                                }

                                // Connect Button (Unconnected Saved or Open)
                                Rectangle {
                                    visible: !model.connected && (isKnown || !model.isSecure)
                                    Layout.fillWidth: true; implicitHeight: 26; radius: Config.cornerRadius / 2
                                    color: connHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Config.accent
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: isConnecting ? "..." : "CONNECT"
                                        font.family: Config.sysFont; font.bold: true; font.pixelSize: Config.size(Config.fontMicro)
                                        color: connHover.hovered ? Config.accent : Config.bgBase
                                    }
                                    TapHandler {
                                        enabled: !isConnecting && !isDisconnecting && cardRoot.hasAdapter
                                        onTapped: cardRoot.connectTo(model.ssid, "", isKnown)
                                    }
                                    HoverHandler { id: connHover; cursorShape: Qt.PointingHandCursor }
                                }

                                // Forget Button (Saved networks)
                                Rectangle {
                                    visible: isKnown
                                    Layout.fillWidth: true; implicitHeight: 26; radius: Config.cornerRadius / 2
                                    color: forgetWifiHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "FORGET"
                                        font.family: Config.sysFont; font.bold: true; font.pixelSize: Config.size(Config.fontMicro)
                                        color: forgetWifiHover.hovered ? Config.accent : Config.textMuted
                                    }
                                    TapHandler {
                                        enabled: !isConnecting && !isDisconnecting && cardRoot.hasAdapter
                                        onTapped: cardRoot.forgetSsid(model.ssid)
                                    }
                                    HoverHandler { id: forgetWifiHover; cursorShape: Qt.PointingHandCursor }
                                }
                            }
                        }
                    }

                    TapHandler {
                        onTapped: cardRoot.expandedSsid = (cardRoot.expandedSsid === model.ssid ? "" : model.ssid)
                    }
                    HoverHandler { id: wifiItemHover; cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }
}