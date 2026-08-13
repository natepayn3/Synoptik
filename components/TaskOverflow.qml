import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

Item {
    id: overflowRoot

    // Inline Comment: Card margin token pulled from global Config
    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    property string activeScreenName: ""

    // Inline Comment: Running client instances on current active display
    readonly property var activeClients: Hyprland.toplevels.values.filter(c => !activeScreenName || !c.monitor || c.monitor.name === overflowRoot.activeScreenName)

    implicitWidth: mainLayout.implicitWidth + (cardMargin * 2)
    implicitHeight: mainLayout.implicitHeight + (cardMargin * 2)

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: overflowRoot.cardMargin
        spacing: overflowRoot.cardMargin

        // Inner Surface Frame
        Rectangle {
            Layout.fillWidth: true
            implicitWidth: 320
            implicitHeight: cardContentLayout.implicitHeight + (overflowRoot.cardMargin * 2)
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.05)
            clip: true

            // GRAPHIC WATERMARK
            Item {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -15
                anchors.bottomMargin: -20
                implicitWidth: 150
                implicitHeight: 150
                visible: Config.showWatermarks

                Text {
                    anchors.centerIn: parent
                    text: Config.getIcon("apps")
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 150
                    color: Config.accent
                    opacity: 0.12
                    rotation: 15
                }
            }

            ColumnLayout {
                id: cardContentLayout
                anchors.fill: parent
                anchors.margins: overflowRoot.cardMargin
                spacing: overflowRoot.cardMargin

                // Header
                Item {
                    implicitWidth: taskTitleText.implicitWidth
                    implicitHeight: taskTitleText.implicitHeight
                    Layout.fillWidth: true

                    Glow {
                        anchors.fill: taskTitleText
                        source: taskTitleText
                        radius: 8
                        samples: 16
                        color: Config.accent
                        spread: 0.2
                        transparentBorder: true
                        visible: Config.clockShowGlow
                    }

                    Text {
                        id: taskTitleText
                        anchors.fill: parent
                        text: "RUNNING TASKS"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontTitle)
                        font.bold: true
                        font.italic: true
                    }
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

                // Single Column Task List
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: overflowRoot.activeClients

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 52
                            radius: Config.cornerRadius / 1.5
                            color: itemHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(0, 0, 0, 0.25)

                            Behavior on color { ColorAnimation { duration: 150 } }

                            readonly property string appId: modelData.wayland?.appId || modelData.lastIpcObject?.class || ""

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                spacing: 12

                                IconImage {
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 36
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