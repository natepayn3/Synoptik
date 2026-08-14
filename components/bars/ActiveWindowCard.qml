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

    readonly property string barPos: rootRef ? (rootRef.barPosition || "top") : "top"
    readonly property bool isHoriz: rootRef ? rootRef.isHorizontal : true

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

    signal popoutRequested(var item)

    // Rotation angle for text in vertical mode:
    // Left bar: 90 degrees (reads top-to-bottom)
    // Right bar: -90 degrees (reads bottom-to-top)
    readonly property real textRotation: {
        if (isHoriz) return 0
        return barPos === "left" ? 90 : -90
    }

    // STATIC FIXED DIMENSIONS - NO RESIZING
    width: isHoriz ? 190 : 36
    height: isHoriz ? 36 : 190

    radius: Config.cornerRadius / 2
    color: (Config.showTaskOverflow || cardHover.hovered) ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
    border.color: (Config.showTaskOverflow || cardHover.hovered) ? Config.accent : "transparent"
    border.width: (Config.showTaskOverflow || cardHover.hovered) ? 2 : 0
    clip: true

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    TapHandler {
        onTapped: {
            activeWinCard.popoutRequested(activeWinCard)
            if (rootRef) rootRef.setPopoutPos(activeWinCard)
            Config.showTaskOverflow = !Config.showTaskOverflow
        }
    }
    HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }

    // HORIZONTAL LAYOUT (Icon fixed left, ticker text fills remaining width)
    RowLayout {
        id: contentRow
        visible: isHoriz
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        IconImage {
            id: iconHoriz
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

        Item {
            id: tickerBoxHoriz
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Text {
                id: titleTextHoriz
                anchors.verticalCenter: parent.verticalCenter
                text: activeWinCard.winTitle
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true

                readonly property real overflowDist: Math.max(0, titleTextHoriz.implicitWidth - tickerBoxHoriz.width)
                readonly property bool needsTicker: overflowDist > 2

                x: 0

                SequentialAnimation on x {
                    id: tickerAnimHoriz
                    running: activeWinCard.isHoriz && titleTextHoriz.needsTicker && activeWinCard.visible
                    loops: 1

                    NumberAnimation {
                        to: -titleTextHoriz.overflowDist
                        duration: Math.max(1000, titleTextHoriz.overflowDist * 40)
                        easing.type: Easing.Linear
                    }
                }

                onTextChanged: {
                    x = 0
                    tickerAnimHoriz.restart()
                }
            }
        }
    }

    // VERTICAL LAYOUT (Icon fixed top, ticker text fills remaining height)
    ColumnLayout {
        id: contentColumn
        visible: !isHoriz
        anchors.fill: parent
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 8

        IconImage {
            id: iconVert
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

        Item {
            id: tickerBoxVert
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Item {
                id: titleTextVertWrapper
                anchors.centerIn: parent
                implicitWidth: titleTextVert.implicitHeight
                implicitHeight: titleTextVert.implicitWidth

                readonly property real overflowDist: Math.max(0, titleTextVert.implicitWidth - tickerBoxVert.height)
                readonly property bool needsTicker: overflowDist > 2

                property real tickerOffset: 0

                SequentialAnimation on tickerOffset {
                    id: tickerAnimVert
                    running: !activeWinCard.isHoriz && titleTextVertWrapper.needsTicker && activeWinCard.visible
                    loops: 1

                    NumberAnimation {
                        to: -titleTextVertWrapper.overflowDist
                        duration: Math.max(1000, titleTextVertWrapper.overflowDist * 40)
                        easing.type: Easing.Linear
                    }
                }

                Text {
                    id: titleTextVert
                    anchors.centerIn: parent
                    text: activeWinCard.winTitle
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.bold: true
                    rotation: activeWinCard.textRotation
                    transformOrigin: Item.Center
                    width: titleTextVertWrapper.implicitHeight

                    transform: Translate {
                        y: activeWinCard.barPos === "left" ? titleTextVertWrapper.tickerOffset : -titleTextVertWrapper.tickerOffset
                    }

                    onTextChanged: {
                        titleTextVertWrapper.tickerOffset = 0
                        tickerAnimVert.restart()
                    }
                }
            }
        }
    }
}
