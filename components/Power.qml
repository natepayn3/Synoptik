import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

Item {
    id: powerModule

    property int activeHoverIndex: -1

    implicitWidth: 412
    implicitHeight: mainLayout.implicitHeight + 24

    ColumnLayout {
        id: mainLayout
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
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

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 68
                            radius: Config.cornerRadius / 2

                            color: powerModule.activeHoverIndex === index
                                ? Qt.rgba(255, 255, 255, 0.12)
                                : (btnHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2))
                            Behavior on color { ColorAnimation { duration: 150 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width - 4
                                spacing: 4

                                Text {
                                    text: modelData.icon
                                    font.family: "Material Symbols Outlined"
                                    font.weight: Font.Bold
                                    font.pixelSize: 24
                                    color: powerModule.activeHoverIndex === index ? Config.accent : Config.textMain
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: modelData.label
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: true
                                    color: powerModule.activeHoverIndex === index ? Config.accent : Config.textMuted
                                    Layout.alignment: Qt.AlignHCenter
                                    elide: Text.ElideNone
                                    maximumLineCount: 1
                                }
                            }

                            HoverHandler {
                                id: btnHover
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: {
                                    if (hovered) powerModule.activeHoverIndex = index;
                                    else if (powerModule.activeHoverIndex === index) powerModule.activeHoverIndex = -1;
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