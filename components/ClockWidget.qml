import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: clockWindow
    visible: Config.showDesktopClock

    Component.onCompleted: {
        let activeName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        let found = Quickshell.screens.find(s => s.name === activeName)
        clockWindow.screen = found || Quickshell.screens[0]
    }

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-desktop-clock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: 0

    mask: Region { item: clockContainer }

    Item {
        id: clockContainer
        
        // Tight padding around content regardless of scale
        readonly property real basePadding: 16
        width: clockLoader.implicitWidth + (basePadding * 2)
        height: clockLoader.implicitHeight + (basePadding * 2)

        property real dragX: 100
        property real dragY: 100
        property bool initialized: false

        x: dragX
        y: dragY

        Connections {
            target: clockWindow
            function onWidthChanged() { clockContainer.initPosition() }
            function onHeightChanged() { clockContainer.initPosition() }
        }

        function initPosition() {
            if (!initialized && clockWindow.width > 0 && clockWindow.height > 0) {
                dragX = Math.max(0, clockWindow.width - width - 60)
                dragY = 60
                initialized = true
            }
        }

        Component.onCompleted: initPosition()

        onXChanged: checkScreenBoundary()
        onYChanged: checkScreenBoundary()

        function checkScreenBoundary() {
            if (!dragArea.drag.active) return

            let globalX = clockWindow.screen.x + clockContainer.x
            let globalY = clockWindow.screen.y + clockContainer.y

            let centerX = globalX + (clockContainer.width / 2)
            let centerY = globalY + (clockContainer.height / 2)

            for (let i = 0; i < Quickshell.screens.length; i++) {
                let s = Quickshell.screens[i]
                if (s === clockWindow.screen) continue

                if (centerX >= s.x && centerX <= (s.x + s.width) &&
                    centerY >= s.y && centerY <= (s.y + s.height)) {

                    let newLocalX = globalX - s.x
                    let newLocalY = globalY - s.y

                    clockWindow.screen = s
                    clockContainer.dragX = newLocalX
                    clockContainer.dragY = newLocalY
                    break
                }
            }
        }

        // BACKGROUND PANEL
        Rectangle {
            anchors.fill: parent
            visible: Config.clockShowBackground || Config.clockShowBorder
            color: Config.clockShowBackground ? Config.bgPanel : "transparent"
            radius: Config.cornerRadius
            border.width: Config.clockShowBorder ? (Config.showBorders ? 3 : 1) : 0
            border.color: Config.showBorders ? Config.accent : Qt.rgba(255, 255, 255, 0.15)
            opacity: Config.clockShowBackground ? 0.85 : 1.0
        }

        // DYNAMIC CLOCK LOADER
        Loader {
            id: clockLoader
            anchors.centerIn: parent
            sourceComponent: Config.clockStyle === "analog" ? analogComp : digitalComp
        }

        // --- DIGITAL FACE COMPONENT ---
        Component {
            id: digitalComp

            ColumnLayout {
                spacing: 2

                property var currentDate: new Date()

                Timer {
                    interval: Config.clockShowSeconds ? 1000 : 5000
                    running: true
                    repeat: true
                    onTriggered: currentDate = new Date()
                }

                function formatTimeString() {
                    let fmt = ""
                    if (Config.clockUse12Hour) {
                        fmt = Config.clockShowSeconds ? "h:mm:ss" : "h:mm"
                        if (Config.clockShowAmPm) fmt += " ap"
                    } else {
                        fmt = Config.clockShowSeconds ? "hh:mm:ss" : "hh:mm"
                    }
                    return Qt.formatTime(currentDate, fmt)
                }

                Text {
                    text: formatTimeString()
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontTitle) * 1.5 * Config.clockScale
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    // Always formats as "Fri - Jul 31"
                    text: Qt.formatDate(currentDate, "ddd - MMM d")
                    color: Config.accent
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontSubhead) * Config.clockScale
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // --- ANALOG FACE COMPONENT ---
        Component {
            id: analogComp

            Item {
                // Bounds scaled linearly without redundant offsets
                readonly property real baseSize: 140
                implicitWidth: baseSize * Config.clockScale
                implicitHeight: baseSize * Config.clockScale

                Canvas {
                    id: analogCanvas
                    anchors.fill: parent

                    property var now: new Date()

                    Timer {
                        interval: Config.clockShowSeconds ? 1000 : 5000
                        running: true
                        repeat: true
                        onTriggered: {
                            analogCanvas.now = new Date()
                            analogCanvas.requestPaint()
                        }
                    }

                    onPaint: {
                        var ctx = getContext("2d")
                        var cx = width / 2
                        var cy = height / 2
                        // Clamp stroke margin so dial fits container edge
                        var strokeMargin = Math.max(2, 3 * Config.clockScale)
                        var radius = (Math.min(width, height) / 2) - strokeMargin

                        ctx.reset()

                        // Dial Outline
                        ctx.beginPath()
                        ctx.arc(cx, cy, radius, 0, 2 * Math.PI)
                        ctx.strokeStyle = Qt.color(Config.accent)
                        ctx.lineWidth = strokeMargin
                        ctx.stroke()

                        var hours = now.getHours() % 12
                        var minutes = now.getMinutes()
                        var seconds = now.getSeconds()

                        // Hour Hand
                        var hourAngle = (hours + minutes / 60) * (Math.PI / 6) - (Math.PI / 2)
                        ctx.beginPath()
                        ctx.moveTo(cx, cy)
                        ctx.lineTo(cx + Math.cos(hourAngle) * (radius * 0.5), cy + Math.sin(hourAngle) * (radius * 0.5))
                        ctx.strokeStyle = Qt.color(Config.textMain)
                        ctx.lineWidth = Math.max(1.5, 4 * Config.clockScale)
                        ctx.stroke()

                        // Minute Hand
                        var minAngle = (minutes + seconds / 60) * (Math.PI / 30) - (Math.PI / 2)
                        ctx.beginPath()
                        ctx.moveTo(cx, cy)
                        ctx.lineTo(cx + Math.cos(minAngle) * (radius * 0.75), cy + Math.sin(minAngle) * (radius * 0.75))
                        ctx.strokeStyle = Qt.color(Config.textMain)
                        ctx.lineWidth = Math.max(1.0, 2.5 * Config.clockScale)
                        ctx.stroke()

                        // Second Hand (Conditional)
                        if (Config.clockShowSeconds) {
                            var secAngle = seconds * (Math.PI / 30) - (Math.PI / 2)
                            ctx.beginPath()
                            ctx.moveTo(cx, cy)
                            ctx.lineTo(cx + Math.cos(secAngle) * (radius * 0.85), cy + Math.sin(secAngle) * (radius * 0.85))
                            ctx.strokeStyle = Qt.color(Config.accent)
                            ctx.lineWidth = Math.max(1.0, 1.5 * Config.clockScale)
                            ctx.stroke()
                        }

                        // Center Pin
                        ctx.beginPath()
                        ctx.arc(cx, cy, Math.max(2, 4 * Config.clockScale), 0, 2 * Math.PI)
                        ctx.fillStyle = Qt.color(Config.accent)
                        ctx.fill()
                    }
                }
            }
        }

        // DRAG & SCROLL-RESIZE MOUSE AREA
        MouseArea {
            id: dragArea
            anchors.fill: parent
            drag.target: clockContainer
            drag.axis: Drag.XAndYAxis
            cursorShape: Qt.PointingHandCursor

            onPositionChanged: {
                if (drag.active) {
                    clockContainer.dragX = clockContainer.x
                    clockContainer.dragY = clockContainer.y
                }
            }

            onWheel: (wheel) => {
                let step = 0.05
                if (wheel.angleDelta.y > 0) {
                    Config.clockScale = Math.min(3.0, Config.clockScale + step)
                } else {
                    Config.clockScale = Math.max(0.5, Config.clockScale - step)
                }
            }
        }
    }
}