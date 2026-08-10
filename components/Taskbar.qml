import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

Item {
    id: taskbarRoot
    property string activeScreenName: ""
    property bool isVertical: false

    signal popoutRequested(var item)
    property alias viewAppsBtn: btnViewApps

    anchors.fill: parent

    // Inline Comment: Active window filter for the current monitor
    readonly property var activeClients: Hyprland.toplevels.values.filter(c => c.monitor && c.monitor.name === activeScreenName)
    readonly property int totalCount: activeClients.length

    // Inline Comment: Dynamic icon capacity calculation based on pixel bounds
    readonly property int maxVisibleCount: {
        let span = isVertical ? height : width
        return Math.max(1, Math.floor((span + 8) / 36))
    }

    readonly property bool hasOverflow: totalCount > maxVisibleCount
    readonly property int visibleLimit: hasOverflow ? Math.max(1, maxVisibleCount - 1) : totalCount

    readonly property real calculatedWidth: grid.childrenRect.width > 0 ? grid.childrenRect.width : grid.implicitWidth
    readonly property real calculatedHeight: grid.childrenRect.height > 0 ? grid.childrenRect.height : grid.implicitHeight

    implicitWidth: calculatedWidth
    implicitHeight: calculatedHeight

    GridLayout {
        id: grid
        anchors.horizontalCenter: taskbarRoot.isVertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: taskbarRoot.isVertical ? undefined : parent.verticalCenter
        anchors.left: taskbarRoot.isVertical ? undefined : parent.left
        anchors.top: taskbarRoot.isVertical ? parent.top : undefined

        rowSpacing: 8
        columnSpacing: 8

        columns: taskbarRoot.isVertical ? 1 : -1
        rows: taskbarRoot.isVertical ? -1 : 1

        Repeater {
            model: taskbarRoot.activeClients.slice(0, taskbarRoot.visibleLimit)

            delegate: Item {
                id: clientDelegate
                
                implicitWidth: 28
                implicitHeight: 28

                readonly property string appId: modelData.wayland?.appId || modelData.lastIpcObject?.class || ""

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: clientMouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Item {
                    id: iconContainer
                    anchors.centerIn: parent
                    width: modelData.activated ? 24 : 18
                    height: modelData.activated ? 24 : 18
                    
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    IconImage {
                        id: clientIcon
                        anchors.fill: parent
                        asynchronous: true

                        source: {
                            let id = clientDelegate.appId;
                            if (!id) return "";

                            let _cacheWatcher = DesktopEntries.applications.values;

                            let entry = DesktopEntries.heuristicLookup(id);
                            if (entry && entry.icon) {
                                let entryPath = Quickshell.iconPath(entry.icon, true);
                                if (entryPath) return entryPath;
                            }

                            let raw = Quickshell.iconPath(id, true);
                            if (raw) return raw;

                            let lower = Quickshell.iconPath(id.toLowerCase(), true);
                            if (lower) return lower;

                            if (id.includes(".")) {
                                let baseName = id.split('.').pop().toLowerCase();
                                let dnsPath = Quickshell.iconPath(baseName, true);
                                if (dnsPath) return dnsPath;
                            }

                            return Quickshell.iconPath("application-x-executable", true) 
                                || Quickshell.iconPath("applications-other", true) 
                                || "";
                        }
                    }
                }

                MouseArea {
                    id: clientMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        if (modelData.wayland) {
                            modelData.wayland.activate()
                        }
                    }
                }
            }
        }

        // Inline Comment: Running windows overflow trigger button
        Rectangle {
            id: btnViewApps
            visible: taskbarRoot.hasOverflow
            implicitWidth: visible ? 28 : 0
            implicitHeight: visible ? 28 : 0
            radius: 8
            color: (Config.showTaskOverflow || viewAppsHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "unfold_more"
                font.family: "Material Symbols Outlined"
                font.weight: Font.Bold
                font.pixelSize: 18
                color: Config.showTaskOverflow ? Config.accent : Config.textMain
            }

            TapHandler {
                onTapped: {
                    taskbarRoot.popoutRequested(btnViewApps)
                    Config.showTaskOverflow = !Config.showTaskOverflow
                }
            }
            HoverHandler { id: viewAppsHover; cursorShape: Qt.PointingHandCursor }
        }
    }
}