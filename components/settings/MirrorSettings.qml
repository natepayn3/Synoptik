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

    onVisibleChanged: previewCamera.updateState()

    ColumnLayout {
        id: mainColumn
        width: parent.width
        spacing: 12

        // SECTION TITLE
        Text {
            text: "CAMERA MIRROR"
            color: Config.textMain
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontSubhead)
            font.bold: true
        }

        Item { implicitHeight: 4 }

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

            // Checkbox 3: Show Panel
            RowLayout {
                spacing: 8
                Rectangle {
                    implicitWidth: 18; implicitHeight: 18; radius: 4
                    property bool isChecked: typeof Config.mirrorShowPanel !== "undefined" ? Config.mirrorShowPanel : true
                    color: isChecked ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: Config.bgBase
                        visible: parent.isChecked
                        font.pixelSize: 11
                        font.bold: true
                    }

                    TapHandler { 
                        onTapped: {
                            if (typeof Config.mirrorShowPanel !== "undefined") {
                                Config.mirrorShowPanel = !Config.mirrorShowPanel
                            }
                        } 
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                Text {
                    text: "Background"
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

        Item { implicitHeight: 8 }

        // PREVIEW SECTION
        Text {
            text: "PREVIEW"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            font.bold: true
        }

        Item {
            id: previewContainer
            Layout.fillWidth: true

            readonly property real nativeRatio: (previewOutput.sourceRect.width > 0 && previewOutput.sourceRect.height > 0)
                ? (previewOutput.sourceRect.height / previewOutput.sourceRect.width)
                : 0.75

            readonly property bool showPanel: typeof Config.mirrorShowPanel !== "undefined" ? Config.mirrorShowPanel : true
            readonly property real containerPadding: showPanel ? (Config.cardMargin + (Config.showBorders ? Config.borderThickness : 0)) : 0

            implicitHeight: Config.mirrorKeepAspect 
                ? width 
                : Math.round(((width - (containerPadding * 2)) * nativeRatio) + (containerPadding * 2))

            Rectangle {
                id: previewFrame
                anchors.fill: parent

                radius: previewContainer.showPanel ? Config.surfaceRadius : 0
                color: previewContainer.showPanel ? Config.bgPanel : "transparent"
                border.width: (previewContainer.showPanel && Config.showBorders) ? Config.borderThickness : 0
                border.color: (typeof shellRoot !== "undefined" && shellRoot.currentBorderColor) ? shellRoot.currentBorderColor : Config.accent

                Item {
                    anchors.fill: parent
                    anchors.margins: previewContainer.containerPadding
                    clip: true

                    VideoOutput {
                        id: previewOutput
                        anchors.fill: parent
                        fillMode: Config.mirrorKeepAspect ? VideoOutput.PreserveAspectCrop : VideoOutput.PreserveAspectFit

                        transform: Scale {
                            origin.x: previewOutput.width / 2
                            xScale: Config.mirrorMirrored ? 1 : -1
                        }
                    }
                }

                CaptureSession {
                    id: previewSession
                    camera: Camera {
                        id: previewCamera
                        active: false
                        cameraDevice: mediaDevices.defaultVideoInput

                        function updateState() {
                            if (root.visible && !Config.showMirror && mediaDevices.defaultVideoInput !== null) {
                                previewStartTimer.restart()
                            } else {
                                previewStartTimer.stop()
                                previewCamera.active = false
                            }
                        }

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
                                previewCamera.cameraFormat = bestFormat
                            }
                            
                            if (active) {
                                previewCamera.stop()
                                previewCamera.start()
                            }
                        }

                        onCameraDeviceChanged: applyRawFormat()
                        Component.onCompleted: applyRawFormat()
                    }
                    videoOutput: previewOutput
                }

                Timer {
                    id: previewStartTimer
                    interval: 150
                    repeat: false
                    onTriggered: {
                        if (root.visible && !Config.showMirror && mediaDevices.defaultVideoInput !== null) {
                            previewCamera.active = true
                        }
                    }
                }

                Connections {
                    target: Config
                    function onShowMirrorChanged() {
                        previewCamera.updateState()
                    }
                }

                // Overlay when desktop mirror widget is actively open
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.75)
                    visible: Config.showMirror
                    z: 10

                    Text {
                        anchors.centerIn: parent
                        text: "Camera active in desktop Mirror"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                    }
                }
            }
        }
    }
}