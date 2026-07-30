import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property color flyoutBorderColor: Config.accent
    property real panelWidth: 420
    property real panelHeight: 80

    // Equal padding margin buffer matching NotificationOSD
    property real overshootPadding: 30

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
        bottom: (Config.barHeight || 30) - (overshootPadding / 2)
        left: 0
        right: 0
    }

    implicitWidth: panelWidth + overshootPadding
    implicitHeight: panelHeight + overshootPadding
    color: "transparent"

    mask: Region {
        item: mainFrame
    }

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

    // Static outer bounding region
    Item {
        id: mainFrame
        anchors.fill: parent

        // Centered scaling inner container
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

            // --- OUTER GRADIENT BORDER FRAME ---
            Rectangle {
                anchors.fill: parent
                radius: Config.cornerRadius
                color: Config.showBorders ? Config.accent : "transparent"

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

                // --- MAIN INNER BODY ---
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Config.showBorders ? 3 : 0
                    radius: Math.max(0, Config.cornerRadius - (Config.showBorders ? 3 : 0))
                    color: Config.bgPanel

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismiss()
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        // LEFT APP ICON BADGE
                        Rectangle {
                            implicitWidth: 48
                            implicitHeight: 48
                            radius: Config.cornerRadius / 2
                            color: Qt.rgba(255, 255, 255, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.1)
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: root.isMuted 
                                    ? "volume_off" 
                                    : (root.volume === 0 ? "volume_mute" : (root.volume < 50 ? "volume_down" : "volume_up"))
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 22
                                color: root.isMuted ? Config.textMuted : Config.accent
                            }
                        }

                        // CONTENT CARD CONTAINER
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Config.cornerRadius / 2
                            color: Qt.rgba(255, 255, 255, 0.05)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                // HALF-SINE WAVE TRACK & INSTANT PILL
                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: 32
                                    Layout.alignment: Qt.AlignVCenter

                                    Canvas {
                                        id: waveCanvas
                                        anchors.fill: parent

                                        property real animPhase: 0.0
                                        property real activeWidth: Math.min(width, width * (Math.max(0, root.volume) / 100))

                                        // Snappy 80ms animation for instant reaction
                                        Behavior on activeWidth {
                                            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                                        }

                                        onActiveWidthChanged: requestPaint()
                                        onWidthChanged: requestPaint()
                                        onAnimPhaseChanged: requestPaint()

                                        NumberAnimation on animPhase {
                                            running: breathingContainer.opacity > 0
                                            from: 0.0
                                            to: Math.PI * 2
                                            duration: 3000
                                            loops: Animation.Infinite
                                        }

                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)

                                            var waveAmplitude = 4.0 
                                            var waveFrequency = 0.14 
                                            var centerY = height / 2
                                            var strokeLineWidth = 4

                                            // 1. Active Wave Track (Left)
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
                                                
                                                if (!root.isMuted) {
                                                    ctx.shadowColor = Config.accent
                                                    ctx.shadowBlur = 8
                                                }

                                                ctx.stroke()
                                                ctx.restore()
                                            }

                                            // 2. Inactive Straight Line Track (Right)
                                            if (waveCanvas.activeWidth < width) {
                                                ctx.save()
                                                ctx.beginPath()
                                                ctx.moveTo(waveCanvas.activeWidth, centerY)
                                                ctx.lineTo(width, centerY)
                                                ctx.strokeStyle = Qt.rgba(255, 255, 255, 0.12)
                                                ctx.lineWidth = strokeLineWidth
                                                ctx.lineCap = "round"
                                                ctx.stroke()
                                                ctx.restore()
                                            }
                                        }
                                    }

                                    // INSTANT-TRACKING PILL INDICATOR
                                    Rectangle {
                                        width: 6
                                        height: 20
                                        radius: 3
                                        color: Config.textMain
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: Math.max(0, Math.min(parent.width - width, waveCanvas.activeWidth - (width / 2)))
                                    }
                                }

                                // VOLUME PERCENTAGE
                                Text {
                                    text: root.isMuted ? "Muted" : Math.max(0, root.volume) + "%"
                                    color: root.isMuted ? Config.textMuted : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontSubhead)
                                    font.bold: true
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: 48
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}