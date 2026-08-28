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

    // Inline Comment: Every running client, across all workspaces and monitors (not just the
    // currently-focused workspace). Sorted: active window first, then grouped by workspace.
    readonly property var activeClients: {
        let all = Hyprland.toplevels.values.slice()
        all.sort((a, b) => {
            if (a.activated !== b.activated) return a.activated ? -1 : 1
            let wsA = (a.workspace && a.workspace.id !== undefined) ? a.workspace.id : 0
            let wsB = (b.workspace && b.workspace.id !== undefined) ? b.workspace.id : 0
            if (wsA !== wsB) return wsA - wsB
            return (a.title || "").localeCompare(b.title || "")
        })
        return all
    }

    implicitWidth: mainLayout.implicitWidth + (cardMargin * 2)
    implicitHeight: mainLayout.implicitHeight + (cardMargin * 2)

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: overflowRoot.cardMargin
        spacing: overflowRoot.cardMargin

        // Inner Surface Frame
        // ClippingRectangle (not plain Rectangle) so the watermark actually
        // respects the rounded corners instead of bleeding past them - plain
        // Rectangle.clip only clips to the square bounding box.
        ClippingRectangle {
            Layout.fillWidth: true
            implicitWidth: 270
            implicitHeight: cardContentLayout.implicitHeight + (overflowRoot.cardMargin * 2)
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.05)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)

            Behavior on border.color { ColorAnimation { duration: 150 } }

            // GRAPHIC WATERMARK
            Watermark {
                icon: Config.getIcon("apps")
                iconSize: 120
                seed: 12
            }

            ColumnLayout {
                id: cardContentLayout
                anchors.fill: parent
                anchors.margins: overflowRoot.cardMargin
                spacing: 8

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
                    font.pixelSize: Config.size(Config.fontCaption)
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }

                // Single Column Task List
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: overflowRoot.activeClients

                        delegate: Rectangle {
                            id: taskDelegate
                            // Deliberately NOT a `required property int index` - that flips
                            // this delegate into Qt Quick's required-property injection mode,
                            // which silently drops the legacy implicit `modelData` context
                            // property the rest of this delegate relies on everywhere else.
                            // Bare `index` below is the same implicit context property.

                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: Config.cornerRadius / 2
                            color: itemHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(0, 0, 0, 0.25)

                            Behavior on color { ColorAnimation { duration: 150 } }

                            // Staggered entrance so the list cascades in on
                            // open instead of every row snapping in at once.
                            // The delegates persist across open/close (this
                            // panel is always-instantiated, just visibility-
                            // toggled - see UnifiedSurface.qml), so replay on
                            // each visible transition rather than just once.
                            opacity: 0
                            transform: Translate { id: entranceOffset; y: -8 }

                            SequentialAnimation {
                                id: entranceAnim
                                PauseAnimation { duration: index * 25 }
                                ParallelAnimation {
                                    NumberAnimation { target: taskDelegate; property: "opacity"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: entranceOffset; property: "y"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                                }
                            }

                            Connections {
                                target: overflowRoot
                                function onVisibleChanged() {
                                    if (overflowRoot.visible) {
                                        taskDelegate.opacity = 0
                                        entranceOffset.y = -8
                                        entranceAnim.restart()
                                    }
                                }
                            }

                            Component.onCompleted: if (overflowRoot.visible) entranceAnim.start()

                            readonly property string appId: modelData.wayland?.appId || modelData.lastIpcObject?.class || ""
                            readonly property var wsInfo: modelData.workspace || null
                            readonly property string wsLabel: wsInfo ? String(wsInfo.name || wsInfo.id || "") : ""

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                IconImage {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
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
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: modelData.activated
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    visible: parent.parent.wsLabel !== ""
                                    implicitWidth: wsLabelText.implicitWidth + 10
                                    implicitHeight: 16
                                    radius: 8
                                    color: Qt.rgba(255, 255, 255, 0.08)

                                    Text {
                                        id: wsLabelText
                                        anchors.centerIn: parent
                                        text: parent.parent.parent.wsLabel
                                        color: Config.textMuted
                                        font.family: Config.sysFont
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
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