import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import ".."

Rectangle {
    id: activeWinCard

    property var rootRef
    property string activeScreenName: (rootRef && rootRef.screen) ? rootRef.screen.name : ""

    // Target the focused/activated client on this monitor display
    readonly property var activeClient: {
        let clients = Hyprland.toplevels.values.filter(c => !activeScreenName || !c.monitor || c.monitor.name === activeScreenName)
        let active = clients.find(c => c.activated)
        if (active) return active
        if (Hyprland.activeToplevel && (!activeScreenName || !Hyprland.activeToplevel.monitor || Hyprland.activeToplevel.monitor.name === activeScreenName)) {
            return Hyprland.activeToplevel
        }
        return null
    }

    readonly property string appId: activeClient ? (activeClient.wayland?.appId || activeClient.lastIpcObject?.class || "") : ""
    readonly property string winTitle: activeClient ? (activeClient.title || appId || "") : ""
    readonly property bool hasWindow: activeClient !== null && winTitle !== ""

    visible: hasWindow

    // Card styling to match LeftModules and RightModules
    width: (rootRef && rootRef.isHorizontal)
        ? Math.min(contentRow.implicitWidth + 16, Math.max(120, (rootRef.width || 1920) - 600))
        : 36

    height: (rootRef && rootRef.isHorizontal)
        ? 36
        : Math.min(contentColumn.implicitHeight + 16, Math.max(120, (rootRef.height || 1080) - 600))

    radius: Config.cornerRadius / 2
    color: Qt.rgba(255, 255, 255, 0.05)
    clip: true

    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    // HORIZONTAL LAYOUT
    RowLayout {
        id: contentRow
        visible: rootRef && rootRef.isHorizontal
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        IconImage {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            asynchronous: true
            source: {
                if (!activeWinCard.appId) return Quickshell.iconPath("application-x-executable", true)
                let entry = DesktopEntries.heuristicLookup(activeWinCard.appId)
                if (entry && entry.icon) {
                    let path = Quickshell.iconPath(entry.icon, true)
                    if (path) return path
                }
                return Quickshell.iconPath(activeWinCard.appId, true) || Quickshell.iconPath("application-x-executable", true)
            }
        }

        Text {
            text: activeWinCard.winTitle
            color: Config.textMain
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // VERTICAL LAYOUT
    ColumnLayout {
        id: contentColumn
        visible: rootRef && !rootRef.isHorizontal
        anchors.fill: parent
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 8

        IconImage {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            source: {
                if (!activeWinCard.appId) return Quickshell.iconPath("application-x-executable", true)
                let entry = DesktopEntries.heuristicLookup(activeWinCard.appId)
                if (entry && entry.icon) {
                    let path = Quickshell.iconPath(entry.icon, true)
                    if (path) return path
                }
                return Quickshell.iconPath(activeWinCard.appId, true) || Quickshell.iconPath("application-x-executable", true)
            }
        }
    }
}
