import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."

Rectangle {
    id: root

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.alignment: Qt.AlignTop
    implicitHeight: 64
    radius: Config.cornerRadius

    color: cardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
    Behavior on color { ColorAnimation { duration: 150 } }

    property bool hasHypridle: false
    // States: 0 = Off (hypridle running), 1 = Awake Indefinite, 2 = Awake 30m Timer
    property int caffeineState: 0
    
    // Absolute expiration epoch timestamp (ms)
    property double timerEndTime: 0
    property string remainingTimeString: ""

    TapHandler {
        enabled: root.hasHypridle
        onTapped: root.cycleCaffeine()
    }

    HoverHandler {
        id: cardHover
        cursorShape: root.hasHypridle ? Qt.PointingHandCursor : Qt.ForbiddenCursor
    }

    // Check if hypridle binary exists on system
    Process {
        id: checkBinaryProc
        command: ["fish", "-c", "which hypridle"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasHypridle = this.text.trim().length > 0
                if (root.hasHypridle) checkStatusProc.running = true
            }
        }
    }

    // Check if hypridle is currently running
    Process {
        id: checkStatusProc
        command: ["fish", "-c", "pgrep -x hypridle"]
        running: false
        
        stdout: StdioCollector {
            id: statusOutput
        }

        onExited: (exitCode, exitStatus) => {
            let isRunning = (exitCode === 0 && statusOutput.text.trim().length > 0)
            
            if (!isRunning) {
                if (root.caffeineState === 0) {
                    root.caffeineState = 1
                }
            } else {
                if (root.caffeineState !== 0) {
                    root.caffeineState = 0
                    root.timerEndTime = 0
                }
            }
        }
    }

    // Periodic status poller to detect manual pkill / terminal actions
    Timer {
        interval: 2000
        running: root.hasHypridle
        repeat: true
        onTriggered: {
            if (!execProc.running && !checkStatusProc.running) {
                checkStatusProc.running = true
            }
        }
    }

    // Clean 1000ms poller
    Timer {
        id: countdownTicker
        interval: 1000
        repeat: true
        running: root.caffeineState === 2
        onTriggered: root.updateCountdown()
    }

    Process {
        id: execProc
        running: false
        onExited: {
            checkStatusProc.running = true
        }
    }

    function updateCountdown() {
        if (root.caffeineState !== 2) return

        let now = Date.now()
        let diffMs = root.timerEndTime - now

        if (diffMs <= 0) {
            root.caffeineState = 0
            root.timerEndTime = 0
            setHypridleRunning(true)
            return
        }

        // Math.round creates a stable window (+/- 500ms) around each target second
        let totalSeconds = Math.round(diffMs / 1000)
        let mins = Math.floor(totalSeconds / 60)
        let secs = totalSeconds % 60

        root.remainingTimeString = `${mins}:${secs < 10 ? '0' : ''}${secs}`
    }

    function setHypridleRunning(enable) {
        let cmd = enable
            ? "systemctl --user start hypridle.service"
            : "pkill -x hypridle; and systemctl --user stop hypridle.service; and systemctl --user reset-failed hypridle.service"

        execProc.command = ["fish", "-c", cmd]
        execProc.running = true
    }

    function cycleCaffeine() {
        if (!hasHypridle) return

        let nextState = (caffeineState + 1) % 3

        if (nextState === 1) {
            root.timerEndTime = 0
            setHypridleRunning(false)
        } else if (nextState === 2) {
            // Align target expiration precisely to integer seconds (strips fractional ms)
            let roundedNow = Math.floor(Date.now() / 1000) * 1000
            root.timerEndTime = roundedNow + 1800000
            root.updateCountdown()
            setHypridleRunning(false)
        } else {
            root.timerEndTime = 0
            setHypridleRunning(true)
        }

        root.caffeineState = nextState
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8
        opacity: root.hasHypridle ? 1.0 : 0.45

        Rectangle {
            implicitWidth: 44
            implicitHeight: 44
            radius: Config.cornerRadius / 2
            
            color: {
                if (!root.hasHypridle || root.caffeineState === 0) {
                    return Qt.rgba(255, 255, 255, 0.08)
                } else if (root.caffeineState === 1) {
                    return Config.accent
                } else {
                    return Qt.tint(Config.accent, Qt.rgba(1, 1, 1, 0.4))
                }
            }

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: root.caffeineState === 2 ? "schedule" : "coffee"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 22
                color: (!root.hasHypridle || root.caffeineState === 0) ? Config.textMuted : Config.bgBase
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: "Caffeine"
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
                color: Config.textMain
            }

            Text {
                text: {
                    if (!root.hasHypridle) return "Unavailable"
                    switch (root.caffeineState) {
                        case 1: return "Awake"
                        case 2: return root.remainingTimeString
                        default: return "Off"
                    }
                }
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                color: Config.textMuted
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}