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
    property bool wifiPowered: false
    property bool wifiScanning: false
    property string activeSsid: ""
    property string expandedSsid: ""
    property string connectingSsid: ""
    property string disconnectingSsid: ""
    property string errorSsid: ""
    property string connectionError: ""
    property var savedSsids: ([])

    opacity: root.hasAdapter ? 1.0 : 0.4
    enabled: root.hasAdapter

    ListModel { id: wifiModel }

    Component.onCompleted: {
        detectWifiAdapterProc.running = true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            implicitWidth: 36; implicitHeight: 36; radius: Config.cornerRadius / 2
            color: root.wifiPowered && root.hasAdapter ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

            Text {
                anchors.centerIn: parent
                text: !root.hasAdapter ? "signal_wifi_off" : (root.wifiPowered ? "wifi" : "signal_wifi_off")
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: root.wifiPowered && root.hasAdapter ? Config.bgBase : Config.textMuted
            }

            TapHandler {
                enabled: root.hasAdapter
                onTapped: {
                    let nextState = root.wifiPowered ? "off" : "on"
                    toggleWifiProc.command = ["fish", "-c", "nmcli radio wifi " + nextState]
                    toggleWifiProc.running = true
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { text: "Wi-Fi Network"; font.family: Config.sysFont; font.bold: true; color: Config.textMain; font.pixelSize: Config.size(Config.fontCaption) }
            Text { 
                text: !root.hasAdapter ? "No Adapter" : (!root.wifiPowered ? "Disabled" : (root.activeSsid !== "" ? root.activeSsid : "Disconnected"))
                font.family: Config.sysFont
                font.bold: root.activeSsid !== "" && root.wifiPowered && root.hasAdapter
                color: root.activeSsid !== "" && root.wifiPowered && root.hasAdapter ? Config.accent : Config.textMuted
                font.pixelSize: Config.size(Config.fontMicro)
            }
        }

        Rectangle {
            implicitWidth: 28; implicitHeight: 28; radius: 14
            visible: root.wifiPowered && root.hasAdapter
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
                required property bool isSaved
                readonly property bool isExpanded: root.expandedSsid === ssid
                readonly property bool isConnecting: root.connectingSsid === ssid
                readonly property bool isDisconnecting: root.disconnectingSsid === ssid
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

                        // Password Panel
                        RowLayout {
                            visible: !connected && isSecure && (!isSaved || hasError)
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
                                    enabled: !isConnecting && !isDisconnecting
                                    selectByMouse: true
                                    onAccepted: {
                                        if (isSecure && passInput.text.trim() === "" && (!isSaved || hasError)) {
                                            root.errorSsid = ssid
                                            root.connectionError = "Password Required"
                                            return
                                        }
                                        root.connectWifi(ssid, passInput.text)
                                    }
                                    onTextChanged: {
                                        if (hasError && passInput.activeFocus) {
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
                                    enabled: !isConnecting && !isDisconnecting
                                    onTapped: {
                                        if (isSecure && passInput.text.trim() === "" && (!isSaved || hasError)) {
                                            root.errorSsid = ssid
                                            root.connectionError = "Password Required"
                                            return
                                        }
                                        root.connectWifi(ssid, passInput.text)
                                    }
                                }
                                HoverHandler { id: joinHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }

                        // Controls Panel
                        RowLayout {
                            visible: connected || (isSaved && !hasError) || !isSecure
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                visible: connected
                                Layout.fillWidth: true; implicitHeight: 26; radius: Config.cornerRadius / 2
                                color: discHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                                Text { anchors.centerIn: parent; text: isDisconnecting ? "..." : "DISCONNECT"; font.family: Config.sysFont; font.bold: true; font.pixelSize: Config.size(Config.fontMicro); color: discHover.hovered ? Config.accent : Config.textMain }
                                TapHandler {
                                    enabled: !isDisconnecting && !isConnecting
                                    onTapped: root.disconnectWifi(ssid)
                                }
                                HoverHandler { id: discHover; cursorShape: Qt.PointingHandCursor }
                            }

                            Rectangle {
                                visible: !connected && isSaved
                                Layout.fillWidth: true; implicitHeight: 26; radius: Config.cornerRadius / 2
                                color: connHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Config.accent
                                Text { anchors.centerIn: parent; text: isConnecting ? "..." : "CONNECT"; font.family: Config.sysFont; font.bold: true; font.pixelSize: Config.size(Config.fontMicro); color: connHover.hovered ? Config.accent : Config.bgBase }
                                TapHandler {
                                    enabled: !isConnecting && !isDisconnecting
                                    onTapped: root.connectWifi(ssid, "")
                                }
                                HoverHandler { id: connHover; cursorShape: Qt.PointingHandCursor }
                            }

                            Rectangle {
                                visible: isSaved
                                Layout.fillWidth: true; implicitHeight: 26; radius: Config.cornerRadius / 2
                                color: forgetHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                                Text { anchors.centerIn: parent; text: "FORGET"; font.family: Config.sysFont; font.bold: true; font.pixelSize: Config.size(Config.fontMicro); color: forgetHover.hovered ? Config.accent : Config.textMuted }
                                TapHandler {
                                    enabled: !isConnecting && !isDisconnecting
                                    onTapped: root.forgetWifi(ssid)
                                }
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
        interval: 4000; running: root.visible && root.hasAdapter; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (!root.hasActiveInputFocus()) {
                fetchWifiStatusProc.running = true
            }
        }
    }

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
        id: detectWifiAdapterProc
        command: ["fish", "-c", "nmcli -t -f TYPE device | grep -q '^wifi$' && echo 'YES' || echo 'NO'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasAdapter = this.text.trim() === "YES"
                if (root.hasAdapter) fetchWifiStatusProc.running = true
            }
        }
    }

    Process {
        id: toggleWifiProc
        running: false
        onExited: {
            fetchWifiStatusProc.running = true
        }
    }

    Process {
        id: fetchWifiStatusProc
        command: ["fish", "-c", "
            nmcli -t -f WIFI g; echo '---'; 
            nmcli -t -f TYPE,NAME connection show --active | awk -F: '$1 == \"802-11-wireless\" {print $2; exit}'; echo '---'; 
            nmcli -t -f TYPE,NAME connection show | awk -F: '$1 == \"802-11-wireless\" {print $2}'; echo '---';
            nmcli -t -f ACTIVE,SSID,SECURITY device wifi
        "]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.split("---")
                if (parts.length < 4) return
                root.wifiPowered = parts[0].trim().includes("enabled")
                
                let activeConnSsid = parts[1].trim()
                let savedList = parts[2].trim().split("\n").map(s => s.trim()).filter(s => s.length > 0)
                root.savedSsids = savedList

                if (root.hasActiveInputFocus()) return

                wifiModel.clear()
                if (!root.wifiPowered || !root.hasAdapter) return

                let lines = parts[3].trim().split("\n")
                let seen = {}, active = activeConnSsid
                
                if (activeConnSsid.length > 0) {
                    wifiModel.append({ ssid: activeConnSsid, connected: true, isSecure: true, isSaved: true })
                    seen[activeConnSsid] = true
                }

                for (let i = 0; i < lines.length; i++) {
                    let fields = lines[i].split(":")
                    if (fields.length < 2) continue
                    let isConn = fields[0].toLowerCase() === "yes" || fields[0].toLowerCase() === "true"
                    let ssidName = fields[1].trim()
                    let sec = fields[2] || ""
                    
                    if (!ssidName) continue
                    if (isConn && !active) active = ssidName

                    let isSavedProfile = savedList.indexOf(ssidName) !== -1

                    if (seen[ssidName]) {
                        if (isConn) {
                            for (let m = 0; m < wifiModel.count; m++) {
                                if (wifiModel.get(m).ssid === ssidName) {
                                    wifiModel.setProperty(m, "connected", true)
                                    wifiModel.setProperty(m, "isSaved", true)
                                    break
                                }
                            }
                        }
                        continue
                    }
                    
                    seen[ssidName] = true
                    wifiModel.append({ 
                        ssid: ssidName, 
                        connected: isConn || (ssidName === activeConnSsid), 
                        isSecure: sec !== "",
                        isSaved: isSavedProfile
                    })
                }
                root.activeSsid = active
            }
        }
    }

    function triggerScan() {
        if (root.wifiScanning || !root.hasAdapter) return
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
        if (!root.hasAdapter || connProc.running || discProc.running) return
        connProc.activeTargetSsid = ssid
        root.connectingSsid = ssid
        root.errorSsid = ""
        root.connectionError = ""
        
        let escapedSsid = ssid.replace(/'/g, "'\"'\"'")
        let cmd = ""
        if (password.length > 0) {
            let escapedPass = password.replace(/'/g, "'\"'\"'")
            cmd = `nmcli device wifi connect '${escapedSsid}' password '${escapedPass}'`
        } else {
            cmd = `nmcli connection up id '${escapedSsid}' 2>/dev/null || nmcli device wifi connect '${escapedSsid}'`
        }
        
        connProc.command = ["fish", "-c", cmd]
        connProc.running = true
    }
    
    function disconnectWifi(ssid) {
        if (!root.hasAdapter || discProc.running || connProc.running) return
        root.disconnectingSsid = ssid
        root.errorSsid = ""
        root.connectionError = ""
        
        let escapedSsid = ssid.replace(/'/g, "'\"'\"'")
        
        discProc.command = ["fish", "-c", `
            # Retrieve active UUID utilizing regex for both 'wifi' and '802-11-wireless' nmcli types
            set active_uuid (nmcli -t -f UUID,TYPE,NAME connection show --active | awk -F: -v target='${escapedSsid}' '($2 ~ /802-11-wireless|wifi/) && $3 == target {print $1; exit}')
            
            if test -n "$active_uuid"
                # Drop the specific connection directly by its UUID
                nmcli connection down "$active_uuid"
            else
                # Aggressive fallback: Disconnect the Wi-Fi hardware device if profile targeting fails
                set dev (nmcli -t -f DEVICE,TYPE device | awk -F: '$2 ~ /802-11-wireless|wifi/ {print $1; exit}')
                if test -n "$dev"
                    nmcli device disconnect "$dev"
                end
            end
        `]
        discProc.running = true
    }

    function forgetWifi(ssid) {
        if (!root.hasAdapter || forgetProc.running) return
        root.errorSsid = ""
        root.connectionError = ""
        
        let escapedSsid = ssid.replace(/'/g, "'\"'\"'")
        
        forgetProc.command = ["fish", "-c", `
            # Extract all matching UUIDs for the given SSID
            set uuids (nmcli -t -f UUID,TYPE,NAME connection show | awk -F: -v target='${escapedSsid}' '$2 ~ /802-11-wireless/ && $3 == target {print $1}')
            
            # Iterate directly to bypass test -n list expansion crashes
            for u in $uuids
                nmcli connection delete uuid "$u"
            end
        `]
        forgetProc.running = true
    }

    Process { 
        id: discProc
        running: false
        onExited: {
            root.disconnectingSsid = ""
            fetchWifiStatusProc.running = false
            fetchWifiStatusProc.running = true
        }
    }

    Process { 
        id: forgetProc
        running: false
        onExited: {
            root.errorSsid = ""
            root.connectionError = ""
            fetchWifiStatusProc.running = false
            fetchWifiStatusProc.running = true
        }
    }

    Process {
        id: connCleanupProc
        running: false
        onExited: {
            fetchWifiStatusProc.running = false
            fetchWifiStatusProc.running = true
        }
    }

    Process {
        id: connProc
        running: false
        property string activeTargetSsid: ""

        stdout: StdioCollector { id: connStdout }
        stderr: StdioCollector { id: connStderr }

        onExited: (exitCode) => {
            let failedSsid = activeTargetSsid
            root.connectingSsid = ""

            if (exitCode !== 0 && failedSsid !== "") {
                root.errorSsid = failedSsid
                root.expandedSsid = failedSsid
                let fullErr = (connStdout.text + "\n" + connStderr.text).trim().toLowerCase()
                if (fullErr.includes("not found") || fullErr.includes("no network")) {
                    root.connectionError = "Network Not Found"
                } else {
                    root.connectionError = "Invalid Password"
                }

                let safeSsid = failedSsid.replace(/'/g, "'\"'\"'")
                connCleanupProc.command = ["fish", "-c", `
                    set uuids (nmcli -t -f UUID,TYPE,NAME connection show | awk -F: -v target='${safeSsid}' '$2 ~ /802-11-wireless|wifi/ && $3 == target {print $1}')
                    for u in $uuids
                        nmcli connection delete uuid "$u" 2>/dev/null
                    end
                `]
                connCleanupProc.running = true
            } else {
                root.errorSsid = ""
                root.connectionError = ""
                fetchWifiStatusProc.running = false
                fetchWifiStatusProc.running = true
            }
        }
    }
}