import ".."
import QtQuick
import QtQuick.Shapes

Item {
    id: sfOpenGroupBottom

    required property var panelRoot
    required property Item panelCanvas

    anchors.fill: parent
    visible: panelRoot.barPosition === "bottom" && panelRoot.isScreenFrame && (panelRoot.progress > 0 || panelRoot.isPeeking)

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
            startX: panelRoot.pLeft - panelRoot.wingW
            startY: panelRoot.inY + panelRoot.inH

            PathLine {
                x: panelRoot.pRight + panelRoot.wingW
                y: panelRoot.inY + panelRoot.inH
            }

            PathCubic {
                x: panelRoot.pRight
                y: panelRoot.inY + panelRoot.inH - panelRoot.wingW
                control1X: panelRoot.pRight + panelRoot.wingW * 0.5
                control1Y: panelRoot.inY + panelRoot.inH
                control2X: panelRoot.pRight
                control2Y: panelRoot.inY + panelRoot.inH - panelRoot.wingW * 0.5
            }

            PathLine {
                x: panelRoot.pRight
                y: panelRoot.bottomBarPopT + panelRoot.radius
            }

            PathArc {
                x: panelRoot.pRight - panelRoot.radius
                y: panelRoot.bottomBarPopT
                radiusX: panelRoot.radius
                radiusY: panelRoot.radius
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.pLeft + panelRoot.radius
                y: panelRoot.bottomBarPopT
            }

            PathArc {
                x: panelRoot.pLeft
                y: panelRoot.bottomBarPopT + panelRoot.radius
                radiusX: panelRoot.radius
                radiusY: panelRoot.radius
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.pLeft
                y: panelRoot.inY + panelRoot.inH - panelRoot.wingW
            }

            PathCubic {
                x: panelRoot.pLeft - panelRoot.wingW
                y: panelRoot.inY + panelRoot.inH
                control1X: panelRoot.pLeft
                control1Y: panelRoot.inY + panelRoot.inH - panelRoot.wingW * 0.5
                control2X: panelRoot.pLeft - panelRoot.wingW * 0.5
                control2Y: panelRoot.inY + panelRoot.inH
            }

        }

    }

    Shape {
        anchors.fill: parent
        visible: panelRoot.isLeftFlush || (peekActive && panelRoot.isPeekLeftFlush)

        ShapePath {
            fillColor: Config.bgPanel
            strokeWidth: 0
            startX: panelRoot.inX
            startY: panelRoot.inY + panelRoot.inH

            PathLine {
                x: panelRoot.pRight + panelRoot.wingW
                y: panelRoot.inY + panelRoot.inH
            }

            PathCubic {
                x: panelRoot.pRight
                y: panelRoot.inY + panelRoot.inH - panelRoot.wingW
                control1X: panelRoot.pRight + panelRoot.wingW * 0.5
                control1Y: panelRoot.inY + panelRoot.inH
                control2X: panelRoot.pRight
                control2Y: panelRoot.inY + panelRoot.inH - panelRoot.wingW * 0.5
            }

            PathLine {
                x: panelRoot.pRight
                y: panelRoot.bottomBarPopT + panelRoot.radius
            }

            PathArc {
                x: panelRoot.pRight - panelRoot.radius
                y: panelRoot.bottomBarPopT
                radiusX: panelRoot.radius
                radiusY: panelRoot.radius
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.inX + panelRoot.wingW
                y: panelRoot.bottomBarPopT
            }

            PathCubic {
                x: panelRoot.inX
                y: panelRoot.bottomBarPopT - panelRoot.wingW
                control1X: panelRoot.inX + panelRoot.wingW * 0.5
                control1Y: panelRoot.bottomBarPopT
                control2X: panelRoot.inX
                control2Y: panelRoot.bottomBarPopT - panelRoot.wingW * 0.5
            }

            PathLine {
                x: panelRoot.inX
                y: panelRoot.inY + panelRoot.inH
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
                x: panelRoot.pLeft - panelRoot.wingW
                y: panelRoot.inY + panelRoot.inH
            }

            PathCubic {
                x: panelRoot.pLeft
                y: panelRoot.inY + panelRoot.inH - panelRoot.wingW
                control1X: panelRoot.pLeft
                control1Y: panelRoot.inY + panelRoot.inH - panelRoot.wingW * 0.5
                control2X: panelRoot.pLeft - panelRoot.wingW * 0.5
                control2Y: panelRoot.inY + panelRoot.inH
            }

            PathLine {
                x: panelRoot.pLeft
                y: panelRoot.bottomBarPopT + panelRoot.radius
            }

            PathArc {
                x: panelRoot.pLeft + panelRoot.radius
                y: panelRoot.bottomBarPopT
                radiusX: panelRoot.radius
                radiusY: panelRoot.radius
                direction: PathArc.Clockwise
            }

            PathLine {
                x: panelRoot.inX + panelRoot.inW - panelRoot.wingW
                y: panelRoot.bottomBarPopT
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.inW
                y: panelRoot.bottomBarPopT - panelRoot.wingW
                control1X: panelRoot.inX + panelRoot.inW - panelRoot.wingW * 0.5
                control1Y: panelRoot.bottomBarPopT
                control2X: panelRoot.inX + panelRoot.inW
                control2Y: panelRoot.bottomBarPopT - panelRoot.wingW * 0.5
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
                x: panelRoot.pRight + panelRoot.wingW
                y: panelRoot.inY + panelRoot.inH - panelRoot.halfB
            }

            PathCubic {
                x: panelRoot.pRight
                y: panelRoot.inY + panelRoot.inH - panelRoot.halfB - panelRoot.wingW
                control1X: panelRoot.pRight + panelRoot.wingW * 0.5
                control1Y: panelRoot.inY + panelRoot.inH - panelRoot.halfB
                control2X: panelRoot.pRight
                control2Y: panelRoot.inY + panelRoot.inH - panelRoot.halfB - panelRoot.wingW * 0.5
            }

            PathLine {
                x: panelRoot.pRight
                y: panelRoot.bottomBarPopT + panelRoot.radius
            }

            PathArc {
                x: panelRoot.pRight - panelRoot.radius
                y: panelRoot.bottomBarPopT
                radiusX: Math.max(0.1, panelRoot.radius)
                radiusY: Math.max(0.1, panelRoot.radius)
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.pLeft + panelRoot.radius
                y: panelRoot.bottomBarPopT
            }

            PathArc {
                x: panelRoot.pLeft
                y: panelRoot.bottomBarPopT + panelRoot.radius
                radiusX: Math.max(0.1, panelRoot.radius)
                radiusY: Math.max(0.1, panelRoot.radius)
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.pLeft
                y: panelRoot.inY + panelRoot.inH - panelRoot.halfB - panelRoot.wingW
            }

            PathCubic {
                x: panelRoot.pLeft - panelRoot.wingW
                y: panelRoot.inY + panelRoot.inH - panelRoot.halfB
                control1X: panelRoot.pLeft
                control1Y: panelRoot.inY + panelRoot.inH - panelRoot.halfB - panelRoot.wingW * 0.5
                control2X: panelRoot.pLeft - panelRoot.wingW * 0.5
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
                x: panelRoot.pRight + panelRoot.wingW
                y: panelRoot.inY + panelRoot.inH - panelRoot.halfB
            }

            PathCubic {
                x: panelRoot.pRight
                y: panelRoot.inY + panelRoot.inH - panelRoot.halfB - panelRoot.wingW
                control1X: panelRoot.pRight + panelRoot.wingW * 0.5
                control1Y: panelRoot.inY + panelRoot.inH - panelRoot.halfB
                control2X: panelRoot.pRight
                control2Y: panelRoot.inY + panelRoot.inH - panelRoot.halfB - panelRoot.wingW * 0.5
            }

            PathLine {
                x: panelRoot.pRight
                y: panelRoot.bottomBarPopT + panelRoot.radius
            }

            PathArc {
                x: panelRoot.pRight - panelRoot.radius
                y: panelRoot.bottomBarPopT
                radiusX: Math.max(0.1, panelRoot.radius)
                radiusY: Math.max(0.1, panelRoot.radius)
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.inX + panelRoot.halfB + panelRoot.wingW
                y: panelRoot.bottomBarPopT
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.halfB
                y: panelRoot.bottomBarPopT - panelRoot.wingH
                control1X: panelRoot.inX + panelRoot.halfB + panelRoot.wingW * 0.5
                control1Y: panelRoot.bottomBarPopT
                control2X: panelRoot.inX + panelRoot.halfB
                control2Y: panelRoot.bottomBarPopT - panelRoot.wingH * 0.5
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
                y: panelRoot.bottomBarPopT - panelRoot.wingW
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.inW - panelRoot.halfB - panelRoot.wingW
                y: panelRoot.bottomBarPopT
                control1X: panelRoot.inX + panelRoot.inW - panelRoot.halfB
                control1Y: panelRoot.bottomBarPopT - panelRoot.wingW * 0.5
                control2X: panelRoot.inX + panelRoot.inW - panelRoot.halfB - panelRoot.wingW * 0.5
                control2Y: panelRoot.bottomBarPopT
            }

            PathLine {
                x: panelRoot.pLeft + panelRoot.radius
                y: panelRoot.bottomBarPopT
            }

            PathArc {
                x: panelRoot.pLeft
                y: panelRoot.bottomBarPopT + panelRoot.radius
                radiusX: Math.max(0.1, panelRoot.radius)
                radiusY: Math.max(0.1, panelRoot.radius)
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.pLeft
                y: panelRoot.inY + panelRoot.inH - panelRoot.halfB - panelRoot.wingW
            }

            PathCubic {
                x: panelRoot.pLeft - panelRoot.wingW
                y: panelRoot.inY + panelRoot.inH - panelRoot.halfB
                control1X: panelRoot.pLeft
                control1Y: panelRoot.inY + panelRoot.inH - panelRoot.halfB - panelRoot.wingW * 0.5
                control2X: panelRoot.pLeft - panelRoot.wingW * 0.5
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
