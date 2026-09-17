import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "bars"
import "osds"
import "services"
import "surface"

PanelWindow {
    id: root

    default property alias content: contentContainer.data

    property bool isOpen: false

    // --- Hover Peek State & Math ---
    property bool isPeeking: false
    property var peekTargetItem: null
    property real peekProgress: isPeeking ? 1.0 : 0.0
    Behavior on peekProgress {
        NumberAnimation {
            duration: Config.motionService.durationFastEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Config.motionService.expressiveFastEffectsPoints
        }
    }

    readonly property real peekSpan: 50      // Increased default length
    readonly property real peekDepth: 6      // Depth extending into the screen
    readonly property real peekRadius: 4     // Increased for much rounder corners
    readonly property real peekWing: 2

    readonly property real pkSpan: {
        let flushExtra = (isScreenFrame && (isPeekLeftFlush || isPeekRightFlush)) ? 12 : 0
        return basePeekSpan + flushExtra
    }
    readonly property real pkDepth: peekDepth * (peekProgress || 0)
    readonly property real pkWing: peekWing * (peekProgress || 0)
    readonly property real pkRad: Math.max(0.1, peekRadius * (peekProgress || 0))

    readonly property real pkCenter: (isHorizontal ? (popoutXOffset || 0) : (popoutYOffset || 0)) || 0
    readonly property real pkLeft: {
        let center = pkCenter
        let safeMargin = isScreenFrame ? ((inRadi || 0) + pkWing) : ((barRadius || 0) + pkWing)
        let minL = isScreenFrame ? ((isHorizontal ? (inX || 0) : (inY || 0)) + (halfB || 0)) : (halfB || 0)
        let maxR = isScreenFrame ? ((isHorizontal ? ((inX || 0) + (inW || 0)) : ((inY || 0) + (inH || 0))) - (halfB || 0)) : ((isHorizontal ? (mainContainer ? mainContainer.width : 0) : (mainContainer ? mainContainer.height : 0)) - (halfB || 0))
        
        if (root.isIsland) {
            let barOrigin = isHorizontal ? (islandX || 0) : (islandY || 0)
            let barEnd = isHorizontal ? ((islandX || 0) + (animatedIslandWidth || 0)) : ((islandY || 0) + (animatedIslandHeight || 0))
            return Math.max(barOrigin + safeMargin, Math.min(barEnd - safeMargin - pkSpan, center - (pkSpan / 2.0))) || 0
        }

        // In screen frame mode flush states, snap to exact screen frame edge boundaries
        if (root.isScreenFrame && root.isPeekLeftFlush) return minL
        if (root.isScreenFrame && root.isPeekRightFlush) return maxR - pkSpan
        return Math.max(minL + safeMargin, Math.min(maxR - safeMargin - pkSpan, center - (pkSpan / 2.0))) || 0
    }
    readonly property real pkRight: (pkLeft + pkSpan) || 0

    // Peek-specific flush helpers (no circular dependency — use raw center/span, not pLeft)
    readonly property real _pkSafeMargin: isScreenFrame ? ((inRadi || 0) + pkWing) : ((barRadius || 0) + pkWing)
    
    readonly property bool isPeekLeftFlush: root.isScreenFrame && (
        (pkCenter - (basePeekSpan / 2.0)) <= (minPossibleLeft + _pkSafeMargin + 8)
    )
    readonly property bool isPeekRightFlush: root.isScreenFrame && (
        (pkCenter + (basePeekSpan / 2.0)) >= (maxPossibleRight - _pkSafeMargin - 8)
    )

    readonly property real basePeekSpan: {
        let span = 32
        if (peekTargetItem) {
            span = isHorizontal 
                ? (peekTargetItem.width || peekTargetItem.implicitWidth || 32) 
                : (peekTargetItem.height || peekTargetItem.implicitHeight || 32)
        }
        return (span || 32) + 20
    }

    function startPeek(item) {
        if (!Config.enableHoverPeek || !item || root.isOpen || !item.visible) return
        setPopoutPos(item)
        root.peekTargetItem = item
        root.isPeeking = true
    }

    function stopPeek() {
        root.isPeeking = false
    }

    readonly property real actualScreenWidth: screen ? screen.width : 1920
    readonly property real actualScreenHeight: screen ? screen.height : 1080

    property real popoutXOffset: actualScreenWidth / 2.0
    property real popoutYOffset: actualScreenHeight / 2.0
    property bool isCentered: false

    // The button setPopoutPos was last given, so it can be re-measured below
    // whenever the island bar's own live position/size changes. An island
    // bar (isIsland, always centred on screen) grows and shrinks around its
    // own centre, so a card anchored to one of its edges - like rightCard's
    // bottom edge in vertical mode - physically slides as the bar grows,
    // even though the button never moves within that card. popoutXOffset/
    // YOffset were only ever captured once, at click time, so that slide
    // left the popout anchored to where the icon *used to be*, producing a
    // visible "scoop" as the icon (and the popout, still using the stale
    // offset) drifted apart during the bar's own grow/shrink animation.
    property var popoutAnchorItem: null
    onIslandXChanged: if (popoutAnchorItem) setPopoutPos(popoutAnchorItem)
    onIslandYChanged: if (popoutAnchorItem) setPopoutPos(popoutAnchorItem)

    property Timer barLayoutReopenTimer: Timer {
        id: barLayoutReopenTimer
        interval: 220
        repeat: false
        onTriggered: {
            if (root.activeView !== "none") {
                root.refreshPopoutPos()
                root.isOpen = true
            }
        }
    }

    readonly property real shadowPadding: 16

    readonly property string barPosition: Config.barPosition || "top"
    readonly property bool isHorizontal: barPosition === "top" || barPosition === "bottom"
    readonly property bool isBottom: barPosition === "bottom"
    readonly property bool isRight: barPosition === "right"

    property real currentMargin: isFloatingStyle ? (Config.barMargin || 4) : 0
    Behavior on currentMargin {
        NumberAnimation {
            duration: Config.motionService.durationFastSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Config.motionService.expressiveFastSpatialPoints
        }
    }

    property real barRadius: isFloatingStyle ? (Config.cornerRadius || 12) : 0
    Behavior on barRadius {
        NumberAnimation {
            duration: Config.motionService.durationFastSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Config.motionService.expressiveFastSpatialPoints
        }
    }

    readonly property bool isScreenFrame: Config.barFrameStyle === "screen"
    readonly property real framePadding: isScreenFrame ? 8 : 0
    readonly property real frameRadius: isScreenFrame ? (Config.surfaceRadius || 18) : 0

    readonly property real activeBarSideThickness: isScreenFrame
        ? (framePadding + (barH * autoHideProgress))
        : barH

    readonly property real padL: barPosition === "left" ? activeBarSideThickness : framePadding
    readonly property real padR: barPosition === "right" ? activeBarSideThickness : framePadding
    readonly property real padT: barPosition === "top" ? activeBarSideThickness : framePadding
    readonly property real padB: barPosition === "bottom" ? activeBarSideThickness : framePadding

    readonly property real inX: padL
    readonly property real inY: padT
    readonly property real inW: actualScreenWidth - padL - padR
    readonly property real inH: actualScreenHeight - padT - padB
    readonly property real inRadi: Math.max(0.1, frameRadius)

    // --- Dynamic Child Measurement Engine ---
    property Item activeDrawerItem: null

    readonly property real rawChildWidth: {
        if (root.activeView === "osd") return volumeOsdModule.implicitWidth
        if (root.activeView === "notifOsd") return notifOsdModule.implicitWidth
        if (root.activeView === "launcherOsd") return launcherOsdModule.implicitWidth
        if (root.activeView === "taskOverflow") return taskOverflowModule.implicitWidth
        if (root.activeView === "trayMenu") return trayMenuModule.implicitWidth
        if (root.activeDrawerItem && root.activeDrawerItem.implicitWidth > 0) {
            return root.activeDrawerItem.implicitWidth
        }

        // Direct O(1) dimension fallback lookup table
        switch (root.activeView) {
            case "calendar":      return 680
            case "settings":      return 620
            case "systemMonitor": return 540
            default:              return 340
        }
    }

    readonly property real rawChildHeight: {
        if (root.activeView === "osd") return volumeOsdModule.implicitHeight
        if (root.activeView === "notifOsd") return notifOsdModule.implicitHeight
        if (root.activeView === "launcherOsd") return launcherOsdModule.implicitHeight
        if (root.activeView === "taskOverflow") return taskOverflowModule.implicitHeight
        if (root.activeView === "trayMenu") return trayMenuModule.implicitHeight
        if (root.activeDrawerItem && root.activeDrawerItem.implicitHeight > 0) {
            return root.activeDrawerItem.implicitHeight
        }

        switch (root.activeView) {
            case "calendar":         return 460
            case "settings":         return 520
            case "systemMonitor":    return 500
            case "workspacePreview": return 260
            case "controlCenter":    return 480
            default:                 return 480
        }
    }

    // Explicit state variables declared in scope
    property real lastOpenWidth: rawChildWidth
    property real lastOpenHeight: rawChildHeight

    SoundEffect {
        id: openSoundPlayer
        volume: Config.windowSoundVolume !== undefined ? Config.windowSoundVolume : 0.25
        source: {
            let baseDir = Quickshell.shellDir.toString()
            if (!baseDir.endsWith("/")) baseDir += "/"
            let file = Config.windowSoundPath || "sound1.wav"
            return Qt.resolvedUrl(baseDir + "assets/" + file)
        }
    }

    function playOpenSound() {
        if (!Config.playWindowSounds || root.activeView === "notifOsd" || root.activeView === "osd") return
        openSoundPlayer.stop()
        openSoundPlayer.play()
    }

    onIsOpenChanged: {
        if (isOpen) {
            root.playOpenSound()
            root.isBarRevealedByUser = true
            root.isPeeking = false
            autoHideTimer.stop()
        } else {
            lastOpenWidth = rawChildWidth
            lastOpenHeight = rawChildHeight
            if (Config.autoHideBar) {
                root.isBarRevealedByUser = true
                autoHideTimer.restart()
            }
        }
    }

    property real targetWidth: isOpen ? rawChildWidth : (isHorizontal ? (lastOpenWidth * 0.1) : (lastOpenWidth * 1.10))
    property real targetHeight: isOpen ? rawChildHeight : (isHorizontal ? (lastOpenHeight * 1.10) : (lastOpenHeight * 0.1))

    // Content within an already-open, already-settled view (e.g. LauncherOSD's
    // results list growing/shrinking as you type) should resize calmly instead
    // of replaying the elastic open/close "pop" every keystroke.
    readonly property bool isSettledContentResize: isOpen && progress >= 0.999 && activeView === "launcherOsd"

    Behavior on targetWidth {
        NumberAnimation {
            duration: root.isSettledContentResize ? 160 : 350
            easing.type: root.isSettledContentResize ? Easing.OutCubic : Easing.OutBack
            easing.overshoot: root.isSettledContentResize ? 0 : 0.6
        }
    }

    Behavior on targetHeight {
        NumberAnimation {
            duration: root.isSettledContentResize ? 160 : 350
            easing.type: root.isSettledContentResize ? Easing.OutCubic : Easing.OutBack
            easing.overshoot: root.isSettledContentResize ? 0 : 0.6
        }
    }

    property real progress: 0.0
    readonly property real animScale: Math.max(0.0, progress)
    readonly property real closeFactor: root.isOpen ? progress : Math.pow(progress, 1.2)

    // Unmodified popout squish math - written in terms of depth (the axis
    // that extends out from the bar, collapsing to zero via the closeFactor
    // power curve) and span (the axis that runs along the bar, following the
    // gentler squish-blend curve), then mapped onto width/height by
    // orientation below. It used to hardcode height=depth/width=span, which
    // is only correct for a horizontal (top/bottom) bar - for a vertical
    // (left/right) bar, height is the span axis and width is the depth axis,
    // so the two curves were swapped onto the wrong dimensions, giving
    // vertical popouts a "scoop" on open/close that horizontal ones never had.
    readonly property real depthTarget: isHorizontal ? targetHeight : targetWidth
    readonly property real spanTarget: isHorizontal ? targetWidth : targetHeight
    readonly property real popoutDepth: depthTarget * Math.pow(closeFactor, 1.8)
    readonly property real squishRatio: depthTarget > 0 ? (1.0 - (popoutDepth / depthTarget)) : 0.0
    readonly property real popoutSpan: root.isOpen ? (spanTarget * animScale) : (spanTarget * (closeFactor + (0.33 * squishRatio * closeFactor)))
    readonly property real popoutWidth: isHorizontal ? popoutSpan : popoutDepth
    readonly property real popoutHeight: isHorizontal ? popoutDepth : popoutSpan

    // Dynamic switch to peek geometry without polluting the squish lifecycle
    readonly property bool peekActive: root.isPeeking && !root.isOpen && root.progress <= 0.005
    readonly property real currentWidth: peekActive ? (isHorizontal ? pkSpan : pkDepth) : popoutWidth
    readonly property real currentHeight: peekActive ? (isHorizontal ? pkDepth : pkSpan) : popoutHeight

    readonly property real wingW: peekActive ? pkWing : ((Config.surfaceRadius || 18) * animScale)
    readonly property real wingH: peekActive ? pkWing : ((Config.surfaceRadius || 18) * animScale)
    readonly property real wingK: 0.55228474983 // 4/3 * (sqrt(2) - 1) for true circular arc
    readonly property real radius: Math.max(0.1, peekActive ? pkRad : ((Config.surfaceRadius || 18) * animScale))

    readonly property real borderWidth: (Config.borderThickness !== undefined && Config.borderThickness !== null) ? Number(Config.borderThickness) : 0.0
    readonly property real halfB: borderWidth / 2.0

    readonly property real leftBarRx: inX + currentWidth
    readonly property real rightBarPopL: inX + inW - currentWidth
    readonly property real topBarPopB: inY + currentHeight
    readonly property real bottomBarPopT: inY + inH - currentHeight

    anchors {
        top: barPosition === "top" || !isHorizontal
        bottom: barPosition === "bottom" || !isHorizontal
        left: barPosition === "left" || isHorizontal
        right: barPosition === "right" || isHorizontal
    }

    margins {
        top: barPosition === "bottom" ? 0 : (currentMargin - shadowPadding)
        bottom: barPosition === "top" ? 0 : (currentMargin - shadowPadding)
        left: barPosition === "right" ? 0 : (currentMargin - shadowPadding)
        right: barPosition === "left" ? 0 : (currentMargin - shadowPadding)
    }

    readonly property real baseBarHeight: Config.barHeight || 54
    readonly property real barH: isScreenFrame ? (baseBarHeight - 8) : baseBarHeight
    readonly property real barBottomY: barH - halfB

    implicitHeight: actualScreenHeight + (shadowPadding * 2)
    implicitWidth: actualScreenWidth + (shadowPadding * 2)

    color: "transparent"
    visible: true

    // --- AUTO-HIDE ENGINE ---
    property bool isBarHovered: false
    property bool isBarRevealedByUser: false
    readonly property bool isBarRevealed: !Config.autoHideBar || root.isOpen || (root.progress > 0.005) || isBarHovered || isBarRevealedByUser || (root.activeView !== "none")

    Timer {
        id: autoHideTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!barContentHover.hovered && !edgeHover.hovered && !root.isOpen && root.activeView === "none") {
                root.isBarRevealedByUser = false
                root.isBarHovered = false
            }
        }
    }

    property real autoHideProgress: isBarRevealed ? 1.0 : 0.0
    Behavior on autoHideProgress {
        NumberAnimation {
            duration: Config.motionService.durationFastEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Config.motionService.expressiveFastEffectsPoints
        }
    }

    readonly property real autoHideDist: barH + currentMargin + 32
    readonly property real autoHideShiftDist: isScreenFrame ? barH : autoHideDist
    readonly property real autoHideXOffset: {
        if (!Config.autoHideBar) return 0
        if (barPosition === "left") return (1.0 - autoHideProgress) * -autoHideShiftDist
        if (barPosition === "right") return (1.0 - autoHideProgress) * autoHideShiftDist
        return 0
    }
    readonly property real autoHideYOffset: {
        if (!Config.autoHideBar) return 0
        if (barPosition === "top") return (1.0 - autoHideProgress) * -autoHideShiftDist
        if (barPosition === "bottom") return (1.0 - autoHideProgress) * autoHideShiftDist
        return 0
    }

    mask: Region {
        Region { item: isBarRevealed ? barContent : null }
        Region { item: root.progress > 0.01 ? contentContainer : null }
        Region { item: (Config.autoHideBar && !isBarRevealed) ? edgeTrigger : null }
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: (Config.isBarEnabledForScreen(screen ? screen.name : "") && !Config.autoHideBar)
        ? (isScreenFrame ? (barH + (framePadding * 2)) : (barH + (currentMargin > 0 ? currentMargin : (Config.barMargin || 4))))
        : 0
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "synoptik-shell"

    // Note: closing does not force isCentered false here — refreshPopoutPos()
    // (triggered via closeOthers -> the relevant onShowXChanged -> updateActiveView)
    // deliberately leaves it alone on close so the shrink-away animation keeps
    // collapsing toward whatever anchor it opened from instead of snapping over.
    Shortcut {
        sequences: ["Escape"]
        enabled: root.isOpen
        onActivated: {
            root.closeOthers("none")
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: root.isOpen && root.activeView !== "osd" && root.activeView !== "notifOsd" && (!screen || screen.name === (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""))
        windows: [root]
        onCleared: {
            root.closeOthers("none")
        }
    }

    readonly property bool isIsland: Config.barFrameStyle === "island"
    readonly property bool isFloatingStyle: Config.barFrameStyle === "floating" || isIsland
    readonly property real leftCardTargetWidth: leftCard ? (root.isHorizontal ? (leftCard.contentTargetWidth || leftCard.width) : 36) : 0
    readonly property real leftCardTargetHeight: leftCard ? (!root.isHorizontal ? (leftCard.contentTargetHeight || leftCard.height) : 36) : 0
    readonly property real rightCardTargetWidth: rightCard ? (root.isHorizontal ? (rightCard.contentTargetWidth || rightCard.width) : 36) : 0
    readonly property real rightCardTargetHeight: rightCard ? (!root.isHorizontal ? (rightCard.contentTargetHeight || rightCard.height) : 36) : 0

    // Tray footprint, same "+8" reservation as ActiveWindowCard's own
    // trayReserve below - without it, the island's total width never grows
    // to make room for tray icons, so they eat into the shared middle gap
    // instead and the bar visibly leans right as more apps register one.
    readonly property real islandTraySpan: (trayCard && trayCard.visible)
        ? ((root.isHorizontal ? trayCard.width : trayCard.height) + 8) : 0

    readonly property real islandContentWidth: (root.isHorizontal ? leftCardTargetWidth : (leftCard ? leftCard.width : 0))
        + (activeWindowCard && activeWindowCard.visible ? 190 : 0)
        + (root.isHorizontal ? rightCardTargetWidth : (rightCard ? rightCard.width : 0))
        + root.islandTraySpan
        + 64
    // isPanelActive (open OR still closing), not isOpen: isOpen flips false
    // the instant a close starts, which would drop this back to
    // islandContentWidth immediately - well before animatedIslandWidth (which
    // has its own Behavior, below) has actually shrunk back down.
    //
    // rawChildWidth, not targetWidth: targetWidth has its own overshoot
    // Behavior (see its declaration above) for the popout's own springy
    // grow/squish, but the island bar's footprint shouldn't also inherit that
    // bounce on top of animatedIslandWidth's own Behavior below - that
    // compounded into the bar visibly overshooting past its final width then
    // snapping back, on both open and close. rawChildWidth is the stable,
    // un-animated destination size, so animatedIslandWidth's own curve is the
    // only bounce the bar's shape gets.
    readonly property real islandTargetWidth: Math.min(
        mainContainer.width - (root.currentMargin * 2),
        Math.max(200, (root.isPanelActive && root.isHorizontal) ? Math.max(islandContentWidth, root.rawChildWidth) : islandContentWidth)
    )

    property real animatedIslandWidth: isIsland ? islandTargetWidth : (mainContainer.width - Math.ceil(root.borderWidth))
    Behavior on animatedIslandWidth {
        NumberAnimation {
            id: islandWidthAnim
            duration: Config.motionService.durationDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Config.motionService.expressiveDefaultSpatialPoints
        }
    }

    readonly property real islandContentHeight: (!root.isHorizontal ? leftCardTargetHeight : (leftCard ? leftCard.height : 0))
        + (activeWindowCard && activeWindowCard.visible ? 190 : 0)
        + (rightCard ? rightCard.height : 0)
        + root.islandTraySpan
        + 64

    // Same isPanelActive + rawChildHeight reasoning as islandTargetWidth above.
    readonly property real islandTargetHeight: Math.min(
        mainContainer.height - (root.currentMargin * 2),
        Math.max(200, (root.isPanelActive && !root.isHorizontal) ? Math.max(islandContentHeight, root.rawChildHeight) : islandContentHeight)
    )
    property real animatedIslandHeight: isIsland ? islandTargetHeight : (mainContainer.height - Math.ceil(root.borderWidth))
    Behavior on animatedIslandHeight {
        NumberAnimation {
            id: islandHeightAnim
            duration: Config.motionService.durationDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Config.motionService.expressiveDefaultSpatialPoints
        }
    }

    readonly property bool isIslandResizing: isIsland && (islandWidthAnim.running || islandHeightAnim.running)

    readonly property real islandX: (mainContainer.width - animatedIslandWidth) / 2
    readonly property real islandY: (mainContainer.height - animatedIslandHeight) / 2

    // Where the island bar's own edges settle once ITS resize animation
    // finishes - unlike islandX/animatedIslandWidth above, which track
    // where the bar visually IS on this frame, mid-animation included. The
    // popout's own position (staticLeft) needs to clamp against the bar's
    // FINAL bounds, not its live ones: the island bar growing wider to fit
    // an opening panel and the panel itself growing are two independent
    // Behavior animations with different easing curves, so at any given
    // moment they're rarely at the same fraction of completion. Clamping
    // the popout against the live (smaller, still catching up) island
    // bounds pins it in tighter than it needs to be for part of the
    // animation, then releases it once the island finishes expanding -
    // which reads as the popout pushing out past where it should be and
    // snapping back, even though nothing was ever actually out of bounds.
    readonly property real targetIslandX: (mainContainer.width - islandTargetWidth) / 2
    readonly property real targetIslandY: (mainContainer.height - islandTargetHeight) / 2

    readonly property bool isOsdView: activeView === "osd" || activeView === "notifOsd"

    readonly property real minPossibleLeft: isScreenFrame ? ((isHorizontal ? inX : inY) + halfB) : halfB
    readonly property real maxPossibleRight: isScreenFrame ? ((isHorizontal ? inX + inW : inY + inH) - halfB) : ((isHorizontal ? mainContainer.width : mainContainer.height) - halfB)

    readonly property bool isIslandBothFlush: root.isIsland && root.isOpen && (
        (root.isHorizontal ? root.targetWidth : root.targetHeight) >= (root.isHorizontal ? (root.islandContentWidth - 16) : (root.islandContentHeight - 16))
    )
    
    readonly property real islandBarL: root.isIsland ? Math.min(root.islandX, root.pLeft) : root.halfB
    readonly property real islandBarR: root.isIsland ? Math.max(root.islandX + root.animatedIslandWidth, root.pRight) : (mainContainer.width - root.halfB)
    readonly property real islandBarT: root.isIsland ? Math.min(root.islandY, root.pLeft) : root.halfB
    readonly property real islandBarB: root.isIsland ? Math.max(root.islandY + root.animatedIslandHeight, root.pRight) : (mainContainer.height - root.halfB)

    readonly property real safeCornerMargin: isScreenFrame ? (root.inRadi + root.wingW) : (root.barRadius + root.wingW)

    readonly property bool isPanelActive: root.isOpen || root.progress > 0.005

    // Compared against targetIslandX/islandTargetWidth (the bar's settled
    // bounds), not islandX/animatedIslandWidth (its live, still-animating
    // ones) - staticLeft below makes that same choice for the same reason,
    // and comparing a target-based staticLeft against a live island bound
    // would drift out of step with it for as long as the island bar is
    // still resizing, flipping flush on/off independently of where the
    // popout actually is.
    readonly property bool isLeftFlush: isPanelActive && !peekActive && (root.isIsland
        ? (root.isHorizontal
            ? (staticLeft <= (root.targetIslandX + safeCornerMargin))
            : (staticLeft <= (root.targetIslandY + safeCornerMargin)))
        : (root.isScreenFrame && !isCentered && (
            (isHorizontal ? (popoutXOffset - rawChildWidth / 2.0) : (popoutYOffset - rawChildHeight / 2.0)) <= minPossibleLeft
        )))

    readonly property bool isRightFlush: isPanelActive && !peekActive && (root.isIsland
        ? (root.isHorizontal
            ? ((staticLeft + rawChildWidth) >= (root.targetIslandX + root.islandTargetWidth - safeCornerMargin))
            : ((staticLeft + rawChildHeight) >= (root.targetIslandY + root.islandTargetHeight - safeCornerMargin)))
        : (root.isScreenFrame && !isCentered && (
            (isHorizontal ? (popoutXOffset + rawChildWidth / 2.0) : (popoutYOffset + rawChildHeight / 2.0)) >= maxPossibleRight
        )))

    // Deliberately keyed off currentWidth/currentHeight (the size the popout
    // actually is on this frame) rather than targetWidth/targetHeight (the
    // size it's animating TOWARD). Using the target size fixes this edge at
    // where the fully-grown box would sit and only grows width/height
    // outward from there, so the shape visibly expands from a stationary
    // top-left corner instead of from the icon it's supposed to emerge from.
    // Keying off the live size instead means this edge moves every frame to
    // keep the shape centred on the anchor, so it grows (and, closing,
    // shrinks back to a point) symmetrically around it.
    readonly property real targetCenteredLeft: Math.max(
        minPossibleLeft + safeCornerMargin,
        Math.min(
            maxPossibleRight - (isHorizontal ? currentWidth : currentHeight) - safeCornerMargin,
            ((isHorizontal ? mainContainer.width : mainContainer.height) - (isHorizontal ? currentWidth : currentHeight)) / 2.0
        )
    )

    readonly property real staticLeft: {
        let span = isHorizontal ? currentWidth : currentHeight
        // rawChildWidth/Height, not targetWidth/Height: targetWidth has its
        // own overshoot Behavior (see its declaration above), so it isn't
        // actually settled during the open transition either - using it here
        // let the flush decision below flip mid-open as the overshoot passed
        // through the threshold, which is the "opens from the top right"-then-
        // "snaps into place" bug this comment used to (incorrectly) claim
        // couldn't happen. rawChildWidth/Height is the real, un-animated
        // destination size, so it's stable from the very first frame.
        let targetSpan = isHorizontal ? rawChildWidth : rawChildHeight
        let offset = isHorizontal ? popoutXOffset : popoutYOffset
        let safeMargin = root.safeCornerMargin
        if (isCentered) return targetCenteredLeft

        // Which edge (if any) this popout ends up pinned against - left
        // flush, right flush, or neither (grows centred on its icon) - is
        // decided from targetSpan, the settled final size, not the live
        // still-animating span. A popout that only becomes flush once it's
        // mostly grown would otherwise pick the centred-on-icon branch
        // early in the animation and the flush branch late, jumping
        // sideways the instant span crosses the threshold - small and
        // unnoticeable for an icon already near the edge (crosses within
        // the first few frames, while the shape is tiny), but a visible
        // snap for one further in (crosses late, once the shape is big).
        // Deciding once up front from the size it's actually heading toward
        // means the same branch - and the same edge - holds for the whole
        // animation; only the live `span` still drives the interpolated
        // position within that choice.
        if (root.isIsland) {
            // If this popout alone is what's forcing the island bar past its
            // natural content width (islandTargetWidth's own formula grows
            // it to fit whichever is bigger - see islandTargetWidth above),
            // an icon-anchored position can't work: the icon sits wherever
            // it sits on the bar's CURRENT, smaller footprint, so anchoring
            // to it and clamping to the (much wider) final bar would pin
            // one edge at the icon and stretch the other almost the entire
            // new width - overflowing the bar's current, not-yet-expanded
            // shape on that side, then correcting once the bar catches up.
            // There's no icon-relative position that avoids this, so don't
            // try - centre plainly on the screen instead, exactly like
            // islandX/Y already centre the bar itself as it grows. Both
            // then animate around the same fixed point with nothing to
            // race, which is what "the bar can expand but the panel is
            // centred" actually requires.
            let islandContentSpan = isHorizontal ? root.islandContentWidth : root.islandContentHeight
            if (targetSpan > islandContentSpan - safeMargin) {
                return ((isHorizontal ? mainContainer.width : mainContainer.height) - span) / 2.0
            }

            // Otherwise the island bar isn't growing on this popout's
            // account, so its bounds are effectively stable already - which
            // edge (if any) the popout pins against is still decided from
            // targetSpan rather than the live span, for the same reason as
            // above: the decision must hold for the whole animation, not
            // flip once span crosses a threshold mid-growth.
            let barOrigin = isHorizontal ? root.targetIslandX : root.targetIslandY
            let barEnd = isHorizontal ? (root.targetIslandX + root.islandTargetWidth) : (root.targetIslandY + root.islandTargetHeight)
            let targetRawLeft = offset - (targetSpan / 2.0)
            let targetRawRight = offset + (targetSpan / 2.0)

            if (targetRawLeft <= barOrigin + safeMargin) return barOrigin
            if (targetRawRight >= barEnd - safeMargin) return barEnd - span
            return Math.max(barOrigin + safeMargin, Math.min(barEnd - safeMargin - span, offset - (span / 2.0)))
        }

        let targetRawLeft = offset - (targetSpan / 2.0)
        let targetRawRight = offset + (targetSpan / 2.0)
        if (root.isScreenFrame && !isCentered && targetRawLeft <= minPossibleLeft) return minPossibleLeft
        if (root.isScreenFrame && !isCentered && targetRawRight >= maxPossibleRight) return maxPossibleRight - span
        return Math.max(minPossibleLeft + safeMargin, Math.min(maxPossibleRight - span - safeMargin, offset - (span / 2.0)))
    }

    readonly property real staticRight: staticLeft + (isHorizontal ? targetWidth : targetHeight)

    readonly property real pLeft: peekActive ? pkLeft : staticLeft
    readonly property real pRight: peekActive ? pkRight : staticRight

    property string activeView: "none"

    function refreshPopoutPos() {
        // Closing (activeView "none") intentionally leaves isCentered/popoutOffset
        // untouched so the shrink-away animation keeps collapsing toward whatever
        // anchor it opened from instead of snapping to a stale value mid-close.
        if (activeView === "none" || activeView === "workspacePreview") return

        // 0. Command Launcher OSD: anchor to its search bar icon (RightModules),
        // same as every other panel - it used to always center under the bar
        // instead, which looked disconnected from its trigger icon in bar
        // layouts where that icon isn't itself centered.
        if (activeView === "launcherOsd") {
            root.isCentered = false
            let btn = rightCard ? (rightCard.getButton("search") || rightCard) : null
            if (btn) setPopoutPos(btn)
            return
        }

        // 1. Edge OSDs: Snap coordinates to screen boundaries or center on Island bar
        if (activeView === "osd" || activeView === "notifOsd") {
            root.isCentered = false
            if (root.isIsland) {
                if (root.isHorizontal) root.popoutXOffset = root.islandX + (root.animatedIslandWidth / 2.0)
                else root.popoutYOffset = root.islandY + (root.animatedIslandHeight / 2.0)
            } else {
                if (activeView === "osd") {
                    if (root.isHorizontal) root.popoutXOffset = mainContainer.width
                    else root.popoutYOffset = mainContainer.height
                } else {
                    root.popoutXOffset = 0
                    root.popoutYOffset = 0
                }
            }
            return
        }

        // 2. Bar Panel Modules: Map view IDs to button handles
        root.isCentered = false
        let btn = null

        switch (activeView) {
            // Left Card Modules
            case "settings":       btn = leftCard ? (leftCard.getButton("settings") || leftCard) : null; break
            case "power":          btn = leftCard ? (leftCard.getButton("power") || leftCard) : null; break
            case "wallpaper":      btn = leftCard ? (leftCard.getButton("wallpaper") || leftCard) : null; break
            case "screenRecorder": btn = leftCard ? (leftCard.getButton("recorder") || leftCard) : null; break
            case "audio":          btn = leftCard ? (leftCard.getButton("audio") || leftCard) : null; break
            case "network":        btn = leftCard ? (leftCard.getButton("network") || leftCard) : null; break
            case "battery":        btn = leftCard ? (leftCard.getButton("batt") || leftCard) : null; break
            case "clipboard":      btn = leftCard ? (leftCard.getButton("clipboard") || leftCard) : null; break

            // Right Card & Center Modules
            case "workspacePreview": btn = rightCard ? (rightCard.getButton("overview") || rightCard) : null; break
            case "taskOverflow":     btn = activeWindowCard; break
            case "controlCenter":    btn = rightCard ? (rightCard.getButton("cc") || rightCard) : null; break
            case "calendar":         btn = rightCard ? (rightCard.getButton("clock") || rightCard) : null; break
        }

        // Snap popout offset to the active button position
        if (btn) {
            setPopoutPos(btn)
        }
    }

    // Unified popout re-anchoring engine for ALL views
    onActiveViewChanged: {
        refreshPopoutPos()
    }

    function updateActiveView() {
        let nextView = "none"
        let isFocused = !screen || screen.name === (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")

        if (isFocused) {
            // High Priority OSD Takeover (Preserves underlying panel state)
            if (typeof Config.showOSD !== "undefined" && Config.showOSD) nextView = "osd"
            else if (typeof Config.showNotificationOsd !== "undefined" && Config.showNotificationOsd) nextView = "notifOsd"
            else if (typeof Config.showLauncherOsd !== "undefined" && Config.showLauncherOsd) nextView = "launcherOsd"

            // Standard Module Panels (Unpinned active modules take priority)
            else if (Config.showSettings) nextView = "settings"
            else if (Config.showWorkspacePreview) nextView = "workspacePreview"
            else if (Config.showPower) nextView = "power"
            else if (Config.showWallpaper) nextView = "wallpaper"
            else if (Config.showCalendar) nextView = "calendar"
            else if (Config.showAudio) nextView = "audio"
            else if (Config.showNetwork) nextView = "network"
            else if (Config.showBattery) nextView = "battery"
            else if (Config.showClipboard) nextView = "clipboard"
            else if (Config.showScreenRecorder) nextView = "screenRecorder"
            else if (Config.showControlCenter) nextView = "controlCenter"
            else if (typeof Config.showTaskOverflow !== "undefined" && Config.showTaskOverflow) nextView = "taskOverflow"
            else if (typeof Config.showTrayMenu !== "undefined" && Config.showTrayMenu) nextView = "trayMenu"
        }

        if (nextView === "none") {
            root.isOpen = false
            activeView = "none"
        } else {
            activeView = nextView
            root.isOpen = true
        }
    }

    function setPopoutPos(item) {
        if (!item) return
        root.isCentered = false
        root.popoutAnchorItem = item
        if (isHorizontal) {
            root.popoutXOffset = item.mapToItem(mainContainer, item.width / 2, 0).x
        } else {
            root.popoutYOffset = item.mapToItem(mainContainer, 0, item.height / 2).y
        }
    }

    // Thin adapter over Config.closePanels() - the flag table lives there so
    // shell.qml's IpcHandlers arbitrate identically instead of each carrying
    // their own (drifted) copy of this list. "none" closes everything.
    function closeOthers(except) {
        Config.closePanels(except === "none" ? "" : except)
    }

    Connections {
        target: Config
        ignoreUnknownSignals: true

        function onEnableHoverPeekChanged() {
            if (!Config.enableHoverPeek && root.isPeeking) {
                root.stopPeek()
            }
        }

        function onBarPositionChanged() {
            if (root.isOpen && root.activeView !== "none") {
                root.isOpen = false
                barLayoutReopenTimer.restart()
            }
        }

        function onBarFrameStyleChanged() {
            if (root.isOpen && root.activeView !== "none") {
                root.isOpen = false
                barLayoutReopenTimer.restart()
            }
        }

        function onShowOSDChanged() {
            updateActiveView()
        }

        function onShowNotificationOsdChanged() {
            updateActiveView()
        }
        
        function onShowWorkspacePreviewChanged() {
            if (Config.showWorkspacePreview) {
                closeOthers("workspacePreview")
                let btn = rightCard ? rightCard.getButton("overview") : null
                if (btn) setPopoutPos(btn)
            }
            updateActiveView()
        }
        function onShowSettingsChanged() {
            if (Config.showSettings) {
                closeOthers("settings")
                let btn = leftCard ? leftCard.getButton("settings") : null
                if (btn) setPopoutPos(btn)
            }
            updateActiveView()
        }
        function onShowTaskOverflowChanged() {
            if (Config.showTaskOverflow) {
                closeOthers("taskOverflow")
                if (activeWindowCard) setPopoutPos(activeWindowCard)
            }
            updateActiveView()
        }
        // No setPopoutPos here, unlike its neighbours: the tray icon that was
        // actually clicked emits popoutRequested with itself immediately after
        // flipping this flag, so the menu anchors under that one icon rather
        // than under the middle of the whole tray card.
        function onShowTrayMenuChanged() {
            if (Config.showTrayMenu) closeOthers("trayMenu")
            updateActiveView()
        }
        function onShowLauncherOsdChanged() { if (Config.showLauncherOsd) { closeOthers("launcherOsd"); let btn = rightCard ? rightCard.getButton("search") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowPowerChanged() { if (Config.showPower) { closeOthers("power"); let btn = leftCard ? leftCard.getButton("power") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowWallpaperChanged() { if (Config.showWallpaper) { closeOthers("wallpaper"); let btn = leftCard ? leftCard.getButton("wallpaper") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowCalendarChanged() { if (Config.showCalendar) { closeOthers("calendar"); let btn = rightCard ? rightCard.getButton("clock") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowAudioChanged() { if (Config.showAudio) { closeOthers("audio"); let btn = leftCard ? leftCard.getButton("audio") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowNetworkChanged() { if (Config.showNetwork) { closeOthers("network"); let btn = leftCard ? leftCard.getButton("network") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowBatteryChanged() { if (Config.showBattery) { closeOthers("battery"); let btn = leftCard ? leftCard.getButton("batt") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowClipboardChanged() { if (Config.showClipboard) { closeOthers("clipboard"); let btn = leftCard ? leftCard.getButton("clipboard") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowScreenRecorderChanged() { if (Config.showScreenRecorder) { closeOthers("screenRecorder"); let btn = leftCard ? leftCard.getButton("recorder") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowControlCenterChanged() { if (Config.showControlCenter) { closeOthers("controlCenter"); let btn = rightCard ? rightCard.getButton("cc") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
    }

    // --- AUTO-HIDE EDGE TRIGGER ---
    Item {
        id: edgeTrigger
        z: 999
        visible: Config.autoHideBar && !root.isBarRevealed

        x: root.shadowPadding + (isHorizontal ? (root.isIsland ? root.islandX : 0) : (barPosition === "right" ? (root.actualScreenWidth - 16) : 0))
        y: root.shadowPadding + (isHorizontal ? (barPosition === "bottom" ? (root.actualScreenHeight - 16) : 0) : (root.isIsland ? root.islandY : 0))
        width: isHorizontal ? (root.isIsland ? root.animatedIslandWidth : root.actualScreenWidth) : 16
        height: !isHorizontal ? (root.isIsland ? root.animatedIslandHeight : root.actualScreenHeight) : 16

        HoverHandler {
            id: edgeHover
            onHoveredChanged: {
                if (hovered) {
                    root.isBarRevealedByUser = true
                    autoHideTimer.restart()
                }
            }
        }
    }

    Item {
        id: mainContainer
        anchors.fill: parent
        anchors.margins: shadowPadding

        opacity: root.isScreenFrame ? 1.0 : (Config.autoHideBar ? root.autoHideProgress : 1.0)
        visible: root.isScreenFrame || !Config.autoHideBar || root.autoHideProgress > 0.001

        MouseArea {
            anchors.fill: parent
            enabled: root.isOpen
            onClicked: {
                root.closeOthers("none")
            }
        }

        states: [
            State { name: "open"; when: root.isOpen; PropertyChanges { target: root; progress: 1.0 } },
            State { name: "closed"; when: !root.isOpen; PropertyChanges { target: root; progress: 0.0 } }
        ]

        transitions: [
            Transition {
                from: "closed"; to: "open"
                NumberAnimation {
                    target: root
                    property: "progress"
                    duration: Config.motionService.durationDefaultSpatial
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.55
                }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation {
                    target: root
                    property: "progress"
                    duration: 280
                    easing.type: Easing.InBack
                    easing.overshoot: 1.2
                }
            }
        ]

        Item {
            id: shadowWrapper
            anchors.fill: parent

            layer.enabled: true
            layer.samples: 8
            layer.smooth: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#D0000000"
                shadowBlur: 0.7
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }


            // Bezier wing renderer - the fallback for whatever SdfIslandBar
            // doesn't cover (flush states, screen frame - see its own
            // visible binding). Mirrors the negation of that condition
            // exactly, rather than just "!experimentalSdfBar", so enabling
            // the flag can never hide both renderers at once for a case
            // SdfIslandBar excludes itself from.
            Item {
                anchors.fill: parent
                visible: !Config.experimentalSdfBar || root.isScreenFrame
                    || root.isLeftFlush || root.isRightFlush
                BarClosedShape { panelRoot: root; panelCanvas: mainContainer }
                BarOpenShapeLeft { panelRoot: root }
                BarOpenShapeTop { panelRoot: root }
                BarOpenShapeBottom { panelRoot: root; panelCanvas: mainContainer }
                BarOpenShapeRight { panelRoot: root; panelCanvas: mainContainer }
            }

            // EXPERIMENTAL: one blob covering every bar state (idle, open,
            // peeking) instead of the five Bezier files above - see
            // SdfIslandBar.qml. Bound directly to barContent/
            // contentContainer's own real geometry (declared further down
            // this file - forward id references within one component are
            // fine in QML), not a second derivation of it, which is what
            // kept letting the bar and the popout disagree about where each
            // other's edge was. Flush states and screen frame still render
            // via the Bezier group above regardless of this flag
            // (SdfIslandBar hides itself for those).
            SdfIslandBar {
                panelRoot: root
                barContentItem: barContent
                popoutContentItem: contentContainer
            }

            ScreenFrameClosedGroup { panelRoot: root; panelCanvas: mainContainer }
            ScreenFrameOpenGroupLeft { panelRoot: root; panelCanvas: mainContainer }
            ScreenFrameOpenGroupRight { panelRoot: root; panelCanvas: mainContainer }
            ScreenFrameOpenGroupTop { panelRoot: root; panelCanvas: mainContainer }
            ScreenFrameOpenGroupBottom { panelRoot: root; panelCanvas: mainContainer }

            Item {
                id: barContent
                x: (root.isIsland 
                    ? (root.isHorizontal ? root.islandX : (root.isRight ? (mainContainer.width - root.barH + Math.floor(root.halfB)) : Math.floor(root.halfB)))
                    : (root.isRight ? (mainContainer.width - root.barH + Math.floor(root.halfB)) : Math.floor(root.halfB)))
                    + (root.isScreenFrame ? (root.barPosition === "left" ? root.framePadding / 2 : (root.barPosition === "right" ? -root.framePadding / 2 : 0)) : 0)
                    + root.autoHideXOffset

                y: (root.isIsland
                    ? (root.isHorizontal ? (root.isBottom ? (mainContainer.height - root.barH + Math.floor(root.halfB)) : Math.floor(root.halfB)) : root.islandY)
                    : (root.isBottom ? (mainContainer.height - root.barH + Math.floor(root.halfB)) : Math.floor(root.halfB)))
                    + (root.isScreenFrame ? (root.barPosition === "top" ? root.framePadding / 2 : (root.barPosition === "bottom" ? -root.framePadding / 2 : 0)) : 0)
                    + root.autoHideYOffset

                width: root.isHorizontal ? (root.isIsland ? root.animatedIslandWidth : (mainContainer.width - Math.ceil(root.borderWidth))) : (root.barH - Math.ceil(root.borderWidth))
                height: root.isHorizontal ? (root.barH - Math.ceil(root.borderWidth)) : (root.isIsland ? root.animatedIslandHeight : (mainContainer.height - Math.ceil(root.borderWidth)))

                // Ambient audio throb: a small uniform scale pulse around this
                // item's own center (its width/height are just the bar's own
                // footprint, not the full screen, so the default center origin
                // pivots on the bar itself rather than the monitor).
                scale: typeof shellRoot !== "undefined" ? shellRoot.throbScale : 1.0

                opacity: 1.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                LeftModules {
                    id: leftCard
                    rootRef: root
                    onPopoutRequested: item => root.setPopoutPos(item)
                }
                ActiveWindowCard {
                    id: activeWindowCard
                    rootRef: root
                    onPopoutRequested: item => root.setPopoutPos(item)

                    // Factor in the 30px outer shell margins for both cards
                    readonly property real leftBound: leftCard ? (root.isHorizontal ? (leftCard.width + 30) : (leftCard.height + 30)) : 30
                    // The tray sits between this card and the right modules, so
                    // its footprint has to come out of the gap too - otherwise
                    // the window title slides underneath the tray icons as soon
                    // as more than a couple of apps register one. Same value
                    // islandContentWidth uses to grow the bar's own footprint.
                    readonly property real trayReserve: root.islandTraySpan
                    readonly property real rightBound: rightCard ? (root.isHorizontal ? (parent.width - rightCard.width - trayReserve - 30) : (parent.height - rightCard.height - trayReserve - 30)) : (root.isHorizontal ? parent.width : parent.height)
                    readonly property real barSpan: root.isHorizontal ? parent.width : parent.height

                    // Real available gap bounded cleanly between the padded card edges
                    readonly property real availableGap: Math.max(36, rightBound - leftBound - 24)

                    // Dynamically scale down width if space gets tight instead of overlapping
                    maxAvailableSpan: Math.max(36, Math.min(190, availableGap))

                    // Clamp position strictly between left and right bounds
                    x: root.isHorizontal
                        ? Math.max(leftBound + 12, Math.min(rightBound - activeWindowCard.width - 12, (barSpan - activeWindowCard.width) / 2))
                        : ((parent.width - activeWindowCard.width) / 2)

                    y: root.isHorizontal
                        ? ((parent.height - activeWindowCard.height) / 2)
                        : Math.max(leftBound + 12, Math.min(rightBound - activeWindowCard.height - 12, (barSpan - activeWindowCard.height) / 2))
                }
                RightModules {
                    id: rightCard
                    rootRef: root
                    onPopoutRequested: item => root.setPopoutPos(item)
                }

                // Rides just inboard of the right modules: the tray is status,
                // like the modules it sits next to, rather than navigation like
                // the left card.
                TrayGroup {
                    id: trayCard
                    rootRef: root
                    onPopoutRequested: item => root.setPopoutPos(item)

                    anchors.right: root.isHorizontal ? rightCard.left : undefined
                    anchors.rightMargin: root.isHorizontal ? 8 : 0
                    anchors.verticalCenter: root.isHorizontal ? rightCard.verticalCenter : undefined

                    anchors.bottom: root.isHorizontal ? undefined : rightCard.top
                    anchors.bottomMargin: root.isHorizontal ? 0 : 8
                    anchors.horizontalCenter: root.isHorizontal ? undefined : rightCard.horizontalCenter
                }

                HoverHandler {
                    id: barContentHover
                    onHoveredChanged: {
                        if (hovered) {
                            autoHideTimer.stop()
                            root.isBarHovered = true
                            root.isBarRevealedByUser = true
                        } else {
                            root.isBarHovered = false
                            if (Config.autoHideBar && !root.isOpen) {
                                autoHideTimer.restart()
                            }
                        }
                    }
                }
            }

            Item {
                id: contentContainer
                
                x: {
                    if (isHorizontal) {
                        return root.pLeft
                    } else {
                        if (isRight) {
                            return isScreenFrame 
                                ? root.rightBarPopL 
                                : (mainContainer.width - root.barH - root.currentWidth)
                        } else {
                            return isScreenFrame 
                                ? root.inX 
                                : root.barH
                        }
                    }
                }

                y: {
                    if (isHorizontal) {
                        if (isBottom) {
                            return isScreenFrame 
                                ? root.bottomBarPopT 
                                : (mainContainer.height - root.barH - root.currentHeight)
                        } else {
                            return isScreenFrame 
                                ? root.inY 
                                : root.barH
                        }
                    } else {
                        return root.pLeft
                    }
                }

                width: root.currentWidth
                height: root.currentHeight
                
                clip: true
                visible: root.progress > 0.01
                opacity: root.isOpen ? Math.min(1.0, root.progress * 1.3) : 0.0
                focus: true

                // --- CAELESTIA 2D DIRECTIONAL MATRIX DEFORMATION ---
                property real prevCenterX: x + width / 2.0
                property real prevCenterY: y + height / 2.0
                property real dm00: 1.0
                property real dm01: 0.0
                property real dm11: 1.0
                property real vel00: 0.0
                property real vel01: 0.0
                property real vel11: 0.0

                Timer {
                    id: matrixPhysicsTicker
                    interval: 16
                    repeat: true
                    running: root.progress > 0.01

                    onTriggered: {
                        let curCx = contentContainer.x + contentContainer.width / 2.0
                        let curCy = contentContainer.y + contentContainer.height / 2.0

                        let dt = 0.016
                        let vx = (curCx - contentContainer.prevCenterX) / dt
                        let vy = (curCy - contentContainer.prevCenterY) / dt

                        contentContainer.prevCenterX = curCx
                        contentContainer.prevCenterY = curCy

                        let speed = Math.sqrt(vx * vx + vy * vy)

                        let target00 = 1.0
                        let target01 = 0.0
                        let target11 = 1.0

                        // Tasteful deformation capped at 5% max stretch to prevent border spills
                        if (speed > 10.0) {
                            let kStretch = 0.00006
                            let targetStretch = 1.0 + Math.min(speed * kStretch, 0.05)
                            let targetCompress = 1.0 / targetStretch
                            let cosA = vx / speed
                            let sinA = vy / speed
                            let cos2 = cosA * cosA
                            let sin2 = sinA * sinA
                            let cs = cosA * sinA

                            target00 = targetStretch * cos2 + targetCompress * sin2
                            target01 = (targetStretch - targetCompress) * cs
                            target11 = targetStretch * sin2 + targetCompress * cos2
                        }

                        // Implicit underdamped spring (settles smoothly without overshooting boundaries)
                        let kStiffness = 380.0
                        let kDamping = 30.0
                        let invDamp = 1.0 / (1.0 + kDamping * dt)

                        contentContainer.vel00 = (contentContainer.vel00 - kStiffness * (contentContainer.dm00 - target00) * dt) * invDamp
                        contentContainer.dm00 += contentContainer.vel00 * dt

                        contentContainer.vel01 = (contentContainer.vel01 - kStiffness * (contentContainer.dm01 - target01) * dt) * invDamp
                        contentContainer.dm01 += contentContainer.vel01 * dt

                        contentContainer.vel11 = (contentContainer.vel11 - kStiffness * (contentContainer.dm11 - target11) * dt) * invDamp
                        contentContainer.dm11 += contentContainer.vel11 * dt
                    }
                }

                transform: Matrix4x4 {
                    matrix: {
                        let cx = contentContainer.width / 2.0
                        let cy = contentContainer.height / 2.0
                        let m = Qt.matrix4x4(
                            1, 0, 0, cx,
                            0, 1, 0, cy,
                            0, 0, 1, 0,
                            0, 0, 0, 1
                        )
                        let def = Qt.matrix4x4(
                            contentContainer.dm00, contentContainer.dm01, 0, 0,
                            contentContainer.dm01, contentContainer.dm11, 0, 0,
                            0, 0, 1, 0,
                            0, 0, 0, 1
                        )
                        let inv = Qt.matrix4x4(
                            1, 0, 0, -cx,
                            0, 1, 0, -cy,
                            0, 0, 1, 0,
                            0, 0, 0, 1
                        )
                        return m.times(def).times(inv)
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                TapHandler { onTapped: {} }

                VolumeOSD {
                    id: volumeOsdModule
                    objectName: "internalOsd"
                    anchors.fill: parent
                    visible: root.activeView === "osd"
                }

                NotificationOSD {
                    id: notifOsdModule
                    objectName: "internalNotifOsd"
                    anchors.fill: parent
                    visible: root.activeView === "notifOsd"
                }

                LauncherOSD {
                    id: launcherOsdModule
                    objectName: "internalLauncherOsd"
                    anchors.fill: parent
                    visible: root.activeView === "launcherOsd"
                }

                TaskOverflow {
                    id: taskOverflowModule
                    objectName: "internalTaskOverflow"
                    anchors.fill: parent
                    activeScreenName: screen ? screen.name : ""
                    visible: root.activeView === "taskOverflow"
                }

                TrayMenu {
                    id: trayMenuModule
                    objectName: "internalTrayMenu"
                    anchors.fill: parent
                    visible: root.activeView === "trayMenu"
                }
            }
        }
    }
}
