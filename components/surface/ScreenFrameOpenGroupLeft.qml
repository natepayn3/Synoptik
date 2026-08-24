import ".."
import QtQuick
import QtQuick.Shapes

Item {
    id: sfOpenGroupLeft

    required property var panelRoot
    required property Item panelCanvas

    anchors.fill: parent
    visible: panelRoot.barPosition === "left" && panelRoot.isScreenFrame && (panelRoot.progress > 0 || panelRoot.isPeeking)

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

    // --- Center Floating Surface ---
    Shape {
        anchors.fill: parent
        visible: !panelRoot.isLeftFlush && !panelRoot.isRightFlush && !(peekActive && panelRoot.isPeekLeftFlush) && !(peekActive && panelRoot.isPeekRightFlush)

        ShapePath {
            fillColor: Config.bgPanel
            strokeWidth: 0
            startX: panelRoot.inX
            startY: panelRoot.pLeft - panelRoot.wingW

            PathCubic {
                x: panelRoot.inX + panelRoot.wingW
                y: panelRoot.pLeft
                control1X: panelRoot.inX
                control1Y: panelRoot.pLeft - panelRoot.wingW * (1 - panelRoot.wingK)
                control2X: panelRoot.inX + panelRoot.wingW * (1 - panelRoot.wingK)
                control2Y: panelRoot.pLeft
            }

            PathLine {
                x: panelRoot.leftBarRx - panelRoot.radius
                y: panelRoot.pLeft
            }

            PathCubic {
                x: panelRoot.leftBarRx
                y: panelRoot.pLeft + panelRoot.radius
                control1X: panelRoot.leftBarRx - panelRoot.radius * (1 - panelRoot.wingK)
                control1Y: panelRoot.pLeft
                control2X: panelRoot.leftBarRx
                control2Y: panelRoot.pLeft + panelRoot.radius * (1 - panelRoot.wingK)
            }

            PathLine {
                x: panelRoot.leftBarRx
                y: panelRoot.pRight - panelRoot.radius
            }

            PathCubic {
                x: panelRoot.leftBarRx - panelRoot.radius
                y: panelRoot.pRight
                control1X: panelRoot.leftBarRx
                control1Y: panelRoot.pRight - panelRoot.radius * (1 - panelRoot.wingK)
                control2X: panelRoot.leftBarRx - panelRoot.radius * (1 - panelRoot.wingK)
                control2Y: panelRoot.pRight
            }

            PathLine {
                x: panelRoot.inX + panelRoot.wingW
                y: panelRoot.pRight
            }

            PathCubic {
                x: panelRoot.inX
                y: panelRoot.pRight + panelRoot.wingW
                control1X: panelRoot.inX + panelRoot.wingW * (1 - panelRoot.wingK)
                control1Y: panelRoot.pRight
                control2X: panelRoot.inX
                control2Y: panelRoot.pRight + panelRoot.wingW * (1 - panelRoot.wingK)
            }

            PathLine {
                x: panelRoot.inX
                y: panelRoot.pLeft - panelRoot.wingW
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
            startY: panelRoot.inY

            PathLine {
                x: panelRoot.leftBarRx + panelRoot.wingW
                y: panelRoot.inY
            }

            PathCubic {
                x: panelRoot.leftBarRx
                y: panelRoot.inY + panelRoot.wingW
                control1X: panelRoot.leftBarRx + panelRoot.wingW * 0.5
                control1Y: panelRoot.inY
                control2X: panelRoot.leftBarRx
                control2Y: panelRoot.inY + panelRoot.wingW * 0.5
            }

            PathLine {
                x: panelRoot.leftBarRx
                y: panelRoot.pRight - panelRoot.radius
            }

            PathArc {
                x: panelRoot.leftBarRx - panelRoot.radius
                y: panelRoot.pRight
                radiusX: panelRoot.radius
                radiusY: panelRoot.radius
                direction: PathArc.Clockwise
            }

            PathLine {
                x: panelRoot.inX + panelRoot.wingW
                y: panelRoot.pRight
            }

            PathCubic {
                x: panelRoot.inX
                y: panelRoot.pRight + panelRoot.wingW
                control1X: panelRoot.inX + panelRoot.wingW * 0.5
                control1Y: panelRoot.pRight
                control2X: panelRoot.inX
                control2Y: panelRoot.pRight + panelRoot.wingW * 0.5
            }

            PathLine {
                x: panelRoot.inX
                y: panelRoot.inY
            }

        }

    }

    Shape {
        anchors.fill: parent
        visible: panelRoot.isRightFlush || (peekActive && panelRoot.isPeekRightFlush)

        ShapePath {
            fillColor: Config.bgPanel
            strokeWidth: 0
            startX: panelRoot.inX
            startY: panelRoot.pLeft - panelRoot.wingW

            PathCubic {
                x: panelRoot.inX + panelRoot.wingW
                y: panelRoot.pLeft
                control1X: panelRoot.inX
                control1Y: panelRoot.pLeft - panelRoot.wingW * 0.5
                control2X: panelRoot.inX + panelRoot.wingW * 0.5
                control2Y: panelRoot.pLeft
            }

            PathLine {
                x: panelRoot.leftBarRx - panelRoot.radius
                y: panelRoot.pLeft
            }

            PathArc {
                x: panelRoot.leftBarRx
                y: panelRoot.pLeft + panelRoot.radius
                radiusX: panelRoot.radius
                radiusY: panelRoot.radius
                direction: PathArc.Clockwise
            }

            PathLine {
                x: panelRoot.leftBarRx
                y: panelRoot.inY + panelRoot.inH - panelRoot.wingW
            }

            PathCubic {
                x: panelRoot.leftBarRx + panelRoot.wingW
                y: panelRoot.inY + panelRoot.inH
                control1X: panelRoot.leftBarRx
                control1Y: panelRoot.inY + panelRoot.inH - panelRoot.wingW * 0.5
                control2X: panelRoot.leftBarRx + panelRoot.wingW * 0.5
                control2Y: panelRoot.inY + panelRoot.inH
            }

            PathLine {
                x: panelRoot.inX
                y: panelRoot.inY + panelRoot.inH
            }

            PathLine {
                x: panelRoot.inX
                y: panelRoot.pLeft - panelRoot.wingW
            }

        }

    }

    // --- Inner Border Lines ---
    Shape {
        anchors.fill: parent
        visible: !panelRoot.isLeftFlush && !panelRoot.isRightFlush && !(peekActive && panelRoot.isPeekLeftFlush) && !(peekActive && panelRoot.isPeekRightFlush)

        ShapePath {
            fillColor: "transparent"
            strokeWidth: panelRoot.borderWidth
            strokeColor: shellRoot.currentBorderColor
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            startX: panelRoot.inX + panelRoot.inW - panelRoot.inRadi
            startY: panelRoot.inY + panelRoot.halfB

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
                y: panelRoot.pRight + panelRoot.wingW
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.wingW
                y: panelRoot.pRight
                control1X: panelRoot.inX + panelRoot.halfB
                control1Y: panelRoot.pRight + panelRoot.wingW * (1 - panelRoot.wingK)
                control2X: panelRoot.inX + panelRoot.wingW * (1 - panelRoot.wingK)
                control2Y: panelRoot.pRight
            }

            PathLine {
                x: panelRoot.leftBarRx - panelRoot.radius
                y: panelRoot.pRight
            }

            PathCubic {
                x: panelRoot.leftBarRx
                y: panelRoot.pRight - panelRoot.radius
                control1X: panelRoot.leftBarRx - panelRoot.radius * (1 - panelRoot.wingK)
                control1Y: panelRoot.pRight
                control2X: panelRoot.leftBarRx
                control2Y: panelRoot.pRight - panelRoot.radius * (1 - panelRoot.wingK)
            }

            PathLine {
                x: panelRoot.leftBarRx
                y: panelRoot.pLeft + panelRoot.radius
            }

            PathCubic {
                x: panelRoot.leftBarRx - panelRoot.radius
                y: panelRoot.pLeft
                control1X: panelRoot.leftBarRx
                control1Y: panelRoot.pLeft + panelRoot.radius * (1 - panelRoot.wingK)
                control2X: panelRoot.leftBarRx - panelRoot.radius * (1 - panelRoot.wingK)
                control2Y: panelRoot.pLeft
            }

            PathLine {
                x: panelRoot.inX + panelRoot.wingW
                y: panelRoot.pLeft
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.halfB
                y: panelRoot.pLeft - panelRoot.wingW
                control1X: panelRoot.inX + panelRoot.wingW * (1 - panelRoot.wingK)
                control1Y: panelRoot.pLeft
                control2X: panelRoot.inX + panelRoot.halfB
                control2Y: panelRoot.pLeft - panelRoot.wingW * (1 - panelRoot.wingK)
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

            PathLine {
                x: panelRoot.inX + panelRoot.inW - panelRoot.inRadi
                y: panelRoot.inY + panelRoot.halfB
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
            startX: panelRoot.inX + panelRoot.inW - panelRoot.inRadi
            startY: panelRoot.inY + panelRoot.halfB

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
                y: panelRoot.pRight + panelRoot.wingW
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.wingW
                y: panelRoot.pRight
                control1X: panelRoot.inX + panelRoot.halfB
                control1Y: panelRoot.pRight + panelRoot.wingW * 0.5
                control2X: panelRoot.inX + panelRoot.wingW * 0.5
                control2Y: panelRoot.pRight
            }

            PathLine {
                x: panelRoot.leftBarRx - panelRoot.radius
                y: panelRoot.pRight
            }

            PathArc {
                x: panelRoot.leftBarRx
                y: panelRoot.pRight - panelRoot.radius
                radiusX: Math.max(0.1, panelRoot.radius)
                radiusY: Math.max(0.1, panelRoot.radius)
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.leftBarRx
                y: panelRoot.inY + panelRoot.halfB + panelRoot.wingW
            }

            PathCubic {
                x: panelRoot.leftBarRx + panelRoot.wingW
                y: panelRoot.inY + panelRoot.halfB
                control1X: panelRoot.leftBarRx
                control1Y: panelRoot.inY + panelRoot.halfB + panelRoot.wingW * 0.5
                control2X: panelRoot.leftBarRx + panelRoot.wingW * 0.5
                control2Y: panelRoot.inY + panelRoot.halfB
            }

            PathLine {
                x: panelRoot.inX + panelRoot.inW - panelRoot.inRadi
                y: panelRoot.inY + panelRoot.halfB
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
                x: panelRoot.leftBarRx + panelRoot.wingW
                y: panelRoot.inY + panelRoot.inH - panelRoot.halfB
            }

            PathCubic {
                x: panelRoot.leftBarRx
                y: panelRoot.inY + panelRoot.inH - panelRoot.halfB - panelRoot.wingW
                control1X: panelRoot.leftBarRx + panelRoot.wingW * 0.5
                control1Y: panelRoot.inY + panelRoot.inH - panelRoot.halfB
                control2X: panelRoot.leftBarRx
                control2Y: panelRoot.inY + panelRoot.inH - panelRoot.halfB - panelRoot.wingW * 0.5
            }

            PathLine {
                x: panelRoot.leftBarRx
                y: panelRoot.pLeft + panelRoot.radius
            }

            PathArc {
                x: panelRoot.leftBarRx - panelRoot.radius
                y: panelRoot.pLeft
                radiusX: Math.max(0.1, panelRoot.radius)
                radiusY: Math.max(0.1, panelRoot.radius)
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: panelRoot.inX + panelRoot.wingW
                y: panelRoot.pLeft
            }

            PathCubic {
                x: panelRoot.inX + panelRoot.halfB
                y: panelRoot.pLeft - panelRoot.wingW
                control1X: panelRoot.inX + panelRoot.wingW * 0.5
                control1Y: panelRoot.pLeft
                control2X: panelRoot.inX + panelRoot.halfB
                control2Y: panelRoot.pLeft - panelRoot.wingW * 0.5
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
