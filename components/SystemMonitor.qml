import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: sysRoot
    
    implicitWidth: 420
    implicitHeight: mainLayout.implicitHeight + 24

    property real sysCpu: 0.0
    property real sysGpu: 0.0
    property real sysRam: 0.0
    property real sysDisk: 0.0

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
            
            // Only fetch process list if user isn't hovering a row
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
                let user = parseInt(parts[1])||0, nice = parseInt(parts[2])||0, sys = parseInt(parts[3])||0, idle = parseInt(parts[4])||0, io = parseInt(parts[5])||0, irq = parseInt(parts[6])||0, soft = parseInt(parts[7])||0;
                let total = user + nice + sys + idle + io + irq + soft;
                let totalDelta = total - sysRoot.lastCpuTotal, idleDelta = idle - sysRoot.lastCpuIdle;
                if (totalDelta > 0) sysRoot.sysCpu = (totalDelta - idleDelta) / totalDelta;
                sysRoot.lastCpuTotal = total; sysRoot.lastCpuIdle = idle;
            }
        }
    }

    Process {
        id: diskGpuProc
        command: ["fish", "-c", "cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || cat /sys/class/hwmon/hwmon*/device/gpu_busy_percent 2>/dev/null || nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo 0; df / | awk 'NR==2 {print $5}' | sed 's/%//'"]
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
                } catch(e) {}
                diskGpuProc.running = false;
            }
        }
    }

    Process {
        id: allProcessesFetcher
        // Auto-detects NVIDIA first -> Falls back to AMD/Intel DRM device node mapping -> Defaults to top RSS
        command: [
            "/bin/fish", "-c",
            "echo '___CAT___|CPU'; " +
            "ps -eo pid,pcpu,comm --sort=-pcpu | head -n 11 | tail -n +2 | awk -v cores=(nproc) '{print $1\"|\"$2/cores\"|\"$3}'; " +
            "echo '___CAT___|GPU'; " +
            "if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; " +
                "# NVIDIA Path: Query VRAM & Compute processes \n" +
                "nvidia-smi --query-compute-apps=pid,used_memory,process_name --format=csv,noheader,nounits 2>/dev/null | head -n 10 | awk -F', ' '{print $1\"|\"$2\" MB|\"$3}'; " +
            "else if test -d /dev/dri; " +
                "# AMD / Intel / Generic DRM Path: Resolve processes accessing GPU nodes \n" +
                "set pids (fuser /dev/dri/renderD* /dev/dri/card* 2>/dev/null | string split -n ' '); " +
                "if test (count $pids) -gt 0; " +
                    "ps -p (string join ',' $pids) -o pmem,comm --sort=-pmem 2>/dev/null | head -n 11 | tail -n +2 | awk '{print $1\"|\"$2\"%|\"$3}'; " +
                "else; " +
                    "ps -eo pid,pmem,comm --sort=-pmem | head -n 11 | tail -n +2 | awk '{print $1\"|\"$2\"%|\"$3}'; " +
                "end; " +
            "else; " +
                "# Fallback Path \n" +
                "ps -eo pid,pmem,comm --sort=-pmem | head -n 11 | tail -n +2 | awk '{print $1\"|\"$2\"%|\"$3}'; " +
            "end; " +
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
                        
                        // Keep raw strings for MB/formatted % values, otherwise handle rounding
                        if (currentCat !== "GPU" && !metricVal.includes("%")) {
                            let rounded = Math.round(parseFloat(parts[1]));
                            metricVal = (rounded > 100 ? 100 : rounded) + "%";
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
        property bool clickable: true
        property bool selected: sysRoot.activeCategory === ringRow.label

        layer.enabled: true
        layer.smooth: true
        layer.samples: 4
        layer.textureSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)

        Shape {
            anchors.fill: parent

            ShapePath {
                fillColor: "transparent"
                strokeColor: ringRow.clickable && ringRow.selected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2) : Qt.rgba(255, 255, 255, 0.08)
                strokeWidth: ringRow.clickable && ringRow.selected ? 5.5 : 4.5
                PathAngleArc { 
                    centerX: 42; centerY: 42; radiusX: 37; radiusY: 37
                    startAngle: -90; sweepAngle: 360
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Config.accent
                strokeWidth: ringRow.clickable && ringRow.selected ? 5.5 : 4.5
                capStyle: ShapePath.RoundCap
                PathAngleArc { 
                    centerX: 42; centerY: 42; radiusX: 37; radiusY: 37
                    startAngle: -90; sweepAngle: Math.max(0.1, ringRow.value * 360)
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 0

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
        anchors.margins: 12
        spacing: 14

        // ==========================================
        // CARD 1: HARDWARE MONITOR RINGS
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: ringCardLayout.implicitHeight + 24
            color: Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius

            ColumnLayout {
                id: ringCardLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

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
                    StatRingItem { label: "CPU"; value: sysRoot.sysCpu }
                    Item { Layout.fillWidth: true }
                    StatRingItem { label: "GPU"; value: sysRoot.sysGpu }
                    Item { Layout.fillWidth: true }
                    StatRingItem { label: "RAM"; value: sysRoot.sysRam }
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
            implicitHeight: processCardLayout.implicitHeight + 24
            color: Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius

            ColumnLayout {
                id: processCardLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

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
                        // Entire row highlights ONLY when the cursor is over the 'x' button
                        color: deleteMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : Qt.rgba(0, 0, 0, 0.15)
                        radius: 4

                        Behavior on color { ColorAnimation { duration: 150 } }

                        // Background MouseArea strictly tracks hover for ticker & refresh pause (no pointer cursor)
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
                                horizontalAlignment: Text.AlignRight
                            }

                            Text {
                                text: model.metric
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: true
                                Layout.preferredWidth: 45
                                horizontalAlignment: Text.AlignRight
                            }

                            // Delete button handles action, pointer cursor, and accent state
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