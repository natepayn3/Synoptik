import ".."
import QtQuick
import QtQuick.Shapes

Item {
    id: sfClosedGroup

    required property var panelRoot
    required property Item panelCanvas

    anchors.fill: parent
    visible: panelRoot.progress === 0 && !panelRoot.isPeeking && panelRoot.isScreenFrame

    Rectangle {
        x: 0
        y: 0
        width: panelCanvas.width
        height: panelRoot.inY
        color: Config.bgPanel
    }

    Rectangle {
        x: 0
        y: panelRoot.inY + panelRoot.inH
        width: panelCanvas.width
        height: panelCanvas.height - (panelRoot.inY + panelRoot.inH)
        color: Config.bgPanel
    }

    Rectangle {
        x: 0
        y: panelRoot.inY
        width: panelRoot.inX
        height: panelRoot.inH
        color: Config.bgPanel
    }

    Rectangle {
        x: panelRoot.inX + panelRoot.inW
        y: panelRoot.inY
        width: panelCanvas.width - (panelRoot.inX + panelRoot.inW)
        height: panelRoot.inH
        color: Config.bgPanel
    }

    ScreenFrameCorners {
        anchors.fill: parent
        surfaceRoot: panelRoot
    }

    Shape {
        anchors.fill: parent

        ShapePath {
            fillColor: "transparent"
            strokeWidth: panelRoot.borderWidth
            strokeColor: shellRoot.currentBorderColor
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            startX: panelRoot.inX + panelRoot.inRadi
            startY: panelRoot.inY + panelRoot.halfB

            PathLine {
                x: panelRoot.inX + panelRoot.inW - panelRoot.inRadi
                y: panelRoot.inY + panelRoot.halfB
            }

            PathArc {
                x: panelRoot.inX + panelRoot.inW - panelRoot.halfB
                y: panelRoot.inY + panelRoot.inRadi
                radiusX: panelRoot.inRadi
                radiusY: panelRoot.inRadi
                direction: PathArc.Clockwise
            }

            PathLine {
                x: panelRoot.inX + panelRoot.inW - panelRoot.halfB
                y: panelRoot.inY + panelRoot.inH - panelRoot.inRadi
            }

            PathArc {
                x: panelRoot.inX + panelRoot.inW - panelRoot.inRadi
                y: panelRoot.inY + panelRoot.inH - panelRoot.halfB
                radiusX: panelRoot.inRadi
                radiusY: panelRoot.inRadi
                direction: PathArc.Clockwise
            }

            PathLine {
                x: panelRoot.inX + panelRoot.inRadi
                y: panelRoot.inY + panelRoot.inH - panelRoot.halfB
            }

            PathArc {
                x: panelRoot.inX + panelRoot.halfB
                y: panelRoot.inY + panelRoot.inH - panelRoot.inRadi
                radiusX: panelRoot.inRadi
                radiusY: panelRoot.inRadi
                direction: PathArc.Clockwise
            }

            PathLine {
                x: panelRoot.inX + panelRoot.halfB
                y: panelRoot.inY + panelRoot.inRadi
            }

            PathArc {
                x: panelRoot.inX + panelRoot.inRadi
                y: panelRoot.inY + panelRoot.halfB
                radiusX: panelRoot.inRadi
                radiusY: panelRoot.inRadi
                direction: PathArc.Clockwise
            }

        }

    }

}
