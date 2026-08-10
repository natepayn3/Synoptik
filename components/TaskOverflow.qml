import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

Rectangle {
    id: overflowRoot

    property string activeScreenName: ""

    // Inline Comment: Fetch running windows on active display
    readonly property var activeClients: Hyprland.toplevels.values.filter(c => c.monitor && c.monitor.name === overflowRoot.activeScreenName)

    implicitWidth: 220
    implicitHeight: Math.max(64, mainCol.implicitHeight + 24)
    radius: Config.cornerRadius
    color: Qt.rgba(255, 255, 255, 0.05)

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            text: "RUNNING TASKS"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            font.bold: true
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

        Repeater {
            model: overflowRoot.activeClients

            delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: Config.cornerRadius / 2
                color: itemHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(0, 0, 0, 0.2)

                readonly property string appId: modelData.wayland?.appId || modelData.lastIpcObject?.class || ""

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
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