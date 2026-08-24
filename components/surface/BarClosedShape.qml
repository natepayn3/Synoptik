import ".."
import QtQuick
import QtQuick.Shapes

Shape {
    id: closedShape

    required property var panelRoot
    required property Item panelCanvas
    readonly property real bX: (panelRoot.isIsland ? (panelRoot.isHorizontal ? panelRoot.islandX : (panelRoot.isRight ? (panelCanvas.width - panelRoot.barH + panelRoot.halfB) : panelRoot.halfB)) : (panelRoot.isRight ? (panelCanvas.width - panelRoot.barH + panelRoot.halfB) : panelRoot.halfB)) + panelRoot.autoHideXOffset
    readonly property real bY: (panelRoot.isIsland ? (panelRoot.isHorizontal ? (panelRoot.isBottom ? (panelCanvas.height - panelRoot.barH + panelRoot.halfB) : panelRoot.halfB) : panelRoot.islandY) : (panelRoot.isBottom ? (panelCanvas.height - panelRoot.barH + panelRoot.halfB) : panelRoot.halfB)) + panelRoot.autoHideYOffset
    readonly property real bW: (panelRoot.isIsland ? (panelRoot.isHorizontal ? (panelRoot.islandX + panelRoot.animatedIslandWidth) : (panelRoot.isRight ? (panelCanvas.width - panelRoot.halfB) : (panelRoot.barH - panelRoot.halfB))) : (panelRoot.isHorizontal ? (panelCanvas.width - panelRoot.halfB) : (panelRoot.isRight ? (panelCanvas.width - panelRoot.halfB) : (panelRoot.barH - panelRoot.halfB)))) + panelRoot.autoHideXOffset
    readonly property real bH: (panelRoot.isIsland ? (panelRoot.isHorizontal ? (panelRoot.isBottom ? (panelCanvas.height - panelRoot.halfB) : (panelRoot.barH - panelRoot.halfB)) : (panelRoot.islandY + panelRoot.animatedIslandHeight)) : (panelRoot.isHorizontal ? (panelRoot.isBottom ? (panelCanvas.height - panelRoot.halfB) : (panelRoot.barH - panelRoot.halfB)) : (panelCanvas.height - panelRoot.halfB))) + panelRoot.autoHideYOffset

    anchors.fill: parent
    visible: panelRoot.progress <= 0.005 && !panelRoot.isPeeking && !panelRoot.isScreenFrame

    ShapePath {
        fillColor: Config.bgPanel
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
