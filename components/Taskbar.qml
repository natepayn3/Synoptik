import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Item {
    id: taskbarRoot
    property string activeScreenName: ""
    property bool isVertical: false

    signal popoutRequested(var item)
    property alias viewAppsBtn: btnViewApps

    // Inline Comment: Measure open windows for active display
    readonly property var activeClients: Hyprland.toplevels.values.filter(c => c.monitor && c.monitor.name === activeScreenName)
    readonly property int totalCount: activeClients.length

    // Static size locked to the single trigger button
    implicitWidth: 28
    implicitHeight: 28

    // Inline Comment: Only show single view_apps trigger button in the bar
    Rectangle {
        id: btnViewApps
        anchors.centerIn: parent
        implicitWidth: 28
        implicitHeight: 28
        radius: 8
        color: (Config.showTaskOverflow || viewAppsHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: "view_apps"
            font.family: "Material Symbols Outlined"
            font.weight: Font.Bold
            font.pixelSize: 18
            color: Config.showTaskOverflow ? Config.accent : Config.textMain
        }

        // Active running indicator dot when windows are open
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 2
            width: 4
            height: 4
            radius: 2
            color: Config.accent
            visible: taskbarRoot.totalCount > 0
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