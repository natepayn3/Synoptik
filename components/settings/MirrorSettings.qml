import QtQuick
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import ".."

Flickable {
    id: root
    anchors.fill: parent
    contentHeight: mainColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: mainColumn
        width: parent.width
        spacing: 12

        Text {
            text: "MIRROR WIDGET"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            font.bold: true
        }

        RowLayout {
            id: mirrorControlsRow
            Layout.fillWidth: true
            spacing: 16

            // Checkbox 1: Mirrored
            RowLayout {
                spacing: 8
                Rectangle {
                    implicitWidth: 18; implicitHeight: 18; radius: 4
                    color: Config.mirrorMirrored ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: Config.bgBase
                        visible: Config.mirrorMirrored
                        font.pixelSize: 11
                        font.bold: true
                    }

                    TapHandler { onTapped: Config.mirrorMirrored = !Config.mirrorMirrored }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                Text {
                    text: "Mirrored"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }
            }

            // Checkbox 2: Square Crop
            RowLayout {
                spacing: 8
                Rectangle {
                    implicitWidth: 18; implicitHeight: 18; radius: 4
                    color: Config.mirrorKeepAspect ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: Config.bgBase
                        visible: Config.mirrorKeepAspect
                        font.pixelSize: 11
                        font.bold: true
                    }

                    TapHandler { onTapped: Config.mirrorKeepAspect = !Config.mirrorKeepAspect }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                Text {
                    text: "Square Crop"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }
            }
        }

        Item { implicitHeight: 8 }

        Text {
            text: "CAMERA DEVICE"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            font.bold: true
        }

        MediaDevices {
            id: mediaDevices
        }

        Text {
            text: mediaDevices.defaultVideoInput ? mediaDevices.defaultVideoInput.description : "No camera detected"
            color: Config.textMain
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }
}