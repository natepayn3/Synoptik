import QtQuick
import QtQuick.Shapes
import QtMultimedia
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
            mirrorContainer.x = Math.max(0, Math.min(savedX, mirrorWindow.width - mirrorContainer.width))
            mirrorContainer.y = Math.max(0, Math.min(savedY, mirrorWindow.height - mirrorContainer.height))
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

        // Track the visibility state of the panel safely
        readonly property bool showPanel: typeof Config.mirrorShowPanel !== "undefined" ? Config.mirrorShowPanel : true

        // Drop padding to 0 when panel is hidden so the video completely fills the draggable bounds
        readonly property real containerPadding: showPanel ? (Config.cardMargin + (Config.showBorders ? Config.borderThickness : 0)) : 0

        readonly property real nativeRatio: (videoOutput.sourceRect.width > 0 && videoOutput.sourceRect.height > 0)
            ? (videoOutput.sourceRect.height / videoOutput.sourceRect.width)
            : 0.75

        height: Config.mirrorKeepAspect 
            ? width 
            : Math.round(((width - (containerPadding * 2)) * nativeRatio) + (containerPadding * 2))

        x: mirrorWindow.savedX >= 0 ? mirrorWindow.savedX : (mirrorWindow.width > 0 ? mirrorWindow.width - width - Config.cardMargin : Config.cardMargin)
        y: mirrorWindow.savedY >= 0 ? mirrorWindow.savedY : (Config.barHeight + Config.cardMargin * 2)

        Rectangle {
            id: container
            anchors.fill: parent

            radius: mirrorContainer.showPanel ? Config.surfaceRadius : 0
            color: mirrorContainer.showPanel ? Config.bgPanel : "transparent"
            border.width: (mirrorContainer.showPanel && Config.showBorders) ? Config.borderThickness : 0
            border.color: (typeof shellRoot !== "undefined" && shellRoot.currentBorderColor) ? shellRoot.currentBorderColor : Config.accent

            property real padding: mirrorContainer.containerPadding

            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                anchors.margins: container.padding
                fillMode: Config.mirrorKeepAspect ? VideoOutput.PreserveAspectCrop : VideoOutput.PreserveAspectFit
                visible: true

                transform: Scale {
                    origin.x: videoOutput.width / 2
                    xScale: Config.mirrorMirrored ? 1 : -1
                }
            }

            CaptureSession {
                id: captureSession
                camera: Camera {
                    id: camera
                    active: Config.showMirror && mediaDevices.defaultVideoInput !== null
                    cameraDevice: mediaDevices.defaultVideoInput

                    function applyRawFormat() {
                        if (!cameraDevice) return

                        let formats = cameraDevice.videoFormats
                        let bestFormat = undefined
                        let bestScore = -1

                        for (let i = 0; i < formats.length; ++i) {
                            let f = formats[i]
                            
                            if (f.pixelFormat === 0 || f.pixelFormat === 29) continue

                            let fpsTarget = Math.min(f.maxFrameRate, 30)
                            let width = f.resolution.width
                            let widthScore = width <= 1280 ? width : (1280 - (width - 1280)) 
                            let score = (fpsTarget * 10000) + widthScore

                            if (score > bestScore) {
                                bestScore = score
                                bestFormat = f
                            }
                        }

                        if (bestFormat) {
                            camera.cameraFormat = bestFormat
                        }
                        
                        if (active) {
                            camera.stop()
                            camera.start()
                        }
                    }

                    onCameraDeviceChanged: applyRawFormat()
                    Component.onCompleted: applyRawFormat()
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

                drag.minimumX: 0
                drag.maximumX: Math.max(0, mirrorWindow.width - mirrorContainer.width)
                drag.minimumY: 0
                drag.maximumY: Math.max(0, mirrorWindow.height - mirrorContainer.height)

                onReleased: mirrorWindow.savePosition()

                onWheel: (wheel) => {
                    let step = wheel.angleDelta.y > 0 ? 32 : -32
                    let newWidth = Math.max(160, Math.min(800, mirrorContainer.width + step))

                    mirrorContainer.width = newWidth
                    mirrorWindow.savePosition()
                }

                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        Config.showMirror = false
                    }
                }
                onDoubleClicked: Config.showMirror = false
            }

            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                
                // Keep the button from clipping into the video corners when padding hits 0
                anchors.topMargin: mirrorContainer.showPanel ? (container.padding + 6) : 6
                anchors.rightMargin: mirrorContainer.showPanel ? (container.padding + 6) : 6
                
                width: 24
                height: 24
                radius: width / 2
                color: closeHover.hovered ? "#f38ba8" : Qt.rgba(0, 0, 0, 0.4)
                opacity: closeHover.hovered ? 1.0 : 0.6
                z: 101

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