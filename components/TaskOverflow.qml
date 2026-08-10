import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

Item {
    id: overflowRoot

    // Inline Comment: Exact card margin logic matching BatteryCard structure
    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    property string activeScreenName: ""

    // Inline Comment: Fallback filter ensuring open windows display even if activeScreenName isn't set yet
    readonly property var activeClients: Hyprland.toplevels.values.filter(c => !activeScreenName || !c.monitor || c.monitor.name === overflowRoot.activeScreenName)

    implicitWidth: mainLayout.implicitWidth + (cardMargin * 2)
    implicitHeight: mainLayout.implicitHeight + (cardMargin * 2)

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: overflowRoot.cardMargin
        spacing: overflowRoot.cardMargin

        // Primary Inner Card Box (Matches Battery Card 1 Structure)
        Rectangle {
            Layout.fillWidth: true
            implicitWidth: 280
            implicitHeight: cardContentLayout.implicitHeight + (overflowRoot.cardMargin * 2)
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.05)

            ColumnLayout {
                id: cardContentLayout
                anchors.fill: parent
                anchors.margins: overflowRoot.cardMargin
                spacing: overflowRoot.cardMargin

                // Header
                Text {
                    text: "RUNNING TASKS"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontTitle)
                    font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    visible: overflowRoot.activeClients.length === 0
                    text: "No active windows"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                }

                // Window Items List
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: overflowRoot.activeClients

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: Config.cornerRadius / 2
                            color: itemHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(0, 0, 0, 0.25)

                            readonly property string appId: modelData.wayland?.appId || modelData.lastIpcObject?.class || ""

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                IconImage {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    asynchronous: true
                                    source: {
                                        let id = parent.parent.appId
                                        if (!id) return ""
                                        let entry = DesktopEntries.heuristicLookup(id)
                                        if (entry && entry.icon) {
                                            let path = Quickshell.iconPath(entry.icon, true)
                                            if (path) return path
                                        }
                                        return Quickshell.iconPath(id, true) || Quickshell.iconPath("application-x-executable", true)
                                    }
                                }

                                Text {
                                    text: modelData.title || parent.parent.appId || "Window"
                                    color: modelData.activated ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontBody)
                                    font.bold: modelData.activated
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    if (modelData.wayland) modelData.wayland.activate()
                                    Config.showTaskOverflow = false
                                }
                            }
                            HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }
        }
    }
}