import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import ".."

Item {
    id: cardRoot

    Layout.fillWidth: true
    Layout.alignment: Qt.AlignTop

    implicitHeight: 116
    Layout.preferredHeight: 116
    z: panelExpanded ? 1000 : 1

    property Item controlCenterPanel: null
    property bool panelExpanded: false
    property bool shouldExpand: panelExpanded

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    property real sysCpu: 0.0
    // Combined GPU reading for the single collapsed HUD tile - max() of the
    // two GPUs below, so the tile lights up whenever either one is actually
    // busy instead of only ever reflecting the dGPU.
    property real sysGpu: 0.0
    property real sysRam: 0.0
    property real sysDisk: 0.0

    // Split out per-GPU on a hybrid-graphics laptop (Intel iGPU + NVIDIA
    // dGPU) - see gpu_stats.sh's header comment for why nvidia-smi alone
    // (the previous approach) can never see the iGPU, which is what
    // actually decodes video in a browser on this kind of setup.
    property real sysGpuIntel: 0.0
    property real sysGpuNvidia: 0.0
    property int gpuTempIntel: 0
    property int gpuTempNvidia: 0

    property int cpuTemp: 0
    // Combined tile's temp: whichever GPU is currently the busier one, to
    // match sysGpu's own max()-of-the-two semantics.
    property int gpuTemp: 0
    property int ramTemp: 0

    property var lastCpuTotal: 0
    property var lastCpuIdle: 0

    property var diskDrives: []
    property var diskDeviceNames: []
    property real diskReadRate: 0.0
    property real diskWriteRate: 0.0
    property var lastDiskStats: null

    // Rolling history of overall system load, sampled every historyTimer
    // tick, used to drive the scrolling waveform in the expanded view.
    property var loadHistory: []
    readonly property int loadHistoryMax: 40

    function fmtBytes(bytes) {
        if (!bytes || bytes <= 0) return "0 GB"
        let gb = bytes / (1024 * 1024 * 1024)
        return (gb < 10 ? gb.toFixed(1) : Math.round(gb)) + " GB"
    }

    function fmtPowerOn(hours) {
        if (hours === null || hours === undefined) return ""
        let days = hours / 24
        if (days < 365) return Math.round(days) + " days powered on"
        return (days / 365).toFixed(1) + " years powered on"
    }

    // Parses the marker-delimited output of diskDetailProc: an lsblk JSON
    // block (capacity/model/fstype), a df block (used/avail per mountpoint,
    // matched to lsblk partitions by device path), and one ___SMART___ line
    // per physical drive with the raw busctl JSON for its NVMe controller
    // properties (temperature/health/power-on hours - empty for non-NVMe
    // drives since that's the only interface parsed).
    function parseDiskDetails(raw) {
        let lines = raw.split("\n")
        let section = null
        let lsblkLines = [], dfLines = [], smartMap = {}
        for (let i = 0; i < lines.length; i++) {
            let l = lines[i]
            if (l === "___LSBLK___") { section = "lsblk"; continue }
            if (l === "___DF___") { section = "df"; continue }
            if (l.indexOf("___SMART___|") === 0) {
                let rest = l.substring("___SMART___|".length)
                let sep = rest.indexOf("|")
                if (sep === -1) continue
                let devName = rest.substring(0, sep)
                try { smartMap[devName] = JSON.parse(rest.substring(sep + 1)) } catch (e) {}
                continue
            }
            if (section === "lsblk") lsblkLines.push(l)
            else if (section === "df") dfLines.push(l)
        }

        let dfMap = {}
        for (let i = 0; i < dfLines.length; i++) {
            let parts = dfLines[i].trim().split(/\s+/)
            if (parts.length < 4) continue
            if (!(parts[0] in dfMap)) {
                dfMap[parts[0]] = { used: parseInt(parts[1]) || 0, avail: parseInt(parts[2]) || 0 }
            }
        }

        let lsblkData
        try { lsblkData = JSON.parse(lsblkLines.join("\n")) } catch (e) { return }

        let drives = [], names = []
        let devices = lsblkData.blockdevices || []
        for (let i = 0; i < devices.length; i++) {
            let dev = devices[i]
            if (dev.type !== "disk" || !dev.size || dev.size <= 0 || dev.fstype === "swap") continue

            let parts = []
            let children = dev.children || []
            for (let j = 0; j < children.length; j++) {
                let child = children[j]
                let mounts = (child.mountpoints || []).filter(m => m && m !== "[SWAP]")
                if (!child.fstype || mounts.length === 0) continue
                let mount = mounts.indexOf("/") !== -1 ? "/" : mounts[0]
                let usage = dfMap["/dev/" + child.name] || { used: 0, avail: 0 }
                parts.push({
                    name: child.name,
                    fstype: child.fstype,
                    mount: mount,
                    sizeBytes: child.size,
                    usedBytes: usage.used,
                    availBytes: usage.avail
                })
            }

            let tempC = null, health = "", powerOnHours = null
            let smart = smartMap[dev.name]
            if (smart && smart.data && smart.data.length > 0) {
                let props = smart.data[0]
                let d = {}
                for (let key in props) d[key] = props[key].data
                if (d.SmartTemperature !== undefined) tempC = Math.round(d.SmartTemperature - 273.15)
                if (d.SmartPowerOnHours !== undefined) powerOnHours = d.SmartPowerOnHours
                if (d.SmartCriticalWarning && d.SmartCriticalWarning.length > 0) health = "Warning"
                else if (d.SmartSelftestStatus === "success") health = "OK"
                else if (d.SmartSelftestStatus) health = d.SmartSelftestStatus
            }

            drives.push({
                name: dev.name,
                model: dev.model || dev.name,
                sizeBytes: dev.size,
                tempC: tempC,
                health: health,
                powerOnHours: powerOnHours,
                partitions: parts
            })
            names.push(dev.name)
        }

        cardRoot.diskDrives = drives
        cardRoot.diskDeviceNames = names
    }

    property string activeCategory: "CPU"

    ListModel { id: globalProcessModel }
    ListModel { id: filteredProcessModel }

    onActiveCategoryChanged: {
        updateFilteredModel()
        if (activeCategory === "DISK" && panelExpanded && !diskDetailProc.running) {
            diskDetailProc.running = true
        }
    }

    // Compound (PID + Category) in-place model synchronizer
    function syncModelInPlace(targetModel, newItems) {
        // 1. Remove stale entries
        for (let i = targetModel.count - 1; i >= 0; i--) {
            let entry = targetModel.get(i)
            let match = newItems.find(item => item.pid === entry.pid && item.category === entry.category)
            if (!match) {
                targetModel.remove(i)
            }
        }

        // 2. Update existing entries or append new ones
        for (let j = 0; j < newItems.length; j++) {
            let incoming = newItems[j]
            let foundIdx = -1
            for (let k = 0; k < targetModel.count; k++) {
                let existing = targetModel.get(k)
                if (existing.pid === incoming.pid && existing.category === incoming.category) {
                    foundIdx = k
                    break
                }
            }

            if (foundIdx !== -1) {
                let existing = targetModel.get(foundIdx)
                if (existing.metric !== incoming.metric) targetModel.setProperty(foundIdx, "metric", incoming.metric)
                if (existing.name !== incoming.name) targetModel.setProperty(foundIdx, "name", incoming.name)
            } else {
                targetModel.append(incoming)
            }
        }
    }

    function updateFilteredModel() {
        let subset = []
        for (let i = 0; i < globalProcessModel.count; i++) {
            let item = globalProcessModel.get(i)
            if (item.category === cardRoot.activeCategory) {
                subset.push({
                    "category": item.category,
                    "metric": item.metric,
                    "name": item.name,
                    "pid": item.pid
                })
            }
        }
        syncModelInPlace(filteredProcessModel, subset)
    }

    Timer {
        id: refreshTimer
        interval: 2000
        running: cardRoot.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: { 
            cpuStatReader.reload()
            memInfoReader.reload()
            
            // Collect GPU, Disk, and Temp
            if (!diskGpuProc.running) {
                diskGpuProc.running = true
            }
            
            // Only query top processes when the card is actively opened
            if (cardRoot.panelExpanded && !processListView.isHoveringRow && !allProcessesFetcher.running) {
                allProcessesFetcher.running = true
            }

            // Same idea for disk details/throughput - only worth polling
            // while the DISK panel is actually the one open.
            if (cardRoot.panelExpanded && cardRoot.activeCategory === "DISK") {
                diskStatsReader.reload()
                if (!diskDetailProc.running) diskDetailProc.running = true
            }
        }
    }

    Timer {
        id: historyTimer
        interval: 2000
        running: cardRoot.visible
        repeat: true
        onTriggered: {
            let avg = (cardRoot.sysCpu + cardRoot.sysGpu + cardRoot.sysRam) / 3
            let hist = cardRoot.loadHistory.slice()
            hist.push(avg)
            if (hist.length > cardRoot.loadHistoryMax) hist.shift()
            cardRoot.loadHistory = hist
        }
    }

    property bool processListVisible: false

    // Fallback only - normally the process list reveals itself the instant
    // its data actually lands (see processCollector.onStreamFinished), not
    // on a fixed clock. A flat timer here would flip the list visible
    // before the fetch finishes on a slow tick, showing an empty list that
    // then jumps to ~40 rows a moment later - that pop was the flicker.
    Timer {
        id: processListFadeTimer
        interval: 600
        repeat: false
        onTriggered: {
            if (cardRoot.panelExpanded) {
                cardRoot.processListVisible = true
            }
        }
    }

    onPanelExpandedChanged: {
        if (panelExpanded) {
            processListFadeTimer.restart()
            if (!allProcessesFetcher.running) {
                allProcessesFetcher.running = true
            }
            if (cardRoot.activeCategory === "DISK" && !diskDetailProc.running) {
                diskDetailProc.running = true
            }
        } else {
            processListFadeTimer.stop()
            processListVisible = false
        }
    }

    FileView {
        id: memInfoReader
        path: "/proc/meminfo"
        onTextChanged: {
            let lines = text().split('\n'), total = 0, avail = 0
            for (let i = 0; i < lines.length; i++) {
                if (lines[i].startsWith("MemTotal:")) total = parseInt(lines[i].replace(/\D/g, ''))
                if (lines[i].startsWith("MemAvailable:")) avail = parseInt(lines[i].replace(/\D/g, ''))
            }
            if (total > 0) cardRoot.sysRam = (total - avail) / total
        }
    }

    FileView {
        id: cpuStatReader
        path: "/proc/stat"
        onTextChanged: {
            let parts = text().split('\n')[0].split(/\s+/).filter(Boolean)
            if (parts.length >= 5) {
                let user = parseInt(parts[1])||0, nice = parseInt(parts[2])||0, sys = parseInt(parts[3])||0, idle = parseInt(parts[4])||0, io = parseInt(parts[5])||0, irq = parseInt(parts[6])||0, soft = parseInt(parts[7])||0, steal = parseInt(parts[8])||0
                let total = user + nice + sys + idle + io + irq + soft + steal
                let idleTotal = idle + io
                let totalDelta = total - cardRoot.lastCpuTotal
                let idleDelta = idleTotal - cardRoot.lastCpuIdle
                if (totalDelta > 0) cardRoot.sysCpu = Math.max(0.0, Math.min(1.0, (totalDelta - idleDelta) / totalDelta))
                cardRoot.lastCpuTotal = total; cardRoot.lastCpuIdle = idleTotal
            }
        }
    }

    // See scripts/gpu_stats.sh's header comment for why this is a script
    // rather than an inline fish -c one-liner (the previous approach) -
    // deriving iGPU busy% from /proc/*/fdinfo needs real per-process
    // dedup logic that isn't reasonable to inline, and the CPU-temp lookup
    // needs to match coretemp by name rather than trust hwmon enumeration
    // order.
    Process {
        id: diskGpuProc
        // Config.scriptsDir is shellDir with the file:// prefix already stripped,
        // so this stays a plain filesystem path Process can exec while still
        // following the checkout wherever it actually lives.
        command: [Config.scriptsDir + "/gpu_stats.sh"]
        running: false
        stdout: StdioCollector {
            id: diskGpuCollector
            onStreamFinished: {
                let raw = diskGpuCollector.text ? diskGpuCollector.text.trim() : ""
                if (!raw) return

                let lines = raw.split("\n").map(l => l.trim())
                if (lines.length < 5) return

                let nvidiaUtil = parseFloat(lines[0]) || 0.0
                let rawDisk = parseFloat(lines[1]) || 0.0
                let cpuT = parseFloat(lines[2]) || 0
                let nvidiaT = parseFloat(lines[3]) || 0
                // Already a finished percent, computed in the script from
                // its own persisted per-client state - see its header
                // comment for why that delta math has to live there
                // rather than here (it needs a baseline per GPU client,
                // not just one prior sample of a single combined number).
                let intelPct = parseFloat(lines[4]) || 0.0

                cardRoot.sysDisk = rawDisk / 100.0
                cardRoot.cpuTemp = Math.round(cpuT)
                cardRoot.sysGpuNvidia = Math.max(0, Math.min(100, nvidiaUtil)) / 100.0
                cardRoot.gpuTempNvidia = Math.round(nvidiaT)
                cardRoot.sysGpuIntel = Math.max(0, Math.min(100, intelPct)) / 100.0
                // No dedicated Intel iGPU thermal sensor exists on this
                // kind of client hardware (confirmed empirically - there's
                // no i915 hwmon device at all) - the iGPU shares the CPU's
                // die/package, so its package temp is the closest real
                // reading available rather than showing a fabricated 0.
                cardRoot.gpuTempIntel = cardRoot.cpuTemp

                cardRoot.sysGpu = Math.max(cardRoot.sysGpuIntel, cardRoot.sysGpuNvidia)
                cardRoot.gpuTemp = cardRoot.sysGpuIntel >= cardRoot.sysGpuNvidia ? cardRoot.gpuTempIntel : cardRoot.gpuTempNvidia

                diskGpuProc.running = false
            }
        }
    }

    Process {
        id: allProcessesFetcher
        command: [
            "/bin/fish", "-c",
            "echo '___CAT___|CPU'; " +
            "ps -eo pid,pcpu,comm --sort=-pcpu | head -n 41 | tail -n +2 | awk -v cores=(nproc) '{print $1\"|\"$2/cores\"|\"$3}'; " +
            "echo '___CAT___|GPU'; " +
            "set -l g_devs (find /dev/dri -maxdepth 1 -name 'renderD*' 2>/dev/null); " +
            "set -l g_pids; " +
            "if test (count $g_devs) -gt 0; " +
                "set g_pids (fuser $g_devs 2>/dev/null | string match -ra '\\d+' | sort -u); " +
            "end; " +
            "if test (count $g_pids) -gt 0; " +
                "ps -p (string join ',' $g_pids) -o pid,pmem,comm --sort=-pmem 2>/dev/null | head -n 41 | tail -n +2 | awk '{print $1\"|\"$2\"%|\"$3}'; " +
            "else if test -e /dev/nvidiactl; and command -q nvidia-smi; " +
                "nvidia-smi --query-compute-apps=pid,used_memory,process_name --format=csv,noheader,nounits 2>/dev/null | awk -F', ' '{print $1\"|\"$2\" MB|\"$3}'; " +
            "end; " +
            "echo '___CAT___|RAM'; " +
            "ps -eo pid,pmem,comm --sort=-pmem | head -n 41 | tail -n +2 | awk '{print $1\"|\"$2\"|\"$3}'"
        ]
        running: false
        stdout: StdioCollector {
            id: processCollector
            onStreamFinished: {
                let raw = processCollector.text ? processCollector.text.trim() : ""
                if (!raw) return
                let parsedItems = []
                let currentCat = "CPU"
                let lines = raw.split("\n")
                
                for (let i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue
                    let parts = lines[i].split("|")
                    
                    if (parts[0] === "___CAT___") {
                        currentCat = parts[1]
                    } else if (parts.length === 3) {
                        let metricVal = parts[1]
                        
                        if (metricVal.includes("%")) {
                            let val = parseFloat(metricVal.replace("%", "")) || 0.0
                            let clamped = val > 100 ? 100 : val
                            metricVal = (clamped < 1.0) ? clamped.toFixed(1) + "%" : Math.round(clamped) + "%"
                        } else if (!metricVal.includes("MB")) {
                            let val = parseFloat(metricVal) || 0.0
                            let clamped = val > 100 ? 100 : val
                            metricVal = (clamped < 1.0) ? clamped.toFixed(1) + "%" : Math.round(clamped) + "%"
                        }
                        
                        parsedItems.push({
                            "category": currentCat,
                            "metric": metricVal,
                            "name": parts[2],
                            "pid": parts[0]
                        })
                    }
                }

                syncModelInPlace(globalProcessModel, parsedItems)
                cardRoot.updateFilteredModel()

                // Reveal only once there's actually something to show -
                // the model is already populated by this point, so the
                // list fades in with its rows instead of fading in empty
                // and then jumping as they land.
                if (cardRoot.panelExpanded) {
                    processListFadeTimer.stop()
                    cardRoot.processListVisible = true
                }
            }
        }
    }

    Process {
        id: killerProc
        running: false
    }

    // Capacity/model/health come from lsblk, df, and the disk-management
    // daemon (busctl/jq talking to the same service `udisksctl` uses) -
    // no smartmontools install or sudo rule needed. Only NVMe controller
    // properties are queried for temperature/health; a non-NVMe drive just
    // shows capacity with no temp/health line.
    Process {
        id: diskDetailProc
        command: [
            "fish", "-c",
            "echo '___LSBLK___'; " +
            "lsblk -b -J -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL; " +
            "echo '___DF___'; " +
            "df -B1 --output=source,used,avail,target | grep '^/dev/'; " +
            "for dev in (lsblk -b -n -o NAME,TYPE,SIZE | awk '$2==\"disk\" && $3>0 && $1 !~ /^(zram|loop)/ {print $1}'); " +
                "set -l drivepath (busctl call org.freedesktop.UDisks2 /org/freedesktop/UDisks2/block_devices/$dev org.freedesktop.DBus.Properties Get ss org.freedesktop.UDisks2.Block Drive --json=short 2>/dev/null | jq -r '.data[0].data' 2>/dev/null); " +
                "if test -n \"$drivepath\" -a \"$drivepath\" != \"/\"; " +
                    "set -l smart (busctl call org.freedesktop.UDisks2 \"$drivepath\" org.freedesktop.DBus.Properties GetAll s org.freedesktop.UDisks2.NVMe.Controller --json=short 2>/dev/null); " +
                    "test -n \"$smart\"; and echo \"___SMART___|$dev|$smart\"; " +
                "end; " +
            "end"
        ]
        running: false
        stdout: StdioCollector {
            id: diskDetailCollector
            onStreamFinished: {
                let raw = diskDetailCollector.text ? diskDetailCollector.text.trim() : ""
                diskDetailProc.running = false
                if (!raw) return
                cardRoot.parseDiskDetails(raw)
            }
        }
    }

    FileView {
        id: diskStatsReader
        path: "/proc/diskstats"
        onTextChanged: {
            if (cardRoot.diskDeviceNames.length === 0) return
            let lines = text().split('\n')
            let totalRead = 0, totalWrite = 0
            for (let i = 0; i < lines.length; i++) {
                let parts = lines[i].trim().split(/\s+/)
                if (parts.length < 10) continue
                if (cardRoot.diskDeviceNames.indexOf(parts[2]) === -1) continue
                totalRead += parseInt(parts[5]) || 0
                totalWrite += parseInt(parts[9]) || 0
            }
            if (cardRoot.lastDiskStats) {
                let elapsedSec = refreshTimer.interval / 1000
                let deltaReadMB = (totalRead - cardRoot.lastDiskStats.r) * 512 / 1e6
                let deltaWriteMB = (totalWrite - cardRoot.lastDiskStats.w) * 512 / 1e6
                cardRoot.diskReadRate = Math.max(0, deltaReadMB / elapsedSec)
                cardRoot.diskWriteRate = Math.max(0, deltaWriteMB / elapsedSec)
            }
            cardRoot.lastDiskStats = { r: totalRead, w: totalWrite }
        }
    }

    // A HUD-style readout for one metric: a glowing vertical channel meter
    // in the collapsed strip (like an equalizer cell), a glowing horizontal
    // bar in the expanded readout. Same identity (icon/label/color) in both,
    // just laid out differently.
    component HudMeter : Item {
        id: meterRoot

        // compact: vertical channel meter (collapsed strip).
        // !compact: horizontal bar (expanded readout).
        property bool compact: true

        readonly property real channelWidth: 40
        readonly property real channelHeight: 56

        property string label: ""
        property real value: 0.0
        property int temp: 0
        property bool clickable: true
        property bool selected: cardRoot.activeCategory === meterRoot.label

        readonly property bool isOverheating: meterRoot.temp > 75
        readonly property color liveColor: (meterRoot.isOverheating || meterRoot.value > 0.85) ? "#f97316" : Config.accent

        // An icon that actually means something for each metric.
        readonly property string glyph: (meterRoot.label === "GPU" || meterRoot.label === "iGPU" || meterRoot.label === "dGPU") ? "monitor"
            : (meterRoot.label === "RAM" ? "sd_card"
            : (meterRoot.label === "DISK" ? "storage" : "memory"))

        implicitWidth: meterRoot.compact ? channelWidth : 260
        implicitHeight: meterRoot.compact ? (channelHeight + 5 + vLabels.implicitHeight) : 32
        width: implicitWidth
        height: implicitHeight

        // ---------------- collapsed: vertical channel meter ----------------
        Column {
            id: vChannel
            visible: meterRoot.compact
            // Pinned to channelWidth rather than left to auto-size: a Column
            // sizes itself to its widest child (the label row, once it grows
            // past 40px for a two-digit temp), which then left-aligns the
            // narrower icon tile inside that wider box instead of centering
            // it - the tile and the label text were centering on two
            // different axes. Fixing the width to channelWidth gives both
            // children the same axis to center against.
            width: meterRoot.channelWidth
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 5

            Item {
                id: vTrack
                width: meterRoot.channelWidth
                height: meterRoot.channelHeight

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.35)
                }

                Text {
                    anchors.centerIn: parent
                    text: meterRoot.glyph
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: vTrack.width * 0.55
                    color: Qt.rgba(255, 255, 255, 0.12)
                }

                Rectangle {
                    id: vFill
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    radius: 8
                    height: Math.max(4, vTrack.height * meterRoot.value)
                    Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Qt.rgba(meterRoot.liveColor.r, meterRoot.liveColor.g, meterRoot.liveColor.b, 0.9) }
                        GradientStop { position: 1.0; color: Qt.rgba(meterRoot.liveColor.r, meterRoot.liveColor.g, meterRoot.liveColor.b, 0.35) }
                    }

                    Rectangle {
                        id: vCap
                        anchors.top: parent.top
                        width: parent.width
                        height: 3
                        radius: 2
                        color: meterRoot.liveColor
                    }
                    Glow {
                        anchors.fill: vCap
                        source: vCap
                        radius: 6
                        samples: 12
                        color: meterRoot.liveColor
                        spread: 0.4
                        transparentBorder: true
                    }
                }

                HoverHandler {
                    enabled: meterRoot.clickable
                    cursorShape: Qt.PointingHandCursor
                }
            }

            Column {
                id: vLabels
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: meterRoot.label
                    color: meterRoot.clickable && meterRoot.selected ? Config.textMain : Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.bold: true
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    Text {
                        // Fixed width (not auto-sized) so every tile's Row
                        // is the same total width regardless of how many
                        // digits its own value/temp happen to have this
                        // tick - without it, e.g. a 1-digit "3%" next to a
                        // 2-digit "66°C" made this Row narrower than a
                        // neighboring tile showing "12%" next to a
                        // 0-width-reserved temp, so each tile centered to a
                        // different total width and the "%" digits drifted
                        // out of column across tiles instead of lining up.
                        width: 26
                        horizontalAlignment: Text.AlignRight
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(meterRoot.value * 100) + "%"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontSubhead)
                        font.bold: true
                    }
                    Text {
                        // opacity (not visible) so this always reserves its
                        // space - a meter with no temp reading (RAM/DISK)
                        // otherwise ends up a row shorter than CPU/GPU and,
                        // once vertically centered against them, its icon
                        // tile sits visibly lower than theirs.
                        opacity: meterRoot.temp > 0 ? 1 : 0
                        width: 30
                        horizontalAlignment: Text.AlignLeft
                        anchors.verticalCenter: parent.verticalCenter
                        text: (meterRoot.temp > 0 ? meterRoot.temp : 0) + "°C"
                        color: meterRoot.isOverheating ? "#f97316" : Config.accent
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }
                }
            }
        }

        // ---------------- expanded: horizontal HUD bar ----------------
        RowLayout {
            id: hBar
            visible: !meterRoot.compact
            anchors.fill: parent
            spacing: 10

            Text {
                text: meterRoot.glyph
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: meterRoot.clickable && meterRoot.selected ? meterRoot.liveColor : Config.textMuted
                Layout.preferredWidth: 22
            }

            Text {
                text: meterRoot.label
                color: meterRoot.clickable && meterRoot.selected ? Config.textMain : Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
                Layout.preferredWidth: 40
            }

            Item {
                id: hTrack
                Layout.fillWidth: true
                Layout.preferredHeight: 10

                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: Qt.rgba(0, 0, 0, 0.35)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                }

                Rectangle {
                    id: hFill
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 4
                    radius: 4
                    width: Math.max(6, (hTrack.width - 4) * meterRoot.value)
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(meterRoot.liveColor.r, meterRoot.liveColor.g, meterRoot.liveColor.b, 0.35) }
                        GradientStop { position: 1.0; color: Qt.rgba(meterRoot.liveColor.r, meterRoot.liveColor.g, meterRoot.liveColor.b, 0.95) }
                    }

                    Rectangle {
                        id: hCap
                        anchors.right: parent.right
                        height: parent.height
                        width: 3
                        radius: 2
                        color: meterRoot.liveColor
                    }
                    Glow {
                        anchors.fill: hCap
                        source: hCap
                        radius: 6
                        samples: 12
                        color: meterRoot.liveColor
                        spread: 0.4
                        transparentBorder: true
                    }
                }

                HoverHandler {
                    enabled: meterRoot.clickable
                    cursorShape: Qt.PointingHandCursor
                }
            }

            Text {
                text: Math.round(meterRoot.value * 100) + "%"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontSubhead)
                font.bold: true
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
            }

            Text {
                // opacity (not visible) so DISK - which never has a temp -
                // still reserves this column's width, keeping all four bars'
                // percentage readouts lined up in the same place.
                opacity: meterRoot.temp > 0 ? 1 : 0
                text: (meterRoot.temp > 0 ? meterRoot.temp : 0) + "°C"
                color: meterRoot.isOverheating ? "#f97316" : Config.accent
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.bold: true
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignRight
            }
        }

        TapHandler {
            enabled: meterRoot.clickable
            onTapped: {
                if (meterRoot.clickable) {
                    cardRoot.activeCategory = meterRoot.label
                    if (!cardRoot.panelExpanded) {
                        cardRoot.panelExpanded = true
                    }
                }
            }
        }
    }

    readonly property real collapsedX: {
        let sum = 0
        let p = cardRoot
        while (p && p !== controlCenterPanel) {
            sum += p.x
            p = p.parent
        }
        return sum
    }

    readonly property real collapsedY: {
        let sum = 0
        let p = cardRoot
        while (p && p !== controlCenterPanel) {
            sum += p.y
            p = p.parent
        }
        return sum
    }

    // ClippingRectangle (not plain Rectangle) so the watermark actually
    // respects the rounded corners instead of bleeding past them - plain
    // Rectangle.clip only clips to the square bounding box.
    ClippingRectangle {
        id: visualBackground
        parent: controlCenterPanel ? controlCenterPanel : cardRoot.parent
        z: cardRoot.panelExpanded ? 1000 : 100

        x: cardRoot.panelExpanded ? cardRoot.cardMargin : cardRoot.collapsedX
        y: cardRoot.panelExpanded ? cardRoot.cardMargin : cardRoot.collapsedY
        width: cardRoot.panelExpanded ? (controlCenterPanel ? (controlCenterPanel.width - (cardRoot.cardMargin * 2)) : 400) : cardRoot.width
        height: cardRoot.panelExpanded ? (controlCenterPanel ? (controlCenterPanel.height - (cardRoot.cardMargin * 2)) : 500) : cardRoot.height
        
        radius: Config.cornerRadius
        
        color: cardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.1)

        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Rectangle {
            anchors.fill: parent
            // ClippingRectangle's default property forwards children to an
            // inner plain Item (contentItem), so `parent` here is that Item,
            // not visualBackground - parent.radius was silently undefined.
            radius: visualBackground.radius
            color: Qt.rgba(Config.bgBase.r, Config.bgBase.g, Config.bgBase.b, 1.0)
            visible: opacity > 0
            opacity: cardRoot.panelExpanded ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }

        HoverHandler {
            id: cardHover
            enabled: !cardRoot.panelExpanded
        }

        MouseArea {
            anchors.fill: parent
            enabled: cardRoot.panelExpanded
            preventStealing: true
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onPressed: (mouse) => mouse.accepted = true
            onReleased: (mouse) => mouse.accepted = true
            onClicked: (mouse) => mouse.accepted = true
        }

        TapHandler {
            enabled: cardRoot.panelExpanded
            gesturePolicy: TapHandler.WithinBounds
            onTapped: {}
        }

        TapHandler {
            enabled: !cardRoot.panelExpanded
            onTapped: cardRoot.panelExpanded = true
        }

        Watermark {
            icon: "analytics"
            iconSize: 150
            activeVisible: !cardRoot.panelExpanded
            seed: 3
        }

        // A faint highlight that sweeps across the top edge on a loop while
        // open, like a radar/scan pass - reinforces "live" without being a
        // distraction (it pauses between sweeps rather than looping tight).
        Rectangle {
            id: scanLine
            visible: cardRoot.panelExpanded
            y: 0
            width: 90
            height: 2
            z: 1001

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0) }
                GradientStop { position: 0.5; color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.6) }
                GradientStop { position: 1.0; color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0) }
            }

            SequentialAnimation {
                running: cardRoot.panelExpanded
                loops: Animation.Infinite
                NumberAnimation { target: scanLine; property: "x"; from: -scanLine.width; to: visualBackground.width; duration: 3200; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 900 }
                NumberAnimation { target: scanLine; property: "x"; to: -scanLine.width; duration: 0 }
            }
        }

        // ==========================================
        // COLLAPSED CARD CONTENT (FOUR ENLARGED RINGS)
        // ==========================================
        Item {
            id: collapsedView
            anchors.fill: parent
            visible: opacity > 0
            enabled: !cardRoot.panelExpanded
            opacity: cardRoot.panelExpanded ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 0

                Item { Layout.fillWidth: true }
                HudMeter { Layout.alignment: Qt.AlignVCenter; label: "CPU"; value: cardRoot.sysCpu; temp: cardRoot.cpuTemp }
                Item { Layout.fillWidth: true }
                HudMeter { Layout.alignment: Qt.AlignVCenter; label: "GPU"; value: cardRoot.sysGpu; temp: cardRoot.gpuTemp }
                Item { Layout.fillWidth: true }
                HudMeter { Layout.alignment: Qt.AlignVCenter; label: "RAM"; value: cardRoot.sysRam; temp: cardRoot.ramTemp }
                Item { Layout.fillWidth: true }
                HudMeter { Layout.alignment: Qt.AlignVCenter; label: "DISK"; value: cardRoot.sysDisk }
                Item { Layout.fillWidth: true }
            }
        }

        // ==========================================
        // EXPANDED CARD CONTENT (FULL SYSTEM MONITOR)
        // ==========================================
        Item {
            id: expandedView
            anchors.fill: parent
            anchors.margins: cardRoot.cardMargin
            
            visible: opacity > 0
            enabled: cardRoot.panelExpanded
            opacity: cardRoot.panelExpanded ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        implicitWidth: 32; implicitHeight: 32; radius: Config.cornerRadius / 2
                        color: backBtnHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "arrow_back"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                            color: Config.textMain
                        }

                        TapHandler { onTapped: cardRoot.panelExpanded = false }
                        HoverHandler { id: backBtnHover; cursorShape: Qt.PointingHandCursor }
                    }

                    Item {
                        implicitWidth: sysExpTitleText.implicitWidth
                        implicitHeight: sysExpTitleText.implicitHeight
                        Layout.fillWidth: true

                        Text {
                            id: sysExpTitleText
                            anchors.fill: parent
                            text: "SYSTEM MONITOR"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontTitle)
                            font.bold: true
                            font.italic: true
                        }

                        Glow {
                            anchors.fill: sysExpTitleText
                            source: sysExpTitleText
                            radius: 6
                            samples: 12
                            color: Config.accent
                            spread: 0.2
                            transparentBorder: true
                            visible: Config.clockShowGlow
                        }
                    }

                    // A small breathing dot to sell "this is a live readout",
                    // not just a static panel.
                    Rectangle {
                        implicitWidth: 6; implicitHeight: 6; radius: 3
                        color: Config.accent
                        Layout.alignment: Qt.AlignVCenter

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.25; to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    // +38 over the original 210 to fit the new iGPU/dGPU
                    // row (32 tall + 6 spacing) without shrinking the load
                    // graph below it, which has Layout.fillHeight and would
                    // otherwise silently absorb the difference.
                    implicitHeight: 248
                    color: Qt.rgba(0, 0, 0, 0.15)
                    radius: Config.cornerRadius / 1.5

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        HudMeter { Layout.fillWidth: true; compact: false; label: "CPU"; value: cardRoot.sysCpu; temp: cardRoot.cpuTemp }
                        // Split from the single collapsed-tile "GPU" reading
                        // into the two real GPUs on a hybrid-graphics laptop
                        // - the expanded panel has the horizontal room the
                        // collapsed strip doesn't, so this is where the
                        // breakdown actually lives (see sysGpuIntel's own
                        // comment for why nvidia-smi alone can't see the
                        // iGPU that browser video decode actually runs on).
                        // Not clickable - there's no "iGPU"/"dGPU" process
                        // category (only CPU/GPU/RAM exist below), so these
                        // would otherwise switch to an empty process list.
                        HudMeter { Layout.fillWidth: true; compact: false; label: "iGPU"; value: cardRoot.sysGpuIntel; temp: cardRoot.gpuTempIntel; clickable: false }
                        HudMeter { Layout.fillWidth: true; compact: false; label: "dGPU"; value: cardRoot.sysGpuNvidia; temp: cardRoot.gpuTempNvidia; clickable: false }
                        HudMeter { Layout.fillWidth: true; compact: false; label: "RAM"; value: cardRoot.sysRam; temp: cardRoot.ramTemp }
                        HudMeter { Layout.fillWidth: true; compact: false; label: "DISK"; value: cardRoot.sysDisk }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            implicitHeight: 1
                            color: Qt.rgba(255, 255, 255, 0.08)
                        }

                        Text {
                            text: "SYSTEM LOAD"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                        }

                        // A scrolling waveform of overall load (avg of CPU/GPU/RAM
                        // over the last ~80s), built the same way as the old
                        // shape-tile path: a Catmull-Rom-smoothed SVG path
                        // sampled from raw points, so new samples ease the line
                        // in instead of popping.
                        //
                        // Wrapped in a plain Item (not itself Layout-managed
                        // beyond fillWidth/fillHeight) so the Glow below can
                        // anchor to the Shape without fighting ColumnLayout,
                        // which forbids anchors on its direct children.
                        Item {
                            id: loadGraphSlot
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Shape {
                                id: loadGraph
                                anchors.fill: parent
                                antialiasing: true
                                preferredRendererType: Shape.CurveRenderer

                                function graphPath() {
                                    let hist = cardRoot.loadHistory
                                    if (hist.length < 2) return ""
                                    let w = loadGraph.width, h = loadGraph.height
                                    let n = hist.length
                                    let stepX = w / (cardRoot.loadHistoryMax - 1)
                                    let startX = w - (n - 1) * stepX
                                    let pts = []
                                    for (let i = 0; i < n; i++) {
                                        let x = startX + i * stepX
                                        let y = h - 3 - hist[i] * (h - 6)
                                        pts.push(Qt.point(x, y))
                                    }

                                    let d = "M " + pts[0].x.toFixed(2) + " " + pts[0].y.toFixed(2) + " "
                                    for (let j = 0; j < pts.length - 1; j++) {
                                        let p0 = pts[Math.max(0, j - 1)]
                                        let p1 = pts[j]
                                        let p2 = pts[j + 1]
                                        let p3 = pts[Math.min(pts.length - 1, j + 2)]
                                        let b1x = p1.x + (p2.x - p0.x) / 6
                                        let b1y = p1.y + (p2.y - p0.y) / 6
                                        let b2x = p2.x - (p3.x - p1.x) / 6
                                        let b2y = p2.y - (p3.y - p1.y) / 6
                                        d += "C " + b1x.toFixed(2) + " " + b1y.toFixed(2) + " " + b2x.toFixed(2) + " " + b2y.toFixed(2) + " " + p2.x.toFixed(2) + " " + p2.y.toFixed(2) + " "
                                    }
                                    return d
                                }

                                ShapePath {
                                    strokeColor: Config.accent
                                    strokeWidth: 2
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin
                                    PathSvg { path: loadGraph.graphPath() }
                                }
                            }
                            Glow {
                                anchors.fill: loadGraph
                                source: loadGraph
                                radius: 8
                                samples: 16
                                color: Config.accent
                                spread: 0.25
                                transparentBorder: true
                            }
                        }
                    }
                }

                Rectangle {
                    id: processSectionContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Qt.rgba(0, 0, 0, 0.15)
                    radius: Config.cornerRadius / 1.5
                    clip: true
                    // Deliberately no `visible: opacity > 0` here - while
                    // invisible this stays a sibling under a ColumnLayout, and
                    // an invisible child is dropped from layout entirely,
                    // which let the header/icon row above re-center into its
                    // reserved space and then snap back up once it reappears.
                    // Staying visible (just transparent) keeps its
                    // Layout.fillHeight space reserved the whole time.
                    opacity: (cardRoot.panelExpanded && cardRoot.processListVisible) ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: cardRoot.activeCategory === "DISK" ? "DISK DETAILS" : (cardRoot.activeCategory + " PROCESSES")
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: true
                                Layout.fillWidth: true
                            }
                        }

                        ListView {
                            id: processListView
                            visible: cardRoot.activeCategory !== "DISK"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            model: filteredProcessModel
                            boundsBehavior: Flickable.StopAtBounds

                            property bool isHoveringRow: false

                            WheelHandler {
                                id: processWheelHandler
                                onWheel: (event) => {
                                    let delta = event.angleDelta.y
                                    let maxScroll = Math.max(0, processListView.contentHeight - processListView.height)
                                    processListView.contentY = Math.max(0, Math.min(maxScroll, processListView.contentY - delta))
                                }
                            }

                            delegate: Rectangle {
                                id: rowDelegate
                                width: processListView.width
                                height: 28
                                color: deleteMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2)
                                radius: 4

                                Behavior on color { ColorAnimation { duration: 150 } }

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    cursorShape: Qt.ArrowCursor
                                    onContainsMouseChanged: {
                                        processListView.isHoveringRow = containsMouse
                                        if (!containsMouse) {
                                            processNameText.x = 0
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Item {
                                        id: nameContainer
                                        Layout.fillWidth: true
                                        height: parent.height
                                        clip: true

                                        Text {
                                            id: processNameText
                                            text: model.name
                                            color: Config.textMain
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontCaption)
                                            anchors.verticalCenter: parent.verticalCenter
                                            
                                            elide: (rowMouse.containsMouse && scrollAnim.running) ? Text.ElideNone : Text.ElideRight
                                            width: (rowMouse.containsMouse && scrollAnim.running) ? undefined : nameContainer.width

                                            NumberAnimation on x {
                                                id: scrollAnim
                                                running: rowMouse.containsMouse && (processNameText.implicitWidth > nameContainer.width)
                                                from: 0
                                                to: -(processNameText.implicitWidth - nameContainer.width)
                                                duration: Math.max(800, (processNameText.implicitWidth - nameContainer.width) * 15)
                                                loops: Animation.Infinite

                                                onStopped: {
                                                    processNameText.x = 0
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: model.pid !== "0" ? model.pid : ""
                                        color: Config.textMuted
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontMicro)
                                        Layout.preferredWidth: 44
                                        Layout.alignment: Qt.AlignVCenter
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    Text {
                                        text: model.metric
                                        color: Config.textMain
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontCaption)
                                        font.bold: true
                                        Layout.preferredWidth: 50
                                        Layout.alignment: Qt.AlignVCenter
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    Rectangle {
                                        id: deleteBtn
                                        implicitWidth: 20
                                        implicitHeight: 20
                                        radius: Config.cornerRadius / 4
                                        color: deleteMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                                        Layout.alignment: Qt.AlignVCenter

                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            color: deleteMouse.containsMouse ? Config.accent : Config.textMuted
                                            font.family: Config.sysFont
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        TapHandler {
                                            onTapped: {
                                                let targetPid = parseInt(model.pid)
                                                if (targetPid > 0) {
                                                    killerProc.command = ["kill", "-15", targetPid.toString()]
                                                    killerProc.running = true
                                                    allProcessesFetcher.running = true
                                                }
                                            }
                                        }
                                        HoverHandler { id: deleteMouse; cursorShape: Qt.PointingHandCursor }
                                    }
                                }
                            }
                        }

                        Flickable {
                            id: diskDetailFlick
                            visible: cardRoot.activeCategory === "DISK"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            contentHeight: diskDetailColumn.implicitHeight

                            ColumnLayout {
                                id: diskDetailColumn
                                width: diskDetailFlick.width
                                spacing: 12

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: "arrow_downward"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 14
                                        color: Config.accent
                                    }
                                    Text {
                                        text: cardRoot.diskReadRate.toFixed(1) + " MB/s"
                                        color: Config.textMain
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontCaption)
                                        font.bold: true
                                    }
                                    Text {
                                        text: "arrow_upward"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 14
                                        color: Config.accent
                                    }
                                    Text {
                                        text: cardRoot.diskWriteRate.toFixed(1) + " MB/s"
                                        color: Config.textMain
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontCaption)
                                        font.bold: true
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                Repeater {
                                    model: cardRoot.diskDrives

                                    delegate: ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        property var drive: modelData

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Text {
                                                text: drive.model
                                                color: Config.textMain
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontCaption)
                                                font.bold: true
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                visible: drive.tempC !== null
                                                text: drive.tempC + "°C"
                                                color: drive.tempC > 55 ? "#f97316" : Config.accent
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontMicro)
                                                font.bold: true
                                            }
                                            Text {
                                                visible: drive.health !== ""
                                                text: drive.health
                                                color: drive.health === "OK" ? Config.textMuted : "#f97316"
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontMicro)
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            text: cardRoot.fmtBytes(drive.sizeBytes) + (drive.powerOnHours !== null ? "  ·  " + cardRoot.fmtPowerOn(drive.powerOnHours) : "")
                                            color: Config.textMuted
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontMicro)
                                        }

                                        Repeater {
                                            model: drive.partitions

                                            delegate: ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 3
                                                property var part: modelData
                                                readonly property real usedFrac: part.sizeBytes > 0 ? Math.min(1.0, part.usedBytes / part.sizeBytes) : 0

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Text {
                                                        text: part.mount + "  ·  " + part.fstype
                                                        color: Config.textMuted
                                                        font.family: Config.sysFont
                                                        font.pixelSize: Config.size(Config.fontMicro)
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }
                                                    Text {
                                                        text: cardRoot.fmtBytes(part.usedBytes) + " / " + cardRoot.fmtBytes(part.sizeBytes)
                                                        color: Config.textMain
                                                        font.family: Config.sysFont
                                                        font.pixelSize: Config.size(Config.fontMicro)
                                                        font.bold: true
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    implicitHeight: 6
                                                    radius: 3
                                                    color: Qt.rgba(255, 255, 255, 0.08)

                                                    Rectangle {
                                                        width: parent.width * usedFrac
                                                        height: parent.height
                                                        radius: 3
                                                        color: Config.accent
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}