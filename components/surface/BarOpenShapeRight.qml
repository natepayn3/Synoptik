import ".."
import QtQuick
import QtQuick.Shapes

Shape {
    id: openShapeRightFloating

    required property var panelRoot
    required property Item panelCanvas
    readonly property real rX: panelCanvas.width - panelRoot.barH

    anchors.fill: parent
    visible: panelRoot.barPosition === "right" && !panelRoot.isScreenFrame && (panelRoot.progress > 0 || panelRoot.isPeeking)

    ShapePath {
        fillColor: Config.bgPanel
        strokeWidth: panelRoot.borderWidth
        strokeColor: shellRoot.currentBorderColor
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap
        startX: openShapeRightFloating.rX + panelRoot.halfB + (panelRoot.isLeftFlush ? 0 : panelRoot.barRadius)
        startY: panelRoot.islandBarT

        PathLine {
            x: panelCanvas.width - panelRoot.halfB - panelRoot.barRadius
            y: panelRoot.islandBarT
        }

        PathArc {
            x: panelCanvas.width - panelRoot.halfB
            y: panelRoot.islandBarT + panelRoot.barRadius
            radiusX: panelRoot.barRadius
            radiusY: panelRoot.barRadius
            direction: PathArc.Clockwise
        }

        PathLine {
            x: panelCanvas.width - panelRoot.halfB
            y: panelRoot.islandBarB - panelRoot.barRadius
        }

        PathArc {
            x: panelCanvas.width - panelRoot.halfB - panelRoot.barRadius
            y: panelRoot.islandBarB
            radiusX: panelRoot.barRadius
            radiusY: panelRoot.barRadius
            direction: PathArc.Clockwise
        }

        // Bottom edge transition into outer popup boundary
        PathLine {
            x: panelRoot.isRightFlush ? (openShapeRightFloating.rX + panelRoot.halfB - panelRoot.currentWidth + panelRoot.radius) : (openShapeRightFloating.rX + panelRoot.halfB + panelRoot.barRadius)
            y: panelRoot.islandBarB
        }

        PathArc {
            x: panelRoot.isRightFlush ? (openShapeRightFloating.rX + panelRoot.halfB - panelRoot.currentWidth) : (openShapeRightFloating.rX + panelRoot.halfB)
            y: panelRoot.isRightFlush ? (panelRoot.islandBarB - panelRoot.radius) : (panelRoot.islandBarB - panelRoot.barRadius)
            radiusX: panelRoot.isRightFlush ? Math.max(0.1, panelRoot.radius) : panelRoot.barRadius
            radiusY: panelRoot.isRightFlush ? Math.max(0.1, panelRoot.radius) : panelRoot.barRadius
            direction: PathArc.Clockwise
        }

        // Bottom wing curve into popout
        PathLine {
            x: panelRoot.isRightFlush ? (openShapeRightFloating.rX + panelRoot.halfB - panelRoot.currentWidth) : (openShapeRightFloating.rX + panelRoot.halfB)
            y: panelRoot.isRightFlush ? (panelRoot.isLeftFlush ? (panelRoot.islandBarT + panelRoot.radius) : (panelRoot.pLeft + panelRoot.radius)) : (panelRoot.pRight + panelRoot.wingW)
        }

        PathCubic {
            x: panelRoot.isRightFlush ? (openShapeRightFloating.rX + panelRoot.halfB - panelRoot.currentWidth) : (openShapeRightFloating.rX + panelRoot.halfB - panelRoot.wingW)
            y: panelRoot.isRightFlush ? (panelRoot.islandBarB - panelRoot.radius) : panelRoot.pRight
            control1X: panelRoot.isRightFlush ? (openShapeRightFloating.rX + panelRoot.halfB - panelRoot.currentWidth) : (openShapeRightFloating.rX + panelRoot.halfB)
            control1Y: panelRoot.isRightFlush ? (panelRoot.islandBarB - panelRoot.radius) : (panelRoot.pRight + (panelRoot.wingW * 0.5))
            control2X: panelRoot.isRightFlush ? (openShapeRightFloating.rX + panelRoot.halfB - panelRoot.currentWidth) : (openShapeRightFloating.rX + panelRoot.halfB - (panelRoot.wingW * 0.5))
            control2Y: panelRoot.isRightFlush ? (panelRoot.islandBarB - panelRoot.radius) : panelRoot.pRight
        }

        // Popout outer edge & corners
        PathLine {
            x: panelRoot.isRightFlush ? (openShapeRightFloating.rX + panelRoot.halfB - panelRoot.currentWidth) : (openShapeRightFloating.rX + panelRoot.halfB - panelRoot.currentWidth + panelRoot.radius)
            y: panelRoot.isRightFlush ? (panelRoot.islandBarB - panelRoot.radius) : panelRoot.pRight
        }

        PathArc {
            x: openShapeRightFloating.rX + panelRoot.halfB - panelRoot.currentWidth
            y: panelRoot.isRightFlush ? (panelRoot.islandBarB - panelRoot.radius) : (panelRoot.pRight - panelRoot.radius)
            radiusX: panelRoot.isRightFlush ? 0 : Math.max(0.1, panelRoot.radius)
            radiusY: panelRoot.isRightFlush ? 0 : Math.max(0.1, panelRoot.radius)
            direction: PathArc.Clockwise
        }

        PathLine {
            x: openShapeRightFloating.rX + panelRoot.halfB - panelRoot.currentWidth
            y: panelRoot.isLeftFlush ? (panelRoot.islandBarT + panelRoot.radius) : (panelRoot.pLeft + panelRoot.radius)
        }

        PathArc {
            x: openShapeRightFloating.rX + panelRoot.halfB - panelRoot.currentWidth + panelRoot.radius
            y: panelRoot.isLeftFlush ? panelRoot.islandBarT : panelRoot.pLeft
            radiusX: Math.max(0.1, panelRoot.radius)
            radiusY: Math.max(0.1, panelRoot.radius)
            direction: PathArc.Clockwise
        }

        // Top wing curve return to bar
        PathLine {
            x: panelRoot.isLeftFlush ? (panelCanvas.width - panelRoot.halfB - panelRoot.barRadius) : (openShapeRightFloating.rX + panelRoot.halfB - panelRoot.wingW)
            y: panelRoot.isLeftFlush ? panelRoot.islandBarT : panelRoot.pLeft
        }

        PathCubic {
            x: panelRoot.isLeftFlush ? (panelCanvas.width - panelRoot.halfB - panelRoot.barRadius) : (openShapeRightFloating.rX + panelRoot.halfB)
            y: panelRoot.isLeftFlush ? panelRoot.islandBarT : (panelRoot.pLeft - panelRoot.wingW)
            control1X: panelRoot.isLeftFlush ? (panelCanvas.width - panelRoot.halfB - panelRoot.barRadius) : (openShapeRightFloating.rX + panelRoot.halfB - (panelRoot.wingW * 0.5))
            control1Y: panelRoot.isLeftFlush ? panelRoot.islandBarT : panelRoot.pLeft
            control2X: panelRoot.isLeftFlush ? (panelCanvas.width - panelRoot.halfB - panelRoot.barRadius) : (openShapeRightFloating.rX + panelRoot.halfB)
            control2Y: panelRoot.isLeftFlush ? panelRoot.islandBarT : (panelRoot.pLeft - (panelRoot.wingW * 0.5))
        }

        PathLine {
            x: panelRoot.isLeftFlush ? (panelCanvas.width - panelRoot.halfB - panelRoot.barRadius) : (openShapeRightFloating.rX + panelRoot.halfB)
            y: panelRoot.isLeftFlush ? panelRoot.islandBarT : (panelRoot.islandBarT + panelRoot.barRadius)
        }

        PathArc {
            x: panelRoot.isLeftFlush ? (panelCanvas.width - panelRoot.halfB - panelRoot.barRadius) : (openShapeRightFloating.rX + panelRoot.halfB + panelRoot.barRadius)
            y: panelRoot.islandBarT
            radiusX: panelRoot.isLeftFlush ? 0 : panelRoot.barRadius
            radiusY: panelRoot.isLeftFlush ? 0 : panelRoot.barRadius
            direction: PathArc.Clockwise
        }

    }

}
