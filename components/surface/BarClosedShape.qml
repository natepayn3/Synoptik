import ".."
import QtQuick
import QtQuick.Shapes

Shape {
    id: closedShape

    required property var panelRoot
    required property Item panelCanvas

    // Material fill: a slow-drifting radial highlight instead of one flat
    // color, so the pill reads as painted rather than a tinted pane of glass.
    // Drift is a plain 0..1 ping-pong - not tied to any interaction - so the
    // panel is quietly alive even when nothing else is happening.
    property real materialDrift: 0.0
    SequentialAnimation on materialDrift {
        running: true
        loops: Animation.Infinite
        NumberAnimation { to: 1.0; duration: 15000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.0; duration: 15000; easing.type: Easing.InOutSine }
    }
    readonly property real bX: (panelRoot.isIsland ? (panelRoot.isHorizontal ? panelRoot.islandX : (panelRoot.isRight ? (panelCanvas.width - panelRoot.barH + panelRoot.halfB) : panelRoot.halfB)) : (panelRoot.isRight ? (panelCanvas.width - panelRoot.barH + panelRoot.halfB) : panelRoot.halfB)) + panelRoot.autoHideXOffset
    readonly property real bY: (panelRoot.isIsland ? (panelRoot.isHorizontal ? (panelRoot.isBottom ? (panelCanvas.height - panelRoot.barH + panelRoot.halfB) : panelRoot.halfB) : panelRoot.islandY) : (panelRoot.isBottom ? (panelCanvas.height - panelRoot.barH + panelRoot.halfB) : panelRoot.halfB)) + panelRoot.autoHideYOffset
    readonly property real bW: (panelRoot.isIsland ? (panelRoot.isHorizontal ? (panelRoot.islandX + panelRoot.animatedIslandWidth) : (panelRoot.isRight ? (panelCanvas.width - panelRoot.halfB) : (panelRoot.barH - panelRoot.halfB))) : (panelRoot.isHorizontal ? (panelCanvas.width - panelRoot.halfB) : (panelRoot.isRight ? (panelCanvas.width - panelRoot.halfB) : (panelRoot.barH - panelRoot.halfB)))) + panelRoot.autoHideXOffset
    readonly property real bH: (panelRoot.isIsland ? (panelRoot.isHorizontal ? (panelRoot.isBottom ? (panelCanvas.height - panelRoot.halfB) : (panelRoot.barH - panelRoot.halfB)) : (panelRoot.islandY + panelRoot.animatedIslandHeight)) : (panelRoot.isHorizontal ? (panelRoot.isBottom ? (panelCanvas.height - panelRoot.halfB) : (panelRoot.barH - panelRoot.halfB)) : (panelCanvas.height - panelRoot.halfB))) + panelRoot.autoHideYOffset

    anchors.fill: parent
    visible: panelRoot.progress <= 0.005 && !panelRoot.isPeeking && !panelRoot.isScreenFrame

    // This Shape fills the whole screen (anchors.fill: parent), so the default
    // center-origin scale would pivot on the monitor's center, not the bar -
    // pin the origin to the bar rectangle's own center instead.
    transform: Scale {
        origin.x: closedShape.bX + (closedShape.bW - closedShape.bX) / 2
        origin.y: closedShape.bY + (closedShape.bH - closedShape.bY) / 2
        xScale: typeof shellRoot !== "undefined" ? shellRoot.throbScale : 1.0
        yScale: typeof shellRoot !== "undefined" ? shellRoot.throbScale : 1.0
    }

    ShapePath {
        fillGradient: RadialGradient {
            centerX: closedShape.bX + (closedShape.bW - closedShape.bX) * (0.3 + closedShape.materialDrift * 0.4)
            centerY: closedShape.bY + (closedShape.bH - closedShape.bY) * 0.5
            centerRadius: Math.max(closedShape.bW - closedShape.bX, closedShape.bH - closedShape.bY) * 1.1
            focalX: centerX
            focalY: centerY
            GradientStop { position: 0.0; color: Qt.tint(Config.bgPanel, Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.16)) }
            GradientStop { position: 0.6; color: Config.bgPanel }
            GradientStop { position: 1.0; color: Qt.darker(Config.bgPanel, 1.12) }
        }
        strokeWidth: panelRoot.borderWidth
        strokeColor: shellRoot.currentBorderColor
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap
        startX: closedShape.bX + panelRoot.barRadius
        startY: closedShape.bY

        PathLine {
            x: closedShape.bW - panelRoot.barRadius
            y: closedShape.bY
        }

        PathArc {
            x: closedShape.bW
            y: closedShape.bY + panelRoot.barRadius
            radiusX: panelRoot.barRadius
            radiusY: panelRoot.barRadius
            direction: PathArc.Clockwise
        }

        PathLine {
            x: closedShape.bW
            y: closedShape.bH - panelRoot.barRadius
        }

        PathArc {
            x: closedShape.bW - panelRoot.barRadius
            y: closedShape.bH
            radiusX: panelRoot.barRadius
            radiusY: panelRoot.barRadius
            direction: PathArc.Clockwise
        }

        PathLine {
            x: closedShape.bX + panelRoot.barRadius
            y: closedShape.bH
        }

        PathArc {
            x: closedShape.bX
            y: closedShape.bH - panelRoot.barRadius
            radiusX: panelRoot.barRadius
            radiusY: panelRoot.barRadius
            direction: PathArc.Clockwise
        }

        PathLine {
            x: closedShape.bX
            y: closedShape.bY + panelRoot.barRadius
        }

        PathArc {
            x: closedShape.bX + panelRoot.barRadius
            y: closedShape.bY
            radiusX: panelRoot.barRadius
            radiusY: panelRoot.barRadius
            direction: PathArc.Clockwise
        }

    }

}
