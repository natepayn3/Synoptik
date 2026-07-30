import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes 
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root
    
    default property alias content: contentContainer.data
    
    property color flyoutBorderColor: Config.accent
    property real panelWidth: 320
    property real panelHeight: 400

    property real visualPanelWidth: panelWidth
    property real visualPanelHeight: panelHeight

    Behavior on visualPanelWidth {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    
    Behavior on visualPanelHeight {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    property bool isOpen: false

    // Restored wing dimensions
    readonly property real wingDepth: 8
    readonly property real wingWidth: 12
    readonly property real drawerRadius: 24
    readonly property real bounceBuffer: 64

    // Inset distance to keep wing origins safely inside the bar's flat region
    readonly property real wingInset: 16

    readonly property string pos: Config.barPosition || "top"
    readonly property bool isHorizontal: pos === "top" || pos === "bottom"

    readonly property color activeBorderColor: {
        if (!Config.showBorders) return "transparent"
        if (flyoutBorderColor !== Config.accent) return flyoutBorderColor
        if (!Config.animateGradient) return Config.borderStart

        let c1 = Qt.color(Config.borderStart)
        let c2 = Qt.color(Config.borderEnd)
        
        let phase = (Math.sin((shellRoot ? shellRoot.animOffset : 0) * Math.PI * 2) + 1.0) / 2.0
        let dramaticProgress = phase < 0.5 ? 4 * phase * phase * phase : 1 - Math.pow(-2 * phase + 2, 3) / 2

        return Qt.rgba(
            c1.r + (c2.r - c1.r) * dramaticProgress,
            c1.g + (c2.g - c1.g) * dramaticProgress,
            c1.b + (c2.b - c1.b) * dramaticProgress,
            1.0
        )
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1

    Behavior on panelWidth {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    
    Behavior on panelHeight {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    property bool alignRight: false
    property bool alignCenter: false

    anchors {
        top: pos === "top" || (!isHorizontal && !alignRight && !alignCenter)
        bottom: pos === "bottom" || (!isHorizontal && alignRight && !alignCenter)
        left: (isHorizontal && !alignRight && !alignCenter) || pos === "left"
        right: (isHorizontal && alignRight && !alignCenter) || pos === "right"
    }

    margins {
        top: pos === "top" 
            ? ((Config.barHeight || 30) + (Config.barMargin || 8) - 3)
            : (!isHorizontal ? Math.max(0, Config.barMargin + 12 - (bounceBuffer / 2)) : 0)

        bottom: pos === "bottom" 
            ? ((Config.barHeight || 30) + (Config.barMargin || 8) - 3)
            : 0

        left: pos === "left"
            ? ((Config.barHeight || 30) + (Config.barMargin || 8) - 3)
            : (isHorizontal && !alignRight && !alignCenter ? Math.max(0, Config.barMargin + 12 - (bounceBuffer / 2)) : 0)

        right: pos === "right"
            ? ((Config.barHeight || 30) + (Config.barMargin || 8) - 3)
            : (isHorizontal && alignRight && !alignCenter ? Math.max(0, Config.barMargin + 12 - (bounceBuffer / 2)) : 0)
    }
    
    readonly property real unscaledWidth: isHorizontal 
        ? (visualPanelWidth + (wingWidth * 2) + (wingInset * 2)) 
        : (visualPanelWidth + 24)

    readonly property real unscaledHeight: isHorizontal 
        ? (visualPanelHeight + 24) 
        : (visualPanelHeight + (wingWidth * 2) + (wingInset * 2))
    
    implicitWidth: breathingContainer.width + (isHorizontal ? bounceBuffer : (wingWidth + bounceBuffer))
    implicitHeight: breathingContainer.height + (isHorizontal ? (wingWidth + bounceBuffer) : bounceBuffer)

    color: "transparent"
    
    readonly property bool isContentReady: {
        if (content && content.length > 0 && typeof content[0].contentReady !== "undefined") {
            return content[0].contentReady;
        }
        return true;
    }

    readonly property bool shouldShow: isOpen && isContentReady

    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    visible: isOpen || closeTransition.running || openTransition.running

    HyprlandFocusGrab {
        id: focusGrab
        active: root.isOpen && (root.WlrLayershell.keyboardFocus !== WlrKeyboardFocus.None)
        windows: [root]
        onCleared: {
            Config.showControlCenter = false
            Config.showSettings = false
            Config.showCalendar = false
            Config.showWallpaper = false
            Config.showAppLauncher = false
            Config.showNotifications = false
            Config.showNetwork = false
            Config.showAudio = false
            Config.showBattery = false
            Config.showSystemMonitor = false
            Config.showPower = false
            Config.showClipboard = false
            if (typeof Config.showWorkspacePreview !== "undefined") Config.showWorkspacePreview = false
        }
    }

    Shortcut {
        sequences: ["Escape"]
        enabled: root.isOpen
        onActivated: {
            Config.showControlCenter = false
            Config.showSettings = false
            Config.showCalendar = false
            Config.showWallpaper = false
            Config.showAppLauncher = false
            Config.showNotifications = false
            Config.showNetwork = false
            Config.showAudio = false
            Config.showBattery = false
            Config.showSystemMonitor = false
            Config.showPower = false
            Config.showClipboard = false
            if (typeof Config.showWorkspacePreview !== "undefined") Config.showWorkspacePreview = false
        }
    }

    Connections {
        target: Config
        function onBarPositionChanged() {
            if (!root.isOpen) {
                breathingContainer.x = breathingContainer.closedX
                breathingContainer.y = breathingContainer.closedY
            }
        }
    }

    Item {
        id: breathingContainer
        width: root.unscaledWidth
        height: root.unscaledHeight
        
        readonly property real centerX: (root.width - breathingContainer.width) / 2
        readonly property real centerY: (root.height - breathingContainer.height) / 2

        readonly property real openX: isHorizontal ? centerX : (pos === "right" ? (root.width - breathingContainer.width) : 0)
        readonly property real openY: !isHorizontal ? centerY : (pos === "bottom" ? (root.height - breathingContainer.height) : 0)

        readonly property real closedX: pos === "left" ? -breathingContainer.width : (pos === "right" ? root.width : openX)
        readonly property real closedY: pos === "top" ? -breathingContainer.height : (pos === "bottom" ? root.height : openY)

        transformOrigin: {
            if (pos === "bottom") return Item.Bottom
            if (pos === "left") return Item.Left
            if (pos === "right") return Item.Right
            return Item.Top
        }

        states: [
            State {
                name: "open"
                when: root.shouldShow
                PropertyChanges { 
                    target: breathingContainer 
                    x: breathingContainer.openX 
                    y: breathingContainer.openY
                    scale: 1.0 
                }
            },
            State {
                name: "closed"
                when: !root.shouldShow
                PropertyChanges { 
                    target: breathingContainer 
                    x: breathingContainer.closedX
                    y: breathingContainer.closedY
                    scale: 0.75 
                }
            }
        ]

        transitions: [
            Transition {
                id: openTransition
                from: "closed"; to: "open"
                ParallelAnimation {
                    NumberAnimation { properties: "x,y"; duration: 450; easing.type: Easing.OutQuart }
                    NumberAnimation { properties: "scale"; duration: 600; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                }
            },
            Transition {
                id: closeTransition
                from: "open"; to: "closed"
                ParallelAnimation {
                    NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.InCubic }
                    NumberAnimation { properties: "scale"; duration: 400; easing.type: Easing.InQuad }
                }
            }
        ]

        // VECTOR SHAPE CONTAINER
        Item {
            id: shapeContainer
            anchors.fill: parent

            // TOP BAR SHAPE
            Shape {
                id: shapeTop
                anchors.fill: parent
                visible: root.pos === "top"
                layer.enabled: true
                layer.samples: 4
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#D0000000"
                    shadowBlur: 0.7
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }

                ShapePath {
                    strokeWidth: 0; strokeColor: "transparent"; fillColor: Config.bgPanel
                    startX: root.wingInset; startY: 0

                    PathCubic { 
                        x: root.wingInset + root.wingWidth; y: root.wingDepth
                        control1X: root.wingInset + (root.wingWidth * 0.5); control1Y: 0
                        control2X: root.wingInset + root.wingWidth; control2Y: root.wingDepth * 0.5
                    }
                    PathLine { x: root.wingInset + root.wingWidth; y: shapeTop.height - root.drawerRadius - 12 }
                    PathArc { x: root.wingInset + root.wingWidth + root.drawerRadius; y: shapeTop.height - 12; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Counterclockwise }
                    PathLine { x: shapeTop.width - root.wingInset - root.wingWidth - root.drawerRadius; y: shapeTop.height - 12 }
                    PathArc { x: shapeTop.width - root.wingInset - root.wingWidth; y: shapeTop.height - root.drawerRadius - 12; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Counterclockwise }
                    PathLine { x: shapeTop.width - root.wingInset - root.wingWidth; y: root.wingDepth }
                    PathCubic {
                        x: shapeTop.width - root.wingInset; y: 0
                        control1X: shapeTop.width - root.wingInset - root.wingWidth; control1Y: root.wingDepth * 0.5
                        control2X: shapeTop.width - root.wingInset - (root.wingWidth * 0.5); control2Y: 0
                    }
                    PathLine { x: root.wingInset; y: 0 }
                }

                ShapePath {
                    strokeWidth: Config.showBorders ? 3 : 0; strokeColor: root.activeBorderColor; fillColor: "transparent"
                    capStyle: ShapePath.FlatCap; joinStyle: ShapePath.RoundJoin
                    startX: root.wingInset; startY: 0

                    PathCubic { 
                        x: root.wingInset + root.wingWidth; y: root.wingDepth
                        control1X: root.wingInset + (root.wingWidth * 0.5); control1Y: 0
                        control2X: root.wingInset + root.wingWidth; control2Y: root.wingDepth * 0.5
                    }
                    PathLine { x: root.wingInset + root.wingWidth; y: shapeTop.height - root.drawerRadius - 12 }
                    PathArc { x: root.wingInset + root.wingWidth + root.drawerRadius; y: shapeTop.height - 12; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Counterclockwise }
                    PathLine { x: shapeTop.width - root.wingInset - root.wingWidth - root.drawerRadius; y: shapeTop.height - 12 }
                    PathArc { x: shapeTop.width - root.wingInset - root.wingWidth; y: shapeTop.height - root.drawerRadius - 12; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Counterclockwise }
                    PathLine { x: shapeTop.width - root.wingInset - root.wingWidth; y: root.wingDepth }
                    PathCubic {
                        x: shapeTop.width - root.wingInset; y: 0
                        control1X: shapeTop.width - root.wingInset - root.wingWidth; control1Y: root.wingDepth * 0.5
                        control2X: shapeTop.width - root.wingInset - (root.wingWidth * 0.5); control2Y: 0
                    }
                }
            }

            // BOTTOM BAR SHAPE
            Shape {
                id: shapeBottom
                anchors.fill: parent
                visible: root.pos === "bottom"
                layer.enabled: true
                layer.samples: 4
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#D0000000"
                    shadowBlur: 0.7
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }

                ShapePath {
                    strokeWidth: 0; strokeColor: "transparent"; fillColor: Config.bgPanel
                    startX: root.wingInset; startY: shapeBottom.height
                    PathCubic {
                        x: root.wingInset + root.wingWidth; y: shapeBottom.height - root.wingDepth
                        control1X: root.wingInset + (root.wingWidth * 0.5); control1Y: shapeBottom.height
                        control2X: root.wingInset + root.wingWidth; control2Y: shapeBottom.height - (root.wingDepth * 0.5)
                    }
                    PathLine { x: root.wingInset + root.wingWidth; y: root.drawerRadius + 12 }
                    PathArc { x: root.wingInset + root.wingWidth + root.drawerRadius; y: 12; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Clockwise }
                    PathLine { x: shapeBottom.width - root.wingInset - root.wingWidth - root.drawerRadius; y: 12 }
                    PathArc { x: shapeBottom.width - root.wingInset - root.wingWidth; y: root.drawerRadius + 12; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Clockwise }
                    PathLine { x: shapeBottom.width - root.wingInset - root.wingWidth; y: shapeBottom.height - root.wingDepth }
                    PathCubic {
                        x: shapeBottom.width - root.wingInset; y: shapeBottom.height
                        control1X: shapeBottom.width - root.wingInset - root.wingWidth; control1Y: shapeBottom.height - (root.wingDepth * 0.5)
                        control2X: shapeBottom.width - root.wingInset - (root.wingWidth * 0.5); control2Y: shapeBottom.height
                    }
                    PathLine { x: root.wingInset; y: shapeBottom.height }
                }

                ShapePath {
                    strokeWidth: Config.showBorders ? 3 : 0; strokeColor: root.activeBorderColor; fillColor: "transparent"
                    capStyle: ShapePath.FlatCap; joinStyle: ShapePath.RoundJoin
                    startX: root.wingInset; startY: shapeBottom.height
                    PathCubic {
                        x: root.wingInset + root.wingWidth; y: shapeBottom.height - root.wingDepth
                        control1X: root.wingInset + (root.wingWidth * 0.5); control1Y: shapeBottom.height
                        control2X: root.wingInset + root.wingWidth; control2Y: shapeBottom.height - (root.wingDepth * 0.5)
                    }
                    PathLine { x: root.wingInset + root.wingWidth; y: root.drawerRadius + 12 }
                    PathArc { x: root.wingInset + root.wingWidth + root.drawerRadius; y: 12; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Clockwise }
                    PathLine { x: shapeBottom.width - root.wingInset - root.wingWidth - root.drawerRadius; y: 12 }
                    PathArc { x: shapeBottom.width - root.wingInset - root.wingWidth; y: root.drawerRadius + 12; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Clockwise }
                    PathLine { x: shapeBottom.width - root.wingInset - root.wingWidth; y: shapeBottom.height - root.wingDepth }
                    PathCubic {
                        x: shapeBottom.width - root.wingInset; y: shapeBottom.height
                        control1X: shapeBottom.width - root.wingInset - root.wingWidth; control1Y: shapeBottom.height - (root.wingDepth * 0.5)
                        control2X: shapeBottom.width - root.wingInset - (root.wingWidth * 0.5); control2Y: shapeBottom.height
                    }
                }
            }

            // LEFT BAR SHAPE
            Shape {
                id: shapeLeft
                anchors.fill: parent
                visible: root.pos === "left"
                layer.enabled: true
                layer.samples: 4
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#D0000000"
                    shadowBlur: 0.7
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }

                ShapePath {
                    strokeWidth: 0; strokeColor: "transparent"; fillColor: Config.bgPanel
                    startX: 0; startY: shapeLeft.height - root.wingInset

                    PathCubic {
                        x: root.wingDepth; y: shapeLeft.height - root.wingInset - root.wingWidth
                        control1X: 0; control1Y: shapeLeft.height - root.wingInset - (root.wingWidth * 0.5)
                        control2X: root.wingDepth * 0.5; control2Y: shapeLeft.height - root.wingInset - root.wingWidth
                    }
                    PathLine { x: shapeLeft.width - root.drawerRadius - 12; y: shapeLeft.height - root.wingInset - root.wingWidth }
                    PathArc { x: shapeLeft.width - 12; y: shapeLeft.height - root.wingInset - root.wingWidth - root.drawerRadius; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Counterclockwise }
                    PathLine { x: shapeLeft.width - 12; y: root.wingInset + root.wingWidth + root.drawerRadius }
                    PathArc { x: shapeLeft.width - root.drawerRadius - 12; y: root.wingInset + root.wingWidth; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Counterclockwise }
                    PathLine { x: root.wingDepth; y: root.wingInset + root.wingWidth }
                    PathCubic {
                        x: 0; y: root.wingInset
                        control1X: root.wingDepth * 0.5; control1Y: root.wingInset + root.wingWidth
                        control2X: 0; control2Y: root.wingInset + (root.wingWidth * 0.5)
                    }
                    PathLine { x: 0; y: shapeLeft.height - root.wingInset }
                }

                ShapePath {
                    strokeWidth: Config.showBorders ? 3 : 0; strokeColor: root.activeBorderColor; fillColor: "transparent"
                    capStyle: ShapePath.FlatCap; joinStyle: ShapePath.RoundJoin
                    startX: 0; startY: shapeLeft.height - root.wingInset

                    PathCubic {
                        x: root.wingDepth; y: shapeLeft.height - root.wingInset - root.wingWidth
                        control1X: 0; control1Y: shapeLeft.height - root.wingInset - (root.wingWidth * 0.5)
                        control2X: root.wingDepth * 0.5; control2Y: shapeLeft.height - root.wingInset - root.wingWidth
                    }
                    PathLine { x: shapeLeft.width - root.drawerRadius - 12; y: shapeLeft.height - root.wingInset - root.wingWidth }
                    PathArc { x: shapeLeft.width - 12; y: shapeLeft.height - root.wingInset - root.wingWidth - root.drawerRadius; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Counterclockwise }
                    PathLine { x: shapeLeft.width - 12; y: root.wingInset + root.wingWidth + root.drawerRadius }
                    PathArc { x: shapeLeft.width - root.drawerRadius - 12; y: root.wingInset + root.wingWidth; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Counterclockwise }
                    PathLine { x: root.wingDepth; y: root.wingInset + root.wingWidth }
                    PathCubic {
                        x: 0; y: root.wingInset
                        control1X: root.wingDepth * 0.5; control1Y: root.wingInset + root.wingWidth
                        control2X: 0; control2Y: root.wingInset + (root.wingWidth * 0.5)
                    }
                }
            }

            // RIGHT BAR SHAPE
            Shape {
                id: shapeRight
                anchors.fill: parent
                visible: root.pos === "right"
                layer.enabled: true
                layer.samples: 4
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#D0000000"
                    shadowBlur: 0.7
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }

                ShapePath {
                    strokeWidth: 0; strokeColor: "transparent"; fillColor: Config.bgPanel
                    startX: shapeRight.width; startY: shapeRight.height - root.wingInset

                    PathCubic {
                        x: shapeRight.width - root.wingDepth; y: shapeRight.height - root.wingInset - root.wingWidth
                        control1X: shapeRight.width; control1Y: shapeRight.height - root.wingInset - (root.wingWidth * 0.5)
                        control2X: shapeRight.width - (root.wingDepth * 0.5); control2Y: shapeRight.height - root.wingInset - root.wingWidth
                    }
                    PathLine { x: root.drawerRadius + 12; y: shapeRight.height - root.wingInset - root.wingWidth }
                    PathArc { x: 12; y: shapeRight.height - root.wingInset - root.wingWidth - root.drawerRadius; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Clockwise }
                    PathLine { x: 12; y: root.wingInset + root.wingWidth + root.drawerRadius }
                    PathArc { x: root.drawerRadius + 12; y: root.wingInset + root.wingWidth; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Clockwise }
                    PathLine { x: shapeRight.width - root.wingDepth; y: root.wingInset + root.wingWidth }
                    PathCubic {
                        x: shapeRight.width; y: root.wingInset
                        control1X: shapeRight.width - (root.wingDepth * 0.5); control1Y: root.wingInset + root.wingWidth
                        control2X: shapeRight.width; control2Y: root.wingInset + (root.wingWidth * 0.5)
                    }
                    PathLine { x: shapeRight.width; y: shapeRight.height - root.wingInset }
                }

                ShapePath {
                    strokeWidth: Config.showBorders ? 3 : 0; strokeColor: root.activeBorderColor; fillColor: "transparent"
                    capStyle: ShapePath.FlatCap; joinStyle: ShapePath.RoundJoin
                    startX: shapeRight.width; startY: shapeRight.height - root.wingInset

                    PathCubic {
                        x: shapeRight.width - root.wingDepth; y: shapeRight.height - root.wingInset - root.wingWidth
                        control1X: shapeRight.width; control1Y: shapeRight.height - root.wingInset - (root.wingWidth * 0.5)
                        control2X: shapeRight.width - (root.wingDepth * 0.5); control2Y: shapeRight.height - root.wingInset - root.wingWidth
                    }
                    PathLine { x: root.drawerRadius + 12; y: shapeRight.height - root.wingInset - root.wingWidth }
                    PathArc { x: 12; y: shapeRight.height - root.wingInset - root.wingWidth - root.drawerRadius; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Clockwise }
                    PathLine { x: 12; y: root.wingInset + root.wingWidth + root.drawerRadius }
                    PathArc { x: root.drawerRadius + 12; y: root.wingInset + root.wingWidth; radiusX: root.drawerRadius; radiusY: root.drawerRadius; direction: PathArc.Clockwise }
                    PathLine { x: shapeRight.width - root.wingDepth; y: root.wingInset + root.wingWidth }
                    PathCubic {
                        x: shapeRight.width; y: root.wingInset
                        control1X: shapeRight.width - (root.wingDepth * 0.5); control1Y: root.wingInset + root.wingWidth
                        control2X: shapeRight.width; control2Y: root.wingInset + (root.wingWidth * 0.5)
                    }
                }
            }
        }

        Item {
            id: contentContainer
            x: root.isHorizontal 
                ? (root.wingInset + root.wingWidth)
                : 12

            y: root.isHorizontal 
                ? 12 
                : (root.wingInset + root.wingWidth)
            
            width: root.visualPanelWidth
            height: root.visualPanelHeight
            clip: true 
        }
    }
}