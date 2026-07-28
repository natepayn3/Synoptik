import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

MorphingFlyout {
    id: powerFlyout

    isOpen: Config.showPower
    panelWidth: (5 * 68) + (4 * 8) + 28 + 40 
    panelHeight: mainLayout.implicitHeight + 40

    alignRight: false
    alignCenter: false

    property int activeHoverIndex: -1

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 12

        // ==========================================
        // POWER CARD (Title + Actions)
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: cardLayout.implicitHeight + 24
            color: Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius

            ColumnLayout {
                id: cardLayout
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Text {
                    text: "POWER OPTIONS"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontTitle)
                    font.bold: true
                    Layout.fillWidth: true
                }

                RowLayout {
                    id: actionRow
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            { icon: "lock", label: "Lock", cmd: ["hyprlock"] },
                            { icon: "bedtime", label: "Suspend", cmd: ["systemctl", "suspend"] },
                            { icon: "logout", label: "Log Out", cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
                            { icon: "restart_alt", label: "Reboot", cmd: ["systemctl", "reboot"] },
                            { icon: "power_settings_new", label: "Power Off", cmd: ["systemctl", "poweroff"] }
                        ]
                        
                        delegate: Rectangle {
                            id: actionBtn
                            
                            // Fill the available card width evenly across all 5 buttons
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1 // Acts as a weight ratio in RowLayout
                            
                            implicitHeight: 68
                            radius: Config.cornerRadius / 2

                            color: powerFlyout.activeHoverIndex === index
                                ? Qt.rgba(255, 255, 255, 0.12)
                                : (btnHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2))
                            Behavior on color { ColorAnimation { duration: 150 } }

                            border.color: powerFlyout.activeHoverIndex === index ? Config.accent : "transparent"
                            border.width: powerFlyout.activeHoverIndex === index ? 1 : 0

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width - 4
                                spacing: 4

                                Text {
                                    text: modelData.icon
                                    font.family: "Material Symbols Outlined"
                                    font.weight: Font.Bold
                                    font.pixelSize: 24
                                    color: powerFlyout.activeHoverIndex === index ? Config.accent : Config.textMain
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: modelData.label
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: true
                                    color: powerFlyout.activeHoverIndex === index ? Config.accent : Config.textMuted
                                    Layout.alignment: Qt.AlignHCenter
                                    elide: Text.ElideNone
                                    maximumLineCount: 1
                                }
                            }

                            HoverHandler {
                                id: btnHover
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: {
                                    if (hovered) powerFlyout.activeHoverIndex = index;
                                    else if (powerFlyout.activeHoverIndex === index) powerFlyout.activeHoverIndex = -1;
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    Config.showPower = false;
                                    Quickshell.execDetached(modelData.cmd);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}