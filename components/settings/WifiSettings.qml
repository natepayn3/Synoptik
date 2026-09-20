pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."

// Shared with the Control Center's WifiCard via Config.network - see
// NetworkService.qml. The poll timer, scan timeout and nmcli Process blocks
// live there, so this page is presentation only.
SettingsPage {
    id: root

    title: "Wi-Fi"
    description: "Wireless radio, access point discovery and saved network profiles."
    icon: "wifi"

    readonly property var net: Config.network

    readonly property bool hasPolledOnce: root.net.hasPolledOnce
    readonly property bool hasAdapter: root.net.hasAdapter
    readonly property bool wifiPowered: root.net.powered
    readonly property bool wifiScanning: root.net.scanning
    readonly property string activeSsid: root.net.activeSsid
    readonly property string connectingSsid: root.net.connectingSsid
    readonly property string disconnectingSsid: root.net.disconnectingSsid
    readonly property string errorSsid: root.net.errorSsid
    readonly property string connectionError: root.net.connectionError
    readonly property var wifiModel: root.net.networks

    property string expandedSsid: ""

    // Pre-flight validation ("Password Required") is kept local so it never
    // has to write to the service-bound properties above.
    property string validationSsid: ""
    property string validationError: ""
    readonly property string shownErrorSsid: root.validationSsid !== "" ? root.validationSsid : root.errorSsid
    readonly property string shownError: root.validationSsid !== "" ? root.validationError : root.connectionError

    function clearValidation() {
        root.validationSsid = ""
        root.validationError = ""
    }

    readonly property string statusLabel: {
        if (!root.hasAdapter) return "NO ADAPTER"
        if (!root.wifiPowered) return "DISABLED"
        return root.activeSsid !== "" ? "CONNECTED" : "DISCONNECTED"
    }

    readonly property string statusDetail: {
        if (!root.hasAdapter) return "No wireless network interface detected"
        if (!root.wifiPowered) return "Wi-Fi radio is powered off to save power"
        return root.activeSsid !== ""
            ? "Connected to " + root.activeSsid
            : "Wi-Fi enabled • scanning for access points"
    }

    SettingsCard {
        title: "Wireless Radio"
        icon: !root.hasAdapter
            ? "signal_wifi_off"
            : (root.wifiPowered ? (root.activeSsid !== "" ? "wifi" : "wifi_find") : "signal_wifi_off")
        subtitle: root.statusDetail

        accessory: RowLayout {
            spacing: SettingsStyle.tightGap

            SettingsBadge {
                text: root.statusLabel
                highlighted: root.wifiPowered && root.activeSsid !== ""
            }

            SettingsButton {
                label: root.wifiScanning ? "Scanning…" : "Rescan"
                icon: "refresh"
                busy: root.wifiScanning
                visible: root.wifiPowered && root.hasAdapter
                onClicked: root.net.scan()
            }

            SettingsButton {
                label: root.wifiPowered ? "On" : "Off"
                icon: root.wifiPowered ? "power_settings_new" : "power_off"
                variant: (root.wifiPowered && root.hasAdapter) ? "accent" : "quiet"
                enabled: root.hasAdapter
                onClicked: root.net.togglePower()
            }
        }
    }

    SettingsCard {
        title: "Available Networks"
        icon: "wifi_find"
        visible: root.hasAdapter && root.wifiPowered

        accessory: SettingsBadge {
            text: root.wifiModel.count.toString()
        }

        SettingsList {
            Repeater {
                model: root.wifiModel

                delegate: Rectangle {
                    id: netCard

                    required property string ssid
                    required property bool connected
                    required property bool isSecure
                    required property bool isSaved

                    readonly property bool isExpanded: root.expandedSsid === netCard.ssid
                    readonly property bool isConnecting: root.connectingSsid === netCard.ssid
                    readonly property bool isDisconnecting: root.disconnectingSsid === netCard.ssid
                    readonly property bool hasError: root.shownErrorSsid === netCard.ssid
                    readonly property bool isBusy: netCard.isConnecting || netCard.isDisconnecting

                    // A secure network needs a password unless NetworkManager has
                    // one saved - and if the saved one just failed, it needs a new
                    // one, which is why hasError re-opens the field.
                    readonly property bool needsPassword:
                        !netCard.connected && netCard.isSecure && (!netCard.isSaved || netCard.hasError)

                    function join() {
                        if (netCard.needsPassword && passField.text.trim() === "") {
                            root.validationSsid = netCard.ssid
                            root.validationError = "Password required"
                            return
                        }
                        root.clearValidation()
                        root.net.connectTo(netCard.ssid, passField.text, false)
                    }

                    Layout.fillWidth: true
                    implicitHeight: netCol.implicitHeight + 20
                    radius: SettingsStyle.controlRadius
                    color: netCard.connected
                        ? SettingsStyle.accentSoft
                        : (netHover.hovered ? SettingsStyle.controlBgHover : SettingsStyle.controlBg)
                    border.width: 1
                    border.color: netCard.hasError
                        ? SettingsStyle.danger
                        : (netCard.connected ? SettingsStyle.accentLine : SettingsStyle.controlBorder)
                    clip: true

                    Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }
                    Behavior on border.color { ColorAnimation { duration: SettingsStyle.animFast } }

                    ColumnLayout {
                        id: netCol

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: SettingsStyle.tightGap

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 36
                                implicitHeight: 36
                                radius: SettingsStyle.controlRadius
                                color: netCard.connected ? SettingsStyle.accentMed : SettingsStyle.controlBg

                                Text {
                                    anchors.centerIn: parent
                                    text: netCard.isSecure ? "wifi_password" : "wifi"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 18
                                    color: netCard.connected ? Config.accent : Config.textMain
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
                                        text: netCard.ssid
                                        color: netCard.connected ? Config.accent : Config.textMain
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontBody)
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 240
                                    }

                                    SettingsBadge {
                                        text: "SAVED"
                                        visible: netCard.isSaved && !netCard.connected
                                    }

                                    SettingsBadge {
                                        text: "ACTIVE"
                                        highlighted: true
                                        visible: netCard.connected
                                    }

                                    Item { Layout.fillWidth: true }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: netCard.isSecure ? "WPA/WPA2 Personal" : "Open access point (unsecured)"
                                    color: Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    elide: Text.ElideRight
                                }
                            }

                            SettingsButton {
                                Layout.alignment: Qt.AlignVCenter
                                label: netCard.isConnecting ? "…" : "Connect"
                                icon: "login"
                                variant: "accent"
                                visible: !netCard.connected && netCard.isSaved && !netCard.isExpanded
                                busy: netCard.isConnecting
                                enabled: !netCard.isBusy
                                onClicked: root.net.connectTo(netCard.ssid, "", false)
                            }

                            SettingsButton {
                                Layout.alignment: Qt.AlignVCenter
                                icon: netCard.isExpanded ? "expand_less" : "chevron_right"
                                onClicked: root.expandedSsid = netCard.isExpanded ? "" : netCard.ssid
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: SettingsStyle.tightGap
                            visible: netCard.isExpanded

                            SettingsNote {
                                visible: netCard.hasError
                                variant: "danger"
                                text: root.shownError
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: SettingsStyle.tightGap
                                visible: netCard.needsPassword

                                SettingsTextField {
                                    id: passField

                                    implicitHeight: 34
                                    icon: "key"
                                    placeholder: "Enter the Wi-Fi password…"
                                    passwordMode: !showPassword.checked
                                    enabled: !netCard.isBusy

                                    onAccepted: netCard.join()
                                    onEdited: {
                                        if (netCard.hasError) root.clearValidation()
                                    }

                                    trailing: Text {
                                        id: showPassword

                                        property bool checked: false

                                        text: showPassword.checked ? "visibility" : "visibility_off"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 16
                                        color: eyeHover.hovered ? Config.textMain : Config.textMuted

                                        TapHandler { onTapped: showPassword.checked = !showPassword.checked }
                                        HoverHandler { id: eyeHover; cursorShape: Qt.PointingHandCursor }
                                    }
                                }

                                SettingsButton {
                                    label: netCard.isConnecting ? "Connecting…" : "Join Network"
                                    icon: "login"
                                    variant: "accent"
                                    busy: netCard.isConnecting
                                    enabled: !netCard.isBusy
                                    onClicked: netCard.join()
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: SettingsStyle.tightGap

                                SettingsButton {
                                    Layout.fillWidth: true
                                    label: netCard.isDisconnecting ? "Disconnecting…" : "Disconnect"
                                    icon: "link_off"
                                    visible: netCard.connected
                                    busy: netCard.isDisconnecting
                                    enabled: !netCard.isBusy
                                    onClicked: root.net.disconnect(netCard.ssid)
                                }

                                SettingsButton {
                                    Layout.fillWidth: true
                                    label: netCard.isConnecting ? "Connecting…" : "Connect"
                                    icon: "login"
                                    variant: "accent"
                                    visible: !netCard.connected && netCard.isSaved
                                    busy: netCard.isConnecting
                                    enabled: !netCard.isBusy
                                    onClicked: root.net.connectTo(netCard.ssid, "", false)
                                }

                                SettingsButton {
                                    Layout.fillWidth: true
                                    label: "Forget Profile"
                                    icon: "delete_outline"
                                    visible: netCard.isSaved
                                    enabled: !netCard.isBusy
                                    onClicked: root.net.forget(netCard.ssid)
                                }
                            }
                        }
                    }

                    HoverHandler { id: netHover; cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }

    SettingsEmptyState {
        visible: root.hasPolledOnce
            && (!root.hasAdapter || !root.wifiPowered
                || (root.wifiModel.count === 0 && !root.wifiScanning))
        icon: !root.hasAdapter ? "phonelink_erase" : (!root.wifiPowered ? "wifi_off" : "wifi_find")
        title: !root.hasAdapter
            ? "No Wi-Fi interface detected"
            : (!root.wifiPowered ? "Wi-Fi is disabled" : "No nearby wireless networks found")
        hint: !root.hasAdapter
            ? "Check your network adapter hardware or its kernel module."
            : (!root.wifiPowered
                ? "Switch the radio on above to scan for networks."
                : "Press Rescan to probe for 2.4GHz and 5GHz access points.")
    }
}
