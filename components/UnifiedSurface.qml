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

    property Timer mirrorReopenTimer: Timer {
        id: mirrorReopenTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (Config.showMirror) {
                updateMirrorPopoutPos()
                root.isOpen = true
            }
        }
    }

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

    function updateMirrorPopoutPos() {
        if (root.activeView !== "mirror") return

        let screenCenter = isHorizontal 
            ? (inX + (inW / 2.0)) 
            : (inY + (inH / 2.0))

        if (Config.mirrorAnchorPos === "top") {
            if (isHorizontal) root.popoutXOffset = inX + (rawChildWidth / 2.0) + 12
            else root.popoutYOffset = inY + (rawChildHeight / 2.0) + 12
        } else if (Config.mirrorAnchorPos === "bottom") {
            if (isHorizontal) root.popoutXOffset = (inX + inW) - (rawChildWidth / 2.0) - 12
            else root.popoutYOffset = (inY + inH) - (rawChildHeight / 2.0) - 12
        } else {
            if (isHorizontal) root.popoutXOffset = screenCenter
            else root.popoutYOffset = screenCenter
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

    onRawChildWidthChanged: {
        if (activeView === "mirror") updateMirrorPopoutPos()
    }

    onRawChildHeightChanged: {
        if (activeView === "mirror") updateMirrorPopoutPos()
    }

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

    // Unmodified popout squish math
    readonly property real popoutHeight: targetHeight * Math.pow(closeFactor, 1.8)
    readonly property real squishRatio: targetHeight > 0 ? (1.0 - (popoutHeight / targetHeight)) : 0.0
    readonly property real popoutWidth: root.isOpen ? (targetWidth * animScale) : (targetWidth * (closeFactor + (0.33 * squishRatio * closeFactor)))

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
        active: root.isOpen && root.activeView !== "osd" && root.activeView !== "notifOsd" && !(root.activeView === "mirror" && Config.mirrorPinned) && (!screen || screen.name === (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""))
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

    readonly property real islandContentWidth: (root.isHorizontal ? leftCardTargetWidth : (leftCard ? leftCard.width : 0)) 
        + (activeWindowCard && activeWindowCard.visible ? 190 : 0) 
        + (root.isHorizontal ? rightCardTargetWidth : (rightCard ? rightCard.width : 0)) 
        + 64
    readonly property real islandTargetWidth: Math.min(
        mainContainer.width - (root.currentMargin * 2),
        Math.max(200, (root.isOpen && root.isHorizontal) ? Math.max(islandContentWidth, root.targetWidth) : islandContentWidth)
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
        + 64

    readonly property real islandTargetHeight: Math.min(
        mainContainer.height - (root.currentMargin * 2),
        Math.max(200, (root.isOpen && !root.isHorizontal) ? Math.max(islandContentHeight, root.targetHeight) : islandContentHeight)
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

    readonly property bool isLeftFlush: isPanelActive && !peekActive && (root.isIsland
        ? (root.isHorizontal 
            ? (staticLeft <= (root.islandX + safeCornerMargin)) 
            : (staticLeft <= (root.islandY + safeCornerMargin)))
        : (root.isScreenFrame && !isCentered && (
            (isHorizontal ? (popoutXOffset - targetWidth / 2.0) : (popoutYOffset - targetHeight / 2.0)) <= minPossibleLeft
        )))

    readonly property bool isRightFlush: isPanelActive && !peekActive && (root.isIsland
        ? (root.isHorizontal 
            ? ((staticLeft + targetWidth) >= (root.islandX + root.animatedIslandWidth - safeCornerMargin)) 
            : ((staticLeft + targetHeight) >= (root.islandY + root.animatedIslandHeight - safeCornerMargin)))
        : (root.isScreenFrame && !isCentered && (
            (isHorizontal ? (popoutXOffset + targetWidth / 2.0) : (popoutYOffset + targetHeight / 2.0)) >= maxPossibleRight
        )))

    readonly property real targetCenteredLeft: Math.max(
        minPossibleLeft + safeCornerMargin,
        Math.min(
            maxPossibleRight - (isHorizontal ? targetWidth : targetHeight) - safeCornerMargin,
            ((isHorizontal ? mainContainer.width : mainContainer.height) - (isHorizontal ? targetWidth : targetHeight)) / 2.0
        )
    )

    readonly property real staticLeft: {
        let span = isHorizontal ? targetWidth : targetHeight
        let offset = isHorizontal ? popoutXOffset : popoutYOffset
        let safeMargin = root.safeCornerMargin
        if (isCentered) return targetCenteredLeft

        if (root.isIsland) {
            let barOrigin = isHorizontal ? root.islandX : root.islandY
            let barEnd = isHorizontal ? (root.islandX + root.animatedIslandWidth) : (root.islandY + root.animatedIslandHeight)
            let barSpan = barEnd - barOrigin
            let rawLeft = offset - (span / 2.0)
            let rawRight = offset + (span / 2.0)

            if (span >= barSpan - safeMargin) {
                return barOrigin + ((barSpan - span) / 2.0)
            }
            if (rawLeft <= barOrigin + safeMargin) return barOrigin
            if (rawRight >= barEnd - safeMargin) return barEnd - span
            return Math.max(barOrigin + safeMargin, Math.min(barEnd - safeMargin - span, rawLeft))
        }

        let rawLeft = offset - (span / 2.0)
        let rawRight = offset + (span / 2.0)
        if (root.isScreenFrame && !isCentered && rawLeft <= minPossibleLeft) return minPossibleLeft
        if (root.isScreenFrame && !isCentered && rawRight >= maxPossibleRight) return maxPossibleRight - span
        return Math.max(minPossibleLeft + safeMargin, Math.min(maxPossibleRight - span - safeMargin, rawLeft))
    }

    readonly property real staticRight: staticLeft + (isHorizontal ? targetWidth : targetHeight)

    readonly property real pLeft: peekActive ? pkLeft : staticLeft
    readonly property real pRight: peekActive ? pkRight : staticRight

    property string activeView: "none"

    function refreshPopoutPos() {
        // Closing (activeView "none") intentionally leaves isCentered untouched so the
        // shrink-away animation keeps collapsing toward whatever anchor it opened from
        // (center for the launcher OSD, the origin button for everything else) instead
        // of snapping to a stale popoutXOffset mid-close.
        if (activeView === "none" || activeView === "workspacePreview") return

        // 0. Command Launcher OSD: always centered under the bar
        if (activeView === "launcherOsd") {
            root.isCentered = true
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
            case "appLauncher":    btn = leftCard ? (leftCard.getButton("launcher") || leftCard) : null; break
            case "power":          btn = leftCard ? (leftCard.getButton("power") || leftCard) : null; break
            case "wallpaper":      btn = leftCard ? (leftCard.getButton("wallpaper") || leftCard) : null; break
            case "notifications":  btn = leftCard ? (leftCard.getButton("notifications") || leftCard) : null; break
            case "screenRecorder": btn = leftCard ? (leftCard.getButton("recorder") || leftCard) : null; break
            case "mirror":         btn = leftCard ? (leftCard.getButton("mirror") || leftCard) : null; break
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

        // Snap popout offset to the active button position or anchor mode
        if (activeView === "mirror") {
            updateMirrorPopoutPos()
        } else if (btn) {
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
            else if (Config.showAppLauncher) nextView = "appLauncher"
            else if (Config.showCalendar) nextView = "calendar"
            else if (Config.showNotifications) nextView = "notifications"
            else if (Config.showAudio) nextView = "audio"
            else if (Config.showNetwork) nextView = "network"
            else if (Config.showSystemMonitor) nextView = "systemMonitor"
            else if (Config.showBattery) nextView = "battery"
            else if (Config.showClipboard) nextView = "clipboard"
            else if (Config.showScreenRecorder) nextView = "screenRecorder"
            else if (Config.showControlCenter) nextView = "controlCenter"
            else if (Config.showMirror && !Config.mirrorPinned) nextView = "mirror"
            else if (typeof Config.showTaskOverflow !== "undefined" && Config.showTaskOverflow) nextView = "taskOverflow"

            // Pinned Fallback Panels (Active when no temporary unpinned panel is open)
            else if (Config.showMirror && Config.mirrorPinned) nextView = "mirror"
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
        if (isHorizontal) {
            root.popoutXOffset = item.mapToItem(mainContainer, item.width / 2, 0).x
        } else {
            root.popoutYOffset = item.mapToItem(mainContainer, 0, item.height / 2).y
        }
    }

    function closeOthers(except) {
        let isOsdTrigger = (except === "osd" || except === "notifOsd")

        if (except !== "osd" && typeof Config.showOSD !== "undefined") Config.showOSD = false
        if (except !== "notifOsd" && typeof Config.showNotificationOsd !== "undefined") Config.showNotificationOsd = false

        if (!isOsdTrigger) {
            if (except !== "workspacePreview") Config.showWorkspacePreview = false
            if (except !== "power") Config.showPower = false
            if (except !== "wallpaper") Config.showWallpaper = false
            if (except !== "appLauncher") Config.showAppLauncher = false
            if (except !== "launcherOsd") Config.showLauncherOsd = false
            if (except !== "calendar") Config.showCalendar = false
            if (except !== "notifications") Config.showNotifications = false
            if (except !== "audio") Config.showAudio = false
            if (except !== "network") Config.showNetwork = false
            if (except !== "systemMonitor") Config.showSystemMonitor = false
            if (except !== "battery") Config.showBattery = false
            if (except !== "clipboard") Config.showClipboard = false
            if (except !== "screenRecorder") Config.showScreenRecorder = false
            if (except !== "mirror" && !Config.mirrorPinned) Config.showMirror = false
            if (except !== "controlCenter") Config.showControlCenter = false
            if (except !== "settings") Config.showSettings = false
            if (except !== "taskOverflow" && typeof Config.showTaskOverflow !== "undefined") Config.showTaskOverflow = false
        }
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
        function onShowAppLauncherChanged() { if (Config.showAppLauncher) { closeOthers("appLauncher"); let btn = leftCard ? leftCard.getButton("launcher") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowLauncherOsdChanged() { if (Config.showLauncherOsd) { closeOthers("launcherOsd") } updateActiveView() }
        function onShowPowerChanged() { if (Config.showPower) { closeOthers("power"); let btn = leftCard ? leftCard.getButton("power") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowWallpaperChanged() { if (Config.showWallpaper) { closeOthers("wallpaper"); let btn = leftCard ? leftCard.getButton("wallpaper") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowCalendarChanged() { if (Config.showCalendar) { closeOthers("calendar"); let btn = rightCard ? rightCard.getButton("clock") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowNotificationsChanged() { if (Config.showNotifications) { closeOthers("notifications"); let btn = leftCard ? leftCard.getButton("notifications") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowAudioChanged() { if (Config.showAudio) { closeOthers("audio"); let btn = leftCard ? leftCard.getButton("audio") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowNetworkChanged() { if (Config.showNetwork) { closeOthers("network"); let btn = leftCard ? leftCard.getButton("network") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowBatteryChanged() { if (Config.showBattery) { closeOthers("battery"); let btn = leftCard ? leftCard.getButton("batt") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowClipboardChanged() { if (Config.showClipboard) { closeOthers("clipboard"); let btn = leftCard ? leftCard.getButton("clipboard") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowScreenRecorderChanged() { if (Config.showScreenRecorder) { closeOthers("screenRecorder"); let btn = leftCard ? leftCard.getButton("recorder") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowMirrorChanged() {
            if (Config.showMirror) {
                closeOthers("mirror")
            }
            updateActiveView()
            if (Config.showMirror) {
                updateMirrorPopoutPos()
            }
        }
        function onMirrorAnchorPosChanged() {
            if (activeView === "mirror") {
                root.isOpen = false
                mirrorReopenTimer.restart()
            }
        }
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


            BarClosedShape { panelRoot: root; panelCanvas: mainContainer }
            BarOpenShapeLeft { panelRoot: root }
            BarOpenShapeTop { panelRoot: root }
            BarOpenShapeBottom { panelRoot: root; panelCanvas: mainContainer }
            BarOpenShapeRight { panelRoot: root; panelCanvas: mainContainer }

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
                    readonly property real rightBound: rightCard ? (root.isHorizontal ? (parent.width - rightCard.width - 30) : (parent.height - rightCard.height - 30)) : (root.isHorizontal ? parent.width : parent.height)
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
            }
        }
    }
}
