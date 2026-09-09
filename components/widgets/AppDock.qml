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

    Process {
        id: initPinFile
        command: ["sh", "-c", "[ -f ~/.cache/quickshell_launcher_pins.json ] || echo '{\"pins\":[]}' > ~/.cache/quickshell_launcher_pins.json"]
        running: true
        onExited: dockWindow.pinFilePath = Quickshell.env("HOME") + "/.cache/quickshell_launcher_pins.json"
    }

    FileView {
        id: pinCacheReader
        path: dockWindow.pinFilePath
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: {
            let cleanText = text().trim();
            if (!cleanText) { dockWindow.localPins = []; return; }
            try {
                let parsed = JSON.parse(cleanText);
                dockWindow.localPins = (parsed && parsed.pins) ? parsed.pins : [];
            } catch (e) {}
        }
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

        function restorePosition() {
            if (!dockWindow.screen) return

            let defaultX = Math.max(0, Math.round((dockWindow.width - width) / 2))
            let defaultY = Math.max(0, dockWindow.height - height - 120)

            let savedPos = Config.getAppDockPosition(dockWindow.screen.name, defaultX, defaultY)

            if (savedPos && typeof savedPos.x === "number" && typeof savedPos.y === "number") {
                dragX = savedPos.x
                dragY = savedPos.y
                initialized = true
            }
        }

        function commitGridSnap() {
            if (!Config.snapDesktopWidgets) return
            dragX = snapOverlay.snappedX(dragX, width)
            dragY = snapOverlay.snappedY(dragY, height)
            if (dockWindow.screen) {
                Config.saveAppDockPosition(dockWindow.screen.name, dragX, dragY)
            }
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

        // DRAG & SCROLL-RESIZE MOUSE AREA (declared before the WidgetContextMenu
        // below is irrelevant to click priority since that menu is invisible
        // until opened; what matters is that this whole item - dockContainer -
        // is declared, and therefore painted, *before* ghostBody below, so the
        // DockIcon tiles rendered inside ghostBody keep hit-test priority over
        // this full-area MouseArea without needing an explicit z trick.)
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
                    if (!drag.active) dockContainer.commitGridSnap()
                }
            }

            onReleased: if (dragMoved) dockContainer.commitGridSnap()

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
                } else {
                    Config.closeWidgetMenus()
                }
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

        // Declared before the drag/menu MouseArea inside dockContainer, and
        // painted inside ghostBody (which is declared after dockContainer),
        // so this keeps click priority over the full-area drag MouseArea.
        TapHandler {
            onTapped: dockWindow.launchApp(tile.app)
        }
        HoverHandler { id: iconHover; cursorShape: Qt.PointingHandCursor }
    }
}
