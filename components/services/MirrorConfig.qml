import QtQuick
import QtMultimedia

QtObject {
    id: mirrorRoot

    property var configRef: null

    // --- CAMERA / MIRROR (LAZY LOADED) ---
    property bool showMirror: false
    property bool mirrorShowPanel: true
    property bool mirrorMirrored: true
    property bool mirrorKeepAspect: true
    property bool mirrorExpanded: false
    property bool mirrorPinned: false
    property string mirrorAnchorPos: "center"
    property bool mirrorLoading: false
    property string mirrorError: ""

    // Lazy load the QtMultimedia backend only when mirror is visible
    property Loader mirrorLoader: Loader {
        id: mirrorLoader
        active: mirrorRoot.showMirror

        sourceComponent: Component {
            QtObject {
                id: mirrorBackend

                property MediaDevices mediaDevices: MediaDevices {}

                property CaptureSession captureSession: CaptureSession {
                    id: globalMirrorCaptureSession
                    camera: Camera {
                        id: globalMirrorCamera
                        cameraDevice: mirrorBackend.mediaDevices.defaultVideoInput
                        active: true

                        onActiveChanged: {
                            if (active) {
                                mirrorRoot.mirrorLoading = false
                                mirrorRoot.mirrorError = ""
                            }
                        }

                        function applyRawFormat() {
                            if (!cameraDevice) {
                                mirrorRoot.mirrorLoading = false
                                mirrorRoot.mirrorError = "No camera device found"
                                return
                            }
                            let formats = cameraDevice.videoFormats
                            if (formats && formats.length > 0) {
                                let bestFormat = undefined
                                let bestScore = -1
                                for (let i = 0; i < formats.length; ++i) {
                                    let f = formats[i]
                                    let fpsTarget = Math.min(f.maxFrameRate, 30)
                                    let width = f.resolution.width
                                    let widthScore = width <= 1280 ? width : (1280 - (width - 1280))
                                    let score = (fpsTarget * 10000) + widthScore
                                    if (score > bestScore) {
                                        bestScore = score
                                        bestFormat = f
                                    }
                                }
                                if (bestFormat) cameraFormat = bestFormat
                            }
                        }

                        Component.onCompleted: applyRawFormat()
                    }
                }

                property Connections deviceWatcher: Connections {
                    target: mirrorBackend.mediaDevices
                    function onDefaultVideoInputChanged() {
                        if (mirrorBackend.mediaDevices.defaultVideoInput) {
                            mirrorRoot.mirrorError = ""
                            mirrorBackend.captureSession.camera.applyRawFormat()
                        } else {
                            mirrorRoot.mirrorLoading = false
                            mirrorRoot.mirrorError = "No camera device found"
                        }
                    }
                }
            }
        }

        onActiveChanged: {
            if (active) {
                mirrorRoot.mirrorLoading = true
                mirrorRoot.mirrorError = ""
            } else {
                mirrorRoot.mirrorLoading = false
                mirrorRoot.mirrorError = ""
            }
        }
    }

    // Accessors for external consumers
    readonly property CaptureSession mirrorCaptureSession: mirrorLoader.item ? mirrorLoader.item.captureSession : null
    readonly property MediaDevices mirrorMediaDevices: mirrorLoader.item ? mirrorLoader.item.mediaDevices : null

    function cycleMirrorAnchor(direction) {
        if (direction === "up" || direction === "left" || direction === "prev") {
            if (mirrorAnchorPos === "bottom") mirrorAnchorPos = "center"
            else if (mirrorAnchorPos === "center") mirrorAnchorPos = "top"
            else mirrorAnchorPos = "bottom"
        } else if (direction === "down" || direction === "right" || direction === "next") {
            if (mirrorAnchorPos === "top") mirrorAnchorPos = "center"
            else if (mirrorAnchorPos === "center") mirrorAnchorPos = "bottom"
            else mirrorAnchorPos = "top"
        }
    }

    onShowMirrorChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onMirrorShowPanelChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onMirrorMirroredChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onMirrorKeepAspectChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onMirrorExpandedChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onMirrorPinnedChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onMirrorAnchorPosChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
}
