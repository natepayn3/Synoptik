import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "bars"
import "osds"

PanelWindow {
    id: root

    default property alias content: contentContainer.data

    property bool isOpen: false
    
    readonly property real actualScreenWidth: screen ? screen.width : 1920
    readonly property real actualScreenHeight: screen ? screen.height : 1080

    property real popoutXOffset: actualScreenWidth / 2.0
    property real popoutYOffset: actualScreenHeight / 2.0
    property bool isCentered: false

    function updatePlayerPopoutPos() {
        if (root.activeView !== "player") return

        let btn = centerGroupContainer ? centerGroupContainer.getButton("player") : null
        let centerPos = btn 
            ? (isHorizontal ? btn.mapToItem(mainContainer, btn.width / 2, 0).x : btn.mapToItem(mainContainer, 0, btn.height / 2).y) 
            : (isHorizontal ? mainContainer.width / 2.0 : mainContainer.height / 2.0)

        if (Config.playerAnchorPos === "top") {
            if (isHorizontal) root.popoutXOffset = inX + (rawChildWidth / 2.0) + 12
            else root.popoutYOffset = inY + (rawChildHeight / 2.0) + 12
        } else if (Config.playerAnchorPos === "bottom") {
            if (isHorizontal) root.popoutXOffset = (inX + inW) - (rawChildWidth / 2.0) - 12
            else root.popoutYOffset = (inY + inH) - (rawChildHeight / 2.0) - 12
        } else {
            if (isHorizontal) root.popoutXOffset = centerPos
            else root.popoutYOffset = centerPos
        }
    }

    readonly property real shadowPadding: 16

    readonly property string barPosition: Config.barPosition || "top"
    readonly property bool isHorizontal: barPosition === "top" || barPosition === "bottom"
    readonly property bool isBottom: barPosition === "bottom"
    readonly property bool isRight: barPosition === "right"

    property real currentMargin: Config.barFrameStyle === "floating" ? (Config.barMargin || 4) : 0
    Behavior on currentMargin {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    property real barRadius: Config.barFrameStyle === "floating" ? (Config.cornerRadius || 12) : 0
    Behavior on barRadius {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    readonly property bool isScreenFrame: Config.barFrameStyle === "screen"
    readonly property real framePadding: isScreenFrame ? 8 : 0
    readonly property real frameRadius: isScreenFrame ? (Config.surfaceRadius || 18) : 0

    readonly property real padL: barPosition === "left" ? barH + framePadding : framePadding
    readonly property real padR: barPosition === "right" ? barH + framePadding : framePadding
    readonly property real padT: barPosition === "top" ? barH + framePadding : framePadding
    readonly property real padB: barPosition === "bottom" ? barH + framePadding : framePadding

    readonly property real inX: padL
    readonly property real inY: padT
    readonly property real inW: actualScreenWidth - padL - padR
    readonly property real inH: actualScreenHeight - padT - padB
    readonly property real inRadi: Math.max(0.1, frameRadius)

    readonly property real rawChildWidth: {
        let baseW = 340
        if (root.activeView === "osd") {
            baseW = volumeOsdModule.implicitWidth
        } else if (root.activeView === "notifOsd") {
            baseW = notifOsdModule.implicitWidth
        } else if (root.activeView === "taskOverflow") {
            baseW = taskOverflowModule.implicitWidth
        } else {
            for (let i = 0; i < contentContainer.children.length; i++) {
                let child = contentContainer.children[i]
                if (child.objectName !== "internalOsd" && child.objectName !== "internalNotifOsd" && child.objectName !== "internalTaskOverflow") {
                    if (child.item && child.item.implicitWidth > 0) baseW = child.item.implicitWidth
                    else if (child.implicitWidth > 0) baseW = child.implicitWidth
                    break
                }
            }
        }
        return baseW
    }

    readonly property real rawChildHeight: {
        let baseH = 480
        if (root.activeView === "osd") {
            baseH = volumeOsdModule.implicitHeight
        } else if (root.activeView === "notifOsd") {
            baseH = notifOsdModule.implicitHeight
        } else if (root.activeView === "taskOverflow") {
            baseH = taskOverflowModule.implicitHeight
        } else {
            for (let i = 0; i < contentContainer.children.length; i++) {
                let child = contentContainer.children[i]
                if (child.objectName !== "internalOsd" && child.objectName !== "internalNotifOsd" && child.objectName !== "internalTaskOverflow") {
                    if (child.item && child.item.implicitHeight > 0) baseH = child.item.implicitHeight
                    else if (child.implicitHeight > 0) baseH = child.implicitHeight
                    break
                }
            }
        }
        return baseH
    }

    property real lastOpenWidth: rawChildWidth
    property real lastOpenHeight: rawChildHeight

    function playOpenSound() {
        if (!Config.playWindowSounds || root.activeView === "notifOsd" || root.activeView === "osd") return
        let soundFile = Quickshell.shellDir.toString().replace(/^file:\/\//, "") + "/assets/" + (Config.windowSoundPath || "sound1.wav")
        Quickshell.execDetached(["pw-play", "--volume", "0.25", soundFile])
    }

    onIsOpenChanged: {
        if (isOpen) {
            root.playOpenSound()
        } else {
            lastOpenWidth = rawChildWidth
            lastOpenHeight = rawChildHeight
        }
    }

    property real targetWidth: isOpen ? rawChildWidth : (isHorizontal ? (lastOpenWidth * 0.33) : (lastOpenWidth * 1.10))
    property real targetHeight: isOpen ? rawChildHeight : (isHorizontal ? (lastOpenHeight * 1.10) : (lastOpenHeight * 0.33))

    Behavior on targetWidth {
        NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
    }

    Behavior on targetHeight {
        NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
    }

    property real progress: 0.0
    readonly property real animScale: Math.max(0.0, progress)
    readonly property real closeFactor: root.isOpen ? progress : Math.pow(progress, 1.2)

    readonly property real currentHeight: targetHeight * Math.pow(closeFactor, 1.8)
    readonly property real squishRatio: targetHeight > 0 ? (1.0 - (currentHeight / targetHeight)) : 0.0
    readonly property real currentWidth: root.isOpen ? (targetWidth * animScale) : (targetWidth * (closeFactor + (0.3 * squishRatio * closeFactor)))

    readonly property real wingW: (Config.surfaceRadius || 18) * animScale
    readonly property real wingH: (Config.surfaceRadius || 18) * animScale
    readonly property real radius: Math.max(0.1, (Config.surfaceRadius || 18) * animScale)

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

    mask: Region {
        Region { item: barContent }
        Region { item: (root.isOpen || root.progress > 0.01) ? contentContainer : null }
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: Config.isBarEnabledForScreen(screen ? screen.name : "") ? (isScreenFrame ? (barH + (framePadding * 2)) : (barH + (currentMargin > 0 ? currentMargin : (Config.barMargin || 4)))) : 0
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "synoptik-shell"

    Shortcut {
        sequences: ["Escape"]
        enabled: root.isOpen
        onActivated: {
            root.closeOthers("none")
            root.isCentered = false
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: root.isOpen && root.activeView !== "osd" && root.activeView !== "notifOsd" && !(root.activeView === "player" && Config.playerPinned) && !(root.activeView === "mirror" && Config.mirrorPinned) && (!screen || screen.name === (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""))
        windows: [root]
        onCleared: {
            root.closeOthers("none")
            root.isCentered = false
        }
    }

    readonly property real minPossibleLeft: isScreenFrame ? ((isHorizontal ? inX : inY) + halfB) : halfB
    readonly property real maxPossibleRight: isScreenFrame ? ((isHorizontal ? inX + inW : inY + inH) - halfB) : ((isHorizontal ? mainContainer.width : mainContainer.height) - halfB)

    readonly property bool isLeftFlush: !isCentered && (
        (isHorizontal ? (popoutXOffset - (targetWidth / 2.0)) : (popoutYOffset - (targetHeight / 2.0))) < (minPossibleLeft + root.barRadius + root.wingW + (root.isScreenFrame ? root.inRadi : root.radius))
    )

    readonly property bool isRightFlush: !isCentered && (
        (isHorizontal ? (popoutXOffset + (targetWidth / 2.0)) : (popoutYOffset + (targetHeight / 2.0))) > (maxPossibleRight - root.barRadius - root.wingW - (root.isScreenFrame ? root.inRadi : root.radius))
    )

    readonly property real targetCenteredLeft: Math.max(minPossibleLeft + 16, Math.min(maxPossibleRight - (isHorizontal ? targetWidth : targetHeight) - 16, ((isHorizontal ? mainContainer.width : mainContainer.height) - (isHorizontal ? targetWidth : targetHeight)) / 2.0))

    readonly property real staticLeft: {
        let span = isHorizontal ? targetWidth : targetHeight
        let offset = isHorizontal ? popoutXOffset : popoutYOffset
        if (isCentered) return targetCenteredLeft
        if (isLeftFlush) return minPossibleLeft
        if (isRightFlush) return maxPossibleRight - span
        return Math.max(minPossibleLeft + 16, Math.min(maxPossibleRight - span - 16, offset - (span / 2.0)))
    }

    readonly property real staticRight: staticLeft + (isHorizontal ? targetWidth : targetHeight)

    readonly property real pLeft: staticLeft
    readonly property real pRight: staticRight

    property string activeView: "none"

    // Unified popout re-anchoring engine for ALL views
    onActiveViewChanged: {
        if (activeView === "none" || activeView === "workspacePreview") return

        // 1. Edge OSDs: Snap coordinates directly to screen boundaries
        if (activeView === "osd") {
            root.isCentered = false
            if (root.isHorizontal) root.popoutXOffset = mainContainer.width
            else root.popoutYOffset = mainContainer.height
            return
        }

        if (activeView === "notifOsd") {
            root.isCentered = false
            root.popoutXOffset = 0
            root.popoutYOffset = 0
            return
        }

        // 2. Bar Panel Modules: Map view IDs to button handles
        let btn = null

        switch (activeView) {
            // Left Card Modules
            case "settings":       btn = leftCard ? leftCard.getButton("settings") : null; break
            case "appLauncher":    btn = leftCard ? leftCard.getButton("launcher") : null; break
            case "power":          btn = leftCard ? leftCard.getButton("power") : null; break
            case "wallpaper":      btn = leftCard ? leftCard.getButton("wallpaper") : null; break
            case "notifications":  btn = leftCard ? leftCard.getButton("notifications") : null; break
            case "screenRecorder": btn = leftCard ? leftCard.getButton("recorder") : null; break
            case "mirror":         btn = leftCard ? leftCard.getButton("mirror") : null; break

            // Center Group Modules
            case "player":         btn = centerGroupContainer ? centerGroupContainer.getButton("player") : null; break
            case "taskOverflow":   btn = centerGroupContainer ? centerGroupContainer.getButton("apps") : null; break

            // Right Card Modules
            case "calendar":       btn = rightCard ? rightCard.getButton("clock") : null; break
            case "audio":          btn = rightCard ? rightCard.getButton("audio") : null; break
            case "network":        btn = rightCard ? rightCard.getButton("network") : null; break
            case "systemMonitor":  btn = rightCard ? rightCard.getButton("sys") : null; break
            case "battery":        btn = rightCard ? rightCard.getButton("batt") : null; break
            case "clipboard":      btn = rightCard ? rightCard.getButton("clipboard") : null; break
            case "controlCenter":  btn = rightCard ? rightCard.getButton("cc") : null; break
        }

        // Snap popout offset to the active button position or anchor mode
        if (activeView === "player") {
            updatePlayerPopoutPos()
        } else if (btn) {
            setPopoutPos(btn)
        }
    }

    function updateActiveView() {
        let nextView = "none"
        let isFocused = !screen || screen.name === (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")

        if (isFocused) {
            // High Priority OSD Takeover (Preserves underlying panel state)
            if (typeof Config.showOSD !== "undefined" && Config.showOSD) nextView = "osd"
            else if (typeof Config.showNotificationOsd !== "undefined" && Config.showNotificationOsd) nextView = "notifOsd"

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
            else if (Config.showPlayer && !Config.playerPinned) nextView = "player"
            else if (typeof Config.showTaskOverflow !== "undefined" && Config.showTaskOverflow) nextView = "taskOverflow"

            // Pinned Fallback Panels (Active when no temporary unpinned panel is open)
            else if (Config.showMirror && Config.mirrorPinned) nextView = "mirror"
            else if (Config.showPlayer && Config.playerPinned) nextView = "player"
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
            if (except !== "player" && !Config.playerPinned) Config.showPlayer = false
            if (except !== "taskOverflow" && typeof Config.showTaskOverflow !== "undefined") Config.showTaskOverflow = false
        }
    }

    Connections {
        target: Config
        ignoreUnknownSignals: true

        function onShowOSDChanged() {
            updateActiveView()
        }

        function onShowNotificationOsdChanged() {
            updateActiveView()
        }
        
        function onShowWorkspacePreviewChanged() {
            if (Config.showWorkspacePreview) {
                closeOthers("workspacePreview")
                root.isCentered = true
                root.popoutXOffset = mainContainer.width / 2.0
                root.popoutYOffset = mainContainer.height / 2.0
            } else if (activeView === "workspacePreview") {
                root.isCentered = false
            }
            updateActiveView()
        }
        function onShowSettingsChanged() {
            if (Config.showSettings) {
                closeOthers("settings")
                let btn = leftCard ? leftCard.getButton("settings") : (rightCard ? rightCard.getButton("settings") : null)
                if (btn) setPopoutPos(btn)
            }
            updateActiveView()
        }
        function onShowPlayerChanged() {
            if (Config.showPlayer) {
                closeOthers("player")
                updatePlayerPopoutPos()
            }
            updateActiveView()
        }
        function onPlayerAnchorPosChanged() {
            if (activeView === "player") {
                updatePlayerPopoutPos()
            }
        }
        function onShowTaskOverflowChanged() {
            if (Config.showTaskOverflow) {
                closeOthers("taskOverflow")
                let btn = centerGroupContainer ? centerGroupContainer.getButton("apps") : null
                if (btn) setPopoutPos(btn)
            }
            updateActiveView()
        }
        function onShowAppLauncherChanged() { if (Config.showAppLauncher) { closeOthers("appLauncher"); let btn = leftCard ? leftCard.getButton("launcher") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowPowerChanged() { if (Config.showPower) { closeOthers("power"); let btn = leftCard ? leftCard.getButton("power") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowWallpaperChanged() { if (Config.showWallpaper) { closeOthers("wallpaper"); let btn = leftCard ? leftCard.getButton("wallpaper") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowCalendarChanged() { if (Config.showCalendar) { closeOthers("calendar"); let btn = rightCard ? rightCard.getButton("clock") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowNotificationsChanged() { if (Config.showNotifications) { closeOthers("notifications"); let btn = leftCard ? leftCard.getButton("notifications") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowAudioChanged() { if (Config.showAudio) { closeOthers("audio"); let btn = rightCard ? rightCard.getButton("audio") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowNetworkChanged() { if (Config.showNetwork) { closeOthers("network"); let btn = rightCard ? rightCard.getButton("network") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowSystemMonitorChanged() { if (Config.showSystemMonitor) { closeOthers("systemMonitor"); let btn = rightCard ? rightCard.getButton("sys") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowBatteryChanged() { if (Config.showBattery) { closeOthers("battery"); let btn = rightCard ? rightCard.getButton("batt") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowClipboardChanged() { if (Config.showClipboard) { closeOthers("clipboard"); let btn = rightCard ? rightCard.getButton("clipboard") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowScreenRecorderChanged() { if (Config.showScreenRecorder) { closeOthers("screenRecorder"); let btn = leftCard ? leftCard.getButton("recorder") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowMirrorChanged() { if (Config.showMirror) { closeOthers("mirror"); let btn = leftCard ? leftCard.getButton("mirror") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
        function onShowControlCenterChanged() { if (Config.showControlCenter) { closeOthers("controlCenter"); let btn = rightCard ? rightCard.getButton("cc") : null; if (btn) setPopoutPos(btn); } updateActiveView() }
    }

    Item {
        id: mainContainer
        anchors.fill: parent
        anchors.margins: shadowPadding

        MouseArea {
            anchors.fill: parent
            enabled: root.isOpen
            onClicked: {
                root.closeOthers("none")
                root.isCentered = false
            }
        }

        states: [
            State { name: "open"; when: root.isOpen; PropertyChanges { target: root; progress: 1.0 } },
            State { name: "closed"; when: !root.isOpen; PropertyChanges { target: root; progress: 0.0 } }
        ]

        transitions: [
            Transition {
                from: "closed"; to: "open"
                NumberAnimation { target: root; property: "progress"; duration: 500; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation { target: root; property: "progress"; duration: 300; easing.type: Easing.InBack; easing.overshoot: 1.6 }
            }
        ]

        Item {
            id: shadowWrapper
            anchors.fill: parent

            layer.enabled: true
            layer.samples: 4
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#D0000000"
                shadowBlur: 0.7
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }

            Component {
                id: screenFrameCorners
                Shape {
                    anchors.fill: parent
                    readonly property bool popupActive: root.isOpen || root.progress > 0
                    readonly property bool hideTL: popupActive && ((root.barPosition === "left" && root.isLeftFlush) || (root.barPosition === "top" && root.isLeftFlush))
                    readonly property bool hideTR: popupActive && ((root.barPosition === "right" && root.isLeftFlush) || (root.barPosition === "top" && root.isRightFlush))
                    readonly property bool hideBL: popupActive && ((root.barPosition === "left" && root.isRightFlush) || (root.barPosition === "bottom" && root.isLeftFlush))
                    readonly property bool hideBR: popupActive && ((root.barPosition === "right" && root.isRightFlush) || (root.barPosition === "bottom" && root.isRightFlush))

                    ShapePath {
                        fillColor: hideTL ? "transparent" : Config.bgPanel; strokeWidth: 0
                        startX: root.inX; startY: root.inY
                        PathLine { x: root.inX + root.inRadi; y: root.inY }
                        PathArc { x: root.inX; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Counterclockwise }
                        PathLine { x: root.inX; y: root.inY }
                    }
                    ShapePath {
                        fillColor: hideTR ? "transparent" : Config.bgPanel; strokeWidth: 0
                        startX: root.inX + root.inW; startY: root.inY
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY }
                        PathArc { x: root.inX + root.inW; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inW; y: root.inY }
                    }
                    ShapePath {
                        fillColor: hideBL ? "transparent" : Config.bgPanel; strokeWidth: 0
                        startX: root.inX; startY: root.inY + root.inH
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH }
                        PathArc { x: root.inX; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX; y: root.inY + root.inH }
                    }
                    ShapePath {
                        fillColor: hideBR ? "transparent" : Config.bgPanel; strokeWidth: 0
                        startX: root.inX + root.inW; startY: root.inY + root.inH
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.inH }
                        PathArc { x: root.inX + root.inW; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Counterclockwise }
                        PathLine { x: root.inX + root.inW; y: root.inY + root.inH }
                    }
                }
            }

            Shape {
                id: closedShape
                anchors.fill: parent
                visible: root.progress === 0 && !root.isScreenFrame

                readonly property real bX: root.isRight ? (mainContainer.width - root.barH + root.halfB) : root.halfB
                readonly property real bY: root.isBottom ? (mainContainer.height - root.barH + root.halfB) : root.halfB
                readonly property real bW: root.isHorizontal ? (mainContainer.width - root.halfB) : (root.isRight ? (mainContainer.width - root.halfB) : (root.barH - root.halfB))
                readonly property real bH: root.isHorizontal ? (root.isBottom ? (mainContainer.height - root.halfB) : (root.barH - root.halfB)) : (mainContainer.height - root.halfB)

                ShapePath {
                    fillColor: Config.bgPanel
                    strokeWidth: root.borderWidth
                    strokeColor: shellRoot.currentBorderColor
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap

                    startX: closedShape.bX + root.barRadius
                    startY: closedShape.bY

                    PathLine { x: closedShape.bW - root.barRadius; y: closedShape.bY }
                    PathArc { x: closedShape.bW; y: closedShape.bY + root.barRadius; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: closedShape.bW; y: closedShape.bH - root.barRadius }
                    PathArc { x: closedShape.bW - root.barRadius; y: closedShape.bH; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: closedShape.bX + root.barRadius; y: closedShape.bH }
                    PathArc { x: closedShape.bX; y: closedShape.bH - root.barRadius; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: closedShape.bX; y: closedShape.bY + root.barRadius }
                    PathArc { x: closedShape.bX + root.barRadius; y: closedShape.bY; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                }
            }

            Shape {
                id: openShapeLeftFloating
                anchors.fill: parent
                visible: root.barPosition === "left" && !root.isScreenFrame && (root.isOpen || root.progress > 0)

                ShapePath {
                    fillColor: Config.bgPanel
                    strokeWidth: root.borderWidth
                    strokeColor: shellRoot.currentBorderColor
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap

                    startX: root.halfB + root.barRadius
                    startY: root.halfB
                    PathLine { x: root.isLeftFlush ? (root.barH - root.halfB) : (root.barH - root.halfB - root.barRadius); y: root.halfB }
                    PathArc { x: root.barH - root.halfB; y: root.isLeftFlush ? root.halfB : (root.halfB + root.barRadius); radiusX: root.isLeftFlush ? 0 : root.barRadius; radiusY: root.isLeftFlush ? 0 : root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.barH - root.halfB; y: root.isLeftFlush ? root.pLeft : (root.pLeft - root.wingW) }
                    PathCubic { x: root.barH - root.halfB + root.wingW; y: root.pLeft; control1X: root.barH - root.halfB; control1Y: root.isLeftFlush ? root.pLeft : (root.pLeft - (root.wingW * 0.5)); control2X: root.barH - root.halfB + (root.wingW * 0.5); control2Y: root.pLeft }
                    PathLine { x: root.barH - root.halfB + root.currentWidth - root.radius; y: root.pLeft }
                    PathArc { x: root.barH - root.halfB + root.currentWidth; y: root.pLeft + root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
                    PathLine { x: root.barH - root.halfB + root.currentWidth; y: root.pRight - root.radius }
                    PathArc { x: root.barH - root.halfB + root.currentWidth - root.radius; y: root.pRight; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
                    PathLine { x: root.barH - root.halfB + root.wingW; y: root.pRight }
                    PathCubic { x: root.barH - root.halfB; y: root.isRightFlush ? root.pRight : (root.pRight + root.wingW); control1X: root.barH - root.halfB + (root.wingW * 0.5); control1Y: root.pRight; control2X: root.barH - root.halfB; control2Y: root.isRightFlush ? root.pRight : (root.pRight + (root.wingW * 0.5)) }
                    PathLine { x: root.barH - root.halfB; y: root.isRightFlush ? (mainContainer.height - root.halfB) : (mainContainer.height - root.halfB - root.barRadius) }
                    PathArc { x: root.barH - root.halfB - (root.isRightFlush ? 0 : root.barRadius); y: mainContainer.height - root.halfB; radiusX: root.isRightFlush ? 0 : root.barRadius; radiusY: root.isRightFlush ? 0 : root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.halfB + root.barRadius; y: mainContainer.height - root.halfB }
                    PathArc { x: root.halfB; y: mainContainer.height - root.halfB - root.barRadius; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.halfB; y: root.halfB + root.barRadius }
                    PathArc { x: root.halfB + root.barRadius; y: root.halfB; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                }
            }

            Shape {
                id: openShapeTopFloating
                anchors.fill: parent
                visible: root.barPosition === "top" && !root.isScreenFrame && (root.isOpen || root.progress > 0)

                ShapePath {
                    fillColor: Config.bgPanel
                    strokeWidth: root.borderWidth
                    strokeColor: shellRoot.currentBorderColor
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap

                    startX: root.halfB + root.barRadius
                    startY: root.halfB
                    PathLine { x: mainContainer.width - root.halfB - root.barRadius; y: root.halfB }
                    PathArc { x: mainContainer.width - root.halfB; y: root.halfB + root.barRadius; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: mainContainer.width - root.halfB; y: root.isRightFlush ? (root.barBottomY + root.currentHeight - root.radius) : (root.barBottomY - root.barRadius) }
                    PathArc { x: root.isRightFlush ? (mainContainer.width - root.halfB) : (mainContainer.width - root.halfB - root.barRadius); y: root.isRightFlush ? (root.barBottomY + root.currentHeight - root.radius) : root.barBottomY; radiusX: root.isRightFlush ? 0 : root.barRadius; radiusY: root.isRightFlush ? 0 : root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.isRightFlush ? (mainContainer.width - root.halfB) : (root.pRight + root.wingW); y: root.isRightFlush ? (root.barBottomY + root.currentHeight - root.radius) : root.barBottomY }
                    PathCubic { x: root.isRightFlush ? (mainContainer.width - root.halfB) : root.pRight; y: root.isRightFlush ? (root.barBottomY + root.currentHeight - root.radius) : (root.barBottomY + root.wingH); control1X: root.isRightFlush ? (mainContainer.width - root.halfB) : (root.pRight + (root.wingW * 0.5)); control1Y: root.isRightFlush ? (root.barBottomY + root.currentHeight - root.radius) : root.barBottomY; control2X: root.isRightFlush ? (mainContainer.width - root.halfB) : root.pRight; control2Y: root.isRightFlush ? (root.barBottomY + root.currentHeight - root.radius) : (root.barBottomY + (root.wingH * 0.5)) }
                    PathLine { x: root.isRightFlush ? (mainContainer.width - root.halfB) : root.pRight; y: root.barBottomY + root.currentHeight - root.radius }
                    PathArc { x: root.isRightFlush ? (mainContainer.width - root.halfB - root.radius) : (root.pRight - root.radius); y: root.barBottomY + root.currentHeight; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
                    PathLine { x: root.isLeftFlush ? (root.halfB + root.radius) : (root.pLeft + root.radius); y: root.barBottomY + root.currentHeight }
                    PathArc { x: root.isLeftFlush ? root.halfB : root.pLeft; y: root.barBottomY + root.currentHeight - root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
                    PathLine { x: root.isLeftFlush ? root.halfB : root.pLeft; y: root.isLeftFlush ? (root.halfB + root.barRadius) : (root.barBottomY + root.wingH) }
                    PathCubic { x: root.isLeftFlush ? root.halfB : (root.pLeft - root.wingW); y: root.isLeftFlush ? (root.halfB + root.barRadius) : root.barBottomY; control1X: root.isLeftFlush ? root.halfB : root.pLeft; control1Y: root.isLeftFlush ? (root.halfB + root.barRadius) : (root.barBottomY + (root.wingH * 0.5)); control2X: root.isLeftFlush ? root.halfB : (root.pLeft - (root.wingW * 0.5)); control2Y: root.isLeftFlush ? (root.halfB + root.barRadius) : root.barBottomY }
                    PathLine { x: root.isLeftFlush ? root.halfB : (root.halfB + root.barRadius); y: root.isLeftFlush ? (root.halfB + root.barRadius) : root.barBottomY }
                    PathArc { x: root.halfB; y: root.isLeftFlush ? (root.halfB + root.barRadius) : (root.barBottomY - root.barRadius); radiusX: root.isLeftFlush ? 0 : root.barRadius; radiusY: root.isLeftFlush ? 0 : root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.halfB; y: root.halfB + root.barRadius }
                    PathArc { x: root.halfB + root.barRadius; y: root.halfB; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                }
            }

            Shape {
                id: openShapeBottomFloating
                anchors.fill: parent
                visible: root.barPosition === "bottom" && !root.isScreenFrame && (root.isOpen || root.progress > 0)
                readonly property real barTopY: mainContainer.height - root.barH + root.halfB

                ShapePath {
                    fillColor: Config.bgPanel
                    strokeWidth: root.borderWidth
                    strokeColor: shellRoot.currentBorderColor
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap

                    startX: root.halfB
                    startY: root.isLeftFlush ? openShapeBottomFloating.barTopY : (openShapeBottomFloating.barTopY + root.barRadius)
                    PathArc { x: root.halfB + (root.isLeftFlush ? 0 : root.barRadius); y: openShapeBottomFloating.barTopY; radiusX: root.isLeftFlush ? 0 : root.barRadius; radiusY: root.isLeftFlush ? 0 : root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.isLeftFlush ? root.halfB : (root.pLeft - root.wingW); y: openShapeBottomFloating.barTopY }
                    PathCubic { x: root.pLeft; y: root.isLeftFlush ? openShapeBottomFloating.barTopY : (openShapeBottomFloating.barTopY - root.wingH); control1X: root.isLeftFlush ? root.halfB : (root.pLeft - (root.wingW * 0.5)); control1Y: openShapeBottomFloating.barTopY; control2X: root.pLeft; control2Y: root.isLeftFlush ? openShapeBottomFloating.barTopY : (openShapeBottomFloating.barTopY - (root.wingH * 0.5)) }
                    PathLine { x: root.pLeft; y: openShapeBottomFloating.barTopY - root.currentHeight + root.radius }
                    PathArc { x: root.pLeft + root.radius; y: openShapeBottomFloating.barTopY - root.currentHeight; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
                    PathLine { x: root.pRight - root.radius; y: openShapeBottomFloating.barTopY - root.currentHeight }
                    PathArc { x: root.pRight; y: openShapeBottomFloating.barTopY - root.currentHeight + root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
                    PathLine { x: root.pRight; y: root.isRightFlush ? openShapeBottomFloating.barTopY : (openShapeBottomFloating.barTopY - root.wingH) }
                    PathCubic { x: root.isRightFlush ? (mainContainer.width - root.halfB) : (root.pRight + root.wingW); y: openShapeBottomFloating.barTopY; control1X: root.pRight; control1Y: root.isRightFlush ? openShapeBottomFloating.barTopY : (openShapeBottomFloating.barTopY - (root.wingH * 0.5)); control2X: root.isRightFlush ? (mainContainer.width - root.halfB) : (root.pRight + (root.wingW * 0.5)); control2Y: openShapeBottomFloating.barTopY }
                    PathLine { x: root.isRightFlush ? (mainContainer.width - root.halfB) : (mainContainer.width - root.halfB - root.barRadius); y: openShapeBottomFloating.barTopY }
                    PathArc { x: mainContainer.width - root.halfB; y: openShapeBottomFloating.barTopY + (root.isRightFlush ? 0 : root.barRadius); radiusX: root.isRightFlush ? 0 : root.barRadius; radiusY: root.isRightFlush ? 0 : root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: mainContainer.width - root.halfB; y: mainContainer.height - root.halfB - root.barRadius }
                    PathArc { x: mainContainer.width - root.halfB - root.barRadius; y: mainContainer.height - root.halfB; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.halfB + root.barRadius; y: mainContainer.height - root.halfB }
                    PathArc { x: root.halfB; y: mainContainer.height - root.halfB - root.barRadius; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.halfB; y: openShapeBottomFloating.barTopY + (root.isLeftFlush ? 0 : root.barRadius) }
                }
            }

            Shape {
                id: openShapeRightFloating
                anchors.fill: parent
                visible: root.barPosition === "right" && !root.isScreenFrame && (root.isOpen || root.progress > 0)
                readonly property real rX: mainContainer.width - root.barH

                ShapePath {
                    fillColor: Config.bgPanel
                    strokeWidth: root.borderWidth
                    strokeColor: shellRoot.currentBorderColor
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap

                    startX: openShapeRightFloating.rX + root.halfB + (root.isLeftFlush ? 0 : root.barRadius)
                    startY: root.halfB
                    PathLine { x: mainContainer.width - root.halfB - root.barRadius; y: root.halfB }
                    PathArc { x: mainContainer.width - root.halfB; y: root.halfB + root.barRadius; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: mainContainer.width - root.halfB; y: mainContainer.height - root.halfB - root.barRadius }
                    PathArc { x: mainContainer.width - root.halfB - root.barRadius; y: mainContainer.height - root.halfB; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: openShapeRightFloating.rX + root.halfB + root.barRadius; y: mainContainer.height - root.halfB }
                    PathArc { x: openShapeRightFloating.rX + root.halfB; y: mainContainer.height - root.halfB - (root.isRightFlush ? 0 : root.barRadius); radiusX: root.isRightFlush ? 0 : root.barRadius; radiusY: root.isRightFlush ? 0 : root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: openShapeRightFloating.rX + root.halfB; y: root.isRightFlush ? (mainContainer.height - root.halfB) : (root.pRight + root.wingW) }
                    PathCubic { x: root.isRightFlush ? (openShapeRightFloating.rX + root.halfB) : (openShapeRightFloating.rX + root.halfB - root.wingW); y: root.pRight; control1X: openShapeRightFloating.rX + root.halfB; control1Y: root.isRightFlush ? (mainContainer.height - root.halfB) : (root.pRight + (root.wingW * 0.5)); control2X: root.isRightFlush ? (openShapeRightFloating.rX + root.halfB) : (openShapeRightFloating.rX + root.halfB - (root.wingW * 0.5)); control2Y: root.pRight }
                    PathLine { x: openShapeRightFloating.rX + root.halfB - root.currentWidth + root.radius; y: root.pRight }
                    PathArc { x: openShapeRightFloating.rX + root.halfB - root.currentWidth; y: root.pRight - root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
                    PathLine { x: openShapeRightFloating.rX + root.halfB - root.currentWidth; y: root.pLeft + root.radius }
                    PathArc { x: openShapeRightFloating.rX + root.halfB - root.currentWidth + root.radius; y: root.pLeft; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
                    PathLine { x: root.isLeftFlush ? (openShapeRightFloating.rX + root.halfB) : (openShapeRightFloating.rX + root.halfB - root.wingW); y: root.pLeft }
                    
                    PathCubic { 
                        x: openShapeRightFloating.rX + root.halfB; 
                        y: root.isLeftFlush ? root.halfB : (root.pLeft - root.wingW); 
                        control1X: root.isLeftFlush ? (openShapeRightFloating.rX + root.halfB) : (openShapeRightFloating.rX + root.halfB - (root.wingW * 0.5)); 
                        control1Y: root.pLeft; 
                        control2X: openShapeRightFloating.rX + root.halfB; 
                        control2Y: root.isLeftFlush ? root.halfB : (root.pLeft - (root.wingW * 0.5)) 
                    }
                    PathLine { x: openShapeRightFloating.rX + root.halfB; y: root.isLeftFlush ? root.halfB : (root.halfB + root.barRadius) }
                    PathArc { x: openShapeRightFloating.rX + root.halfB + (root.isLeftFlush ? 0 : root.barRadius); y: root.halfB; radiusX: root.isLeftFlush ? 0 : root.barRadius; radiusY: root.isLeftFlush ? 0 : root.barRadius; direction: PathArc.Clockwise }
                }
            }

            Item {
                id: sfClosedGroup
                anchors.fill: parent
                visible: root.progress === 0 && root.isScreenFrame

                Rectangle { x: 0; y: 0; width: mainContainer.width; height: root.inY; color: Config.bgPanel }
                Rectangle { x: 0; y: root.inY + root.inH; width: mainContainer.width; height: mainContainer.height - (root.inY + root.inH); color: Config.bgPanel }
                Rectangle { x: 0; y: root.inY; width: root.inX; height: root.inH; color: Config.bgPanel }
                Rectangle { x: root.inX + root.inW; y: root.inY; width: mainContainer.width - (root.inX + root.inW); height: root.inH; color: Config.bgPanel }

                Loader { anchors.fill: parent; sourceComponent: screenFrameCorners }

                Shape {
                    anchors.fill: parent
                    ShapePath {
                        fillColor: "transparent"
                        strokeWidth: root.borderWidth
                        strokeColor: shellRoot.currentBorderColor
                        joinStyle: ShapePath.RoundJoin
                        capStyle: ShapePath.RoundCap

                        startX: root.inX + root.inRadi
                        startY: root.inY + root.halfB

                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.halfB }
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.inY + root.inH - root.inRadi }
                        PathArc { x: root.inX + root.inW - root.inRadi; y: root.inY + root.inH - root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH - root.halfB }
                        PathArc { x: root.inX + root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi }
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                    }
                }
            }

            Item {
                id: sfOpenGroupLeft
                anchors.fill: parent
                visible: root.barPosition === "left" && root.isScreenFrame && (root.isOpen || root.progress > 0)

                Rectangle { x: 0; y: 0; width: mainContainer.width; height: root.inY; color: Config.bgPanel }
                Rectangle { x: 0; y: root.inY + root.inH; width: mainContainer.width; height: mainContainer.height - (root.inY + root.inH); color: Config.bgPanel }
                Rectangle { x: 0; y: root.inY; width: root.inX; height: root.inH; color: Config.bgPanel }
                Rectangle { x: root.inX + root.inW; y: root.inY; width: mainContainer.width - (root.inX + root.inW); height: root.inH; color: Config.bgPanel }

                Loader { anchors.fill: parent; sourceComponent: screenFrameCorners }

                Shape {
                    anchors.fill: parent; visible: !root.isLeftFlush && !root.isRightFlush
                    ShapePath {
                        fillColor: Config.bgPanel; strokeWidth: 0
                        startX: root.inX; startY: root.pLeft - root.wingW
                        PathCubic { x: root.inX + root.wingW; y: root.pLeft; control1X: root.inX; control1Y: root.pLeft - root.wingW * 0.5; control2X: root.inX + root.wingW * 0.5; control2Y: root.pLeft }
                        PathLine { x: root.leftBarRx - root.radius; y: root.pLeft }
                        PathArc { x: root.leftBarRx; y: root.pLeft + root.radius; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Clockwise }
                        PathLine { x: root.leftBarRx; y: root.pRight - root.radius }
                        PathArc { x: root.leftBarRx - root.radius; y: root.pRight; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.wingW; y: root.pRight }
                        PathCubic { x: root.inX; y: root.pRight + root.wingW; control1X: root.inX + root.wingW * 0.5; control1Y: root.pRight; control2X: root.inX; control2Y: root.pRight + root.wingW * 0.5 }
                        PathLine { x: root.inX; y: root.pLeft - root.wingW }
                    }
                }
                Shape {
                    anchors.fill: parent; visible: root.isLeftFlush
                    ShapePath {
                        fillColor: Config.bgPanel; strokeWidth: 0
                        startX: root.inX; startY: root.inY
                        
                        PathLine { x: root.leftBarRx + root.wingW; y: root.inY } 
                        PathCubic { x: root.leftBarRx; y: root.inY + root.wingW; control1X: root.leftBarRx + root.wingW * 0.5; control1Y: root.inY; control2X: root.leftBarRx; control2Y: root.inY + root.wingW * 0.5 }
                        
                        PathLine { x: root.leftBarRx; y: root.pRight - root.radius } 
                        PathArc { x: root.leftBarRx - root.radius; y: root.pRight; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Clockwise } 
                        
                        PathLine { x: root.inX + root.wingW; y: root.pRight } 
                        PathCubic { x: root.inX; y: root.pRight + root.wingW; control1X: root.inX + root.wingW * 0.5; control1Y: root.pRight; control2X: root.inX; control2Y: root.pRight + root.wingW * 0.5 } 
                        
                        PathLine { x: root.inX; y: root.inY } 
                    }
                }
                Shape {
                    anchors.fill: parent; visible: root.isRightFlush
                    ShapePath {
                        fillColor: Config.bgPanel; strokeWidth: 0
                        startX: root.inX; startY: root.pLeft - root.wingW
                        
                        PathCubic { x: root.inX + root.wingW; y: root.pLeft; control1X: root.inX; control1Y: root.pLeft - root.wingW * 0.5; control2X: root.inX + root.wingW * 0.5; control2Y: root.pLeft }
                        PathLine { x: root.leftBarRx - root.radius; y: root.pLeft }
                        PathArc { x: root.leftBarRx; y: root.pLeft + root.radius; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Clockwise }
                        
                        PathLine { x: root.leftBarRx; y: root.inY + root.inH - root.wingW }
                        PathCubic { x: root.leftBarRx + root.wingW; y: root.inY + root.inH; control1X: root.leftBarRx; control1Y: root.inY + root.inH - root.wingW * 0.5; control2X: root.leftBarRx + root.wingW * 0.5; control2Y: root.inY + root.inH }
                        
                        PathLine { x: root.inX; y: root.inY + root.inH }
                        PathLine { x: root.inX; y: root.pLeft - root.wingW }
                    }
                }

                Shape {
                    anchors.fill: parent; visible: !root.isLeftFlush && !root.isRightFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: root.borderWidth; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inW - root.inRadi; startY: root.inY + root.halfB
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.inY + root.inH - root.inRadi }
                        PathArc { x: root.inX + root.inW - root.inRadi; y: root.inY + root.inH - root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH - root.halfB }
                        PathArc { x: root.inX + root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.halfB; y: root.pRight + root.wingW }
                        PathCubic { x: root.inX + root.wingW; y: root.pRight; control1X: root.inX + root.halfB; control1Y: root.pRight + root.wingW * 0.5; control2X: root.inX + root.wingW * 0.5; control2Y: root.pRight }
                        PathLine { x: root.leftBarRx - root.radius; y: root.pRight }
                        PathArc { x: root.leftBarRx; y: root.pRight - root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise }
                        PathLine { x: root.leftBarRx; y: root.pLeft + root.radius }
                        PathArc { x: root.leftBarRx - root.radius; y: root.pLeft; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise }
                        PathLine { x: root.inX + root.wingW; y: root.pLeft }
                        PathCubic { x: root.inX + root.halfB; y: root.pLeft - root.wingW; control1X: root.inX + root.wingW * 0.5; control1Y: root.pLeft; control2X: root.inX + root.halfB; control2Y: root.pLeft - root.wingW * 0.5 }
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi }
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.halfB }
                    }
                }
                Shape {
                    anchors.fill: parent; visible: root.isLeftFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: root.borderWidth; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inW - root.inRadi; startY: root.inY + root.halfB
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.inY + root.inH - root.inRadi }
                        PathArc { x: root.inX + root.inW - root.inRadi; y: root.inY + root.inH - root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH - root.halfB }
                        PathArc { x: root.inX + root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        
                        PathLine { x: root.inX + root.halfB; y: root.pRight + root.wingW } 
                        PathCubic { x: root.inX + root.wingW; y: root.pRight; control1X: root.inX + root.halfB; control1Y: root.pRight + root.wingW * 0.5; control2X: root.inX + root.wingW * 0.5; control2Y: root.pRight } 
                        
                        PathLine { x: root.leftBarRx - root.radius; y: root.pRight } 
                        PathArc { x: root.leftBarRx; y: root.pRight - root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise } 
                        
                        PathLine { x: root.leftBarRx; y: root.inY + root.halfB + root.wingW } 
                        PathCubic { x: root.leftBarRx + root.wingW; y: root.inY + root.halfB; control1X: root.leftBarRx; control1Y: root.inY + root.halfB + root.wingW * 0.5; control2X: root.leftBarRx + root.wingW * 0.5; control2Y: root.inY + root.halfB } 
                        
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.halfB } 
                    }
                }
                Shape {
                    anchors.fill: parent; visible: root.isRightFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: root.borderWidth; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inRadi; startY: root.inY + root.halfB
                        
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.halfB }
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.inY + root.inH - root.inRadi }
                        PathArc { x: root.inX + root.inW - root.inRadi; y: root.inY + root.inH - root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        
                        PathLine { x: root.leftBarRx + root.wingW; y: root.inY + root.inH - root.halfB }
                        PathCubic { x: root.leftBarRx; y: root.inY + root.inH - root.halfB - root.wingW; control1X: root.leftBarRx + root.wingW * 0.5; control1Y: root.inY + root.inH - root.halfB; control2X: root.leftBarRx; control2Y: root.inY + root.inH - root.halfB - root.wingW * 0.5 }
                        
                        PathLine { x: root.leftBarRx; y: root.pLeft + root.radius }
                        PathArc { x: root.leftBarRx - root.radius; y: root.pLeft; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise }
                        
                        PathLine { x: root.inX + root.wingW; y: root.pLeft }
                        PathCubic { x: root.inX + root.halfB; y: root.pLeft - root.wingW; control1X: root.inX + root.wingW * 0.5; control1Y: root.pLeft; control2X: root.inX + root.halfB; control2Y: root.pLeft - root.wingW * 0.5 }
                        
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi }
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                    }
                }
            }

            Item {
                id: sfOpenGroupRight
                anchors.fill: parent
                visible: root.barPosition === "right" && root.isScreenFrame && (root.isOpen || root.progress > 0)

                Rectangle { x: 0; y: 0; width: mainContainer.width; height: root.inY; color: Config.bgPanel }
                Rectangle { x: 0; y: root.inY + root.inH; width: mainContainer.width; height: mainContainer.height - (root.inY + root.inH); color: Config.bgPanel }
                Rectangle { x: 0; y: root.inY; width: root.inX; height: root.inH; color: Config.bgPanel }
                Rectangle { x: root.inX + root.inW; y: root.inY; width: mainContainer.width - (root.inX + root.inW); height: root.inH; color: Config.bgPanel }

                Loader { anchors.fill: parent; sourceComponent: screenFrameCorners }

                Shape {
                    anchors.fill: parent; visible: !root.isLeftFlush && !root.isRightFlush
                    ShapePath {
                        fillColor: Config.bgPanel; strokeWidth: 0
                        startX: root.inX + root.inW; startY: root.pRight + root.wingW
                        PathLine { x: root.inX + root.inW; y: root.pLeft - root.wingW }
                        PathCubic { x: root.inX + root.inW - root.wingW; y: root.pLeft; control1X: root.inX + root.inW; control1Y: root.pLeft - root.wingW * 0.5; control2X: root.inX + root.inW - root.wingW * 0.5; control2Y: root.pLeft }
                        PathLine { x: root.rightBarPopL + root.radius; y: root.pLeft }
                        PathArc { x: root.rightBarPopL; y: root.pLeft + root.radius; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Counterclockwise }
                        PathLine { x: root.rightBarPopL; y: root.pRight - root.radius }
                        PathArc { x: root.rightBarPopL + root.radius; y: root.pRight; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Counterclockwise }
                        PathLine { x: root.inX + root.inW - root.wingW; y: root.pRight }
                        PathCubic { x: root.inX + root.inW; y: root.pRight + root.wingW; control1X: root.inX + root.inW - root.wingW * 0.5; control1Y: root.pRight; control2X: root.inX + root.inW; control2Y: root.pRight + root.wingW * 0.5 }
                    }
                }
                Shape {
                    anchors.fill: parent; visible: root.isLeftFlush
                    ShapePath {
                        fillColor: Config.bgPanel; strokeWidth: 0
                        startX: root.inX + root.inW; startY: root.pRight + root.wingW
                        PathLine { x: root.inX + root.inW; y: root.inY }
                        PathLine { x: root.rightBarPopL - root.wingW; y: root.inY }
                        PathCubic { x: root.rightBarPopL; y: root.inY + root.wingW; control1X: root.rightBarPopL - root.wingW * 0.5; control1Y: root.inY; control2X: root.rightBarPopL; control2Y: root.inY + root.wingW * 0.5 }
                        PathLine { x: root.rightBarPopL; y: root.pRight - root.radius }
                        PathArc { x: root.rightBarPopL + root.radius; y: root.pRight; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Counterclockwise }
                        PathLine { x: root.inX + root.inW - root.wingW; y: root.pRight }
                        PathCubic { x: root.inX + root.inW; y: root.pRight + root.wingW; control1X: root.inX + root.inW - root.wingW * 0.5; control1Y: root.pRight; control2X: root.inX + root.inW; control2Y: root.pRight + root.wingW * 0.5 }
                    }
                }
                Shape {
                    anchors.fill: parent; visible: root.isRightFlush
                    ShapePath {
                        fillColor: Config.bgPanel; strokeWidth: 0
                        startX: root.inX + root.inW; startY: root.inY + root.inH
                        
                        PathLine { x: root.inX + root.inW; y: root.pLeft - root.wingW } 
                        PathCubic { x: root.inX + root.inW - root.wingW; y: root.pLeft; control1X: root.inX + root.inW; control1Y: root.pLeft - root.wingW * 0.5; control2X: root.inX + root.inW - root.wingW * 0.5; control2Y: root.pLeft }
                        
                        PathLine { x: root.rightBarPopL + root.radius; y: root.pLeft } 
                        PathArc { x: root.rightBarPopL; y: root.pLeft + root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise } 
                        
                        PathLine { x: root.rightBarPopL; y: root.inY + root.inH - root.wingW } 
                        PathCubic { x: root.rightBarPopL - root.wingW; y: root.inY + root.inH; control1X: root.rightBarPopL; control1Y: root.inY + root.inH - root.wingW * 0.5; control2X: root.rightBarPopL - root.wingW * 0.5; control2Y: root.inY + root.inH } 
                        
                        PathLine { x: root.inX + root.inW; y: root.inY + root.inH } 
                    }
                }

                Shape {
                    anchors.fill: parent; visible: !root.isLeftFlush && !root.isRightFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: root.borderWidth; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inRadi; startY: root.inY + root.halfB
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.halfB }
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.pLeft - root.wingW }
                        PathCubic { x: root.inX + root.inW - root.wingW; y: root.pLeft; control1X: root.inX + root.inW - root.halfB; control1Y: root.pLeft - root.wingW * 0.5; control2X: root.inX + root.inW - root.wingW * 0.5; control2Y: root.pLeft }
                        PathLine { x: root.rightBarPopL + root.radius; y: root.pLeft }
                        PathArc { x: root.rightBarPopL; y: root.pLeft + root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise }
                        PathLine { x: root.rightBarPopL; y: root.pRight - root.radius }
                        PathArc { x: root.rightBarPopL + root.radius; y: root.pRight; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise }
                        PathLine { x: root.inX + root.inW - root.wingW; y: root.pRight }
                        PathCubic { x: root.inX + root.inW - root.halfB; y: root.pRight + root.wingW; control1X: root.inX + root.inW - root.wingW * 0.5; control1Y: root.pRight; control2X: root.inX + root.inW - root.halfB; control2Y: root.pRight + root.wingW * 0.5 }
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.inY + root.inH - root.inRadi }
                        PathArc { x: root.inX + root.inW - root.inRadi; y: root.inY + root.inH - root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH - root.halfB }
                        PathArc { x: root.inX + root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi }
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                    }
                }
                Shape {
                    anchors.fill: parent; visible: root.isLeftFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: root.borderWidth; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inRadi; startY: root.inY + root.halfB
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.inY + root.inH - root.inRadi }
                        PathArc { x: root.inX + root.inW - root.inRadi; y: root.inY + root.inH - root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH - root.halfB }
                        PathArc { x: root.inX + root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        
                        PathLine { x: root.inX + root.halfB; y: root.pRight + root.wingW } 
                        PathCubic { x: root.inX + root.wingW; y: root.pRight; control1X: root.inX + root.halfB; control1Y: root.pRight + root.wingW * 0.5; control2X: root.inX + root.wingW * 0.5; control2Y: root.pRight } 
                        
                        PathLine { x: root.leftBarRx - root.radius; y: root.pRight } 
                        PathArc { x: root.leftBarRx; y: root.pRight - root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise } 
                        
                        PathLine { x: root.leftBarRx; y: root.inY + root.halfB + root.wingW } 
                        PathCubic { x: root.leftBarRx + root.wingW; y: root.inY + root.halfB; control1X: root.leftBarRx; control1Y: root.inY + root.halfB + root.wingW * 0.5; control2X: root.leftBarRx + root.wingW * 0.5; control2Y: root.inY + root.halfB } 
                        
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.halfB } 
                    }
                }
                Shape {
                    anchors.fill: parent; visible: root.isRightFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: root.borderWidth; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inRadi; startY: root.inY + root.halfB
                        
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.halfB }
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.pLeft - root.wingW } 
                        PathCubic { x: root.inX + root.inW - root.halfB - root.wingW; y: root.pLeft; control1X: root.inX + root.inW - root.halfB; control1Y: root.pLeft - root.wingW * 0.5; control2X: root.inX + root.inW - root.halfB - root.wingW * 0.5; control2Y: root.pLeft }
                        
                        PathLine { x: root.rightBarPopL + root.radius; y: root.pLeft } 
                        PathArc { x: root.rightBarPopL; y: root.pLeft + root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise } 
                        
                        PathLine { x: root.rightBarPopL; y: root.inY + root.inH - root.halfB - root.wingW } 
                        PathCubic { x: root.rightBarPopL - root.wingW; y: root.inY + root.inH - root.halfB; control1X: root.rightBarPopL; control1Y: root.inY + root.inH - root.halfB - root.wingW * 0.5; control2X: root.rightBarPopL - root.wingW * 0.5; control2Y: root.inY + root.inH } 
                        
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH - root.halfB } 
                        PathArc { x: root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi } 
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                    }
                }
            }

            Item {
                id: sfOpenGroupTop
                anchors.fill: parent
                visible: root.barPosition === "top" && root.isScreenFrame && (root.isOpen || root.progress > 0)

                Rectangle { x: 0; y: 0; width: mainContainer.width; height: root.inY; color: Config.bgPanel }
                Rectangle { x: 0; y: root.inY + root.inH; width: mainContainer.width; height: mainContainer.height - (root.inY + root.inH); color: Config.bgPanel }
                Rectangle { x: 0; y: root.inY; width: root.inX; height: root.inH; color: Config.bgPanel }
                Rectangle { x: root.inX + root.inW; y: root.inY; width: mainContainer.width - (root.inX + root.inW); height: root.inH; color: Config.bgPanel }

                Loader { anchors.fill: parent; sourceComponent: screenFrameCorners }

                Shape {
                    anchors.fill: parent; visible: !root.isLeftFlush && !root.isRightFlush
                    ShapePath {
                        fillColor: Config.bgPanel; strokeWidth: 0
                        startX: root.pLeft - root.wingW; startY: root.inY
                        PathLine { x: root.pRight + root.wingW; y: root.inY }
                        PathCubic { x: root.pRight; y: root.inY + root.wingW; control1X: root.pRight + root.wingW * 0.5; control1Y: root.inY; control2X: root.pRight; control2Y: root.inY + root.wingW * 0.5 }
                        PathLine { x: root.pRight; y: root.topBarPopB - root.radius }
                        PathArc { x: root.pRight - root.radius; y: root.topBarPopB; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Clockwise }
                        PathLine { x: root.pLeft + root.radius; y: root.topBarPopB }
                        PathArc { x: root.pLeft; y: root.topBarPopB - root.radius; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Clockwise }
                        PathLine { x: root.pLeft; y: root.inY + root.wingW }
                        PathCubic { x: root.pLeft - root.wingW; y: root.inY; control1X: root.pLeft; control1Y: root.inY + root.wingW * 0.5; control2X: root.pLeft - root.wingW * 0.5; control2Y: root.inY }
                    }
                }
                Shape {
                    anchors.fill: parent; visible: root.isLeftFlush
                    ShapePath {
                        fillColor: Config.bgPanel; strokeWidth: 0
                        startX: root.inX; startY: root.inY
                        
                        PathLine { x: root.pRight + root.wingW; y: root.inY } 
                        PathCubic { x: root.pRight; y: root.inY + root.wingW; control1X: root.pRight + root.wingW * 0.5; control1Y: root.inY; control2X: root.pRight; control2Y: root.inY + root.wingW * 0.5 }
                        
                        PathLine { x: root.pRight; y: root.topBarPopB - root.radius } 
                        PathArc { x: root.pRight - root.radius; y: root.topBarPopB; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Clockwise } 
                        
                        PathLine { x: root.inX + root.wingW; y: root.topBarPopB } 
                        PathCubic { x: root.inX; y: root.topBarPopB + root.wingW; control1X: root.inX + root.wingW * 0.5; control1Y: root.topBarPopB; control2X: root.inX; control2Y: root.topBarPopB + root.wingW * 0.5 } 
                        
                        PathLine { x: root.inX; y: root.inY } 
                    }
                }
                Shape {
                    anchors.fill: parent; visible: root.isRightFlush
                    ShapePath {
                        fillColor: Config.bgPanel; strokeWidth: 0
                        startX: root.pLeft - root.wingW; startY: root.inY
                        
                        PathLine { x: root.inX + root.inW; y: root.inY } 
                        
                        PathLine { x: root.inX + root.inW; y: root.topBarPopB + root.wingW } 
                        PathCubic { x: root.inX + root.inW - root.wingW; y: root.topBarPopB; control1X: root.inX + root.inW; control1Y: root.topBarPopB + root.wingW * 0.5; control2X: root.inX + root.inW - root.wingW * 0.5; control2Y: root.topBarPopB }
                        
                        PathLine { x: root.pLeft + root.radius; y: root.topBarPopB } 
                        PathArc { x: root.pLeft; y: root.topBarPopB - root.radius; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Clockwise } 
                        
                        PathLine { x: root.pLeft; y: root.inY + root.wingW } 
                        PathCubic { x: root.pLeft - root.wingW; y: root.inY; control1X: root.pLeft; control1Y: root.inY + root.wingW * 0.5; control2X: root.pLeft - root.wingW * 0.5; control2Y: root.inY } 
                    }
                }

                Shape {
                    anchors.fill: parent; visible: !root.isLeftFlush && !root.isRightFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: root.borderWidth; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inW - root.inRadi; startY: root.inY + root.halfB
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.inY + root.inH - root.inRadi }
                        PathArc { x: root.inX + root.inW - root.inRadi; y: root.inY + root.inH - root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH - root.halfB }
                        PathArc { x: root.inX + root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi }
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.pLeft - root.wingW; y: root.inY + root.halfB }
                        PathCubic { x: root.pLeft; y: root.inY + root.halfB + root.wingW; control1X: root.pLeft - root.wingW * 0.5; control1Y: root.inY + root.halfB; control2X: root.pLeft; control2Y: root.inY + root.halfB + root.wingW * 0.5 }
                        PathLine { x: root.pLeft; y: root.topBarPopB - root.radius }
                        PathArc { x: root.pLeft + root.radius; y: root.topBarPopB; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise }
                        PathLine { x: root.pRight - root.radius; y: root.topBarPopB }
                        PathArc { x: root.pRight; y: root.topBarPopB - root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise }
                        PathLine { x: root.pRight; y: root.inY + root.halfB + root.wingW }
                        PathCubic { x: root.pRight + root.wingW; y: root.inY + root.halfB; control1X: root.pRight; control1Y: root.inY + root.halfB + root.wingW * 0.5; control2X: root.pRight + root.wingW * 0.5; control2Y: root.inY + root.halfB }
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.halfB }
                    }
                }
                Shape {
                    anchors.fill: parent; visible: root.isLeftFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: root.borderWidth; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inW - root.inRadi; startY: root.inY + root.halfB
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.inY + root.inH - root.inRadi }
                        PathArc { x: root.inX + root.inW - root.inRadi; y: root.inY + root.inH - root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH - root.halfB }
                        PathArc { x: root.inX + root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        
                        PathLine { x: root.inX + root.halfB; y: root.topBarPopB + root.wingW }
                        PathCubic { x: root.inX + root.halfB + root.wingW; y: root.topBarPopB; control1X: root.inX + root.halfB; control1Y: root.topBarPopB + root.wingW * 0.5; control2X: root.inX + root.halfB + root.wingW * 0.5; control2Y: root.topBarPopB }
                        
                        PathLine { x: root.pRight - root.radius; y: root.topBarPopB } 
                        PathArc { x: root.pRight; y: root.topBarPopB - root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise }
                        
                        PathLine { x: root.pRight; y: root.inY + root.halfB + root.wingW } 
                        PathCubic { x: root.pRight + root.wingW; y: root.inY + root.halfB; control1X: root.pRight; control1Y: root.inY + root.halfB + root.wingW * 0.5; control2X: root.pRight + root.wingW * 0.5; control2Y: root.inY + root.halfB } 
                        
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.halfB } 
                    }
                }
                Shape {
                    anchors.fill: parent; visible: root.isRightFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: root.borderWidth; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inRadi; startY: root.inY + root.halfB
                        
                        PathLine { x: root.pLeft - root.wingW; y: root.inY + root.halfB } 
                        PathCubic { x: root.pLeft; y: root.inY + root.halfB + root.wingW; control1X: root.pLeft - root.wingW * 0.5; control1Y: root.inY + root.halfB; control2X: root.pLeft; control2Y: root.inY + root.halfB + root.wingW * 0.5 }
                        
                        PathLine { x: root.pLeft; y: root.topBarPopB - root.radius } 
                        PathArc { x: root.pLeft + root.radius; y: root.topBarPopB; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise }
                        
                        PathLine { x: root.inX + root.inW - root.halfB - root.wingW; y: root.topBarPopB }
                        PathCubic { x: root.inX + root.inW - root.halfB; y: root.topBarPopB + root.wingW; control1X: root.inX + root.inW - root.halfB - root.wingW * 0.5; control1Y: root.topBarPopB; control2X: root.inX + root.inW - root.halfB; control2Y: root.topBarPopB + root.wingW * 0.5 }
                        
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.inY + root.inH - root.inRadi }
                        PathArc { x: root.inX + root.inW - root.inRadi; y: root.inY + root.inH - root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH - root.halfB }
                        PathArc { x: root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi }
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                    }
                }
            }

            Item {
                id: sfOpenGroupBottom
                anchors.fill: parent
                visible: root.barPosition === "bottom" && root.isScreenFrame && (root.isOpen || root.progress > 0)

                Rectangle { x: 0; y: 0; width: mainContainer.width; height: root.inY; color: Config.bgPanel }
                Rectangle { x: 0; y: root.inY + root.inH; width: mainContainer.width; height: mainContainer.height - (root.inY + root.inH); color: Config.bgPanel }
                Rectangle { x: 0; y: root.inY; width: root.inX; height: root.inH; color: Config.bgPanel }
                Rectangle { x: root.inX + root.inW; y: root.inY; width: mainContainer.width - (root.inX + root.inW); height: root.inH; color: Config.bgPanel }

                Loader { anchors.fill: parent; sourceComponent: screenFrameCorners }

                Shape {
                    anchors.fill: parent; visible: !root.isLeftFlush && !root.isRightFlush
                    ShapePath {
                        fillColor: Config.bgPanel; strokeWidth: 0
                        startX: root.pLeft - root.wingW; startY: root.inY + root.inH
                        PathLine { x: root.pRight + root.wingW; y: root.inY + root.inH }
                        PathCubic { x: root.pRight; y: root.inY + root.inH - root.wingW; control1X: root.pRight + root.wingW * 0.5; control1Y: root.inY + root.inH; control2X: root.pRight; control2Y: root.inY + root.inH - root.wingW * 0.5 }
                        PathLine { x: root.pRight; y: root.bottomBarPopT + root.radius }
                        PathArc { x: root.pRight - root.radius; y: root.bottomBarPopT; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Counterclockwise }
                        PathLine { x: root.pLeft + root.radius; y: root.bottomBarPopT }
                        PathArc { x: root.pLeft; y: root.bottomBarPopT + root.radius; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Counterclockwise }
                        PathLine { x: root.pLeft; y: root.inY + root.inH - root.wingW }
                        PathCubic { x: root.pLeft - root.wingW; y: root.inY + root.inH; control1X: root.pLeft; control1Y: root.inY + root.inH - root.wingW * 0.5; control2X: root.pLeft - root.wingW * 0.5; control2Y: root.inY + root.inH }
                    }
                }

                Shape {
                    anchors.fill: parent; visible: root.isLeftFlush
                    ShapePath {
                        fillColor: Config.bgPanel; strokeWidth: 0
                        startX: root.inX; startY: root.inY + root.inH
                        
                        PathLine { x: root.pRight + root.wingW; y: root.inY + root.inH } 
                        PathCubic { x: root.pRight; y: root.inY + root.inH - root.wingW; control1X: root.pRight + root.wingW * 0.5; control1Y: root.inY + root.inH; control2X: root.pRight; control2Y: root.inY + root.inH - root.wingW * 0.5 }
                        
                        PathLine { x: root.pRight; y: root.bottomBarPopT + root.radius } 
                        PathArc { x: root.pRight - root.radius; y: root.bottomBarPopT; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Counterclockwise } 
                        
                        PathLine { x: root.inX + root.wingW; y: root.bottomBarPopT } 
                        PathCubic { x: root.inX; y: root.bottomBarPopT - root.wingW; control1X: root.inX + root.wingW * 0.5; control1Y: root.bottomBarPopT; control2X: root.inX; control2Y: root.bottomBarPopT - root.wingW * 0.5 }
                        
                        PathLine { x: root.inX; y: root.inY + root.inRadi }
                        PathArc { x: root.inX + root.inRadi; y: root.inY; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Counterclockwise }
                        PathLine { x: root.inX; y: root.inY }
                        PathLine { x: root.inX; y: root.inY + root.inH } 
                    }
                }

                Shape {
                    anchors.fill: parent; visible: root.isRightFlush
                    ShapePath {
                        fillColor: Config.bgPanel; strokeWidth: 0
                        startX: root.inX + root.inW; startY: root.inY + root.inH
                        
                        PathLine { x: root.pLeft - root.wingW; y: root.inY + root.inH } 
                        PathCubic { x: root.pLeft; y: root.inY + root.inH - root.wingW; control1X: root.pLeft; control1Y: root.inY + root.inH - root.wingW * 0.5; control2X: root.pLeft - root.wingW * 0.5; control2Y: root.inY + root.inH }
                        
                        PathLine { x: root.pLeft; y: root.bottomBarPopT + root.radius } 
                        PathArc { x: root.pLeft + root.radius; y: root.bottomBarPopT; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Clockwise } 
                        
                        PathLine { x: root.inX + root.inW - root.wingW; y: root.bottomBarPopT } 
                        PathCubic { x: root.inX + root.inW; y: root.bottomBarPopT - root.wingW; control1X: root.inX + root.inW - root.wingW * 0.5; control1Y: root.bottomBarPopT; control2X: root.inX + root.inW; control2Y: root.bottomBarPopT - root.wingW * 0.5 }
                        
                        PathLine { x: root.inX + root.inW; y: root.inY + root.inRadi }
                        PathArc { x: root.inX + root.inW - root.inRadi; y: root.inY; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inW; y: root.inY }
                        PathLine { x: root.inX + root.inW; y: root.inY + root.inH } 
                    }
                }

                Shape {
                    anchors.fill: parent; visible: !root.isLeftFlush && !root.isRightFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: root.borderWidth; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inRadi; startY: root.inY + root.halfB
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.halfB }
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.inY + root.inH - root.inRadi }
                        PathArc { x: root.inX + root.inW - root.inRadi; y: root.inY + root.inH - root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.pRight + root.wingW; y: root.inY + root.inH - root.halfB }
                        PathCubic { x: root.pRight; y: root.inY + root.inH - root.halfB - root.wingW; control1X: root.pRight + root.wingW * 0.5; control1Y: root.inY + root.inH - root.halfB; control2X: root.pRight; control2Y: root.inY + root.inH - root.halfB - root.wingW * 0.5 }
                        PathLine { x: root.pRight; y: root.bottomBarPopT + root.radius }
                        PathArc { x: root.pRight - root.radius; y: root.bottomBarPopT; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise }
                        PathLine { x: root.pLeft + root.radius; y: root.bottomBarPopT }
                        PathArc { x: root.pLeft; y: root.bottomBarPopT + root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise }
                        PathLine { x: root.pLeft; y: root.inY + root.inH - root.halfB - root.wingW }
                        PathCubic { x: root.pLeft - root.wingW; y: root.inY + root.inH - root.halfB; control1X: root.pLeft; control1Y: root.inY + root.inH - root.halfB - root.wingW * 0.5; control2X: root.pLeft - root.wingW * 0.5; control2Y: root.inY + root.inH }
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH - root.halfB }
                        PathArc { x: root.inX + root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi }
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                    }
                }

                Shape {
                    anchors.fill: parent; visible: root.isLeftFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: root.borderWidth; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inRadi; startY: root.inY + root.halfB
                        
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.halfB }
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.inY + root.inH - root.inRadi }
                        PathArc { x: root.inX + root.inW - root.inRadi; y: root.inY + root.inH - root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        
                        PathLine { x: root.pRight + root.wingW; y: root.inY + root.inH - root.halfB } 
                        PathCubic { x: root.pRight; y: root.inY + root.inH - root.halfB - root.wingW; control1X: root.pRight + root.wingW * 0.5; control1Y: root.inY + root.inH - root.halfB; control2X: root.pRight; control2Y: root.inY + root.inH - root.halfB - root.wingW * 0.5 }
                        
                        PathLine { x: root.pRight; y: root.bottomBarPopT + root.radius } 
                        PathArc { x: root.pRight - root.radius; y: root.bottomBarPopT; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise }
                        
                        PathLine { x: root.inX + root.halfB + root.wingW; y: root.bottomBarPopT }
                        PathCubic { x: root.inX + root.halfB; y: root.bottomBarPopT - root.wingH; control1X: root.inX + root.halfB + root.wingW * 0.5; control1Y: root.bottomBarPopT; control2X: root.inX + root.halfB; control2Y: root.bottomBarPopT - root.wingH * 0.5 }
                        
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi } 
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                    }
                }

                Shape {
                    anchors.fill: parent; visible: root.isRightFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: root.borderWidth; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inRadi; startY: root.inY + root.halfB
                        
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.halfB }
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.bottomBarPopT - root.wingW } 
                        PathCubic { x: root.inX + root.inW - root.halfB - root.wingW; y: root.bottomBarPopT; control1X: root.inX + root.inW - root.halfB; control1Y: root.bottomBarPopT - root.wingW * 0.5; control2X: root.inX + root.inW - root.halfB - root.wingW * 0.5; control2Y: root.bottomBarPopT }
                        
                        PathLine { x: root.pLeft + root.radius; y: root.bottomBarPopT } 
                        PathArc { x: root.pLeft; y: root.bottomBarPopT + root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise } 
                        
                        PathLine { x: root.pLeft; y: root.inY + root.inH - root.halfB - root.wingW } 
                        PathCubic { x: root.pLeft - root.wingW; y: root.inY + root.inH - root.halfB; control1X: root.pLeft; control1Y: root.inY + root.inH - root.halfB - root.wingW * 0.5; control2X: root.pLeft - root.wingW * 0.5; control2Y: root.inY + root.inH } 
                        
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH - root.halfB } 
                        PathArc { x: root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi } 
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                    }
                }
            }

            Item {
                id: barContent
                x: root.isRight ? (mainContainer.width - root.barH + Math.floor(root.halfB)) : Math.floor(root.halfB)
                y: root.isBottom ? (mainContainer.height - root.barH + Math.floor(root.halfB)) : Math.floor(root.halfB)
                
                transform: Translate {
                    x: root.isScreenFrame ? (root.barPosition === "left" ? root.framePadding / 2 : (root.barPosition === "right" ? -root.framePadding / 2 : 0)) : 0
                    y: root.isScreenFrame ? (root.barPosition === "top" ? root.framePadding / 2 : (root.barPosition === "bottom" ? -root.framePadding / 2 : 0)) : 0
                }

                width: root.isHorizontal ? (mainContainer.width - Math.ceil(root.borderWidth)) : (root.barH - Math.ceil(root.borderWidth))
                height: root.isHorizontal ? (root.barH - Math.ceil(root.borderWidth)) : (mainContainer.height - Math.ceil(root.borderWidth))

                LeftModules {
                    id: leftCard
                    rootRef: root
                    onPopoutRequested: item => root.setPopoutPos(item)
                }

                CenterModules {
                    id: centerGroupContainer
                    rootRef: root
                    leftCardRef: leftCard
                    rightCardRef: rightCard
                    barContentRef: barContent
                    onPopoutRequested: item => root.setPopoutPos(item)
                }

                RightModules {
                    id: rightCard
                    rootRef: root
                    onPopoutRequested: item => root.setPopoutPos(item)
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
                opacity: (root.isOpen && root.progress >= 0.95) ? 1.0 : 0.0
                focus: true

                Behavior on opacity {
                    NumberAnimation {
                        duration: (root.isOpen && root.progress >= 0.95) ? 200 : 80
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