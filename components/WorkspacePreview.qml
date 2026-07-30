import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

FocusScope {
    id: overviewFlyout
    focus: true

    implicitWidth: Math.max(480, (rowContainer.childrenRect.width > 0 ? rowContainer.childrenRect.width + 48 : 480))
    implicitHeight: Math.max(260, (cardLayout.implicitHeight > 0 ? cardLayout.implicitHeight + 48 : 260))
    
    readonly property bool isOpen: typeof Config.showWorkspacePreview !== "undefined" ? Config.showWorkspacePreview : false

    property var liveClientJson: []
    property var liveMonitorJson: []
    property var resolvedIconPaths: ({})
    property int highlightedIndex: 0
    property bool contentReady: false

    readonly property var activeWorkspaces: {
        let ids = [1];
        for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
            let ws = Hyprland.workspaces.values[i];
            if (ws.id > 0 && !ids.includes(ws.id)) {
                ids.push(ws.id);
            }
        }
        return ids.sort((a, b) => a - b);
    }

    function switchWorkspace(targetWs) {
        // 1. Force Hyprland to release any active layer-shell input captures
        Hyprland.dispatch("hl.dsp.release_input_capture()");

        // 2. Dispatch workspace focus using the exact Lua signature
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + targetWs + " })");

        // 3. Close the preview drawer
        if (typeof Config.showWorkspacePreview !== "undefined") {
            Config.showWorkspacePreview = false;
        }
    }

    Keys.onPressed: (event) => {
        if (!overviewFlyout.isOpen) return;

        if (event.key === Qt.Key_Left) {
            if (overviewFlyout.highlightedIndex > 0) {
                overviewFlyout.highlightedIndex--;
            } else {
                overviewFlyout.highlightedIndex = overviewFlyout.activeWorkspaces.length - 1;
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            if (overviewFlyout.highlightedIndex < overviewFlyout.activeWorkspaces.length - 1) {
                overviewFlyout.highlightedIndex++;
            } else {
                overviewFlyout.highlightedIndex = 0;
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Select) {
            let targetWs = overviewFlyout.activeWorkspaces[overviewFlyout.highlightedIndex];
            event.accepted = true;
            switchWorkspace(targetWs);
        } else if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            if (typeof Config.showWorkspacePreview !== "undefined") {
                Config.showWorkspacePreview = false;
            }
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            contentReady = false
            renderDelayTimer.restart()

            // Refresh Wayland state
            Hyprland.refreshToplevels()
            Hyprland.refreshWorkspaces()
            clientQueryProcess.running = true
            
            // Sync highlight to current workspace
            let currentId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
            let idx = activeWorkspaces.indexOf(currentId)
            highlightedIndex = idx !== -1 ? idx : 0
            
            // Removed forceActiveFocus() here
        } else {
            renderDelayTimer.stop()
            contentReady = false
        }
    }

    Component.onCompleted: {
        if (isOpen) {
            contentReady = false
            renderDelayTimer.restart()
            
            // Refresh Wayland state
            Hyprland.refreshToplevels()
            Hyprland.refreshWorkspaces()
            clientQueryProcess.running = true
            
            // Removed forceActiveFocus() here
        }
    }

    Timer {
        id: renderDelayTimer
        interval: 300
        repeat: false
        onTriggered: {
            overviewFlyout.contentReady = true
            // Grab focus only after the layer-shell surface is fully realized
            overviewFlyout.forceActiveFocus() 
        }
    }

    Connections {
        target: Hyprland
        ignoreUnknownSignals: true
        function onRawEvent(event) {
            let evtName = event && event.name ? event.name : "";
            let evtData = event && event.data ? event.data : "";

            if (evtName.includes("openwindow") || evtName.includes("closewindow") || evtName.includes("movewindow")) {
                clientQueryProcess.running = true;
            }

            if (evtName.includes("workspaceoverview") || evtData.includes("workspaceoverview")) {
                if (typeof Config.showWorkspacePreview !== "undefined") {
                    Config.showWorkspacePreview = !Config.showWorkspacePreview;
                }
            }
        }
    }

    Process {
        id: clientQueryProcess
        command: ["hyprctl", "clients", "-j"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let cleanText = text.trim();
                if (!cleanText || cleanText === "[]") return;
                try { 
                    overviewFlyout.liveClientJson = JSON.parse(cleanText);
                    triggerIconLookups();
                } catch(e) {}
            }
        }
    }

    Process {
        id: monitorQueryProcess
        command: ["hyprctl", "monitors", "-j"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let cleanText = text.trim();
                if (!cleanText || cleanText === "[]") return;
                try { 
                    overviewFlyout.liveMonitorJson = JSON.parse(cleanText);
                } catch(e) {}
            }
        }
    }

    Process {
        id: iconFinderProcess
        running: false
        
        command: ["python", "-c", `
import os, sys, json

class_list = json.loads(sys.argv[1])
app_dirs = [
    os.path.expanduser("~/.local/share/applications"),
    "/usr/share/applications"
]

resolved_map = {}

for target_class in class_list:
    target = target_class.lower().strip()
    resolved_icon = ""
    
    for base_dir in app_dirs:
        if resolved_icon: break
        if not os.path.isdir(base_dir): continue
        
        for f in os.listdir(base_dir):
            if not f.endswith(".desktop"): continue
            f_lower = f.lower()
            
            is_match = target in f_lower
            if is_match or target.replace(".", "-") in f_lower:
                path = os.path.join(base_dir, f)
                try:
                    with open(path, "r", errors="ignore") as file_handle:
                        icon_name = ""
                        wm_class_match = False
                        
                        for line in file_handle:
                            if line.startswith("Icon="):
                                icon_name = line.split("=")[1].strip()
                            elif line.startswith("StartupWMClass="):
                                if target == line.split("=")[1].strip().lower():
                                    wm_class_match = True
                        
                        if icon_name and (is_match or wm_class_match):
                            resolved_icon = icon_name
                            break
                except Exception:
                    continue

    resolved_map[target_class] = "image://icon/" + (resolved_icon if resolved_icon else target)

print(json.dumps(resolved_map))
`, JSON.stringify(getUnresolvedClasses())]
        
        stdout: StdioCollector {
            onTextChanged: {
                let cleanText = text.trim();
                if (!cleanText || cleanText === "{}") return;
                try {
                    let parsed = JSON.parse(cleanText);
                    let updatedPaths = Object.assign({}, overviewFlyout.resolvedIconPaths);
                    for (let cls in parsed) {
                        updatedPaths[cls] = parsed[cls];
                    }
                    overviewFlyout.resolvedIconPaths = updatedPaths;
                } catch(e) {}
            }
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        opacity: overviewFlyout.contentReady ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: cardLayout.implicitHeight + 24
            color: Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius

            ColumnLayout {
                id: cardLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text {
                    text: "WORKSPACE OVERVIEW"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontTitle)
                    font.bold: true
                    Layout.fillWidth: true
                }

                Row {
                    id: rowContainer
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    Repeater {
                        model: overviewFlyout.activeWorkspaces

                        delegate: Rectangle {
                            id: wsTile
                            required property int modelData
                            required property int index

                            readonly property bool isCurrent: (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1) === modelData
                            readonly property bool isSelected: overviewFlyout.highlightedIndex === index
                            property int workingWorkspace: modelData

                            color: tileHover.hovered || isSelected ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(0, 0, 0, 0.3)
                    
                            border.color: tileHover.hovered || isSelected || isCurrent ? Config.accent : "transparent"
                            border.width: tileHover.hovered || isSelected ? 3 : (isCurrent ? 2 : 0)
                            
                            radius: Config.cornerRadius / 2
                            clip: false

                            Behavior on color { ColorAnimation { duration: 150 } }

                            property var monitorBounds: {
                                let _json = overviewFlyout.liveMonitorJson;
                                let monName = "";
                                let wsObj = Hyprland.workspaces.values.find(w => w.id === wsTile.workingWorkspace);
                                if (wsObj && wsObj.monitor) {
                                    monName = typeof wsObj.monitor === "string" ? wsObj.monitor : wsObj.monitor.name;
                                }

                                let monData = null;
                                if (_json && _json.length > 0) {
                                    monData = _json.find(m => m.name === monName);
                                    if (!monData) {
                                        let activeMon = Hyprland.activeMonitor;
                                        let activeName = activeMon ? (typeof activeMon === "string" ? activeMon : activeMon.name) : "";
                                        monData = _json.find(m => m.name === activeName);
                                    }
                                }

                                let mWidth = 1920, mHeight = 1080, mX = 0, mY = 0;
                                let isRotated = false;

                                if (monData) {
                                    let scale = monData.scale > 0 ? monData.scale : 1.0;
                                    let rawW = Math.round(monData.width / scale);
                                    let rawH = Math.round(monData.height / scale);
                                    
                                    if (monData.transform !== undefined) {
                                        isRotated = [1, 3, 5, 7].includes(parseInt(monData.transform, 10));
                                    }

                                    mWidth = isRotated ? rawH : rawW;
                                    mHeight = isRotated ? rawW : rawH;
                                    mX = monData.x !== undefined ? monData.x : 0;
                                    mY = monData.y !== undefined ? monData.y : 0;
                                } else {
                                    let fb = Hyprland.monitors.values.find(m => m.name === monName) || Hyprland.activeMonitor;
                                    if (fb) {
                                        let scale = fb.scale > 0 ? fb.scale : 1.0;
                                        mWidth = Math.round(fb.width / scale) || 1920;
                                        mHeight = Math.round(fb.height / scale) || 1080;
                                        mX = fb.x || 0;
                                        mY = fb.y || 0;
                                    }
                                }

                                return {
                                    "w": mWidth,
                                    "h": mHeight,
                                    "isVertical": mHeight > mWidth,
                                    "originX": mX,
                                    "originY": mY
                                };
                            }

                            width: Math.max(160, viewportFrame.width + 24)
                            height: viewportFrame.height + headerRow.height + 24

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 0

                                RowLayout {
                                    id: headerRow
                                    Layout.fillWidth: true
                                    height: 18

                                    Text {
                                        text: wsTile.modelData
                                        color: wsTile.isCurrent ? Config.accent : Config.textMain
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontSubhead)
                                        font.bold: true
                                    }

                                    Text {
                                        text: "task_alt"
                                        color: Config.accent
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: Config.size(Config.fontSubhead)
                                        font.bold: true
                                        visible: wsTile.isCurrent
                                    }

                                    Item { Layout.fillWidth: true }

                                    RowLayout {
                                        spacing: 4
                                        Repeater {
                                            model: viewportFrame.workspaceWindows
                                            delegate: Image {
                                                property string currentClass: (modelData && modelData.class) ? modelData.class : ""
                                                property string resolvedPath: (currentClass !== "" && overviewFlyout.resolvedIconPaths) ? (overviewFlyout.resolvedIconPaths[currentClass] || "") : ""
                                                
                                                visible: modelData && currentClass !== "" && modelData.mapped && resolvedPath !== ""
                                                source: resolvedPath
                                                
                                                Layout.preferredWidth: 14
                                                Layout.preferredHeight: 14
                                                fillMode: Image.PreserveAspectFit
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: viewportFrame
                                    Layout.fillWidth: false
                                    Layout.alignment: Qt.AlignHCenter
                                    color: "transparent"
                                    radius: 4
                                    clip: true

                                    property var targetMonitorOutput: {
                                        let wsObj = Hyprland.workspaces.values.find(w => w.id === wsTile.workingWorkspace);
                                        let monName = wsObj && wsObj.monitor ? (typeof wsObj.monitor === "string" ? wsObj.monitor : wsObj.monitor.name) : "";
                                        
                                        if (!monName && Hyprland.activeMonitor) {
                                            monName = typeof Hyprland.activeMonitor === "string" ? Hyprland.activeMonitor : Hyprland.activeMonitor.name;
                                        }

                                        let qsScreen = Quickshell.screens.find(s => s.name === monName) || Quickshell.screens[0];
                                        return qsScreen ? qsScreen : null;
                                    }

                                    property var workspaceWindows: overviewFlyout.liveClientJson.filter(w => w.workspace.id === wsTile.workingWorkspace)

                                    implicitHeight: wsTile.monitorBounds.isVertical ? 220 : 135
                                    implicitWidth: Math.round(implicitHeight * (wsTile.monitorBounds.w / wsTile.monitorBounds.h))
                                    width: implicitWidth
                                    height: implicitHeight
                                    Layout.preferredWidth: implicitWidth
                                    Layout.preferredHeight: implicitHeight
                                    
                                    property real scaleX: width / wsTile.monitorBounds.w
                                    property real scaleY: height / wsTile.monitorBounds.h

                                    ScreencopyView {
                                        anchors.fill: parent
                                        captureSource: viewportFrame.targetMonitorOutput
                                        live: overviewFlyout.isOpen
                                        paintCursor: false
                                        opacity: 0.7
                                    }
                                    
                                    Repeater {
                                        model: viewportFrame.workspaceWindows

                                        delegate: Rectangle {
                                            id: windowDelegate

                                            x: Math.round((modelData.at[0] - wsTile.monitorBounds.originX) * viewportFrame.scaleX)
                                            y: Math.round((modelData.at[1] - wsTile.monitorBounds.originY) * viewportFrame.scaleY)
                                            width: Math.max(4, Math.round(modelData.size[0] * viewportFrame.scaleX))
                                            height: Math.max(4, Math.round(modelData.size[1] * viewportFrame.scaleY))
                                            visible: modelData.mapped
                                            color: Qt.rgba(255, 255, 255, 0.08)
                                            radius: 2
                                            clip: true

                                            property var wlToplevel: {
                                                if (!modelData || !modelData.address) return null;
                                                let targetAddr = modelData.address.trim().toLowerCase();
                                                let match = Hyprland.toplevels.values.find(t => {
                                                    if (!t.lastIpcObject || !t.lastIpcObject.address) return false;
                                                    return t.lastIpcObject.address.trim().toLowerCase() === targetAddr;
                                                });
                                                if (match && match.wayland) return match.wayland;
                                                return null;
                                            }

                                            ScreencopyView {
                                                anchors.fill: parent
                                                captureSource: windowDelegate.wlToplevel
                                                live: overviewFlyout.isOpen
                                                paintCursor: false
                                            }

                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                height: Math.min(16, parent.height * 0.3)
                                                color: "#cc11111b"
                                                visible: parent.height > 20 && parent.width > 32
                                                radius: 2

                                                Text {
                                                    text: (modelData.class || "")
                                                    font.family: Config.sysFont
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    color: Config.textMain
                                                    anchors.centerIn: parent
                                                    width: parent.width - 4
                                                    elide: Text.ElideRight
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Handle precise pointer inputs without blocking Wayland layer-shell events
                            TapHandler {
                                onTapped: {
                                    overviewFlyout.forceActiveFocus() // Ensure FocusScope retains key listening
                                    switchWorkspace(wsTile.modelData)
                                }
                            }

                            // Handle hover states safely
                            HoverHandler {
                                id: tileHover
                                cursorShape: Qt.PointingHandCursor
                                
                                onHoveredChanged: {
                                    if (hovered) {
                                        overviewFlyout.highlightedIndex = wsTile.index
                                        overviewFlyout.forceActiveFocus() // Re-grab keyboard focus on mouse enter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function getUnresolvedClasses() {
        let windows = overviewFlyout.liveClientJson || [];
        let list = [];
        for (let i = 0; i < windows.length; i++) {
            let cls = windows[i].class;
            if (cls && !overviewFlyout.resolvedIconPaths[cls] && !list.includes(cls)) {
                list.push(cls);
            }
        }
        return list;
    }

    function triggerIconLookups() {
        if (getUnresolvedClasses().length > 0 && !iconFinderProcess.running) {
            iconFinderProcess.running = true;
        }
    }
}