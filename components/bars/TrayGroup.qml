import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import ".."

// The tray's presence on the bar: one icon per StatusNotifierItem, in the same
// card idiom as LeftModules/RightModules.
//
// Collapsed, only pinned items ride here and the rest stay reachable in the
// task popout - the same pin-versus-overflow split the icon groups already use
// (see ModuleLayoutConfig.pinnedIcons), rather than a second, different rule
// for the same idea.
Rectangle {
    id: trayCard

    property var rootRef
    signal popoutRequested(var item)

    readonly property bool isHoriz: rootRef ? rootRef.isHorizontal : true
    readonly property var barItems: Config.tray.barItems
    readonly property int shownCount: barItems.length

    // The whole card disappears when there's nothing to show, so an empty tray
    // costs no bar space at all rather than leaving a stub card behind.
    visible: Config.showTray && (shownCount > 0 || Config.tray.count > 0)

    readonly property real contentWidth: contentLoader.item ? contentLoader.item.implicitWidth : 0
    readonly property real contentHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0

    width: isHoriz ? Math.max(28, contentWidth + 12) : 36
    height: isHoriz ? 36 : Math.max(28, contentHeight + 12)

    // Clipping is what keeps icons from spilling out of the card while it
    // animates open or closed, but it would also cut the hover tooltips off at
    // the card edge - so it yields while the pointer is actually in here.
    clip: !groupHover.hovered

    radius: Config.cornerRadius / 2
    color: Qt.rgba(255, 255, 255, 0.05)
    // See LeftModules.qml's leftCard border for why this is suppressed under
    // the SDF renderer: it doubles up with the island background's own border.
    border.width: Config.experimentalSdfBar ? 0 : 1
    border.color: Qt.rgba(255, 255, 255, 0.1)

    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    HoverHandler { id: groupHover }

    // `anchorItem` is the icon that was clicked, passed on to the surface so the
    // menu opens under that icon rather than under the middle of the card.
    function openMenuFor(item, anchorItem) {
        if (!item) return
        if (rootRef && rootRef.stopPeek) rootRef.stopPeek()
        Config.openTrayMenu(item)
        if (Config.showTrayMenu) trayCard.popoutRequested(anchorItem || trayCard)
    }

    Loader {
        id: contentLoader
        anchors.fill: parent
        anchors.margins: 2
        sourceComponent: trayCard.isHoriz ? horizComp : vertComp
    }

    Component {
        id: horizComp
        RowLayout {
            spacing: 2
            Repeater {
                model: trayCard.barItems
                delegate: trayIconComp
            }
            // Collapse/expand handle. Present whenever there is anything to
            // collapse, so the control is never there doing nothing.
            Loader {
                Layout.alignment: Qt.AlignVCenter
                active: Config.tray.count > 0
                sourceComponent: collapseComp
            }
        }
    }

    Component {
        id: vertComp
        ColumnLayout {
            spacing: 2
            Repeater {
                model: trayCard.barItems
                delegate: trayIconComp
            }
            Loader {
                Layout.alignment: Qt.AlignHCenter
                active: Config.tray.count > 0
                sourceComponent: collapseComp
            }
        }
    }

    // --- ONE TRAY ICON ---
    Component {
        id: trayIconComp

        Rectangle {
            id: iconBtn
            required property var modelData

            readonly property var trayItem: modelData
            readonly property bool isOpenMenu: Config.showTrayMenu && Config.trayMenuItem === trayItem
            readonly property bool needsAttention: trayItem && trayItem.status === Status.NeedsAttention
            readonly property string label: Config.tray.labelFor(trayItem)
            readonly property string subLabel: Config.tray.subLabelFor(trayItem)

            implicitWidth: 28
            implicitHeight: 28
            Layout.alignment: trayCard.isHoriz ? Qt.AlignVCenter : Qt.AlignHCenter
            radius: 9
            color: iconBtn.isOpenMenu ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                anchors.centerIn: parent
                width: 18
                height: 18
                scale: iconHover.hovered ? 1.25 : 1.0

                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                IconImage {
                    id: trayIconImage
                    anchors.fill: parent
                    asynchronous: true
                    source: Config.tray.iconFor(iconBtn.trayItem)
                }

                // Apps that hand over neither a usable icon nor a theme name
                // would otherwise render as an invisible but clickable gap.
                Text {
                    anchors.centerIn: parent
                    visible: trayIconImage.status !== Image.Ready
                    text: "deployed_code"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 15
                    color: Config.textMain
                }
            }

            // NeedsAttention is the one piece of state SNI gives an app to say
            // "look at me" (a message waiting, a sync failure). A pulsing accent
            // dot is the shell's version of that, rather than dropping the
            // status on the floor like most bars do.
            Rectangle {
                visible: iconBtn.needsAttention
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 3
                width: 6
                height: 6
                radius: 3
                color: Config.accent

                SequentialAnimation on opacity {
                    running: iconBtn.needsAttention && Config.mascotAnimationsEnabled
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            // --- TOOLTIP ---
            Rectangle {
                z: 200
                anchors.bottom: trayCard.isHoriz ? parent.top : undefined
                anchors.bottomMargin: trayCard.isHoriz ? 6 : undefined
                anchors.right: trayCard.isHoriz ? undefined : parent.left
                anchors.rightMargin: trayCard.isHoriz ? undefined : 6
                anchors.horizontalCenter: trayCard.isHoriz ? parent.horizontalCenter : undefined
                anchors.verticalCenter: trayCard.isHoriz ? undefined : parent.verticalCenter
                implicitWidth: tipCol.implicitWidth + 14
                implicitHeight: tipCol.implicitHeight + 10
                radius: 6
                color: Qt.rgba(10, 12, 16, 0.95)
                border.width: 1
                border.color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.4)
                visible: opacity > 0
                opacity: (iconHover.hovered && iconBtn.label !== "") ? 1.0 : 0.0

                Behavior on opacity { NumberAnimation { duration: 150 } }

                Column {
                    id: tipCol
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        text: iconBtn.label
                        font.family: Config.sysFont
                        font.pixelSize: 10
                        font.bold: true
                        color: Config.accent
                    }

                    // tooltipDescription is where apps put the part that
                    // actually changes - "3 unread", "Sync error on Photos".
                    Text {
                        visible: iconBtn.subLabel !== ""
                        text: iconBtn.subLabel
                        font.family: Config.sysFont
                        font.pixelSize: 9
                        color: Config.textMuted
                        width: Math.min(implicitWidth, 220)
                        elide: Text.ElideRight
                    }
                }
            }

            // Left opens the app, right opens its menu, middle is SNI's
            // secondary action - the bindings every other tray uses, so muscle
            // memory from waybar/Plasma carries over unchanged.
            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: {
                    if (rootRef && rootRef.stopPeek) rootRef.stopPeek()
                    // The bound closure is how an onlyMenu item (one with no
                    // activate() behaviour at all) still does something useful
                    // on a plain left click - see TrayService.primaryAction.
                    Config.tray.primaryAction(iconBtn.trayItem, it => trayCard.openMenuFor(it, iconBtn))
                }
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: trayCard.openMenuFor(iconBtn.trayItem, iconBtn)
            }

            TapHandler {
                acceptedButtons: Qt.MiddleButton
                onTapped: {
                    if (iconBtn.trayItem) iconBtn.trayItem.secondaryActivate()
                }
            }

            // Scroll passthrough: volume applets and the like are driven this
            // way, and an icon that ignores the wheel feels broken next to one
            // that doesn't.
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (!iconBtn.trayItem) return
                    if (event.angleDelta.y !== 0) iconBtn.trayItem.scroll(event.angleDelta.y, false)
                    if (event.angleDelta.x !== 0) iconBtn.trayItem.scroll(event.angleDelta.x, true)
                }
            }

            HoverHandler {
                id: iconHover
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered && rootRef && rootRef.startPeek) rootRef.startPeek(iconBtn)
                    else if (!hovered && rootRef && rootRef.stopPeek) rootRef.stopPeek()
                }
            }
        }
    }

    // --- COLLAPSE HANDLE ---
    Component {
        id: collapseComp

        Rectangle {
            id: collapseBtn
            implicitWidth: 18
            implicitHeight: 28
            radius: 8
            color: collapseHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            readonly property int hiddenCount: Config.tray.count - trayCard.shownCount

            Text {
                anchors.centerIn: parent
                text: Config.trayCollapsed ? "chevron_left" : "chevron_right"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 14
                color: collapseHover.hovered ? Config.accent : Config.textMuted
                rotation: trayCard.isHoriz ? 0 : 90

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // Collapsed with items tucked away, the handle carries the count so
            // the bar still admits they exist.
            Rectangle {
                visible: collapseBtn.hiddenCount > 0
                anchors.right: parent.right
                anchors.top: parent.top
                width: 5
                height: 5
                radius: 2.5
                color: Config.accent
                opacity: 0.8
            }

            TapHandler { onTapped: Config.trayCollapsed = !Config.trayCollapsed }
            HoverHandler { id: collapseHover; cursorShape: Qt.PointingHandCursor }
        }
    }
}
