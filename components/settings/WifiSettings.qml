import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: root

    // Shared with the Control Center's WifiCard via Config.network - see
    // NetworkService.qml. This page used to run a second, independent nmcli
    // implementation on a 4s poll; with both panels open that meant two
    // competing rescans and two divergent views of the same radio.
    readonly property var net: Config.network

    readonly property bool hasPolledOnce: net.hasPolledOnce
    readonly property bool hasAdapter: net.hasAdapter
    readonly property bool wifiPowered: net.powered
    readonly property bool wifiScanning: net.scanning
    readonly property string activeSsid: net.activeSsid
    property string expandedSsid: ""
    readonly property string connectingSsid: net.connectingSsid
    readonly property string disconnectingSsid: net.disconnectingSsid
    readonly property string errorSsid: net.errorSsid
    readonly property string connectionError: net.connectionError
    readonly property var savedSsids: net.savedSsids

    // Pre-flight validation ("Password Required") kept local so it never has
    // to write to the service-bound properties above.
    property string validationSsid: ""
    property string validationError: ""
    readonly property string shownErrorSsid: validationSsid !== "" ? validationSsid : errorSsid
    readonly property string shownError: validationSsid !== "" ? validationError : connectionError
    function clearValidation() { validationSsid = ""; validationError = "" }

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    readonly property var wifiModel: net.networks

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: root.cardMargin

            // ==========================================
            // HEADER & DESCRIPTION
            // ==========================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "WI-FI CONFIGURATION"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontSubhead)
                    font.bold: true
                }

                Text {
                    text: "Manage wireless radio interfaces, scan nearby access points, authenticate with secured networks, and configure saved profiles."
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }

            // ==========================================
            // 1. HERO INTERFACE & STATUS CARD
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: heroRow.implicitHeight + 28
                radius: Config.cornerRadius
                color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 2
                border.color: Qt.rgba(255, 255, 255, 0.1)

                RowLayout {
                    id: heroRow
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    // Hero Status Icon Badge
                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: 22
                        Layout.alignment: Qt.AlignVCenter
                        color: (root.wifiPowered && root.hasAdapter)
                            ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2)
                            : Qt.rgba(255, 255, 255, 0.06)
                        border.width: 2
                        border.color: (root.wifiPowered && root.hasAdapter) ? Config.accent : Qt.rgba(255, 255, 255, 0.15)

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Text {
                            anchors.centerIn: parent
                            text: !root.hasAdapter ? "signal_wifi_off" : (root.wifiPowered ? (root.activeSsid !== "" ? "wifi" : "wifi_find") : "signal_wifi_off")
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            color: (root.wifiPowered && root.hasAdapter) ? Config.accent : Config.textMuted
                        }
                    }

                    // Status Text
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8
                            Text {
                                text: "Wireless Radio"
                                font.family: Config.sysFont
                                font.bold: true
                                color: Config.textMain
                                font.pixelSize: Config.size(Config.fontBody)
                                verticalAlignment: Text.AlignVCenter
                            }

                            Rectangle {
                                implicitWidth: statusPillText.implicitWidth + 10
                                implicitHeight: 18
                                radius: 9
                                Layout.alignment: Qt.AlignVCenter
                                color: !root.hasAdapter
                                    ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2)
                                    : (root.wifiPowered ? (root.activeSsid !== "" ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2) : Qt.rgba(255, 255, 255, 0.1)) : Qt.rgba(255, 255, 255, 0.08))
                                border.width: 2
                                border.color: !root.hasAdapter
                                    ? Config.accent
                                    : (root.wifiPowered && root.activeSsid !== "" ? Config.accent : Qt.rgba(255, 255, 255, 0.15))

                                Text {
                                    id: statusPillText
                                    anchors.centerIn: parent
                                    text: !root.hasAdapter ? "NO ADAPTER" : (!root.wifiPowered ? "DISABLED" : (root.activeSsid !== "" ? "CONNECTED" : "DISCONNECTED"))
                                    font.family: Config.sysFont
                                    font.pixelSize: 9
                                    font.bold: true
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    color: !root.hasAdapter
                                        ? Config.accent
                                        : (root.wifiPowered && root.activeSsid !== "" ? Config.accent : Config.textMuted)
                                }
                            }
                        }

                        Text {
                            text: !root.hasAdapter
                                ? "No wireless network hardware interface detected"
                                : (!root.wifiPowered
                                    ? "Wi-Fi radio is currently powered off to save power"
                                    : (root.activeSsid !== "" ? ("Connected to " + root.activeSsid) : "Wi-Fi enabled • Scanning for access points"))
                            font.family: Config.sysFont
                            color: (root.wifiPowered && root.activeSsid !== "") ? Config.accent : Config.textMuted
                            font.pixelSize: Config.size(Config.fontCaption)
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Spacer to push action buttons to the right
                    Item { Layout.fillWidth: true }

                    // Action Buttons (Rescan & Power Toggle)
                    RowLayout {
                        spacing: 8
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                        // RESCAN BUTTON
                        Rectangle {
                            implicitWidth: rescanRow.implicitWidth + 16
                            implicitHeight: 32
                            radius: 16
                            Layout.alignment: Qt.AlignVCenter
                            visible: root.wifiPowered && root.hasAdapter
                            color: rescanHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06)
                            border.width: 2
                            border.color: Qt.rgba(255, 255, 255, 0.12)

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                id: rescanRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    id: scanIconText
                                    text: "refresh"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 16
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    color: rescanHover.hovered ? Config.accent : Config.textMain

                                    NumberAnimation on rotation {
                                        from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                                        running: root.wifiScanning
                                    }
                                }

                                Text {
                                    text: root.wifiScanning ? "Scanning..." : "Rescan"
                                    font.family: Config.sysFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    verticalAlignment: Text.AlignVCenter
                                    color: rescanHover.hovered ? Config.accent : Config.textMain
                                }
                            }

                            TapHandler { onTapped: root.triggerScan() }
                            HoverHandler { id: rescanHover; cursorShape: Qt.PointingHandCursor }
                        }

                        // POWER TOGGLE BUTTON
                        Rectangle {
                            id: pwrBtn
                            implicitWidth: pwrRow.implicitWidth + 18
                            implicitHeight: 32
                            radius: 16
                            Layout.alignment: Qt.AlignVCenter
                            enabled: root.hasAdapter
                            color: (root.wifiPowered && root.hasAdapter)
                                ? (pwrHover.hovered ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.85) : Config.accent)
                                : (pwrHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08))

                            Behavior on color { ColorAnimation { duration: 180 } }

                            RowLayout {
                                id: pwrRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: root.wifiPowered ? "power_settings_new" : "power_off"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 16
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    color: (root.wifiPowered && root.hasAdapter) ? Config.bgBase : Config.textMuted
                                }

                                Text {
                                    text: root.wifiPowered ? "ON" : "OFF"
                                    font.family: Config.sysFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    verticalAlignment: Text.AlignVCenter
                                    color: (root.wifiPowered && root.hasAdapter) ? Config.bgBase : Config.textMuted
                                }
                            }

                            TapHandler {
                                enabled: root.hasAdapter
                                onTapped: root.net.togglePower()
                            }
                            HoverHandler { id: pwrHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

            // ==========================================
            // 2. DETECTED NETWORKS SECTION
            // ==========================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.hasAdapter && root.wifiPowered

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "AVAILABLE ACCESS POINTS"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    Rectangle {
                        implicitWidth: countText.implicitWidth + 10
                        implicitHeight: 16
                        radius: 8
                        color: Qt.rgba(255, 255, 255, 0.08)

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: wifiModel.count.toString()
                            font.family: Config.sysFont
                            font.pixelSize: 9
                            font.bold: true
                            color: Config.textMuted
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // NETWORKS LIST VIEW
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: wifiModel

                        delegate: Rectangle {
                            id: netCard
                            required property string ssid
                            required property bool connected
                            required property bool isSecure
                            required property bool isSaved
                            readonly property bool isExpanded: root.expandedSsid === ssid
                            readonly property bool isConnecting: root.connectingSsid === ssid
                            readonly property bool isDisconnecting: root.disconnectingSsid === ssid
                            readonly property bool hasError: root.shownErrorSsid === ssid

                            Layout.fillWidth: true
                            implicitHeight: netCol.implicitHeight + 20
                            radius: Config.cornerRadius * 0.75
                            color: connected
                                ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.12)
                                : (hasError
                                    ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.15)
                                    : (netHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)))
                            border.width: 2
                            border.color: connected
                                ? Config.accent
                                : (hasError ? Config.accent : (netHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)))
                            clip: true

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            ColumnLayout {
                                id: netCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                // Main Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 12

                                    // Signal / Lock Icon Badge
                                    Rectangle {
                                        implicitWidth: 36
                                        implicitHeight: 36
                                        radius: 18
                                        Layout.alignment: Qt.AlignVCenter
                                        color: connected
                                            ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.25)
                                            : Qt.rgba(255, 255, 255, 0.06)

                                        Text {
                                            anchors.centerIn: parent
                                            text: isSecure ? "wifi_password" : "wifi"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 18
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignHCenter
                                            color: connected ? Config.accent : Config.textMain
                                        }
                                    }

                                    // SSID Name & Badges
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        TapHandler {
                                            onTapped: {
                                                root.expandedSsid = (root.expandedSsid === ssid) ? "" : ssid
                                            }
                                        }

                                        RowLayout {
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 6

                                            Text {
                                                text: ssid
                                                color: connected ? Config.accent : Config.textMain
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontBody)
                                                font.bold: true
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: 300
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            // SAVED BADGE
                                            Rectangle {
                                                visible: isSaved && !connected
                                                implicitWidth: savedBadgeText.implicitWidth + 8
                                                implicitHeight: 16
                                                radius: 8
                                                Layout.alignment: Qt.AlignVCenter
                                                color: Qt.rgba(255, 255, 255, 0.1)

                                                Text {
                                                    id: savedBadgeText
                                                    anchors.centerIn: parent
                                                    text: "SAVED"
                                                    font.family: Config.sysFont
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    verticalAlignment: Text.AlignVCenter
                                                    color: Config.textMuted
                                                }
                                            }

                                            // CONNECTED BADGE
                                            Rectangle {
                                                visible: connected
                                                implicitWidth: connBadgeText.implicitWidth + 8
                                                implicitHeight: 16
                                                radius: 8
                                                Layout.alignment: Qt.AlignVCenter
                                                color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.25)
                                                border.width: 2
                                                border.color: Config.accent

                                                Text {
                                                    id: connBadgeText
                                                    anchors.centerIn: parent
                                                    text: "ACTIVE"
                                                    font.family: Config.sysFont
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    verticalAlignment: Text.AlignVCenter
                                                    color: Config.accent
                                                }
                                            }
                                        }

                                        Text {
                                            text: isSecure ? "WPA/WPA2 Personal" : "Open Access Point (Unsecured)"
                                            color: Config.textMuted
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontMicro)
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }

                                    // Spacer to push quick actions to the right
                                    Item { Layout.fillWidth: true }

                                    // Direct Quick Actions
                                    RowLayout {
                                        spacing: 6
                                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                                        // Connect Button for Saved Networks
                                        Rectangle {
                                            visible: !connected && isSaved && !isExpanded
                                            implicitWidth: Math.max(connBtnText.implicitWidth + 24, 76)
                                            implicitHeight: 28
                                            radius: 14
                                            Layout.alignment: Qt.AlignVCenter
                                            color: qConnHover.hovered ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.85) : Config.accent

                                            Text {
                                                id: connBtnText
                                                anchors.centerIn: parent
                                                text: isConnecting ? "..." : "Connect"
                                                font.family: Config.sysFont
                                                font.bold: true
                                                font.pixelSize: 11
                                                verticalAlignment: Text.AlignVCenter
                                                color: Config.bgBase
                                            }

                                            TapHandler {
                                                enabled: !isConnecting && !isDisconnecting
                                                onTapped: root.connectWifi(ssid, "")
                                            }
                                            HoverHandler { id: qConnHover; cursorShape: Qt.PointingHandCursor }
                                        }

                                        // Expand Arrow / Join Button
                                        Rectangle {
                                            implicitWidth: 30
                                            implicitHeight: 30
                                            radius: 15
                                            Layout.alignment: Qt.AlignVCenter
                                            color: expHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)

                                            Text {
                                                anchors.centerIn: parent
                                                text: isExpanded ? "expand_less" : "chevron_right"
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 18
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter
                                                color: expHover.hovered ? Config.textMain : Config.textMuted
                                            }

                                            TapHandler {
                                                onTapped: {
                                                    root.expandedSsid = (root.expandedSsid === ssid) ? "" : ssid
                                                }
                                            }
                                            HoverHandler { id: expHover; cursorShape: Qt.PointingHandCursor }
                                        }
                                    }
                                }

                                // EXPANDED ACTION & AUTHENTICATION DRAWER
                                ColumnLayout {
                                    visible: isExpanded
                                    Layout.fillWidth: true
                                    spacing: 8

                                    // ERROR BANNER
                                    Rectangle {
                                        visible: hasError
                                        Layout.fillWidth: true
                                        implicitHeight: errText.implicitHeight + 12
                                        radius: 6
                                        color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2)
                                        border.width: 2
                                        border.color: Config.accent

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            spacing: 6
                                            Text { text: "error"; font.family: "Material Symbols Outlined"; font.pixelSize: 16; verticalAlignment: Text.AlignVCenter; color: Config.accent }
                                            Text { id: errText; text: root.connectionError; font.family: Config.sysFont; font.pixelSize: 11; font.bold: true; verticalAlignment: Text.AlignVCenter; color: Config.accent; Layout.fillWidth: true }
                                        }
                                    }

                                    // PASSWORD INPUT ROW
                                    RowLayout {
                                        visible: !connected && isSecure && (!isSaved || hasError)
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 32
                                            radius: 8
                                            color: Qt.rgba(0, 0, 0, 0.35)
                                            border.width: 2
                                            border.color: passInput.activeFocus ? Config.accent : (hasError ? Config.accent : Qt.rgba(255, 255, 255, 0.15))

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 6
                                                spacing: 6

                                                Text {
                                                    text: "key"
                                                    font.family: "Material Symbols Outlined"
                                                    font.pixelSize: 15
                                                    verticalAlignment: Text.AlignVCenter
                                                    color: Config.textMuted
                                                }

                                                TextInput {
                                                    id: passInput
                                                    Layout.fillWidth: true
                                                    color: Config.textMain
                                                    font.family: Config.sysFont
                                                    font.pixelSize: 12
                                                    verticalAlignment: Text.AlignVCenter
                                                    echoMode: showPassToggle.showPassword ? TextInput.Normal : TextInput.Password
                                                    enabled: !isConnecting && !isDisconnecting
                                                    selectByMouse: true
                                                    clip: true

                                                    Text {
                                                        anchors.fill: parent
                                                        text: "Enter Wi-Fi network password..."
                                                        color: Qt.rgba(255, 255, 255, 0.3)
                                                        font.family: Config.sysFont
                                                        font.pixelSize: 12
                                                        verticalAlignment: Text.AlignVCenter
                                                        visible: !passInput.text && !passInput.activeFocus
                                                    }

                                                    onAccepted: {
                                                        if (isSecure && passInput.text.trim() === "" && (!isSaved || hasError)) {
                                                             root.validationSsid = ssid
                                                             root.validationError = "Password Required"
                                                             return
                                                        }
                                                        root.clearValidation()
                                                        root.connectWifi(ssid, passInput.text)
                                                    }
                                                    onTextChanged: {
                                                        if (hasError && passInput.activeFocus) {
                                                            root.clearValidation()
                                                        }
                                                    }
                                                }

                                                // Eye Toggle Button
                                                Rectangle {
                                                    id: showPassToggle
                                                    property bool showPassword: false
                                                    implicitWidth: 24
                                                    implicitHeight: 24
                                                    radius: 12
                                                    color: eyeHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : "transparent"

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: showPassToggle.showPassword ? "visibility" : "visibility_off"
                                                        font.family: "Material Symbols Outlined"
                                                        font.pixelSize: 15
                                                        verticalAlignment: Text.AlignVCenter
                                                        horizontalAlignment: Text.AlignHCenter
                                                        color: eyeHover.hovered ? Config.textMain : Config.textMuted
                                                    }

                                                    TapHandler { onTapped: showPassToggle.showPassword = !showPassToggle.showPassword }
                                                    HoverHandler { id: eyeHover; cursorShape: Qt.PointingHandCursor }
                                                }
                                            }
                                        }

                                        // JOIN ACTION BUTTON
                                        Rectangle {
                                            implicitWidth: joinLabel.implicitWidth + 20
                                            implicitHeight: 32
                                            radius: 8
                                            color: joinActionHover.hovered ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.85) : Config.accent

                                            Text {
                                                id: joinLabel
                                                anchors.centerIn: parent
                                                text: isConnecting ? "Connecting..." : "Join Network"
                                                font.family: Config.sysFont
                                                font.bold: true
                                                font.pixelSize: 11
                                                verticalAlignment: Text.AlignVCenter
                                                color: Config.bgBase
                                            }

                                            TapHandler {
                                                enabled: !isConnecting && !isDisconnecting
                                                onTapped: {
                                                    if (isSecure && passInput.text.trim() === "" && (!isSaved || hasError)) {
                                                        root.validationSsid = ssid
                                                        root.validationError = "Password Required"
                                                        return
                                                    }
                                                    root.connectWifi(ssid, passInput.text)
                                                }
                                            }
                                            HoverHandler { id: joinActionHover; cursorShape: Qt.PointingHandCursor }
                                        }
                                    }

                                    // CONTROLS & FORGET ROW
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        // Disconnect Button
                                        Rectangle {
                                            visible: connected
                                            Layout.fillWidth: true
                                            implicitHeight: 30
                                            radius: 8
                                            color: discActionHover.hovered ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2) : Qt.rgba(255, 255, 255, 0.08)
                                            border.width: 2
                                            border.color: discActionHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.12)

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                Text { text: "link_off"; font.family: "Material Symbols Outlined"; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter; color: discActionHover.hovered ? Config.accent : Config.textMain }
                                                Text { text: isDisconnecting ? "Disconnecting..." : "Disconnect"; font.family: Config.sysFont; font.bold: true; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; color: discActionHover.hovered ? Config.accent : Config.textMain }
                                            }

                                            TapHandler {
                                                enabled: !isDisconnecting && !isConnecting
                                                onTapped: root.disconnectWifi(ssid)
                                            }
                                            HoverHandler { id: discActionHover; cursorShape: Qt.PointingHandCursor }
                                        }

                                        // Connect Button for Saved Networks inside drawer
                                        Rectangle {
                                            visible: !connected && isSaved
                                            Layout.fillWidth: true
                                            implicitHeight: 30
                                            radius: 8
                                            color: connActionHover.hovered ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.85) : Config.accent

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                Text { text: "login"; font.family: "Material Symbols Outlined"; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter; color: Config.bgBase }
                                                Text { text: isConnecting ? "Connecting..." : "Connect"; font.family: Config.sysFont; font.bold: true; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; color: Config.bgBase }
                                            }

                                            TapHandler {
                                                enabled: !isConnecting && !isDisconnecting
                                                onTapped: root.connectWifi(ssid, "")
                                            }
                                            HoverHandler { id: connActionHover; cursorShape: Qt.PointingHandCursor }
                                        }

                                        // Forget Network Profile Button
                                        Rectangle {
                                            visible: isSaved
                                            Layout.fillWidth: true
                                            implicitHeight: 30
                                            radius: 8
                                            color: forgetActionHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                                            border.width: 2
                                            border.color: Qt.rgba(255, 255, 255, 0.1)

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                Text { text: "delete_outline"; font.family: "Material Symbols Outlined"; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter; color: forgetActionHover.hovered ? Config.accent : Config.textMuted }
                                                Text { text: "Forget Profile"; font.family: Config.sysFont; font.bold: true; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; color: forgetActionHover.hovered ? Config.accent : Config.textMuted }
                                            }

                                            TapHandler {
                                                enabled: !isConnecting && !isDisconnecting
                                                onTapped: root.forgetWifi(ssid)
                                            }
                                            HoverHandler { id: forgetActionHover; cursorShape: Qt.PointingHandCursor }
                                        }
                                    }
                                }
                            }
                            HoverHandler { id: netHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

            // ==========================================
            // 3. EMPTY / DISABLED STATE CARD
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 160
                radius: Config.cornerRadius
                color: Qt.rgba(255, 255, 255, 0.03)
                border.width: 2
                border.color: Qt.rgba(255, 255, 255, 0.06)
                visible: root.hasPolledOnce && (!root.hasAdapter || !root.wifiPowered || (wifiModel.count === 0 && !root.wifiScanning))

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: !root.hasAdapter ? "phonelink_erase" : (!root.wifiPowered ? "wifi_off" : "wifi_find")
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 36
                        color: Config.textMuted
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: !root.hasAdapter
                            ? "No Wi-Fi interface detected"
                            : (!root.wifiPowered ? "Wi-Fi is currently disabled" : "No nearby wireless networks detected")
                        font.family: Config.sysFont
                        font.bold: true
                        font.pixelSize: Config.size(Config.fontBody)
                        color: Config.textMain
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: !root.hasAdapter
                            ? "Check your network adapter hardware or kernel modules"
                            : (!root.wifiPowered ? "Toggle the power switch above to scan for networks" : "Click Rescan to probe for 2.4GHz and 5GHz access points")
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        color: Config.textMuted
                    }
                }
            }
        }
    }

    // The BACKEND IPC PROCESSES & TIMERS block that used to live here - a 4s
    // poll, a scan-timeout timer and eight Process blocks running nmcli - is
    // gone. NetworkService owns all of it, so this page is presentation only.
    //
    // Two bugs went with it. Connect failures were classified by grepping
    // nmcli's stderr ("not found" -> Network Not Found, everything else ->
    // Invalid Password); NetworkManager reports the actual reason over
    // connectionFailed() now. And disconnect/forget matched the SSID through
    // `awk -v target=...`, which processes backslash escapes in the value
    // before awk sees it, so those two silently did nothing for any SSID
    // containing a backslash while still reporting success.
    //
    // The poll also used to clear() the model on every tick, which is why it
    // needed a hasActiveInputFocus() guard to avoid yanking the password field
    // out from under whoever was typing. The service reconciles in place, so
    // that guard is no longer needed either.
    function triggerScan() { root.net.scan() }
    function connectWifi(ssid, password) { root.net.connectTo(ssid, password, false) }
    function disconnectWifi(ssid) { root.net.disconnect(ssid) }
    function forgetWifi(ssid) { root.net.forget(ssid) }
}
