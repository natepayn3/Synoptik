import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."

ColumnLayout {
    id: root
    spacing: 12

    property bool wifiPowered: false
    property bool wifiScanning: false
    property string activeSsid: ""
    property string expandedSsid: ""
    property string connectingSsid: ""
    property string errorSsid: ""
    property string connectionError: ""

    ListModel { id: wifiModel }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            implicitWidth: 36; implicitHeight: 36; radius: Config.cornerRadius / 2
            color: root.wifiPowered ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

            Text {
                anchors.centerIn: parent
                text: root.wifiPowered ? "wifi" : "signal_wifi_off"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: root.wifiPowered ? Config.bgBase : Config.textMuted
            }

            TapHandler {
                onTapped: {
                    toggleWifiProc.command = ["fish", "-c", "nmcli radio wifi " + (root.wifiPowered ? "off" : "on")]
                    toggleWifiProc.running = true
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { text: "Wi-Fi Network"; font.family: Config.sysFont; font.bold: true; color: Config.textMain; font.pixelSize: Config.size(Config.fontCaption) }
            Text { text: !root.wifiPowered ? "Disabled" : (root.activeSsid !== "" ? root.activeSsid : "Disconnected"); font.family: Config.sysFont; color: Config.textMuted; font.pixelSize: Config.size(Config.fontMicro) }
        }

        Rectangle {
            implicitWidth: 28; implicitHeight: 28; radius: 14
            visible: root.wifiPowered
            color: scanHover.hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent"

            Text {
                id: scanIcon
                anchors.centerIn: parent
                text: "refresh"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 16
                color: scanHover.hovered ? Config.textMain : Config.textMuted

                NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    running: root.wifiScanning
                }
            }

            TapHandler { onTapped: root.triggerScan() }
            HoverHandler { id: scanHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Qt.rgba(0, 0, 0, 0.2)
        radius: Config.cornerRadius / 2
        clip: true

        ListView {
            id: wifiListView
            anchors.fill: parent
            anchors.margins: 6
            spacing: 4
            model: wifiModel

            delegate: Rectangle {
                required property string ssid
                required property bool connected
                required property bool isSecure
                readonly property bool isExpanded: root.expandedSsid === ssid
                readonly property bool isConnecting: root.connectingSsid === ssid
                readonly property bool hasError: root.errorSsid === ssid

                width: wifiListView.width
                implicitHeight: isExpanded ? (hasError ? 96 : 76) : 36
                radius: Config.cornerRadius / 2
                color: hasError ? Qt.rgba(255, 80, 80, 0.15) : (connected ? Qt.rgba(255, 255, 255, 0.12) : (wHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent"))
                border.color: hasError ? "#ff5555" : "transparent"
                border.width: hasError ? 1 : 0
                clip: true
                Behavior on implicitHeight { NumberAnimation { duration: 150 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: ssid; color: connected ? Config.accent : Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: connected; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: isSecure ? "lock" : "wifi"; font.family: "Material Symbols Outlined"; font.pixelSize: 14; color: Config.textMuted }
                    }

                    ColumnLayout {
                        visible: isExpanded
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            visible: hasError
                            text: root.connectionError
                            color: "#ff6b6b"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                        }

                        // Unconnected Password Panel
                        RowLayout {
                            visible: !connected && isSecure
                            Layout.fillWidth: true

                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 26; radius: Config.cornerRadius / 2
                                color: Qt.rgba(0, 0, 0, 0.4)
                                border.color: passInput.activeFocus ? Config.accent : (hasError ? "#ff5555" : "transparent")
                                border.width: 1

                                TextInput {
                                    id: passInput
                                    anchors.fill: parent; anchors.margins: 4
                                    color: Config.textMain; font.family: Config.sysFont; font.pixelSize: 11
                                    echoMode: TextInput.Password
                                    enabled: !isConnecting
                                    selectByMouse: true
                                    onAccepted: root.connectWifi(ssid, passInput.text)
                                    onTextChanged: {
                                        if (hasError) {
                                            root.errorSsid = ""
                                            root.connectionError = ""
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                implicitWidth: 60; implicitHeight: 26; radius: Config.cornerRadius / 2
                                color: joinHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Config.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: isConnecting ? "..." : "JOIN"
                                    font.family: Config.sysFont; font.bold: true; font.pixelSize: Config.size(Config.fontMicro)
                                    color: joinHover.hovered ? Config.accent : Config.bgBase
                                }

                                TapHandler {
                                    enabled: !isConnecting
                                    onTapped: root.connectWifi(ssid, passInput.text)
                                }
                                HoverHandler { id: joinHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }

                        // Connected / Saved Controls
                        RowLayout {
                            visible: connected || !isSecure
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                visible: connected
                                Layout.fillWidth: true; implicitHeight: 26; radius: Config.cornerRadius / 2
                                color: discHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                                Text { anchors.centerIn: parent; text: "DISCONNECT"; font.family: Config.sysFont; font.bold: true; font.pixelSize: Config.size(Config.fontMicro); color: discHover.hovered ? Config.accent : Config.textMain }
                                TapHandler { onTapped: root.disconnectWifi(ssid) }
                                HoverHandler { id: discHover; cursorShape: Qt.PointingHandCursor }
                            }

                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 26; radius: Config.cornerRadius / 2
                                color: forgetHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                                Text { anchors.centerIn: parent; text: "FORGET"; font.family: Config.sysFont; font.bold: true; font.pixelSize: Config.size(Config.fontMicro); color: forgetHover.hovered ? Config.accent : Config.textMuted }
                                TapHandler { onTapped: root.forgetWifi(ssid) }
                                HoverHandler { id: forgetHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }

                TapHandler {
                    onTapped: (point) => {
                        if (root.expandedSsid !== ssid) root.expandedSsid = ssid
                    }
                }
                HoverHandler { id: wHover; cursorShape: Qt.PointingHandCursor }
            }
        }
    }

    Timer {
        interval: 4000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (!root.hasActiveInputFocus()) {
                fetchWifiStatusProc.running = true
            }
        }
    }

    // Keeps animation alive while NetworkManager executes scan
    Timer {
        id: scanTimeoutTimer
        interval: 3500
        repeat: false
        onTriggered: {
            root.wifiScanning = false
            fetchWifiStatusProc.running = true
        }
    }

    function hasActiveInputFocus() {
        return root.Window.window && root.Window.window.activeFocusItem && root.Window.window.activeFocusItem instanceof TextInput
    }

    Process {
        id: toggleWifiProc
        running: false
        onExited: {
            if (root.wifiPowered) {
                autoConnectProc.command = ["fish", "-c", "nmcli device connect (nmcli -t -f DEVICE,TYPE device | grep ':wifi' | cut -d: -f1)"]
                autoConnectProc.running = true
            } else {
                fetchWifiStatusProc.running = true
            }
        }
    }

    Process { 
        id: autoConnectProc
        running: false
        onExited: fetchWifiStatusProc.running = true 
    }

    Process {
        id: fetchWifiStatusProc
        command: ["fish", "-c", "nmcli -t -f WIFI g; echo '---'; nmcli -t -f ACTIVE,SSID,SECURITY device wifi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.split("---")
                if (parts.length < 2) return
                root.wifiPowered = parts[0].trim().includes("enabled")
                
                if (root.hasActiveInputFocus()) return

                wifiModel.clear()
                if (!root.wifiPowered) return

                let lines = parts[1].trim().split("\n")
                let seen = {}, active = ""
                for (let i = 0; i < lines.length; i++) {
                    let fields = lines[i].split(":")
                    if (fields.length < 2) continue
                    let isConn = fields[0] === "yes"
                    let ssidName = fields[1].trim()
                    let sec = fields[2] || ""
                    if (!ssidName || seen[ssidName]) continue
                    seen[ssidName] = true
                    if (isConn) active = ssidName
                    wifiModel.append({ ssid: ssidName, connected: isConn, isSecure: sec !== "" })
                }
                root.activeSsid = active
            }
        }
    }

    function triggerScan() {
        if (root.wifiScanning) return
        root.wifiScanning = true
        scanProc.command = ["fish", "-c", "nmcli device wifi rescan"]
        scanProc.running = true
        scanTimeoutTimer.restart()
    }

    Process { 
        id: scanProc
        running: false 
    }
    
    function connectWifi(ssid, password) {
        root.connectingSsid = ssid
        root.errorSsid = ""
        root.connectionError = ""
        connProc.command = ["fish", "-c", password.length > 0 ? `nmcli device wifi connect '${ssid}' password '${password}'` : `nmcli device wifi connect '${ssid}'`]
        connProc.running = true
    }
    
    function disconnectWifi(ssid) {
        connProc.command = ["fish", "-c", `nmcli connection down id '${ssid}'`]
        connProc.running = true
    }

    function forgetWifi(ssid) {
        forgetProc.command = ["fish", "-c", `nmcli connection delete id '${ssid}'`]
        forgetProc.running = true
    }

    Process { id: forgetProc; running: false; onExited: fetchWifiStatusProc.running = true }

    Process {
        id: connProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                let errText = this.text.trim()
                if (errText.length > 0 && connProc.exitCode !== 0) {
                    root.errorSsid = root.connectingSsid
                    if (errText.includes("Secret") || errText.includes("passphrase") || errText.includes("authentication")) {
                        root.connectionError = "Invalid Password"
                    } else {
                        root.connectionError = "Connection Failed"
                    }
                }
            }
        }
        onExited: {
            root.connectingSsid = ""
            fetchWifiStatusProc.running = true
        }
    }
}