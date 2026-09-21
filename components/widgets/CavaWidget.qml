import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

PanelWindow {
    id: cavaWindow
    visible: Config.showDesktopCava && (screen ? Config.isCavaEnabledForScreen(screen.name) : true)

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-desktop-cava"
    WlrLayershell.keyboardFocus: (typeof widgetMenu !== "undefined" && widgetMenu.visible) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    // -1 opts this surface out of other surfaces' exclusive zones (same flag
    // WallpaperSurface uses), so it isn't inset by the bar and can be dragged
    // anywhere on screen, including behind/into the bar's reserved strip.
    exclusiveZone: -1

    // The third region only matters while the mouse is down: a fast flick
    // can move the cursor past cavaContainer's own (small) input region
    // before the compositor gets the next mask update, and layer-shell
    // surfaces don't get a toplevel's "grab persists outside my bounds"
    // behavior - once the pointer lands outside the registered region,
    // Hyprland stops routing events to this surface altogether, which is
    // what "it just lets go" actually was. Keyed off dragArea.pressed rather
    // than drag.active specifically: pressed fires on the down-click itself,
    // before any movement/threshold is needed, so the region is already
    // full-window before a flick starting immediately on press can outrun
    // it - active only flips true after that threshold, which is too late.
    mask: Region {
        Region { item: cavaContainer }
        Region { item: (typeof widgetMenu !== "undefined" && widgetMenu.visible) ? widgetMenu : null }
        // The rotate handle floats clear of cavaContainer's top edge, outside
        // its bounds, so it needs a region of its own - inheriting the
        // container's wouldn't cover it and it simply wouldn't be clickable.
        Region { item: rotateHandle.visible ? rotateHandle : null }
        // Gated on the resize/rotate gestures as well as dragArea.pressed: the
        // resize edges are only a few px thick and the rotate handle is a 28px
        // disc, so both outrun a lagging mask even more easily than a fast
        // drag flick does - same failure, same fix. See Mirror.qml's note.
        Region {
            item: (dragArea.pressed || cavaContainer.anyResizeActive || cavaContainer.rotating)
                ? fullScreenDragCatch : null
        }
    }

    Item { id: fullScreenDragCatch; anchors.fill: parent }

    SnapGridOverlay {
        id: snapOverlay
        anchors.fill: parent
        gridSize: ghostBody.gridSize
        active: dragArea.drag.active && Config.snapDesktopWidgets
        targetX: ghostBody.x
        targetY: ghostBody.y
        targetWidth: ghostBody.width
        targetHeight: ghostBody.height
    }

    readonly property real minScale: 0.5
    readonly property real maxScale: 5.0
    // Rotation detents. The handle pulls onto a multiple of rotationSnapStep
    // whenever the free angle comes within rotationSnapTolerance of one, which
    // is what makes upright reachable at all: by hand the widget lands a
    // degree or two off every single time.
    //
    // This is magnetic rather than modifier-held on purpose. The obvious
    // design - hold Shift to snap - cannot work on this surface: it runs at
    // WlrKeyboardFocus.None (see keyboardFocus above), and on Wayland a client
    // is only told about modifier state through wl_keyboard, which it only
    // receives after a keyboard enter on that surface. With no keyboard focus
    // there is no modifier state to read, so MouseEvent.modifiers is
    // permanently 0 here and a Shift test silently never fires.
    readonly property real rotationSnapStep: 15
    readonly property real rotationSnapTolerance: 5

    // --- LIVE SPECTRUM DATA ---
    readonly property var levels: Config.cavaService.bars
    readonly property int barsCount: levels.length > 0 ? levels.length : Config.cavaBars

    function levelAt(index) {
        return (index >= 0 && index < cavaWindow.levels.length) ? cavaWindow.levels[index] : 0
    }

    function lerpColor(c1, c2, t) {
        let a = Qt.color(c1)
        let b = Qt.color(c2)
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1.0)
    }

    function barColor(index, count, value) {
        switch (Config.cavaColorMode) {
            case "gradient":
                return cavaWindow.lerpColor(Config.cavaGradientStart, Config.cavaGradientEnd, count > 1 ? index / (count - 1) : 0)
            case "rainbow": {
                let hue = ((index / Math.max(1, count)) + rainbowPhase.phase) % 1.0
                return Qt.hsva(hue, 0.75, 1.0, 1.0)
            }
            case "solid":
                return Qt.color(Config.cavaSolidColor)
            default:
                return Config.accent
        }
    }

    Item {
        id: rainbowPhase
        property real phase: 0
        NumberAnimation on phase {
            running: Config.cavaColorMode === "rainbow" && Config.cavaRainbowSpeed > 0 && Config.showDesktopCava
            loops: Animation.Infinite
            from: 0
            to: 1
            duration: Config.cavaRainbowSpeed > 0 ? Math.max(800, 360000 / Math.max(0.5, Config.cavaRainbowSpeed)) : 999999
        }
    }

    Item {
        id: cavaContainer

        readonly property real basePadding: 16
        readonly property real barCell: Config.cavaBarWidth + Config.cavaBarGap
        readonly property real linearWidth: Math.max(Config.cavaBarWidth, cavaWindow.barsCount * barCell - Config.cavaBarGap)
        readonly property real linearHeight: Config.cavaMaxHeight
        readonly property real radialSide: (Config.cavaRingRadius + Config.cavaMaxHeight) * 2

        readonly property real contentWidth: Config.cavaStyle === "radial" ? radialSide : linearWidth
        readonly property real contentHeight: Config.cavaStyle === "radial" ? radialSide : linearHeight

        property real currentScale: cavaWindow.screen ? Config.getCavaScale(cavaWindow.screen.name) : 1.0
        property real currentRotation: cavaWindow.screen ? Config.getCavaRotation(cavaWindow.screen.name) : 0

        // Rotation is a free angle now, not 90-degree steps, so the panel
        // window (and the click-through mask cut from it) can't just swap
        // width and height at the quarter turns - it needs the real
        // axis-aligned bounding box of the rotated content, which grows to a
        // maximum on the diagonals and collapses back to contentWidth /
        // contentHeight at every multiple of 90.
        readonly property real rotationRad: currentRotation * Math.PI / 180
        readonly property real absCos: Math.abs(Math.cos(rotationRad))
        readonly property real absSin: Math.abs(Math.sin(rotationRad))
        readonly property real boundsWidth: contentWidth * absCos + contentHeight * absSin
        readonly property real boundsHeight: contentWidth * absSin + contentHeight * absCos

        // True while a ResizeEdge or the rotate handle is mid-drag. Both move
        // dragX/dragY as a side effect (a resize keeps the opposite corner
        // pinned, a rotation keeps the centre pinned while the bounding box
        // grows underneath it), so those position writes have to persist too -
        // not just the ones dragArea's own move gesture makes.
        property bool anyResizeActive: false
        property bool rotating: false

        width: (boundsWidth * currentScale) + (basePadding * 2)
        height: (boundsHeight * currentScale) + (basePadding * 2)

        // Click-to-reveal rotate controls (not a Settings toggle -- lives on the widget itself)
        property bool controlsVisible: false

        Timer {
            id: hideControlsTimer
            interval: 3500
            onTriggered: cavaContainer.controlsVisible = false
        }

        property real dragX: 140
        property real dragY: 140
        property bool initialized: false

        // This item is the drag target and always tracks the cursor 1:1 -
        // it's also the window's input mask, so hit-testing must never lag.
        // The visible skin lives on the sibling ghostBody item below instead,
        // which follows this one via a genuine binding (x: cavaContainer.x)
        // rather than a direct external write, which is what actually lets a
        // Behavior animate it: a MouseArea.drag.target's own writes land
        // straight on this item and don't reliably trigger a Behavior placed
        // on the same item.
        x: dragX
        y: dragY

        function restorePosition() {
            if (!cavaWindow.screen) return

            let defaultX = 80
            let defaultY = Math.max(0, cavaWindow.height - height - 80)

            let savedPos = Config.getCavaPosition(cavaWindow.screen.name, defaultX, defaultY)

            if (savedPos && typeof savedPos.x === "number" && typeof savedPos.y === "number") {
                dragX = savedPos.x
                dragY = savedPos.y
                initialized = true
            }
        }

        // Called from both drag.onActiveChanged and dragArea.onReleased below -
        // belt and suspenders against a lost/missed release event leaving
        // drag.active stuck true (seen once with a fast flick), which would
        // otherwise strand the grid overlay visible and out of sync forever.
        // Idempotent: re-running this against an already-grid-aligned position
        // is a no-op.
        function commitGridSnap() {
            if (!Config.snapDesktopWidgets) return
            dragX = snapOverlay.snappedX(dragX, width)
            dragY = snapOverlay.snappedY(dragY, height)
            if (cavaWindow.screen) {
                Config.saveCavaPosition(cavaWindow.screen.name, dragX, dragY)
            }
        }

        Connections {
            target: Config
            function onIsLoadedChanged() {
                if (Config.isLoaded) cavaContainer.restorePosition()
            }
        }

        Component.onCompleted: {
            if (Config.isLoaded) restorePosition()
        }

        // A left/top-edge resize and a rotation both reposition the anchor to
        // keep the opposite corner (resp. the centre) still, so those writes
        // need persisting exactly like a drag's - without anyResizeActive /
        // rotating here the widget silently walks back to its pre-gesture
        // position on the next shell restart.
        readonly property bool gesturing: dragArea.drag.active || anyResizeActive || rotating

        onXChanged: {
            if (initialized && gesturing && cavaWindow.screen) {
                Config.saveCavaPosition(cavaWindow.screen.name, dragX, dragY)
            }
        }
        onYChanged: {
            if (initialized && gesturing && cavaWindow.screen) {
                Config.saveCavaPosition(cavaWindow.screen.name, dragX, dragY)
            }
        }

        // commitGridSnap() bails out entirely when snapping is off, so it
        // can't be the only thing that persists a gesture's final position -
        // the resize/rotate handlers call this on release instead.
        function commitPosition() {
            if (!cavaWindow.screen) return
            Config.saveCavaPosition(cavaWindow.screen.name, dragX, dragY)
        }

        // Rotating grows or shrinks the axis-aligned bounding box (see
        // boundsWidth), and width/height hang off dragX/dragY as a top-left
        // anchor - so left alone the widget would crawl down-right as it
        // turns. Re-anchor off the centre instead: capture it, let the new
        // angle resize the box, then put the centre back where it was.
        function applyRotation(degrees) {
            if (!cavaWindow.screen) return
            let cx = dragX + width / 2
            let cy = dragY + height / 2
            Config.saveCavaRotation(cavaWindow.screen.name, degrees)
            dragX = cx - width / 2
            dragY = cy - height / 2
        }


        // DRAG & SCROLL-RESIZE MOUSE AREA
        MouseArea {
            id: dragArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            // Tracked independently of drag.active itself (set from the raw
            // onPositionChanged move signal, not the drag state signal) so
            // the onReleased backup below still knows a drag happened even
            // if drag.active's own changed signal is what got lost - and so
            // a plain click (no movement) never triggers a spurious commit.
            property bool dragMoved: false

            onPressed: dragMoved = false

            drag {
                target: cavaContainer
                axis: Drag.XAndYAxis

                // Commit the anchor itself to the grid on release so the
                // hit-region matches the grid-locked visual from here on,
                // instead of only ghostBody's rendered position snapping.
                onActiveChanged: {
                    if (!drag.active) cavaContainer.commitGridSnap()
                }
            }

            // Backup trigger for the same commit, in case a fast flick or a
            // release right at a screen edge loses the drag.active change
            // signal above - see commitGridSnap()'s note.
            onReleased: if (dragMoved) cavaContainer.commitGridSnap()

            onPositionChanged: {
                if (drag.active) {
                    dragMoved = true
                    cavaContainer.dragX = cavaContainer.x
                    cavaContainer.dragY = cavaContainer.y
                }
            }

            // MouseArea only emits "clicked" for a press/release that never crossed the
            // drag threshold, so this never fires while the user is actually repositioning.
            onClicked: (mouse) => {
                if (widgetMenu.visible) {
                    widgetMenu.close()
                    return
                }
                if (mouse.button === Qt.RightButton) {
                    widgetMenu.openAt(mouse.x, mouse.y, cavaContainer, cavaWindow.width, cavaWindow.height)
                    return
                }
                Config.closeWidgetMenus()
                cavaContainer.controlsVisible = !cavaContainer.controlsVisible
                if (cavaContainer.controlsVisible) hideControlsTimer.restart()
                else hideControlsTimer.stop()
            }

            onWheel: (wheel) => {
                let step = 0.1
                let newScale = cavaContainer.currentScale
                if (wheel.angleDelta.y > 0) {
                    newScale = Math.min(cavaWindow.maxScale, newScale + step)
                } else {
                    newScale = Math.max(cavaWindow.minScale, newScale - step)
                }

                if (cavaWindow.screen) {
                    Config.saveCavaScale(cavaWindow.screen.name, newScale)
                }
            }
        }

        // --- FREE-ANGLE ROTATION ---
        // Replaces the old pair of 90-degree step buttons: drag the handle
        // and the widget follows the cursor to any angle. Parented to
        // cavaContainer (the hit region) rather than ghostBody (the eased
        // visual skin) so the grab point never lags the pointer, and given
        // its own mask Region above since it sits outside the container.
        Item {
            id: rotateHandle
            readonly property real stemLength: 14

            width: 28
            height: 28
            z: 210
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: stemLength

            opacity: cavaContainer.controlsVisible ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            // Stem down to the widget's top edge, so the handle reads as
            // attached to it rather than floating loose on the wallpaper.
            Rectangle {
                width: 2
                height: rotateHandle.stemLength
                anchors.top: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(255, 255, 255, 0.25)
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: (rotateArea.pressed && rotateArea.snapped) ? "#ffffff"
                     : (rotateArea.pressed || rotateHover.hovered) ? Config.accent
                     : Qt.rgba(0, 0, 0, 0.45)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.15)
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "rotate_right"
                    color: "#ffffff"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 16
                    font.bold: true
                }
            }

            HoverHandler { id: rotateHover; cursorShape: Qt.PointingHandCursor }

            MouseArea {
                id: rotateArea
                anchors.fill: parent

                // Absolute angle of the cursor around the widget's centre,
                // measured in fullScreenDragCatch's coordinates - that item
                // is screen-anchored and never moves, unlike this handle,
                // which is orbiting the centre as the drag proceeds.
                function angleAt(mouse) {
                    let abs = mapToItem(fullScreenDragCatch, mouse.x, mouse.y)
                    let cx = cavaContainer.x + cavaContainer.width / 2
                    let cy = cavaContainer.y + cavaContainer.height / 2
                    return Math.atan2(abs.y - cy, abs.x - cx) * 180 / Math.PI
                }

                // Tracked as a running delta from the previous move rather
                // than as an absolute angle, so the stored rotation stays
                // unwrapped: dragging twice round the circle really is 720
                // degrees, and nothing ever jumps a near-full turn when the
                // cursor crosses atan2's +/-180 seam.
                property real lastAngle: 0

                // The un-snapped angle the cursor is actually pointing at,
                // accumulated separately from what gets stored. Holding Shift
                // quantises the *stored* value, but the free angle has to keep
                // tracking the pointer underneath it - feed a snapped value
                // back in as the next frame's starting point and the detents
                // turn sticky, because every sub-7.5-degree move then rounds
                // straight back to the detent it just left and the widget
                // refuses to advance until the cursor jumps half a step.
                property real rawRotation: 0

                // Drives the handle's colour so the pull onto a detent is
                // visible - otherwise a magnetic snap just reads as the
                // widget mysteriously refusing to track the cursor.
                property bool snapped: false

                onPressed: (mouse) => {
                    lastAngle = angleAt(mouse)
                    rawRotation = cavaContainer.currentRotation
                    cavaContainer.rotating = true
                    hideControlsTimer.stop()
                }

                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    let a = angleAt(mouse)
                    let delta = a - lastAngle
                    // Shortest way round: a raw difference of +350 is really
                    // -10 the other way, and taking it at face value would
                    // spin the widget almost a full turn per seam crossing.
                    while (delta > 180) delta -= 360
                    while (delta < -180) delta += 360
                    lastAngle = a
                    rawRotation += delta

                    // Nearest detent, and how far the free angle is from it.
                    // Inside the tolerance the stored angle pulls onto the
                    // detent; outside it the angle stays exactly where the
                    // cursor put it, so arbitrary angles are still reachable -
                    // just not the last few degrees either side of a detent.
                    let step = cavaWindow.rotationSnapStep
                    let detent = Math.round(rawRotation / step) * step
                    snapped = Math.abs(rawRotation - detent) <= cavaWindow.rotationSnapTolerance
                    cavaContainer.applyRotation(snapped ? detent : rawRotation)
                }

                onReleased: {
                    cavaContainer.rotating = false
                    snapped = false
                    cavaContainer.commitPosition()
                    hideControlsTimer.restart()
                }
                onCanceled: {
                    cavaContainer.rotating = false
                    snapped = false
                    hideControlsTimer.restart()
                }
            }
        }

        // --- MANUAL RESIZE ---
        // No native resize protocol exists for a layer-shell surface, so this
        // is the same synchronous cursor-tracking approach Mirror.qml uses:
        // absolute position mapped into the screen-anchored fullScreenDragCatch,
        // accumulated since press. Unlike Mirror's, this one is aspect-locked -
        // it drives the single currentScale the scroll wheel already writes,
        // so the two gestures stay interchangeable rather than fighting over
        // two different notions of size.
        component ResizeEdge: MouseArea {
            id: resizeEdge
            required property int edges

            z: 100
            hoverEnabled: true
            cursorShape: {
                if (edges === (Qt.LeftEdge | Qt.TopEdge) || edges === (Qt.RightEdge | Qt.BottomEdge)) return Qt.SizeFDiagCursor
                if (edges === (Qt.RightEdge | Qt.TopEdge) || edges === (Qt.LeftEdge | Qt.BottomEdge)) return Qt.SizeBDiagCursor
                if (edges === Qt.LeftEdge || edges === Qt.RightEdge) return Qt.SizeHorCursor
                return Qt.SizeVerCursor
            }

            property real startAbsX: 0
            property real startAbsY: 0
            property real startScale: 1
            property real startWidth: 0
            property real startHeight: 0
            property real startDragX: 0
            property real startDragY: 0

            onPressed: (mouse) => {
                let abs = mapToItem(fullScreenDragCatch, mouse.x, mouse.y)
                startAbsX = abs.x
                startAbsY = abs.y
                startScale = cavaContainer.currentScale
                startWidth = cavaContainer.width
                startHeight = cavaContainer.height
                startDragX = cavaContainer.dragX
                startDragY = cavaContainer.dragY
                cavaContainer.anyResizeActive = true
                hideControlsTimer.stop()
            }

            onPositionChanged: (mouse) => {
                // hoverEnabled (needed so cursorShape updates before a click)
                // makes this fire on plain hover too - without this guard the
                // resize math runs against uninitialised start* values on the
                // very first hover event. Same note as Mirror.qml's.
                if (!resizeEdge.pressed) return
                if (!cavaWindow.screen) return

                let abs = mapToItem(fullScreenDragCatch, mouse.x, mouse.y)
                let deltaX = abs.x - startAbsX
                let deltaY = abs.y - startAbsY

                // Outward-positive on whichever side is being pulled, so left
                // and right (top and bottom) grow the widget symmetrically.
                let dw = (edges & Qt.RightEdge) ? deltaX : ((edges & Qt.LeftEdge) ? -deltaX : 0)
                let dh = (edges & Qt.BottomEdge) ? deltaY : ((edges & Qt.TopEdge) ? -deltaY : 0)

                // Content extents at press, padding excluded - the padding
                // ring is a fixed 16px that doesn't scale, so folding it into
                // the ratio would make the widget grow slightly slower than
                // the cursor at small scales and never quite catch up.
                let baseW = startScale * cavaContainer.boundsWidth
                let baseH = startScale * cavaContainer.boundsHeight
                if (baseW <= 0 || baseH <= 0) return

                let horizontal = (edges & (Qt.LeftEdge | Qt.RightEdge)) !== 0
                let vertical = (edges & (Qt.TopEdge | Qt.BottomEdge)) !== 0

                let ratio
                if (horizontal && vertical) {
                    // Corner: weight the two axes by their own lengths rather
                    // than picking whichever moved more in raw pixels. That
                    // tracks the diagonal smoothly; a max()/winner-takes-all
                    // rule visibly jerks at the crossover where the dominant
                    // axis changes mid-drag.
                    ratio = ((baseW + dw) + (baseH + dh)) / (baseW + baseH)
                } else if (horizontal) {
                    ratio = (baseW + dw) / baseW
                } else {
                    ratio = (baseH + dh) / baseH
                }

                let newScale = Math.max(cavaWindow.minScale, Math.min(cavaWindow.maxScale, startScale * ratio))
                Config.saveCavaScale(cavaWindow.screen.name, newScale)

                // Re-anchor so the grabbed edge is the one that moves. On an
                // axis with no grabbed edge the widget still changes size
                // (the scale is uniform), so split the difference there and
                // keep that axis centred instead of letting it drift.
                let newWidth = newScale * cavaContainer.boundsWidth + cavaContainer.basePadding * 2
                let newHeight = newScale * cavaContainer.boundsHeight + cavaContainer.basePadding * 2

                if (edges & Qt.RightEdge) cavaContainer.dragX = startDragX
                else if (edges & Qt.LeftEdge) cavaContainer.dragX = startDragX + (startWidth - newWidth)
                else cavaContainer.dragX = startDragX + (startWidth - newWidth) / 2

                if (edges & Qt.BottomEdge) cavaContainer.dragY = startDragY
                else if (edges & Qt.TopEdge) cavaContainer.dragY = startDragY + (startHeight - newHeight)
                else cavaContainer.dragY = startDragY + (startHeight - newHeight) / 2
            }

            onReleased: {
                cavaContainer.anyResizeActive = false
                cavaContainer.commitPosition()
                cavaContainer.commitGridSnap()
                hideControlsTimer.restart()
            }
            onCanceled: {
                cavaContainer.anyResizeActive = false
                hideControlsTimer.restart()
            }
        }

        readonly property real edgeThickness: 6
        // Scales with the user's configured corner rounding rather than a
        // fixed guess - same as Mirror.qml / MediaCardWidget.qml.
        readonly property real cornerSize: Math.max(18, Config.cornerRadius + 8)

        ResizeEdge {
            edges: Qt.TopEdge
            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: cavaContainer.cornerSize; rightMargin: cavaContainer.cornerSize }
            height: cavaContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.BottomEdge
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: cavaContainer.cornerSize; rightMargin: cavaContainer.cornerSize }
            height: cavaContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.LeftEdge
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: cavaContainer.cornerSize; bottomMargin: cavaContainer.cornerSize }
            width: cavaContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.RightEdge
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: cavaContainer.cornerSize; bottomMargin: cavaContainer.cornerSize }
            width: cavaContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.LeftEdge | Qt.TopEdge
            anchors { top: parent.top; left: parent.left }
            width: cavaContainer.cornerSize; height: cavaContainer.cornerSize
        }
        ResizeEdge {
            edges: Qt.RightEdge | Qt.TopEdge
            anchors { top: parent.top; right: parent.right }
            width: cavaContainer.cornerSize; height: cavaContainer.cornerSize
        }
        ResizeEdge {
            edges: Qt.LeftEdge | Qt.BottomEdge
            anchors { bottom: parent.bottom; left: parent.left }
            width: cavaContainer.cornerSize; height: cavaContainer.cornerSize
        }
        ResizeEdge {
            edges: Qt.RightEdge | Qt.BottomEdge
            anchors { bottom: parent.bottom; right: parent.right }
            width: cavaContainer.cornerSize; height: cavaContainer.cornerSize
        }

        WidgetContextMenu { id: widgetMenu; hostWidgetId: "cava" }
    }

    // Visible skin, decoupled from cavaContainer (the drag anchor / hit
    // region above) precisely so Behavior can animate it - see the note by
    // cavaContainer.x for why.
    Item {
        id: ghostBody
        readonly property real gridSize: 24

        // Snap ON: round to a visible grid, no easing - the skin visibly
        // jumps between grid steps as cavaContainer moves continuously.
        // Snap OFF: the exact position, eased in via Behavior below.
        // Only round to the grid *while actively dragging* - at rest this
        // must equal cavaContainer exactly, or the visible skin and the
        // invisible hit-region it's grabbed by permanently drift apart. The
        // anchor's real position gets committed to the grid on release
        // instead (see dragArea below).
        x: (Config.snapDesktopWidgets && dragArea.drag.active) ? snapOverlay.snappedX(cavaContainer.x, width) : cavaContainer.x
        y: (Config.snapDesktopWidgets && dragArea.drag.active) ? snapOverlay.snappedY(cavaContainer.y, height) : cavaContainer.y
        width: cavaContainer.width
        height: cavaContainer.height

        // Easing is for a settled move; during a live resize or rotation the
        // skin has to mirror the hit region exactly, or the outline visibly
        // trails the cursor and the grab point stops being where it looks.
        Behavior on x {
            enabled: !Config.snapDesktopWidgets && !cavaContainer.anyResizeActive && !cavaContainer.rotating
            NumberAnimation {
                duration: Config.motionService.durationFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Config.motionService.expressiveFastSpatialPoints
            }
        }
        Behavior on y {
            enabled: !Config.snapDesktopWidgets && !cavaContainer.anyResizeActive && !cavaContainer.rotating
            NumberAnimation {
                duration: Config.motionService.durationFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Config.motionService.expressiveFastSpatialPoints
            }
        }

        // BACKGROUND PANEL
        Rectangle {
            anchors.fill: parent
            visible: Config.cavaShowBackground || Config.cavaShowBorder
            color: Config.cavaShowBackground ? Config.bgPanel : "transparent"
            radius: Config.cornerRadius
            border.width: Config.cavaShowBorder ? (Config.showBorders ? Config.borderThickness : 1) : 0
            border.color: Config.showBorders ? Config.accent : Qt.rgba(255, 255, 255, 0.15)
            opacity: Config.cavaShowBackground ? 0.85 : 1.0
        }

        // RESIZE AFFORDANCE -- purely decorative; the grabbable edges are the
        // ResizeEdge items over on cavaContainer. Drawn only while the
        // controls are revealed so the widget stays clean at rest.
        Item {
            anchors.fill: parent
            z: 50
            opacity: cavaContainer.controlsVisible ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: Config.cornerRadius
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.35)
            }

            Repeater {
                model: [[0, 0], [1, 0], [0, 1], [1, 1]]
                delegate: Rectangle {
                    required property var modelData
                    width: 7; height: 7; radius: 3.5
                    color: Config.accent
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.6)
                    x: modelData[0] * (parent.width - width)
                    y: modelData[1] * (parent.height - height)
                }
            }
        }

        // "NO CAVA" FALLBACK
        Text {
            anchors.centerIn: parent
            visible: !Config.cavaService.cavaAvailable
            text: "cava not found — install the 'cava' package"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            wrapMode: Text.WordWrap
            width: parent.width - 24
            horizontalAlignment: Text.AlignHCenter
        }

        Item {
            id: visualScaler
            anchors.centerIn: parent
            width: cavaContainer.contentWidth
            height: cavaContainer.contentHeight
            scale: cavaContainer.currentScale
            rotation: cavaContainer.currentRotation
            visible: Config.cavaService.cavaAvailable

            // Only eases a rotation that arrives all at once (a restore on
            // startup, or another screen's value being applied); a live drag
            // has to track the cursor exactly, and easing there would leave
            // the bars lagging behind the handle the whole way round.
            Behavior on rotation {
                enabled: !cavaContainer.rotating
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            Item {
                id: visualContent
                anchors.fill: parent

            // --- BARS / MIRRORED LAYOUT ---
            Row {
                id: linearRow
                visible: Config.cavaStyle === "bars" || Config.cavaStyle === "mirrored"
                anchors.bottom: Config.cavaStyle === "bars" ? parent.bottom : undefined
                anchors.verticalCenter: Config.cavaStyle === "mirrored" ? parent.verticalCenter : undefined
                anchors.horizontalCenter: parent.horizontalCenter
                height: parent.height
                spacing: Config.cavaBarGap

                Repeater {
                    model: cavaWindow.barsCount
                    delegate: Item {
                        required property int index
                        width: Config.cavaBarWidth
                        height: linearRow.height

                        Rectangle {
                            width: Config.cavaBarWidth
                            radius: Config.cavaBarRadius
                            color: cavaWindow.barColor(index, cavaWindow.barsCount, cavaWindow.levelAt(index))
                            height: Math.max(Config.cavaBarRadius * 2, cavaWindow.levelAt(index) * Config.cavaMaxHeight)
                            anchors.bottom: Config.cavaStyle === "bars" ? parent.bottom : undefined
                            anchors.verticalCenter: Config.cavaStyle === "mirrored" ? parent.verticalCenter : undefined

                            Behavior on height {
                                NumberAnimation { duration: Math.max(35, 900 / Math.max(15, Config.cavaFramerate)); easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }
            }

            // --- WAVE LAYOUT ---
            Canvas {
                id: waveCanvas
                visible: Config.cavaStyle === "wave"
                anchors.fill: parent

                property real animatedProgress: 0

                Connections {
                    target: cavaWindow
                    function onLevelsChanged() { waveCanvas.requestPaint() }
                }
                Connections {
                    target: Config
                    function onCavaColorModeChanged() { waveCanvas.requestPaint() }
                    function onAccentChanged() { waveCanvas.requestPaint() }
                }

                onPaint: {
                    let ctx = getContext("2d")
                    ctx.reset()
                    if (!visible || cavaWindow.barsCount < 2) return

                    let cell = width / cavaWindow.barsCount
                    let pts = []
                    for (let i = 0; i < cavaWindow.barsCount; i++) {
                        pts.push({ x: (i + 0.5) * cell, y: height - (cavaWindow.levelAt(i) * height) })
                    }

                    ctx.beginPath()
                    ctx.moveTo(0, height)
                    ctx.lineTo(pts[0].x, pts[0].y)
                    for (let j = 0; j < pts.length - 1; j++) {
                        let midX = (pts[j].x + pts[j + 1].x) / 2
                        let midY = (pts[j].y + pts[j + 1].y) / 2
                        ctx.quadraticCurveTo(pts[j].x, pts[j].y, midX, midY)
                    }
                    ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y)
                    ctx.lineTo(width, height)
                    ctx.closePath()

                    let fillColor = Qt.color(cavaWindow.barColor(Math.floor(cavaWindow.barsCount / 2), cavaWindow.barsCount, 1.0))
                    let grad = ctx.createLinearGradient(0, 0, 0, height)
                    grad.addColorStop(0, Qt.rgba(fillColor.r, fillColor.g, fillColor.b, 0.9))
                    grad.addColorStop(1, Qt.rgba(fillColor.r, fillColor.g, fillColor.b, 0.15))
                    ctx.fillStyle = grad
                    ctx.fill()

                    ctx.lineWidth = Math.max(1.5, Config.cavaBarWidth * 0.4)
                    ctx.strokeStyle = fillColor
                    ctx.stroke()
                }
            }

            // --- RADIAL LAYOUT ---
            Item {
                id: radialLayout
                visible: Config.cavaStyle === "radial"
                anchors.fill: parent

                Repeater {
                    model: cavaWindow.barsCount
                    delegate: Item {
                        required property int index
                        anchors.centerIn: parent
                        width: Config.cavaRingRadius * 2
                        height: Config.cavaRingRadius * 2
                        rotation: (index / Math.max(1, cavaWindow.barsCount)) * 360

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 0
                            width: Config.cavaBarWidth
                            radius: Config.cavaBarRadius
                            color: cavaWindow.barColor(index, cavaWindow.barsCount, cavaWindow.levelAt(index))
                            height: Math.max(Config.cavaBarRadius * 2, cavaWindow.levelAt(index) * (Config.cavaMaxHeight * 0.6))

                            Behavior on height {
                                NumberAnimation { duration: Math.max(35, 900 / Math.max(15, Config.cavaFramerate)); easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }
            }

            } // visualContent

            // Behind the content, not over it. Declared after visualContent,
            // so without the negative z this paints its blurred copy straight
            // on top of the crisp bars - which is why the glow read as the
            // whole widget being out of focus rather than as a halo. The
            // sharp edges have to sit on top of their own glow.
            //
            // Kept deliberately tight: a wide, high-spread glow on the wave
            // style (a filled shape, not thin bars) has nowhere to fall off
            // to and just washes the whole panel out.
            Glow {
                z: -1
                anchors.fill: visualContent
                source: visualContent
                radius: 10
                // Qt wants samples ~= 2 * radius + 1 for a smooth falloff;
                // below that the blur visibly bands into rings.
                samples: 21
                color: Config.cavaColorMode === "gradient" ? Config.cavaGradientEnd : (Config.cavaColorMode === "solid" ? Config.cavaSolidColor : Config.accent)
                spread: 0.12
                opacity: 0.75
                transparentBorder: true
                visible: Config.cavaShowGlow
            }
        }
    }
}
