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

    // Bind directly to your root NotificationServer instance, which is itself
    // bound to Config.dndActive - so this reflects a schedule window opening or
    // a window going fullscreen, not just taps on this card.
    property bool dndActive: notifServer.dnd
    onDndActiveChanged: bellWobble.restart()

    // Why DND is on, so an automatic trigger doesn't look like a card that
    // turned itself on for no reason.
    readonly property string dndReason: Config.dndReason

    TapHandler {
        onTapped: root.toggleDnd()
    }

    HoverHandler {
        id: cardHover
        cursorShape: Qt.PointingHandCursor
    }

    function toggleDnd() {
        Config.dnd.toggle()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Rectangle {
            implicitWidth: 44
            implicitHeight: 44
            radius: Config.cornerRadius / 2
            color: root.dndActive ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                id: bellIcon
                anchors.centerIn: parent
                text: root.dndActive ? "notifications_off" : "notifications"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 22
                color: root.dndActive ? Config.bgBase : Config.textMuted

                SequentialAnimation {
                    id: bellWobble
                    NumberAnimation { target: bellIcon; property: "rotation"; to: -18; duration: 70; easing.type: Easing.OutCubic }
                    NumberAnimation { target: bellIcon; property: "rotation"; to: 14; duration: 100; easing.type: Easing.InOutCubic }
                    NumberAnimation { target: bellIcon; property: "rotation"; to: -8; duration: 90; easing.type: Easing.InOutCubic }
                    NumberAnimation { target: bellIcon; property: "rotation"; to: 0; duration: 90; easing.type: Easing.OutCubic }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: "Do Not Disturb"
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
                color: Config.textMain
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: {
                    if (!root.dndActive) return "Off"
                    if (root.dndReason === "schedule") return "On · Scheduled"
                    if (root.dndReason === "fullscreen") return "On · Fullscreen"
                    return "On"
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