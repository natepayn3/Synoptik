import QtQuick
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import ".."

ColumnLayout {
    id: mirrorSettingsRoot
    anchors.fill: parent
    spacing: Config.cardMargin

    Text {
        text: "MIRROR WIDGET"
        color: Config.textMain
        font.family: Config.sysFont
        font.pixelSize: Config.size(Config.fontTitle)
        font.bold: true
    }

    Text {
        text: "Configure live camera transformations, mirroring behaviors, and stream aspect ratios."
        color: Config.textMuted
        font.family: Config.sysFont
        font.pixelSize: Config.size(Config.fontCaption)
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }

    // TOGGLE 1: FLIP HORIZONTALLY
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 48
        radius: Config.cornerRadius / 2
        color: horizHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: Config.cardMargin

            Text {
                text: "flip"
                color: Config.accent
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Flip Horizontally"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    font.bold: true
                }

                Text {
                    text: "Mirror the camera feed horizontally like a physical mirror."
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }
            }

            Rectangle {
                implicitWidth: 40; implicitHeight: 22; radius: 11
                color: Config.mirrorFlipHorizontal ? Config.accent : Qt.rgba(255, 255, 255, 0.15)
                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    width: 16; height: 16; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: Config.mirrorFlipHorizontal ? 21 : 3
                    color: "#ffffff"
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Config.mirrorFlipHorizontal = !Config.mirrorFlipHorizontal
        }
        HoverHandler { id: horizHover }
    }

    // TOGGLE 2: FLIP VERTICALLY
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 48
        radius: Config.cornerRadius / 2
        color: vertHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: Config.cardMargin

            Text {
                text: "swap_vert"
                color: Config.accent
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Flip Vertically"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    font.bold: true
                }

                Text {
                    text: "Invert the video stream upside down."
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }
            }

            Rectangle {
                implicitWidth: 40; implicitHeight: 22; radius: 11
                color: Config.mirrorFlipVertical ? Config.accent : Qt.rgba(255, 255, 255, 0.15)
                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    width: 16; height: 16; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: Config.mirrorFlipVertical ? 21 : 3
                    color: "#ffffff"
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Config.mirrorFlipVertical = !Config.mirrorFlipVertical
        }
        HoverHandler { id: vertHover }
    }

    // TOGGLE 3: CROP TO ASPECT RATIO
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 48
        radius: Config.cornerRadius / 2
        color: aspectHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: Config.cardMargin

            Text {
                text: "crop_free"
                color: Config.accent
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Preserve Aspect Ratio"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    font.bold: true
                }

                Text {
                    text: "Crop video to fill square frame instead of stretching."
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }
            }

            Rectangle {
                implicitWidth: 40; implicitHeight: 22; radius: 11
                color: Config.mirrorKeepAspect ? Config.accent : Qt.rgba(255, 255, 255, 0.15)
                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    width: 16; height: 16; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: Config.mirrorKeepAspect ? 21 : 3
                    color: "#ffffff"
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Config.mirrorKeepAspect = !Config.mirrorKeepAspect
        }
        HoverHandler { id: aspectHover }
    }

    // ACTIVE CAMERA DEVICE INFO CARD
    MediaDevices {
        id: mediaDevices
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 52
        radius: Config.cornerRadius / 2
        color: Qt.rgba(0, 0, 0, 0.2)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: Config.cardMargin

            Text {
                text: "videocam"
                color: Config.accent
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Default Capture Device"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    font.bold: true
                }

                Text {
                    text: mediaDevices.defaultVideoInput ? mediaDevices.defaultVideoInput.description : "No camera detected"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    elide: Text.ElideRight
                }
            }
        }
    }

    Item { Layout.fillHeight: true }
}