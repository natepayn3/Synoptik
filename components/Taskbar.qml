import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

GridLayout {
    id: taskbarRoot
    rowSpacing: 8
    columnSpacing: 8
    property string activeScreenName: ""
    property bool isVertical: false

    columns: isVertical ? 1 : -1
    rows: isVertical ? -1 : 1

    visible: implicitWidth > 0 && implicitHeight > 0

    Repeater {
        model: ScriptModel {
            values: Hyprland.toplevels.values
        }

        delegate: Item {
            id: clientDelegate
            implicitWidth: 32
            implicitHeight: 32
            
            visible: modelData.monitor && (modelData.monitor.name === taskbarRoot.activeScreenName)

            readonly property string appId: modelData.wayland?.appId || modelData.lastIpcObject?.class || ""

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: clientMouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Item {
                id: iconContainer
                anchors.centerIn: parent
                width: modelData.activated ? 24 : 20
                height: modelData.activated ? 24 : 20
                
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

                        // 1. Try desktop entry heuristic lookup
                        let entry = DesktopEntries.heuristicLookup(id);
                        if (entry && entry.icon) {
                            let entryPath = Quickshell.iconPath(entry.icon, true);
                            if (entryPath) return entryPath;
                        }

                        // 2. Direct icon name lookup
                        let raw = Quickshell.iconPath(id, true);
                        if (raw) return raw;

                        // 3. Lowercase lookup
                        let lower = Quickshell.iconPath(id.toLowerCase(), true);
                        if (lower) return lower;

                        // 4. Reverse DNS fallback (e.g. org.gnome.Nautilus -> Nautilus)
                        if (id.includes(".")) {
                            let baseName = id.split('.').pop().toLowerCase();
                            let dnsPath = Quickshell.iconPath(baseName, true);
                            if (dnsPath) return dnsPath;
                        }

                        // 5. Resolved fallback icon or empty string (prevents QRC lookup errors)
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
}