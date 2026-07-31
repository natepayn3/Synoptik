import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: clockWindow
    visible: Config.showDesktopClock && (screen ? Config.isClockEnabledForScreen(screen.name) : true)

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
        
        readonly property real basePadding: 16
        width: clockLoader.implicitWidth + (basePadding * 2)
        height: clockLoader.implicitHeight + (basePadding * 2)

        // Per-screen scale factor
        property real currentScale: clockWindow.screen ? Config.getClockScale(clockWindow.screen.name) : 1.0

        property real dragX: 100
        property real dragY: 100
        property bool initialized: false

        x: dragX
        y: dragY

        // RESTORE SAVED POSITION ONCE SCREEN & CONFIG ARE READY
        function restorePosition() {
            if (!clockWindow.screen) return

            let defaultX = Math.max(0, clockWindow.width - width - 60)
            let defaultY = 60

            let savedPos = Config.getClockPosition(clockWindow.screen.name, defaultX, defaultY)
            
            // Only assign if valid numbers exist in settings
            if (savedPos && typeof savedPos.x === "number" && typeof savedPos.y === "number") {
                dragX = savedPos.x
                dragY = savedPos.y
                initialized = true
            }
        }

        // Trigger position restore when config finishes loading from disk
        Connections {
            target: Config
            function onIsLoadedChanged() {
                if (Config.isLoaded) clockContainer.restorePosition()
            }
        }

        Component.onCompleted: {
            if (Config.isLoaded) restorePosition()
        }

        // SAVE POSITION ON DRAG RELEASE OR POSITION CHANGE
        onXChanged: {
            if (initialized && dragArea.drag.active && clockWindow.screen) {
                Config.saveClockPosition(clockWindow.screen.name, dragX, dragY)
            }
        }
        onYChanged: {
            if (initialized && dragArea.drag.active && clockWindow.screen) {
                Config.saveClockPosition(clockWindow.screen.name, dragX, dragY)
            }
        }

        // BACKGROUND PANEL
        Rectangle {
            anchors.fill: parent
            visible: Config.clockShowBackground || Config.clockShowBorder
            color: Config.clockShowBackground ? Config.bgPanel : "transparent"
            radius: Config.cornerRadius
            border.width: Config.clockShowBorder ? (Config.showBorders ? 2 : 1) : 0
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
                spacing: 4

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

                // Main Time Display
                Text {
                    text: formatTimeString()
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontTitle) * 1.5 * clockContainer.currentScale
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                // Modernized Date Row (Bold Day | Pipe | Light Date)
                RowLayout {
                    spacing: 6
                    Layout.alignment: Qt.AlignHCenter

                    Text {
                        text: Qt.formatDate(currentDate, "ddd")
                        color: Config.accent
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontSubhead) * clockContainer.currentScale
                        font.bold: true
                    }

                    Text {
                        text: "|"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontSubhead) * clockContainer.currentScale
                        opacity: 0.6
                    }

                    Text {
                        text: Qt.formatDate(currentDate, "MMM d")
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontSubhead) * clockContainer.currentScale
                        font.bold: false
                    }
                }
            }
        }

        // --- ANALOG FACE COMPONENT ---
        Component {
            id: analogComp

            Item {
                readonly property real baseSize: 140
                implicitWidth: baseSize * clockContainer.currentScale
                implicitHeight: baseSize * clockContainer.currentScale

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
                        var strokeMargin = Math.max(2, 3 * clockContainer.currentScale)
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
                        ctx.lineWidth = Math.max(1.5, 4 * clockContainer.currentScale)
                        ctx.stroke()

                        // Minute Hand
                        var minAngle = (minutes + seconds / 60) * (Math.PI / 30) - (Math.PI / 2)
                        ctx.beginPath()
                        ctx.moveTo(cx, cy)
                        ctx.lineTo(cx + Math.cos(minAngle) * (radius * 0.75), cy + Math.sin(minAngle) * (radius * 0.75))
                        ctx.strokeStyle = Qt.color(Config.textMain)
                        ctx.lineWidth = Math.max(1.0, 2.5 * clockContainer.currentScale)
                        ctx.stroke()

                        // Second Hand
                        if (Config.clockShowSeconds) {
                            var secAngle = seconds * (Math.PI / 30) - (Math.PI / 2)
                            ctx.beginPath()
                            ctx.moveTo(cx, cy)
                            ctx.lineTo(cx + Math.cos(secAngle) * (radius * 0.85), cy + Math.sin(secAngle) * (radius * 0.85))
                            ctx.strokeStyle = Qt.color(Config.accent)
                            ctx.lineWidth = Math.max(1.0, 1.5 * clockContainer.currentScale)
                            ctx.stroke()
                        }

                        // Center Pin
                        ctx.beginPath()
                        ctx.arc(cx, cy, Math.max(2, 4 * clockContainer.currentScale), 0, 2 * Math.PI)
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
                let newScale = clockContainer.currentScale
                if (wheel.angleDelta.y > 0) {
                    newScale = Math.min(3.0, newScale + step)
                } else {
                    newScale = Math.max(0.5, newScale - step)
                }

                if (clockWindow.screen) {
                    Config.saveClockScale(clockWindow.screen.name, newScale)
                }
            }
        }
    }
}