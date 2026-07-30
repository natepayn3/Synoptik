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

    // Reserved outer space so MultiEffect shadows bleed cleanly around screen borders
    readonly property real shadowPadding: 16

    // Configured Bar Edge Position: "top" | "bottom" | "left" | "right"
    readonly property string barPosition: Config.barPosition || "top"
    readonly property bool isHorizontal: barPosition === "top" || barPosition === "bottom"
    readonly property bool isBottom: barPosition === "bottom"
    readonly property bool isRight: barPosition === "right"

    // Corner radius for main bar shell
    readonly property real barRadius: Config.cornerRadius || 12

    // 1. Raw Child Bounds
    readonly property real rawChildWidth: {
        let baseW = 420
        if (contentContainer.children.length > 0) {
            let child = contentContainer.children[0]
            if (child.item && child.item.implicitWidth > 0) baseW = child.item.implicitWidth
            else if (child.implicitWidth > 0) baseW = child.implicitWidth
        }
        return baseW + 24
    }

    readonly property real rawChildHeight: {
        let baseH = 480
        if (contentContainer.children.length > 0) {
            let child = contentContainer.children[0]
            if (child.item && child.item.implicitHeight > 0) baseH = child.item.implicitHeight
            else if (child.implicitHeight > 0) baseH = child.implicitHeight
        }
        return isHorizontal ? baseH : (baseH + 24)
    }

    // Capture active dimensions at unmap trigger to prevent evaluation loops on close
    property real lastOpenWidth: rawChildWidth
    property real lastOpenHeight: rawChildHeight

    onIsOpenChanged: {
        if (!isOpen) {
            lastOpenWidth = rawChildWidth
            lastOpenHeight = rawChildHeight
        }
    }

    property real targetWidth: isOpen ? rawChildWidth : (isHorizontal ? (lastOpenWidth * 0.50) : (lastOpenWidth * 1.10))
    property real targetHeight: isOpen ? rawChildHeight : (isHorizontal ? (lastOpenHeight * 1.10) : (lastOpenHeight * 0.50))

    // Dynamic Morphing Behaviors
    Behavior on targetWidth {
        NumberAnimation { 
            duration: 350; 
            easing.type: Easing.OutBack; 
            easing.overshoot: 0.8
        }
    }

    Behavior on targetHeight {
        NumberAnimation { 
            duration: 350; 
            easing.type: Easing.OutBack; 
            easing.overshoot: 0.8
        }
    }

    property real progress: 0.0
    readonly property real animScale: Math.max(0.0, progress)

    // Smooth closing progress curve
    readonly property real closeFactor: root.isOpen ? progress : Math.pow(progress, 1.2)

    // Pure squish logic mapping
    readonly property real currentHeight: targetHeight * Math.pow(closeFactor, 1.8)
    readonly property real squishRatio: targetHeight > 0 ? (1.0 - (currentHeight / targetHeight)) : 0.0
    readonly property real currentWidth: root.isOpen ? (targetWidth * animScale) : (targetWidth * (closeFactor + (0.3 * squishRatio * closeFactor)))

    readonly property real wingW: 16 * animScale
    readonly property real wingH: 16 * animScale
    readonly property real radius: 18 * animScale

    readonly property real borderWidth: 3
    readonly property real halfB: borderWidth / 2.0

    // Dynamic Wayland Anchor Mapping
    anchors {
        top: barPosition === "top" || !isHorizontal
        bottom: barPosition === "bottom" || !isHorizontal
        left: barPosition === "left" || isHorizontal
        right: barPosition === "right" || isHorizontal
    }

    margins {
        top: barPosition === "bottom" ? 0 : ((Config.barMargin || 4) - shadowPadding)
        bottom: barPosition === "top" ? 0 : ((Config.barMargin || 4) - shadowPadding)
        left: barPosition === "right" ? 0 : ((Config.barMargin || 4) - shadowPadding)
        right: barPosition === "left" ? 0 : ((Config.barMargin || 4) - shadowPadding)
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
    WlrLayershell.exclusiveZone: barH + (Config.barMargin || 4)
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // ESCAPE KEY DISMISSAL
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

    readonly property real minPossibleLeft: root.halfB
    readonly property real maxPossibleRight: (isHorizontal ? mainContainer.width : mainContainer.height) - root.halfB

    readonly property bool isLeftFlush: !isCentered && ((isHorizontal ? popoutXOffset : popoutYOffset) < ((isHorizontal ? mainContainer.width : mainContainer.height) * 0.35))
    readonly property bool isRightFlush: !isCentered && ((isHorizontal ? popoutXOffset : popoutYOffset) > ((isHorizontal ? mainContainer.width : mainContainer.height) * 0.65))

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
        if (Config.showWorkspacePreview) activeView = "workspacePreview"
        else if (Config.showPower) activeView = "power"
        else if (Config.showWallpaper) activeView = "wallpaper"
        else if (Config.showAppLauncher) activeView = "appLauncher"
        else if (Config.showCalendar) activeView = "calendar"
        else if (Config.showNotifications) activeView = "notifications"
        else if (Config.showAudio) activeView = "audio"
        else if (Config.showNetwork) activeView = "network"
        else if (Config.showSystemMonitor) activeView = "systemMonitor"
        else if (Config.showBattery) activeView = "battery"
        else if (Config.showClipboard) activeView = "clipboard"
        else if (Config.showScreenRecorder) activeView = "screenRecorder"
        else if (Config.showControlCenter) activeView = "controlCenter"
        else activeView = "none"

        root.isOpen = (activeView !== "none")
    }

    function setPopoutPos(item) {
        root.isCentered = false
        if (isHorizontal) {
            root.popoutXOffset = item.mapToItem(mainContainer, item.width / 2, 0).x
        } else {
            root.popoutYOffset = item.mapToItem(mainContainer, 0, item.height / 2).y
        }
    }

    function recordRegion() {
        closeOthers("none")
        let home = Quickshell.env("HOME")
        let dateStr = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss")
        let file = home + "/Videos/recording_" + dateStr + ".mp4"
        let cmd = "sleep 0.15; and set -l geom (slurp); and test -n \"$geom\"; and mkdir -p ~/Videos; and exec wf-recorder -f " + file + " -g \"$geom\""
        
        Quickshell.execDetached(["fish", "-c", cmd])
        Quickshell.execDetached(["notify-send", "-a", "Screen Recorder", "-i", "media-record", "Screen Recorder", "Select region to start recording..."])
    }

    function recordFullscreen() {
        closeOthers("none")
        let home = Quickshell.env("HOME")
        let dateStr = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss")
        let file = home + "/Videos/recording_" + dateStr + ".mp4"
        let cmd = "mkdir -p ~/Videos; and exec wf-recorder -f " + file
        
        Quickshell.execDetached(["fish", "-c", cmd])
        Quickshell.execDetached(["notify-send", "-a", "Screen Recorder", "-i", "media-record", "Recording Started", "Capturing video..."])
    }

    function stopRecording() {
        Quickshell.execDetached(["pkill", "-2", "wf-recorder"])
    }

    Connections {
        target: Config
        ignoreUnknownSignals: true

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

    function closeOthers(except) {
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

    Item {
        id: mainContainer
        anchors.fill: parent
        anchors.margins: shadowPadding

        // BACKDROP DISMISS AREA (Catches clicks on empty bar spaces when open)
        MouseArea {
            anchors.fill: parent
            enabled: root.isOpen
            onClicked: {
                root.closeOthers("none")
                root.isCentered = false
            }
        }

        states: [
            State {
                name: "open"
                when: root.isOpen
                PropertyChanges { target: root; progress: 1.0 }
            },
            State {
                name: "closed"
                when: !root.isOpen
                PropertyChanges { target: root; progress: 0.0 }
            }
        ]

        transitions: [
            Transition {
                from: "closed"; to: "open"
                
                NumberAnimation { 
                    target: root
                    property: "progress"
                    duration: 500
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.7
                }
            },
            Transition {
                from: "open"; to: "closed"
                
                NumberAnimation { 
                    target: root
                    property: "progress"
                    duration: 300
                    easing.type: Easing.InBack
                    easing.overshoot: 1.6
                }
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

            // CLOSED STATE SHAPE
            Shape {
                id: closedShape
                anchors.fill: parent
                visible: root.progress === 0

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

            // OPEN STATE - TOP POSITION SHAPE
            Shape {
                id: openShapeTop
                anchors.fill: parent
                visible: root.barPosition === "top" && (root.isOpen || root.progress > 0)

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

                    PathLine { 
                        x: mainContainer.width - root.halfB
                        y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : (root.barBottomY - root.barRadius)
                    }

                    PathArc {
                        x: root.isRightFlush ? (mainContainer.width - root.halfB) : (mainContainer.width - root.halfB - root.barRadius)
                        y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : root.barBottomY
                        radiusX: root.isRightFlush ? 0 : root.barRadius
                        radiusY: root.isRightFlush ? 0 : root.barRadius
                        direction: PathArc.Clockwise
                    }

                    PathLine {
                        x: root.isRightFlush ? (mainContainer.width - root.halfB) : (root.pRight + root.wingW)
                        y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : root.barBottomY
                    }

                    PathCubic {
                        x: root.isRightFlush ? (mainContainer.width - root.halfB) : root.pRight
                        y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : (root.barBottomY + root.wingH)
                        control1X: root.isRightFlush ? (mainContainer.width - root.halfB) : (root.pRight + (root.wingW * 0.5))
                        control1Y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : root.barBottomY
                        control2X: root.isRightFlush ? (mainContainer.width - root.halfB) : root.pRight
                        control2Y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : (root.barBottomY + (root.wingH * 0.5))
                    }

                    PathLine { 
                        x: root.isRightFlush ? (mainContainer.width - root.halfB) : root.pRight
                        y: root.barBottomY + root.wingH + root.currentHeight - root.radius 
                    }

                    PathArc {
                        x: root.isRightFlush ? (mainContainer.width - root.halfB - root.radius) : (root.pRight - root.radius)
                        y: root.barBottomY + root.wingH + root.currentHeight
                        radiusX: Math.max(0.1, root.radius)
                        radiusY: Math.max(0.1, root.radius)
                        direction: PathArc.Clockwise
                    }

                    PathLine { 
                        x: root.isLeftFlush ? (root.halfB + root.radius) : (root.pLeft + root.radius)
                        y: root.barBottomY + root.wingH + root.currentHeight 
                    }

                    PathArc {
                        x: root.isLeftFlush ? root.halfB : root.pLeft
                        y: root.barBottomY + root.wingH + root.currentHeight - root.radius
                        radiusX: Math.max(0.1, root.radius)
                        radiusY: Math.max(0.1, root.radius)
                        direction: PathArc.Clockwise
                    }

                    PathLine { 
                        x: root.isLeftFlush ? root.halfB : root.pLeft
                        y: root.isLeftFlush ? (root.halfB + root.barRadius) : (root.barBottomY + root.wingH)
                    }

                    PathCubic {
                        x: root.isLeftFlush ? root.halfB : (root.pLeft - root.wingW)
                        y: root.isLeftFlush ? (root.halfB + root.barRadius) : root.barBottomY
                        control1X: root.isLeftFlush ? root.halfB : root.pLeft
                        control1Y: root.isLeftFlush ? (root.halfB + root.barRadius) : (root.barBottomY + (root.wingH * 0.5))
                        control2X: root.isLeftFlush ? root.halfB : (root.pLeft - (root.wingW * 0.5))
                        control2Y: root.isLeftFlush ? root.barBottomY : root.barBottomY
                    }

                    PathLine { 
                        x: root.isLeftFlush ? root.halfB : (root.halfB + root.barRadius)
                        y: root.isLeftFlush ? (root.halfB + root.barRadius) : root.barBottomY 
                    }

                    PathArc {
                        x: root.halfB
                        y: root.isLeftFlush ? (root.halfB + root.barRadius) : (root.barBottomY - root.barRadius)
                        radiusX: root.isLeftFlush ? 0 : root.barRadius
                        radiusY: root.isLeftFlush ? 0 : root.barRadius
                        direction: PathArc.Clockwise
                    }

                    PathLine { x: root.halfB; y: root.halfB + root.barRadius }
                    PathArc {
                        x: root.halfB + root.barRadius; y: root.halfB
                        radiusX: root.barRadius; radiusY: root.barRadius
                        direction: PathArc.Clockwise
                    }
                }
            }

            // OPEN STATE - BOTTOM POSITION SHAPE
            Shape {
                id: openShapeBottom
                anchors.fill: parent
                visible: root.barPosition === "bottom" && (root.isOpen || root.progress > 0)

                readonly property real barTopY: mainContainer.height - root.barH + root.halfB

                ShapePath {
                    fillColor: Config.bgPanel
                    strokeWidth: root.borderWidth
                    strokeColor: shellRoot.currentBorderColor
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap

                    startX: root.halfB
                    startY: root.isLeftFlush ? openShapeBottom.barTopY : (openShapeBottom.barTopY + root.barRadius)

                    PathArc { 
                        x: root.halfB + (root.isLeftFlush ? 0 : root.barRadius)
                        y: openShapeBottom.barTopY
                        radiusX: root.isLeftFlush ? 0 : root.barRadius
                        radiusY: root.isLeftFlush ? 0 : root.barRadius
                        direction: PathArc.Clockwise 
                    }

                    PathLine { 
                        x: root.isLeftFlush ? root.halfB : (root.pLeft - root.wingW)
                        y: openShapeBottom.barTopY 
                    }

                    PathCubic {
                        x: root.pLeft
                        y: root.isLeftFlush ? openShapeBottom.barTopY : (openShapeBottom.barTopY - root.wingH)
                        control1X: root.isLeftFlush ? root.halfB : (root.pLeft - (root.wingW * 0.5))
                        control1Y: openShapeBottom.barTopY
                        control2X: root.pLeft
                        control2Y: root.isLeftFlush ? openShapeBottom.barTopY : (openShapeBottom.barTopY - (root.wingH * 0.5))
                    }

                    PathLine { x: root.pLeft; y: openShapeBottom.barTopY - root.wingH - root.currentHeight + root.radius }

                    PathArc { 
                        x: root.pLeft + root.radius
                        y: openShapeBottom.barTopY - root.wingH - root.currentHeight
                        radiusX: Math.max(0.1, root.radius)
                        radiusY: Math.max(0.1, root.radius)
                        direction: PathArc.Clockwise 
                    }

                    PathLine { x: root.pRight - root.radius; y: openShapeBottom.barTopY - root.wingH - root.currentHeight }

                    PathArc { 
                        x: root.pRight
                        y: openShapeBottom.barTopY - root.wingH - root.currentHeight + root.radius
                        radiusX: Math.max(0.1, root.radius)
                        radiusY: Math.max(0.1, root.radius)
                        direction: PathArc.Clockwise 
                    }

                    PathLine { x: root.pRight; y: root.isRightFlush ? openShapeBottom.barTopY : (openShapeBottom.barTopY - root.wingH) }

                    PathCubic {
                        x: root.isRightFlush ? (mainContainer.width - root.halfB) : (root.pRight + root.wingW)
                        y: openShapeBottom.barTopY
                        control1X: root.pRight
                        control1Y: root.isRightFlush ? openShapeBottom.barTopY : (openShapeBottom.barTopY - (root.wingH * 0.5))
                        control2X: root.isRightFlush ? (mainContainer.width - root.halfB) : (root.pRight + (root.wingW * 0.5))
                        control2Y: openShapeBottom.barTopY
                    }

                    PathLine { 
                        x: root.isRightFlush ? (mainContainer.width - root.halfB) : (mainContainer.width - root.halfB - root.barRadius)
                        y: openShapeBottom.barTopY 
                    }

                    PathArc { 
                        x: mainContainer.width - root.halfB
                        y: openShapeBottom.barTopY + (root.isRightFlush ? 0 : root.barRadius)
                        radiusX: root.isRightFlush ? 0 : root.barRadius
                        radiusY: root.isRightFlush ? 0 : root.barRadius
                        direction: PathArc.Clockwise 
                    }

                    PathLine { x: mainContainer.width - root.halfB; y: mainContainer.height - root.halfB - root.barRadius }
                    PathArc { x: mainContainer.width - root.halfB - root.barRadius; y: mainContainer.height - root.halfB; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.halfB + root.barRadius; y: mainContainer.height - root.halfB }
                    PathArc { x: root.halfB; y: mainContainer.height - root.halfB - root.barRadius; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }
                    PathLine { x: root.halfB; y: openShapeBottom.barTopY + (root.isLeftFlush ? 0 : root.barRadius) }
                }
            }

            // OPEN STATE - LEFT POSITION SHAPE
            Shape {
                id: openShapeLeft
                anchors.fill: parent
                visible: root.barPosition === "left" && (root.isOpen || root.progress > 0)

                ShapePath {
                    fillColor: Config.bgPanel
                    strokeWidth: root.borderWidth
                    strokeColor: shellRoot.currentBorderColor
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap

                    startX: root.halfB + root.barRadius
                    startY: root.halfB

                    PathLine { 
                        x: root.isLeftFlush ? (root.barH - root.halfB) : (root.barH - root.halfB - root.barRadius)
                        y: root.halfB 
                    }

                    PathArc { 
                        x: root.barH - root.halfB
                        y: root.isLeftFlush ? root.halfB : (root.halfB + root.barRadius)
                        radiusX: root.isLeftFlush ? 0 : root.barRadius
                        radiusY: root.isLeftFlush ? 0 : root.barRadius
                        direction: PathArc.Clockwise 
                    }

                    PathLine { 
                        x: root.barH - root.halfB
                        y: root.isLeftFlush ? root.pLeft : (root.pLeft - root.wingW) 
                    }

                    PathCubic {
                        x: root.barH - root.halfB + root.wingW
                        y: root.pLeft
                        control1X: root.barH - root.halfB
                        control1Y: root.isLeftFlush ? root.pLeft : (root.pLeft - (root.wingW * 0.5))
                        control2X: root.barH - root.halfB + (root.wingW * 0.5)
                        control2Y: root.pLeft
                    }

                    PathLine { x: root.barH - root.halfB + root.wingW + root.currentWidth - root.radius; y: root.pLeft }
                    PathArc { x: root.barH - root.halfB + root.wingW + root.currentWidth; y: root.pLeft + root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }

                    PathLine { x: root.barH - root.halfB + root.wingW + root.currentWidth; y: root.pRight - root.radius }
                    PathArc { x: root.barH - root.halfB + root.wingW + root.currentWidth - root.radius; y: root.pRight; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }

                    PathLine { x: root.barH - root.halfB + root.wingW; y: root.pRight }
                    PathCubic {
                        x: root.barH - root.halfB
                        y: root.isRightFlush ? root.pRight : (root.pRight + root.wingW)
                        control1X: root.barH - root.halfB + (root.wingW * 0.5)
                        control1Y: root.pRight
                        control2X: root.barH - root.halfB
                        control2Y: root.isRightFlush ? root.pRight : (root.pRight + (root.wingW * 0.5))
                    }

                    PathLine { 
                        x: root.barH - root.halfB
                        y: root.isRightFlush ? (mainContainer.height - root.halfB) : (mainContainer.height - root.halfB - root.barRadius)
                    }

                    PathArc { 
                        x: root.barH - root.halfB - (root.isRightFlush ? 0 : root.barRadius)
                        y: mainContainer.height - root.halfB
                        radiusX: root.isRightFlush ? 0 : root.barRadius
                        radiusY: root.isRightFlush ? 0 : root.barRadius
                        direction: PathArc.Clockwise 
                    }

                    PathLine { x: root.halfB + root.barRadius; y: mainContainer.height - root.halfB }
                    PathArc { 
                        x: root.halfB
                        y: mainContainer.height - root.halfB - root.barRadius
                        radiusX: root.barRadius
                        radiusY: root.barRadius
                        direction: PathArc.Clockwise 
                    }

                    PathLine { x: root.halfB; y: root.halfB + root.barRadius }
                    PathArc { 
                        x: root.halfB + root.barRadius
                        y: root.halfB
                        radiusX: root.barRadius
                        radiusY: root.barRadius
                        direction: PathArc.Clockwise 
                    }
                }
            }

            // OPEN STATE - RIGHT POSITION SHAPE
            Shape {
                id: openShapeRight
                anchors.fill: parent
                visible: root.barPosition === "right" && (root.isOpen || root.progress > 0)

                readonly property real rX: mainContainer.width - root.barH

                ShapePath {
                    fillColor: Config.bgPanel
                    strokeWidth: root.borderWidth
                    strokeColor: shellRoot.currentBorderColor
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap

                    startX: openShapeRight.rX + root.halfB
                    startY: root.isLeftFlush ? root.halfB : (root.halfB + root.barRadius)

                    PathLine { x: mainContainer.width - root.halfB - root.barRadius; y: root.halfB }
                    PathArc { x: mainContainer.width - root.halfB; y: root.halfB + root.barRadius; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }

                    PathLine { x: mainContainer.width - root.halfB; y: mainContainer.height - root.halfB - root.barRadius }
                    PathArc { x: mainContainer.width - root.halfB - root.barRadius; y: mainContainer.height - root.halfB; radiusX: root.barRadius; radiusY: root.barRadius; direction: PathArc.Clockwise }

                    PathLine { x: openShapeRight.rX + root.halfB + root.barRadius; y: mainContainer.height - root.halfB }
                    PathArc { x: openShapeRight.rX + root.halfB; y: mainContainer.height - root.halfB - (root.isRightFlush ? 0 : root.barRadius); radiusX: root.isRightFlush ? 0 : root.barRadius; radiusY: root.isRightFlush ? 0 : root.barRadius; direction: PathArc.Clockwise }

                    PathLine { x: openShapeRight.rX + root.halfB; y: root.isRightFlush ? (mainContainer.height - root.halfB) : (root.pRight + root.wingW) }

                    PathCubic {
                        x: root.isRightFlush ? (openShapeRight.rX + root.halfB) : (openShapeRight.rX + root.halfB - root.wingW)
                        y: root.pRight
                        control1X: openShapeRight.rX + root.halfB
                        control1Y: root.isRightFlush ? (mainContainer.height - root.halfB) : (root.pRight + (root.wingW * 0.5))
                        control2X: root.isRightFlush ? (openShapeRight.rX + root.halfB) : (openShapeRight.rX + root.halfB - (root.wingW * 0.5))
                        control2Y: root.pRight
                    }

                    PathLine { x: openShapeRight.rX + root.halfB - root.wingW - root.currentWidth + root.radius; y: root.pRight }
                    PathArc { x: openShapeRight.rX + root.halfB - root.wingW - root.currentWidth; y: root.pRight - root.radius; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }

                    PathLine { x: openShapeRight.rX + root.halfB - root.wingW - root.currentWidth; y: root.pLeft + root.radius }
                    PathArc { x: openShapeRight.rX + root.halfB - root.wingW - root.currentWidth + root.radius; y: root.pLeft; radiusX: Math.max(0.1, root.radius); radiusY: Math.max(0.1, root.radius); direction: PathArc.Clockwise }

                    PathLine { x: root.isLeftFlush ? (openShapeRight.rX + root.halfB) : (openShapeRight.rX + root.halfB - root.wingW); y: root.pLeft }

                    PathCubic {
                        x: openShapeRight.rX + root.halfB
                        y: root.isLeftFlush ? root.halfB : (root.pLeft - root.wingW)
                        control1X: root.isLeftFlush ? (openShapeRight.rX + root.halfB) : (openShapeRight.rX + root.halfB - (root.wingW * 0.5))
                        control1Y: root.pLeft
                        control2X: openShapeRight.rX + root.halfB
                        control2Y: root.isLeftFlush ? root.halfB : (root.pLeft - (root.wingW * 0.5))
                    }

                    PathLine { x: openShapeRight.rX + root.halfB; y: root.isLeftFlush ? root.halfB : (root.halfB + root.barRadius) }

                    PathArc { 
                        x: openShapeRight.rX + root.halfB + (root.isLeftFlush ? 0 : root.barRadius)
                        y: root.halfB
                        radiusX: root.isLeftFlush ? 0 : root.barRadius
                        radiusY: root.isLeftFlush ? 0 : root.barRadius
                        direction: PathArc.Clockwise 
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
                anchors.centerIn: parent
                implicitHeight: isHorizontal ? 32 : centerGroup.implicitHeight + 16
                implicitWidth: isHorizontal ? centerGroup.implicitWidth + 24 : 32
                radius: Config.cornerRadius / 2
                color: Qt.rgba(255, 255, 255, 0.05)

                GridLayout {
                    id: centerGroup
                    anchors.centerIn: parent
                    columns: isHorizontal ? -1 : 1
                    rows: isHorizontal ? 1 : -1
                    columnSpacing: 16
                    rowSpacing: 16

                    WorkspaceIndicators {
                        isVertical: !root.isHorizontal
                        Layout.alignment: Qt.AlignCenter
                    }

                    Item {
                        id: taskbarContainerH
                        Layout.alignment: Qt.AlignCenter
                        implicitWidth: horizTaskbarLoader.item ? horizTaskbarLoader.item.implicitWidth : 0
                        implicitHeight: horizTaskbarLoader.item ? horizTaskbarLoader.item.implicitHeight : 0

                        Timer {
                            id: horizBootTimer
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
                                isVertical: !root.isHorizontal
                                activeScreenName: root.screen ? root.screen.name : ""
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
            
            x: isHorizontal 
                ? (root.staticLeft + ((root.targetWidth - root.currentWidth) / 2.0) + 12)
                : (isRight 
                    ? (mainContainer.width - root.barH - root.currentWidth) 
                    : (root.barH + (root.wingW * (1.0 - root.animScale))))

            y: isHorizontal 
                ? (isBottom 
                    ? (mainContainer.height - root.barH - root.currentHeight) 
                    : (root.barH + (root.wingH * (1.0 - root.animScale))))
                : (root.staticLeft + ((root.targetHeight - root.currentHeight) / 2.0) + 12)
            
            width: isHorizontal ? Math.max(1, root.currentWidth - 24) : Math.max(1, root.currentWidth)
            height: isHorizontal ? Math.max(1, root.currentHeight) : Math.max(1, root.currentHeight - 24)
            clip: true
            visible: root.progress >= 0.98
            focus: true

            TapHandler {
                onTapped: {} 
            }
        }
    }
}