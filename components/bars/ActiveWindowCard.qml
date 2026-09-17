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

    // This monitor's own active workspace, which is what the card is really
    // about: one bar instance exists per screen, and each should describe its
    // own screen rather than all of them echoing whichever monitor happens to
    // hold keyboard focus.
    readonly property var thisMonitor: {
        if (!activeScreenName) return Hyprland.focusedMonitor
        let mons = Hyprland.monitors ? Hyprland.monitors.values : []
        for (let i = 0; i < mons.length; i++) {
            if (mons[i] && mons[i].name === activeScreenName) return mons[i]
        }
        return null
    }

    // Focused client resolution, per monitor.
    //
    // The fast path is still Hyprland.activeToplevel - when the focused window
    // is on this screen, that's the answer without touching the toplevel list.
    //
    // The slow path replaces a fallback that never worked: it was guarded on
    // `Hyprland.focusedMonitor.name === activeScreenName`, i.e. it only ran when
    // this monitor WAS the focused one, and then returned the very
    // Hyprland.activeToplevel the fast path had just rejected. Its comment
    // claimed to handle "activeToplevel is on another monitor" - the one case
    // the guard made unreachable. So on a multi-monitor setup every unfocused
    // monitor's card went blank instead of showing that monitor's window.
    //
    // The scan is O(n) over toplevels, but only on the path the old code got
    // wrong, and n here is "windows you have open" - a couple of dozen at the
    // extreme, re-evaluated only when Hyprland signals a change.
    readonly property var activeClient: {
        let top = Hyprland.activeToplevel
        if (top && top.activated) {
            let matchesScreen = !activeScreenName || !top.monitor || top.monitor.name === activeScreenName
            if (matchesScreen) return top
        }

        // Focus is elsewhere: show the most recently focused window on this
        // monitor's active workspace. Hyprland's per-client focusHistoryID is
        // exactly that ordering (0 = most recent), so this keeps showing the
        // window you'd land on if you moved focus back here, rather than an
        // arbitrary pick that reshuffles whenever the toplevel list reorders.
        let ws = thisMonitor ? thisMonitor.activeWorkspace : null
        if (!ws) return null

        let all = Hyprland.toplevels ? Hyprland.toplevels.values : []
        let best = null
        let bestRank = Infinity
        for (let i = 0; i < all.length; i++) {
            let t = all[i]
            if (!t || !t.workspace || t.workspace.id !== ws.id) continue

            let hist = t.lastIpcObject ? t.lastIpcObject.focusHistoryID : undefined
            // No focusHistoryID (an IPC object not refreshed yet) sorts behind
            // every window that has one, instead of tying at 0 and winning.
            let rank = (hist === undefined || hist === null) ? Number.MAX_SAFE_INTEGER : hist
            if (rank < bestRank) {
                bestRank = rank
                best = t
            }
        }
        return best
    }

    readonly property string appId: activeClient ? (activeClient.wayland?.appId || activeClient.lastIpcObject?.class || "") : ""
    readonly property string winTitle: activeClient ? (activeClient.title || appId || "") : ""
    readonly property bool hasWindow: activeClient !== null && winTitle !== ""

    // --- NOW PLAYING ---
    // Media used to take the card over outright whenever mpris reported
    // something playing, which meant that for as long as music was on there was
    // no way to see the focused window's title - the one thing this card exists
    // to tell you. Config.activeWindowMediaMode picks the behaviour now;
    // "takeover" is still available and is exactly what this did before.
    readonly property bool mediaPlaying: (typeof shellRoot !== "undefined") && shellRoot.mediaPlaying === true
    readonly property string mediaMode: Config.activeWindowMediaMode || "chip"
    readonly property bool mediaActive: mediaPlaying && mediaMode !== "off"
    readonly property string mediaArtUrl: (typeof shellRoot !== "undefined" && shellRoot.mediaArtUrl) ? shellRoot.mediaArtUrl : ""

    // With no window to show, chip mode has nothing to defer to, so it falls
    // through to the takeover layout rather than rendering an empty card with a
    // chip stuck on the end of it.
    readonly property bool mediaTakesOver: mediaActive && (mediaMode === "takeover" || !hasWindow)
    readonly property bool showArtChip: mediaActive && !mediaTakesOver

    // Hovering the chip swaps the title line to the track for as long as you
    // hold there - the whole track name, without permanently spending the
    // card's one line of text on it.
    readonly property bool chipPeek: showArtChip && (artChipHoriz.peeking || artChipVert.peeking)
    readonly property string displayTitle: (mediaTakesOver || chipPeek) ? shellRoot.mediaTitle : winTitle

    visible: hasWindow || mediaActive

    function togglePlayback() {
        Quickshell.execDetached(["playerctl", "--player=%any,playerctld", "play-pause"])
    }

    signal popoutRequested(var item)

    // Rotation angle for text in vertical mode
    readonly property real textRotation: {
        if (isHoriz) return 0
        return barPos === "left" ? -90 : 90
    }

    // Dynamic dimensions
    property real maxAvailableSpan: 190
    width: isHoriz ? Math.max(36, Math.min(190, maxAvailableSpan)) : 36
    height: isHoriz ? 36 : Math.max(36, Math.min(190, maxAvailableSpan))

    radius: Config.cornerRadius / 2
    color: (Config.showTaskOverflow || cardHover.hovered) ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
    // Every border here (idle AND hover) doubled up with the unified island
    // background's own border under the SDF renderer - same as
    // LeftModules/RightModules for the idle case, but the hover/active
    // border was worse: a standalone 2px accent-colored box popping up out
    // of an otherwise borderless bar reads as even less cohesive than the
    // constant 1px double-border did. The background tint above is already
    // how every other bar icon shows hover/active state (see e.g.
    // RightModules' btnSearchHoriz) - this card doesn't need its own border
    // to do the same job.
    border.width: Config.experimentalSdfBar ? 0 : ((Config.showTaskOverflow || cardHover.hovered) ? 2 : 1)
    border.color: (Config.showTaskOverflow || cardHover.hovered) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
    clip: true

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    TapHandler {
        onTapped: {
            if (rootRef && rootRef.stopPeek) rootRef.stopPeek()
            activeWinCard.popoutRequested(activeWinCard)
            if (rootRef) rootRef.setPopoutPos(activeWinCard)
            Config.showTaskOverflow = !Config.showTaskOverflow
        }
    }

    HoverHandler { 
        id: cardHover
        cursorShape: Qt.PointingHandCursor 
        onHoveredChanged: {
            if (hovered) {
                if (rootRef && rootRef.startPeek) rootRef.startPeek(activeWinCard)
            } else {
                if (rootRef && rootRef.stopPeek) rootRef.stopPeek()
            }
        }
    }

    // HORIZONTAL LAYOUT
    RowLayout {
        id: contentRow
        visible: isHoriz
        anchors.fill: parent
        anchors.leftMargin: activeWinCard.width <= 44 ? 0 : 10
        anchors.rightMargin: activeWinCard.width <= 44 ? 0 : 10
        spacing: activeWinCard.width <= 44 ? 0 : 8

        IconImage {
            id: iconHoriz
            visible: !activeWinCard.mediaTakesOver
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: activeWinCard.width <= 44 ? Qt.AlignCenter : Qt.AlignVCenter
            asynchronous: true
            source: Config.appIconFor(activeWinCard.appId)
        }

        Item {
            id: artBoxHoriz
            visible: activeWinCard.mediaTakesOver
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: activeWinCard.width <= 44 ? Qt.AlignCenter : Qt.AlignVCenter
            clip: true

            Image {
                id: artImageHoriz
                anchors.fill: parent
                source: activeWinCard.mediaArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                text: "music_note"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 14
                color: Config.textMuted
                visible: artImageHoriz.status !== Image.Ready
            }
        }

        Item {
            id: tickerBoxHoriz
            visible: activeWinCard.width > 50
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            readonly property real overflowDist: Math.max(0, titleTextHoriz.implicitWidth - tickerBoxHoriz.width)
            readonly property bool needsTicker: overflowDist > 2

            // Rearms the ticker from a clean x:0 state instead of leaving stop()/start()
            // to fight a declarative `running:` binding - calling .restart() on an
            // animation with a bound `running` property overwrites that binding with a
            // literal, so a restart mid-flight (e.g. a title change while the card is
            // momentarily narrow, giving a wildly wrong overflowDist) could strand the
            // text scrolled out past the clip with nothing left to ever reset it.
            function refreshTicker() {
                tickerAnimHoriz.stop()
                titleTextHoriz.x = 0
                if (activeWinCard.isHoriz && tickerBoxHoriz.needsTicker && activeWinCard.visible && tickerBoxHoriz.visible) {
                    tickerAnimHoriz.start()
                }
            }

            onNeedsTickerChanged: refreshTicker()
            onWidthChanged: refreshTicker()
            onVisibleChanged: refreshTicker()

            // Scroll out, hold on the tail, ease back, hold on the head, repeat.
            // This used to be `loops: 1` with only the outward leg, so a long
            // title crawled to its end once and then sat there permanently
            // truncated at the FRONT - the half you actually need to identify a
            // window - until the title text happened to change. The return leg
            // is eased rather than linear so it reads as a rewind, not a second
            // pass of the same scroll.
            SequentialAnimation {
                id: tickerAnimHoriz
                loops: Animation.Infinite

                PauseAnimation { duration: 1000 }

                NumberAnimation {
                    target: titleTextHoriz
                    property: "x"
                    to: -tickerBoxHoriz.overflowDist
                    duration: Math.max(1000, tickerBoxHoriz.overflowDist * 40)
                    easing.type: Easing.Linear
                }

                PauseAnimation { duration: 1600 }

                NumberAnimation {
                    target: titleTextHoriz
                    property: "x"
                    to: 0
                    duration: Math.max(450, tickerBoxHoriz.overflowDist * 8)
                    easing.type: Easing.InOutCubic
                }
            }

            Text {
                id: titleTextHoriz
                anchors.verticalCenter: parent.verticalCenter
                text: activeWinCard.displayTitle
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true

                onTextChanged: tickerBoxHoriz.refreshTicker()
            }
        }

        // --- NOW-PLAYING CHIP ---
        // A MouseArea, not a TapHandler: the card itself carries a TapHandler
        // that toggles the task list, and an accepting MouseArea is what stops
        // a tap on the chip from also opening that popout behind it.
        Item {
            id: artChipHoriz
            visible: activeWinCard.showArtChip && activeWinCard.width > 66
            property bool peeking: visible && chipMouseHoriz.containsMouse
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18

            Rectangle {
                anchors.fill: parent
                radius: 5
                clip: true
                color: Qt.rgba(255, 255, 255, 0.08)
                border.width: 1
                border.color: chipMouseHoriz.containsMouse ? Config.accent : Qt.rgba(255, 255, 255, 0.14)
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Image {
                    id: chipArtHoriz
                    anchors.fill: parent
                    source: activeWinCard.mediaArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    opacity: chipMouseHoriz.containsMouse ? 0.35 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                // Shown when there's no art to show, and again under the hover
                // dim as the affordance that the chip is a play/pause button.
                Text {
                    anchors.centerIn: parent
                    text: chipMouseHoriz.containsMouse
                        ? (activeWinCard.mediaPlaying ? "pause" : "play_arrow")
                        : "music_note"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 12
                    color: chipMouseHoriz.containsMouse ? Config.accent : Config.textMuted
                    visible: chipMouseHoriz.containsMouse || chipArtHoriz.status !== Image.Ready
                }
            }

            MouseArea {
                id: chipMouseHoriz
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: activeWinCard.togglePlayback()
            }
        }
    }

    // VERTICAL LAYOUT (Icon positioned at the leading start of the text reading direction)
    GridLayout {
        id: contentColumn
        visible: !isHoriz
        anchors.fill: parent
        anchors.topMargin: activeWinCard.height <= 44 ? 0 : 10
        anchors.bottomMargin: activeWinCard.height <= 44 ? 0 : 10
        columnSpacing: 0
        rowSpacing: activeWinCard.height <= 44 ? 0 : 8
        columns: 1
        // Three rows since the now-playing chip joined: the icon sits at the
        // leading end of the reading direction, the chip at the trailing end,
        // which swap places between a left bar (text rotated -90, reading
        // bottom-to-top) and a right one.
        rows: 3

        IconImage {
            id: iconVert
            visible: !activeWinCard.mediaTakesOver
            Layout.row: activeWinCard.barPos === "left" ? 2 : 0
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: activeWinCard.height <= 44 ? Qt.AlignCenter : Qt.AlignHCenter
            asynchronous: true
            source: Config.appIconFor(activeWinCard.appId)
        }

        Item {
            id: artBoxVert
            visible: activeWinCard.mediaTakesOver
            Layout.row: activeWinCard.barPos === "left" ? 2 : 0
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: activeWinCard.height <= 44 ? Qt.AlignCenter : Qt.AlignHCenter
            clip: true

            Image {
                id: artImageVert
                anchors.fill: parent
                source: activeWinCard.mediaArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                text: "music_note"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 14
                color: Config.textMuted
                visible: artImageVert.status !== Image.Ready
            }
        }

        Item {
            id: tickerBoxVert
            Layout.row: 1
            visible: activeWinCard.height > 50
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            readonly property real overflowDist: Math.max(0, titleTextVert.implicitWidth - tickerBoxVert.height)
            readonly property bool needsTicker: overflowDist > 2
            readonly property bool isCcw: activeWinCard.textRotation === -90
            property real tickerOffset

            // See refreshTicker() in tickerBoxHoriz for why this can't be a
            // declarative `running:` binding combined with .restart() calls.
            function refreshTicker() {
                tickerAnimVert.stop()
                tickerBoxVert.tickerOffset = 0
                if (!activeWinCard.isHoriz && tickerBoxVert.needsTicker && activeWinCard.visible && tickerBoxVert.visible) {
                    tickerAnimVert.start()
                }
            }

            onNeedsTickerChanged: refreshTicker()
            onHeightChanged: refreshTicker()
            onVisibleChanged: refreshTicker()

            // See tickerAnimHoriz for why this loops and returns.
            SequentialAnimation {
                id: tickerAnimVert
                loops: Animation.Infinite

                PauseAnimation { duration: 1000 }

                NumberAnimation {
                    target: tickerBoxVert
                    property: "tickerOffset"
                    to: tickerBoxVert.isCcw ? tickerBoxVert.overflowDist : -tickerBoxVert.overflowDist
                    duration: Math.max(1000, tickerBoxVert.overflowDist * 40)
                    easing.type: Easing.Linear
                }

                PauseAnimation { duration: 1600 }

                NumberAnimation {
                    target: tickerBoxVert
                    property: "tickerOffset"
                    to: 0
                    duration: Math.max(450, tickerBoxVert.overflowDist * 8)
                    easing.type: Easing.InOutCubic
                }
            }

            Text {
                id: titleTextVert
                text: activeWinCard.displayTitle
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true

                transformOrigin: Item.TopLeft
                rotation: activeWinCard.textRotation

                x: tickerBoxVert.isCcw
                    ? Math.round((tickerBoxVert.width - titleTextVert.implicitHeight) / 2.0)
                    : Math.round((tickerBoxVert.width + titleTextVert.implicitHeight) / 2.0)

                y: {
                    if (tickerBoxVert.needsTicker) {
                        return tickerBoxVert.isCcw
                            ? (tickerBoxVert.height + tickerBoxVert.tickerOffset)
                            : tickerBoxVert.tickerOffset
                    }
                    return tickerBoxVert.isCcw
                        ? Math.round((tickerBoxVert.height + titleTextVert.implicitWidth) / 2.0)
                        : Math.round((tickerBoxVert.height - titleTextVert.implicitWidth) / 2.0)
                }

                onTextChanged: tickerBoxVert.refreshTicker()
            }
        }

        // --- NOW-PLAYING CHIP ---
        // A MouseArea, not a TapHandler: the card itself carries a TapHandler
        // that toggles the task list, and an accepting MouseArea is what stops
        // a tap on the chip from also opening that popout behind it.
        Item {
            id: artChipVert
            visible: activeWinCard.showArtChip && activeWinCard.height > 66
            property bool peeking: visible && chipMouseVert.containsMouse
            Layout.row: activeWinCard.barPos === "left" ? 0 : 2
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18

            Rectangle {
                anchors.fill: parent
                radius: 5
                clip: true
                color: Qt.rgba(255, 255, 255, 0.08)
                border.width: 1
                border.color: chipMouseVert.containsMouse ? Config.accent : Qt.rgba(255, 255, 255, 0.14)
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Image {
                    id: chipArtVert
                    anchors.fill: parent
                    source: activeWinCard.mediaArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    opacity: chipMouseVert.containsMouse ? 0.35 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                // Shown when there's no art to show, and again under the hover
                // dim as the affordance that the chip is a play/pause button.
                Text {
                    anchors.centerIn: parent
                    text: chipMouseVert.containsMouse
                        ? (activeWinCard.mediaPlaying ? "pause" : "play_arrow")
                        : "music_note"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 12
                    color: chipMouseVert.containsMouse ? Config.accent : Config.textMuted
                    visible: chipMouseVert.containsMouse || chipArtVert.status !== Image.Ready
                }
            }

            MouseArea {
                id: chipMouseVert
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: activeWinCard.togglePlayback()
            }
        }
    }
}