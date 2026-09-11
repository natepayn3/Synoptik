import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Notifications as Notifs
import "controlcenter"

Item {
    id: root

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    // Derive root dimensions from the master bento grid
    implicitWidth: ccGrid.width + (cardMargin * 2)
    implicitHeight: ccGrid.height + (cardMargin * 2)

    // Compiled-in starting arrangement for the ControlCenter bento grid (two
    // lanes, left/right - see DraggableGridContainer.qml). Only used until
    // the user actually drags a card, at which point the result is saved to
    // Config.ccCardArrangement and this is ignored. Each card's actual size
    // is declared on its own GridCard below, not here.
    readonly property var defaultCcOrder: ["controls", "sliders", "sysMonitor", "notifications", "media"]
    readonly property var defaultCcLanes: ({ controls: 0, sliders: 0, sysMonitor: 1, notifications: 1 })

    // --- State Properties ---
    // Wi-Fi and Bluetooth state is owned by Config.network / Config.bluetooth
    // (see NetworkService.qml and BluetoothService.qml). This panel used to
    // carry a complete nmcli implementation of its own, duplicated again in
    // Settings' WifiSettings page; both now read the same live model.
    readonly property var net: Config.network

    readonly property bool hasWifiAdapter: net.hasAdapter
    readonly property bool hasAdapter: net.hasAdapter
    readonly property bool hasBtAdapter: Config.bluetooth.available
    readonly property bool wifiPowered: net.powered
    readonly property bool wifiScanning: net.scanning
    readonly property string activeSsid: net.activeSsid
    property string expandedSsid: ""
    readonly property string connectingSsid: net.connectingSsid
    readonly property string disconnectingSsid: net.disconnectingSsid
    readonly property string errorSsid: net.errorSsid
    readonly property string connectionError: net.connectionError
    readonly property var knownNetworks: net.knownNetworks

    property int currentVolume: shellRoot.audioVolume
    property bool isAudioMuted: shellRoot.audioMuted
    property bool isUserDraggingVol: false
    property int currentBrightness: 100
    property bool hasBacklight: false
    property bool isSettingVolume: false

    readonly property int notifCount: (typeof shellRoot !== "undefined" && shellRoot.activeNotifs !== undefined)
        ? shellRoot.activeNotifs
        : ((typeof notifServer !== "undefined" && notifServer.trackedNotifications) ? notifServer.trackedNotifications.values.length : 0)

    property bool showNotifHistory: false
    readonly property int notifHistoryCount: Config.notificationHistory ? Config.notificationHistory.length : 0

    function notifRelativeTime(ts) {
        if (!ts) return ""
        let mins = Math.floor((Date.now() - ts) / 60000)
        if (mins < 1) return "Just now"
        if (mins < 60) return mins + "m ago"
        let hours = Math.floor(mins / 60)
        if (hours < 24) return hours + "h ago"
        return Math.floor(hours / 24) + "d ago"
    }

    readonly property bool isAnyPanelExpanded: (wifiCard && (wifiCard.panelExpanded || wifiCard.shouldExpand)) ||
                                               (btCard && (btCard.panelExpanded || btCard.shouldExpand)) ||
                                               (caffeineCard && caffeineCard.panelExpanded) ||
                                               (sysMonitorCard && sysMonitorCard.panelExpanded)

    readonly property var wifiModel: net.networks

    function clearAllNotifications() {
        if (typeof notifServer === "undefined" || !notifServer.trackedNotifications) return;
        let notifs = notifServer.trackedNotifications.values;
        if (!notifs) return;
        
        for (let i = notifs.length - 1; i >= 0; i--) {
            if (notifs[i]) notifs[i].dismiss();
        }
        if (typeof shellRoot !== "undefined" && shellRoot.updateNotifCount) {
            Qt.callLater(shellRoot.updateNotifCount);
        }
    }


    // MAIN BENTO GRID - cards are DraggableGridContainer/GridCard-positioned so
    // they can always be dragged (grab anywhere on a card) to reorder; see
    // DraggableGridContainer.qml for the lane-balancing/reflow rules.
    DraggableGridContainer {
        id: ccGrid
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: root.cardMargin
        spacing: root.cardMargin / 2
        enabled: !root.isAnyPanelExpanded

        Connections {
            target: Config
            function onIsLoadedChanged() {
                if (Config.isLoaded) ccGrid.initArrangement(root.defaultCcOrder, root.defaultCcLanes, Config.ccCardArrangement)
            }
        }
        // Applies the compiled-in default arrangement immediately (rather than
        // waiting on Config's async file read, which can take a couple of
        // seconds) so cards never sit piled on top of each other at start-up -
        // if there's a saved arrangement it re-applies moments later via
        // onIsLoadedChanged above, springing into place instead.
        Component.onCompleted: {
            ccGrid.initArrangement(root.defaultCcOrder, root.defaultCcLanes, Config.isLoaded ? Config.ccCardArrangement : null)
        }
        onArrangementCommitted: {
            Config.ccCardArrangement = { order: ccGrid.order, lanes: ccGrid.lanes }
            Config.saveSettings()
        }

        // COMBINED HEADER & 4 TOGGLES CARD
        GridCard {
            id: controlsGridCard
            container: ccGrid
            cardId: "controls"
            colSpan: 4
            naturalHeight: topControlsCard.implicitHeight

            // ClippingRectangle (not plain Rectangle) so the watermark actually
            // respects the rounded corners instead of bleeding past them - plain
            // Rectangle.clip (and the inner plain-Item clip this used to rely on)
            // only clips to the square bounding box.
            ClippingRectangle {
                id: topControlsCard
                anchors.fill: parent
                implicitHeight: topControlsLayout.implicitHeight + (root.cardMargin * 2)
                radius: Config.cornerRadius
                color: Qt.rgba(255, 255, 255, 0.04)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.1)

                Behavior on border.color { ColorAnimation { duration: 150 } }

                Watermark {
                    icon: Config.getIcon("cc")
                    iconSize: 150
                    seed: 25
                }

                ColumnLayout {
                        id: topControlsLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: root.cardMargin
                        spacing: root.cardMargin / 2

                        // 2x2 Toggles Grid (Row 1)
                        RowLayout {
                            Layout.fillWidth: true
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
                                // MUST stay qualified. WifiCard declares its
                                // own `property var wifiModel`, and inside this
                                // block that shadows the outer one - so a bare
                                // `wifiModel: wifiModel` is a self-reference
                                // that silently evaluates to undefined. It only
                                // worked before because the model was an
                                // `id` here, and ids outrank properties in QML
                                // scope resolution.
                                wifiModel: root.wifiModel
                                onTogglePower: power => root.net.setPowered(power)
                                onTriggerScan: root.net.scan()
                                onConnectTo: (ssid, pass, isKnown) => root.net.connectTo(ssid, pass, isKnown)
                                onDisconnectSsid: ssid => root.net.disconnect(ssid)
                                onForgetSsid: ssid => root.net.forget(ssid)
                            }

                            BluetoothCard {
                                id: btCard
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                // BluetoothCard used to expose togglePower/
                                // triggerScan signals that this panel handled
                                // by calling straight back into the card. Now
                                // that the card talks to Config.bluetooth
                                // directly, its own controls call those
                                // functions and the round trip is gone.
                                controlCenterPanel: root
                            }
                        }

                        // 2x2 Toggles Grid (Row 2)
                        RowLayout {
                            Layout.fillWidth: true
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
                    }
                }
            }

        // Sliders Card
        GridCard {
            id: slidersGridCard
            container: ccGrid
            cardId: "sliders"
            colSpan: 4
            naturalHeight: slidersCardComponent.implicitHeight

            SlidersCard {
                id: slidersCardComponent
                anchors.fill: parent
                currentBrightness: root.currentBrightness
                hasBacklight: root.hasBacklight
                currentVolume: root.currentVolume
                isAudioMuted: root.isAudioMuted
                onBrightnessChanged: pct => root.setBrightness(pct)
                onVolumeChanged: pct => root.setVolume(pct)
                onIsUserDraggingVolChanged: root.isUserDraggingVol = isUserDraggingVol
            }
        }

        // SYSTEM MONITOR
        GridCard {
            id: sysMonitorGridCard
            container: ccGrid
            cardId: "sysMonitor"
            colSpan: 4
            naturalHeight: sysMonitorCard.implicitHeight

            SystemMonitorCard {
                id: sysMonitorCard
                anchors.fill: parent
                controlCenterPanel: root
            }
        }

        // NOTIFICATION HUB (Full-Height Grounded Container)
        GridCard {
            id: notifGridCard
            container: ccGrid
            cardId: "notifications"
            colSpan: 4
            naturalHeight: notifHubContainer.implicitHeight

            // ClippingRectangle (not plain Rectangle) so the watermark actually
            // respects the rounded corners instead of bleeding past them - plain
            // Rectangle.clip only clips to the square bounding box.
            ClippingRectangle {
                id: notifHubContainer
                anchors.fill: parent
                // Notification count is unbounded (the list scrolls internally),
                // so there's no real "fits everything" height like the other
                // cards have - this is just a reasonable minimum viewport
                // (header + tabs + a handful of rows) for it to ask the lane
                // balancer for; it's free to end up taller to match its neighbor.
                implicitHeight: 260
                radius: Config.cornerRadius
                color: Qt.rgba(255, 255, 255, 0.04)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.1)

                Behavior on border.color { ColorAnimation { duration: 150 } }

                Watermark {
                    icon: Config.getIcon("notifications")
                    iconSize: 160
                    seed: 10
                }

                ColumnLayout {
                    anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // Aligned Header Row
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            spacing: 8

                            Text {
                                text: root.notifCount > 0 ? "notifications_active" : "notifications"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 20
                                color: root.notifCount > 0 ? Config.accent : Config.textMuted
                            }

                            Item {
                                implicitWidth: notifTitle.implicitWidth
                                implicitHeight: notifTitle.implicitHeight
                                Layout.fillWidth: true

                                Text {
                                    id: notifTitle
                                    anchors.fill: parent
                                    text: "NOTIFICATIONS"
                                    color: Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: true
                                    font.italic: true
                                }

                                Glow {
                                    anchors.fill: notifTitle
                                    source: notifTitle
                                    radius: 6
                                    samples: 12
                                    color: Config.accent
                                    spread: 0.2
                                    transparentBorder: true
                                    visible: Config.clockShowGlow && root.notifCount > 0
                                }
                            }

                            Rectangle {
                                implicitWidth: clearBtnText.implicitWidth + 14
                                implicitHeight: 22
                                radius: 11
                                visible: root.showNotifHistory ? root.notifHistoryCount > 0 : root.notifCount > 0
                                color: clearHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                                border.width: 1
                                border.color: clearHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.12)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    id: clearBtnText
                                    anchors.centerIn: parent
                                    text: "CLEAR"
                                    color: clearHover.hovered ? Config.accent : Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: true
                                }

                                TapHandler { onTapped: root.showNotifHistory ? Config.clearNotificationHistory() : root.clearAllNotifications() }
                                HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }

                        // Active / History Tabs
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: [
                                    { label: "Active", history: false },
                                    { label: "History", history: true }
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 22
                                    radius: Config.cornerRadius / 2

                                    readonly property bool isSelected: root.showNotifHistory === modelData.history
                                    color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (notifTabHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: parent.isSelected ? Config.accent : Config.textMuted
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontMicro)
                                        font.bold: true
                                    }

                                    TapHandler { onTapped: root.showNotifHistory = modelData.history }
                                    HoverHandler { id: notifTabHover; cursorShape: Qt.PointingHandCursor }
                                }
                            }
                        }

                        // Scrollable List View
                        ListView {
                            id: notifListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 8
                            boundsBehavior: Flickable.StopAtBounds
                            visible: root.showNotifHistory ? root.notifHistoryCount > 0 : root.notifCount > 0

                            model: root.showNotifHistory
                                ? (Config.notificationHistory || [])
                                : ((typeof notifServer !== "undefined" && notifServer.trackedNotifications)
                                    ? notifServer.trackedNotifications.values
                                    : [])

                            delegate: Rectangle {
                                id: notifRow
                                width: notifListView.width
                                implicitHeight: itemLayout.implicitHeight + 16
                                radius: Config.cornerRadius * 0.5
                                color: cardMouse.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.25)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                // Urgency was previously read only by the OSD
                                // and thrown away when the entry was recorded,
                                // so in this list a battery-critical warning
                                // looked exactly like a track change. It is
                                // persisted now (see NotificationHistoryService)
                                // and drives the same red the OSD uses.
                                readonly property bool isCritical:
                                    modelData && modelData.urgency === 2

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 4
                                    width: 3
                                    radius: 1.5
                                    color: "#ef4444"
                                    visible: notifRow.isCritical
                                }

                                ColumnLayout {
                                    id: itemLayout
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 10
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: (modelData && modelData.appName) ? modelData.appName.toUpperCase() : "SYSTEM"
                                            color: notifRow.isCritical ? "#ef4444" : Config.accent
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontMicro)
                                            font.bold: true
                                            font.italic: true
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            visible: root.showNotifHistory
                                            text: modelData ? root.notifRelativeTime(modelData.timestamp) : ""
                                            color: Config.textMuted
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontMicro)
                                        }
                                    }

                                    Text {
                                        visible: modelData && modelData.summary !== ""
                                        text: (modelData && modelData.summary) ? modelData.summary : ""
                                        color: Config.textMain
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontCaption)
                                        font.bold: true
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                    }

                                    Text {
                                        visible: modelData && modelData.body !== ""
                                        text: (modelData && modelData.body) ? modelData.body : ""
                                        color: Config.textMuted
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontMicro)
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                    }
                                }

                                Rectangle {
                                    visible: !root.showNotifHistory
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 6
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    radius: 9
                                    color: closeHover.hovered ? Qt.rgba(255, 255, 255, 0.2) : "transparent"
                                    opacity: cardMouse.hovered ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "close"
                                        color: closeHover.hovered ? Config.accent : Config.textMuted
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 13
                                    }

                                    TapHandler {
                                        onTapped: {
                                            if (modelData) modelData.dismiss();
                                        }
                                    }
                                    HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                                }

                                HoverHandler { id: cardMouse }
                            }
                        }

                        // Centered Empty State Placeholder
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.showNotifHistory ? root.notifHistoryCount === 0 : root.notifCount === 0

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: "notifications_off"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 36
                                    color: Config.textMuted
                                    opacity: 0.35
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: root.showNotifHistory ? "No notification history yet" : "No notifications"
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: true
                                    color: Config.textMuted
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }

        // ==========================================
        // BOTTOM: FULL WIDTH GROUNDED MEDIA CARD
        // ==========================================
        GridCard {
            id: mediaGridCard
            container: ccGrid
            cardId: "media"
            colSpan: 8
            naturalHeight: mediaCardComponent.implicitHeight

            MediaCard {
                id: mediaCardComponent
                anchors.fill: parent
                controlCenterPanel: root
                onSendCommand: cmd => {
                    mediaControlProc.command = cmd
                    mediaControlProc.running = true
                }
            }
        }
    }

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
        id: cavaProc
        command: ["sh", "-c", "printf '[general]\\nbars = 32\\nsensitivity = 150\\n[output]\\nmethod = raw\\ndata_format = ascii\\nascii_max_range = 255\\nbar_delimiter = 59\\nframe_delimiter = 10\\n' | cava -p /dev/stdin"]
        running: Config.showControlCenter && mediaCardComponent.mediaStatus === "Playing"
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                let clean = data.trim();
                if (!clean) return;
                
                let points = clean.split(';');
                let arr = [];
                for (let i = 0; i < points.length; i++) {
                    if (points[i] !== "") arr.push(parseInt(points[i], 10) || 0);
                }
                if (arr.length > 0) mediaCardComponent.cavaBars = arr;
            }
        }
    }

    // detectWifiAdapterProc and detectBtAdapterProc used to live here, shelling
    // out to `nmcli -t -f TYPE device` and `bluetoothctl list` to find out
    // whether the hardware existed. Both services report that directly now.

    Process {
        id: detectBacklightProc
        command: ["sh", "-c", "brightnessctl --list | grep -q 'backlight' && echo 'YES' || echo 'NO'"]
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
        command: ["sh", "-c", "brightnessctl -m | cut -d',' -f4 | tr -d '%'"]
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
            command = ["sh", "-c", `brightnessctl set ${pct}%`]
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

    // The Wi-Fi backend that used to occupy this space - scan, toggle,
    // connect, disconnect, forget, cleanup and a status poller, seven Process
    // blocks in all - now lives once in NetworkService.qml. Along with the
    // duplication that removed the SSID-into-shell-string quoting and the
    // `awk -v target=...` matching that silently failed on any SSID
    // containing a backslash.

    // Opening the panel used to kick off five refetches and start a 3.5s Wi-Fi
    // poll. Wi-Fi and Bluetooth are event-driven now, so only brightness - which
    // has no change notification of its own - still needs asking.
    Connections {
        target: Config
        function onShowControlCenterChanged() {
            if (Config.showControlCenter && root.hasBacklight) {
                fetchBrightnessProc.running = false
                fetchBrightnessProc.running = true
            }
        }
    }

    Timer {
        interval: 3500
        running: Config.showControlCenter && root.hasBacklight
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchBrightnessProc.running = true
    }
}