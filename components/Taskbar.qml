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

    // Use boolean check to avoid unnecessary array allocations
    readonly property bool hasActiveClients: Hyprland.toplevels.values.some(c => !activeScreenName || !c.monitor || c.monitor.name === activeScreenName)
    readonly property int totalCount: hasActiveClients ? 1 : 0

    // Explicit static footprint avoids parent layout feedback loops
    implicitWidth: 28
    implicitHeight: 28
    Layout.preferredWidth: 28
    Layout.preferredHeight: 28

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
            text: Config.getIcon("apps")
            font.family: "Material Symbols Outlined"
            font.weight: Font.Bold
            font.pixelSize: 18
            color: Config.showTaskOverflow ? Config.accent : Config.textMain
        }

        // Active running indicator dot shown when open windows exist
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