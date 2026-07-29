import QtQuick
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
    z: shouldExpand ? 10 : 1

    property bool isHovered: cardHover.hovered
    property bool wifiPowered: false
    property bool wifiScanning: false
    property string activeSsid: ""
    property string expandedSsid: ""
    property string connectingSsid: ""
    property var knownNetworks: ({})
    property var wifiModel

    property bool shouldExpand: isHovered && wifiPowered && wifiModel && wifiModel.count > 0

    signal togglePower(bool power)
    signal triggerScan()
    signal connectTo(string ssid, string password, bool isKnown)
    signal disconnectSsid(string ssid)
    signal forgetSsid(string ssid)

    // Keeps rotation animation alive while NetworkManager scans background channels
    Timer {
        id: cardScanTimeoutTimer
        interval: 3500
        repeat: false
        onTriggered: cardRoot.wifiScanning = false
    }

    Rectangle {
        id: visualBackground
        parent: cardRoot.parent.parent.parent 
        z: 100
        
        x: cardRoot.parent.parent.x + cardRoot.parent.x + cardRoot.x
        y: cardRoot.parent.parent.y + cardRoot.parent.y + cardRoot.y
        width: cardRoot.width
        
        height: cardRoot.shouldExpand ? (64 + 10 + wifiListView.targetHeight) : 64
        
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
                    onTapped: cardRoot.togglePower(!cardRoot.wifiPowered)
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: Config.cornerRadius / 2
                        color: cardRoot.wifiPowered ? Config.accent : Qt.rgba(255, 255, 255, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: cardRoot.wifiPowered ? "wifi" : "signal_wifi_off"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            color: cardRoot.wifiPowered ? Config.bgBase : Config.textMuted
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
                            text: !cardRoot.wifiPowered ? "Off" : (cardRoot.activeSsid !== "" ? cardRoot.activeSsid : "Disconnected")
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            color: cardRoot.activeSsid !== "" ? Config.accent : Config.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Item {
                        implicitWidth: 24
                        implicitHeight: 24
                        visible: cardRoot.wifiPowered

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
                            gesturePolicy: TapHandler.WithinBounds
                            onTapped: {
                                if (cardRoot.wifiPowered && !cardRoot.wifiScanning) {
                                    cardRoot.wifiScanning = true
                                    cardScanTimeoutTimer.restart()
                                    cardRoot.triggerScan()
                                }
                            }
                        }
                        HoverHandler { id: wifiScanHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }

        ListView {
            id: wifiListView
            anchors.top: headerContainer.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            
            clip: true
            model: cardRoot.wifiModel
            spacing: 6
            
            property real targetHeight: Math.min(contentHeight, 220)

            opacity: cardRoot.shouldExpand ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            delegate: Rectangle {
                id: wifiItemDelegate
                property bool isExpanded: cardRoot.expandedSsid === model.ssid
                property bool isKnown: cardRoot.knownNetworks[model.ssid] === true
                property bool isConnecting: cardRoot.connectingSsid === model.ssid

                width: wifiListView.width
                implicitHeight: isExpanded ? (expandedWifiContent.implicitHeight + 42) : 36
                radius: Config.cornerRadius / 2.5
                color: model.connected ? Qt.rgba(255, 255, 255, 0.12) : (wifiItemHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.25))
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
                            spacing: 4

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

                        TapHandler {
                            gesturePolicy: TapHandler.WithinBounds
                            onTapped: cardRoot.expandedSsid = (cardRoot.expandedSsid === model.ssid ? "" : model.ssid)
                        }
                        HoverHandler { id: wifiItemHover; cursorShape: Qt.PointingHandCursor }
                    }

                    ColumnLayout {
                        id: expandedWifiContent
                        Layout.fillWidth: true
                        visible: isExpanded
                        spacing: 6

                        RowLayout {
                            visible: model.connected
                            Layout.fillWidth: true
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 26
                                radius: Config.cornerRadius / 2
                                color: offHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "OFF"
                                    font.family: Config.sysFont
                                    color: offHover.hovered ? Config.accent : Config.textMain
                                    font.bold: true
                                    font.pixelSize: Config.size(Config.fontMicro)
                                }
                                TapHandler {
                                    gesturePolicy: TapHandler.WithinBounds
                                    onTapped: cardRoot.disconnectSsid(model.ssid)
                                }
                                HoverHandler { id: offHover; cursorShape: Qt.PointingHandCursor }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 26
                                radius: Config.cornerRadius / 2
                                color: forgetWifiHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "FORGET"
                                    font.family: Config.sysFont
                                    color: forgetWifiHover.hovered ? Config.accent : Config.textMuted
                                    font.bold: true
                                    font.pixelSize: Config.size(Config.fontMicro)
                                }
                                TapHandler {
                                    gesturePolicy: TapHandler.WithinBounds
                                    onTapped: cardRoot.forgetSsid(model.ssid)
                                }
                                HoverHandler { id: forgetWifiHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }

                        RowLayout {
                            visible: !model.connected && (!model.isSecure || isKnown)
                            Layout.fillWidth: true

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 26
                                radius: Config.cornerRadius / 2
                                color: joinKnownHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Config.accent
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: isConnecting ? "JOINING..." : "JOIN"
                                    font.family: Config.sysFont
                                    color: joinKnownHover.hovered ? Config.accent : Config.bgBase
                                    font.bold: true
                                    font.pixelSize: Config.size(Config.fontMicro)
                                }
                                TapHandler {
                                    gesturePolicy: TapHandler.WithinBounds
                                    onTapped: if (!isConnecting) cardRoot.connectTo(model.ssid, "", isKnown)
                                }
                                HoverHandler { id: joinKnownHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }

                        ColumnLayout {
                            visible: !model.connected && model.isSecure && !isKnown
                            Layout.fillWidth: true
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 26
                                radius: Config.cornerRadius / 2
                                color: Qt.rgba(0, 0, 0, 0.4)

                                TextInput {
                                    id: passInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: 10
                                    echoMode: TextInput.Password
                                    selectByMouse: true
                                    onAccepted: if (!isConnecting) cardRoot.connectTo(model.ssid, passInput.text, false)
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 26
                                radius: Config.cornerRadius / 2
                                color: joinNewHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Config.accent
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: isConnecting ? "JOINING..." : "JOIN"
                                    font.family: Config.sysFont
                                    color: joinNewHover.hovered ? Config.accent : Config.bgBase
                                    font.bold: true
                                    font.pixelSize: Config.size(Config.fontMicro)
                                }
                                TapHandler {
                                    gesturePolicy: TapHandler.WithinBounds
                                    onTapped: if (!isConnecting) cardRoot.connectTo(model.ssid, passInput.text, false)
                                }
                                HoverHandler { id: joinNewHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }
            }
        }
    }
}