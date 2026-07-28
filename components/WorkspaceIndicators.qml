import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Item {
    id: root
    
    property bool isVertical: false

    // Explicitly swap parent dimensions when vertical so parent containers don't collapse
    implicitWidth: isVertical ? mainLayout.implicitWidth : mainLayout.implicitWidth
    implicitHeight: isVertical ? mainLayout.implicitHeight : mainLayout.implicitHeight

    function parseSpecialPayload(data) {
        if (!data) return "";
        let parts = data.split(',');
        let target = parts[0].trim();
        if (target.startsWith("special:")) {
            return target.replace(/^special:/, "");
        }
        return target;
    }

    // --- TRACKING ENGINES ---
    property int activeWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    property string activeSpecialName: ""
    property var occupiedMap: ({})
    property var workspaceList: []
    
    property bool isMagicOccupied: false
    property bool isMagicActive: activeSpecialName === "magic"

    property bool isMusicOccupied: false
    property bool isMusicActive: activeSpecialName === "music"

    property bool isPrivateOccupied: false
    property bool isPrivateActive: activeSpecialName === "private"

    function rebuildWorkspaceData() {
        let occupied = {};
        let magicOcc = false;
        let musicOcc = false;
        let privateOcc = false;

        let activeId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
        let currentSpecial = root.activeSpecialName;

        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.name) {
            let focusedName = Hyprland.focusedWorkspace.name;
            if (focusedName.startsWith("special:")) {
                currentSpecial = focusedName.replace(/^special:/, "");
            }
        }

        for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
            let ws = Hyprland.workspaces.values[i];
            if (ws.id > 0) {
                occupied[ws.id] = true;
            } else if (ws.name) {
                let cleanName = ws.name.replace(/^special:/, "");
                if (cleanName === "magic") magicOcc = true;
                if (cleanName === "music") musicOcc = true;
                if (cleanName === "private") privateOcc = true;
            }
        }

        let listSet = new Set(Object.keys(occupied).map(Number));
        if (activeId > 0) {
            listSet.add(activeId);
        }

        let sortedList = Array.from(listSet).sort((a, b) => a - b);
        if (sortedList.length === 0) sortedList = [1];

        root.occupiedMap = occupied;
        root.activeWorkspace = activeId;
        root.activeSpecialName = currentSpecial;
        root.workspaceList = sortedList;

        root.isMagicOccupied = magicOcc;
        root.isMusicOccupied = musicOcc;
        root.isPrivateOccupied = privateOcc;
    }

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { root.rebuildWorkspaceData(); }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { root.rebuildWorkspaceData(); }
        function onRawEvent(event) {
            if (event.name === "activespecial") {
                let cleanName = root.parseSpecialPayload(event.data);
                root.activeSpecialName = cleanName;
                root.rebuildWorkspaceData();
            }
            if (event.name === "destroyworkspace" || event.name === "createworkspace") {
                root.rebuildWorkspaceData();
            }
        }
    }

    Component.onCompleted: root.rebuildWorkspaceData()

    // Single dynamic container using Flow to avoid Layout/Loader transform bugs
    Flow {
        id: mainLayout
        anchors.centerIn: parent
        flow: root.isVertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: 10

        Repeater {
            model: root.workspaceList
            delegate: Item {
                id: pillSlot
                property int wsId: modelData
                property bool isSpecialAnyActive: root.activeSpecialName !== ""
                property bool isActive: root.activeWorkspace === wsId && !isSpecialAnyActive
                property bool isOccupied: root.occupiedMap[wsId] === true

                // The pill's own target size (same values as before).
                property int pillW: root.isVertical ? (isActive ? 12 : 20) : (isActive ? 30 : 10)
                property int pillH: root.isVertical ? (isActive ? 30 : 10) : (isActive ? 12 : 20)

                // Only fix the CROSS-axis size (so the pill can be centered
                // on that axis instead of top/left-aligned). Leave the
                // main/flow-axis size dynamic so item spacing is unchanged.
                implicitWidth: root.isVertical ? 20 : pillW
                implicitHeight: root.isVertical ? pillH : 20

                Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.centerIn: parent

                    // Correct pill size recalculation for both orientations
                    implicitWidth: pillSlot.pillW
                    implicitHeight: pillSlot.pillH
                    radius: root.isVertical ? width / 3 : height / 3

                    color: pillSlot.isActive ? Config.accent : "transparent"
                    border.width: pillSlot.isActive ? 0 : 3
                    border.color: pillSlot.isActive ? "transparent" : (pillSlot.isOccupied ? Config.textMain : Qt.rgba(255, 255, 255, 0.15))

                    Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                }

                TapHandler {
                    onTapped: {
                        if (typeof Config.showWorkspacePreview !== "undefined") Config.showWorkspacePreview = false;
                        root.activeSpecialName = "";
                        Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + pillSlot.wsId + "\" })");
                    }
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }

        // ADD BUTTON
        Item {
            implicitWidth: 20; implicitHeight: 20
            Text {
                anchors.centerIn: parent
                font.family: Config.sysFont; font.pixelSize: 18; font.bold: true
                color: addHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.35)
                text: "+"
            }
            TapHandler {
                onTapped: {
                    let maxWs = root.workspaceList.length > 0 ? Math.max(...root.workspaceList) : 0;
                    root.activeSpecialName = "";
                    Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + (maxWs + 1) + "\" })");
                }
            }
            HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
        }

        // OVERVIEW BUTTON
        Item {
            implicitWidth: 20; implicitHeight: 20
            Text {
                anchors.centerIn: parent
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                color: Config.showWorkspacePreview ? Config.accent : (overviewHover.hovered ? Config.textMain : Qt.rgba(255, 255, 255, 0.35))
                text: "select_window_2"
            }
            TapHandler { onTapped: if (typeof Config.showWorkspacePreview !== "undefined") Config.showWorkspacePreview = !Config.showWorkspacePreview }
            HoverHandler { id: overviewHover; cursorShape: Qt.PointingHandCursor }
        }

        // SPECIAL WORKSPACES
        Item {
            implicitWidth: 20; implicitHeight: 20
            visible: root.isMagicOccupied || root.isMagicActive
            Text {
                anchors.centerIn: parent
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold
                font.pixelSize: root.isMagicActive ? 24 : 20
                color: root.isMagicActive ? Config.accent : Qt.rgba(255, 255, 255, 0.35)
                text: root.isMagicActive ? "family_star" : "kid_star"
            }
            TapHandler { onTapped: Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"magic\")") }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        Item {
            implicitWidth: 20; implicitHeight: 20
            visible: root.isMusicOccupied || root.isMusicActive
            Text {
                anchors.centerIn: parent
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold
                font.pixelSize: root.isMusicActive ? 24 : 20
                color: root.isMusicActive ? Config.accent : Qt.rgba(255, 255, 255, 0.35)
                text: root.isMusicActive ? "genres" : "music_note"
            }
            TapHandler { onTapped: Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"music\")") }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        Item {
            implicitWidth: 20; implicitHeight: 20
            visible: root.isPrivateOccupied || root.isPrivateActive
            Text {
                anchors.centerIn: parent
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold
                font.pixelSize: root.isPrivateActive ? 24 : 20
                color: root.isPrivateActive ? Config.accent : Qt.rgba(255, 255, 255, 0.35)
                text: root.isPrivateActive ? "lock_open" : "lock"
            }
            TapHandler { onTapped: Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"private\")") }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }
}