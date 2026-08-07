import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import ".."

Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: brightnessLayout.implicitHeight + 20
    radius: Config.cornerRadius

    color: cardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
    Behavior on color { ColorAnimation { duration: 150 } }

    opacity: root.hasBacklight ? 1.0 : 0.45

    property int currentBrightness: 100
    property bool hasBacklight: false

    signal brightnessChanged(int pct)

    HoverHandler { id: cardHover }

    ColumnLayout {
        id: brightnessLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Brightness"
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
                color: Config.textMain
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.hasBacklight ? (root.currentBrightness + "%") : "Unavailable"
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.bold: true
                color: root.hasBacklight ? Config.textMain : Config.textMuted
            }
        }

        // Slider Container
        Item {
            Layout.fillWidth: true
            implicitHeight: 40

            // Unclipped glow layer matching track corner radius
            RectangularGlow {
                id: activeGlow
                anchors.fill: brightFillContainer
                glowRadius: 8
                spread: 0.2
                color: Config.accent
                cornerRadius: brightTrack.radius
                opacity: (brightHover.hovered || brightDrag.active) && root.hasBacklight && brightFillContainer.width > 0 ? 0.5 : 0.0

                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            // Unclipped reference container tracking physical fill dimensions
            Item {
                id: brightFillContainer
                x: brightTrack.x
                y: brightTrack.y
                height: brightTrack.height

                // Guard against 0% value while keeping minimum height width for proper corner rendering
                width: (root.hasBacklight && root.currentBrightness > 0) 
                    ? Math.max(height, brightTrack.width * (root.currentBrightness / 100.0)) 
                    : 0

                Behavior on width {
                    enabled: !brightDrag.active
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
            }

            Rectangle {
                id: brightTrack
                anchors.fill: parent
                radius: Config.cornerRadius / 1.5
                color: Qt.rgba(0, 0, 0, 0.35)
                clip: true // Enforce inner fill clipping to track boundaries

                Rectangle {
                    id: brightFill
                    width: brightFillContainer.width
                    height: parent.height
                    radius: Config.cornerRadius / 1.5
                    color: Config.accent
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "brightness_6"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 20
                    color: root.hasBacklight ? Config.bgBase : Config.textMuted
                }

                DragHandler {
                    id: brightDrag
                    target: null
                    enabled: root.hasBacklight
                    onTranslationChanged: {
                        if (active && root.hasBacklight) {
                            let localX = brightDrag.centroid.position.x
                            let pct = Math.max(1, Math.min(100, Math.round((localX / brightTrack.width) * 100)))
                            
                            if (pct !== root.currentBrightness) {
                                root.currentBrightness = pct
                                root.brightnessChanged(pct)
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.hasBacklight
                    cursorShape: root.hasBacklight ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: {
                        let pct = Math.max(1, Math.min(100, Math.round((mouseX / brightTrack.width) * 100)))
                        root.currentBrightness = pct
                        root.brightnessChanged(pct)
                    }
                }

                HoverHandler { id: brightHover }
            }
        }
    }
}