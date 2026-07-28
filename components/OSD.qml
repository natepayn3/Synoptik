import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

MorphingFlyout {
    id: root

    isOpen: Config.showOSD
    alignRight: true
    panelWidth: 400
    panelHeight: 50

    property int volume: 50
    property bool isMuted: false

    function trigger() {
        if (Config.showAudio) return;

        osdHideTimer.stop()
        Config.showOSD = true
        osdHideTimer.restart()
    }

    function dismiss() {
        Config.showOSD = false
        osdHideTimer.stop()
    }

    Timer {
        id: osdHideTimer
        interval: 2000
        repeat: false
        onTriggered: root.dismiss()
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
                        root.trigger()
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
                if (data.includes("sink")) {
                    osdReadProc.running = true
                }
            }
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        
        // Manual vertical offset shifting the row 4px higher
        anchors.verticalCenterOffset: -12
        
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            text: root.isMuted 
                ? "volume_off" 
                : (root.volume === 0 ? "volume_mute" : (root.volume < 50 ? "volume_down" : "volume_up"))
            font.family: "Material Symbols Outlined"
            font.weight: Font.Bold
            font.pixelSize: 20
            color: Config.accent
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            color: Qt.rgba(255, 255, 255, 0.1)
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                width: Math.min(parent.width, parent.width * (root.volume / 100))
                height: parent.height
                radius: 2
                color: root.isMuted ? Config.textMuted : Config.accent

                Behavior on width {
                    NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                }
            }
        }

        Text {
            text: root.isMuted ? "Muted" : root.volume + "%"
            color: Config.textMain
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontSubhead)
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }
    }
}