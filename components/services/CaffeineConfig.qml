import QtQuick
import Quickshell.Io

QtObject {
    id: caffeineRoot

    property var configRef: null

    // --- CAFFEINE STATE & TIMER ---
    property bool caffeineHasHypridle: false
    property int caffeineState: 0
    property double caffeineTimerEndTime: 0
    property string caffeineRemainingTimeString: ""

    property Process caffeineCheckBinaryProc: Process {
        id: caffeineCheckBinaryProc
        command: ["fish", "-c", "which hypridle"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                caffeineRoot.caffeineHasHypridle = this.text.trim().length > 0
                if (caffeineRoot.caffeineHasHypridle) caffeineRoot.caffeineCheckStatusProc.running = true
            }
        }
    }

    property Process caffeineCheckStatusProc: Process {
        id: caffeineCheckStatusProc
        command: ["fish", "-c", "pgrep -x hypridle"]
        running: false
        stdout: StdioCollector { id: caffeineStatusOutput }

        onExited: (exitCode, exitStatus) => {
            let isRunning = (exitCode === 0 && caffeineStatusOutput.text.trim().length > 0)
            if (!isRunning) {
                if (caffeineRoot.caffeineState === 0) caffeineRoot.caffeineState = 1
            } else {
                if (caffeineRoot.caffeineState !== 0) {
                    caffeineRoot.caffeineState = 0
                    caffeineRoot.caffeineTimerEndTime = 0
                }
            }
        }
    }

    property Process caffeineExecProc: Process {
        id: caffeineExecProc
        running: false
        onExited: caffeineRoot.caffeineCheckStatusProc.running = true
    }

    // Only polls when hypridle is present and caffeine override is active
    property Timer caffeinePoller: Timer {
        interval: 5000
        running: caffeineRoot.caffeineHasHypridle && caffeineRoot.caffeineState !== 0
        repeat: true
        onTriggered: {
            if (!caffeineRoot.caffeineExecProc.running && !caffeineRoot.caffeineCheckStatusProc.running) {
                caffeineRoot.caffeineCheckStatusProc.running = true
            }
        }
    }

    property Timer caffeineCountdownTicker: Timer {
        id: caffeineCountdownTicker
        interval: 1000
        repeat: true
        running: caffeineRoot.caffeineState === 2
        onTriggered: caffeineRoot.updateCaffeineCountdown()
    }

    function updateCaffeineCountdown() {
        if (caffeineRoot.caffeineState !== 2) return
        let now = Date.now()
        let diffMs = caffeineRoot.caffeineTimerEndTime - now

        if (diffMs <= 0) {
            caffeineRoot.caffeineState = 0
            caffeineRoot.caffeineTimerEndTime = 0
            setHypridleRunning(true)
            return
        }

        let totalSeconds = Math.round(diffMs / 1000)
        let mins = Math.floor(totalSeconds / 60)
        let secs = totalSeconds % 60
        caffeineRoot.caffeineRemainingTimeString = `${mins}:${secs < 10 ? '0' : ''}${secs}`
    }

    function setHypridleRunning(enable) {
        let cmd = enable
            ? "systemctl --user start hypridle.service"
            : "pkill -x hypridle; and systemctl --user stop hypridle.service; and systemctl --user reset-failed hypridle.service"

        caffeineExecProc.command = ["fish", "-c", cmd]
        caffeineExecProc.running = true
    }

    function addCaffeineMinutes(minutes) {
        if (caffeineState !== 2) return
        let msToAdd = minutes * 60 * 1000
        let now = Date.now()
        let baseTime = Math.max(now, caffeineTimerEndTime)
        let newEndTime = baseTime + msToAdd

        if (newEndTime <= now) {
            caffeineState = 0
            caffeineTimerEndTime = 0
            setHypridleRunning(true)
        } else {
            caffeineTimerEndTime = newEndTime
            updateCaffeineCountdown()
        }
    }

    function cycleCaffeine() {
        if (!caffeineHasHypridle) return
        let nextState = (caffeineState + 1) % 3

        if (nextState === 1) {
            caffeineTimerEndTime = 0
            setHypridleRunning(false)
        } else if (nextState === 2) {
            let roundedNow = Math.floor(Date.now() / 1000) * 1000
            caffeineTimerEndTime = roundedNow + 900000
            updateCaffeineCountdown()
            setHypridleRunning(false)
        } else {
            caffeineTimerEndTime = 0
            setHypridleRunning(true)
        }

        caffeineState = nextState
    }

    function startCaffeineTimer(minutes) {
        if (!caffeineHasHypridle) return
        if (minutes <= 0) {
            caffeineState = 0
            caffeineTimerEndTime = 0
            setHypridleRunning(true)
            return
        }
        let roundedNow = Math.floor(Date.now() / 1000) * 1000
        caffeineTimerEndTime = roundedNow + (minutes * 60 * 1000)
        caffeineState = 2
        updateCaffeineCountdown()
        setHypridleRunning(false)
    }

    function setIndefiniteCaffeine() {
        if (!caffeineHasHypridle) return
        caffeineState = 1
        caffeineTimerEndTime = 0
        setHypridleRunning(false)
    }
}
