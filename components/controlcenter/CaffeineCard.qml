import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import ".."

Rectangle {
    id: root

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.alignment: Qt.AlignTop
    implicitHeight: 64
    radius: Config.cornerRadius

    color: cardHover.hovered ? Qt.rgba(Config.bgBase.r, Config.bgBase.g, Config.bgBase.b, 1.0) : Qt.rgba(0, 0, 0, 0.25)
    Behavior on color { ColorAnimation { duration: 150 } }

    readonly property bool hasHypridle: Config.caffeineHasHypridle
    readonly property int caffeineState: Config.caffeineState
    readonly property string remainingTimeString: Config.caffeineRemainingTimeString

    TapHandler {
        enabled: root.hasHypridle
        onTapped: Config.cycleCaffeine()
    }

    HoverHandler {
        id: cardHover
        cursorShape: root.hasHypridle ? Qt.PointingHandCursor : Qt.ForbiddenCursor
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8
        opacity: root.hasHypridle ? 1.0 : 0.45

        Rectangle {
            implicitWidth: 44
            implicitHeight: 44
            radius: Config.cornerRadius / 2
            
            color: {
                if (!root.hasHypridle || root.caffeineState === 0) {
                    return Qt.rgba(255, 255, 255, 0.08)
                } else if (root.caffeineState === 1) {
                    return Config.accent
                } else {
                    return Qt.tint(Config.accent, Qt.rgba(1, 1, 1, 0.4))
                }
            }

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: root.caffeineState === 2 ? "schedule" : "coffee"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 22
                color: (!root.hasHypridle || root.caffeineState === 0) ? Config.textMuted : Config.bgBase
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: "Caffeine"
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
                color: Config.textMain
            }

            Text {
                text: {
                    if (!root.hasHypridle) return "Unavailable"
                    switch (root.caffeineState) {
                        case 1: return "Awake"
                        case 2: return root.remainingTimeString
                        default: return "Off"
                    }
                }
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                color: Config.textMuted
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}