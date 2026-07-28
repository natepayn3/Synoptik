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

    property int currentVolume: 50
    property bool isAudioMuted: false
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
                text: root.isAudioMuted ? "MUTED" : (root.currentVolume + "%")
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
                width: root.isAudioMuted ? 0 : Math.max(height, parent.width * (root.currentVolume / 100.0))
                height: parent.height
                radius: Config.cornerRadius / 1.5
                color: Config.accent

                Behavior on width {
                    enabled: !volDrag.active
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.isAudioMuted ? "volume_off" : (root.currentVolume === 0 ? "volume_mute" : (root.currentVolume < 50 ? "volume_down" : "volume_up"))
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: (!root.isAudioMuted && root.currentVolume > 10) ? Config.bgBase : Config.textMain
            }

            DragHandler {
                id: volDrag
                target: null
                onActiveChanged: {
                    // Keep tracking the drag state so the background poll doesn't fight you
                    root.isUserDraggingVol = active
                }
                onTranslationChanged: {
                    if (active) {
                        let localX = volDrag.centroid.position.x
                        let pct = Math.max(0, Math.min(100, Math.round((localX / volTrack.width) * 100)))
                        
                        // Only emit if the value actually ticked up or down
                        if (pct !== root.currentVolume) {
                            root.currentVolume = pct
                            if (root.isAudioMuted && pct > 0) root.isAudioMuted = false
                            root.volumeChanged(pct)
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    let pct = Math.max(0, Math.min(100, Math.round((mouseX / volTrack.width) * 100)))
                    root.currentVolume = pct
                    if (root.isAudioMuted && pct > 0) root.isAudioMuted = false
                    root.volumeChanged(pct)
                }
            }
        }
    }
}