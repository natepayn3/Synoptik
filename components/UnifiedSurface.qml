import QtQuick
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
    property real popoutXOffset: screen.width / 2.0
    property bool isCentered: false

    // Configured Bar Edge Position: "top" | "bottom" | "left" | "right"
    readonly property string barPosition: Config.barPosition || "top"
    readonly property bool isHorizontal: barPosition === "top" || barPosition === "bottom"

    // Corner radius for main bar shell
    readonly property real barRadius: Config.cornerRadius || 12

    // Target content dimensions relying strictly on implicit sizing
    property real targetWidth: {
        if (contentContainer.children.length > 0) {
            let child = contentContainer.children[0]
            if (child.item && child.item.implicitWidth > 0) return child.item.implicitWidth
            if (child.implicitWidth > 0) return child.implicitWidth
        }
        return 420
    }

    property real targetHeight: {
        if (contentContainer.children.length > 0) {
            let child = contentContainer.children[0]
            if (child.item && child.item.implicitHeight > 0) return child.item.implicitHeight
            if (child.implicitHeight > 0) return child.implicitHeight
        }
        return 480
    }

    property real progress: 0.0
    readonly property real animScale: Math.max(0.0, Math.min(1.0, progress))

    // Morph dimensions
    readonly property real wingW: 16 * animScale
    readonly property real wingH: 16 * animScale
    readonly property real radius: 18 * animScale
    readonly property real currentHeight: targetHeight * animScale
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
        top: barPosition === "bottom" ? 0 : (Config.barMargin || 4)
        bottom: barPosition === "top" ? 0 : (Config.barMargin || 4)
        left: barPosition === "right" ? 0 : (Config.barMargin || 4)
        right: barPosition === "left" ? 0 : (Config.barMargin || 4)
    }

    readonly property real barH: Config.barHeight || 46
    readonly property real barBottomY: barH - halfB

    implicitHeight: isHorizontal ? Math.max(barH, targetHeight + barH + 32) : screen.height
    implicitWidth: isHorizontal ? screen.width : Math.max(barH, targetWidth + barH + 32)
    color: "transparent"

    visible: true

    // Direct Wayland region mapping for seamless mouse hit-testing
    mask: Region {
        Region { item: barContent }
        Region { item: (root.isOpen || root.progress > 0.01) ? contentContainer : null }
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: barH
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    HyprlandFocusGrab {
        id: focusGrab
        active: root.isOpen
        windows: [root]
        
        onCleared: {
            root.closeOthers("none")
            root.isCentered = false
        }
    }

    // Outer edge boundaries
    readonly property real minPossibleLeft: root.halfB
    readonly property real maxPossibleRight: root.width - root.halfB

    // Centered vs Edge Docking Logic
    readonly property bool isLeftFlush: !isCentered && (popoutXOffset < (root.width * 0.35))
    readonly property bool isRightFlush: !isCentered && (popoutXOffset > (root.width * 0.65))

    readonly property real targetCenteredLeft: Math.max(minPossibleLeft + 16, Math.min(maxPossibleRight - targetWidth - 16, (root.width - targetWidth) / 2.0))

    readonly property real staticLeft: {
        if (isCentered) return targetCenteredLeft
        if (isLeftFlush) return minPossibleLeft
        if (isRightFlush) return maxPossibleRight - targetWidth
        return Math.max(minPossibleLeft + 16, Math.min(maxPossibleRight - targetWidth - 16, popoutXOffset - (targetWidth / 2.0)))
    }

    readonly property real staticRight: staticLeft + targetWidth

    readonly property real pLeft: staticLeft
    readonly property real pRight: staticRight

    // Active View State Machine: ensures only one panel type is ever active
    property string activeView: "none"

    function updateActiveView() {
        if (Config.showWorkspacePreview) activeView = "workspacePreview"
        else if (Config.showSettings) activeView = "settings"
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
        else if (Config.showControlCenter) activeView = "controlCenter"
        else activeView = "none"

        root.isOpen = (activeView !== "none")
    }

    Connections {
        target: Config
        ignoreUnknownSignals: true

        function onShowWorkspacePreviewChanged() {
            if (Config.showWorkspacePreview) {
                closeOthers("workspacePreview")
                root.isCentered = true
                root.popoutXOffset = root.width / 2.0
            } else if (activeView === "workspacePreview") {
                root.isCentered = false
            }
            updateActiveView()
        }

        function onShowAppLauncherChanged() {
            if (Config.showAppLauncher) {
                closeOthers("appLauncher")
                root.isCentered = false
                // Anchor to the launcher button even when triggered via IPC
                root.popoutXOffset = btnLauncher.mapToItem(mainContainer, btnLauncher.width / 2, 0).x
            }
            updateActiveView()
        }

        function onShowSettingsChanged() {
            if (Config.showSettings) {
                closeOthers("settings")
                root.isCentered = false
                root.popoutXOffset = btnSettings.mapToItem(mainContainer, btnSettings.width / 2, 0).x
            }
            updateActiveView()
        }

        function onShowPowerChanged() {
            if (Config.showPower) {
                closeOthers("power")
                root.isCentered = false
                root.popoutXOffset = btnPower.mapToItem(mainContainer, btnPower.width / 2, 0).x
            }
            updateActiveView()
        }

        function onShowWallpaperChanged() {
            if (Config.showWallpaper) {
                closeOthers("wallpaper")
                root.isCentered = false
                root.popoutXOffset = btnWallpaper.mapToItem(mainContainer, btnWallpaper.width / 2, 0).x
            }
            updateActiveView()
        }

        function onShowCalendarChanged() {
            if (Config.showCalendar) {
                closeOthers("calendar")
                root.isCentered = false
                root.popoutXOffset = btnClock.mapToItem(mainContainer, btnClock.width / 2, 0).x
            }
            updateActiveView()
        }

        function onShowNotificationsChanged() {
            if (Config.showNotifications) {
                closeOthers("notifications")
                root.isCentered = false
                root.popoutXOffset = btnNotifications.mapToItem(mainContainer, btnNotifications.width / 2, 0).x
            }
            updateActiveView()
        }

        function onShowAudioChanged() {
            if (Config.showAudio) {
                closeOthers("audio")
                root.isCentered = false
                root.popoutXOffset = btnAudio.mapToItem(mainContainer, btnAudio.width / 2, 0).x
            }
            updateActiveView()
        }

        function onShowNetworkChanged() {
            if (Config.showNetwork) {
                closeOthers("network")
                root.isCentered = false
                root.popoutXOffset = btnNetwork.mapToItem(mainContainer, btnNetwork.width / 2, 0).x
            }
            updateActiveView()
        }

        function onShowSystemMonitorChanged() {
            if (Config.showSystemMonitor) {
                closeOthers("systemMonitor")
                root.isCentered = false
                root.popoutXOffset = btnSys.mapToItem(mainContainer, btnSys.width / 2, 0).x
            }
            updateActiveView()
        }

        function onShowBatteryChanged() {
            if (Config.showBattery) {
                closeOthers("battery")
                root.isCentered = false
                root.popoutXOffset = btnBatt.mapToItem(mainContainer, btnBatt.width / 2, 0).x
            }
            updateActiveView()
        }

        function onShowClipboardChanged() {
            if (Config.showClipboard) {
                closeOthers("clipboard")
                root.isCentered = false
                root.popoutXOffset = btnClipboard.mapToItem(mainContainer, btnClipboard.width / 2, 0).x
            }
            updateActiveView()
        }

        function onShowControlCenterChanged() {
            if (Config.showControlCenter) {
                closeOthers("controlCenter")
                root.isCentered = false
                root.popoutXOffset = btnCC.mapToItem(mainContainer, btnCC.width / 2, 0).x
            }
            updateActiveView()
        }
    }

    function closeOthers(except) {
        if (except !== "workspacePreview") Config.showWorkspacePreview = false
        if (except !== "settings") Config.showSettings = false
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
        if (except !== "controlCenter") Config.showControlCenter = false
    }

    Item {
        id: mainContainer
        anchors.fill: parent

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
                    property: "progress"
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation {
                    property: "progress"
                    duration: 220
                    easing.type: Easing.InQuad
                }
            }
        ]

        Item {
            anchors.fill: parent

            // 1. CLOSED STATE
            Shape {
                anchors.fill: parent
                visible: root.progress === 0
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    fillColor: Config.bgPanel
                    strokeWidth: root.borderWidth
                    strokeColor: shellRoot.currentBorderColor
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap

                    startX: root.halfB + root.barRadius
                    startY: root.halfB

                    PathLine { x: root.width - root.halfB - root.barRadius; y: root.halfB }
                    PathArc {
                        x: root.width - root.halfB; y: root.halfB + root.barRadius
                        radiusX: root.barRadius; radiusY: root.barRadius
                        direction: PathArc.Clockwise
                    }

                    PathLine { x: root.width - root.halfB; y: root.barBottomY - root.barRadius }
                    PathArc {
                        x: root.width - root.halfB - root.barRadius; y: root.barBottomY
                        radiusX: root.barRadius; radiusY: root.barRadius
                        direction: PathArc.Clockwise
                    }

                    PathLine { x: root.halfB + root.barRadius; y: root.barBottomY }
                    PathArc {
                        x: root.halfB; y: root.barBottomY - root.barRadius
                        radiusX: root.barRadius; radiusY: root.barRadius
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

            // 2. OPEN / ANIMATING STATE
            Shape {
                id: openShape
                anchors.fill: parent
                visible: root.progress > 0
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    fillColor: Config.bgPanel
                    strokeWidth: root.borderWidth
                    strokeColor: shellRoot.currentBorderColor
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap

                    startX: root.halfB + root.barRadius
                    startY: root.halfB

                    // Top Edge -> Top-Right Arc
                    PathLine { x: root.width - root.halfB - root.barRadius; y: root.halfB }
                    PathArc {
                        x: root.width - root.halfB; y: root.halfB + root.barRadius
                        radiusX: root.barRadius; radiusY: root.barRadius
                        direction: PathArc.Clockwise
                    }

                    // Right Bar Edge & Bottom-Right Arc
                    PathLine { 
                        x: root.width - root.halfB
                        y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : (root.barBottomY - root.barRadius)
                    }

                    PathArc {
                        x: root.isRightFlush ? (root.width - root.halfB) : (root.width - root.halfB - root.barRadius)
                        y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : root.barBottomY
                        radiusX: root.isRightFlush ? 0 : root.barRadius
                        radiusY: root.isRightFlush ? 0 : root.barRadius
                        direction: PathArc.Clockwise
                    }

                    // Right Wing
                    PathLine {
                        x: root.isRightFlush ? (root.width - root.halfB) : (root.pRight + root.wingW)
                        y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : root.barBottomY
                    }

                    PathCubic {
                        x: root.isRightFlush ? (root.width - root.halfB) : root.pRight
                        y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : (root.barBottomY + root.wingH)
                        control1X: root.isRightFlush ? (root.width - root.halfB) : (root.pRight + (root.wingW * 0.5))
                        control1Y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : root.barBottomY
                        control2X: root.isRightFlush ? (root.width - root.halfB) : root.pRight
                        control2Y: root.isRightFlush ? (root.barBottomY + root.wingH + root.currentHeight - root.radius) : (root.barBottomY + (root.wingH * 0.5))
                    }

                    // Drawer Right Wall & Bottom-Right Arc
                    PathLine { 
                        x: root.isRightFlush ? (root.width - root.halfB) : root.pRight
                        y: root.barBottomY + root.wingH + root.currentHeight - root.radius 
                    }

                    PathArc {
                        x: root.isRightFlush ? (root.width - root.halfB - root.radius) : (root.pRight - root.radius)
                        y: root.barBottomY + root.wingH + root.currentHeight
                        radiusX: Math.max(0.1, root.radius)
                        radiusY: Math.max(0.1, root.radius)
                        direction: PathArc.Clockwise
                    }

                    // Drawer Bottom Wall & Bottom-Left Arc
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

                    // Left Wing
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

                    // Bar Bottom Left Line & Arc
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

                    // Left Wall -> Top-Left Arc
                    PathLine { x: root.halfB; y: root.halfB + root.barRadius }
                    PathArc {
                        x: root.halfB + root.barRadius; y: root.halfB
                        radiusX: root.barRadius; radiusY: root.barRadius
                        direction: PathArc.Clockwise
                    }
                }
            }
        }

        // TOP BAR CONTROLS
        Item {
            id: barContent
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: root.barH

            // Left Side Actions
            RowLayout {
                id: leftModules
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 10
                }
                spacing: 8

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

                    TapHandler {
                        onTapped: {
                            root.isCentered = false
                            root.popoutXOffset = btnSettings.mapToItem(mainContainer, btnSettings.width / 2, 0).x
                            Config.showSettings = !Config.showSettings
                        }
                    }
                    HoverHandler { id: settingsHover; cursorShape: Qt.PointingHandCursor }
                }

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

                    TapHandler {
                        onTapped: {
                            root.isCentered = false
                            root.popoutXOffset = btnPower.mapToItem(mainContainer, btnPower.width / 2, 0).x
                            Config.showPower = !Config.showPower
                        }
                    }
                    HoverHandler { id: powerHover; cursorShape: Qt.PointingHandCursor }
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

                    TapHandler {
                        onTapped: {
                            root.isCentered = false
                            root.popoutXOffset = btnWallpaper.mapToItem(mainContainer, btnWallpaper.width / 2, 0).x
                            Config.showWallpaper = !Config.showWallpaper
                        }
                    }
                    HoverHandler { id: wallpaperHover; cursorShape: Qt.PointingHandCursor }
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

                    TapHandler {
                        onTapped: {
                            root.isCentered = false
                            root.popoutXOffset = btnLauncher.mapToItem(mainContainer, btnLauncher.width / 2, 0).x
                            Config.showAppLauncher = !Config.showAppLauncher
                        }
                    }
                    HoverHandler { id: launcherHover; cursorShape: Qt.PointingHandCursor }
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

                    TapHandler {
                        onTapped: {
                            Quickshell.execDetached(["fish", "-c", "sleep 0.1; and grim -g (slurp) -t ppm - | satty --filename -"])
                        }
                    }
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

                    TapHandler {
                        onTapped: {
                            root.isCentered = false
                            root.popoutXOffset = btnClipboard.mapToItem(mainContainer, btnClipboard.width / 2, 0).x
                            Config.showClipboard = !Config.showClipboard
                        }
                    }
                    HoverHandler { id: clipHover; cursorShape: Qt.PointingHandCursor }
                }
            }

            // Center Workspace Indicators & Taskbar
            Rectangle {
                anchors.centerIn: parent
                implicitHeight: 32
                implicitWidth: centerGroup.implicitWidth + 24
                radius: Config.cornerRadius / 2
                color: Qt.rgba(255, 255, 255, 0.05)

                RowLayout {
                    id: centerGroup
                    anchors.centerIn: parent
                    spacing: 16

                    WorkspaceIndicators {
                        isVertical: false
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item {
                        id: taskbarContainerH
                        Layout.alignment: Qt.AlignVCenter
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
                                isVertical: false
                                activeScreenName: root.screen ? root.screen.name : ""
                            }
                        }
                    }
                }
            }

            // Right Status Indicators & Clock
            RowLayout {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 10
                }
                spacing: 8

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

                    TapHandler {
                        onTapped: {
                            root.isCentered = false
                            root.popoutXOffset = btnAudio.mapToItem(mainContainer, btnAudio.width / 2, 0).x
                            Config.showAudio = !Config.showAudio
                        }
                    }
                    HoverHandler { id: audioHover; cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    id: btnNotifications
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    color: (Config.showNotifications || notificationsHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: (typeof notificationsFlyout !== "undefined" && notificationsFlyout.activeCount > 0) ? "inbox_text" : "inbox"
                        color: Config.showNotifications ? Config.accent : Config.textMain
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                    }

                    TapHandler {
                        onTapped: {
                            root.isCentered = false
                            root.popoutXOffset = btnNotifications.mapToItem(mainContainer, btnNotifications.width / 2, 0).x
                            Config.showNotifications = !Config.showNotifications
                        }
                    }
                    HoverHandler { id: notificationsHover; cursorShape: Qt.PointingHandCursor }
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

                    TapHandler {
                        onTapped: {
                            root.isCentered = false
                            root.popoutXOffset = btnNetwork.mapToItem(mainContainer, btnNetwork.width / 2, 0).x
                            Config.showNetwork = !Config.showNetwork
                        }
                    }
                    HoverHandler { id: networkHover; cursorShape: Qt.PointingHandCursor }
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

                    TapHandler {
                        onTapped: {
                            root.isCentered = false
                            root.popoutXOffset = btnSys.mapToItem(mainContainer, btnSys.width / 2, 0).x
                            Config.showSystemMonitor = !Config.showSystemMonitor
                        }
                    }
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

                    TapHandler {
                        onTapped: {
                            root.isCentered = false
                            root.popoutXOffset = btnBatt.mapToItem(mainContainer, btnBatt.width / 2, 0).x
                            Config.showBattery = !Config.showBattery
                        }
                    }
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

                    TapHandler {
                        onTapped: {
                            root.isCentered = false
                            root.popoutXOffset = btnCC.mapToItem(mainContainer, btnCC.width / 2, 0).x
                            Config.showControlCenter = !Config.showControlCenter
                        }
                    }
                    HoverHandler { id: ccHover; cursorShape: Qt.PointingHandCursor }
                }

                Rectangle {
                    id: btnClock
                    implicitWidth: dateRow.implicitWidth + 20; implicitHeight: 32; radius: 10
                    color: (Config.showCalendar || clockHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: dateRow
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
                    TapHandler {
                        onTapped: {
                            root.isCentered = false
                            root.popoutXOffset = btnClock.mapToItem(mainContainer, btnClock.width / 2, 0).x
                            Config.showCalendar = !Config.showCalendar
                        }
                    }
                    HoverHandler { id: clockHover; cursorShape: Qt.PointingHandCursor }
                }
            }
        }

        // FLYOUT DRAWER CONTENT CONTAINER
        Item {
            id: contentContainer
            x: root.pLeft
            y: root.barH
            width: root.targetWidth
            height: root.currentHeight
            clip: true
            opacity: root.animScale
            focus: true // Bridge the focus chain
        }
    }
}