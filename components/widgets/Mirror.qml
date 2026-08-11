import QtQuick
import QtQuick.Shapes
import QtMultimedia
import Qt.labs.platform
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

    function restorePosition() {
        if (width <= 0 || height <= 0) return

        if (savedX >= 0 && savedY >= 0) {
            mirrorContainer.x = Math.max(0, Math.min(savedX, width - mirrorContainer.width))
            mirrorContainer.y = Math.max(0, Math.min(savedY, height - mirrorContainer.height))
        } else {
            mirrorContainer.x = Config.cardMargin
            mirrorContainer.y = Config.cardMargin
        }
    }

    function takeSnapshot() {
        let timestamp = Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss")
        let picturesDir = StandardPaths.writableLocation(StandardPaths.PicturesLocation).toString().replace(/^file:\/\//, "")
        let targetPath = `${picturesDir}/mirror_snap_${timestamp}.png`

        flashAnimation.restart()

        videoWrapper.grabToImage(function(result) {
            if (result.saveToFile(targetPath)) {
                console.log("Snapshot saved to:", targetPath)
            } else {
                console.warn("Failed to save snapshot to:", targetPath)
            }
        })
    }

    onVisibleChanged: if (visible) restorePosition()
    onWidthChanged: if (visible) restorePosition()
    onHeightChanged: if (visible) restorePosition()

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
        x: Config.cardMargin
        y: Config.cardMargin

        Component.onCompleted: mirrorWindow.restorePosition()

        readonly property bool showPanel: typeof Config.mirrorShowPanel !== "undefined" ? Config.mirrorShowPanel : true
        readonly property real containerPadding: showPanel ? (Config.cardMargin + (Config.showBorders ? Config.borderThickness : 0)) : 0

        readonly property real nativeRatio: {
            if (camLoader.item && camLoader.item.sourceWidth > 0 && camLoader.item.sourceHeight > 0) {
                return camLoader.item.sourceHeight / camLoader.item.sourceWidth
            }
            return 0.75
        }

        height: Config.mirrorKeepAspect 
            ? width 
            : Math.round(((width - (containerPadding * 2)) * nativeRatio) + (containerPadding * 2))

        Rectangle {
            id: container
            anchors.fill: parent

            radius: mirrorContainer.showPanel ? Config.surfaceRadius : 0
            color: mirrorContainer.showPanel ? Config.bgPanel : "transparent"
            border.width: (mirrorContainer.showPanel && Config.showBorders) ? Config.borderThickness : 0
            border.color: (typeof shellRoot !== "undefined" && shellRoot.currentBorderColor) ? shellRoot.currentBorderColor : Config.accent

            property real padding: mirrorContainer.containerPadding

            Item {
                id: videoWrapper
                anchors.fill: parent
                anchors.margins: container.padding
                clip: true

                Loader {
                    id: camLoader
                    anchors.fill: parent
                    active: false
                    sourceComponent: Component {
                        Item {
                            anchors.fill: parent
                            property alias sourceWidth: localOutput.sourceRect.width
                            property alias sourceHeight: localOutput.sourceRect.height

                            VideoOutput {
                                id: localOutput
                                anchors.fill: parent
                                fillMode: Config.mirrorKeepAspect ? VideoOutput.PreserveAspectCrop : VideoOutput.PreserveAspectFit
                                visible: true

                                transform: Scale {
                                    origin.x: localOutput.width / 2
                                    xScale: Config.mirrorMirrored ? 1 : -1
                                }
                            }

                            CaptureSession {
                                camera: Camera {
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
                                            cameraFormat = bestFormat
                                        }
                                        active = true
                                    }
                                    Component.onCompleted: applyRawFormat()
                                }
                                videoOutput: localOutput
                            }
                        }
                    }
                }

                Timer {
                    id: attachTimer
                    interval: 500
                    repeat: false
                    onTriggered: camLoader.active = true
                }

                function evaluateCamera() {
                    let shouldRun = Config.showMirror && mediaDevices.defaultVideoInput !== null
                    if (shouldRun) {
                        if (!camLoader.active && !attachTimer.running) attachTimer.restart()
                    } else {
                        attachTimer.stop()
                        camLoader.active = false
                    }
                }

                Connections { target: Config; function onShowMirrorChanged() { videoWrapper.evaluateCamera() } }
                Connections { target: mediaDevices; function onDefaultVideoInputChanged() { videoWrapper.evaluateCamera() } }
                
                Component.onCompleted: evaluateCamera()
            }

            Rectangle {
                id: flashOverlay
                anchors.fill: videoWrapper
                color: "#ffffff"
                opacity: 0.0
                z: 99
                radius: mirrorContainer.showPanel ? Config.surfaceRadius : 0

                NumberAnimation on opacity {
                    id: flashAnimation
                    running: false
                    from: 0.85
                    to: 0.0
                    duration: 200
                    easing.type: Easing.OutQuad
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

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                
                anchors.bottomMargin: mirrorContainer.showPanel ? (container.padding + 6) : 6
                anchors.rightMargin: mirrorContainer.showPanel ? (container.padding + 6) : 6
                
                width: 24
                height: 24
                radius: width / 2
                color: snapHover.hovered ? Config.accent : Qt.rgba(0, 0, 0, 0.4)
                opacity: snapHover.hovered ? 1.0 : 0.6
                z: 101

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "photo_camera"
                    color: "#ffffff"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 14
                }

                TapHandler {
                    onTapped: mirrorWindow.takeSnapshot()
                }
                HoverHandler { id: snapHover; cursorShape: Qt.PointingHandCursor }
            }
        }
    }
}