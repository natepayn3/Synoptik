import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

// Detached floating counterpart to controlcenter/MediaCard.qml - a small
// panel showing the same thumbnail art + radial cava visualizer + transport
// controls, so playback stays visible/controllable without keeping Control
// Center open.
//
// A layer-shell PanelWindow, same architecture as ClockWidget/Mascot/etc -
// NOT a real xdg-toplevel FloatingWindow, which an earlier version of this
// file was. That approach handed move/resize off to
// startSystemMove()/startSystemResize(), which turned out to be a dead end:
// once called, Hyprland owns the gesture entirely over the xdg_toplevel
// protocol, with no guarantee of ANY further pointer events (including
// release) being delivered back to the client - confirmed empirically (zero
// events after a real drag). A rebuilt manual-move version that dispatched
// absolute moves over Hyprland's IPC on every pointer event also failed:
// that dispatch is asynchronous, so pointer events kept arriving faster than
// the window's on-screen position could catch up, and the same
// tracked-position math that (correctly) updated every frame double-counted
// drift against a baseline that hadn't actually been reached yet - runaway
// exponential drift in practice.
//
// None of that class of bug is possible here: position and size are plain
// local QML properties written synchronously in the same process, exactly
// like every other desktop widget's drag-anchor + snap-grid ghostBody model
// (see ClockWidget.qml's file comment for the full rationale). Resize is the
// one thing the other widgets don't need - see the ResizeEdge component
// below for the manual (but synchronous, lag-free) equivalent.
//
// Single roaming instance (like Mascot, not per-screen like Clock/Cava/
// SysInfo) - see mediaCardContainer.restorePosition() below.
PanelWindow {
    id: mediaCardWindow
    visible: Config.showDesktopMediaCard

    Component.onCompleted: {
        let activeName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        let found = Quickshell.screens.find(s => s.name === activeName)
        mediaCardWindow.screen = found || Quickshell.screens[0]
    }

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-desktop-mediacard"
    WlrLayershell.keyboardFocus: (typeof widgetMenu !== "undefined" && widgetMenu.visible) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: -1

    readonly property size minCardSize: Qt.size(160, 90)
    readonly property size maxCardSize: Qt.size(480, 420)

    // Math.max/Math.min don't actually clamp a NaN input - it just
    // propagates straight through untouched, and a NaN real property can
    // round-trip through Quickshell's JSON persistence as a plain 0 (seen
    // once already: a corrupted mediaCardWidth of exactly 0, below the
    // supposedly-enforced 160 minimum). Route every resize/restore
    // computation through this instead of a bare Math.max/min clamp so a
    // stray NaN (or a missing/undefined saved value) always falls back to a
    // safe, valid size rather than silently producing an invisible
    // zero-size card.
    function clampSize(value, lo, hi, fallback) {
        if (typeof value !== "number" || !isFinite(value)) return fallback
        return Math.max(lo, Math.min(hi, value))
    }

    // The third region only matters while the mouse is down - see
    // ClockWidget.qml's identical mask comment for the full explanation of
    // why (fast flicks outrunning a small input region on a layer-shell
    // surface).
    mask: Region {
        Region { item: mediaCardContainer }
        Region { item: (typeof widgetMenu !== "undefined" && widgetMenu.visible) ? widgetMenu : null }
        Region { item: dragArea.pressed ? fullScreenDragCatch : null }
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

    readonly property real cardPad: 10
    readonly property bool isVertical: mediaCardContainer.cardHeight > mediaCardContainer.cardWidth

    readonly property bool isStopped: mediaTitle === "Not Playing" || mediaTitle === "" || mediaStatus === "Stopped"
    readonly property string mediaTitle: (typeof shellRoot !== "undefined" && shellRoot.mediaTitle) ? shellRoot.mediaTitle : "Not Playing"
    readonly property string mediaArtist: (typeof shellRoot !== "undefined" && shellRoot.mediaArtist) ? shellRoot.mediaArtist : "---"
    readonly property string mediaStatus: (typeof shellRoot !== "undefined" && shellRoot.mediaStatus) ? shellRoot.mediaStatus : "Stopped"
    readonly property string mediaArtUrl: (typeof shellRoot !== "undefined" && shellRoot.mediaArtUrl) ? shellRoot.mediaArtUrl : ""
    property var cavaBars: []

    // Per-track accent sampled from the album art, same approach as
    // MediaCard.qml's colorSampler below.
    property color dynamicAccent: Config.accent
    onMediaArtUrlChanged: if (mediaArtUrl === "") dynamicAccent = Config.accent

    property double trackPosition: 0
    property double trackLength: 0

    function formatTime(sec) {
        if (isNaN(sec) || sec <= 0) return "0:00"
        let m = Math.floor(sec / 60)
        let s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function sendCommand(cmd) {
        mediaControlProc.command = cmd
        mediaControlProc.running = true
    }

    function seekRelative(offsetSec) {
        let sign = offsetSec >= 0 ? "+" : "-"
        let val = Math.abs(offsetSec)
        sendCommand(["playerctl", "position", `${val}${sign}`])
        mediaCardWindow.trackPosition = Math.max(0, mediaCardWindow.trackPosition + offsetSec)
    }

    Process { id: mediaControlProc; running: false }

    Process {
        id: mediaPosProc
        command: ["fish", "-c", "playerctl position; playerctl metadata mpris:length"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                if (lines.length >= 1 && lines[0] !== "") {
                    let pos = parseFloat(lines[0])
                    if (!isNaN(pos)) mediaCardWindow.trackPosition = pos
                }
                if (lines.length >= 2 && lines[1] !== "") {
                    let len = parseFloat(lines[1])
                    if (!isNaN(len)) mediaCardWindow.trackLength = len / 1000000.0
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: Config.showDesktopMediaCard && mediaCardWindow.mediaStatus === "Playing"
        repeat: true
        triggeredOnStart: true
        onTriggered: mediaPosProc.running = true
    }

    // Dedicated cava feed scaled 0-255 (not the shared Config.cavaService,
    // whose bars are pre-normalized 0-1 for the desktop visualizer/ambient
    // breathing) - same config shape as ControlCenter.qml's MediaCard feed,
    // gated on this panel's own visibility instead of Control Center's.
    Process {
        id: cavaProc
        command: ["fish", "-c", "printf '[general]\\nbars = 32\\nsensitivity = 150\\n[output]\\nmethod = raw\\ndata_format = ascii\\nascii_max_range = 255\\nbar_delimiter = 59\\nframe_delimiter = 10\\n' | cava -p /dev/stdin"]
        running: Config.showDesktopMediaCard && mediaCardWindow.mediaStatus === "Playing"

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                let clean = data.trim()
                if (!clean) return
                let points = clean.split(';')
                let arr = []
                for (let i = 0; i < points.length; i++) {
                    if (points[i] !== "") arr.push(parseInt(points[i], 10) || 0)
                }
                if (arr.length > 0) mediaCardWindow.cavaBars = arr
            }
        }
    }

    // Tiny hidden canvas used purely to sample an average color out of the
    // currently loaded album art - identical approach to MediaCard.qml.
    Canvas {
        id: colorSampler
        width: 8
        height: 8
        visible: false
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        function sample() {
            if (artImage.status !== Image.Ready) return
            var ctx = getContext("2d")
            // getContext() can momentarily return null right as this Canvas
            // is created (this widget mounts immediately at startup, unlike
            // MediaCard.qml's copy which only ever mounts once Control
            // Center is already open and settled).
            if (!ctx) return
            ctx.clearRect(0, 0, width, height)
            try {
                ctx.drawImage(artImage, 0, 0, width, height)
                var data = ctx.getImageData(0, 0, width, height).data
                var r = 0, g = 0, b = 0, n = 0
                for (var i = 0; i < data.length; i += 4) {
                    if (data[i + 3] < 16) continue
                    r += data[i]; g += data[i + 1]; b += data[i + 2]
                    n++
                }
                if (n === 0) return
                var avg = Qt.rgba((r / n) / 255, (g / n) / 255, (b / n) / 255, 1.0)
                var sat = Math.max(avg.hslSaturation, 0.5)
                var light = Math.min(Math.max(avg.hslLightness, 0.4), 0.62)
                mediaCardWindow.dynamicAccent = Qt.hsla(avg.hslHue, sat, light, 1.0)
            } catch (e) {
                // Pixel readback can fail for some image sources - keep the
                // previous accent rather than breaking the widget.
            }
        }
    }

    Connections {
        target: artImage
        function onStatusChanged() {
            if (artImage.status === Image.Ready) colorSampler.sample()
        }
    }

    // This item is the drag/resize anchor and always tracks the cursor 1:1 -
    // it's also the window's input mask, so hit-testing must never lag. The
    // visible skin lives on the sibling ghostBody item instead, which
    // follows this one via a genuine binding (x: mediaCardContainer.x)
    // rather than a direct external write, which is what actually lets a
    // Behavior animate it - see ClockWidget.qml's identical note.
    //
    // z is elevated above ghostBody (z: 0, default) so this item's children
    // - the 8 ResizeEdges below - always win hit-testing over ghostBody's
    // visual content in the narrow edge/corner strips where they overlap
    // (e.g. the top-right resize corner vs. the close button). Everywhere
    // else this item has no children to compete with, so it's a no-op there
    // - ghostBody's buttons/seekbar/close button/dragArea are completely
    // unaffected.
    Item {
        id: mediaCardContainer
        z: 10

        property real dragX: 0
        property real dragY: 0
        property real cardWidth: 232
        property real cardHeight: 108
        property bool initialized: false

        x: dragX
        y: dragY
        width: cardWidth
        height: cardHeight

        Timer {
            id: sizeSaveDebounce
            interval: 400
            onTriggered: Config.saveMediaCardSize(mediaCardContainer.cardWidth, mediaCardContainer.cardHeight)
        }
        onCardWidthChanged: sizeSaveDebounce.restart()
        onCardHeightChanged: sizeSaveDebounce.restart()

        // Restores the last dragged-to position/size for this screen (falling
        // back to a bottom-right-ish default) once both the parent window has
        // a real size and Config has finished loading - same two-trigger
        // pattern as Mascot.qml/ClockWidget.qml, since either can lag behind.
        Connections {
            target: mediaCardWindow
            function onWidthChanged() { mediaCardContainer.restorePosition() }
            function onHeightChanged() { mediaCardContainer.restorePosition() }
        }

        Connections {
            target: Config
            function onIsLoadedChanged() { if (Config.isLoaded) mediaCardContainer.restorePosition() }
        }

        function restorePosition() {
            if (initialized || mediaCardWindow.width <= 0 || mediaCardWindow.height <= 0 || !Config.isLoaded) return

            // mediaCardWindow's own Component.onCompleted picks a screen from
            // Hyprland.focusedMonitor before Config has loaded (needed just
            // to get *some* size for the width/height guard above) - correct
            // it to the remembered screen now that we actually know it.
            if (Config.mediaCardLastScreen && mediaCardWindow.screen && Config.mediaCardLastScreen !== mediaCardWindow.screen.name) {
                let savedScreen = Quickshell.screens.find(s => s.name === Config.mediaCardLastScreen)
                if (savedScreen) mediaCardWindow.screen = savedScreen
            }

            cardWidth = mediaCardWindow.clampSize(Config.mediaCardWidth, mediaCardWindow.minCardSize.width, mediaCardWindow.maxCardSize.width, 232)
            cardHeight = mediaCardWindow.clampSize(Config.mediaCardHeight, mediaCardWindow.minCardSize.height, mediaCardWindow.maxCardSize.height, 108)

            let defaultX = Math.max(0, mediaCardWindow.width - cardWidth - 60)
            let defaultY = Math.max(0, mediaCardWindow.height - cardHeight - 60)

            let savedPos = mediaCardWindow.screen
                ? Config.getMediaCardPosition(mediaCardWindow.screen.name, defaultX, defaultY)
                : { x: defaultX, y: defaultY }

            dragX = savedPos.x
            dragY = savedPos.y
            initialized = true
        }

        // Called from drag.onActiveChanged, dragArea.onReleased, and every
        // ResizeEdge.onReleased below - belt and suspenders against a lost
        // release event leaving things out of sync, same as
        // ClockWidget.qml's commitGridSnap(). Idempotent, and position-only:
        // size never grid-snaps, only the drag position does.
        function commitGridSnap() {
            if (!Config.snapDesktopWidgets) return
            dragX = Math.round(dragX / ghostBody.gridSize) * ghostBody.gridSize
            dragY = Math.round(dragY / ghostBody.gridSize) * ghostBody.gridSize
            if (mediaCardWindow.screen) {
                Config.saveMediaCardPosition(mediaCardWindow.screen.name, dragX, dragY)
            }
        }

        Component.onCompleted: restorePosition()

        onXChanged: {
            checkScreenBoundary()
            if (initialized && mediaCardWindow.screen && (dragArea.drag.active || anyResizeActive)) {
                Config.saveMediaCardPosition(mediaCardWindow.screen.name, dragX, dragY)
            }
        }
        onYChanged: {
            checkScreenBoundary()
            if (initialized && mediaCardWindow.screen && (dragArea.drag.active || anyResizeActive)) {
                Config.saveMediaCardPosition(mediaCardWindow.screen.name, dragX, dragY)
            }
        }

        // Lets a drag carry the card across onto a different monitor - same
        // approach as Mascot.qml's checkScreenBoundary(): once the card's
        // center crosses onto another screen's rect, re-parent this whole
        // PanelWindow to that screen and re-express dragX/dragY in its local
        // coordinate space (global position stays continuous through the
        // switch, so there's no visible jump). Resize-only moves don't need
        // this (a corner nudging dragX/dragY by a few px never crosses a
        // monitor boundary in practice), so it's gated on dragArea.drag.active.
        function checkScreenBoundary() {
            if (!dragArea.drag.active || !mediaCardWindow.screen) return

            let cur = mediaCardWindow.screen
            let globalX = cur.x + mediaCardContainer.x
            let globalY = cur.y + mediaCardContainer.y

            let centerX = globalX + (mediaCardContainer.width / 2)
            let centerY = globalY + (mediaCardContainer.height / 2)

            // Still within the current screen's own rect - stop here, no
            // need to consider any other screen.
            if (centerX >= cur.x && centerX <= (cur.x + cur.width) &&
                centerY >= cur.y && centerY <= (cur.y + cur.height)) {
                return
            }

            for (let i = 0; i < Quickshell.screens.length; i++) {
                let s = Quickshell.screens[i]
                if (s === cur) continue

                if (centerX >= s.x && centerX <= (s.x + s.width) &&
                    centerY >= s.y && centerY <= (s.y + s.height)) {

                    let newLocalX = globalX - s.x
                    let newLocalY = globalY - s.y

                    mediaCardWindow.screen = s
                    mediaCardContainer.dragX = newLocalX
                    mediaCardContainer.dragY = newLocalY
                    return
                }
            }

            // Cursor has dragged the card's center out of every screen's
            // rect at once - a real dead zone between differently
            // sized/aligned monitors (this rig's DP-1 is rotated to
            // portrait - 1440x2560 - and only overlaps DP-2's y-range for
            // part of its own height, so there's empty space directly off
            // DP-1's right edge above y=763 that belongs to neither
            // screen). Clamp back onto the current screen's own bounds
            // instead of leaving dragX/dragY to drift arbitrarily far past
            // it - MouseArea.drag doesn't clamp on its own, and an
            // unclamped drag through here is exactly what corrupted the
            // saved position last time (x=2280 persisted against DP-1,
            // whose real - rotated - width is only 1440, putting the card
            // entirely off its own surface and invisible). This also gives
            // the card the expected "hugs the edge" feel: it stays pinned
            // at the boundary until the cursor is actually over a screen
            // that covers where it would go next.
            mediaCardContainer.dragX = Math.max(0, Math.min(cur.width - mediaCardContainer.width, mediaCardContainer.dragX))
            mediaCardContainer.dragY = Math.max(0, Math.min(cur.height - mediaCardContainer.height, mediaCardContainer.dragY))
        }

        // True while any ResizeEdge below is mid-drag - a left/top-edge
        // resize moves dragX/dragY as a side effect (keeping the opposite
        // corner fixed), so those position writes need to persist too, not
        // just the ones from dragArea's own move gesture.
        property bool anyResizeActive: false

        // --- MANUAL RESIZE ---
        // No native resize protocol exists for a layer-shell surface (that's
        // exactly what motivated the old FloatingWindow version - see the
        // file-level comment). This is the synchronous, lag-free
        // replacement: absolute cursor position mapped into mediaCardWindow
        // (the one item in this whole file guaranteed to never move - it's
        // screen-anchored and fills the monitor) tracked cumulatively since
        // press, so there's no local-coordinate-frame drift to accumulate
        // regardless of what dragX/dragY/cardWidth/cardHeight do mid-gesture.
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
                startWidth = mediaCardContainer.cardWidth
                startHeight = mediaCardContainer.cardHeight
                startDragX = mediaCardContainer.dragX
                startDragY = mediaCardContainer.dragY
                mediaCardContainer.anyResizeActive = true
            }

            onPositionChanged: (mouse) => {
                // hoverEnabled (needed so cursorShape updates before a
                // click) makes this fire on plain hover too, not just a
                // real drag - without this guard, a mere hover runs the
                // resize math against start* values that were never
                // initialized by an actual press (they default to 0), which
                // can shove dragX/dragY to a wildly wrong position on the
                // very first hover event. Confirmed as the cause of the
                // card "disappearing" on hover.
                if (!resizeEdge.pressed) return

                let abs = mapToItem(fullScreenDragCatch, mouse.x, mouse.y)
                let deltaX = abs.x - startAbsX
                let deltaY = abs.y - startAbsY

                let newWidth = startWidth
                let newDragX = startDragX
                if (edges & Qt.RightEdge) {
                    newWidth = mediaCardWindow.clampSize(startWidth + deltaX, mediaCardWindow.minCardSize.width, mediaCardWindow.maxCardSize.width, startWidth)
                } else if (edges & Qt.LeftEdge) {
                    newWidth = mediaCardWindow.clampSize(startWidth - deltaX, mediaCardWindow.minCardSize.width, mediaCardWindow.maxCardSize.width, startWidth)
                    newDragX = startDragX + (startWidth - newWidth)
                }

                let newHeight = startHeight
                let newDragY = startDragY
                if (edges & Qt.BottomEdge) {
                    newHeight = mediaCardWindow.clampSize(startHeight + deltaY, mediaCardWindow.minCardSize.height, mediaCardWindow.maxCardSize.height, startHeight)
                } else if (edges & Qt.TopEdge) {
                    newHeight = mediaCardWindow.clampSize(startHeight - deltaY, mediaCardWindow.minCardSize.height, mediaCardWindow.maxCardSize.height, startHeight)
                    newDragY = startDragY + (startHeight - newHeight)
                }

                mediaCardContainer.cardWidth = newWidth
                mediaCardContainer.cardHeight = newHeight
                mediaCardContainer.dragX = newDragX
                mediaCardContainer.dragY = newDragY
            }

            onReleased: {
                mediaCardContainer.anyResizeActive = false
                mediaCardContainer.commitGridSnap()
            }
            onCanceled: mediaCardContainer.anyResizeActive = false
        }

        readonly property real edgeThickness: 6
        readonly property real cornerSize: 14

        ResizeEdge {
            edges: Qt.TopEdge
            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: mediaCardContainer.cornerSize; rightMargin: mediaCardContainer.cornerSize }
            height: mediaCardContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.BottomEdge
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: mediaCardContainer.cornerSize; rightMargin: mediaCardContainer.cornerSize }
            height: mediaCardContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.LeftEdge
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: mediaCardContainer.cornerSize; bottomMargin: mediaCardContainer.cornerSize }
            width: mediaCardContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.RightEdge
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: mediaCardContainer.cornerSize; bottomMargin: mediaCardContainer.cornerSize }
            width: mediaCardContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.LeftEdge | Qt.TopEdge
            anchors { top: parent.top; left: parent.left }
            width: mediaCardContainer.cornerSize; height: mediaCardContainer.cornerSize
        }
        ResizeEdge {
            edges: Qt.RightEdge | Qt.TopEdge
            anchors { top: parent.top; right: parent.right }
            width: mediaCardContainer.cornerSize; height: mediaCardContainer.cornerSize
        }
        ResizeEdge {
            edges: Qt.LeftEdge | Qt.BottomEdge
            anchors { bottom: parent.bottom; left: parent.left }
            width: mediaCardContainer.cornerSize; height: mediaCardContainer.cornerSize
        }
        ResizeEdge {
            edges: Qt.RightEdge | Qt.BottomEdge
            anchors { bottom: parent.bottom; right: parent.right }
            width: mediaCardContainer.cornerSize; height: mediaCardContainer.cornerSize
        }

        WidgetContextMenu { id: widgetMenu }
    }

    // Visible skin, decoupled from mediaCardContainer (the drag/resize
    // anchor / hit region above) precisely so Behavior can animate it - see
    // the note by mediaCardContainer.x for why. Deliberately lower z
    // (default, 0) than mediaCardContainer (10) - see that item's comment.
    Item {
        id: ghostBody
        readonly property real gridSize: 24

        // Snap ON: only round to the grid *while actively dragging* - at
        // rest this must equal mediaCardContainer exactly, or the visible
        // skin and the invisible hit-region it's grabbed by permanently
        // drift apart. The anchor's real position gets committed to the
        // grid on release instead (see dragArea/ResizeEdge above), so once
        // you let go the two are back in exact agreement.
        // Snap OFF: the exact position, eased in via Behavior below.
        x: (Config.snapDesktopWidgets && dragArea.drag.active) ? Math.round(mediaCardContainer.x / gridSize) * gridSize : mediaCardContainer.x
        y: (Config.snapDesktopWidgets && dragArea.drag.active) ? Math.round(mediaCardContainer.y / gridSize) * gridSize : mediaCardContainer.y
        // Size never grid-snaps (only position does) and never lags behind
        // a live resize - direct mirror, no Behavior.
        width: mediaCardContainer.cardWidth
        height: mediaCardContainer.cardHeight

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

        // ClippingRectangle (not plain Rectangle) so the blurred art backdrop
        // respects the rounded corners - same reasoning as MediaCard.qml.
        ClippingRectangle {
            id: cardBg
            anchors.fill: parent
            radius: Config.cornerRadius

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            color: cardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.05)
            border.width: 1
            border.color: mediaCardWindow.isStopped
                ? Qt.rgba(255, 255, 255, 0.1)
                : Qt.rgba(mediaCardWindow.dynamicAccent.r, mediaCardWindow.dynamicAccent.g, mediaCardWindow.dynamicAccent.b, cardHover.hovered ? 0.5 : 0.24)

            HoverHandler { id: cardHover }

            // Full-bleed blurred album art backdrop, same as MediaCard.qml.
            Item {
                anchors.fill: parent
                visible: !mediaCardWindow.isStopped && mediaCardWindow.mediaArtUrl !== ""

                Image {
                    id: backdropImage
                    anchors.fill: parent
                    source: mediaCardWindow.mediaArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    opacity: 0.5

                    Behavior on source {
                        SequentialAnimation {
                            NumberAnimation { target: backdropImage; property: "opacity"; to: 0.0; duration: 120 }
                            PropertyAction { target: backdropImage; property: "source" }
                            NumberAnimation { target: backdropImage; property: "opacity"; to: 0.5; duration: 300 }
                        }
                    }
                }

                FastBlur {
                    anchors.fill: backdropImage
                    source: backdropImage
                    radius: 48
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0.03 + mediaCardWindow.dynamicAccent.r * 0.05, 0.03 + mediaCardWindow.dynamicAccent.g * 0.05, 0.03 + mediaCardWindow.dynamicAccent.b * 0.07, 0.6)
                    Behavior on color { ColorAnimation { duration: 400 } }
                }
            }

            Watermark {
                icon: Config.getIcon("cc")
                iconSize: mediaCardWindow.isStopped ? 26 : 60
                seed: 7
                activeVisible: mediaCardWindow.isStopped || mediaCardWindow.mediaArtUrl === ""
            }

            // ==========================================
            // 1. MINIMAL COMPACT BAR (WHEN STOPPED)
            // ==========================================
            RowLayout {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 24)
                visible: mediaCardWindow.isStopped
                opacity: mediaCardWindow.isStopped ? 1.0 : 0.0
                spacing: 8
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Text {
                    text: "music_off"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 16
                    color: Config.textMuted
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "No Media Playing"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    elide: Text.ElideRight
                }
            }

            // ==========================================
            // 2. ACTIVE MEDIA VIEW (WHEN PLAYING / PAUSED)
            // ==========================================
            // GridLayout (not RowLayout) so resizing the panel into a taller-
            // than-wide shape naturally reflows this from side-by-side to
            // stacked - columns: 2 sits art+metadata side by side, columns: 1
            // drops metadata onto its own row underneath the art.
            GridLayout {
                id: contentCluster
                anchors.fill: parent
                anchors.margins: mediaCardWindow.cardPad
                columns: mediaCardWindow.isVertical ? 1 : 2
                columnSpacing: 14
                rowSpacing: 8
                visible: !mediaCardWindow.isStopped
                opacity: !mediaCardWindow.isStopped ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                // --- CIRCULAR VISUALIZER & ART (smaller version of MediaCard.qml's) ---
                // Sized directly off mediaCardContainer's own resized width/
                // height (not off contentCluster/Layout.fill*) so it grows or
                // shrinks to fill its row (side-by-side layout) or column
                // (stacked layout) as the panel is resized, without any
                // circular layout->size->layout feedback.
                Item {
                    id: artContainer

                    readonly property real availW: mediaCardContainer.cardWidth - (mediaCardWindow.cardPad * 2)
                    readonly property real availH: mediaCardContainer.cardHeight - (mediaCardWindow.cardPad * 2)
                    // Side-by-side: art is square, capped to a fraction of the
                    // row's width so the metadata column keeps room to breathe.
                    // Stacked: art is square, capped to a fraction of the
                    // column's height so title/controls keep room underneath.
                    readonly property real artSize: Math.max(40, mediaCardWindow.isVertical
                        ? Math.min(availW, availH * 0.62)
                        : Math.min(availH, availW * 0.46))

                    implicitWidth: artSize
                    implicitHeight: artSize
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

                    Canvas {
                        id: visualizerCanvas
                        anchors.fill: parent
                        antialiasing: true

                        readonly property bool isVisualizerActive: mediaCardWindow.visible
                            && mediaCardWindow.mediaStatus === "Playing"

                        property real rotationAngle: 0.0

                        PropertyAnimation on rotationAngle {
                            from: 0.0
                            to: 2 * Math.PI
                            duration: 20000
                            loops: Animation.Infinite
                            running: visualizerCanvas.isVisualizerActive
                        }

                        onRotationAngleChanged: if (isVisualizerActive) requestPaint()
                        onWidthChanged: if (isVisualizerActive) requestPaint()
                        onHeightChanged: if (isVisualizerActive) requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            if (!visualizerCanvas.isVisualizerActive || !mediaCardWindow.cavaBars || mediaCardWindow.cavaBars.length === 0) return;

                            var centerX = width / 2;
                            var centerY = height / 2;
                            var innerRadius = artContainer.artSize * 0.346;
                            var barCount = mediaCardWindow.cavaBars.length;
                            var maxBarLength = artContainer.artSize * 0.115;
                            var barWidth = Math.max(1.5, artContainer.artSize * 0.0257);

                            ctx.save();
                            ctx.fillStyle = mediaCardWindow.dynamicAccent;

                            for (var i = 0; i < barCount; i++) {
                                var angle = ((i * 2 * Math.PI) / barCount) + visualizerCanvas.rotationAngle;
                                var value = mediaCardWindow.cavaBars[i] / 255.0;
                                var barLength = value * maxBarLength;

                                ctx.save();
                                ctx.translate(centerX, centerY);
                                ctx.rotate(angle);

                                var startY = innerRadius + 1;
                                var endY = startY + barLength;

                                var baseRadius = barWidth / 2;
                                var tipRadius = baseRadius + (value * 0.9);

                                ctx.beginPath();
                                ctx.moveTo(-baseRadius, startY);
                                ctx.lineTo(-tipRadius, endY);
                                ctx.arc(0, endY, tipRadius, Math.PI, 0, true);
                                ctx.lineTo(baseRadius, startY);
                                ctx.closePath();
                                ctx.fill();

                                ctx.restore();
                            }
                            ctx.restore();
                        }

                        Connections {
                            target: mediaCardWindow
                            function onCavaBarsChanged() {
                                if (visualizerCanvas.isVisualizerActive) visualizerCanvas.requestPaint();
                            }
                            function onDynamicAccentChanged() {
                                if (visualizerCanvas.isVisualizerActive) visualizerCanvas.requestPaint();
                            }
                        }
                    }

                    RectangularGlow {
                        anchors.centerIn: parent
                        width: artContainer.artSize * 0.744
                        height: width
                        glowRadius: Math.max(8, artContainer.artSize * 0.18)
                        spread: 0.25
                        color: mediaCardWindow.dynamicAccent
                        cornerRadius: width / 2
                        opacity: visualizerCanvas.isVisualizerActive ? 0.6 : 0.25

                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }

                    Item {
                        id: artDisc
                        width: artContainer.artSize * 0.692
                        height: width
                        anchors.centerIn: parent

                        PropertyAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 16000
                            loops: Animation.Infinite
                            running: visualizerCanvas.isVisualizerActive
                        }

                        Image {
                            id: artImage
                            anchors.fill: parent
                            source: mediaCardWindow.mediaArtUrl ? mediaCardWindow.mediaArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                        }

                        Rectangle {
                            id: maskTarget
                            anchors.fill: parent
                            radius: width / 2
                            color: "black"
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: artImage
                            maskSource: maskTarget
                            visible: artImage.status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "music_note"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: Math.max(14, artContainer.artSize * 0.256)
                            color: Config.textMuted
                            visible: artImage.status !== Image.Ready
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.18)
                        }
                    }
                }

                // --- METADATA, PROGRESS & CONTROLS ---
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: mediaCardWindow.mediaTitle
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro) + 1
                            font.bold: true
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }

                        Text {
                            text: mediaCardWindow.mediaArtist
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro) - 1
                            font.bold: true
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                    }

                    // Slim progress / scrub bar
                    Item {
                        id: progressTrack
                        Layout.fillWidth: true
                        implicitHeight: 12
                        visible: mediaCardWindow.trackLength > 0

                        readonly property real playedRatio: mediaCardWindow.trackLength > 0
                            ? Math.min(1.0, mediaCardWindow.trackPosition / mediaCardWindow.trackLength)
                            : 0

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 3
                            radius: 1.5
                            color: Qt.rgba(255, 255, 255, 0.15)
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * progressTrack.playedRatio
                            height: 3
                            radius: 1.5
                            color: mediaCardWindow.dynamicAccent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (mediaCardWindow.trackLength > 0) {
                                    let targetSec = (mouse.x / width) * mediaCardWindow.trackLength;
                                    mediaCardWindow.sendCommand(["playerctl", "position", targetSec.toFixed(2)]);
                                    mediaCardWindow.trackPosition = targetSec;
                                }
                            }
                        }
                    }

                    // Transport Controls
                    RowLayout {
                        spacing: 10
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 2

                        // Previous
                        Item {
                            implicitWidth: 24
                            implicitHeight: 24
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: mediaCardWindow.dynamicAccent
                                opacity: prevHover.hovered ? 0.14 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "skip_previous"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 16
                                color: prevHover.hovered ? mediaCardWindow.dynamicAccent : Config.textMain
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            TapHandler { onTapped: mediaCardWindow.sendCommand(["playerctl", "previous"]) }
                            HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                        }

                        // Play / Pause
                        Item {
                            implicitWidth: 34
                            implicitHeight: 34
                            Layout.alignment: Qt.AlignVCenter

                            RectangularGlow {
                                anchors.fill: playCircle
                                glowRadius: 12
                                spread: 0.3
                                color: mediaCardWindow.dynamicAccent
                                cornerRadius: playCircle.radius
                                opacity: mediaCardWindow.mediaStatus === "Playing" ? 0.6 : 0.35
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }

                            Rectangle {
                                id: playCircle
                                anchors.centerIn: parent
                                width: playHover.hovered ? 32 : 30
                                height: width
                                radius: width / 2
                                color: mediaCardWindow.dynamicAccent

                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: mediaCardWindow.mediaStatus === "Playing" ? "pause" : "play_arrow"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 17
                                color: Config.bgBase
                            }

                            TapHandler { onTapped: mediaCardWindow.sendCommand(["playerctl", "play-pause"]) }
                            HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
                        }

                        // Next
                        Item {
                            implicitWidth: 24
                            implicitHeight: 24
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: mediaCardWindow.dynamicAccent
                                opacity: nextHover.hovered ? 0.14 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "skip_next"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 16
                                color: nextHover.hovered ? mediaCardWindow.dynamicAccent : Config.textMain
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            TapHandler { onTapped: mediaCardWindow.sendCommand(["playerctl", "next"]) }
                            HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

            // Re-attach / close button - always on top so it never falls
            // through to the move areas beneath it.
            Item {
                id: closeButton
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 5
                implicitWidth: 18
                implicitHeight: 18
                z: 50
                opacity: closeHover.hovered ? 1.0 : 0.45
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(0, 0, 0, 0.45)
                }

                Text {
                    anchors.centerIn: parent
                    text: "close"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 12
                    color: "#ffffff"
                }

                TapHandler { onTapped: Config.showDesktopMediaCard = false }
                HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
            }

            // --- MOVE + RIGHT-CLICK WIDGET MENU ---
            // Declared after the visuals/controls above so they keep click
            // priority, but z:-1 makes that explicit too. drag.target points
            // at mediaCardContainer (a different item, not this MouseArea's
            // own parent) - exactly like ClockWidget.qml/Mascot.qml's
            // dragArea - so Qt's built-in drag handling does the actual move
            // math, with none of the manual-tracking bugs the old
            // dispatch-based version had.
            MouseArea {
                id: dragArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                z: -1

                property bool dragMoved: false

                onPressed: dragMoved = false

                drag {
                    target: mediaCardContainer
                    axis: Drag.XAndYAxis

                    onActiveChanged: {
                        if (!drag.active) mediaCardContainer.commitGridSnap()
                    }
                }

                onReleased: if (dragMoved) mediaCardContainer.commitGridSnap()

                onPositionChanged: {
                    if (drag.active) {
                        dragMoved = true
                        mediaCardContainer.dragX = mediaCardContainer.x
                        mediaCardContainer.dragY = mediaCardContainer.y
                    }
                }

                onClicked: (mouse) => {
                    if (widgetMenu.visible) {
                        widgetMenu.close()
                        return
                    }
                    if (mouse.button === Qt.RightButton) {
                        widgetMenu.openAt(mouse.x, mouse.y, mediaCardContainer, mediaCardWindow.width, mediaCardWindow.height)
                        return
                    }
                    Config.closeWidgetMenus()
                }
            }
        }
    }
}
