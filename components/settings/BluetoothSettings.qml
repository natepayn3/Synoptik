import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: root

    // Shared with the Control Center's BluetoothCard via Config.bluetooth -
    // see BluetoothService.qml. This page used to run its own parallel
    // bluetoothctl implementation on a 3s poll, including a second copy of the
    // device-icon table that had drifted out of sync with the card's.
    readonly property var bt: Config.bluetooth

    readonly property bool hasPolledOnce: true
    readonly property bool hasAdapter: bt.available
    readonly property bool isPowered: bt.powered
    readonly property bool isScanning: bt.scanning
    readonly property string activeDeviceName: bt.connectedNames
    readonly property string connectingMac: bt.connectingMac

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    readonly property var btModel: bt.devices

    // Single implementations now live in BluetoothService; these stay as
    // thin forwarders so the delegates below read unchanged.
    function batteryGlyph(pct) { return bt.batteryGlyph(pct) }
    function batteryColor(pct) { return bt.batteryColor(pct) }

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
                    text: "BLUETOOTH WIRELESS"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontSubhead)
                    font.bold: true
                }

                Text {
                    text: "Manage Bluetooth controller state, discover discoverable peripherals, pair wireless audio accessories, and configure trusted devices."
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }

            // ==========================================
            // 1. HERO CONTROLLER & STATUS CARD
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: heroRow.implicitHeight + 28
                radius: Config.cornerRadius
                color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
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
                        color: (root.isPowered && root.hasAdapter)
                            ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2)
                            : Qt.rgba(255, 255, 255, 0.06)
                        border.width: 1.5
                        border.color: (root.isPowered && root.hasAdapter) ? Config.accent : Qt.rgba(255, 255, 255, 0.15)

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Text {
                            anchors.centerIn: parent
                            text: !root.hasAdapter ? "bluetooth_disabled" : (root.isPowered ? (root.activeDeviceName !== "" ? "bluetooth_connected" : "bluetooth") : "bluetooth_disabled")
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            color: (root.isPowered && root.hasAdapter) ? Config.accent : Config.textMuted
                        }
                    }

                    // Status Text
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 8
                            Text {
                                text: "Bluetooth Adapter"
                                font.family: Config.sysFont
                                font.bold: true
                                color: Config.textMain
                                font.pixelSize: Config.size(Config.fontBody)
                            }

                            Rectangle {
                                implicitWidth: statusPillText.implicitWidth + 10
                                implicitHeight: 18
                                radius: 9
                                color: !root.hasAdapter
                                    ? Qt.rgba(255, 255, 255, 0.08)
                                    : (root.isPowered ? (root.activeDeviceName !== "" ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2) : Qt.rgba(255, 255, 255, 0.1)) : Qt.rgba(255, 255, 255, 0.08))
                                border.width: 1
                                border.color: !root.hasAdapter
                                    ? Qt.rgba(255, 255, 255, 0.15)
                                    : (root.isPowered && root.activeDeviceName !== "" ? Config.accent : Qt.rgba(255, 255, 255, 0.15))

                                Text {
                                    id: statusPillText
                                    anchors.centerIn: parent
                                    text: !root.hasAdapter ? "NO CONTROLLER" : (!root.isPowered ? "POWERED OFF" : (root.activeDeviceName !== "" ? "CONNECTED" : "DISCOVERABLE"))
                                    font.family: Config.sysFont
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: !root.hasAdapter
                                        ? Config.textMuted
                                        : (root.isPowered && root.activeDeviceName !== "" ? Config.accent : Config.textMuted)
                                }
                            }
                        }

                        Text {
                            text: !root.hasAdapter
                                ? "No Bluetooth controller hardware detected on this system"
                                : (!root.isPowered
                                    ? "Bluetooth controller is powered off"
                                    : (root.activeDeviceName !== "" ? ("Connected to " + root.activeDeviceName) : "Ready • Scanning for discoverable Bluetooth accessories"))
                            font.family: Config.sysFont
                            color: (root.isPowered && root.activeDeviceName !== "") ? Config.accent : Config.textMuted
                            font.pixelSize: Config.size(Config.fontCaption)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Spacer to push action buttons to the right
                    Item { Layout.fillWidth: true }

                    // Action Buttons (Scan & Power Toggle)
                    RowLayout {
                        spacing: 8
                        Layout.alignment: Qt.AlignRight

                        // DISCOVER BUTTON
                        Rectangle {
                            implicitWidth: discRow.implicitWidth + 16
                            implicitHeight: 32
                            radius: 16
                            visible: root.isPowered && root.hasAdapter
                            color: discHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.12)

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                id: discRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    id: btScanIcon
                                    text: "refresh"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 16
                                    color: discHover.hovered ? Config.accent : Config.textMain

                                    RotationAnimator {
                                        target: btScanIcon; from: 0; to: 360; duration: 1000
                                        loops: Animation.Infinite; running: root.isScanning
                                    }
                                }

                                Text {
                                    text: root.isScanning ? "Scanning..." : "Discover"
                                    font.family: Config.sysFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: discHover.hovered ? Config.accent : Config.textMain
                                }
                            }

                            TapHandler { onTapped: root.triggerScan() }
                            HoverHandler { id: discHover; cursorShape: Qt.PointingHandCursor }
                        }

                        // POWER TOGGLE BUTTON
                        Rectangle {
                            id: pwrBtBtn
                            implicitWidth: pwrBtRow.implicitWidth + 18
                            implicitHeight: 32
                            radius: 16
                            enabled: root.hasAdapter
                            color: (root.isPowered && root.hasAdapter)
                                ? (pwrBtHover.hovered ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.85) : Config.accent)
                                : (pwrBtHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08))

                            Behavior on color { ColorAnimation { duration: 180 } }

                            RowLayout {
                                id: pwrBtRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: root.isPowered ? "power_settings_new" : "power_off"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 16
                                    color: (root.isPowered && root.hasAdapter) ? Config.bgBase : Config.textMuted
                                }

                                Text {
                                    text: root.isPowered ? "ON" : "OFF"
                                    font.family: Config.sysFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: (root.isPowered && root.hasAdapter) ? Config.bgBase : Config.textMuted
                                }
                            }

                            TapHandler {
                                enabled: root.hasAdapter
                                onTapped: {
                                    root.bt.togglePower()
                                }
                            }
                            HoverHandler { id: pwrBtHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

            // ==========================================
            // 2. DISCOVERED & PAIRED DEVICES LIST
            // ==========================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.hasAdapter && root.isPowered

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "PAIRED & NEARBY ACCESSORIES"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    Rectangle {
                        implicitWidth: btCountText.implicitWidth + 10
                        implicitHeight: 16
                        radius: 8
                        color: Qt.rgba(255, 255, 255, 0.08)

                        Text {
                            id: btCountText
                            anchors.centerIn: parent
                            text: btModel.count.toString()
                            font.family: Config.sysFont
                            font.pixelSize: 9
                            font.bold: true
                            color: Config.textMuted
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // DEVICES LIST
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: btModel

                        delegate: Rectangle {
                            id: devCard
                            required property string mac
                            required property string name
                            required property bool connected
                            required property bool paired
                            required property int battery
                            required property string icon
                            required property bool isAudio
                            readonly property bool isConnecting: root.connectingMac === mac

                            // Audio-profile pills only appear for a connected
                            // audio device that offers more than one profile.
                            readonly property bool showProfiles:
                                connected && isAudio && root.bt.hasProfilesFor(mac)

                            Layout.fillWidth: true
                            implicitHeight: devRow.implicitHeight + 20
                                + (showProfiles ? profileRow.implicitHeight + 10 : 0)
                            radius: Config.cornerRadius * 0.75
                            color: connected
                                ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.12)
                                : (devHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04))
                            border.width: 1
                            border.color: connected
                                ? Config.accent
                                : (devHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08))
                            clip: true

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                id: devRow
                                // Top-anchored rather than filling: the audio
                                // profile pills sit below this row when shown,
                                // and anchors.fill would overlap them.
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 10
                                spacing: 12

                                // Device Type Icon Badge
                                Rectangle {
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    radius: 18
                                    color: connected
                                        ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.25)
                                        : Qt.rgba(255, 255, 255, 0.06)

                                    Text {
                                        anchors.centerIn: parent
                                        text: icon
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 18
                                        color: connected ? Config.accent : Config.textMain
                                    }
                                }

                                // Device Name, MAC & Status Badges
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        spacing: 6

                                        Text {
                                            text: name
                                            color: connected ? Config.accent : Config.textMain
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontBody)
                                            font.bold: true
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 320
                                        }

                                        // PAIRED BADGE
                                        Rectangle {
                                            visible: paired && !connected
                                            implicitWidth: pairedBadgeText.implicitWidth + 8
                                            implicitHeight: 16
                                            radius: 8
                                            color: Qt.rgba(255, 255, 255, 0.1)

                                            Text {
                                                id: pairedBadgeText
                                                anchors.centerIn: parent
                                                text: "PAIRED"
                                                font.family: Config.sysFont
                                                font.pixelSize: 9
                                                font.bold: true
                                                color: Config.textMuted
                                            }
                                        }

                                        // CONNECTED ACTIVE BADGE
                                        Rectangle {
                                            visible: connected
                                            implicitWidth: activeBadgeText.implicitWidth + 8
                                            implicitHeight: 16
                                            radius: 8
                                            color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.25)
                                            border.width: 1
                                            border.color: Config.accent

                                            Text {
                                                id: activeBadgeText
                                                anchors.centerIn: parent
                                                text: "CONNECTED"
                                                font.family: Config.sysFont
                                                font.pixelSize: 9
                                                font.bold: true
                                                color: Config.accent
                                            }
                                        }

                                        // BATTERY BADGE - only for a connected device that
                                        // actually reports a level (parser uses -1 = unknown).
                                        Rectangle {
                                            visible: connected && battery >= 0
                                            implicitWidth: battBadgeRow.implicitWidth + 10
                                            implicitHeight: 16
                                            radius: 8
                                            color: Qt.rgba(255, 255, 255, 0.1)

                                            RowLayout {
                                                id: battBadgeRow
                                                anchors.centerIn: parent
                                                spacing: 2

                                                Text {
                                                    text: root.batteryGlyph(battery)
                                                    font.family: "Material Symbols Outlined"
                                                    font.pixelSize: 11
                                                    color: root.batteryColor(battery)
                                                }

                                                Text {
                                                    text: battery + "%"
                                                    font.family: Config.sysFont
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    color: root.batteryColor(battery)
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: `${mac} • ${connected ? "Active Audio/HID Link" : (paired ? "Trusted Profile" : "Discoverable Peripheral")}`
                                        color: Config.textMuted
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontMicro)
                                    }
                                }

                                // Spacer to push action buttons to the right
                                Item { Layout.fillWidth: true }

                                // Action Buttons
                                RowLayout {
                                    spacing: 6
                                    Layout.alignment: Qt.AlignRight

                                    // CONNECT / DISCONNECT / PAIR BUTTON
                                    Rectangle {
                                        implicitWidth: Math.max(actionRow.implicitWidth + 24, 76)
                                        implicitHeight: 30
                                        radius: 15
                                        color: isConnecting
                                            ? Qt.rgba(255, 255, 255, 0.1)
                                            : (actionHover.hovered
                                                ? (connected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2) : Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.85))
                                                : (connected ? Qt.rgba(255, 255, 255, 0.08) : Config.accent))
                                        border.width: connected ? 1 : 0
                                        border.color: actionHover.hovered && connected ? Config.accent : Qt.rgba(255, 255, 255, 0.12)

                                        RowLayout {
                                            id: actionRow
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: connected ? "link_off" : (paired ? "login" : "add_link")
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 14
                                                color: connected
                                                    ? (actionHover.hovered ? Config.accent : Config.textMain)
                                                    : Config.bgBase
                                            }

                                            Text {
                                                id: actionBtnText
                                                text: isConnecting ? "..." : (connected ? "Disconnect" : (paired ? "Connect" : "Pair"))
                                                font.family: Config.sysFont
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: connected
                                                    ? (actionHover.hovered ? Config.accent : Config.textMain)
                                                    : Config.bgBase
                                            }
                                        }

                                        TapHandler {
                                            onTapped: {
                                                if (isConnecting || !root.hasAdapter) return
                                                if (connected) {
                                                    root.bt.disconnectDevice(mac)
                                                } else if (paired) {
                                                    root.bt.connectDevice(mac)
                                                } else {
                                                    root.bt.pairDevice(mac)
                                                }
                                            }
                                        }
                                        HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
                                    }

                                    // FORGET / UNPAIR BUTTON
                                    Rectangle {
                                        visible: true
                                        implicitWidth: 30
                                        implicitHeight: 30
                                        radius: 15
                                        color: forgetHover.hovered ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2) : Qt.rgba(255, 255, 255, 0.06)
                                        border.width: 1
                                        border.color: forgetHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "delete_outline"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 15
                                            color: forgetHover.hovered ? Config.accent : Config.textMuted
                                        }

                                        TapHandler {
                                            onTapped: {
                                                if (!root.hasAdapter) return
                                                root.bt.forgetDevice(mac)
                                            }
                                        }
                                        HoverHandler { id: forgetHover; cursorShape: Qt.PointingHandCursor }
                                    }
                                }
                            }

                            // --- AUDIO PROFILE SWITCHER ---
                            // A2DP <-> HSP/HFP. A call flips a headset to
                            // headset-head-unit (16kHz mono) and nothing
                            // switches it back; this is what previously
                            // required pavucontrol.
                            Flow {
                                id: profileRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 10
                                spacing: 6
                                visible: devCard.showProfiles

                                Repeater {
                                    model: devCard.showProfiles
                                        ? root.bt.profilesFor(devCard.mac) : []

                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool isActive:
                                            modelData.name === root.bt.activeProfileFor(devCard.mac)

                                        implicitWidth: profPillRow.implicitWidth + 16
                                        implicitHeight: 24
                                        radius: 6
                                        color: isActive
                                            ? Config.accent
                                            : (profPillHover.hovered
                                                ? Qt.rgba(255, 255, 255, 0.12)
                                                : Qt.rgba(255, 255, 255, 0.05))
                                        border.width: 1
                                        border.color: isActive ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        RowLayout {
                                            id: profPillRow
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text {
                                                text: root.bt.profileIcon(modelData.name)
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 12
                                                verticalAlignment: Text.AlignVCenter
                                                color: isActive ? Config.bgBase : Config.textMuted
                                            }
                                            Text {
                                                text: root.bt.profileLabel(modelData.name)
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontMicro)
                                                font.bold: isActive
                                                verticalAlignment: Text.AlignVCenter
                                                color: isActive ? Config.bgBase : Config.textMain
                                            }
                                        }

                                        TapHandler {
                                            onTapped: root.bt.setAudioProfile(devCard.mac, modelData.name)
                                        }
                                        HoverHandler { id: profPillHover; cursorShape: Qt.PointingHandCursor }
                                    }
                                }
                            }

                            HoverHandler { id: devHover; cursorShape: Qt.PointingHandCursor }
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
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.06)
                visible: root.hasPolledOnce && (!root.hasAdapter || !root.isPowered || (btModel.count === 0 && !root.isScanning))

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: !root.hasAdapter ? "bluetooth_disabled" : (!root.isPowered ? "bluetooth_disabled" : "bluetooth_searching")
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 36
                        color: Config.textMuted
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: !root.hasAdapter
                            ? "No Bluetooth controller detected"
                            : (!root.isPowered ? "Bluetooth is currently powered off" : "No nearby Bluetooth devices found")
                        font.family: Config.sysFont
                        font.bold: true
                        font.pixelSize: Config.size(Config.fontBody)
                        color: Config.textMain
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: !root.hasAdapter
                            ? "Check your system Bluetooth hardware or bluez daemon"
                            : (!root.isPowered ? "Toggle the controller power switch above to begin discovering devices" : "Put your accessory into pairing mode and click Discover")
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        color: Config.textMuted
                    }
                }
            }
        }
    }

    // The BACKEND IPC PROCESSES & TIMERS block that used to live here - a 3s
    // poll timer plus five Process blocks shelling out to bluetoothctl - is
    // gone. BluetoothService owns all of it now and pushes changes in as
    // property notifications, so this page has no backend of its own.
    function triggerScan() { root.bt.startScan() }
}
