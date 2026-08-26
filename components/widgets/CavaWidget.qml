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

    mask: Region {
        Region { item: cavaContainer }
        Region { item: (typeof widgetMenu !== "undefined" && widgetMenu.visible) ? widgetMenu : null }
    }

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

        // 90/270 rotation swaps the visual bounding box, so the panel window
        // (and its click-through mask) needs to swap dimensions to match.
        readonly property bool sideways: (((Config.cavaRotation % 180) + 180) % 180) !== 0
        readonly property real boundsWidth: sideways ? contentHeight : contentWidth
        readonly property real boundsHeight: sideways ? contentWidth : contentHeight

        property real currentScale: cavaWindow.screen ? Config.getCavaScale(cavaWindow.screen.name) : 1.0

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

        Connections {
            target: Config
            function onIsLoadedChanged() {
                if (Config.isLoaded) cavaContainer.restorePosition()
            }
        }

        Component.onCompleted: {
            if (Config.isLoaded) restorePosition()
        }

        onXChanged: {
            if (initialized && dragArea.drag.active && cavaWindow.screen) {
                Config.saveCavaPosition(cavaWindow.screen.name, dragX, dragY)
            }
        }
        onYChanged: {
            if (initialized && dragArea.drag.active && cavaWindow.screen) {
                Config.saveCavaPosition(cavaWindow.screen.name, dragX, dragY)
            }
        }

        // BACKGROUND PANEL
        Rectangle {
            anchors.fill: parent
            visible: Config.cavaShowBackground || Config.cavaShowBorder
            color: Config.cavaShowBackground ? Config.bgPanel : "transparent"
            radius: Config.cornerRadius
            border.width: Config.cavaShowBorder ? (Config.showBorders ? 2 : 1) : 0
            border.color: Config.showBorders ? Config.accent : Qt.rgba(255, 255, 255, 0.15)
            opacity: Config.cavaShowBackground ? 0.85 : 1.0
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
            rotation: Config.cavaRotation
            visible: Config.cavaService.cavaAvailable

            Behavior on rotation {
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

            Glow {
                anchors.fill: visualContent
                source: visualContent
                radius: 16
                samples: 24
                color: Config.cavaColorMode === "gradient" ? Config.cavaGradientEnd : (Config.cavaColorMode === "solid" ? Config.cavaSolidColor : Config.accent)
                spread: 0.25
                transparentBorder: true
                visible: Config.cavaShowGlow
            }
        }

        // DRAG & SCROLL-RESIZE MOUSE AREA
        MouseArea {
            id: dragArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            drag.target: cavaContainer
            drag.axis: Drag.XAndYAxis
            cursorShape: Qt.PointingHandCursor

            onPositionChanged: {
                if (drag.active) {
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
                    newScale = Math.min(5.0, newScale + step)
                } else {
                    newScale = Math.max(0.5, newScale - step)
                }

                if (cavaWindow.screen) {
                    Config.saveCavaScale(cavaWindow.screen.name, newScale)
                }
            }
        }

        // ROTATE CONTROLS -- appears on click, sits above dragArea so its taps
        // never fall through to the drag/toggle handling underneath.
        Row {
            id: rotateControls
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 10
            spacing: 6
            z: 200

            opacity: cavaContainer.controlsVisible ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            component RotateButton: Rectangle {
                id: btn
                property string icon: ""
                signal activated()

                implicitWidth: 30; implicitHeight: 30; radius: 15
                color: btnHover.hovered ? Config.accent : Qt.rgba(0, 0, 0, 0.45)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.15)

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: btn.icon
                    color: "#ffffff"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 17
                    font.bold: true
                }

                TapHandler {
                    onTapped: {
                        btn.activated()
                        hideControlsTimer.restart()
                    }
                }
                HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
            }

            RotateButton {
                icon: "rotate_left"
                onActivated: Config.rotateCava("ccw")
            }
            RotateButton {
                icon: "rotate_right"
                onActivated: Config.rotateCava("cw")
            }
        }

        WidgetContextMenu { id: widgetMenu }
    }
}
