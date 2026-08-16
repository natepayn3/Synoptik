import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "controlcenter"

Item {
    id: root

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    // Calculate root implicit dimensions cleanly from mainLayout
    implicitWidth: mainLayout.implicitWidth + (cardMargin * 2)
    implicitHeight: mainLayout.implicitHeight + (cardMargin * 2)

    // --- State Properties ---
    property bool hasWifiAdapter: false
    property alias hasAdapter: root.hasWifiAdapter

    onHasWifiAdapterChanged: {
        if (hasWifiAdapter) {
            fetchWifiStatusProc.running = false
            fetchWifiStatusProc.running = true
        }
    }

    property bool hasBtAdapter: false
    property bool wifiPowered: false
    property bool wifiScanning: false
    property string activeSsid: ""
    property string expandedSsid: ""
    property string connectingSsid: ""
    property string disconnectingSsid: ""
    property string errorSsid: ""
    property string connectionError: ""
    property var knownNetworks: ({})

    // Bind directly to global shell state to eliminate loading latency & jumps
    property int currentVolume: shellRoot.audioVolume
    property bool isAudioMuted: shellRoot.audioMuted
    property bool isUserDraggingVol: false
    property int currentBrightness: 100
    property bool hasBacklight: false

    // Local override guard
    property bool isSettingVolume: false

    readonly property bool isAnyPanelExpanded: (wifiCard && (wifiCard.panelExpanded || wifiCard.shouldExpand)) ||
                                               (btCard && (btCard.panelExpanded || btCard.shouldExpand)) ||
                                               (caffeineCard && caffeineCard.panelExpanded) ||
                                               (sysMonitorCard && sysMonitorCard.panelExpanded)

    ListModel { id: wifiModel }

    Component.onCompleted: {
        detectWifiAdapterProc.running = true
        detectBtAdapterProc.running = true
        fetchWifiStatusProc.running = true
    }

    ColumnLayout {
        id: mainLayout
        
        // Define explicit width and top-left anchoring to prevent parent stretch locking
        width: 400
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.cardMargin
        anchors.leftMargin: root.cardMargin
        spacing: root.cardMargin / 2

        enabled: !root.isAnyPanelExpanded

        // TOP HEADER & TOGGLES CONTAINER CARD
        Rectangle {
            id: topHeaderCard
            Layout.fillWidth: true
            implicitWidth: 400
            // Inline Comment: Reduced height addition to match half-margin top/bottom (cardMargin/2 * 2 = cardMargin)
            implicitHeight: topHeaderLayout.implicitHeight + (root.cardMargin * 2)
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.04)

            // GRAPHIC WATERMARK
            Item {
                anchors.fill: parent
                clip: true

                Watermark {
                    icon: Config.getIcon("cc")
                    iconSize: 150
                    seed: 25
                }
            }

            z: ((wifiCard && (wifiCard.panelExpanded || wifiCard.shouldExpand)) || (btCard && (btCard.panelExpanded || btCard.shouldExpand)) || (caffeineCard && caffeineCard.panelExpanded)) ? 1000 : 1

            ColumnLayout {
                id: topHeaderLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                // Inline Comment: Reduced outer padding around the title and toggle cards
                anchors.margins: root.cardMargin
                spacing: root.cardMargin / 2

                Item {
                    implicitWidth: ccTitleText.implicitWidth
                    implicitHeight: ccTitleText.implicitHeight
                    Layout.fillWidth: true

                    Glow {
                        anchors.fill: ccTitleText
                        source: ccTitleText
                        radius: 8
                        samples: 16
                        color: Config.accent
                        spread: 0.2
                        transparentBorder: true
                        visible: Config.clockShowGlow
                    }

                    Text {
                        id: ccTitleText
                        anchors.fill: parent
                        text: "CONTROL CENTER"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontTitle)
                        font.bold: true
                        font.italic: true
                    }
                }

                RowLayout {
                    id: topHeaderRow
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: root.cardMargin / 2
                    z: (caffeineCard && caffeineCard.panelExpanded) ? 1000 : 1

                    CaffeineCard {
                        id: caffeineCard
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        controlCenterPanel: root
                    }

                    DndCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                    }
                }

                RowLayout {
                    id: staticToggleRow
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: root.cardMargin / 2

                    z: ((wifiCard && (wifiCard.panelExpanded || wifiCard.shouldExpand)) || (btCard && (btCard.panelExpanded || btCard.shouldExpand))) ? 1000 : 1

                    WifiCard {
                        id: wifiCard
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        hasAdapter: root.hasWifiAdapter
                        controlCenterPanel: root
                        wifiPowered: root.wifiPowered
                        wifiScanning: root.wifiScanning
                        activeSsid: root.activeSsid
                        expandedSsid: root.expandedSsid
                        connectingSsid: root.connectingSsid
                        disconnectingSsid: root.disconnectingSsid
                        errorSsid: root.errorSsid
                        connectionError: root.connectionError
                        knownNetworks: root.knownNetworks
                        wifiModel: wifiModel
                        onTogglePower: power => root.toggleWifiPower(power)
                        onTriggerScan: root.triggerWifiScan()
                        onConnectTo: (ssid, pass, isKnown) => connectWifiProc.connectTo(ssid, pass, isKnown)
                        onDisconnectSsid: ssid => disconnectWifiProc.disconnect(ssid)
                        onForgetSsid: ssid => forgetWifiProc.forget(ssid)
                    }

                    BluetoothCard {
                        id: btCard
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        hasHardware: root.hasBtAdapter
                        controlCenterPanel: root
                        onTogglePower: power => btCard.execTogglePower(power)
                        onTriggerScan: btCard.execTriggerScan()
                    }
                }
            }
        }

        SystemMonitorCard {
            id: sysMonitorCard
            controlCenterPanel: root
            z: panelExpanded ? 1000 : 1
        }

        SlidersCard {
            id: slidersCardComponent
            currentBrightness: root.currentBrightness
            hasBacklight: root.hasBacklight
            currentVolume: root.currentVolume
            isAudioMuted: root.isAudioMuted
            onBrightnessChanged: pct => root.setBrightness(pct)
            onVolumeChanged: pct => root.setVolume(pct)
            onIsUserDraggingVolChanged: root.isUserDraggingVol = isUserDraggingVol
        }

        MediaCard {
            id: mediaCardComponent
            onSendCommand: cmd => {
                mediaControlProc.command = cmd
                mediaControlProc.running = true
            }
        }
    }

    // Keep ControlCenter aligned with shellRoot unless actively dragging/setting
    Connections {
        target: shellRoot
        function onAudioVolumeChanged() {
            if (!root.isUserDraggingVol && !root.isSettingVolume) {
                root.currentVolume = shellRoot.audioVolume
            }
        }
        function onAudioMutedChanged() {
            root.isAudioMuted = shellRoot.audioMuted
        }
    }

    Process { id: mediaControlProc; running: false }

    Process {
        id: mediaFollower
        command: ["playerctl", "--player=%any,playerctld", "--follow", "--format", '{"title": "{{title}}", "artist": "{{artist}}", "status": "{{status}}", "art": "{{mpris:artUrl}}"}', "metadata"]
        running: Config.showControlCenter
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    let parsed = JSON.parse(data.trim());
                    if (parsed.status === "Stopped" || !parsed.title || parsed.title.trim() === "") {
                        mediaCardComponent.mediaTitle = "Not Playing";
                        mediaCardComponent.mediaArtist = "---"; 
                        mediaCardComponent.mediaStatus = "Stopped";
                        mediaCardComponent.mediaArtUrl = "";
                    } else {
                        mediaCardComponent.mediaTitle = parsed.title;
                        mediaCardComponent.mediaArtist = parsed.artist || "Unknown Artist";
                        mediaCardComponent.mediaStatus = parsed.status;
                        mediaCardComponent.mediaArtUrl = parsed.art || "";
                    }
                } catch(e) {
                    mediaCardComponent.mediaTitle = "Not Playing";
                    mediaCardComponent.mediaArtist = "---";
                    mediaCardComponent.mediaStatus = "Stopped";
                    mediaCardComponent.mediaArtUrl = "";
                }
            }
        }
    }

    Process {
        id: cavaProc
        command: ["fish", "-c", "printf '[general]\\nbars = 32\\nsensitivity = 150\\n[output]\\nmethod = raw\\ndata_format = ascii\\nascii_max_range = 255\\nbar_delimiter = 59\\nframe_delimiter = 10\\n' | cava -p /dev/stdin"]
        running: Config.showControlCenter && mediaCardComponent.mediaStatus === "Playing"
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                let clean = data.trim();
                if (!clean) return;
                
                let points = clean.split(';');
                let arr = [];
                
                for (let i = 0; i < points.length; i++) {
                    if (points[i] !== "") {
                        arr.push(parseInt(points[i], 10) || 0);
                    }
                }
                
                if (arr.length > 0) {
                    mediaCardComponent.cavaBars = arr;
                }
            }
        }
    }

    Process {
        id: detectWifiAdapterProc
        command: ["fish", "-c", "nmcli -t -f TYPE device | grep -q '^wifi$' && echo 'YES' || echo 'NO'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasWifiAdapter = this.text.trim() === "YES"
            }
        }
    }

    Process {
        id: detectBtAdapterProc
        command: ["fish", "-c", "bluetoothctl list | grep -q 'Controller' && echo 'YES' || echo 'NO'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let res = this.text.trim() === "YES"
                if (root.hasBtAdapter !== res) root.hasBtAdapter = res
            }
        }
    }

    Process {
        id: detectBacklightProc
        command: ["fish", "-c", "brightnessctl --list | grep -q 'backlight' && echo 'YES' || echo 'NO'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasBacklight = this.text.trim() === "YES"
                if (root.hasBacklight) fetchBrightnessProc.running = true
            }
        }
    }

    Process {
        id: fetchBrightnessProc
        command: ["fish", "-c", "brightnessctl -m | cut -d',' -f4 | tr -d '%'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let val = parseInt(this.text.trim())
                if (!isNaN(val)) root.currentBrightness = val
            }
        }
    }

    Process {
        id: setBrightnessProc
        running: false
        function setVal(pct) {
            command = ["fish", "-c", `brightnessctl set ${pct}%`]
            running = true
        }
    }

    Process {
        id: setVolumeProc
        running: false
        function setVal(pct) {
            let floatVal = (pct / 100.0).toFixed(2)
            command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", `${floatVal}`]
            running = true
        }

        onExited: {
            root.isSettingVolume = false
            if (typeof shellRoot !== "undefined") shellRoot.isUserSettingVolume = false
        }
    }

    function setBrightness(pct) {
        root.currentBrightness = pct
        setBrightnessProc.setVal(pct)
    }

    function setVolume(pct) {
        root.isSettingVolume = true
        if (typeof shellRoot !== "undefined") shellRoot.isUserSettingVolume = true
        root.currentVolume = pct
        setVolumeProc.setVal(pct)
    }

    function triggerWifiScan() {
        if (root.hasWifiAdapter && root.wifiPowered && !root.wifiScanning) scanWifiProc.startScan()
    }

    function toggleWifiPower(turnOn) {
        if (!root.hasWifiAdapter) return
        toggleWifiProc.command = ["fish", "-c", turnOn ? "rfkill unblock wifi; nmcli radio wifi on" : "nmcli radio wifi off"]
        toggleWifiProc.running = true
    }

    Process {
        id: toggleWifiProc
        running: false
        onExited: fetchWifiStatusProc.running = true
    }

    Process {
        id: scanWifiProc
        command: ["nmcli", "dev", "wifi", "rescan"]
        running: false
        
        function startScan() {
            root.wifiScanning = true
            running = true
        }

        onExited: {
            root.wifiScanning = false
            fetchWifiStatusProc.running = true
        }
    }

    Process {
        id: disconnectWifiProc
        running: false
        function disconnect(ssid) {
            root.disconnectingSsid = ssid
            command = ["nmcli", "connection", "down", "id", ssid]
            running = true
        }
        onExited: {
            root.disconnectingSsid = ""
            fetchWifiStatusProc.running = true
        }
    }

    Process {
        id: forgetWifiProc
        running: false
        function forget(ssid) {
            root.errorSsid = ""
            root.connectionError = ""
            let safeSsid = ssid.replace(/'/g, "'\"'\"'")
            command = ["fish", "-c", `
                set uuids (nmcli -t -f UUID,TYPE,NAME connection show | awk -F: -v target='${safeSsid}' '$2 ~ /802-11-wireless|wifi/ && $3 == target {print $1}')
                for u in $uuids
                    nmcli connection delete uuid "$u"
                end
            `]
            running = true
        }
        onExited: {
            root.errorSsid = ""
            root.connectionError = ""
            fetchWifiStatusProc.running = false
            fetchWifiStatusProc.running = true
        }
    }

    Process {
        id: cleanupWifiProc
        running: false
        onExited: {
            fetchWifiStatusProc.running = false
            fetchWifiStatusProc.running = true
        }
    }

    Process {
        id: connectWifiProc
        running: false
        property string activeTargetSsid: ""

        stdout: StdioCollector { id: connectStdout }
        stderr: StdioCollector { id: connectStderr }

        function connectTo(ssidTarget, password, isKnown) {
            activeTargetSsid = ssidTarget
            root.connectingSsid = ssidTarget
            root.errorSsid = ""
            root.connectionError = ""

            let safeSsid = ssidTarget.replace(/'/g, "'\"'\"'")
            let cmd = ""
            if (password && password.trim() !== "") {
                let safePass = password.replace(/'/g, "'\"'\"'")
                cmd = `nmcli dev wifi connect '${safeSsid}' password '${safePass}'`
            } else if (isKnown) {
                cmd = `nmcli connection up id '${safeSsid}'`
            } else {
                cmd = `nmcli dev wifi connect '${safeSsid}'`
            }
            command = ["fish", "-c", cmd]
            running = false
            running = true
        }

        onExited: (exitCode) => {
            let failedSsid = activeTargetSsid
            root.connectingSsid = ""

            if (exitCode !== 0 && failedSsid !== "") {
                root.errorSsid = failedSsid
                root.expandedSsid = failedSsid
                let fullErr = (connectStdout.text + "\n" + connectStderr.text).trim().toLowerCase()
                if (fullErr.includes("not found") || fullErr.includes("no network")) {
                    root.connectionError = "Network Not Found"
                } else {
                    root.connectionError = "Invalid Password"
                }

                let safeSsid = failedSsid.replace(/'/g, "'\"'\"'")
                cleanupWifiProc.command = ["fish", "-c", `
                    set uuids (nmcli -t -f UUID,TYPE,NAME connection show | awk -F: -v target='${safeSsid}' '$2 ~ /802-11-wireless|wifi/ && $3 == target {print $1}')
                    for u in $uuids
                        nmcli connection delete uuid "$u" 2>/dev/null
                    end
                `]
                cleanupWifiProc.running = false
                cleanupWifiProc.running = true
            } else {
                root.errorSsid = ""
                root.connectionError = ""
                fetchWifiStatusProc.running = false
                fetchWifiStatusProc.running = true
            }
        }
    }

    Process {
        id: fetchWifiStatusProc
        command: ["fish", "-c", "nmcli radio wifi; echo '---'; nmcli -t -f ACTIVE,SIGNAL,SECURITY,SSID dev wifi; echo '---'; nmcli -t -f NAME connection show"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("---")
                if (parts.length < 2) return
                root.wifiPowered = parts[0].trim() === "enabled"
                if (!root.wifiPowered || !root.hasWifiAdapter) {
                    wifiModel.clear()
                    return
                }

                let knownMap = {}
                if (parts.length >= 3) {
                    let knownLines = parts[2].trim().split("\n")
                    for (let j = 0; j < knownLines.length; j++) {
                        let name = knownLines[j].trim()
                        if (name) knownMap[name] = true
                    }
                }
                root.knownNetworks = knownMap

                let lines = parts[1].trim().split("\n")
                let uniqueMap = {}
                let activeSsidFound = ""

                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()
                    if (!line) continue
                    let tokens = line.split(":")
                    if (tokens.length < 4) continue

                    let isActive = tokens[0].trim() === "yes"
                    let signal = parseInt(tokens[1].trim()) || 0
                    let sec = tokens[2].trim()
                    let ssid = tokens.slice(3).join(":").trim()
                    if (!ssid) continue

                    if (isActive) activeSsidFound = ssid
                    let isSecure = sec !== "--" && sec !== ""

                    if (!uniqueMap[ssid]) {
                        uniqueMap[ssid] = { ssid: ssid, signalStrength: signal, connected: isActive, isSecure: isSecure }
                    } else {
                        if (isActive) uniqueMap[ssid].connected = true
                        if (signal > uniqueMap[ssid].signalStrength) uniqueMap[ssid].signalStrength = signal
                    }
                }

                root.activeSsid = activeSsidFound
                let newResults = Object.values(uniqueMap).sort((a, b) => b.signalStrength - a.signalStrength)

                let existingMap = {}
                for (let idx = 0; idx < wifiModel.count; idx++) existingMap[wifiModel.get(idx).ssid] = idx
                let freshMap = {}

                for (let k = 0; k < newResults.length; k++) {
                    let item = newResults[k]
                    freshMap[item.ssid] = true
                    if (item.ssid in existingMap) {
                        let tIndex = existingMap[item.ssid]
                        wifiModel.setProperty(tIndex, "connected", item.connected)
                        wifiModel.setProperty(tIndex, "signalStrength", item.signalStrength)
                    } else {
                        wifiModel.append(item)
                    }
                }
                for (let r = wifiModel.count - 1; r >= 0; r--) {
                    if (!freshMap[wifiModel.get(r).ssid]) wifiModel.remove(r)
                }
            }
        }
    }

    Connections {
        target: Config
        function onShowControlCenterChanged() {
            if (Config.showControlCenter) {
                detectWifiAdapterProc.running = false
                detectWifiAdapterProc.running = true
                detectBtAdapterProc.running = false
                detectBtAdapterProc.running = true
                fetchWifiStatusProc.running = false
                fetchWifiStatusProc.running = true
                if (root.hasBacklight) {
                    fetchBrightnessProc.running = false
                    fetchBrightnessProc.running = true
                }
            }
        }
    }

    Timer {
        interval: 3500
        running: Config.showControlCenter
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            fetchWifiStatusProc.running = true
            if (root.hasBacklight) fetchBrightnessProc.running = true
        }
    }
}