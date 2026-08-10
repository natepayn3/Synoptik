import QtQuick
import QtMultimedia
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import ".."

PanelWindow {
    id: mirrorWindow

    visible: Config.showMirror

    property real savedX: (typeof Config !== "undefined" && typeof Config.mirrorX !== "undefined") ? Config.mirrorX : -1
    property real savedY: (typeof Config !== "undefined" && typeof Config.mirrorY !== "undefined") ? Config.mirrorY : -1

    function savePosition() {
        savedX = mirrorContainer.x
        savedY = mirrorContainer.y
        if (typeof Config !== "undefined") {
            Config.mirrorX = mirrorContainer.x
            Config.mirrorY = mirrorContainer.y
        }
    }

    onVisibleChanged: {
        if (visible && savedX >= 0 && savedY >= 0) {
            mirrorContainer.x = savedX
            mirrorContainer.y = savedY
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "synoptik-shell-mirror"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    color: "transparent"
    exclusiveZone: 0

    mask: Region {
        item: dragArea.drag.active ? null : container
    }

    MediaDevices {
        id: mediaDevices
    }

    Item {
        id: mirrorContainer

        width: 320
        height: 320

        x: mirrorWindow.savedX >= 0 ? mirrorWindow.savedX : (mirrorWindow.width > 0 ? mirrorWindow.width - width - Config.cardMargin : Config.cardMargin)
        y: mirrorWindow.savedY >= 0 ? mirrorWindow.savedY : (Config.barHeight + Config.cardMargin * 2)

        Rectangle {
            id: container
            anchors.fill: parent

            radius: Config.surfaceRadius
            color: Config.bgPanel
            border.width: Config.showBorders ? Config.borderThickness : 0
            border.color: (typeof shellRoot !== "undefined" && shellRoot.currentBorderColor) ? shellRoot.currentBorderColor : Config.accent

            property real padding: Config.cardMargin + container.border.width
            property real videoRadius: Math.max(6, Config.surfaceRadius - 6)

            // Shader-Masked Video Wrapper
            Item {
                id: videoWrapper
                anchors.fill: parent
                anchors.margins: container.padding

                VideoOutput {
                    id: videoOutput
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectCrop
                    visible: false
                    layer.enabled: true

                    transform: Rotation {
                        origin.x: videoOutput.width / 2
                        origin.y: videoOutput.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: 180
                    }
                }

                Rectangle {
                    id: maskShape
                    anchors.fill: parent
                    radius: container.videoRadius
                    visible: false
                    color: "black"
                    layer.enabled: true
                }

                OpacityMask {
                    anchors.fill: parent
                    source: videoOutput
                    maskSource: maskShape
                }
            }

            CaptureSession {
                id: captureSession
                camera: Camera {
                    id: camera
                    cameraDevice: mediaDevices.defaultVideoInput
                    active: Config.showMirror && mediaDevices.defaultVideoInput !== null
                }
                videoOutput: videoOutput
            }

            Connections {
                target: mediaDevices
                function onDefaultVideoInputChanged() {
                    if (Config.showMirror && camera) {
                        camera.start()
                    }
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                drag.target: mirrorContainer
                drag.axis: Drag.XAndYAxis
                cursorShape: Qt.SizeAllCursor

                onReleased: mirrorWindow.savePosition()

                onWheel: (wheel) => {
                    let step = wheel.angleDelta.y > 0 ? 32 : -32
                    let newSize = Math.max(160, Math.min(800, mirrorContainer.width + step))

                    mirrorContainer.x -= (newSize - mirrorContainer.width) / 2
                    mirrorContainer.y -= (newSize - mirrorContainer.height) / 2

                    mirrorContainer.width = newSize
                    mirrorContainer.height = newSize
                    mirrorWindow.savePosition()
                }

                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        Config.showMirror = false
                    }
                }
                onDoubleClicked: Config.showMirror = false
            }

            // Close Button
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: container.padding + 6
                anchors.rightMargin: container.padding + 6
                width: 24
                height: 24
                radius: width / 2
                color: closeHover.hovered ? "#f38ba8" : Qt.rgba(0, 0, 0, 0.4)
                opacity: closeHover.hovered ? 1.0 : 0.6
                z: 10

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "close"
                    color: "#ffffff"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 14
                }

                TapHandler {
                    onTapped: Config.showMirror = false
                }
                HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
            }
        }
    }
}