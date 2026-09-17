import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: overflowRoot

    // Inline Comment: Card margin token pulled from global Config
    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    property string activeScreenName: ""

    // The row the pointer is on, and - separately - what the preview is
    // actually showing.
    //
    // These were one property, and the preview pane grew from 0 to its full
    // height whenever it was set. Two things went wrong with that. The pane's
    // height feeds this item's implicitHeight, which is what UnifiedSurface
    // measures to size the whole morphing surface, so every frame of that
    // little animation re-laid-out and re-animated the entire bar - while a
    // live screencopy was running inside it. And sweeping down the list
    // cleared the property between rows, so each row boundary crossed meant a
    // full collapse, capture teardown, capture rebuild and re-expand.
    //
    // Now the pane is a fixed height that never animates, and the capture
    // source only follows the pointer once it settles. Un-hovering deliberately
    // does NOT clear it: keeping the last window on screen is both more useful
    // and one less reason to tear a capture down.
    property var hoveredClient: null
    property var previewClient: null

    property Timer previewSettleTimer: Timer {
        interval: 90
        repeat: false
        onTriggered: overflowRoot.previewClient = overflowRoot.hoveredClient
    }

    onHoveredClientChanged: {
        if (hoveredClient) previewSettleTimer.restart()
    }

    onVisibleChanged: {
        hoveredClient = null
        previewSettleTimer.stop()
        // Opening on the focused window means the pane is never empty, and
        // never has to grow into place the first time the pointer lands.
        previewClient = visible && activeClients.length > 0 ? activeClients[0] : null
    }

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

                // --- LIVE PREVIEW ---
                // The same ScreencopyView the workspace overview uses, pointed
                // at one window instead of a whole monitor. Collapsed to zero
                // height when nothing is hovered, so the popout is no taller
                // than the list until you actually ask to see something.
                Item {
                    Layout.fillWidth: true
                    clip: true
                    // Deliberately a constant. See the comment on previewClient
                    // above for what animating this cost.
                    implicitHeight: 132
                    visible: overflowRoot.activeClients.length > 0

                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: 4
                        radius: Config.cornerRadius / 2
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.1)

                        ScreencopyView {
                            id: previewCapture
                            anchors.fill: parent
                            anchors.margins: 1
                            captureSource: (overflowRoot.previewClient && overflowRoot.previewClient.wayland)
                                ? overflowRoot.previewClient.wayland
                                : null
                            // Only while the popout is up: a live capture is a
                            // continuous copy of that window's buffer, not a
                            // still, so leaving it running would keep costing
                            // frames after the panel closed.
                            live: overflowRoot.visible
                            paintCursor: false
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: overflowRoot.previewClient === null
                            text: "Hover a window to preview it"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                        }

                        // Which window you're looking at - without it the pane
                        // is an unlabelled rectangle whenever the pointer has
                        // moved on but the preview has stayed put.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            implicitHeight: 18
                            color: Qt.rgba(0, 0, 0, 0.6)
                            visible: overflowRoot.previewClient !== null

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                verticalAlignment: Text.AlignVCenter
                                text: overflowRoot.previewClient ? (overflowRoot.previewClient.title || "") : ""
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }
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
                                    source: Config.appIconFor(parent.parent.appId)
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

                                // The list was entirely read-only: it could
                                // take you to a window but never do anything
                                // with one. Closing is the action you actually
                                // want from a list of everything running.
                                Rectangle {
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    radius: 10
                                    color: closeHover.containsMouse ? Qt.rgba(239, 68, 68, 0.9) : Qt.rgba(255, 255, 255, 0.08)
                                    opacity: itemHover.hovered ? 1.0 : 0.0

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "close"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 12
                                        color: closeHover.containsMouse ? "#ffffff" : Config.textMuted
                                    }

                                    // MouseArea, not TapHandler: the row itself
                                    // carries a TapHandler that focuses the
                                    // window, and only an accepting MouseArea
                                    // reliably stops a click on this button from
                                    // reaching it too.
                                    MouseArea {
                                        id: closeHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (modelData.wayland) modelData.wayland.close()
                                    }
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    if (modelData.wayland) modelData.wayland.activate()
                                    Config.showTaskOverflow = false
                                }
                            }

                            // Middle-click to close, the convention every
                            // taskbar shares - paired with the button below so
                            // it isn't the only way to do it.
                            TapHandler {
                                acceptedButtons: Qt.MiddleButton
                                onTapped: if (modelData.wayland) modelData.wayland.close()
                            }

                            HoverHandler {
                                id: itemHover
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: {
                                    if (hovered) overflowRoot.hoveredClient = modelData
                                }
                            }
                        }
                    }
                }

                // --- BACKGROUND APPS (SYSTEM TRAY) ---
                // The half of "what is running" that the window list above
                // structurally cannot see: an app closed to its tray icon owns
                // no toplevel, so Hyprland never reports it. Listing both here
                // is what makes this popout an honest inventory rather than a
                // window switcher wearing the name.
                //
                // Every tray item appears, including the ones already on the
                // bar, because this is also where they are managed - the pin
                // button on each row is what puts an icon on the bar or takes
                // it off again.
                Item {
                    visible: Config.showTray && Config.tray.count > 0
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: trayHeaderText.implicitHeight

                    Glow {
                        anchors.fill: trayHeaderText
                        source: trayHeaderText
                        radius: 8
                        samples: 16
                        color: Config.accent
                        spread: 0.2
                        transparentBorder: true
                        visible: Config.clockShowGlow
                    }

                    Text {
                        id: trayHeaderText
                        anchors.fill: parent
                        text: "BACKGROUND APPS"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontTitle)
                        font.bold: true
                        font.italic: true
                    }
                }

                ColumnLayout {
                    visible: Config.showTray && Config.tray.count > 0
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: Config.tray.items

                        delegate: Rectangle {
                            id: trayRow
                            required property var modelData

                            readonly property var trayItem: modelData
                            readonly property bool isPinned: Config.tray.isPinned(trayItem)
                            readonly property string label: Config.tray.labelFor(trayItem)
                            readonly property string subLabel: Config.tray.subLabelFor(trayItem)

                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: Config.cornerRadius / 2
                            color: trayHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(0, 0, 0, 0.25)

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 6
                                spacing: 8

                                Item {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22

                                    IconImage {
                                        id: trayRowIcon
                                        anchors.fill: parent
                                        asynchronous: true
                                        source: Config.tray.iconFor(trayRow.trayItem)
                                    }

                                    // An app whose icon resolves to nothing at
                                    // all would otherwise be a blank gap with a
                                    // name beside it. Same glyph the bar group
                                    // falls back to.
                                    Text {
                                        anchors.centerIn: parent
                                        visible: trayRowIcon.status !== Image.Ready
                                        text: "deployed_code"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 17
                                        color: Config.textMuted
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        text: trayRow.label
                                        color: Config.textMain
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontCaption)
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: trayRow.subLabel !== ""
                                        text: trayRow.subLabel
                                        color: Config.textMuted
                                        font.family: Config.sysFont
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                // Pin. Dimmed until hovered or actually pinned,
                                // so a row of unpinned apps doesn't read as a
                                // column of buttons demanding attention.
                                Rectangle {
                                    implicitWidth: 22
                                    implicitHeight: 22
                                    radius: Config.cornerRadius / 2
                                    color: pinHover.containsMouse ? Qt.rgba(255, 255, 255, 0.18) : "transparent"
                                    opacity: (trayRow.isPinned || trayHover.hovered) ? 1.0 : 0.0

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: trayRow.isPinned ? "keep" : "keep_off"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 13
                                        color: trayRow.isPinned ? Config.accent : Config.textMuted
                                    }

                                    MouseArea {
                                        id: pinHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Config.tray.togglePin(trayRow.trayItem)
                                    }
                                }

                                Rectangle {
                                    implicitWidth: 22
                                    implicitHeight: 22
                                    radius: Config.cornerRadius / 2
                                    visible: trayRow.trayItem && trayRow.trayItem.hasMenu
                                    color: menuHover.containsMouse ? Qt.rgba(255, 255, 255, 0.18) : "transparent"

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "more_vert"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 14
                                        color: menuHover.containsMouse ? Config.accent : Config.textMuted
                                    }

                                    // Opening the menu closes this popout -
                                    // Config.closePanels() arbitrates the two as
                                    // mutually exclusive views of one surface,
                                    // so the bar morphs from the list into the
                                    // menu in place.
                                    MouseArea {
                                        id: menuHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Config.openTrayMenu(trayRow.trayItem)
                                    }
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    Config.tray.primaryAction(trayRow.trayItem, it => Config.openTrayMenu(it))
                                    if (!Config.showTrayMenu) Config.showTaskOverflow = false
                                }
                            }
                            HoverHandler { id: trayHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }
        }
    }
}