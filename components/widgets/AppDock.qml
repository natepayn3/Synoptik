import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."

// Floating, draggable dock showing the apps pinned from LauncherOSD (same
// pin cache file, so pins made there show up here with no extra setup).
// Structurally a copy of ClockWidget.qml's drag/position/scale/context-menu
// scaffolding, with the clock face swapped for a row/column of app icons.
PanelWindow {
    id: dockWindow

    property alias positionRestored: dockContainer.initialized

    visible: positionRestored && Config.showAppDock && (screen ? Config.isAppDockEnabledForScreen(screen.name) : true)

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-desktop-appdock"
    WlrLayershell.keyboardFocus: (typeof widgetMenu !== "undefined" && widgetMenu.visible) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: -1

    mask: Region {
        Region { item: dockContainer }
        Region { item: (typeof widgetMenu !== "undefined" && widgetMenu.visible) ? widgetMenu : null }
        Region { item: dragArea.pressed ? fullScreenDragCatch : null }
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

    // --- PIN CACHE (same file LauncherOSD reads/writes) ---
    property string pinFilePath: ""
    property var localPins: []

    readonly property var pinnedApps: {
        let raw = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        let result = [];
        for (let i = 0; i < dockWindow.localPins.length; i++) {
            let pin = dockWindow.localPins[i];
            let match = raw.find(a => a.id === pin || pin === (a.id + ".desktop") || pin.endsWith("/" + a.id + ".desktop"));
            if (match) result.push(match);
        }
        return result;
    }

    // The pin file used to be bootstrapped by a `sh -c "[ -f ... ] || echo
    // ... > ..."` Process purely so the FileView below had something to open.
    // A missing file and an empty pin list are the same state, so just treat a
    // failed load as "no pins" and skip the spawn entirely.
    Component.onCompleted: dockWindow.pinFilePath = Quickshell.env("HOME") + "/.cache/quickshell_launcher_pins.json"

    FileView {
        id: pinCacheReader
        path: dockWindow.pinFilePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: dockWindow.localPins = []
        onTextChanged: {
            let cleanText = text().trim();
            if (!cleanText) { dockWindow.localPins = []; return; }
            try {
                let parsed = JSON.parse(cleanText);
                dockWindow.localPins = (parsed && parsed.pins) ? parsed.pins : [];
            } catch (e) {}
        }
    }

    // Which pinned tile, if any, sits under a point in dockContainer
    // coordinates. Used instead of a per-tile TapHandler so that a press
    // anywhere on the dock - icons included - belongs to the drag MouseArea
    // (see its comment), with the launch decided at release time from where
    // the press landed rather than from who grabbed it.
    function appAt(px, py) {
        let face = dockLoader.item
        if (!face) return null

        let p = dockContainer.mapToItem(face, px, py)
        let child = face.childAt(p.x, p.y)
        return (child && child.app) ? child.app : null
    }

    function launchApp(app) {
        if (!app) return;
        if (typeof app.execute === "function") {
            app.execute();
        } else if (app.execString) {
            let cleanExec = app.execString.replace(/%[uUfFkKcCiI]/g, "").trim();
            Quickshell.execDetached(["sh", "-c", cleanExec]);
        }
    }

    Item {
        id: dockContainer

        // Cross-axis padding (top/bottom when horizontal, left/right when
        // vertical) is kept tight so the dock's thickness matches the bar's
        // own pill height exactly: 32px icon + 2px margin each side = 36px,
        // same recipe RightModules/LeftModules/ActiveWindowCard use for the
        // bar itself. Along-axis padding just gives the capsule some
        // breathing room and doesn't affect that measurement.
        readonly property real crossPadding: 2
        readonly property real alongPadding: 10
        width: ghostBody.width
        height: ghostBody.height

        property real currentScale: dockWindow.screen ? Config.getAppDockScale(dockWindow.screen.name) : 1.0
        readonly property bool isVertical: Config.appDockOrientation === "vertical"

        property real dragX: 100
        property real dragY: 100
        property bool initialized: false

        x: dragX
        y: dragY

        // Whether this screen has a spot the user actually chose. Until it does,
        // the dock keeps re-deriving its default placement as its own size
        // settles (the first pinned icon loading changes the width, and a
        // default centred on a zero-width dock is half a dock off).
        readonly property bool hasSavedPosition: {
            let all = Config.appDockPositions
            let saved = (dockWindow.screen && all) ? all[dockWindow.screen.name] : null
            return !!saved && typeof saved.x === "number" && typeof saved.y === "number"
        }

        // Bottom-centre of the *free* desktop area - the bar claims a whole
        // screen edge without an exclusive zone, so a dock placed against the
        // raw screen edge is just hidden behind it.
        //
        // Measured off screen.width/height rather than dockWindow.width/height
        // on purpose: this window is deliberately left unmapped until
        // restorePosition() has run (visible: positionRestored above), and an
        // unmapped layer surface has no size yet. Reading the window here is
        // what parked the dock at 0,0 under the bar on first run - both terms
        // of the old default were max(0, 0 - size - offset).
        function defaultPosition() {
            let sw = dockWindow.screen ? dockWindow.screen.width : 0
            let sh = dockWindow.screen ? dockWindow.screen.height : 0
            let l = Config.desktopInset("left")
            let t = Config.desktopInset("top")
            let freeW = sw - l - Config.desktopInset("right")
            let freeH = sh - t - Config.desktopInset("bottom")

            return {
                x: l + Math.max(0, Math.round((freeW - width) / 2)),
                y: t + Math.max(0, freeH - height - 120)
            }
        }

        function restorePosition() {
            if (!dockWindow.screen) return

            let def = defaultPosition()
            let pos = Config.getAppDockPosition(dockWindow.screen.name, def.x, def.y)
            if (!pos || typeof pos.x !== "number" || typeof pos.y !== "number") pos = def

            // Even a saved position goes through the clamp: it can fall under
            // the bar later on, when the bar moves to another edge or the
            // monitor changes resolution.
            let clamped = Config.clampToDesktopArea(pos.x, pos.y, width, height,
                                                    dockWindow.screen.width, dockWindow.screen.height)
            dragX = clamped.x
            dragY = clamped.y
            initialized = true
        }

        onWidthChanged: if (initialized && !hasSavedPosition) restorePosition()
        onHeightChanged: if (initialized && !hasSavedPosition) restorePosition()

        // Called from both drag.onActiveChanged and dragArea.onReleased - belt
        // and suspenders against a missed release leaving drag.active stuck true.
        // Idempotent: re-running it on an already-snapped, already-in-bounds
        // position is a no-op.
        //
        // Grid snapping is optional, staying clear of the bar is not: a dock
        // dropped behind the bar's edge is invisible and unclickable, and the
        // only way back would be hand-editing settings.json.
        function commitPosition() {
            if (Config.snapDesktopWidgets) {
                dragX = snapOverlay.snappedX(dragX, width)
                dragY = snapOverlay.snappedY(dragY, height)
            }
            if (!dockWindow.screen) return

            let clamped = Config.clampToDesktopArea(dragX, dragY, width, height,
                                                    dockWindow.screen.width, dockWindow.screen.height)
            dragX = clamped.x
            dragY = clamped.y
            Config.saveAppDockPosition(dockWindow.screen.name, dragX, dragY)
        }

        Connections {
            target: Config
            function onIsLoadedChanged() {
                if (Config.isLoaded) dockContainer.restorePosition()
            }
        }

        Component.onCompleted: {
            if (Config.isLoaded) restorePosition()
        }

        onXChanged: {
            if (initialized && dragArea.drag.active && dockWindow.screen) {
                Config.saveAppDockPosition(dockWindow.screen.name, dragX, dragY)
            }
        }
        onYChanged: {
            if (initialized && dragArea.drag.active && dockWindow.screen) {
                Config.saveAppDockPosition(dockWindow.screen.name, dragX, dragY)
            }
        }

        // --- HORIZONTAL FACE ---
        Component {
            id: horizComp
            RowLayout {
                spacing: 6 * dockContainer.currentScale

                Repeater {
                    model: dockWindow.pinnedApps
                    delegate: DockIcon { required property var modelData; app: modelData }
                }

                Text {
                    visible: dockWindow.pinnedApps.length === 0
                    text: "Pin apps from the Launcher to fill this dock"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.italic: true
                }
            }
        }

        // --- VERTICAL FACE ---
        Component {
            id: vertComp
            ColumnLayout {
                spacing: 6 * dockContainer.currentScale

                Repeater {
                    model: dockWindow.pinnedApps
                    delegate: DockIcon { required property var modelData; app: modelData }
                }

                Text {
                    visible: dockWindow.pinnedApps.length === 0
                    Layout.preferredWidth: 90
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    text: "Pin apps from the Launcher"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.italic: true
                }
            }
        }

        // DRAG & SCROLL-RESIZE MOUSE AREA. This is the dock's only press
        // handler, deliberately: the tiles carry no TapHandler of their own, so
        // every press - over an icon or over the padding - lands here and can
        // start a drag. On a dock holding one or two icons the padding is about
        // 10px of grabbable edge, which is not a realistic drag handle.
        //
        // Launching is therefore decided on release: no drag past the threshold
        // means it was a click, and dockWindow.appAt() says which tile it was
        // on. drag.active only turns true once Qt's own startDragDistance is
        // exceeded, so a normal click still launches and a deliberate pull
        // still moves the dock.
        MouseArea {
            id: dragArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            property bool dragMoved: false

            onPressed: dragMoved = false

            drag {
                target: dockContainer
                axis: Drag.XAndYAxis

                onActiveChanged: {
                    if (!drag.active) dockContainer.commitPosition()
                }
            }

            onReleased: if (dragMoved) dockContainer.commitPosition()

            onPositionChanged: {
                if (drag.active) {
                    dragMoved = true
                    dockContainer.dragX = dockContainer.x
                    dockContainer.dragY = dockContainer.y
                }
            }

            onClicked: (mouse) => {
                if (widgetMenu.visible) {
                    widgetMenu.close()
                    return
                }
                if (mouse.button === Qt.RightButton) {
                    widgetMenu.openAt(mouse.x, mouse.y, dockContainer, dockWindow.width, dockWindow.height)
                    return
                }

                Config.closeWidgetMenus()
                if (dragMoved) return

                let app = dockWindow.appAt(mouse.x, mouse.y)
                if (app) dockWindow.launchApp(app)
            }

            onWheel: (wheel) => {
                let step = 0.1
                let newScale = dockContainer.currentScale
                if (wheel.angleDelta.y > 0) {
                    newScale = Math.min(3.0, newScale + step)
                } else {
                    newScale = Math.max(0.5, newScale - step)
                }

                if (dockWindow.screen) {
                    Config.saveAppDockScale(dockWindow.screen.name, newScale)
                }
            }
        }

        WidgetContextMenu { id: widgetMenu; hostWidgetId: "appdock" }
    }

    // Visible skin, decoupled from dockContainer so Behavior can animate it
    // (see ClockWidget.qml's ghostBody for why this split exists).
    Item {
        id: ghostBody
        readonly property real gridSize: 24

        x: (Config.snapDesktopWidgets && dragArea.drag.active) ? snapOverlay.snappedX(dockContainer.x, width) : dockContainer.x
        y: (Config.snapDesktopWidgets && dragArea.drag.active) ? snapOverlay.snappedY(dockContainer.y, height) : dockContainer.y
        width: dockLoader.implicitWidth + ((dockContainer.isVertical ? dockContainer.crossPadding : dockContainer.alongPadding) * 2)
        height: dockLoader.implicitHeight + ((dockContainer.isVertical ? dockContainer.alongPadding : dockContainer.crossPadding) * 2)

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

        // BACKGROUND PANEL
        Rectangle {
            anchors.fill: parent
            visible: Config.appDockShowBackground || Config.appDockShowBorder
            color: Config.appDockShowBackground ? Config.bgPanel : "transparent"
            radius: Config.cornerRadius
            border.width: Config.appDockShowBorder ? (Config.showBorders ? Config.borderThickness : 1) : 0
            border.color: Config.showBorders ? Config.accent : Qt.rgba(255, 255, 255, 0.15)
            opacity: Config.appDockShowBackground ? 0.85 : 1.0
        }

        Loader {
            id: dockLoader
            anchors.centerIn: parent
            sourceComponent: dockContainer.isVertical ? vertComp : horizComp
        }
    }

    // INLINE COMPONENT: ONE PINNED-APP TILE
    component DockIcon: Item {
        id: tile
        required property var app
        readonly property real tileSize: 32 * dockContainer.currentScale

        implicitWidth: tileSize
        implicitHeight: tileSize
        Layout.preferredWidth: tileSize
        Layout.preferredHeight: tileSize

        Item {
            anchors.centerIn: parent
            width: tile.tileSize
            height: tile.tileSize
            scale: iconHover.hovered ? 1.15 : 1.0

            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: iconHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Glow {
                anchors.fill: iconImg
                source: iconImg
                radius: iconHover.hovered ? 10 : 0
                samples: 16
                color: Config.accent
                spread: 0.15
                transparentBorder: true
                visible: Config.appDockShowGlow && iconHover.hovered

                Behavior on radius { NumberAnimation { duration: 150 } }
            }

            Image {
                id: iconImg
                anchors.centerIn: parent
                width: tile.tileSize * 0.72
                height: tile.tileSize * 0.72
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                source: Config.getAppIcon(tile.app.icon)
                asynchronous: true
            }
        }

        // No TapHandler here on purpose - it would take the press grab over
        // the icon and leave only the dock's thin padding draggable. The tile
        // stays input-transparent (a plain Item accepts no mouse buttons), so
        // presses fall through to dragArea, which launches on a click that
        // didn't turn into a drag. HoverHandler is grab-free and unaffected.
        HoverHandler { id: iconHover; cursorShape: Qt.PointingHandCursor }
    }
}
