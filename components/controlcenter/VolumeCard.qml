import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import ".."

Rectangle {
    id: root

    Layout.fillWidth: true
    Layout.preferredWidth: parent ? parent.width : 356
    implicitHeight: volumeLayout.implicitHeight + 20
    radius: Config.cornerRadius

    color: cardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
    Behavior on color { ColorAnimation { duration: 150 } }

    property int currentVolume
    property bool isAudioMuted
    property bool isUserDraggingVol: false
    property real localRatio: 0.0

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
                readonly property int displayVol: root.isUserDraggingVol 
                    ? Math.round(root.localRatio * 100) 
                    : root.currentVolume

                text: root.isAudioMuted ? "MUTED" : (displayVol < 0 ? "---" : displayVol + "%")
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.bold: true
                color: root.isAudioMuted ? Config.textMuted : Config.textMain
            }
        }

        // Slider Container
        Item {
            Layout.fillWidth: true
            implicitHeight: 40

            // Unclipped glow layer matching track corner radius
            RectangularGlow {
                id: activeGlow
                anchors.fill: volFillContainer
                glowRadius: 8
                spread: 0.2
                color: Config.accent
                cornerRadius: volTrack.radius
                opacity: (volHover.hovered || root.isUserDraggingVol) && !root.isAudioMuted && volFillContainer.width > 0 ? 0.5 : 0.0

                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            // Unclipped reference container tracking physical fill dimensions
            Item {
                id: volFillContainer
                x: volTrack.x
                y: volTrack.y
                height: volTrack.height

                readonly property real targetRatio: root.isUserDraggingVol 
                    ? root.localRatio 
                    : (root.currentVolume / 100.0)

                // Guard against muted/0% volume while keeping minimum height width for proper corner rendering
                width: (root.isAudioMuted || targetRatio <= 0) 
                    ? 0 
                    : Math.max(height, volTrack.width * Math.min(1.0, targetRatio))

                Behavior on width {
                    enabled: !root.isUserDraggingVol && !volArea.pressed && root.currentVolume >= 0
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
            }

            Rectangle {
                id: volTrack
                anchors.fill: parent
                radius: Config.cornerRadius / 1.5
                color: Qt.rgba(0, 0, 0, 0.35)
                clip: true // Enforce inner fill clipping to track boundaries

                Rectangle {
                    id: volFill
                    width: volFillContainer.width
                    height: parent.height
                    radius: Config.cornerRadius / 1.5
                    color: Config.accent
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property int activeVol: root.isUserDraggingVol 
                        ? Math.round(root.localRatio * 100) 
                        : root.currentVolume

                    text: root.isAudioMuted ? "volume_off" : (activeVol <= 0 ? "volume_mute" : (activeVol < 50 ? "volume_down" : "volume_up"))
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 20
                    color: (!root.isAudioMuted && activeVol > 10) ? Config.bgBase : Config.textMain
                }

                MouseArea {
                    id: volArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true

                    // Calculate drag ratio clamped to physical track width
                    function applyDrag(mouseXPos) {
                        let trackW = volTrack.width
                        if (trackW <= 0) return

                        let ratio = Math.max(0.0, Math.min(1.0, mouseXPos / trackW))
                        root.localRatio = ratio
                        
                        let pct = Math.round(ratio * 100)
                        if (pct !== root.currentVolume) {
                            root.volumeChanged(pct)
                        }
                    }

                    onPressed: mouse => {
                        root.isUserDraggingVol = true
                        applyDrag(mouse.x)
                    }

                    onPositionChanged: mouse => {
                        if (pressed) {
                            applyDrag(mouse.x)
                        }
                    }

                    onReleased: root.isUserDraggingVol = false
                    onCanceled: root.isUserDraggingVol = false
                }

                HoverHandler { id: volHover }
            }
        }
    }
}