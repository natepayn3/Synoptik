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

            readonly property real nativeRatio: {
                if (camLoader.item && camLoader.item.sourceWidth > 0 && camLoader.item.sourceHeight > 0) {
                    return camLoader.item.sourceHeight / camLoader.item.sourceWidth
                }
                return 0.75
            }

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
                    id: previewWrapper
                    anchors.fill: parent
                    anchors.margins: previewContainer.containerPadding
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
                        let shouldRun = root.visible && !Config.showMirror && mediaDevices.defaultVideoInput !== null
                        if (shouldRun) {
                            if (!camLoader.active && !attachTimer.running) attachTimer.restart()
                        } else {
                            attachTimer.stop()
                            camLoader.active = false
                        }
                    }

                    Connections { target: Config; function onShowMirrorChanged() { previewWrapper.evaluateCamera() } }
                    Connections { target: root; function onVisibleChanged() { previewWrapper.evaluateCamera() } }
                    Connections { target: mediaDevices; function onDefaultVideoInputChanged() { previewWrapper.evaluateCamera() } }
                    
                    Component.onCompleted: evaluateCamera()
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