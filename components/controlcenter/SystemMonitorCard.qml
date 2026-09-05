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
    property real sysGpu: 0.0
    property real sysRam: 0.0
    property real sysDisk: 0.0

    property int cpuTemp: 0
    property int gpuTemp: 0
    property int ramTemp: 0

    property var lastCpuTotal: 0
    property var lastCpuIdle: 0

    property string activeCategory: "CPU"

    ListModel { id: globalProcessModel }
    ListModel { id: filteredProcessModel }

    onActiveCategoryChanged: updateFilteredModel()

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

    Process {
        id: diskGpuProc
        command: [
            "fish", "-c",
            "set -l gpu (cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | sort -nr | head -n1 | string trim); " +
            "if test -z \"$gpu\" -a -e /dev/nvidiactl; and command -q nvidia-smi; " +
                "set gpu (nvidia-smi --query-gpu=utilization.gpu,utilization.decoder --format=csv,noheader,nounits 2>/dev/null | awk -F', ' '{print ($1 > $2 ? $1 : $2)}' | head -n1 | string trim); " +
            "end; " +
            "test -n \"$gpu\"; and echo $gpu; or echo 0; " +

            "df / | awk 'NR==2 {print $5}' | sed 's/%//'; " +

            "set -l cpu_t (cat (find /sys/class/hwmon -maxdepth 1 -name 'hwmon*' 2>/dev/null)/temp1_input 2>/dev/null | head -n1); " +
            "test -n \"$cpu_t\"; and math -s0 \"$cpu_t / 1000\"; or echo 0; " +

            "set -l gtemp (cat (find /sys/class/hwmon -maxdepth 1 -name 'hwmon*' 2>/dev/null)/temp1_input 2>/dev/null | head -n1); " +
            "if test -z \"$gtemp\" -a -e /dev/nvidiactl; and command -q nvidia-smi; " +
                "set gtemp (nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 | string trim); " +
                "test -n \"$gtemp\"; and echo $gtemp; or echo 0; " +
            "else; " +
                "test -n \"$gtemp\"; and math -s0 \"$gtemp / 1000\"; or echo 0; " +
            "end; " +
            "echo 0"
        ]
        running: false
        stdout: StdioCollector {
            id: diskGpuCollector
            onStreamFinished: {
                let raw = diskGpuCollector.text ? diskGpuCollector.text.trim() : ""
                if (!raw) return
                
                let lines = raw.split("\n")
                if (lines.length >= 2) {
                    let rawGpu = parseFloat(lines[0].trim()) || 0.0
                    cardRoot.sysGpu = rawGpu / 100.0
                    let rawDisk = parseFloat(lines[1].trim()) || 0.0
                    cardRoot.sysDisk = rawDisk / 100.0
                }
                if (lines.length >= 3) cardRoot.cpuTemp = Math.round(parseFloat(lines[2].trim()) || 0)
                if (lines.length >= 4) cardRoot.gpuTemp = Math.round(parseFloat(lines[3].trim()) || 0)
                if (lines.length >= 5) cardRoot.ramTemp = Math.round(parseFloat(lines[4].trim()) || 0)
                
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

    component StatRingItem : Item {
        id: ringRow

        // compact: stats sit below the tile (small collapsed row).
        // !compact: stats sit to the right of the tile (expanded view).
        property bool compact: true

        // The tile itself shrank so the icon it holds reads bigger relative
        // to it - the icon's own size is unchanged, just less padding around it.
        readonly property real tileSize: 48

        implicitWidth: ringRow.compact ? tileSize : (tileSize + 10 + statRight.implicitWidth)
        implicitHeight: ringRow.compact ? (tileSize + 5 + statBelow.implicitHeight) : tileSize
        width: implicitWidth
        height: implicitHeight

        property string label: ""
        property real value: 0.0
        property int temp: 0
        property bool clickable: true
        property bool selected: cardRoot.activeCategory === ringRow.label

        readonly property bool isOverheating: ringRow.temp > 75

        // Same icon size for all four.
        readonly property real bodyW: 40
        readonly property real bodyH: 40

        // An icon that actually means something for each metric, instead of
        // an arbitrary geometric shape.
        readonly property string shapeGlyph: ringRow.label === "GPU" ? "monitor"
            : (ringRow.label === "RAM" ? "sd_card"
            : (ringRow.label === "DISK" ? "storage" : "memory"))

        // A curated slice of Material 3's shape catalog (m3.material.io/styles/shape) -
        // just the radially-symmetric ones, since those all reduce to the
        // same "lobes + depth + tip sharpness" formula below. The asymmetric
        // ones in the guide (slanted, arch, pill, arrow, fan, clamshell,
        // ghost-ish, bun, pixel circle) have a distinct "this side vs that
        // side" and aren't a function of angle alone, so they need a
        // genuinely different construction and aren't attempted. Square is
        // skipped too - it's already the permanent idle shape, so as a hover
        // target it would be indistinguishable from not hovering at all.
        //
        // amp is how far each shape's minimum radius dips below baseR (its
        // radius is baseR * (1 - amp) at the deepest point of a lobe) - the
        // icon sits fixed at bodyW/bodyH regardless of which shape is active,
        // so anything that dips too far below baseR uncovers the icon's
        // corners (clover/sunny were 0.45/0.6 - roughly half the tile -
        // before being cut for exactly this). Every entry below is kept
        // under ~0.15 for that reason, which is why the spikier ones read as
        // gentle bumps rather than the dramatic points in the reference
        // image - depth had to be sacrificed for containment, so they're
        // told apart by lobe count and tip sharpness (power) instead.
        // phase just rotates the lobes so shapes sharing a lobe count (e.g.
        // puffy vs. puffy diamond) can still look distinct.
        readonly property var shapeDefs: [
            { name: "circle", lobes: 0, amp: 0.0, power: 1 },
            { name: "triangle", lobes: 3, amp: 0.15, power: 8, phase: -Math.PI / 2 },
            { name: "pentagon", lobes: 5, amp: 0.13, power: 7, phase: -Math.PI / 2 },
            { name: "gem", lobes: 6, amp: 0.12, power: 6 },
            { name: "cookie4", lobes: 4, amp: 0.14, power: 2 },
            { name: "cookie6", lobes: 6, amp: 0.14, power: 2 },
            { name: "cookie7", lobes: 7, amp: 0.14, power: 2 },
            { name: "cookie9", lobes: 9, amp: 0.13, power: 2 },
            { name: "cookie12", lobes: 12, amp: 0.12, power: 2 },
            { name: "clover4", lobes: 4, amp: 0.15, power: 1.3 },
            { name: "clover8", lobes: 8, amp: 0.14, power: 1.3 },
            { name: "sunny", lobes: 10, amp: 0.15, power: 4 },
            { name: "verySunny", lobes: 16, amp: 0.14, power: 5 },
            { name: "burst", lobes: 12, amp: 0.15, power: 7 },
            { name: "softBurst", lobes: 10, amp: 0.14, power: 3 },
            { name: "flower", lobes: 6, amp: 0.15, power: 1.8 },
            { name: "puffy", lobes: 4, amp: 0.10, power: 1.2 },
            { name: "puffyDiamond", lobes: 4, amp: 0.13, power: 2, phase: Math.PI / 4 }
        ]
        // Picked once when the tile is created, not re-rolled per hover, so
        // each metric keeps a consistent identity while still differing from
        // its neighbors.
        readonly property int shapeIndex: Math.floor(Math.random() * shapeDefs.length)

        // A small accent-filled tile with a meaningful icon and a gentle
        // shake under heavy load, instead of an abstract gauge.
        //
        // Rounded square at rest, morphing into a random shape from the M3
        // shape catalog on hover. Built as an SVG path sampled from two
        // blended polar radius functions (a superellipse for the square, a
        // lobed radius for the target shape) rather than swapping between two
        // discrete shapes, so the two interpolate into every shape in between
        // as morphT animates instead of just cross-fading. CurveRenderer
        // avoids the faceted/grainy look Shape's default tessellating
        // renderer gives curves at this size.
        Shape {
            id: tileBody
            x: 0
            y: 0
            width: ringRow.tileSize
            height: ringRow.tileSize
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            property real morphT: (ringRow.clickable && tileHover.hovered) ? 1.0 : 0.0
            Behavior on morphT { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            // lobes/amp/power/phase together cover the whole shapeDefs family:
            // amp is how deep the lobes cut in, power sharpens the tips (low =
            // round bumps, high = pointed spikes), lobes is how many of them,
            // phase rotates them.
            function lobedRadius(theta, lobes, amp, power, phase) {
                if (lobes <= 0 || amp <= 0) return 1.0
                var m = Math.pow(Math.abs(Math.cos(lobes * (theta + (phase || 0)) / 2)), power)
                return (1 - amp) + amp * m
            }

            function tilePath() {
                var w = ringRow.tileSize
                var cx = w / 2, cy = w / 2
                var baseR = w / 2 - 2
                var shape = ringRow.shapeDefs[ringRow.shapeIndex]
                var n = 5
                var t = tileBody.morphT
                var samples = Math.max(48, shape.lobes * 8)
                var pts = []
                for (var i = 0; i < samples; i++) {
                    var theta = (i / samples) * Math.PI * 2
                    var c = Math.cos(theta), s = Math.sin(theta)
                    var rSquare = baseR / Math.pow(Math.pow(Math.abs(c), n) + Math.pow(Math.abs(s), n), 1 / n)
                    var rShape = baseR * tileBody.lobedRadius(theta, shape.lobes, shape.amp, shape.power, shape.phase)
                    var r = rSquare * (1 - t) + rShape * t
                    pts.push(Qt.point(cx + r * c, cy + r * s))
                }

                var len = pts.length
                var d = "M " + pts[0].x.toFixed(2) + " " + pts[0].y.toFixed(2) + " "
                for (var j = 0; j < len; j++) {
                    var p0 = pts[(j - 1 + len) % len]
                    var p1 = pts[j]
                    var p2 = pts[(j + 1) % len]
                    var p3 = pts[(j + 2) % len]
                    var b1x = p1.x + (p2.x - p0.x) / 6
                    var b1y = p1.y + (p2.y - p0.y) / 6
                    var b2x = p2.x - (p3.x - p1.x) / 6
                    var b2y = p2.y - (p3.y - p1.y) / 6
                    d += "C " + b1x.toFixed(2) + " " + b1y.toFixed(2) + " " + b2x.toFixed(2) + " " + b2y.toFixed(2) + " " + p2.x.toFixed(2) + " " + p2.y.toFixed(2) + " "
                }
                d += "Z"
                return d
            }

            ShapePath {
                fillColor: Config.accent
                strokeWidth: -1
                PathSvg { path: tileBody.tilePath() }
            }

            HoverHandler {
                id: tileHover
                enabled: ringRow.clickable
                cursorShape: Qt.PointingHandCursor
            }

            Item {
                id: creature
                width: ringRow.bodyW
                height: ringRow.bodyH
                anchors.centerIn: parent

                // Plain Material Symbols shape - circle/square/triangle/star,
                // colored by mood, no face on top.
                Text {
                    id: creatureBody
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: ringRow.shapeGlyph
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: parent.width * 0.8
                    color: Config.bgBase
                }
            }

        }

        // Label + stats live outside the creature entirely now - below it
        // in the small collapsed row, beside it in the expanded view.
        Column {
            id: statBelow
            visible: ringRow.compact
            anchors.top: tileBody.bottom
            anchors.horizontalCenter: tileBody.horizontalCenter
            anchors.topMargin: 5
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ringRow.label
                color: ringRow.clickable && ringRow.selected ? Config.textMain : Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
            }

            // Usage and temperature side by side on one line instead of
            // stacked, so the card doesn't need to grow taller to fit both.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(ringRow.value * 100) + "%"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontSubhead)
                    font.bold: true
                }
                Text {
                    visible: ringRow.temp > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: ringRow.temp + "°C"
                    color: ringRow.isOverheating ? "#f97316" : Config.accent
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                }
            }
        }

        Column {
            id: statRight
            visible: !ringRow.compact
            anchors.left: tileBody.right
            anchors.verticalCenter: tileBody.verticalCenter
            anchors.leftMargin: 10
            spacing: 0

            Text {
                text: ringRow.label
                color: ringRow.clickable && ringRow.selected ? Config.textMain : Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontSubhead)
                font.bold: true
            }
            Row {
                spacing: 5

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(ringRow.value * 100) + "%"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontSubhead)
                    font.bold: true
                }
                Text {
                    visible: ringRow.temp > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: ringRow.temp + "°C"
                    color: ringRow.isOverheating ? "#f97316" : Config.accent
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                }
            }
        }

        TapHandler {
            enabled: ringRow.clickable
            onTapped: {
                if (ringRow.clickable) {
                    cardRoot.activeCategory = ringRow.label
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
                StatRingItem { Layout.alignment: Qt.AlignVCenter; label: "CPU"; value: cardRoot.sysCpu; temp: cardRoot.cpuTemp }
                Item { Layout.fillWidth: true }
                StatRingItem { Layout.alignment: Qt.AlignVCenter; label: "GPU"; value: cardRoot.sysGpu; temp: cardRoot.gpuTemp }
                Item { Layout.fillWidth: true }
                StatRingItem { Layout.alignment: Qt.AlignVCenter; label: "RAM"; value: cardRoot.sysRam; temp: cardRoot.ramTemp }
                Item { Layout.fillWidth: true }
                StatRingItem { Layout.alignment: Qt.AlignVCenter; label: "DISK"; value: cardRoot.sysDisk; clickable: false }
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
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 96
                    color: Qt.rgba(0, 0, 0, 0.15)
                    radius: Config.cornerRadius / 1.5

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 0

                        Item { Layout.fillWidth: true }
                        StatRingItem { Layout.alignment: Qt.AlignVCenter; compact: false; label: "CPU"; value: cardRoot.sysCpu; temp: cardRoot.cpuTemp }
                        Item { Layout.fillWidth: true }
                        StatRingItem { Layout.alignment: Qt.AlignVCenter; compact: false; label: "GPU"; value: cardRoot.sysGpu; temp: cardRoot.gpuTemp }
                        Item { Layout.fillWidth: true }
                        StatRingItem { Layout.alignment: Qt.AlignVCenter; compact: false; label: "RAM"; value: cardRoot.sysRam; temp: cardRoot.ramTemp }
                        Item { Layout.fillWidth: true }
                        StatRingItem { Layout.alignment: Qt.AlignVCenter; compact: false; label: "DISK"; value: cardRoot.sysDisk; clickable: false }
                        Item { Layout.fillWidth: true }
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
                                text: cardRoot.activeCategory + " PROCESSES"
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: true
                                Layout.fillWidth: true
                            }
                        }

                        ListView {
                            id: processListView
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
                    }
                }
            }
        }
    }
}