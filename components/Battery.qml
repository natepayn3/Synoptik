import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

MorphingFlyout {
    id: root

    isOpen: typeof Config.showBattery !== "undefined" ? Config.showBattery : false
    alignRight: true
    panelWidth: 320
    panelHeight: mainContent.implicitHeight + 40

    property string battName: shellRoot.battName
    property int battCapacity: shellRoot.battCapacity
    property string battStatus: shellRoot.battStatus

    // Detailed Stats Poller
    Process {
        id: battDetailProc
        command: ["fish", "-c", "cat /sys/class/power_supply/" + root.battName + "/power_now 2>/dev/null; or echo 0"]
        running: root.isOpen
        stdout: StdioCollector {
            onStreamFinished: {
                let val = parseInt(this.text.trim()) || 0
                root.powerDraw = (val / 1000000.0).toFixed(1)
            }
        }
    }

    property string powerDraw: "0.0"

    ColumnLayout {
        id: mainContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 16

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "BATTERY"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontTitle)
                font.bold: true
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: statusText.implicitWidth + 12
                implicitHeight: 22
                radius: Config.cornerRadius / 2
                color: root.battStatus === "Charging" ? Qt.rgba(16, 185, 129, 0.2) : Qt.rgba(255, 255, 255, 0.08)

                Text {
                    id: statusText
                    anchors.centerIn: parent
                    text: root.battStatus.toUpperCase()
                    color: root.battStatus === "Charging" ? Config.accent : Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                }
            }
        }

        // Percentage Level Display
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 70
            radius: Config.cornerRadius / 2
            color: Config.bgBase

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    text: {
                        if (root.battStatus === "Charging") return "battery_charging_full"
                        if (root.battCapacity <= 15) return "battery_alert"
                        if (root.battCapacity <= 30) return "battery_2_bar"
                        if (root.battCapacity <= 70) return "battery_4_bar"
                        return "battery_full"
                    }
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 32
                    color: root.battCapacity <= 15 ? "#ef4444" : Config.accent
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: root.battCapacity + "% Available"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontSubhead)
                        font.bold: true
                    }

                    // Progress bar
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Qt.rgba(255, 255, 255, 0.1)

                        Rectangle {
                            width: parent.width * (root.battCapacity / 100.0)
                            height: parent.height
                            radius: 3
                            color: root.battCapacity <= 15 ? "#ef4444" : Config.accent

                            Behavior on width {
                                NumberAnimation { duration: 200 }
                            }
                        }
                    }
                }
            }
        }

        // Extra details
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Config.cornerRadius / 2
                color: Config.bgBase

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        text: "DEVICE"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                    }

                    Text {
                        text: root.battName
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Config.cornerRadius / 2
                color: Config.bgBase

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        text: "DISCHARGE"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                    }

                    Text {
                        text: root.powerDraw + " W"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                    }
                }
            }
        }
    }
}