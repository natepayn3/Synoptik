import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."

Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: volumeLayout.implicitHeight + 20
    radius: Config.cornerRadius

    color: cardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
    Behavior on color { ColorAnimation { duration: 150 } }

    // --- Strict Read-Only State (Passed down from ControlCenter) ---
    property int currentVolume
    property bool isAudioMuted
    property bool isUserDraggingVol: false

    signal volumeChanged(int pct)

    HoverHandler { id: cardHover }

    ColumnLayout {
        id: volumeLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Volume"
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
                color: Config.textMain
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.isAudioMuted ? "MUTED" : (root.currentVolume < 0 ? "---" : root.currentVolume + "%")
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.bold: true
                color: root.isAudioMuted ? Config.textMuted : Config.textMain
            }
        }

        Rectangle {
            id: volTrack
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Config.cornerRadius / 1.5
            color: Qt.rgba(0, 0, 0, 0.35)
            clip: true

            Rectangle {
                id: volFill
                // Clamp width to 0 if muted or uninitialized (< 0)
                width: (root.isAudioMuted || root.currentVolume <= 0) 
                    ? 0 
                    : Math.max(height, parent.width * (Math.min(100, root.currentVolume) / 100.0))
                height: parent.height
                radius: Config.cornerRadius / 1.5
                color: Config.accent

                // Suppress smooth animations on initial load and during drag updates
                Behavior on width {
                    enabled: !volArea.pressed && root.currentVolume >= 0
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.isAudioMuted ? "volume_off" : (root.currentVolume <= 0 ? "volume_mute" : (root.currentVolume < 50 ? "volume_down" : "volume_up"))
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: (!root.isAudioMuted && root.currentVolume > 10) ? Config.bgBase : Config.textMain
            }

            // Single unified MouseArea handles both clicks and smooth dragging cleanly
            MouseArea {
                id: volArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function updateVolume(mouseXPos) {
                    if (volTrack.width <= 0) return
                    let pct = Math.max(0, Math.min(100, Math.round((mouseXPos / volTrack.width) * 100)))
                    if (pct !== root.currentVolume) {
                        root.volumeChanged(pct)
                    }
                }

                onPressed: mouse => {
                    root.isUserDraggingVol = true
                    updateVolume(mouse.x)
                }

                onPositionChanged: mouse => {
                    if (pressed) {
                        updateVolume(mouse.x)
                    }
                }

                onReleased: {
                    root.isUserDraggingVol = false
                }

                onCanceled: {
                    root.isUserDraggingVol = false
                }
            }
        }
    }
}