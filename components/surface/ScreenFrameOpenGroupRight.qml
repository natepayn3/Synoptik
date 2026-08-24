import ".."
import QtQuick
import QtQuick.Shapes

Item {
    id: sfOpenGroupRight

    required property var panelRoot
    required property Item panelCanvas

    anchors.fill: parent
    visible: panelRoot.barPosition === "right" && panelRoot.isScreenFrame && (panelRoot.progress > 0 || panelRoot.isPeeking)

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
        visible: !panelRoot.isLeftFlush && !panelRoot.isRightFlush && !(peekActive && panelRoot.isPeekLeftFlush) && !(peekActive && panelRoot.isPeekRightFlush)

        ShapePath {
            fillColor: Config.bgPanel
            strokeWidth: 0
            startX: panelRoot.inX + panelRoot.inW
            startY: panelRoot.pRight + panelRoot.wingW

            PathLine {
                x: panelRoot.inX + panelRoot.inW
                y: panelRoot.pLeft - panelRoot.wingW
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.inW - panelRoot.wingW
                y: panelRoot.pLeft
                control1X: panelRoot.inX + panelRoot.inW
                control1Y: panelRoot.pLeft - panelRoot.wingW * 0.5
                control2X: panelRoot.inX + panelRoot.inW - panelRoot.wingW * 0.5
                control2Y: panelRoot.pLeft
            }

            PathLine {
                x: panelRoot.rightBarPopL + panelRoot.radius
                y: panelRoot.pLeft
            }

            PathArc {
                x: panelRoot.rightBarPopL
                y: panelRoot.pLeft + panelRoot.radius
                radiusX: panelRoot.radius
                radiusY: panelRoot.radius
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.rightBarPopL
                y: panelRoot.pRight - panelRoot.radius
            }

            PathArc {
                x: panelRoot.rightBarPopL + panelRoot.radius
                y: panelRoot.pRight
                radiusX: panelRoot.radius
                radiusY: panelRoot.radius
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.inX + panelRoot.inW - panelRoot.wingW
                y: panelRoot.pRight
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.inW
                y: panelRoot.pRight + panelRoot.wingW
                control1X: panelRoot.inX + panelRoot.inW - panelRoot.wingW * 0.5
                control1Y: panelRoot.pRight
                control2X: panelRoot.inX + panelRoot.inW
                control2Y: panelRoot.pRight + panelRoot.wingW * 0.5
            }

        }

    }

    Shape {
        anchors.fill: parent
        visible: panelRoot.isLeftFlush || (peekActive && panelRoot.isPeekLeftFlush)

        ShapePath {
            fillColor: Config.bgPanel
            strokeWidth: 0
            startX: panelRoot.inX + panelRoot.inW
            startY: panelRoot.pRight + panelRoot.wingW

            PathLine {
                x: panelRoot.inX + panelRoot.inW
                y: panelRoot.inY
            }

            PathLine {
                x: panelRoot.rightBarPopL - panelRoot.wingW
                y: panelRoot.inY
            }

            PathCubic {
                x: panelRoot.rightBarPopL
                y: panelRoot.inY + panelRoot.wingW
                control1X: panelRoot.rightBarPopL - panelRoot.wingW * 0.5
                control1Y: panelRoot.inY
                control2X: panelRoot.rightBarPopL
                control2Y: panelRoot.inY + panelRoot.wingW * 0.5
            }

            PathLine {
                x: panelRoot.rightBarPopL
                y: panelRoot.pRight - panelRoot.radius
            }

            PathArc {
                x: panelRoot.rightBarPopL + panelRoot.radius
                y: panelRoot.pRight
                radiusX: panelRoot.radius
                radiusY: panelRoot.radius
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.inX + panelRoot.inW - panelRoot.wingW
                y: panelRoot.pRight
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.inW
                y: panelRoot.pRight + panelRoot.wingW
                control1X: panelRoot.inX + panelRoot.inW - panelRoot.wingW * 0.5
                control1Y: panelRoot.pRight
                control2X: panelRoot.inX + panelRoot.inW
                control2Y: panelRoot.pRight + panelRoot.wingW * 0.5
            }

        }

    }

    Shape {
        anchors.fill: parent
        visible: panelRoot.isRightFlush || (peekActive && panelRoot.isPeekRightFlush)

        ShapePath {
            fillColor: Config.bgPanel
            strokeWidth: 0
            startX: panelRoot.inX + panelRoot.inW
            startY: panelRoot.inY + panelRoot.inH

            PathLine {
                x: panelRoot.inX + panelRoot.inW
                y: panelRoot.pLeft - panelRoot.wingW
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.inW - panelRoot.wingW
                y: panelRoot.pLeft
                control1X: panelRoot.inX + panelRoot.inW
                control1Y: panelRoot.pLeft - panelRoot.wingW * 0.5
                control2X: panelRoot.inX + panelRoot.inW - panelRoot.wingW * 0.5
                control2Y: panelRoot.pLeft
            }

            PathLine {
                x: panelRoot.rightBarPopL + panelRoot.radius
                y: panelRoot.pLeft
            }

            PathArc {
                x: panelRoot.rightBarPopL
                y: panelRoot.pLeft + panelRoot.radius
                radiusX: Math.max(0.1, panelRoot.radius)
                radiusY: Math.max(0.1, panelRoot.radius)
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.rightBarPopL
                y: panelRoot.inY + panelRoot.inH - panelRoot.wingW
            }

            PathCubic {
                x: panelRoot.rightBarPopL - panelRoot.wingW
                y: panelRoot.inY + panelRoot.inH
                control1X: panelRoot.rightBarPopL
                control1Y: panelRoot.inY + panelRoot.inH - panelRoot.wingW * 0.5
                control2X: panelRoot.rightBarPopL - panelRoot.wingW * 0.5
                control2Y: panelRoot.inY + panelRoot.inH
            }

            PathLine {
                x: panelRoot.inX + panelRoot.inW
                y: panelRoot.inY + panelRoot.inH
            }

        }

    }

    Shape {
        anchors.fill: parent
        visible: !panelRoot.isLeftFlush && !panelRoot.isRightFlush && !(peekActive && panelRoot.isPeekLeftFlush) && !(peekActive && panelRoot.isPeekRightFlush)

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
                y: panelRoot.pLeft - panelRoot.wingW
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.inW - panelRoot.wingW
                y: panelRoot.pLeft
                control1X: panelRoot.inX + panelRoot.inW - panelRoot.halfB
                control1Y: panelRoot.pLeft - panelRoot.wingW * 0.5
                control2X: panelRoot.inX + panelRoot.inW - panelRoot.wingW * 0.5
                control2Y: panelRoot.pLeft
            }

            PathLine {
                x: panelRoot.rightBarPopL + panelRoot.radius
                y: panelRoot.pLeft
            }

            PathArc {
                x: panelRoot.rightBarPopL
                y: panelRoot.pLeft + panelRoot.radius
                radiusX: Math.max(0.1, panelRoot.radius)
                radiusY: Math.max(0.1, panelRoot.radius)
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.rightBarPopL
                y: panelRoot.pRight - panelRoot.radius
            }

            PathArc {
                x: panelRoot.rightBarPopL + panelRoot.radius
                y: panelRoot.pRight
                radiusX: Math.max(0.1, panelRoot.radius)
                radiusY: Math.max(0.1, panelRoot.radius)
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.inX + panelRoot.inW - panelRoot.wingW
                y: panelRoot.pRight
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.inW - panelRoot.halfB
                y: panelRoot.pRight + panelRoot.wingW
                control1X: panelRoot.inX + panelRoot.inW - panelRoot.wingW * 0.5
                control1Y: panelRoot.pRight
                control2X: panelRoot.inX + panelRoot.inW - panelRoot.halfB
                control2Y: panelRoot.pRight + panelRoot.wingW * 0.5
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

    Shape {
        anchors.fill: parent
        visible: panelRoot.isLeftFlush || (peekActive && panelRoot.isPeekLeftFlush)

        ShapePath {
            fillColor: "transparent"
            strokeWidth: panelRoot.borderWidth
            strokeColor: shellRoot.currentBorderColor
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            startX: panelRoot.inX + panelRoot.inRadi
            startY: panelRoot.inY + panelRoot.halfB

            PathLine {
                x: panelRoot.rightBarPopL - panelRoot.wingW
                y: panelRoot.inY + panelRoot.halfB
            }

            PathCubic {
                x: panelRoot.rightBarPopL
                y: panelRoot.inY + panelRoot.halfB + panelRoot.wingW
                control1X: panelRoot.rightBarPopL - panelRoot.wingW * 0.5
                control1Y: panelRoot.inY + panelRoot.halfB
                control2X: panelRoot.rightBarPopL
                control2Y: panelRoot.inY + panelRoot.halfB + panelRoot.wingW * 0.5
            }

            PathLine {
                x: panelRoot.rightBarPopL
                y: panelRoot.pRight - panelRoot.radius
            }

            PathArc {
                x: panelRoot.rightBarPopL + panelRoot.radius
                y: panelRoot.pRight
                radiusX: Math.max(0.1, panelRoot.radius)
                radiusY: Math.max(0.1, panelRoot.radius)
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.inX + panelRoot.inW - panelRoot.wingW
                y: panelRoot.pRight
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.inW - panelRoot.halfB
                y: panelRoot.pRight + panelRoot.wingW
                control1X: panelRoot.inX + panelRoot.inW - panelRoot.wingW * 0.5
                control1Y: panelRoot.pRight
                control2X: panelRoot.inX + panelRoot.inW - panelRoot.halfB
                control2Y: panelRoot.pRight + panelRoot.wingW * 0.5
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

    Shape {
        anchors.fill: parent
        visible: panelRoot.isRightFlush || (peekActive && panelRoot.isPeekRightFlush)

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
                y: panelRoot.pLeft - panelRoot.wingW
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.inW - panelRoot.halfB - panelRoot.wingW
                y: panelRoot.pLeft
                control1X: panelRoot.inX + panelRoot.inW - panelRoot.halfB
                control1Y: panelRoot.pLeft - panelRoot.wingW * 0.5
                control2X: panelRoot.inX + panelRoot.inW - panelRoot.halfB - panelRoot.wingW * 0.5
                control2Y: panelRoot.pLeft
            }

            PathLine {
                x: panelRoot.rightBarPopL + panelRoot.radius
                y: panelRoot.pLeft
            }

            PathArc {
                x: panelRoot.rightBarPopL
                y: panelRoot.pLeft + panelRoot.radius
                radiusX: Math.max(0.1, panelRoot.radius)
                radiusY: Math.max(0.1, panelRoot.radius)
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.rightBarPopL
                y: panelRoot.inY + panelRoot.inH - panelRoot.halfB - panelRoot.wingW
            }

            PathCubic {
                x: panelRoot.rightBarPopL - panelRoot.wingW
                y: panelRoot.inY + panelRoot.inH - panelRoot.halfB
                control1X: panelRoot.rightBarPopL
                control1Y: panelRoot.inY + panelRoot.inH - panelRoot.halfB - panelRoot.wingW * 0.5
                control2X: panelRoot.rightBarPopL - panelRoot.wingW * 0.5
                control2Y: panelRoot.inY + panelRoot.inH
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
