pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."

// View over Config.bluetooth (components/services/BluetoothService.qml). The
// poll timer and the bluetoothctl Process blocks live there, not here, and
// push changes in as property notifications - this page has no backend.
SettingsPage {
    id: root

    title: "Bluetooth"
    description: "Controller power, device discovery, pairing and audio profiles."
    icon: "bluetooth"

    readonly property var bt: Config.bluetooth
    readonly property bool hasAdapter: root.bt.available
    readonly property bool isPowered: root.bt.powered
    readonly property bool isScanning: root.bt.scanning
    readonly property string activeDeviceName: root.bt.connectedNames
    readonly property string connectingMac: root.bt.connectingMac
    readonly property var btModel: root.bt.devices

    readonly property string statusLabel: {
        if (!root.hasAdapter) return "NO CONTROLLER"
        if (!root.isPowered) return "POWERED OFF"
        return root.activeDeviceName !== "" ? "CONNECTED" : "DISCOVERABLE"
    }

    readonly property string statusDetail: {
        if (!root.hasAdapter) return "No Bluetooth controller hardware detected on this system"
        if (!root.isPowered) return "Bluetooth controller is powered off"
        return root.activeDeviceName !== ""
            ? "Connected to " + root.activeDeviceName
            : "Ready • scanning for discoverable accessories"
    }

    SettingsCard {
        title: "Bluetooth Adapter"
        icon: !root.hasAdapter
            ? "bluetooth_disabled"
            : (root.isPowered ? (root.activeDeviceName !== "" ? "bluetooth_connected" : "bluetooth") : "bluetooth_disabled")
        subtitle: root.statusDetail

        accessory: RowLayout {
            spacing: SettingsStyle.tightGap

            SettingsBadge {
                text: root.statusLabel
                highlighted: root.isPowered && root.activeDeviceName !== ""
            }

            SettingsButton {
                label: root.isScanning ? "Scanning…" : "Discover"
                icon: "refresh"
                busy: root.isScanning
                visible: root.isPowered && root.hasAdapter
                onClicked: root.bt.startScan()
            }

            SettingsButton {
                label: root.isPowered ? "On" : "Off"
                icon: root.isPowered ? "power_settings_new" : "power_off"
                variant: (root.isPowered && root.hasAdapter) ? "accent" : "quiet"
                enabled: root.hasAdapter
                onClicked: root.bt.togglePower()
            }
        }
    }

    SettingsCard {
        title: "Paired & Nearby"
        icon: "devices_other"
        visible: root.hasAdapter && root.isPowered

        accessory: SettingsBadge {
            text: root.btModel.count.toString()
        }

        SettingsList {
            Repeater {
                model: root.btModel

                delegate: Rectangle {
                    id: devCard

                    required property string mac
                    required property string name
                    required property bool connected
                    required property bool paired
                    required property int battery
                    required property string icon
                    required property bool isAudio

                    readonly property bool isConnecting: root.connectingMac === devCard.mac

                    // Audio-profile pills only appear for a connected audio device
                    // that offers more than one profile.
                    readonly property bool showProfiles:
                        devCard.connected && devCard.isAudio && root.bt.hasProfilesFor(devCard.mac)

                    Layout.fillWidth: true
                    implicitHeight: devRow.implicitHeight + 20
                        + (devCard.showProfiles ? profileRow.implicitHeight + 10 : 0)
                    radius: SettingsStyle.controlRadius
                    color: devCard.connected
                        ? SettingsStyle.accentSoft
                        : (devHover.hovered ? SettingsStyle.controlBgHover : SettingsStyle.controlBg)
                    border.width: 1
                    border.color: devCard.connected ? SettingsStyle.accentLine : SettingsStyle.controlBorder
                    clip: true

                    Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }
                    Behavior on border.color { ColorAnimation { duration: SettingsStyle.animFast } }

                    RowLayout {
                        id: devRow

                        // Top-anchored rather than filling: the audio profile pills
                        // sit below this row when shown, and anchors.fill would
                        // overlap them.
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 12

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: SettingsStyle.controlRadius
                            color: devCard.connected ? SettingsStyle.accentMed : SettingsStyle.controlBg

                            Text {
                                anchors.centerIn: parent
                                text: devCard.icon
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 18
                                color: devCard.connected ? Config.accent : Config.textMain
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.minimumWidth: 0
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: devCard.name
                                    color: devCard.connected ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontBody)
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 260
                                }

                                SettingsBadge {
                                    text: "PAIRED"
                                    visible: devCard.paired && !devCard.connected
                                }

                                SettingsBadge {
                                    text: "CONNECTED"
                                    highlighted: true
                                    visible: devCard.connected
                                }

                                // Only for a connected device that actually reports
                                // a level - the parser uses -1 for unknown.
                                SettingsBadge {
                                    text: devCard.battery + "%"
                                    icon: root.bt.batteryGlyph(devCard.battery)
                                    tone: root.bt.batteryColor(devCard.battery)
                                    highlighted: true
                                    visible: devCard.connected && devCard.battery >= 0
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: `${devCard.mac} • ${devCard.connected ? "Active audio/HID link" : (devCard.paired ? "Trusted profile" : "Discoverable peripheral")}`
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                elide: Text.ElideRight
                            }
                        }

                        SettingsButton {
                            Layout.alignment: Qt.AlignVCenter
                            label: devCard.isConnecting
                                ? "…"
                                : (devCard.connected ? "Disconnect" : (devCard.paired ? "Connect" : "Pair"))
                            icon: devCard.connected ? "link_off" : (devCard.paired ? "login" : "add_link")
                            variant: devCard.connected ? "quiet" : "accent"
                            busy: devCard.isConnecting
                            enabled: root.hasAdapter && !devCard.isConnecting

                            onClicked: {
                                if (devCard.connected) root.bt.disconnectDevice(devCard.mac)
                                else if (devCard.paired) root.bt.connectDevice(devCard.mac)
                                else root.bt.pairDevice(devCard.mac)
                            }
                        }

                        SettingsButton {
                            Layout.alignment: Qt.AlignVCenter
                            icon: "delete_outline"
                            enabled: root.hasAdapter
                            onClicked: root.bt.forgetDevice(devCard.mac)
                        }
                    }

                    // A2DP <-> HSP/HFP. A call flips a headset to headset-head-unit
                    // (16kHz mono) and nothing switches it back; this is what
                    // previously required pavucontrol.
                    Flow {
                        id: profileRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        spacing: 6
                        visible: devCard.showProfiles

                        Repeater {
                            model: devCard.showProfiles ? root.bt.profilesFor(devCard.mac) : []

                            delegate: Rectangle {
                                id: profilePill

                                required property var modelData

                                readonly property bool isActive:
                                    profilePill.modelData.name === root.bt.activeProfileFor(devCard.mac)

                                implicitWidth: profilePillRow.implicitWidth + 18
                                implicitHeight: 26
                                radius: SettingsStyle.controlRadius
                                color: profilePill.isActive
                                    ? SettingsStyle.accentSoft
                                    : (profilePillHover.hovered ? SettingsStyle.controlBgHover : SettingsStyle.controlBg)
                                border.width: 1
                                border.color: profilePill.isActive ? SettingsStyle.accentLine : SettingsStyle.controlBorder

                                Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }

                                RowLayout {
                                    id: profilePillRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: root.bt.profileIcon(profilePill.modelData.name)
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 13
                                        color: profilePill.isActive ? Config.accent : Config.textMuted
                                    }

                                    Text {
                                        text: root.bt.profileLabel(profilePill.modelData.name)
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontMicro)
                                        font.bold: profilePill.isActive
                                        color: profilePill.isActive ? Config.accent : Config.textMain
                                    }
                                }

                                TapHandler { onTapped: root.bt.setAudioProfile(devCard.mac, profilePill.modelData.name) }
                                HoverHandler { id: profilePillHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }

                    HoverHandler { id: devHover; cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }

    SettingsEmptyState {
        visible: !root.hasAdapter || !root.isPowered
            || (root.btModel.count === 0 && !root.isScanning)
        icon: root.isPowered && root.hasAdapter ? "bluetooth_searching" : "bluetooth_disabled"
        title: !root.hasAdapter
            ? "No Bluetooth controller detected"
            : (!root.isPowered ? "Bluetooth is powered off" : "No nearby Bluetooth devices found")
        hint: !root.hasAdapter
            ? "Check your Bluetooth hardware or the bluez daemon."
            : (!root.isPowered
                ? "Switch the controller on above to start discovering devices."
                : "Put your accessory into pairing mode, then press Discover.")
    }
}
