import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: cavaRoot

    property var configRef: null

    // Runs whenever either the desktop visualizer widget or ambient shell
    // breathing wants live audio data - either one alone should be enough.
    readonly property bool active: !!(configRef && configRef.isLoaded &&
        (configRef.showDesktopCava || configRef.ambientBreatheEnabled))
    property var bars: []
    property bool cavaAvailable: true
    property bool pendingLaunch: false

    // --- AMBIENT BREATHING LEVEL ---
    // A slow, smoothed 0..1 signal derived from bass energy, meant for subtle
    // whole-shell modulation (border pulse, panel alpha, etc.) rather than the
    // per-bar visualizer above. Attacks quickly on rising bass, releases slowly
    // so it reads as "breathing" instead of flickering with every frame.
    property real breatheLevel: 0.0
    readonly property int breatheBinCount: 4
    readonly property real breatheAttack: 0.35
    readonly property real breatheRelease: 0.06
    // cava's raw ascii bars (0..1 here after /1000) sit well under 0.1 for
    // most bass content at normal listening volume - autosens is off and
    // sensitivity=100 is tuned for the visualizer widget, not this. Measured
    // live against a sustained 60Hz tone at full system volume: raw bass
    // average topped out around 0.05-0.06, which is imperceptible three
    // multipliers downstream (intensity, then the border's alpha coefficient).
    // This gain is local to the breathing signal only, so it doesn't affect
    // cavaSensitivity or the visible desktop cava widget.
    readonly property real breatheGain: 14.0

    function updateBreatheLevel() {
        if (!cavaRoot.bars || cavaRoot.bars.length === 0) {
            breatheLevel = Math.max(0.0, breatheLevel - breatheRelease)
            return
        }
        let count = Math.min(breatheBinCount, cavaRoot.bars.length)
        let sum = 0.0
        for (let i = 0; i < count; i++) sum += cavaRoot.bars[i]
        let target = Math.max(0.0, Math.min(1.0, (sum / count) * breatheGain))

        let rate = target > breatheLevel ? breatheAttack : breatheRelease
        breatheLevel = breatheLevel + (target - breatheLevel) * rate
    }

    onBarsChanged: updateBreatheLevel()

    // Bars stop arriving entirely when cava exits (active -> false), so this
    // keeps decaying breatheLevel back to 0 smoothly instead of leaving it
    // stuck at whatever value it last held.
    property Timer breatheDecayTimer: Timer {
        interval: 50
        running: !cavaRoot.active && cavaRoot.breatheLevel > 0.001
        repeat: true
        onTriggered: cavaRoot.breatheLevel = Math.max(0.0, cavaRoot.breatheLevel - cavaRoot.breatheRelease)
    }

    readonly property string confDir: Quickshell.env("HOME") + "/.cache/synoptik"
    readonly property string confPath: confDir + "/cava.conf"

    function buildConfigText() {
        if (!configRef) return ""

        let barsCount = Math.max(4, Math.min(200, Math.round(configRef.cavaBars || 40)))
        let framerate = Math.max(15, Math.min(144, Math.round(configRef.cavaFramerate || 60)))
        let sensitivity = Math.max(10, Math.min(500, Math.round(configRef.cavaSensitivity || 100)))
        let noiseReduction = Math.max(0, Math.min(1, configRef.cavaSmoothing !== undefined ? configRef.cavaSmoothing : 0.77))

        return "" +
            "[general]\n" +
            "bars = " + barsCount + "\n" +
            "framerate = " + framerate + "\n" +
            "sensitivity = " + sensitivity + "\n" +
            "autosens = 0\n" +
            "\n" +
            "[input]\n" +
            "method = pulse\n" +
            "source = auto\n" +
            "\n" +
            "[output]\n" +
            "method = raw\n" +
            "raw_target = /dev/stdout\n" +
            "data_format = ascii\n" +
            "ascii_max_range = 1000\n" +
            "bar_delimiter = 59\n" +
            "frame_delimiter = 10\n" +
            "channels = mono\n" +
            "\n" +
            "[smoothing]\n" +
            "noise_reduction = " + noiseReduction.toFixed(2) + "\n"
    }

    function writeConfigAndStart() {
        if (!cavaRoot.active) return
        let conf = cavaRoot.buildConfigText()
        let cmd = "mkdir -p " + cavaRoot.confDir + " && printf '%s' '" + conf.replace(/'/g, "'\\''") + "' > " + cavaRoot.confPath
        confWriter.command = ["fish", "-c", cmd]
        confWriter.running = true
    }

    // Stops the current cava process (if any) and marks that a fresh one should be
    // launched once it has actually exited. Process.running must not be flipped
    // false -> true within the same tick: the old process needs real wall-clock time
    // to terminate, and doing so was the cause of the visualizer getting stuck after
    // changing a setting that requires a restart (bars/framerate/sensitivity/smoothing).
    function launchCava() {
        if (!cavaRoot.active) return
        if (cavaProc.running) {
            pendingLaunch = true
            cavaProc.running = false
        } else {
            cavaProc.command = ["cava", "-p", cavaRoot.confPath]
            cavaProc.running = true
        }
    }

    function requestRestart() {
        restartDebounce.restart()
    }

    property Process confWriter: Process {
        id: confWriter
        running: false
        onExited: cavaRoot.launchCava()
    }

    property Process cavaProc: Process {
        id: cavaProc
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (!data) return
                let parts = data.split(";").filter(p => p.length > 0)
                if (parts.length === 0) return
                cavaRoot.bars = parts.map(p => {
                    let n = parseInt(p, 10)
                    if (isNaN(n)) return 0
                    return Math.max(0, Math.min(1, n / 1000))
                })
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (cavaRoot.pendingLaunch) {
                cavaRoot.pendingLaunch = false
                if (cavaRoot.active) {
                    cavaProc.command = ["cava", "-p", cavaRoot.confPath]
                    cavaProc.running = true
                }
            } else if (cavaRoot.active && exitCode !== 0) {
                cavaRoot.cavaAvailable = false
            }
        }
    }

    property Timer restartDebounce: Timer {
        id: restartDebounce
        interval: 250
        repeat: false
        onTriggered: cavaRoot.writeConfigAndStart()
    }

    onActiveChanged: {
        if (active) {
            cavaAvailable = true
            writeConfigAndStart()
        } else {
            pendingLaunch = false
            cavaProc.running = false
            bars = []
        }
    }
}
