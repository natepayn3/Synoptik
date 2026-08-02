import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root

    default property alias content: contentContainer.data

    property bool isOpen: false
    property real popoutXOffset: (screen ? screen.width : 1920) / 2.0
    property real popoutYOffset: (screen ? screen.height : 1080) / 2.0
    property bool isCentered: false

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
    readonly property real framePadding: isScreenFrame ? 6 : 0
    readonly property real frameRadius: isScreenFrame ? (Config.cornerRadius || 16) : 0

    readonly property real padL: barPosition === "left" ? barH + framePadding : framePadding
    readonly property real padR: barPosition === "right" ? barH + framePadding : framePadding
    readonly property real padT: barPosition === "top" ? barH + framePadding : framePadding
    readonly property real padB: barPosition === "bottom" ? barH + framePadding : framePadding

    readonly property real inX: padL
    readonly property real inY: padT
    readonly property real inW: (screen ? screen.width : 1920) - padL - padR
    readonly property real inH: (screen ? screen.height : 1080) - padT - padB
    readonly property real inRadi: Math.max(0.1, frameRadius)

    readonly property real outerPadding: 16
    readonly property real barSidePadding: 0 // Gap facing the bar

    readonly property real rawChildWidth: {
        let baseW = 420
        if (root.activeView === "osd") {
            baseW = volumeOsdModule.implicitWidth
        } else if (root.activeView === "notifOsd") {
            baseW = notifOsdModule.implicitWidth
        } else {
            for (let i = 0; i < contentContainer.children.length; i++) {
                let child = contentContainer.children[i]
                if (child.objectName !== "internalOsd" && child.objectName !== "internalNotifOsd") {
                    if (child.item && child.item.implicitWidth > 0) baseW = child.item.implicitWidth
                    else if (child.implicitWidth > 0) baseW = child.implicitWidth
                    break
                }
            }
        }
        return isHorizontal ? (baseW + (outerPadding * 2)) : (baseW + outerPadding + barSidePadding)
    }

    readonly property real rawChildHeight: {
        let baseH = 480
        if (root.activeView === "osd") {
            baseH = volumeOsdModule.implicitHeight
        } else if (root.activeView === "notifOsd") {
            baseH = notifOsdModule.implicitHeight
        } else {
            for (let i = 0; i < contentContainer.children.length; i++) {
                let child = contentContainer.children[i]
                if (child.objectName !== "internalOsd" && child.objectName !== "internalNotifOsd") {
                    if (child.item && child.item.implicitHeight > 0) baseH = child.item.implicitHeight
                    else if (child.implicitHeight > 0) baseH = child.implicitHeight
                    break
                }
            }
        }
        return isHorizontal ? (baseH + outerPadding + barSidePadding) : (baseH + (outerPadding * 2))
    }

    property real lastOpenWidth: rawChildWidth
    property real lastOpenHeight: rawChildHeight

    onIsOpenChanged: {
        if (!isOpen) {
            lastOpenWidth = rawChildWidth
            lastOpenHeight = rawChildHeight
        }
    }

    property real targetWidth: isOpen ? rawChildWidth : (isHorizontal ? (lastOpenWidth * 0.25) : (lastOpenWidth * 1.10))
    property real targetHeight: isOpen ? rawChildHeight : (isHorizontal ? (lastOpenHeight * 1.10) : (lastOpenHeight * 0.50))

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

    readonly property real wingW: 16 * animScale
    readonly property real wingH: 16 * animScale
    readonly property real radius: 18 * animScale

    readonly property real borderWidth: Config.showBorders ? 3 : 0
    readonly property real halfB: borderWidth / 2.0

    readonly property real leftBarRx: inX + wingW + currentWidth
    readonly property real rightBarPopL: inX + inW - wingW - currentWidth
    readonly property real topBarPopB: inY + wingH + currentHeight
    readonly property real bottomBarPopT: inY + inH - wingH - currentHeight

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

    readonly property real barH: Config.barHeight || 46
    readonly property real barBottomY: barH - halfB

    implicitHeight: (screen ? screen.height : 1080) + (shadowPadding * 2)
    implicitWidth: (screen ? screen.width : 1920) + (shadowPadding * 2)

    color: "transparent"
    visible: true

    mask: Region {
        Region { item: barContent }
        Region { item: (root.isOpen || root.progress > 0.01) ? contentContainer : null }
    }

    WlrLayershell.layer: WlrLayer.Top
    // Reserve bar height PLUS whatever outer margin/frame padding exists so windows keep their distance in all modes
    WlrLayershell.exclusiveZone: barH + (isScreenFrame ? (framePadding + (Config.barMargin || 4)) : (currentMargin > 0 ? currentMargin : (Config.barMargin || 4)))
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
        active: root.isOpen
        windows: [root]
        onCleared: {
            root.closeOthers("none")
            root.isCentered = false
        }
    }

    readonly property real minPossibleLeft: isScreenFrame ? ((isHorizontal ? inX : inY) + halfB) : halfB
    readonly property real maxPossibleRight: isScreenFrame ? ((isHorizontal ? inX + inW : inY + inH) - halfB) : ((isHorizontal ? mainContainer.width : mainContainer.height) - halfB)

    readonly property bool isLeftFlush: !isCentered && (
        (isHorizontal ? (popoutXOffset - (targetWidth / 2.0)) : (popoutYOffset - (targetHeight / 2.0))) < (minPossibleLeft + root.barRadius + root.wingW)
    )

    readonly property bool isRightFlush: !isCentered && (
        (isHorizontal ? (popoutXOffset + (targetWidth / 2.0)) : (popoutYOffset + (targetHeight / 2.0))) > (maxPossibleRight - root.barRadius - root.wingW)
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

    function updateActiveView() {
        let nextView = "none"

        if (typeof Config.showOSD !== "undefined" && Config.showOSD) nextView = "osd"
        else if (typeof Config.showNotificationOsd !== "undefined" && Config.showNotificationOsd) nextView = "notifOsd"
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

        if (nextView === "none") {
            root.isOpen = false
            activeView = "none"
        } else {
            activeView = nextView
            root.isOpen = true
        }
    }

    function setPopoutPos(item) {
        root.isCentered = false
        if (isHorizontal) {
            root.popoutXOffset = item.mapToItem(mainContainer, item.width / 2, 0).x
        } else {
            root.popoutYOffset = item.mapToItem(mainContainer, 0, item.height / 2).y
        }
    }

    function closeOthers(except) {
        if (except !== "osd" && typeof Config.showOSD !== "undefined") Config.showOSD = false
        if (except !== "notifOsd" && typeof Config.showNotificationOsd !== "undefined") Config.showNotificationOsd = false
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
        if (except !== "controlCenter") Config.showControlCenter = false
    }

    Connections {
        target: Config
        ignoreUnknownSignals: true
        function onShowOSDChanged() {
            if (Config.showOSD) {
                closeOthers("osd")
                root.isCentered = false
                if (root.isHorizontal) root.popoutXOffset = mainContainer.width
                else root.popoutYOffset = mainContainer.height
            }
            updateActiveView()
        }
        function onShowNotificationOsdChanged() {
            if (Config.showNotificationOsd) {
                closeOthers("notifOsd")
                root.isCentered = false
                root.popoutXOffset = 0
                root.popoutYOffset = 0
            }
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
        function onShowAppLauncherChanged() { if (Config.showAppLauncher) { closeOthers("appLauncher"); setPopoutPos(btnLauncher); } updateActiveView() }
        function onShowPowerChanged() { if (Config.showPower) { closeOthers("power"); setPopoutPos(btnPower); } updateActiveView() }
        function onShowWallpaperChanged() { if (Config.showWallpaper) { closeOthers("wallpaper"); setPopoutPos(btnWallpaper); } updateActiveView() }
        function onShowCalendarChanged() { if (Config.showCalendar) { closeOthers("calendar"); setPopoutPos(btnClock); } updateActiveView() }
        function onShowNotificationsChanged() { if (Config.showNotifications) { closeOthers("notifications"); setPopoutPos(btnNotifications); } updateActiveView() }
        function onShowAudioChanged() { if (Config.showAudio) { closeOthers("audio"); setPopoutPos(btnAudio); } updateActiveView() }
        function onShowNetworkChanged() { if (Config.showNetwork) { closeOthers("network"); setPopoutPos(btnNetwork); } updateActiveView() }
        function onShowSystemMonitorChanged() { if (Config.showSystemMonitor) { closeOthers("systemMonitor"); setPopoutPos(btnSys); } updateActiveView() }
        function onShowBatteryChanged() { if (Config.showBattery) { closeOthers("battery"); setPopoutPos(btnBatt); } updateActiveView() }
        function onShowClipboardChanged() { if (Config.showClipboard) { closeOthers("clipboard"); setPopoutPos(btnClipboard); } updateActiveView() }
        function onShowScreenRecorderChanged() { if (Config.showScreenRecorder) { closeOthers("screenRecorder"); setPopoutPos(btnRecorder); } updateActiveView() }
        function onShowControlCenterChanged() { if (Config.showControlCenter) { closeOthers("controlCenter"); setPopoutPos(btnCC); } updateActiveView() }
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

            // =========================================================
            // 1. FLOATING / EDGE BAR SHAPES
            // =========================================================

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
                    PathLine { x: root.barH - root.halfB + root.wingW + root.currentWidth - root.radius; y: root.pLeft }
                    PathArc { x: root.barH - root.halfB + root.wingW + root.currentWidth; y: root.pLeft + root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
                    PathLine { x: root.barH - root.halfB + root.wingW + root.currentWidth; y: root.pRight - root.radius }
                    PathArc { x: root.barH - root.halfB + root.wingW + root.currentWidth - root.radius; y: root.pRight; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
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
                    PathLine { x: mainContainer.width - root.halfB; y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : (root.barBottomY - root.barRadius) }
                    PathArc { x: root.isRightFlush ? (mainContainer.width - root.halfB) : (mainContainer.width - root.halfB - root.barRadius); y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : root.barBottomY; radiusX: root.isRightFlush ? 0 : root.barRadius; radiusY: root.isRightFlush ? 0 : root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.isRightFlush ? (mainContainer.width - root.halfB) : (root.pRight + root.wingW); y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : root.barBottomY }
                    PathCubic { x: root.isRightFlush ? (mainContainer.width - root.halfB) : root.pRight; y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : (root.barBottomY + root.wingH); control1X: root.isRightFlush ? (mainContainer.width - root.halfB) : (root.pRight + (root.wingW * 0.5)); control1Y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : root.barBottomY; control2X: root.isRightFlush ? (mainContainer.width - root.halfB) : root.pRight; control2Y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : (root.barBottomY + (root.wingH * 0.5)) }
                    PathLine { x: root.isRightFlush ? (mainContainer.width - root.halfB) : root.pRight; y: root.barBottomY + root.wingH + root.currentHeight - root.radius }
                    PathArc { x: root.isRightFlush ? (mainContainer.width - root.halfB - root.radius) : (root.pRight - root.radius); y: root.barBottomY + root.wingH + root.currentHeight; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
                    PathLine { x: root.isLeftFlush ? (root.halfB + root.radius) : (root.pLeft + root.radius); y: root.barBottomY + root.wingH + root.currentHeight }
                    PathArc { x: root.isLeftFlush ? root.halfB : root.pLeft; y: root.barBottomY + root.wingH + root.currentHeight - root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
                    PathLine { x: root.isLeftFlush ? root.halfB : root.pLeft; y: root.isLeftFlush ? (root.halfB + root.barRadius) : (root.barBottomY + root.wingH) }
                    PathCubic { x: root.isLeftFlush ? root.halfB : (root.pLeft - root.wingW); y: root.isLeftFlush ? (root.halfB + root.barRadius) : root.barBottomY; control1X: root.isLeftFlush ? root.halfB : root.pLeft; control1Y: root.isLeftFlush ? (root.halfB + root.barRadius) : (root.barBottomY + (root.wingH * 0.5)); control2X: root.isLeftFlush ? root.halfB : (root.pLeft - (root.wingW * 0.5)); control2Y: root.isLeftFlush ? root.barBottomY : root.barBottomY }
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
                    PathLine { x: root.pLeft; y: openShapeBottomFloating.barTopY - root.wingH - root.currentHeight + root.radius }
                    PathArc { x: root.pLeft + root.radius; y: openShapeBottomFloating.barTopY - root.wingH - root.currentHeight; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
                    PathLine { x: root.pRight - root.radius; y: openShapeBottomFloating.barTopY - root.wingH - root.currentHeight }
                    PathArc { x: root.pRight; y: openShapeBottomFloating.barTopY - root.wingH - root.currentHeight + root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
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

                    startX: openShapeRightFloating.rX + root.halfB
                    startY: root.isLeftFlush ? root.halfB : (root.halfB + root.barRadius)
                    PathLine { x: mainContainer.width - root.halfB - root.barRadius; y: root.halfB }
                    PathArc { x: mainContainer.width - root.halfB; y: root.halfB + root.barRadius; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: mainContainer.width - root.halfB; y: mainContainer.height - root.halfB - root.barRadius }
                    PathArc { x: mainContainer.width - root.halfB - root.barRadius; y: mainContainer.height - root.halfB; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: openShapeRightFloating.rX + root.halfB + root.barRadius; y: mainContainer.height - root.halfB }
                    PathArc { x: openShapeRightFloating.rX + root.halfB; y: mainContainer.height - root.halfB - (root.isRightFlush ? 0 : root.barRadius); radiusX: root.isRightFlush ? 0 : root.barRadius; radiusY: root.isRightFlush ? 0 : root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: openShapeRightFloating.rX + root.halfB; y: root.isRightFlush ? (mainContainer.height - root.halfB) : (root.pRight + root.wingW) }
                    PathCubic { x: root.isRightFlush ? (openShapeRightFloating.rX + root.halfB) : (openShapeRightFloating.rX + root.halfB - root.wingW); y: root.pRight; control1X: openShapeRightFloating.rX + root.halfB; control1Y: root.isRightFlush ? (mainContainer.height - root.halfB) : (root.pRight + (root.wingW * 0.5)); control2X: root.isRightFlush ? (openShapeRightFloating.rX + root.halfB) : (openShapeRightFloating.rX + root.halfB - (root.wingW * 0.5)); control2Y: root.pRight }
                    PathLine { x: openShapeRightFloating.rX + root.halfB - root.wingW - root.currentWidth + root.radius; y: root.pRight }
                    PathArc { x: openShapeRightFloating.rX + root.halfB - root.wingW - root.currentWidth; y: root.pRight - root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
                    PathLine { x: openShapeRightFloating.rX + root.halfB - root.wingW - root.currentWidth; y: root.pLeft + root.radius }
                    PathArc { x: openShapeRightFloating.rX + root.halfB - root.wingW - root.currentWidth + root.radius; y: root.pLeft; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }
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


            // =========================================================
            // 2. SCREEN FRAME MODE (Solid Rect Edge Strips + Isolated Paths)
            // =========================================================

            Item {
                id: sfClosedGroup
                anchors.fill: parent
                visible: root.progress === 0 && root.isScreenFrame

                Rectangle { x: 0; y: 0; width: mainContainer.width; height: root.inY; color: Config.bgPanel }
                Rectangle { x: 0; y: root.inY + root.inH; width: mainContainer.width; height: mainContainer.height - (root.inY + root.inH); color: Config.bgPanel }
                Rectangle { x: 0; y: root.inY; width: root.inX; height: root.inH; color: Config.bgPanel }
                Rectangle { x: root.inX + root.inW; y: root.inY; width: mainContainer.width - (root.inX + root.inW); height: root.inH; color: Config.bgPanel }

                Loader {
                    anchors.fill: parent
                    sourceComponent: screenFrameCorners
                }

                Shape {
                    anchors.fill: parent
                    ShapePath {
                        fillColor: "transparent"
                        strokeWidth: Config.showBorders ? root.borderWidth : 0
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

            // ---------------------------------------------------------
            // LEFT BAR OPEN SHAPES
            // ---------------------------------------------------------
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
                        fillColor: "transparent"; strokeWidth: Config.showBorders ? root.borderWidth : 0; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
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
                        fillColor: "transparent"; strokeWidth: Config.showBorders ? root.borderWidth : 0; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
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
                        fillColor: "transparent"; strokeWidth: Config.showBorders ? root.borderWidth : 0; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
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

            // ---------------------------------------------------------
            // RIGHT BAR OPEN SHAPES
            // ---------------------------------------------------------
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
                        PathArc { x: root.rightBarPopL; y: root.pLeft + root.radius; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Counterclockwise } 
                        
                        // Restored inner wing smoothly connecting left edge of popout to bottom screen edge
                        PathLine { x: root.rightBarPopL; y: root.inY + root.inH - root.wingW } 
                        PathCubic { x: root.rightBarPopL - root.wingW; y: root.inY + root.inH; control1X: root.rightBarPopL; control1Y: root.inY + root.inH - root.wingW * 0.5; control2X: root.rightBarPopL - root.wingW * 0.5; control2Y: root.inY + root.inH } 
                        
                        PathLine { x: root.inX + root.inW; y: root.inY + root.inH } 
                    }
                }

                Shape {
                    anchors.fill: parent; visible: !root.isLeftFlush && !root.isRightFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: Config.showBorders ? root.borderWidth : 0; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
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
                        fillColor: "transparent"; strokeWidth: Config.showBorders ? root.borderWidth : 0; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inRadi; startY: root.inY + root.halfB
                        PathLine { x: root.rightBarPopL - root.wingW; y: root.inY + root.halfB }
                        PathCubic { x: root.rightBarPopL; y: root.inY + root.halfB + root.wingW; control1X: root.rightBarPopL - root.wingW * 0.5; control1Y: root.inY + root.halfB; control2X: root.rightBarPopL; control2Y: root.inY + root.halfB + root.wingW * 0.5 }
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
                    anchors.fill: parent; visible: root.isRightFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: Config.showBorders ? root.borderWidth : 0; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inRadi; startY: root.inY + root.halfB
                        
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.halfB }
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.pLeft - root.wingW } 
                        PathCubic { x: root.inX + root.inW - root.halfB - root.wingW; y: root.pLeft; control1X: root.inX + root.inW - root.halfB; control1Y: root.pLeft - root.wingW * 0.5; control2X: root.inX + root.inW - root.halfB - root.wingW * 0.5; control2Y: root.pLeft }
                        
                        PathLine { x: root.rightBarPopL + root.radius; y: root.pLeft } 
                        PathArc { x: root.rightBarPopL; y: root.pLeft + root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise } 
                        
                        // Restored inner wing smoothly connecting left edge of popout to bottom screen border
                        PathLine { x: root.rightBarPopL; y: root.inY + root.inH - root.halfB - root.wingW } 
                        PathCubic { x: root.rightBarPopL - root.wingW; y: root.inY + root.inH - root.halfB; control1X: root.rightBarPopL; control1Y: root.inY + root.inH - root.halfB - root.wingW * 0.5; control2X: root.rightBarPopL - root.wingW * 0.5; control2Y: root.inY + root.inH - root.halfB } 
                        
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH - root.halfB } 
                        PathArc { x: root.inX + root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi } 
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                    }
                }
            }

            // ---------------------------------------------------------
            // TOP BAR OPEN SHAPES
            // ---------------------------------------------------------
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
                        fillColor: "transparent"; strokeWidth: Config.showBorders ? root.borderWidth : 0; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
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
                        fillColor: "transparent"; strokeWidth: Config.showBorders ? root.borderWidth : 0; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
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
                        fillColor: "transparent"; strokeWidth: Config.showBorders ? root.borderWidth : 0; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
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
                        PathArc { x: root.inX + root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi }
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                    }
                }
            }

            // ---------------------------------------------------------
            // BOTTOM BAR OPEN SHAPES
            // ---------------------------------------------------------
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

                // FIXED: Left Flush Fill - Extends up to the top-left screen frame boundary and sweeps around the outer radius
                Shape {
                    anchors.fill: parent; visible: root.isLeftFlush
                    ShapePath {
                        fillColor: Config.bgPanel; strokeWidth: 0
                        startX: root.inX; startY: root.inY + root.inH
                        
                        PathLine { x: root.pRight + root.wingW; y: root.inY + root.inH } 
                        PathCubic { x: root.pRight; y: root.inY + root.inH - root.wingW; control1X: root.pRight + root.wingW * 0.5; control1Y: root.inY + root.inH; control2X: root.pRight; control2Y: root.inY + root.inH - root.wingW * 0.5 }
                        
                        PathLine { x: root.pRight; y: root.bottomBarPopT + root.radius } 
                        PathArc { x: root.pRight - root.radius; y: root.bottomBarPopT; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Counterclockwise } 
                        
                        // Outer top-left corner connection
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
                        startX: root.pLeft - root.wingW; startY: root.inY + root.inH
                        
                        PathLine { x: root.inX + root.inW; y: root.inY + root.inH } 
                        PathLine { x: root.inX + root.inW; y: root.bottomBarPopT + root.radius } 
                        
                        PathArc { x: root.inX + root.inW - root.radius; y: root.bottomBarPopT; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Counterclockwise }
                        PathLine { x: root.pLeft + root.radius; y: root.bottomBarPopT } 
                        
                        PathArc { x: root.pLeft; y: root.bottomBarPopT + root.radius; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Counterclockwise } 
                        PathLine { x: root.pLeft; y: root.inY + root.inH - root.wingW } 
                        PathCubic { x: root.pLeft - root.wingW; y: root.inY + root.inH; control1X: root.pLeft; control1Y: root.inY + root.inH - root.wingW * 0.5; control2X: root.pLeft - root.wingW * 0.5; control2Y: root.inY + root.inH }
                    }
                }

                Shape {
                    anchors.fill: parent; visible: !root.isLeftFlush && !root.isRightFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: Config.showBorders ? root.borderWidth : 0; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
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
                        PathCubic { x: root.pLeft - root.wingW; y: root.inY + root.inH - root.halfB; control1X: root.pLeft; control1Y: root.inY + root.inH - root.halfB - root.wingW * 0.5; control2X: root.pLeft - root.wingW * 0.5; control2Y: root.inY + root.inH - root.halfB }
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH - root.halfB }
                        PathArc { x: root.inX + root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi }
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                    }
                }

                // FIXED: Left Flush Border - Smoothly transitions the stroke from popout top edge, through wing, up along left frame edge
                Shape {
                    anchors.fill: parent; visible: root.isLeftFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: Config.showBorders ? root.borderWidth : 0; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inW - root.inRadi; startY: root.inY + root.halfB
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.inY + root.inH - root.inRadi }
                        PathArc { x: root.inX + root.inW - root.inRadi; y: root.inY + root.inH - root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        
                        PathLine { x: root.pRight + root.wingW; y: root.inY + root.inH - root.halfB } 
                        PathCubic { x: root.pRight; y: root.inY + root.inH - root.halfB - root.wingW; control1X: root.pRight + root.wingW * 0.5; control1Y: root.inY + root.inH - root.halfB; control2X: root.pRight; control2Y: root.inY + root.inH - root.halfB - root.wingW * 0.5 }
                        
                        PathLine { x: root.pRight; y: root.bottomBarPopT + root.radius } 
                        PathArc { x: root.pRight - root.radius; y: root.bottomBarPopT; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise }
                        
                        // Wing curve from popout top edge into left screen frame border
                        PathLine { x: root.inX + root.halfB + root.wingW; y: root.bottomBarPopT }
                        PathCubic { x: root.inX + root.halfB; y: root.bottomBarPopT - root.wingH; control1X: root.inX + root.halfB + root.wingW * 0.5; control1Y: root.bottomBarPopT; control2X: root.inX + root.halfB; control2Y: root.bottomBarPopT - root.wingH * 0.5 }
                        
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi } 
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                    }
                }

                Shape {
                    anchors.fill: parent; visible: root.isRightFlush
                    ShapePath {
                        fillColor: "transparent"; strokeWidth: Config.showBorders ? root.borderWidth : 0; strokeColor: shellRoot.currentBorderColor; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                        startX: root.inX + root.inRadi; startY: root.inY + root.halfB
                        
                        PathLine { x: root.inX + root.inW - root.inRadi; y: root.inY + root.halfB }
                        PathArc { x: root.inX + root.inW - root.halfB; y: root.inY + root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        
                        PathLine { x: root.inX + root.inW - root.halfB; y: root.bottomBarPopT - root.wingW } 
                        PathCubic { x: root.inX + root.inW - root.halfB - root.wingW; y: root.bottomBarPopT; control1X: root.inX + root.inW - root.halfB; control1Y: root.bottomBarPopT - root.wingW * 0.5; control2X: root.inX + root.inW - root.halfB - root.wingW * 0.5; control2Y: root.bottomBarPopT }
                        
                        PathLine { x: root.pLeft + root.radius; y: root.bottomBarPopT } 
                        PathArc { x: root.pLeft; y: root.bottomBarPopT + root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Counterclockwise } 
                        
                        PathLine { x: root.pLeft; y: root.inY + root.inH - root.halfB - root.wingW } 
                        PathCubic { x: root.pLeft - root.wingW; y: root.inY + root.inH - root.halfB; control1X: root.pLeft; control1Y: root.inY + root.inH - root.halfB - root.wingW * 0.5; control2X: root.pLeft - root.wingW * 0.5; control2Y: root.inY + root.inH - root.halfB } 
                        
                        PathLine { x: root.inX + root.inRadi; y: root.inY + root.inH - root.halfB } 
                        PathArc { x: root.inX + root.halfB; y: root.inY + root.inH - root.inRadi; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                        PathLine { x: root.inX + root.halfB; y: root.inY + root.inRadi } 
                        PathArc { x: root.inX + root.inRadi; y: root.inY + root.halfB; radiusX: root.inRadi; radiusY: root.inRadi; direction: PathArc.Clockwise }
                    }
                }
            }
        }

        // BAR CONTROLS
        Item {
            id: barContent
            x: root.isRight ? (mainContainer.width - root.barH + Math.floor(root.halfB)) : Math.floor(root.halfB)
            y: root.isBottom ? (mainContainer.height - root.barH + Math.floor(root.halfB)) : Math.floor(root.halfB)
            
            width: root.isHorizontal ? (mainContainer.width - Math.ceil(root.borderWidth)) : (root.barH - Math.ceil(root.borderWidth))
            height: root.isHorizontal ? (root.barH - Math.ceil(root.borderWidth)) : (mainContainer.height - Math.ceil(root.borderWidth))

            GridLayout {
                id: leftModules
                
                anchors.leftMargin: root.isHorizontal ? 10 : 0
                anchors.topMargin: !root.isHorizontal ? 10 : 0
                columns: root.isHorizontal ? 99 : 1
                rows: root.isHorizontal ? 1 : 99
                columnSpacing: 8
                rowSpacing: 8

                states: [
                    State {
                        name: "horizontal"
                        when: root.isHorizontal
                        AnchorChanges {
                            target: leftModules
                            anchors.left: leftModules.parent.left
                            anchors.verticalCenter: leftModules.parent.verticalCenter
                            anchors.top: undefined
                            anchors.horizontalCenter: undefined
                        }
                    },
                    State {
                        name: "vertical"
                        when: !root.isHorizontal
                        AnchorChanges {
                            target: leftModules
                            anchors.top: leftModules.parent.top
                            anchors.horizontalCenter: leftModules.parent.horizontalCenter
                            anchors.left: undefined
                            anchors.verticalCenter: undefined
                        }
                    }
                ]

                Rectangle {
                    id: btnPower
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    color: (Config.showPower || powerHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "electrical_services" 
                        color: Config.showPower ? Config.accent : Config.textMain
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                    }

                    TapHandler { onTapped: { setPopoutPos(btnPower); Config.showPower = !Config.showPower; } }
                    HoverHandler { id: powerHover; cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    id: btnRecorder
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    color: (Config.showScreenRecorder || recordHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: (typeof shellRoot !== "undefined" && shellRoot.isRecording) ? "radio_button_checked" : "videocam"
                        color: (typeof shellRoot !== "undefined" && shellRoot.isRecording) ? "#ef4444" : (Config.showScreenRecorder ? Config.accent : Config.textMain)
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    TapHandler { onTapped: { setPopoutPos(btnRecorder); Config.showScreenRecorder = !Config.showScreenRecorder; } }
                    HoverHandler { id: recordHover; cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    color: screenshotHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "crop"
                        color: Config.textMain
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                    }

                    TapHandler { onTapped: Quickshell.execDetached(["fish", "-c", "sleep 0.1; and grim -g (slurp) -t ppm - | satty --filename -"]) }
                    HoverHandler { id: screenshotHover; cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    id: btnClipboard
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    color: (Config.showClipboard || clipHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "content_paste"
                        color: Config.showClipboard ? Config.accent : Config.textMain
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                    }

                    TapHandler { onTapped: { setPopoutPos(btnClipboard); Config.showClipboard = !Config.showClipboard; } }
                    HoverHandler { id: clipHover; cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    id: btnWallpaper
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    color: (Config.showWallpaper || wallpaperHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "wall_art" 
                        color: Config.showWallpaper ? Config.accent : Config.textMain
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                    }

                    TapHandler { onTapped: { setPopoutPos(btnWallpaper); Config.showWallpaper = !Config.showWallpaper; } }
                    HoverHandler { id: wallpaperHover; cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    id: btnSettings
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    color: (Config.showSettings || settingsHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "build" 
                        color: Config.showSettings ? Config.accent : Config.textMain
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                    }

                    TapHandler { onTapped: { setPopoutPos(btnSettings); Config.showSettings = !Config.showSettings; } }
                    HoverHandler { id: settingsHover; cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    id: btnLauncher
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    color: (Config.showAppLauncher || launcherHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "terminal_2" 
                        color: Config.showAppLauncher ? Config.accent : Config.textMain
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                    }

                    TapHandler { onTapped: { setPopoutPos(btnLauncher); Config.showAppLauncher = !Config.showAppLauncher; } }
                    HoverHandler { id: launcherHover; cursorShape: Qt.PointingHandCursor }
                }
            }

            Rectangle {
                id: centerGroupContainer
                anchors.centerIn: parent
                
                readonly property real availableW: Math.max(32, barContent.width - leftModules.width - rightModules.width - 48)
                readonly property real availableH: Math.max(32, barContent.height - leftModules.height - rightModules.height - 48)

                width: root.isHorizontal 
                    ? Math.min(centerContentLayout.implicitWidth + 16, availableW) 
                    : 28

                height: root.isHorizontal 
                    ? 28 
                    : Math.min(centerContentLayout.implicitHeight + 16, availableH)
                
                clip: true
                radius: Config.cornerRadius / 2
                color: Qt.rgba(255, 255, 255, 0.05)

                Loader {
                    id: centerContentLayout
                    anchors.fill: parent
                    anchors.leftMargin: root.isHorizontal ? 8 : 2
                    anchors.rightMargin: root.isHorizontal ? 8 : 2
                    anchors.topMargin: !root.isHorizontal ? 8 : 2
                    anchors.bottomMargin: !root.isHorizontal ? 8 : 2

                    sourceComponent: root.isHorizontal ? horizCenterComp : vertCenterComp
                }

                Component {
                    id: horizCenterComp
                    RowLayout {
                        spacing: 8
                        anchors.fill: parent

                        WorkspaceIndicators {
                            isVertical: false
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignVCenter
                            
                            implicitWidth: horizTaskbarLoader.item ? horizTaskbarLoader.item.implicitWidth : 32

                            Timer {
                                interval: 350
                                running: true
                                repeat: false
                                onTriggered: horizTaskbarLoader.active = true
                            }

                            Loader {
                                id: horizTaskbarLoader
                                active: false
                                anchors.fill: parent

                                sourceComponent: Taskbar {
                                    isVertical: false
                                    activeScreenName: root.screen ? root.screen.name : ""
                                }
                            }
                        }
                    }
                }

                Component {
                    id: vertCenterComp
                    ColumnLayout {
                        spacing: 8
                        anchors.fill: parent

                        WorkspaceIndicators {
                            isVertical: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignHCenter

                            implicitHeight: vertTaskbarLoader.item ? vertTaskbarLoader.item.implicitHeight : 32

                            Timer {
                                interval: 350
                                running: true
                                repeat: false
                                onTriggered: vertTaskbarLoader.active = true
                            }

                            Loader {
                                id: vertTaskbarLoader
                                active: false
                                anchors.fill: parent

                                sourceComponent: Taskbar {
                                    isVertical: true
                                    activeScreenName: root.screen ? root.screen.name : ""
                                }
                            }
                        }
                    }
                }
            }

            GridLayout {
                id: rightModules
                
                anchors.rightMargin: root.isHorizontal ? 10 : 0
                anchors.bottomMargin: !root.isHorizontal ? 10 : 0
                anchors.topMargin: 0
                columns: root.isHorizontal ? 99 : 1
                rows: root.isHorizontal ? 1 : 99
                columnSpacing: 8
                rowSpacing: 8

                states: [
                    State {
                        name: "horizontal"
                        when: root.isHorizontal
                        AnchorChanges {
                            target: rightModules
                            anchors.right: rightModules.parent.right
                            anchors.verticalCenter: rightModules.parent.verticalCenter
                            anchors.bottom: undefined
                            anchors.horizontalCenter: undefined
                        }
                    },
                    State {
                        name: "vertical"
                        when: !root.isHorizontal
                        AnchorChanges {
                            target: rightModules
                            anchors.right: undefined
                            anchors.verticalCenter: undefined
                            anchors.bottom: rightModules.parent.bottom
                            anchors.horizontalCenter: rightModules.parent.horizontalCenter
                        }
                    }
                ]

                Rectangle {
                    id: btnAudio
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    color: (Config.showAudio || audioHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: shellRoot.audioMuted ? "hearing_disabled" : (shellRoot.audioVolume === 0 ? "hearing_disabled" : (shellRoot.audioVolume < 50 ? "hearing" : "ear_sound"))
                        color: Config.showAudio ? Config.accent : (shellRoot.audioMuted ? Config.textMuted : Config.textMain)
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                    }

                    TapHandler { onTapped: { setPopoutPos(btnAudio); Config.showAudio = !Config.showAudio; } }
                    HoverHandler { id: audioHover; cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    id: btnSys
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    color: (Config.showSystemMonitor || sysHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "neurology"
                        color: Config.showSystemMonitor ? Config.accent : Config.textMain
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                    }

                    TapHandler { onTapped: { setPopoutPos(btnSys); Config.showSystemMonitor = !Config.showSystemMonitor; } }
                    HoverHandler { id: sysHover; cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    id: btnBatt
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    visible: shellRoot.hasBattery
                    color: (Config.showBattery || battHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (shellRoot.battStatus === "Charging") return "battery_android_frame_bolt"
                            if (shellRoot.battCapacity <= 10) return "battery_android_frame_alert"
                            if (shellRoot.battCapacity <= 25) return "battery_android_frame_1"
                            if (shellRoot.battCapacity <= 40) return "battery_android_frame_2"
                            if (shellRoot.battCapacity <= 55) return "battery_android_frame_3"
                            if (shellRoot.battCapacity <= 70) return "battery_android_frame_4"
                            if (shellRoot.battCapacity <= 85) return "battery_android_frame_5"
                            if (shellRoot.battCapacity < 100) return "battery_android_frame_6"
                            return "battery_android_frame_full"
                        }
                        color: Config.showBattery ? Config.accent : (shellRoot.battCapacity <= 15 ? "#ef4444" : Config.textMain)
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                    }

                    TapHandler { onTapped: { setPopoutPos(btnBatt); Config.showBattery = !Config.showBattery; } }
                    HoverHandler { id: battHover; cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    id: btnCC
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    color: (Config.showControlCenter || ccHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "widgets"
                        color: Config.showControlCenter ? Config.accent : Config.textMain
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                    }

                    TapHandler { onTapped: { setPopoutPos(btnCC); Config.showControlCenter = !Config.showControlCenter; } }
                    HoverHandler { id: ccHover; cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    id: btnNetwork
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    color: (Config.showNetwork || networkHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: shellRoot.vpnActive ? "vpn_key" : "lan"
                        color: Config.showNetwork ? Config.accent : Config.textMain
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                    }

                    TapHandler { onTapped: { setPopoutPos(btnNetwork); Config.showNetwork = !Config.showNetwork; } }
                    HoverHandler { id: networkHover; cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    id: btnNotifications
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    color: (Config.showNotifications || notificationsHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: (typeof shellRoot !== "undefined" && shellRoot.activeNotifs > 0) ? "inbox_text" : "inbox"
                        color: (Config.showNotifications || (typeof shellRoot !== "undefined" && shellRoot.activeNotifs > 0)) ? Config.accent : Config.textMain
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    TapHandler { onTapped: { setPopoutPos(btnNotifications); Config.showNotifications = !Config.showNotifications; } }
                    HoverHandler { id: notificationsHover; cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    id: btnClock
                    implicitWidth: isHorizontal ? dateRow.implicitWidth + 20 : 32
                    implicitHeight: isHorizontal ? 32 : dateColumn.implicitHeight + 12
                    radius: 10
                    color: (Config.showCalendar || clockHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: dateRow
                        visible: root.isHorizontal
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: (shellRoot.vertHour || (new Date().getHours() % 12 || 12).toString()) + ":" + (shellRoot.vertMinute || Qt.formatTime(new Date(), "mm"))
                            color: Config.showCalendar ? Config.accent : Config.textMain
                            font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: Config.size(Config.fontTitle)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: shellRoot.vertAmPm || Qt.formatTime(new Date(), "ap").toLowerCase()
                            color: Config.accent
                            font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: Config.size(Config.fontSubhead)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: (shellRoot.vertMonth || Qt.formatDate(new Date(), "MMM")) + " " + (shellRoot.vertDay || Qt.formatDate(new Date(), "d"))
                            color: Config.showCalendar ? Config.accent : Config.textMuted
                            font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: Config.size(Config.fontSubhead)
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    ColumnLayout {
                        id: dateColumn
                        visible: !root.isHorizontal
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            text: shellRoot.vertHour || (new Date().getHours() % 12 || 12).toString()
                            color: Config.showCalendar ? Config.accent : Config.textMain
                            font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: 15
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: shellRoot.vertMinute || Qt.formatTime(new Date(), "mm")
                            color: Config.showCalendar ? Config.accent : Config.textMain
                            font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: 15
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: shellRoot.vertAmPm || Qt.formatTime(new Date(), "ap").toLowerCase()
                            color: Config.accent
                            font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: 12
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: shellRoot.vertMonth || Qt.formatDate(new Date(), "MMM")
                            color: Config.showCalendar ? Config.accent : Config.textMuted
                            font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: 12
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: shellRoot.vertDay || Qt.formatDate(new Date(), "d")
                            color: Config.showCalendar ? Config.accent : Config.textMuted
                            font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: 12
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    TapHandler { onTapped: { setPopoutPos(btnClock); Config.showCalendar = !Config.showCalendar; } }
                    HoverHandler { id: clockHover; cursorShape: Qt.PointingHandCursor }
                }
            }
        }

        Item {
            id: contentContainer
            
            readonly property real outerPadding: root.outerPadding
            readonly property real barSidePadding: root.barSidePadding

            x: {
                if (isHorizontal) {
                    return root.pLeft + outerPadding
                } else {
                    if (isRight) {
                        return isScreenFrame 
                            ? (root.rightBarPopL + outerPadding) 
                            : (mainContainer.width - root.barH - root.wingW - root.currentWidth + outerPadding)
                    } else {
                        return isScreenFrame 
                            ? (root.inX + root.wingW + barSidePadding) 
                            : (root.barH + root.wingW + barSidePadding)
                    }
                }
            }

            y: {
                if (isHorizontal) {
                    if (isBottom) {
                        return isScreenFrame 
                            ? (root.bottomBarPopT + outerPadding) 
                            : (mainContainer.height - root.barH - root.wingH - root.currentHeight + outerPadding)
                    } else {
                        return isScreenFrame 
                            ? (root.topBarPopB - root.currentHeight + barSidePadding) 
                            : (root.barH + root.wingH + barSidePadding)
                    }
                } else {
                    return root.pLeft + outerPadding
                }
            }

            width: isHorizontal 
                ? Math.max(1, root.currentWidth - (outerPadding * 2)) 
                : Math.max(1, root.currentWidth - outerPadding - barSidePadding)

            height: isHorizontal 
                ? Math.max(1, root.currentHeight - outerPadding - barSidePadding) 
                : Math.max(1, root.currentHeight - (outerPadding * 2))
            
            clip: true
            visible: root.progress >= 0.98
            focus: true

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
        }
    }
}