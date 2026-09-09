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
    property bool mirrorLoading: false
    property string mirrorError: ""

    // --- DESKTOP WIDGET POSITION & PERSISTENCE ---
    // Single roaming instance (only one camera feed makes sense at a time),
    // same as Mascot/MediaCard/Assistant - mirrorLastScreen records which
    // screen it's on so a restart doesn't just fall back to whatever
    // monitor happens to be focused/first.
    property var mirrorPositions: ({})
    property string mirrorLastScreen: ""

    function getMirrorPosition(screenName, defaultX, defaultY) {
        if (mirrorPositions && mirrorPositions[screenName]) {
            return mirrorPositions[screenName]
        }
        return { x: defaultX, y: defaultY }
    }

    function saveMirrorPosition(screenName, x, y) {
        let current = Object.assign({}, mirrorPositions)
        current[screenName] = { x: x, y: y }
        mirrorPositions = current
        mirrorLastScreen = screenName
        if (configRef) configRef.saveSettings()
    }

    // Corner-drag resizable, same as MediaCardWidget.qml - see its file
    // comment for why a layer-shell surface needs this manual approach
    // instead of a native resize protocol.
    property real mirrorWidth: 380
    property real mirrorHeight: 340

    function saveMirrorSize(width, height) {
        mirrorWidth = width
        mirrorHeight = height
        if (configRef) configRef.saveSettings()
    }

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
                        active: false

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

                        Component.onCompleted: {
                            applyRawFormat()
                            // Defer opening the device to the next event loop tick so the
                            // panel and its loading overlay get to render a frame first —
                            // opening the camera synchronously here would block the whole
                            // popout animation until the (often slow) hardware init finishes.
                            Qt.callLater(() => { globalMirrorCamera.active = true })
                        }
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

    onShowMirrorChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onMirrorShowPanelChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onMirrorMirroredChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onMirrorKeepAspectChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
}
