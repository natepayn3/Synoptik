import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import Qt.labs.platform
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

// Desktop widget counterpart to Mascot.qml/MediaCardWidget.qml - a single
// roaming camera-preview card (only one camera feed makes sense at a time,
// so this follows the singleton pattern, not the per-screen one Clock/Cava/
// SysInfo use). Toggled from the shared WidgetContextMenu right-click menu
// like every other desktop widget, instead of a dedicated bar icon/popout.
// Same layer-shell PanelWindow + drag-anchor/ghostBody architecture as the
// rest of components/widgets - see MediaCardWidget.qml's file comment for
// why (manual local x/y instead of startSystemMove()).
PanelWindow {
    id: mirrorWindow
    visible: Config.showMirror

    Component.onCompleted: {
        let activeName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        let found = Quickshell.screens.find(s => s.name === activeName)
        mirrorWindow.screen = found || Quickshell.screens[0]
    }

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-mirror"
    WlrLayershell.keyboardFocus: (typeof widgetMenu !== "undefined" && widgetMenu.visible) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    // -1 opts this surface out of other surfaces' exclusive zones, same as
    // ClockWidget/CavaWidget/Mascot - otherwise Hyprland shrinks this
    // full-screen surface to skip the bar's reserved strip, leaving nowhere
    // there to drag the card into.
    exclusiveZone: -1

    readonly property size minCardSize: Qt.size(300, 220)
    readonly property size maxCardSize: Qt.size(900, 700)

    // Math.max/Math.min don't actually clamp a NaN input - it just
    // propagates straight through untouched, so a corrupted/missing saved
    // size always falls back to a valid one instead of silently producing
    // an invisible zero-size card. Same guard as MediaCardWidget.qml.
    function clampSize(value, lo, hi, fallback) {
        if (typeof value !== "number" || !isFinite(value)) return fallback
        return Math.max(lo, Math.min(hi, value))
    }

    // The third region only matters while the mouse is down - see
    // CavaWidget.qml's identical mask comment for the full explanation of
    // why (fast flicks outrunning a small input region on a layer-shell
    // surface). Also gated on mirrorContainer.anyResizeActive, not just
    // dragArea.pressed: the resize edges are only a few px thick, so even
    // modest cursor movement past the edge being dragged would otherwise
    // outrun the mask almost immediately - that was the resize feeling
    // like it kept "letting go" unless dragged extremely slowly.
    mask: Region {
        Region { item: mirrorContainer }
        Region { item: (typeof widgetMenu !== "undefined" && widgetMenu.visible) ? widgetMenu : null }
        Region { item: (dragArea.pressed || mirrorContainer.anyResizeActive) ? fullScreenDragCatch : null }
    }

    Item { id: fullScreenDragCatch; anchors.fill: parent }

    SnapGridOverlay {
        anchors.fill: parent
        gridSize: ghostBody.gridSize
        active: dragArea.drag.active && Config.snapDesktopWidgets
        targetX: ghostBody.x
        targetY: ghostBody.y
        targetWidth: ghostBody.width
        targetHeight: ghostBody.height
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

    // Attach localOutput to the global Config session dynamically
    function attachSession() {
        if (Config.mirrorCaptureSession) {
            Config.mirrorCaptureSession.videoOutput = localOutput
            if (Config.mirrorCaptureSession.camera) {
                if (mirrorWindow.visible && Config.showMirror) {
                    // Deferred so this (potentially slow) hardware open never blocks
                    // the widget's opening animation or the loading overlay's first frame.
                    Qt.callLater(() => {
                        if (Config.mirrorCaptureSession && Config.mirrorCaptureSession.camera) {
                            Config.mirrorCaptureSession.camera.active = true
                        }
                    })
                } else if (Config.mirrorCaptureSession.camera.active) {
                    Config.mirrorCaptureSession.camera.active = false
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) attachSession()
    }

    Connections {
        target: Config
        ignoreUnknownSignals: true
        function onMirrorCaptureSessionChanged() {
            mirrorWindow.attachSession()
        }
        function onShowMirrorChanged() {
            if (!Config.mirrorCaptureSession || !Config.mirrorCaptureSession.camera) return
            if (Config.showMirror) {
                Qt.callLater(() => {
                    if (Config.mirrorCaptureSession && Config.mirrorCaptureSession.camera) {
                        Config.mirrorCaptureSession.camera.active = true
                    }
                })
            } else {
                Config.mirrorCaptureSession.camera.active = false
            }
        }
    }

    // Invisible drag/resize-anchor / hit-region. Owns cardWidth/cardHeight -
    // the ghostBody visual skin below just mirrors them - same split as
    // MediaCardWidget.qml's mediaCardContainer/ghostBody.
    Item {
        id: mirrorContainer
        z: 10

        property real dragX: 0
        property real dragY: 0
        property real cardWidth: 380
        property real cardHeight: 340
        property bool initialized: false

        x: dragX
        y: dragY
        width: cardWidth
        height: cardHeight

        Timer {
            id: sizeSaveDebounce
            interval: 400
            onTriggered: Config.saveMirrorSize(mirrorContainer.cardWidth, mirrorContainer.cardHeight)
        }
        onCardWidthChanged: sizeSaveDebounce.restart()
        onCardHeightChanged: sizeSaveDebounce.restart()

        // Restores the last dragged-to position (falling back to
        // screen-center) once both the parent window has a real size and
        // Config has finished loading - same two-trigger pattern as
        // Mascot.qml/ClockWidget.qml, since either can lag behind.
        Connections {
            target: mirrorWindow
            function onWidthChanged() { mirrorContainer.restorePosition() }
            function onHeightChanged() { mirrorContainer.restorePosition() }
        }

        Connections {
            target: Config
            function onIsLoadedChanged() { if (Config.isLoaded) mirrorContainer.restorePosition() }
        }

        function restorePosition() {
            if (initialized || mirrorWindow.width <= 0 || mirrorWindow.height <= 0 || !Config.isLoaded) return

            // mirrorWindow's own Component.onCompleted picks a screen from
            // Hyprland.focusedMonitor before Config has loaded (needed just
            // to get *some* size for the width/height guard above) - correct
            // it to the remembered screen now that we actually know it.
            if (Config.mirrorLastScreen && mirrorWindow.screen && Config.mirrorLastScreen !== mirrorWindow.screen.name) {
                let savedScreen = Quickshell.screens.find(s => s.name === Config.mirrorLastScreen)
                if (savedScreen) mirrorWindow.screen = savedScreen
            }

            cardWidth = mirrorWindow.clampSize(Config.mirrorWidth, mirrorWindow.minCardSize.width, mirrorWindow.maxCardSize.width, 380)
            cardHeight = mirrorWindow.clampSize(Config.mirrorHeight, mirrorWindow.minCardSize.height, mirrorWindow.maxCardSize.height, 340)

            let defaultX = Math.max(0, (mirrorWindow.width / 2) - (cardWidth / 2))
            let defaultY = Math.max(0, (mirrorWindow.height / 2) - (cardHeight / 2))

            let savedPos = mirrorWindow.screen
                ? Config.getMirrorPosition(mirrorWindow.screen.name, defaultX, defaultY)
                : { x: defaultX, y: defaultY }

            dragX = savedPos.x
            dragY = savedPos.y
            initialized = true
        }

        // Called from both drag.onActiveChanged and dragArea.onReleased below -
        // belt and suspenders against a lost/missed release event leaving
        // drag.active stuck true, same as the other widgets' commitGridSnap().
        // Idempotent: re-running this against an already-grid-aligned position
        // is a no-op.
        function commitGridSnap() {
            if (!Config.snapDesktopWidgets) return
            dragX = Math.round(dragX / ghostBody.gridSize) * ghostBody.gridSize
            dragY = Math.round(dragY / ghostBody.gridSize) * ghostBody.gridSize
            if (mirrorWindow.screen) {
                Config.saveMirrorPosition(mirrorWindow.screen.name, dragX, dragY)
            }
        }

        Component.onCompleted: restorePosition()

        onXChanged: {
            checkScreenBoundary()
            if (initialized && mirrorWindow.screen && (dragArea.drag.active || anyResizeActive)) {
                Config.saveMirrorPosition(mirrorWindow.screen.name, dragX, dragY)
            }
        }
        onYChanged: {
            checkScreenBoundary()
            if (initialized && mirrorWindow.screen && (dragArea.drag.active || anyResizeActive)) {
                Config.saveMirrorPosition(mirrorWindow.screen.name, dragX, dragY)
            }
        }

        // Lets a drag carry the card across onto a different monitor - same
        // approach as Mascot.qml's checkScreenBoundary().
        function checkScreenBoundary() {
            if (!dragArea.drag.active || !mirrorWindow.screen) return

            let globalX = mirrorWindow.screen.x + mirrorContainer.x
            let globalY = mirrorWindow.screen.y + mirrorContainer.y

            let centerX = globalX + (mirrorContainer.width / 2)
            let centerY = globalY + (mirrorContainer.height / 2)

            for (let i = 0; i < Quickshell.screens.length; i++) {
                let s = Quickshell.screens[i]
                if (s === mirrorWindow.screen) continue

                if (centerX >= s.x && centerX <= (s.x + s.width) &&
                    centerY >= s.y && centerY <= (s.y + s.height)) {

                    let newLocalX = globalX - s.x
                    let newLocalY = globalY - s.y

                    mirrorWindow.screen = s
                    mirrorContainer.dragX = newLocalX
                    mirrorContainer.dragY = newLocalY
                    break
                }
            }
        }

        // True while any ResizeEdge below is mid-drag - a left/top-edge
        // resize moves dragX/dragY as a side effect (keeping the opposite
        // corner fixed), so those position writes need to persist too, not
        // just the ones from dragArea's own move gesture.
        property bool anyResizeActive: false

        // --- MANUAL RESIZE ---
        // No native resize protocol exists for a layer-shell surface - see
        // MediaCardWidget.qml's file comment for the full rationale. Same
        // synchronous, lag-free approach: absolute cursor position mapped
        // into mirrorWindow (screen-anchored, never moves) tracked
        // cumulatively since press.
        component ResizeEdge: MouseArea {
            id: resizeEdge
            required property int edges

            hoverEnabled: true
            cursorShape: {
                if (edges === (Qt.LeftEdge | Qt.TopEdge) || edges === (Qt.RightEdge | Qt.BottomEdge)) return Qt.SizeFDiagCursor
                if (edges === (Qt.RightEdge | Qt.TopEdge) || edges === (Qt.LeftEdge | Qt.BottomEdge)) return Qt.SizeBDiagCursor
                if (edges === Qt.LeftEdge || edges === Qt.RightEdge) return Qt.SizeHorCursor
                return Qt.SizeVerCursor
            }

            property real startAbsX: 0
            property real startAbsY: 0
            property real startWidth: 0
            property real startHeight: 0
            property real startDragX: 0
            property real startDragY: 0

            onPressed: (mouse) => {
                let abs = mapToItem(fullScreenDragCatch, mouse.x, mouse.y)
                startAbsX = abs.x
                startAbsY = abs.y
                startWidth = mirrorContainer.cardWidth
                startHeight = mirrorContainer.cardHeight
                startDragX = mirrorContainer.dragX
                startDragY = mirrorContainer.dragY
                mirrorContainer.anyResizeActive = true
            }

            onPositionChanged: (mouse) => {
                // hoverEnabled (needed so cursorShape updates before a
                // click) makes this fire on plain hover too, not just a
                // real drag - without this guard the resize math runs
                // against uninitialized start* values on the very first
                // hover event.
                if (!resizeEdge.pressed) return

                let abs = mapToItem(fullScreenDragCatch, mouse.x, mouse.y)
                let deltaX = abs.x - startAbsX
                let deltaY = abs.y - startAbsY

                let newWidth = startWidth
                let newDragX = startDragX
                if (edges & Qt.RightEdge) {
                    newWidth = mirrorWindow.clampSize(startWidth + deltaX, mirrorWindow.minCardSize.width, mirrorWindow.maxCardSize.width, startWidth)
                } else if (edges & Qt.LeftEdge) {
                    newWidth = mirrorWindow.clampSize(startWidth - deltaX, mirrorWindow.minCardSize.width, mirrorWindow.maxCardSize.width, startWidth)
                    newDragX = startDragX + (startWidth - newWidth)
                }

                let newHeight = startHeight
                let newDragY = startDragY
                if (edges & Qt.BottomEdge) {
                    newHeight = mirrorWindow.clampSize(startHeight + deltaY, mirrorWindow.minCardSize.height, mirrorWindow.maxCardSize.height, startHeight)
                } else if (edges & Qt.TopEdge) {
                    newHeight = mirrorWindow.clampSize(startHeight - deltaY, mirrorWindow.minCardSize.height, mirrorWindow.maxCardSize.height, startHeight)
                    newDragY = startDragY + (startHeight - newHeight)
                }

                mirrorContainer.cardWidth = newWidth
                mirrorContainer.cardHeight = newHeight
                mirrorContainer.dragX = newDragX
                mirrorContainer.dragY = newDragY
            }

            onReleased: {
                mirrorContainer.anyResizeActive = false
                mirrorContainer.commitGridSnap()
            }
            onCanceled: mirrorContainer.anyResizeActive = false
        }

        readonly property real edgeThickness: 6
        // Scales with the user's actual configured corner rounding rather
        // than a fixed guess - see MediaCardWidget.qml's identical comment.
        readonly property real cornerSize: Math.max(18, Config.cornerRadius + 8)

        ResizeEdge {
            edges: Qt.TopEdge
            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: mirrorContainer.cornerSize; rightMargin: mirrorContainer.cornerSize }
            height: mirrorContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.BottomEdge
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: mirrorContainer.cornerSize; rightMargin: mirrorContainer.cornerSize }
            height: mirrorContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.LeftEdge
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: mirrorContainer.cornerSize; bottomMargin: mirrorContainer.cornerSize }
            width: mirrorContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.RightEdge
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: mirrorContainer.cornerSize; bottomMargin: mirrorContainer.cornerSize }
            width: mirrorContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.LeftEdge | Qt.TopEdge
            anchors { top: parent.top; left: parent.left }
            width: mirrorContainer.cornerSize; height: mirrorContainer.cornerSize
        }
        ResizeEdge {
            edges: Qt.RightEdge | Qt.TopEdge
            anchors { top: parent.top; right: parent.right }
            width: mirrorContainer.cornerSize; height: mirrorContainer.cornerSize
        }
        ResizeEdge {
            edges: Qt.LeftEdge | Qt.BottomEdge
            anchors { bottom: parent.bottom; left: parent.left }
            width: mirrorContainer.cornerSize; height: mirrorContainer.cornerSize
        }
        ResizeEdge {
            edges: Qt.RightEdge | Qt.BottomEdge
            anchors { bottom: parent.bottom; right: parent.right }
            width: mirrorContainer.cornerSize; height: mirrorContainer.cornerSize
        }

        WidgetContextMenu { id: widgetMenu; hostWidgetId: "mirror" }
    }

    // Visible skin, decoupled from mirrorContainer (the drag anchor / hit
    // region above) precisely so Behavior can animate it - see the note by
    // mirrorContainer.x for why. Hosts the actual card content AND the drag
    // MouseArea (kept at a lower z than the card's own buttons below, same
    // as MediaCardWidget.qml) so button clicks take priority over dragging.
    Item {
        id: ghostBody
        readonly property real gridSize: 24

        // Snap ON: round to a visible grid, no easing. Snap OFF: the exact
        // position, eased in via Behavior below. Only round to the grid
        // *while actively dragging* - at rest this must equal
        // mirrorContainer exactly, or the visible skin and the invisible
        // hit-region it's grabbed by permanently drift apart.
        x: (Config.snapDesktopWidgets && dragArea.drag.active) ? Math.round(mirrorContainer.x / gridSize) * gridSize : mirrorContainer.x
        y: (Config.snapDesktopWidgets && dragArea.drag.active) ? Math.round(mirrorContainer.y / gridSize) * gridSize : mirrorContainer.y
        // Size never grid-snaps (only position does) and never lags behind
        // a live resize - direct mirror, no Behavior.
        width: mirrorContainer.cardWidth
        height: mirrorContainer.cardHeight

        Behavior on x {
            enabled: !Config.snapDesktopWidgets
            NumberAnimation {
                duration: Config.motionService.durationFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Config.motionService.expressiveFastSpatialPoints
            }
        }
        Behavior on y {
            enabled: !Config.snapDesktopWidgets
            NumberAnimation {
                duration: Config.motionService.durationFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Config.motionService.expressiveFastSpatialPoints
            }
        }

        Item {
            id: mainColumn
            anchors.fill: parent
            anchors.margins: Config.cardMargin

            // ClippingRectangle (not plain Rectangle) so the watermark actually
            // respects the rounded corners instead of bleeding past them - plain
            // Rectangle.clip only clips to the square bounding box. The panel's
            // border lives here (the outer edge of the widget), not on the
            // camera canvas inside it.
            ClippingRectangle {
                anchors.fill: parent
                color: Qt.rgba(255, 255, 255, 0.05)
                radius: Config.cornerRadius
                border.width: Config.showBorders ? Config.borderThickness : 0
                border.color: (typeof shellRoot !== "undefined" && shellRoot.currentBorderColor) ? shellRoot.currentBorderColor : Config.accent

                // GRAPHIC WATERMARK
                Watermark {
                    icon: Config.getIcon("mirror")
                    iconSize: 150
                    seed: 28
                }

                ColumnLayout {
                    id: cardLayout
                    anchors.fill: parent
                    anchors.margins: Config.cardMargin
                    spacing: 12

                    // HEADER
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item {
                            implicitWidth: mirrorTitleText.implicitWidth
                            implicitHeight: mirrorTitleText.implicitHeight
                            Layout.fillWidth: true

                            Glow {
                                anchors.fill: mirrorTitleText
                                source: mirrorTitleText
                                radius: 8
                                samples: 16
                                color: Config.accent
                                spread: 0.2
                                transparentBorder: true
                                visible: Config.clockShowGlow
                            }

                            Text {
                                id: mirrorTitleText
                                anchors.fill: parent
                                text: "MIRROR"
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontTitle)
                                font.bold: true
                                font.italic: true
                                elide: Text.ElideRight
                            }
                        }

                        // ASPECT / CROP TOGGLE BUTTON
                        Rectangle {
                            implicitWidth: 26; implicitHeight: 26; radius: 13
                            color: cropBtnHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: Config.mirrorKeepAspect ? "crop" : "crop_free"
                                color: Config.mirrorKeepAspect ? Config.accent : Config.textMuted
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 16
                                font.bold: true
                            }

                            TapHandler { onTapped: Config.mirrorKeepAspect = !Config.mirrorKeepAspect }
                            HoverHandler { id: cropBtnHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }

                    // CAMERA DISPLAY CANVAS
                    Rectangle {
                        id: cameraCanvas
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Config.cornerRadius / 2
                        color: Qt.rgba(0, 0, 0, 0.35)
                        clip: true

                        Item {
                            id: videoWrapper
                            anchors.fill: parent
                            clip: true

                            VideoOutput {
                                id: localOutput
                                anchors.fill: parent
                                fillMode: Config.mirrorKeepAspect ? VideoOutput.PreserveAspectCrop : VideoOutput.PreserveAspectFit
                                visible: true

                                transform: Scale {
                                    origin.x: localOutput.width / 2
                                    xScale: Config.mirrorMirrored ? 1 : -1
                                }

                                Component.onCompleted: {
                                    mirrorWindow.attachSession()
                                }
                                Component.onDestruction: {
                                    if (Config.mirrorCaptureSession && Config.mirrorCaptureSession.videoOutput === localOutput) {
                                        Config.mirrorCaptureSession.videoOutput = null
                                    }
                                }
                            }
                        }

                        // LOADING / ERROR OVERLAY
                        Rectangle {
                            id: loadingOverlay
                            anchors.fill: videoWrapper
                            color: Qt.rgba(15 / 255, 15 / 255, 18 / 255, 0.92)
                            z: 90
                            radius: Config.cornerRadius / 2
                            visible: opacity > 0
                            opacity: (Config.mirrorLoading || (Config.mirrorError && Config.mirrorError !== "")) ? 1.0 : 0.0

                            Behavior on opacity {
                                NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 10

                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: 40
                                    implicitHeight: 40

                                    Text {
                                        id: spinnerIcon
                                        anchors.centerIn: parent
                                        text: (Config.mirrorError && Config.mirrorError !== "") ? "videocam_off" : "progress_activity"
                                        color: (Config.mirrorError && Config.mirrorError !== "") ? "#ff5555" : Config.accent
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 32
                                        font.bold: true

                                        RotationAnimation on rotation {
                                            from: 0
                                            to: 360
                                            duration: 1100
                                            loops: Animation.Infinite
                                            running: Config.mirrorLoading && (!Config.mirrorError || Config.mirrorError === "")
                                        }
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: (Config.mirrorError && Config.mirrorError !== "") ? Config.mirrorError : "Loading..."
                                    color: (Config.mirrorError && Config.mirrorError !== "") ? "#ff8888" : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontBody)
                                    font.bold: true
                                }
                            }
                        }

                        // SNAPSHOT FLASH OVERLAY
                        Rectangle {
                            id: flashOverlay
                            anchors.fill: videoWrapper
                            color: "#ffffff"
                            opacity: 0.0
                            z: 99
                            radius: Config.cornerRadius / 2

                            NumberAnimation on opacity {
                                id: flashAnimation
                                running: false
                                from: 0.85
                                to: 0.0
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }

                        // CANVAS OVERLAY CONTROLS
                        RowLayout {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 10
                            spacing: 8
                            z: 100

                            // FLIP HORIZONTAL TOGGLE
                            Rectangle {
                                implicitWidth: 32; implicitHeight: 32; radius: 16
                                color: flipHover.hovered ? Config.accent : Qt.rgba(0, 0, 0, 0.4)
                                opacity: flipHover.hovered ? 1.0 : 0.7

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "flip_camera_android"
                                    color: "#ffffff"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                                TapHandler { onTapped: Config.mirrorMirrored = !Config.mirrorMirrored }
                                HoverHandler { id: flipHover; cursorShape: Qt.PointingHandCursor }
                            }

                            // SNAPSHOT BUTTON
                            Rectangle {
                                implicitWidth: 32; implicitHeight: 32; radius: 16
                                color: snapHover.hovered ? Config.accent : Qt.rgba(0, 0, 0, 0.4)
                                opacity: snapHover.hovered ? 1.0 : 0.7

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "photo_camera"
                                    color: "#ffffff"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                                TapHandler { onTapped: mirrorWindow.takeSnapshot() }
                                HoverHandler { id: snapHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }
            }
        }

        // --- MOVE + RIGHT-CLICK WIDGET MENU ---
        // Declared after the card content above so buttons keep click
        // priority, but z:-1 makes that explicit too - same as
        // MediaCardWidget.qml's dragArea.
        MouseArea {
            id: dragArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            z: -1

            property bool dragMoved: false

            onPressed: dragMoved = false

            drag {
                target: mirrorContainer
                axis: Drag.XAndYAxis

                onActiveChanged: {
                    if (!drag.active) mirrorContainer.commitGridSnap()
                }
            }

            onReleased: if (dragMoved) mirrorContainer.commitGridSnap()

            onPositionChanged: {
                if (drag.active) {
                    dragMoved = true
                    mirrorContainer.dragX = mirrorContainer.x
                    mirrorContainer.dragY = mirrorContainer.y
                }
            }

            onClicked: (mouse) => {
                if (widgetMenu.visible) {
                    widgetMenu.close()
                    return
                }
                if (mouse.button === Qt.RightButton) {
                    widgetMenu.openAt(mouse.x, mouse.y, mirrorContainer, mirrorWindow.width, mirrorWindow.height)
                    return
                }
                Config.closeWidgetMenus()
            }
        }
    }
}
