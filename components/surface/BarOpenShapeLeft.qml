import ".."
import QtQuick
import QtQuick.Shapes

Shape {
    id: openShapeLeftFloating

    required property var panelRoot

    anchors.fill: parent
    visible: panelRoot.barPosition === "left" && !panelRoot.isScreenFrame && (panelRoot.progress > 0 || panelRoot.isPeeking)

    ShapePath {
        fillColor: Config.bgPanel
        strokeWidth: panelRoot.borderWidth
        strokeColor: shellRoot.currentBorderColor
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap
        startX: panelRoot.halfB + panelRoot.barRadius
        startY: panelRoot.islandBarT

        // Top horizontal segment towards popup/bar outer edge
        PathLine {
            x: panelRoot.isLeftFlush ? (panelRoot.barH - panelRoot.halfB + panelRoot.currentWidth - panelRoot.radius) : (panelRoot.barH - panelRoot.halfB - panelRoot.barRadius)
            y: panelRoot.islandBarT
        }

        PathArc {
            x: panelRoot.isLeftFlush ? (panelRoot.barH - panelRoot.halfB + panelRoot.currentWidth) : (panelRoot.barH - panelRoot.halfB)
            y: panelRoot.isLeftFlush ? (panelRoot.islandBarT + panelRoot.radius) : (panelRoot.islandBarT + panelRoot.barRadius)
            radiusX: panelRoot.isLeftFlush ? Math.max(0.1, panelRoot.radius) : panelRoot.barRadius
            radiusY: panelRoot.isLeftFlush ? Math.max(0.1, panelRoot.radius) : panelRoot.barRadius
            direction: PathArc.Clockwise
        }

        // Upper wing transition into the popout
        PathLine {
            x: panelRoot.isLeftFlush ? (panelRoot.barH - panelRoot.halfB + panelRoot.currentWidth) : (panelRoot.barH - panelRoot.halfB)
            y: panelRoot.isLeftFlush ? (panelRoot.isRightFlush ? (panelRoot.islandBarB - panelRoot.radius) : (panelRoot.pRight - panelRoot.radius)) : (panelRoot.pLeft - panelRoot.wingW)
        }

        PathCubic {
            x: panelRoot.isLeftFlush ? (panelRoot.barH - panelRoot.halfB + panelRoot.currentWidth) : (panelRoot.barH - panelRoot.halfB + panelRoot.wingW)
            y: panelRoot.isLeftFlush ? (panelRoot.islandBarT + panelRoot.radius) : panelRoot.pLeft
            control1X: panelRoot.isLeftFlush ? (panelRoot.barH - panelRoot.halfB + panelRoot.currentWidth) : (panelRoot.barH - panelRoot.halfB)
            control1Y: panelRoot.isLeftFlush ? (panelRoot.islandBarT + panelRoot.radius) : (panelRoot.pLeft - (panelRoot.wingW * 0.5))
            control2X: panelRoot.isLeftFlush ? (panelRoot.barH - panelRoot.halfB + panelRoot.currentWidth) : (panelRoot.barH - panelRoot.halfB + (panelRoot.wingW * 0.5))
            control2Y: panelRoot.isLeftFlush ? (panelRoot.islandBarT + panelRoot.radius) : panelRoot.pLeft
        }

        // Popout outer top-right edge & curve
        PathLine {
            x: panelRoot.isLeftFlush ? (panelRoot.barH - panelRoot.halfB + panelRoot.currentWidth) : (panelRoot.barH - panelRoot.halfB + panelRoot.currentWidth - panelRoot.radius)
            y: panelRoot.isLeftFlush ? (panelRoot.islandBarT + panelRoot.radius) : panelRoot.pLeft
        }

        PathArc {
            x: panelRoot.barH - panelRoot.halfB + panelRoot.currentWidth
            y: panelRoot.isLeftFlush ? (panelRoot.islandBarT + panelRoot.radius) : (panelRoot.pLeft + panelRoot.radius)
            radiusX: panelRoot.isLeftFlush ? 0 : Math.max(0.1, panelRoot.radius)
            radiusY: panelRoot.isLeftFlush ? 0 : Math.max(0.1, panelRoot.radius)
            direction: PathArc.Clockwise
        }

        // Popout outer edge down to bottom-right corner
        PathLine {
            x: panelRoot.barH - panelRoot.halfB + panelRoot.currentWidth
            y: panelRoot.isRightFlush ? (panelRoot.islandBarB - panelRoot.radius) : (panelRoot.pRight - panelRoot.radius)
        }

        PathArc {
            x: panelRoot.barH - panelRoot.halfB + panelRoot.currentWidth - panelRoot.radius
            y: panelRoot.isRightFlush ? panelRoot.islandBarB : panelRoot.pRight
            radiusX: Math.max(0.1, panelRoot.radius)
            radiusY: Math.max(0.1, panelRoot.radius)
            direction: PathArc.Clockwise
        }

        // Lower wing transition back into the bar
        PathLine {
            x: panelRoot.isRightFlush ? (panelRoot.halfB + panelRoot.barRadius) : (panelRoot.barH - panelRoot.halfB + panelRoot.wingW)
            y: panelRoot.isRightFlush ? panelRoot.islandBarB : panelRoot.pRight
        }

        PathCubic {
            x: panelRoot.isRightFlush ? (panelRoot.halfB + panelRoot.barRadius) : (panelRoot.barH - panelRoot.halfB)
            y: panelRoot.isRightFlush ? panelRoot.islandBarB : (panelRoot.pRight + panelRoot.wingW)
            control1X: panelRoot.isRightFlush ? (panelRoot.halfB + panelRoot.barRadius) : (panelRoot.barH - panelRoot.halfB + (panelRoot.wingW * 0.5))
            control1Y: panelRoot.isRightFlush ? panelRoot.islandBarB : panelRoot.pRight
            control2X: panelRoot.isRightFlush ? (panelRoot.halfB + panelRoot.barRadius) : (panelRoot.barH - panelRoot.halfB)
            control2Y: panelRoot.isRightFlush ? panelRoot.islandBarB : (panelRoot.pRight + (panelRoot.wingW * 0.5))
        }

        // Bottom bar return line and inner corner arcs
        PathLine {
            x: panelRoot.isRightFlush ? (panelRoot.halfB + panelRoot.barRadius) : (panelRoot.barH - panelRoot.halfB)
            y: panelRoot.isRightFlush ? panelRoot.islandBarB : (panelRoot.islandBarB - panelRoot.barRadius)
        }

        PathArc {
            x: panelRoot.isRightFlush ? (panelRoot.halfB + panelRoot.barRadius) : (panelRoot.barH - panelRoot.halfB - panelRoot.barRadius)
            y: panelRoot.islandBarB
            radiusX: panelRoot.isRightFlush ? 0 : panelRoot.barRadius
            radiusY: panelRoot.isRightFlush ? 0 : panelRoot.barRadius
            direction: PathArc.Clockwise
        }

        PathLine {
            x: panelRoot.halfB + panelRoot.barRadius
            y: panelRoot.islandBarB
        }

        PathArc {
            x: panelRoot.halfB
            y: panelRoot.islandBarB - panelRoot.barRadius
            radiusX: panelRoot.barRadius
            radiusY: panelRoot.barRadius
            direction: PathArc.Clockwise
        }

        PathLine {
            x: panelRoot.halfB
            y: panelRoot.islandBarT + panelRoot.barRadius
        }

        PathArc {
            x: panelRoot.halfB + panelRoot.barRadius
            y: panelRoot.islandBarT
            radiusX: panelRoot.barRadius
            radiusY: panelRoot.barRadius
            direction: PathArc.Clockwise
        }

    }

}
