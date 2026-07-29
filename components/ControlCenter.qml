import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "controlcenter"

Item {
    id: root

    implicitWidth: 380
    implicitHeight: mainLayout.implicitHeight + 24

    // --- State Properties ---
    property bool wifiPowered: false
    property bool wifiScanning: false
    property string activeSsid: ""
    property string expandedSsid: ""
    property string connectingSsid: ""
    property var knownNetworks: ({})

    // Bind directly to global shell state to eliminate loading latency & jumps
    property int currentVolume: shellRoot.audioVolume
    property bool isAudioMuted: shellRoot.audioMuted
    property bool isUserDraggingVol: false
    property int currentBrightness: 100
    property bool hasBacklight: false

    // Local override guard
    property bool isSettingVolume: false

    ListModel { id: wifiModel }

    Component.onCompleted: {
        fetchWifiStatusProc.running = true
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // TOP HEADER & TOGGLES CONTAINER CARD
        Rectangle {
            id: topHeaderCard
            Layout.fillWidth: true
            implicitHeight: topHeaderLayout.implicitHeight + 24
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.04)

            z: 100

            ColumnLayout {
                id: topHeaderLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 12

                Text {
                    text: "CONTROL CENTER"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontTitle)
                    font.bold: true
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 8

                    CaffeineCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
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
                    spacing: 8

                    z: (wifiCard.shouldExpand || btCard.shouldExpand) ? 10 : 1

                    WifiCard {
                        id: wifiCard
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        wifiPowered: root.wifiPowered
                        wifiScanning: root.wifiScanning
                        activeSsid: root.activeSsid
                        expandedSsid: root.expandedSsid
                        connectingSsid: root.connectingSsid
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
                        onTogglePower: power => btCard.execTogglePower(power)
                        onTriggerScan: btCard.execTriggerScan()
                    }
                }
            }
        }

        BrightnessCard {
            currentBrightness: root.currentBrightness
            hasBacklight: root.hasBacklight
            onBrightnessChanged: pct => setBrightnessProc.setVal(pct)
        }

        VolumeCard {
            id: volumeCard
            currentVolume: root.currentVolume
            isAudioMuted: root.isAudioMuted
            onIsUserDraggingVolChanged: {
                root.isUserDraggingVol = volumeCard.isUserDraggingVol
                if (typeof shellRoot !== "undefined") shellRoot.isUserSettingVolume = volumeCard.isUserDraggingVol
            }
            onVolumeChanged: pct => {
                root.isSettingVolume = true
                if (typeof shellRoot !== "undefined") shellRoot.isUserSettingVolume = true
                root.currentVolume = pct
                setVolumeProc.setVal(pct)
            }
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

    function triggerWifiScan() {
        if (root.wifiPowered && !root.wifiScanning) scanWifiProc.startScan()
    }

    function toggleWifiPower(turnOn) {
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
            command = ["nmcli", "connection", "down", "id", ssid]
            running = true
        }
        onExited: fetchWifiStatusProc.running = true
    }

    Process {
        id: forgetWifiProc
        running: false
        function forget(ssid) {
            command = ["nmcli", "connection", "delete", "id", ssid]
            running = true
        }
        onExited: fetchWifiStatusProc.running = true
    }

    Process {
        id: connectWifiProc
        running: false
        function connectTo(ssidTarget, password, isKnown) {
            root.connectingSsid = ssidTarget
            let safeSsid = ssidTarget.replace(/'/g, "'\\''")
            let safePass = password ? password.replace(/'/g, "'\\''") : ""

            if (isKnown) {
                command = ["fish", "-c", `nmcli connection up id '${safeSsid}'`]
            } else if (!password || password.trim() === "") {
                command = ["fish", "-c", `nmcli dev wifi connect '${safeSsid}'`]
            } else {
                command = ["fish", "-c", `nmcli dev wifi connect '${safeSsid}' password '${safePass}'`]
            }
            running = true
        }
        onExited: {
            root.connectingSsid = ""
            fetchWifiStatusProc.running = true
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
                if (!root.wifiPowered) {
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