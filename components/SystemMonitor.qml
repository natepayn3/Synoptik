import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: sysRoot

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    implicitWidth: mainLayout.implicitWidth + (cardMargin * 2)
    implicitHeight: mainLayout.implicitHeight + (cardMargin * 2)

    property real sysCpu: 0.0
    property real sysGpu: 0.0
    property real sysRam: 0.0
    property real sysDisk: 0.0

    // Temperature properties (in °C)
    property int cpuTemp: 0
    property int gpuTemp: 0
    property int ramTemp: 0

    property var lastCpuTotal: 0
    property var lastCpuIdle: 0

    property string activeCategory: "CPU"

    ListModel {
        id: globalProcessModel
    }

    ListModel {
        id: filteredProcessModel
    }

    onActiveCategoryChanged: updateFilteredModel()

    function updateFilteredModel() {
        filteredProcessModel.clear();
        for (let i = 0; i < globalProcessModel.count; i++) {
            let item = globalProcessModel.get(i);
            if (item.category === sysRoot.activeCategory) {
                filteredProcessModel.append(item);
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 3000
        running: Config.showSystemMonitor
        repeat: true
        triggeredOnStart: true
        onTriggered: { 
            cpuStatReader.reload()
            memInfoReader.reload()
            if (!diskGpuProc.running) diskGpuProc.running = true 
            
            // Fetch process list if user isn't hovering a row
            if (!processListView.isHoveringRow && !allProcessesFetcher.running) {
                allProcessesFetcher.running = true
            }
        }
    }

    FileView {
        id: memInfoReader
        path: "/proc/meminfo"
        onTextChanged: {
            let lines = text().split('\n'), total = 0, avail = 0;
            for (let i = 0; i < lines.length; i++) {
                if (lines[i].startsWith("MemTotal:")) total = parseInt(lines[i].replace(/\D/g, ''));
                if (lines[i].startsWith("MemAvailable:")) avail = parseInt(lines[i].replace(/\D/g, ''));
            }
            if (total > 0) sysRoot.sysRam = (total - avail) / total;
        }
    }

    FileView {
        id: cpuStatReader
        path: "/proc/stat"
        onTextChanged: {
            let parts = text().split('\n')[0].split(/\s+/).filter(Boolean);
            if (parts.length >= 5) {
                let user = parseInt(parts[1])||0, nice = parseInt(parts[2])||0, sys = parseInt(parts[3])||0, idle = parseInt(parts[4])||0, io = parseInt(parts[5])||0, irq = parseInt(parts[6])||0, soft = parseInt(parts[7])||0, steal = parseInt(parts[8])||0;
                let total = user + nice + sys + idle + io + irq + soft + steal;
                let idleTotal = idle + io;
                let totalDelta = total - sysRoot.lastCpuTotal;
                let idleDelta = idleTotal - sysRoot.lastCpuIdle;
                if (totalDelta > 0) sysRoot.sysCpu = Math.max(0.0, Math.min(1.0, (totalDelta - idleDelta) / totalDelta));
                sysRoot.lastCpuTotal = total; sysRoot.lastCpuIdle = idleTotal;
            }
        }
    }

    Process {
        id: diskGpuProc
        command: [
            "fish", "-c",
            // 1. GPU Utilization
            "if command -q nvidia-smi; " +
                "set -l gpu (nvidia-smi --query-gpu=utilization.gpu,utilization.decoder --format=csv,noheader,nounits 2>/dev/null | awk -F', ' '{print ($1 > $2 ? $1 : $2)}' | head -n1 | string trim); " +
                "echo (test -n \"$gpu\"; and echo $gpu; or echo 0); " +
            "else; " +
                "set -l sysgpu (cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -n1); " +
                "echo (test -n \"$sysgpu\"; and echo $sysgpu; or echo 0); " +
            "end; " +
            // 2. Disk Usage (%)
            "df / | awk 'NR==2 {print $5}' | sed 's/%//'; " +
            // 3. CPU Temp (°C)
            "set -l cpu_t ''; " +
            "for h in /sys/class/hwmon/hwmon*; " +
                "if test -f \"$h/name\"; " +
                    "set -l n (cat \"$h/name\" 2>/dev/null); " +
                    "if string match -qi '*coretemp*' \"$n\"; or string match -qi '*k10temp*' \"$n\"; or string match -qi '*zenpower*' \"$n\"; or string match -qi '*cpu*' \"$n\"; " +
                        "if test -f \"$h/temp1_input\"; set cpu_t (cat \"$h/temp1_input\" 2>/dev/null); break; end; " +
                    "end; " +
                "end; " +
            "end; " +
            "if test -z \"$cpu_t\"; " +
                "for z in /sys/class/thermal/thermal_zone*; " +
                    "if test -f \"$z/type\"; and string match -qi '*pkg*' (cat \"$z/type\" 2>/dev/null); set cpu_t (cat \"$z/temp\" 2>/dev/null); break; end; " +
                "end; " +
            "end; " +
            "if test -z \"$cpu_t\"; set cpu_t (cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n1); end; " +
            "test -n \"$cpu_t\"; and math -s0 \"$cpu_t / 1000\"; or echo 0; " +
            // 4. GPU Temp (°C)
            "if command -q nvidia-smi; " +
                "set -l gtemp (nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 | string trim); " +
                "echo (test -n \"$gtemp\"; and echo $gtemp; or echo 0); " +
            "else; " +
                "set -l gtemp ''; " +
                "for h in /sys/class/hwmon/hwmon*; " +
                    "if test -f \"$h/name\"; " +
                        "set -l n (cat \"$h/name\" 2>/dev/null); " +
                        "if string match -qi '*amdgpu*' \"$n\"; or string match -qi '*i915*' \"$n\"; or string match -qi '*xe*' \"$n\"; or string match -qi '*nouveau*' \"$n\"; " +
                            "if test -f \"$h/temp1_input\"; set gtemp (cat \"$h/temp1_input\" 2>/dev/null); break; end; " +
                        "end; " +
                    "end; " +
                "end; " +
                "test -n \"$gtemp\"; and math -s0 \"$gtemp / 1000\"; or echo 0; " +
            "end; " +
            // 5. RAM Temp (°C)
            "set -l rtemp (cat /sys/class/hwmon/hwmon*/name 2>/dev/null | grep -i -n 'spd5118\\|dram' | cut -d: -f1 | head -n1); " +
            "if test -n \"$rtemp\"; " +
                "set -l raw_rt (cat /sys/class/hwmon/hwmon\"$rtemp\"/temp1_input 2>/dev/null || echo 0); " +
                "math -s0 \"$raw_rt / 1000\"; " +
            "else; " +
                "echo 0; " +
            "end"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let lines = this.text.trim().split("\n");
                    if (lines.length >= 2) {
                        let rawGpu = parseFloat(lines[0]) || 0.0;
                        sysRoot.sysGpu = rawGpu / 100.0;
                        let rawDisk = parseFloat(lines[1]) || 0.0;
                        sysRoot.sysDisk = rawDisk / 100.0;
                    }
                    if (lines.length >= 3) sysRoot.cpuTemp = Math.round(parseFloat(lines[2]) || 0);
                    if (lines.length >= 4) sysRoot.gpuTemp = Math.round(parseFloat(lines[3]) || 0);
                    if (lines.length >= 5) sysRoot.ramTemp = Math.round(parseFloat(lines[4]) || 0);
                } catch(e) {}
                diskGpuProc.running = false;
            }
        }
    }

    Process {
        id: allProcessesFetcher
        command: [
            "/bin/fish", "-c",
            // CPU Processes
            "echo '___CAT___|CPU'; " +
            "ps -eo pid,pcpu,comm --sort=-pcpu | head -n 11 | tail -n +2 | awk -v cores=(nproc) '{print $1\"|\"$2/cores\"|\"$3}'; " +
            // GPU Processes
            "echo '___CAT___|GPU'; " +
            "set -l g_pids (string match -ra '\\d+' (fuser /dev/nvidia* /dev/dri/renderD* 2>/dev/null) | sort -u); " +
            "if test (count $g_pids) -gt 0; " +
                "ps -p (string join ',' $g_pids) -o pid,pmem,comm --sort=-pmem 2>/dev/null | head -n 11 | tail -n +2 | awk '{print $1\"|\"$2\"%|\"$3}'; " +
            "else if command -q nvidia-smi; " +
                "nvidia-smi --query-compute-apps=pid,used_memory,process_name --format=csv,noheader,nounits 2>/dev/null | head -n 10 | awk -F', ' '{print $1\"|\"$2\" MB|\"$3}'; " +
            "end; " +
            // RAM Processes
            "echo '___CAT___|RAM'; " +
            "ps -eo pid,pmem,comm --sort=-pmem | head -n 11 | tail -n +2 | awk '{print $1\"|\"$2\"|\"$3}'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let parsedItems = [];
                let currentCat = "CPU";
                let lines = this.text.trim().split("\n");
                
                for (let i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    let parts = lines[i].split("|");
                    
                    if (parts[0] === "___CAT___") {
                        currentCat = parts[1];
                    } else if (parts.length === 3) {
                        let metricVal = parts[1];
                        
                        if (metricVal.includes("%")) {
                            let val = parseFloat(metricVal.replace("%", "")) || 0.0;
                            let clamped = val > 100 ? 100 : val;
                            metricVal = (clamped < 1.0) ? clamped.toFixed(1) + "%" : Math.round(clamped) + "%";
                        } else if (!metricVal.includes("MB")) {
                            let val = parseFloat(metricVal) || 0.0;
                            let clamped = val > 100 ? 100 : val;
                            metricVal = (clamped < 1.0) ? clamped.toFixed(1) + "%" : Math.round(clamped) + "%";
                        }
                        
                        parsedItems.push({
                            "category": currentCat,
                            "metric": metricVal,
                            "name": parts[2],
                            "pid": parts[0]
                        });
                    }
                }

                globalProcessModel.clear();
                for (let item of parsedItems) {
                    globalProcessModel.append(item);
                }
                sysRoot.updateFilteredModel();
            }
        }
    }

    Process {
        id: killerProc
        running: false
    }

    component StatRingItem : Item {
        id: ringRow
        width: 84  
        height: 84

        property string label: ""
        property real value: 0.0
        property int temp: 0
        property bool clickable: true
        property bool selected: sysRoot.activeCategory === ringRow.label

        property real animValue: value
        Behavior on animValue {
            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
        }

        property real animStrokeWidth: ringRow.clickable && ringRow.selected ? 5.5 : 4.5
        Behavior on animStrokeWidth {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        Shape {
            anchors.fill: parent

            ShapePath {
                fillColor: "transparent"
                strokeColor: ringRow.clickable && ringRow.selected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2) : Qt.rgba(255, 255, 255, 0.08)
                strokeWidth: ringRow.animStrokeWidth
                PathAngleArc { 
                    centerX: 42; centerY: 42; radiusX: 37; radiusY: 37
                    startAngle: -90; sweepAngle: 360
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Config.accent
                strokeWidth: ringRow.animStrokeWidth
                capStyle: ShapePath.RoundCap
                PathAngleArc { 
                    centerX: 42; centerY: 42; radiusX: 37; radiusY: 37
                    startAngle: -90; sweepAngle: Math.max(0.1, ringRow.animValue * 360)
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: -1

            Text {
                text: ringRow.label
                color: ringRow.clickable && ringRow.selected ? Config.textMain : Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: Math.round(ringRow.value * 100) + "%"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                visible: ringRow.temp > 0
                text: ringRow.temp + "°C"
                color: Config.accent
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: ringRow.clickable
            cursorShape: ringRow.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (ringRow.clickable) {
                    sysRoot.activeCategory = ringRow.label;
                }
            }
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: sysRoot.cardMargin
        spacing: sysRoot.cardMargin / 2

        // ==========================================
        // CARD 1: HARDWARE MONITOR RINGS
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitWidth: 420
            implicitHeight: ringCardLayout.implicitHeight + (sysRoot.cardMargin * 2)
            color: Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius

            ColumnLayout {
                id: ringCardLayout
                anchors.fill: parent
                anchors.margins: sysRoot.cardMargin
                spacing: sysRoot.cardMargin

                Text {
                    text: "SYSTEM MONITOR"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontTitle)
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Item { Layout.fillWidth: true }
                    StatRingItem { label: "CPU"; value: sysRoot.sysCpu; temp: sysRoot.cpuTemp }
                    Item { Layout.fillWidth: true }
                    StatRingItem { label: "GPU"; value: sysRoot.sysGpu; temp: sysRoot.gpuTemp }
                    Item { Layout.fillWidth: true }
                    StatRingItem { label: "RAM"; value: sysRoot.sysRam; temp: sysRoot.ramTemp }
                    Item { Layout.fillWidth: true }
                    StatRingItem { label: "DISK"; value: sysRoot.sysDisk; clickable: false }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        // ==========================================
        // CARD 2: PER-PROCESS LIST
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: processCardLayout.implicitHeight + (sysRoot.cardMargin * 2)
            color: Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius

            ColumnLayout {
                id: processCardLayout
                anchors.fill: parent
                anchors.margins: sysRoot.cardMargin
                spacing: sysRoot.cardMargin

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: sysRoot.activeCategory + " PROCESSES"
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
                    Layout.preferredHeight: Math.min(filteredProcessModel.count, 5) * 34
                    clip: true
                    spacing: 6
                    model: filteredProcessModel

                    property bool isHoveringRow: false

                    delegate: Rectangle {
                        id: rowDelegate
                        width: processListView.width
                        height: 28
                        color: deleteMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : Qt.rgba(0, 0, 0, 0.15)
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
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
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
                                Layout.preferredWidth: 40
                                Layout.alignment: Qt.AlignVCenter
                                horizontalAlignment: Text.AlignRight
                            }

                            Text {
                                text: model.metric
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: true
                                Layout.preferredWidth: 45
                                Layout.alignment: Qt.AlignVCenter
                                horizontalAlignment: Text.AlignRight
                            }

                            Rectangle {
                                id: deleteBtn
                                implicitWidth: 20
                                implicitHeight: 20
                                radius: Config.cornerRadius / 4
                                color: deleteMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
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

                                MouseArea {
                                    id: deleteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onClicked: {
                                        let targetPid = parseInt(model.pid);
                                        if (targetPid > 0) {
                                            killerProc.command = ["kill", "-15", targetPid.toString()];
                                            killerProc.running = true;
                                            allProcessesFetcher.running = true;
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

    Connections {
        target: Config
        function onShowSystemMonitorChanged() {
            if (Config.showSystemMonitor) {
                cpuStatReader.reload()
                memInfoReader.reload()
                allProcessesFetcher.running = true
            }
        }
    }
}