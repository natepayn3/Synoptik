import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: osdRoot

    implicitWidth: 400
    implicitHeight: mainLayout.implicitHeight + 24

    property int volume: -1 
    property bool isMuted: false
    property bool initialized: false 

    function trigger() {
        if (typeof Config !== "undefined" && (Config.showAudio || Config.showControlCenter)) return
        
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

    Connections {
        target: Config
        function onShowOSDChanged() {
            if (Config.showOSD) {
                osdHideTimer.restart()
            }
        }
    }

    Timer {
        id: osdHideTimer
        interval: 2000
        repeat: false
        onTriggered: osdRoot.dismiss()
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
                    osdRoot.volume = Math.round(parseFloat(match[1]) * 100)
                    osdRoot.isMuted = cleaned.includes("[MUTED]")
                    osdRoot.initialized = true
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

                    if (newVol !== osdRoot.volume || newMute !== osdRoot.isMuted) {
                        osdRoot.volume = newVol
                        osdRoot.isMuted = newMute
                        
                        if (osdRoot.initialized) {
                            osdRoot.trigger()
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

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: cardContent.implicitHeight + 24
            color: Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: osdRoot.dismiss()
            }

            RowLayout {
                id: cardContent
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Rectangle {
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: Config.cornerRadius / 2
                    color: Qt.rgba(255, 255, 255, 0.06)
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

                    Text {
                        anchors.centerIn: parent
                        text: osdRoot.isMuted 
                            ? "volume_off" 
                            : (osdRoot.volume === 0 ? "volume_mute" : (osdRoot.volume < 50 ? "volume_down" : "volume_up"))
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 22
                        color: osdRoot.isMuted ? Config.textMuted : Config.accent
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: 48

                    Canvas {
                        id: waveCanvasH
                        anchors.fill: parent

                        property real animPhase: 0.0
                        property real activeSpan: Math.min(width, width * (Math.max(0, osdRoot.volume) / 100))

                        Behavior on activeSpan {
                            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                        }

                        onActiveSpanChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onAnimPhaseChanged: requestPaint()

                        NumberAnimation on animPhase {
                            running: osdRoot.visible
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
                            var strokeLineWidth = 4
                            var centerY = height / 2

                            if (waveCanvasH.activeSpan > 0) {
                                ctx.save()
                                ctx.beginPath()
                                for (var x = 0; x <= waveCanvasH.activeSpan; x += 1) {
                                    var y = centerY + Math.sin(x * waveFrequency + waveCanvasH.animPhase) * waveAmplitude
                                    if (x === 0) ctx.moveTo(x, y)
                                    else ctx.lineTo(x, y)
                                }
                                ctx.strokeStyle = osdRoot.isMuted ? Config.textMuted : Config.accent
                                ctx.lineWidth = strokeLineWidth
                                ctx.lineCap = "round"
                                ctx.lineJoin = "round"
                                
                                if (!osdRoot.isMuted) {
                                    ctx.shadowColor = Config.accent
                                    ctx.shadowBlur = 8
                                }

                                ctx.stroke()
                                ctx.restore()
                            }

                            if (waveCanvasH.activeSpan < width) {
                                ctx.save()
                                ctx.beginPath()
                                ctx.moveTo(waveCanvasH.activeSpan, centerY)
                                ctx.lineTo(width, centerY)
                                ctx.strokeStyle = Qt.rgba(255, 255, 255, 0.12)
                                ctx.lineWidth = strokeLineWidth
                                ctx.lineCap = "round"
                                ctx.stroke()
                                ctx.restore()
                            }
                        }
                    }

                    Rectangle {
                        width: 6
                        height: 20
                        radius: 3
                        color: Config.textMain
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width, waveCanvasH.activeSpan - (width / 2)))
                    }
                }

                Text {
                    text: osdRoot.isMuted ? "Muted" : Math.max(0, osdRoot.volume) + "%"
                    color: osdRoot.isMuted ? Config.textMuted : Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontSubhead)
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 48
                }
            }
        }
    }
}