import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Battery telemetry beyond "what percent is it".
//
// The shell previously knew two things about the battery - capacity and
// status, read from sysfs - plus an instantaneous wattage from a 3s
// `cat power_now` poll. That leaves out everything a laptop user actually
// wants: how long they have left, whether the cell is worn out, and the
// charge ceiling that decides how fast it wears.
//
// UPower already computes time-to-empty/full properly (it smooths the rate
// rather than dividing by an instantaneous reading, which on a laptop swings
// by 10W between keystrokes) and reports health, so that comes from
// Quickshell.Services.UPower. Charge thresholds have no UPower interface and
// stay on sysfs.
QtObject {
    id: root

    property var configRef: null

    readonly property var device: UPower.displayDevice
    readonly property bool available: root.device
        && root.device.isLaptopBattery
        && root.device.isPresent

    readonly property real percentage: root.device ? root.device.percentage : 0
    readonly property int state: root.device ? root.device.state : UPowerDeviceState.Unknown
    readonly property bool charging: root.state === UPowerDeviceState.Charging
        || root.state === UPowerDeviceState.PendingCharge
    readonly property bool fullyCharged: root.state === UPowerDeviceState.FullyCharged

    // Watts. UPower reports this signed by direction; the card only ever wants
    // the magnitude.
    readonly property real powerDraw: root.device ? Math.abs(root.device.changeRate) : 0

    readonly property real energy: root.device ? root.device.energy : 0
    readonly property real energyCapacity: root.device ? root.device.energyCapacity : 0

    // Seconds. UPower reports 0 for "can't say yet" - right after a plug/unplug
    // it needs a moment of rate history before either is meaningful.
    readonly property real timeToEmpty: root.device ? root.device.timeToEmpty : 0
    readonly property real timeToFull: root.device ? root.device.timeToFull : 0

    readonly property bool healthSupported: root.device ? root.device.healthSupported : false
    readonly property real healthPercentage: root.device ? root.device.healthPercentage : 0

    // --- TIME REMAINING ---

    readonly property real secondsRemaining: {
        if (root.charging) return root.timeToFull
        if (root.state === UPowerDeviceState.Discharging) return root.timeToEmpty
        return 0
    }

    readonly property bool hasEstimate: root.secondsRemaining > 0

    function formatDuration(seconds) {
        if (!seconds || seconds <= 0) return "--"
        let mins = Math.round(seconds / 60)
        if (mins < 60) return mins + "m"
        let hours = Math.floor(mins / 60)
        let rem = mins % 60
        // Past a day the minutes are noise on an estimate this rough.
        if (hours >= 24) return Math.floor(hours / 24) + "d " + (hours % 24) + "h"
        return rem === 0 ? hours + "h" : hours + "h " + rem + "m"
    }

    readonly property string timeRemainingText: {
        if (root.fullyCharged) return "Full"
        if (!root.hasEstimate) return "Estimating"
        return root.formatDuration(root.secondsRemaining)
    }

    readonly property string timeRemainingLabel: {
        if (root.fullyCharged) return "CHARGED"
        if (root.charging) return "UNTIL FULL"
        return "REMAINING"
    }

    // --- CHARGE THRESHOLDS ---
    // ThinkPad, ASUS, Framework, Dell, LG and most Chromebooks expose these.
    // Capping the ceiling at 60-80% is the single biggest thing a user can do
    // for cell longevity, and it previously meant editing sysfs by hand or
    // installing TLP.

    readonly property string sysfsBase: "/sys/class/power_supply/"
    property string batteryName: "BAT0"

    property int chargeLimitEnd: -1     // -1 = unsupported / unknown
    property int chargeLimitStart: -1
    readonly property bool chargeLimitSupported: root.chargeLimitEnd >= 0

    // 100 means "no cap", which reads better as Off than as a limit.
    readonly property bool chargeLimitActive: root.chargeLimitSupported && root.chargeLimitEnd < 100

    readonly property var chargeLimitPresets: [60, 80, 100]

    function chargeLimitLabel(v) {
        return v >= 100 ? "Off" : v + "%"
    }

    // Resolve which BATn the kernel is using, once. UPower's nativePath is the
    // authority when it's there; otherwise fall back to probing.
    function resolveBatteryName() {
        if (root.device && root.device.nativePath) {
            let parts = root.device.nativePath.split("/")
            let last = parts[parts.length - 1]
            if (last && last.length > 0) {
                root.batteryName = last
                return
            }
        }
        battNameProc.running = true
    }

    property Process battNameProc: Process {
        id: battNameProc
        running: false
        command: ["sh", "-c",
            "for b in /sys/class/power_supply/BAT*; do [ -d \"$b\" ] && basename \"$b\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                let n = this.text.trim().split("\n")[0]
                if (n) root.batteryName = n
            }
        }
    }

    function refreshChargeLimit() {
        if (!limitReadProc.running) limitReadProc.running = true
    }

    property Process limitReadProc: Process {
        id: limitReadProc
        running: false
        // Both files are optional and independent - some firmware exposes only
        // the end threshold. Missing reads back as an empty line, not an error.
        command: ["sh", "-c",
            "d=" + root.sysfsBase + root.batteryName + "; "
            + "cat \"$d/charge_control_end_threshold\" 2>/dev/null || echo; "
            + "cat \"$d/charge_control_start_threshold\" 2>/dev/null || echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = (this.text || "").split("\n")
                let e = parseInt((lines[0] || "").trim())
                let s = parseInt((lines[1] || "").trim())
                root.chargeLimitEnd = isNaN(e) ? -1 : e
                root.chargeLimitStart = isNaN(s) ? -1 : s
            }
        }
    }

    // These sysfs nodes are root-owned 0644 on every distro that isn't running
    // a udev rule for them, so the write goes through pkexec. That prompt is
    // handled by the shell's own polkit agent (see PolkitAgent.qml) rather than
    // a foreign dialog.
    //
    // Writing the start threshold too where the firmware has one: setting only
    // the end value while start sits above it is rejected by some drivers, so
    // keep start a sensible distance below.
    function setChargeLimit(endPct) {
        if (!root.chargeLimitSupported) return
        let e = Math.max(20, Math.min(100, Math.round(endPct)))

        let script = "d=" + root.sysfsBase + root.batteryName + "; "
        if (root.chargeLimitStart >= 0) {
            let s = Math.max(0, e - 5)
            // Order matters: lowering start first, then end, avoids the
            // transient state where start > end that drivers reject.
            script += "printf '%s' " + s + " > \"$d/charge_control_start_threshold\" 2>/dev/null; "
        }
        script += "printf '%s' " + e + " > \"$d/charge_control_end_threshold\""

        // Try unprivileged first - a udev rule or a distro default may already
        // make these writable, and prompting for a password we don't need is
        // its own kind of bug.
        limitWriteProc.pendingScript = script
        limitWriteProc.escalated = false
        limitWriteProc.command = ["sh", "-c", script]
        limitWriteProc.running = true
    }

    property Process limitWriteProc: Process {
        id: limitWriteProc
        running: false
        property string pendingScript: ""
        property bool escalated: false

        onExited: (exitCode) => {
            if (exitCode !== 0 && !limitWriteProc.escalated) {
                limitWriteProc.escalated = true
                limitWriteProc.command = ["pkexec", "sh", "-c", limitWriteProc.pendingScript]
                limitWriteProc.running = true
                return
            }
            root.refreshChargeLimit()
        }
    }

    // --- CYCLE COUNT ---
    // Not exposed by UPower. Absent or zero on plenty of hardware, in which
    // case the card omits it rather than claiming a brand-new battery.
    property int cycleCount: -1

    function refreshCycleCount() {
        if (!cycleProc.running) cycleProc.running = true
    }

    property Process cycleProc: Process {
        id: cycleProc
        running: false
        command: ["sh", "-c",
            "cat " + root.sysfsBase + root.batteryName + "/cycle_count 2>/dev/null || echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                let c = parseInt((this.text || "").trim())
                root.cycleCount = (isNaN(c) || c <= 0) ? -1 : c
            }
        }
    }

    // Thresholds and cycle count don't change on their own often enough to
    // watch - a refresh when the battery card is opened is plenty, plus one at
    // startup. setChargeLimit() re-reads after its own write.
    function refreshAll() {
        root.resolveBatteryName()
        root.refreshChargeLimit()
        root.refreshCycleCount()
    }

    property Connections deviceConn: Connections {
        target: root
        function onDeviceChanged() { root.refreshAll() }
    }

    Component.onCompleted: root.refreshAll()
}
