import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

Flickable {
    id: taskbarRoot
    property string activeScreenName: ""
    property bool isVertical: false

    anchors.fill: parent

    readonly property real calculatedWidth: grid.childrenRect.width > 0 ? grid.childrenRect.width : grid.implicitWidth
    readonly property real calculatedHeight: grid.childrenRect.height > 0 ? grid.childrenRect.height : grid.implicitHeight

    contentWidth: isVertical ? width : calculatedWidth
    contentHeight: isVertical ? calculatedHeight : height

    implicitWidth: calculatedWidth
    implicitHeight: calculatedHeight

    interactive: true
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    WheelHandler {
        id: wheelHandler
        orientation: taskbarRoot.isVertical ? Qt.Vertical : Qt.Horizontal
        onWheel: (event) => {
            let maxScrollY = Math.max(0, taskbarRoot.contentHeight - taskbarRoot.height)
            let maxScrollX = Math.max(0, taskbarRoot.contentWidth - taskbarRoot.width)
            
            if (taskbarRoot.isVertical) {
                let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                taskbarRoot.contentY = Math.max(0, Math.min(taskbarRoot.contentY - delta, maxScrollY))
            } else {
                let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                taskbarRoot.contentX = Math.max(0, Math.min(taskbarRoot.contentX - delta, maxScrollX))
            }
        }
    }

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
            model: ScriptModel {
                values: Hyprland.toplevels.values
            }

            delegate: Item {
                id: clientDelegate
                
                readonly property bool isOnThisScreen: modelData.monitor && (modelData.monitor.name === taskbarRoot.activeScreenName)
                
                implicitWidth: isOnThisScreen ? 28 : 0
                implicitHeight: isOnThisScreen ? 28 : 0
                visible: isOnThisScreen

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
    }
}