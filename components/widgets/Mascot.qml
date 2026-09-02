import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

PanelWindow {
    id: petWindow
    visible: Config.showMascot && Config.mascotPath !== ""

    Component.onCompleted: {
        let activeName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        let found = Quickshell.screens.find(s => s.name === activeName)
        petWindow.screen = found || Quickshell.screens[0]
    }

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-mascot"
    WlrLayershell.keyboardFocus: (typeof widgetMenu !== "undefined" && widgetMenu.visible) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    
    color: "transparent"
    // -1 (not 0): opts this surface out of avoiding other layer-shell
    // surfaces' exclusive zones, same as ClockWidget/CavaWidget - otherwise
    // Hyprland shrinks this full-screen surface to skip the bar's reserved
    // strip, leaving nowhere there to drag the mascot into.
    exclusiveZone: -1

    // The third region only matters while the mouse is down: a fast flick
    // can move the cursor past petContainer's own (small) input region
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
        Region { item: petContainer }
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

    function formatFileUrl(path) {
        if (!path) return ""
        if (path.startsWith("file://")) return path
        if (path.startsWith("/")) return "file://" + path
        return "file://" + Quickshell.env("HOME") + "/" + path
    }

    property string currentPhrase: ""
    property bool isTalking: false

    Item {
        id: petContainer
        
        width: 128
        height: character.implicitWidth ? (width * (character.implicitHeight / character.implicitWidth)) : width

        // Backend storage for x/y position
        property real dragX: 0
        property real dragY: 0
        property bool initialized: false

        // --- REACTIVE STATE: how "tired" the mascot looks, 0 (full battery
        // or charging) to 1 (critically low) - drives desaturation + droop
        // on `character` below. Ramps from 30% down to 0% rather than a
        // hard cutoff so it reads as draining alongside the battery.
        readonly property real batteryLow: (typeof shellRoot !== "undefined" && shellRoot.hasBattery && shellRoot.battStatus !== "Charging")
            ? Math.max(0, Math.min(1, (30 - shellRoot.battCapacity) / 30))
            : 0

        // This item is the drag target and always tracks the cursor 1:1 -
        // it's also the window's input mask, so hit-testing must never lag.
        // The visible skin lives on the sibling ghostBody item below instead,
        // which follows this one via a genuine binding (x: petContainer.x)
        // rather than a direct external write, which is what actually lets a
        // Behavior animate it: a MouseArea.drag.target's own writes land
        // straight on this item and don't reliably trigger a Behavior placed
        // on the same item.
        x: dragX
        y: dragY

        // Restores the last dragged-to position for this screen (falling
        // back to screen-center) once both the parent window has a real
        // size and Config has finished loading - whichever settles last is
        // what actually runs the restore, same two-trigger pattern
        // ClockWidget.qml uses, since either one alone can lag behind.
        Connections {
            target: petWindow
            function onWidthChanged() { petContainer.restorePosition() }
            function onHeightChanged() { petContainer.restorePosition() }
        }

        Connections {
            target: Config
            function onIsLoadedChanged() { if (Config.isLoaded) petContainer.restorePosition() }
        }

        function restorePosition() {
            if (initialized || petWindow.width <= 0 || petWindow.height <= 0 || !Config.isLoaded) return

            // petWindow's own Component.onCompleted picks a screen from
            // Hyprland.focusedMonitor before Config has loaded (needed just
            // to get *some* size for the width/height guard above) - correct
            // it to the remembered screen now that we actually know it,
            // before computing anything from petWindow's geometry. The
            // reassignment takes effect immediately (screen.name is correct
            // synchronously even though the compositor's resize is async),
            // so getMascotPosition below still finds the right saved entry.
            if (Config.mascotLastScreen && petWindow.screen && Config.mascotLastScreen !== petWindow.screen.name) {
                let savedScreen = Quickshell.screens.find(s => s.name === Config.mascotLastScreen)
                if (savedScreen) petWindow.screen = savedScreen
            }

            let defaultX = Math.max(0, (petWindow.width / 2) - (width / 2))
            let defaultY = Math.max(0, (petWindow.height / 2) - (height / 2))

            let savedPos = petWindow.screen
                ? Config.getMascotPosition(petWindow.screen.name, defaultX, defaultY)
                : { x: defaultX, y: defaultY }

            dragX = savedPos.x
            dragY = savedPos.y
            initialized = true
        }

        // Called from both drag.onActiveChanged and dragArea.onReleased below -
        // belt and suspenders against a lost/missed release event leaving
        // drag.active stuck true (seen once with a fast flick), which would
        // otherwise strand the grid overlay visible and out of sync forever.
        // Idempotent: re-running this against an already-grid-aligned position
        // is a no-op.
        function commitGridSnap() {
            if (!Config.snapDesktopWidgets) return
            dragX = Math.round(dragX / ghostBody.gridSize) * ghostBody.gridSize
            dragY = Math.round(dragY / ghostBody.gridSize) * ghostBody.gridSize
            if (petWindow.screen) {
                Config.saveMascotPosition(petWindow.screen.name, dragX, dragY)
            }
        }

        Component.onCompleted: restorePosition()

        onXChanged: {
            checkScreenBoundary()
            if (initialized && dragArea.drag.active && petWindow.screen) {
                Config.saveMascotPosition(petWindow.screen.name, dragX, dragY)
            }
        }
        onYChanged: {
            checkScreenBoundary()
            if (initialized && dragArea.drag.active && petWindow.screen) {
                Config.saveMascotPosition(petWindow.screen.name, dragX, dragY)
            }
        }

        function checkScreenBoundary() {
            if (!dragArea.drag.active) return

            let globalX = petWindow.screen.x + petContainer.x
            let globalY = petWindow.screen.y + petContainer.y

            let centerX = globalX + (petContainer.width / 2)
            let centerY = globalY + (petContainer.height / 2)

            for (let i = 0; i < Quickshell.screens.length; i++) {
                let s = Quickshell.screens[i]
                if (s === petWindow.screen) continue

                if (centerX >= s.x && centerX <= (s.x + s.width) &&
                    centerY >= s.y && centerY <= (s.y + s.height)) {
                    
                    let newLocalX = globalX - s.x
                    let newLocalY = globalY - s.y

                    petWindow.screen = s
                    petContainer.dragX = newLocalX
                    petContainer.dragY = newLocalY
                    break
                }
            }
        }

        Connections {
            target: Config
            function onNotificationArrived() {
                if (Config.showMascot) notifyBounce.restart()
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: false

            // Tracked independently of drag.active itself (set from the raw
            // onPositionChanged move signal, not the drag state signal) so
            // the onReleased backup below still knows a drag happened even
            // if drag.active's own changed signal is what got lost - and so
            // a plain click (no movement) never triggers a spurious commit.
            property bool dragMoved: false

            onPressed: dragMoved = false

            drag {
                target: petContainer
                axis: Drag.XAndYAxis

                // Commit the anchor itself to the grid on release so the
                // hit-region matches the grid-locked visual from here on,
                // instead of only ghostBody's rendered position snapping.
                onActiveChanged: {
                    if (!drag.active) petContainer.commitGridSnap()
                }
            }

            // Backup trigger for the same commit, in case a fast flick or a
            // release right at a screen edge loses the drag.active change
            // signal above - see commitGridSnap()'s note.
            onReleased: if (dragMoved) petContainer.commitGridSnap()

            // Sync drag position with properties
            onPositionChanged: {
                if (drag.active) {
                    dragMoved = true
                    petContainer.dragX = petContainer.x
                    petContainer.dragY = petContainer.y
                }
            }

            onClicked: (mouse) => {
                if (widgetMenu.visible) {
                    widgetMenu.close()
                    return
                }
                if (mouse.button === Qt.RightButton) {
                    widgetMenu.openAt(mouse.x, mouse.y, petContainer, petWindow.width, petWindow.height)
                } else {
                    Config.closeWidgetMenus()
                }
            }

            onWheel: (wheel) => {
                let step = 16
                if (wheel.angleDelta.y > 0) {
                    petContainer.width += step
                } else {
                    petContainer.width = Math.max(32, petContainer.width - step)
                }
            }
        }

        WidgetContextMenu { id: widgetMenu }
    }

    // Visible skin, decoupled from petContainer (the drag anchor / hit
    // region above) precisely so Behavior can animate it - see the note by
    // petContainer.x for why.
    Item {
        id: ghostBody
        readonly property real gridSize: 24

        // Snap ON: round to a visible grid, no easing - the skin visibly
        // jumps between grid steps as petContainer moves continuously.
        // Snap OFF: the exact position, eased in via Behavior below.
        // Only round to the grid *while actively dragging* - at rest this
        // must equal petContainer exactly, or the visible skin and the
        // invisible hit-region it's grabbed by permanently drift apart. The
        // anchor's real position gets committed to the grid on release
        // instead (see dragArea below).
        x: (Config.snapDesktopWidgets && dragArea.drag.active) ? Math.round(petContainer.x / gridSize) * gridSize : petContainer.x
        y: (Config.snapDesktopWidgets && dragArea.drag.active) ? Math.round(petContainer.y / gridSize) * gridSize : petContainer.y
        width: petContainer.width
        height: petContainer.height

        // Ambient audio throb: same bass-driven signal the bar uses
        // (shellRoot.breathAmount, already gated behind
        // Config.ambientBreatheEnabled + its intensity slider) but with a
        // much larger multiplier - the bar's own 0.04 reads as a big swing
        // on a surface hundreds of pixels wide; the same 4% on this 128px
        // icon is 1-5px, invisible next to an already-animated GIF. Also
        // independently toggleable (Config.mascotAudioThrob) since someone
        // may want the bar throb without the mascot bopping along.
        scale: (Config.mascotAudioThrob && typeof shellRoot !== "undefined")
            ? 1.0 + (shellRoot.breathAmount * 0.4)
            : 1.0

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

        AnimatedImage {
            id: character
            source: petWindow.formatFileUrl(Config.mascotPath)
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            playing: true

            // Bounce on notification (see notifyBounce below) and droop when
            // the battery's low - both layered on top of the single GIF
            // rather than swapping source frames, since AnimatedImage gives
            // no per-frame control.
            transformOrigin: Item.Bottom
            scale: 1.0
            rotation: petContainer.batteryLow * 8

            layer.enabled: petContainer.batteryLow > 0.001
            layer.effect: Desaturate { desaturation: petContainer.batteryLow }

            Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            onStatusChanged: {
                if (status === AnimatedImage.Ready) {
                    playing = true
                }
            }
        }

        SequentialAnimation {
            id: notifyBounce
            NumberAnimation { target: character; property: "scale"; to: 1.22; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: character; property: "scale"; to: 1.0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 4 }
        }

        // --- BARE TEXT OVERLAY (WITH WRAPPING & OUTLINE) ---
        Item {
            id: chatBubble
            visible: isTalking

            width: chatText.width
            height: chatText.height

            anchors {
                bottom: character.top
                bottomMargin: 6
                horizontalCenter: character.horizontalCenter
            }

            Text {
                id: chatText
                text: currentPhrase
                anchors.centerIn: parent
                font.bold: true

                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontBody)

                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.8)

                wrapMode: Text.WordWrap
                width: Math.min(implicitWidth, 240)
                horizontalAlignment: Text.AlignHCenter

                Component.onCompleted: {
                    Config.fontStyle(font)
                }
            }
        }
    }

    Timer {
        interval: 5000 
        running: Config.showMascot
        repeat: true
        onTriggered: {
            let phrases = Config.mascotPhrases || []
            if (!isTalking && phrases.length > 0 && Math.random() > 0.7) {
                currentPhrase = phrases[Math.floor(Math.random() * phrases.length)]
                isTalking = true
                hideChatTimer.start()
            }
        }
    }

    Timer {
        id: hideChatTimer
        interval: 3500 
        onTriggered: isTalking = false
    }

    Timer {
        interval: 600000 
        running: Config.showMascot && Config.fetchOnlineQuotes
        repeat: true
        onTriggered: Config.triggerQuoteFetch()
    }
}