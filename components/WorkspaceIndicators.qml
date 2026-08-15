import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Hyprland

Item {
    id: root
    
    property bool isVertical: false

    signal popoutRequested(var item)
    readonly property var overviewButton: overviewBtn

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

    Flow {
        id: mainLayout
        anchors.centerIn: parent
        flow: root.isVertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: 10

        // --- GROUP 1: WORKSPACE PILLS ---
        Flow {
            flow: root.isVertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: 12

            Repeater {
                model: root.workspaceList
                delegate: Item {
                    id: pillSlot
                    property int wsId: modelData
                    property bool isSpecialAnyActive: root.activeSpecialName !== ""
                    property bool isActive: root.activeWorkspace === wsId
                    property bool isOccupied: root.occupiedMap[wsId] === true

                    property int basePillW: root.isVertical ? (isActive ? 12 : 20) : (isActive ? 30 : 10)
                    property int basePillH: root.isVertical ? (isActive ? 30 : 10) : (isActive ? 12 : 20)

                    implicitWidth: root.isVertical ? 32 : basePillW
                    implicitHeight: root.isVertical ? basePillH : 32

                    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Item {
                        anchors.centerIn: parent
                        implicitWidth: pillSlot.basePillW
                        implicitHeight: pillSlot.basePillH
                        scale: pillHover.hovered ? 1.25 : 1.0

                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                        Glow {
                            anchors.fill: pillRect
                            source: pillRect
                            radius: pillHover.hovered ? 8 : 0
                            samples: 16
                            color: Config.accent
                            spread: 0.2
                            transparentBorder: true
                            visible: pillHover.hovered

                            Behavior on radius { NumberAnimation { duration: 180 } }
                        }

                        Rectangle {
                            id: pillRect
                            anchors.fill: parent
                            radius: root.isVertical ? width / 3 : height / 3

                            color: pillSlot.isActive ? Config.accent : "transparent"
                            border.width: pillSlot.isActive ? 0 : 3
                            border.color: pillSlot.isActive ? "transparent" : (pillSlot.isOccupied ? (pillHover.hovered ? Config.accent : Config.textMain) : Qt.rgba(255, 255, 255, 0.15))

                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on border.color { ColorAnimation { duration: 140 } }
                        }
                    }

                    TapHandler {
                        onTapped: {
                            if (typeof Config.showWorkspacePreview !== "undefined") Config.showWorkspacePreview = false;
                            root.activeSpecialName = "";
                            Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + pillSlot.wsId + "\" })");
                        }
                    }
                    HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
                }
            }
        }

        // --- GROUP 2: ACTION BUTTONS ---
        Flow {
            flow: root.isVertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: 2

            // ADD BUTTON
            Item {
                implicitWidth: 32; implicitHeight: 32

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Item {
                    anchors.centerIn: parent
                    implicitWidth: addIconText.implicitWidth
                    implicitHeight: addIconText.implicitHeight
                    scale: addHover.hovered ? 1.25 : 1.0

                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                    Glow {
                        anchors.fill: addIconText
                        source: addIconText
                        radius: addHover.hovered ? 8 : 0
                        samples: 16
                        color: Config.accent
                        spread: 0.2
                        transparentBorder: true
                        visible: addHover.hovered

                        Behavior on radius { NumberAnimation { duration: 180 } }
                    }

                    Text {
                        id: addIconText
                        anchors.centerIn: parent
                        font.family: Config.sysFont; font.pixelSize: 20; font.bold: true
                        color: addHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.35)
                        text: "+"

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
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
                id: overviewBtn
                implicitWidth: 32; implicitHeight: 32

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Config.showWorkspacePreview ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Item {
                    anchors.centerIn: parent
                    implicitWidth: overviewIconText.implicitWidth
                    implicitHeight: overviewIconText.implicitHeight
                    scale: overviewHover.hovered ? 1.25 : 1.0

                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                    Glow {
                        anchors.fill: overviewIconText
                        source: overviewIconText
                        radius: overviewHover.hovered ? 8 : 0
                        samples: 16
                        color: Config.accent
                        spread: 0.2
                        transparentBorder: true
                        visible: overviewHover.hovered

                        Behavior on radius { NumberAnimation { duration: 180 } }
                    }

                    Text {
                        id: overviewIconText
                        anchors.centerIn: parent
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                        color: (Config.showWorkspacePreview || overviewHover.hovered) ? Config.accent : Qt.rgba(255, 255, 255, 0.35)
                        text: Config.getIcon("overview")

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                TapHandler { onTapped: { root.popoutRequested(overviewBtn); if (typeof Config.showWorkspacePreview !== "undefined") Config.showWorkspacePreview = !Config.showWorkspacePreview; } }
                HoverHandler { id: overviewHover; cursorShape: Qt.PointingHandCursor }
            }

            // SPECIAL WORKSPACES
            Item {
                implicitWidth: 32; implicitHeight: 32
                visible: root.isMagicOccupied || root.isMagicActive

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: root.isMagicActive ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Item {
                    anchors.centerIn: parent
                    implicitWidth: 20
                    implicitHeight: 20
                    scale: magicHover.hovered ? 1.25 : 1.0

                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                    Glow {
                        anchors.fill: magicIconText
                        source: magicIconText
                        radius: magicHover.hovered ? 8 : 0
                        samples: 16
                        color: Config.accent
                        spread: 0.2
                        transparentBorder: true
                        visible: magicHover.hovered

                        Behavior on radius { NumberAnimation { duration: 180 } }
                    }

                    Text {
                        id: magicIconText
                        anchors.centerIn: parent
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold
                        font.pixelSize: root.isMagicActive ? 24 : 20
                        color: (root.isMagicActive || magicHover.hovered) ? Config.accent : Qt.rgba(255, 255, 255, 0.35)
                        text: root.isMagicActive ? Config.getIcon("magic_active") : Config.getIcon("magic")

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                TapHandler { onTapped: Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"magic\")") }
                HoverHandler { id: magicHover; cursorShape: Qt.PointingHandCursor }
            }

            Item {
                implicitWidth: 32; implicitHeight: 32
                visible: root.isMusicOccupied || root.isMusicActive

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: root.isMusicActive ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Item {
                    anchors.centerIn: parent
                    implicitWidth: 20
                    implicitHeight: 20
                    scale: musicHover.hovered ? 1.25 : 1.0

                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                    Glow {
                        anchors.fill: musicIconText
                        source: musicIconText
                        radius: musicHover.hovered ? 8 : 0
                        samples: 16
                        color: Config.accent
                        spread: 0.2
                        transparentBorder: true
                        visible: musicHover.hovered

                        Behavior on radius { NumberAnimation { duration: 180 } }
                    }

                    Text {
                        id: musicIconText
                        anchors.centerIn: parent
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold
                        font.pixelSize: root.isMusicActive ? 24 : 20
                        color: (root.isMusicActive || musicHover.hovered) ? Config.accent : Qt.rgba(255, 255, 255, 0.35)
                        text: root.isMusicActive ? Config.getIcon("music_active") : Config.getIcon("music")

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                TapHandler { onTapped: Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"music\")") }
                HoverHandler { id: musicHover; cursorShape: Qt.PointingHandCursor }
            }

            Item {
                implicitWidth: 32; implicitHeight: 32
                visible: root.isPrivateOccupied || root.isPrivateActive

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: root.isPrivateActive ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Item {
                    anchors.centerIn: parent
                    implicitWidth: 20
                    implicitHeight: 20
                    scale: privateHover.hovered ? 1.25 : 1.0

                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                    Glow {
                        anchors.fill: privateIconText
                        source: privateIconText
                        radius: privateHover.hovered ? 8 : 0
                        samples: 16
                        color: Config.accent
                        spread: 0.2
                        transparentBorder: true
                        visible: privateHover.hovered

                        Behavior on radius { NumberAnimation { duration: 180 } }
                    }

                    Text {
                        id: privateIconText
                        anchors.centerIn: parent
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold
                        font.pixelSize: root.isPrivateActive ? 24 : 20
                        color: (root.isPrivateActive || privateHover.hovered) ? Config.accent : Qt.rgba(255, 255, 255, 0.35)
                        text: root.isPrivateActive ? Config.getIcon("private_active") : Config.getIcon("private")

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                TapHandler { onTapped: Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"private\")") }
                HoverHandler { id: privateHover; cursorShape: Qt.PointingHandCursor }
            }
        }
    }
}