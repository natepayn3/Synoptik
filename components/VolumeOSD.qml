import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property color flyoutBorderColor: Config.accent
    property real panelWidth: 400
    property real panelHeight: 80
    readonly property real bounceBuffer: 64

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property bool alignRight: false
    property bool alignCenter: true

    anchors {
        bottom: true
        left: alignCenter || !alignRight
        right: alignCenter || alignRight
    }

    margins {
        bottom: (Config.barHeight || 30)
        left: 0
        right: 0
    }

    implicitWidth: panelWidth + bounceBuffer
    implicitHeight: panelHeight + bounceBuffer
    color: "transparent"

    visible: (Config.showOSD || false) || closeTransition.running || openTransition.running

    property int volume: -1 
    property bool isMuted: false
    property bool initialized: false 

    function trigger() {
        osdHideTimer.stop()
        Config.showOSD = true
        osdHideTimer.restart()
    }

    function dismiss() {
        Config.showOSD = false
        osdHideTimer.stop()
    }

    Component.onCompleted: {
        initReadProc.running = true
    }

    Timer {
        id: osdHideTimer
        interval: 2000
        repeat: false
        onTriggered: root.dismiss()
    }

    Process {
        id: initReadProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let cleaned = this.text.trim()
                let match = cleaned.match(/Volume:\s+([0-9.]+)/)
                if (match) {
                    root.volume = Math.round(parseFloat(match[1]) * 100)
                    root.isMuted = cleaned.includes("[MUTED]")
                    root.initialized = true
                }
            }
        }
    }

    Process {
        id: osdReadProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let cleaned = this.text.trim()
                let match = cleaned.match(/Volume:\s+([0-9.]+)/)
                if (match) {
                    let newVol = Math.round(parseFloat(match[1]) * 100)
                    let newMute = cleaned.includes("[MUTED]")

                    if (newVol !== root.volume || newMute !== root.isMuted) {
                        root.volume = newVol
                        root.isMuted = newMute
                        
                        if (root.initialized) {
                            root.trigger()
                        }
                    }
                }
            }
        }
    }

    Process {
        id: osdSubscribeProc
        command: ["stdbuf", "-oL", "pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("sink") || data.includes("server")) {
                    if (!osdReadProc.running) {
                        osdReadProc.running = true
                    }
                }
            }
        }
    }

    Item {
        id: breathingContainer
        width: root.panelWidth
        height: root.panelHeight
        anchors.centerIn: parent
        transformOrigin: Item.Center

        states: [
            State {
                name: "open"
                when: Config.showOSD
                PropertyChanges { target: breathingContainer; scale: 1.0; opacity: 1.0 }
            },
            State {
                name: "closed"
                when: !Config.showOSD
                PropertyChanges { target: breathingContainer; scale: 0.0; opacity: 0.0 }
            }
        ]

        transitions: [
            Transition {
                id: openTransition
                from: "closed"; to: "open"
                ParallelAnimation {
                    NumberAnimation { properties: "scale"; duration: 450; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                    NumberAnimation { properties: "opacity"; duration: 200 }
                }
            },
            Transition {
                id: closeTransition
                from: "open"; to: "closed"
                ParallelAnimation {
                    NumberAnimation { properties: "scale"; duration: 300; easing.type: Easing.InBack }
                    NumberAnimation { properties: "opacity"; duration: 250 }
                }
            }
        ]

        // --- OUTER GRADIENT BORDER CONTAINER ---
        Rectangle {
            anchors.fill: parent
            radius: Config.cornerRadius
            color: Config.showBorders ? Config.accent : "transparent"

            // Clean horizontal gradient canvas with color animation
            Rectangle {
                anchors.fill: parent
                radius: Config.cornerRadius
                visible: Config.showBorders && Config.animateGradient

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop { position: 0.0; color: Config.borderStart }
                    GradientStop { 
                        id: animStop
                        position: 1.0; 
                        color: Config.borderEnd 
                    }
                }

                // Smooth color-shift pulse
                SequentialAnimation {
                    running: Config.showBorders && Config.animateGradient && breathingContainer.opacity > 0
                    loops: Animation.Infinite

                    ColorAnimation {
                        target: animStop
                        property: "color"
                        to: Config.accent
                        duration: 2000
                        easing.type: Easing.InOutQuad
                    }
                    ColorAnimation {
                        target: animStop
                        property: "color"
                        to: Config.borderEnd
                        duration: 2000
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            // --- INNER CONTENT MASK ---
            Rectangle {
                anchors.fill: parent
                anchors.margins: Config.showBorders ? 3 : 0
                radius: Math.max(0, Config.cornerRadius - (Config.showBorders ? 3 : 0))
                color: Config.bgPanel

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(255, 255, 255, 0.05)
                    radius: parent.radius

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismiss()
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Text {
                            text: root.isMuted 
                                ? "hearing_disabled" 
                                : (root.volume === 0 ? "hearing_disabled" : (root.volume < 50 ? "hearing" : "ear_sound"))
                            font.family: "Material Symbols Outlined"
                            font.weight: Font.Bold
                            font.pixelSize: 24
                            color: Config.accent
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // --- HALF SQUIGGLE / HALF STRAIGHT TRACK SLIDER ---
                        Canvas {
                            id: waveCanvas
                            Layout.fillWidth: true
                            implicitHeight: 32
                            Layout.alignment: Qt.AlignVCenter

                            property real animPhase: 0.0
                            property real activeWidth: Math.min(width, width * (Math.max(0, root.volume) / 100))

                            Behavior on activeWidth {
                                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                            }

                            onActiveWidthChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onAnimPhaseChanged: requestPaint()

                            // Slow horizontal wave animation
                            NumberAnimation on animPhase {
                                running: breathingContainer.opacity > 0
                                from: 0.0
                                to: Math.PI * 2
                                duration: 3500
                                loops: Animation.Infinite
                            }

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)

                                var waveAmplitude = 5.0 
                                var waveFrequency = 0.18 
                                var centerY = height / 2
                                var strokeLineWidth = 5
                                
                                // Adjust this offset to make the indicator taller or shorter
                                var indicatorExtraHeight = 8 

                                // 1. Active Squiggle Wave (Left of Indicator)
                                if (waveCanvas.activeWidth > 0) {
                                    ctx.save()
                                    ctx.beginPath()
                                    for (var x = 0; x <= waveCanvas.activeWidth; x += 1) {
                                        var y = centerY + Math.sin(x * waveFrequency + waveCanvas.animPhase) * waveAmplitude
                                        if (x === 0) ctx.moveTo(x, y)
                                        else ctx.lineTo(x, y)
                                    }
                                    ctx.strokeStyle = root.isMuted ? Config.textMuted : Config.accent
                                    ctx.lineWidth = strokeLineWidth
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.stroke()
                                    ctx.restore()
                                }

                                // 2. Inactive Straight Line Track (Right of Indicator)
                                if (waveCanvas.activeWidth < width) {
                                    ctx.save()
                                    ctx.beginPath()
                                    ctx.moveTo(waveCanvas.activeWidth, centerY)
                                    ctx.lineTo(width, centerY)
                                    ctx.strokeStyle = Qt.rgba(255, 255, 255, 0.15)
                                    ctx.lineWidth = strokeLineWidth
                                    ctx.lineCap = "round"
                                    ctx.stroke()
                                    ctx.restore()
                                }

                                // 3. Vertical Indicator Line
                                if (waveCanvas.activeWidth <= width) {
                                    ctx.save()
                                    ctx.beginPath()
                                    ctx.moveTo(waveCanvas.activeWidth, centerY - waveAmplitude - indicatorExtraHeight)
                                    ctx.lineTo(waveCanvas.activeWidth, centerY + waveAmplitude + indicatorExtraHeight)
                                    ctx.strokeStyle = Config.textMain
                                    ctx.lineWidth = 8
                                    ctx.lineCap = "round"
                                    ctx.stroke()
                                    ctx.restore()
                                }
                            }
                        }

                        Text {
                            text: root.isMuted ? "Muted" : Math.max(0, root.volume) + "%"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontTitle)
                            font.bold: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}