import ".."
import QtQuick
import QtQuick.Shapes

Shape {
    id: openShapeBottomFloating

    required property var panelRoot
    required property Item panelCanvas
    readonly property real barTopY: panelCanvas.height - panelRoot.barH + panelRoot.halfB

    anchors.fill: parent
    visible: panelRoot.barPosition === "bottom" && !panelRoot.isScreenFrame && (panelRoot.progress > 0 || panelRoot.isPeeking)

    // Same slow drifting tint as the other bar shapes, instead of one flat color.
    property real materialDrift: 0.0
    SequentialAnimation on materialDrift {
        running: true
        loops: Animation.Infinite
        NumberAnimation { to: 1.0; duration: 15000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.0; duration: 15000; easing.type: Easing.InOutSine }
    }
    readonly property real materialSpan: Math.max(
        panelRoot.pRight - panelRoot.pLeft,
        panelRoot.islandBarR - panelRoot.islandBarL,
        panelRoot.currentHeight,
        160)

    ShapePath {
        fillGradient: RadialGradient {
            centerX: panelRoot.islandBarL + (panelRoot.islandBarR - panelRoot.islandBarL) * (0.3 + openShapeBottomFloating.materialDrift * 0.4)
            centerY: panelCanvas.height - panelRoot.halfB
            centerRadius: openShapeBottomFloating.materialSpan * 0.85
            focalX: centerX
            focalY: centerY
            GradientStop { position: 0.0; color: Qt.tint(Config.bgPanel, Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.14)) }
            GradientStop { position: 0.6; color: Config.bgPanel }
            GradientStop { position: 1.0; color: Qt.darker(Config.bgPanel, 1.12) }
        }
        strokeWidth: panelRoot.borderWidth
        strokeColor: shellRoot.currentBorderColor
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap
        startX: panelRoot.islandBarL + panelRoot.barRadius
        startY: panelCanvas.height - panelRoot.halfB

        // Bottom horizontal line (left to right)
        PathLine {
            x: panelRoot.islandBarR - panelRoot.barRadius
            y: panelCanvas.height - panelRoot.halfB
        }

        PathArc {
            x: panelRoot.islandBarR
            y: panelCanvas.height - panelRoot.halfB - panelRoot.barRadius
            radiusX: panelRoot.barRadius
            radiusY: panelRoot.barRadius
            direction: PathArc.Counterclockwise
        }

        // Right side going up to the bar top edge
        PathLine {
            x: panelRoot.islandBarR
            y: panelRoot.isRightFlush ? (openShapeBottomFloating.barTopY - panelRoot.currentHeight + panelRoot.radius) : (openShapeBottomFloating.barTopY + panelRoot.barRadius)
        }

        PathArc {
            x: panelRoot.isRightFlush ? panelRoot.islandBarR : (panelRoot.islandBarR - panelRoot.barRadius)
            y: panelRoot.isRightFlush ? (openShapeBottomFloating.barTopY - panelRoot.currentHeight + panelRoot.radius) : openShapeBottomFloating.barTopY
            radiusX: panelRoot.isRightFlush ? 0 : panelRoot.barRadius
            radiusY: panelRoot.isRightFlush ? 0 : panelRoot.barRadius
            direction: PathArc.Counterclockwise
        }

        // Right transition into popout
        PathLine {
            x: panelRoot.isRightFlush ? panelRoot.islandBarR : (panelRoot.pRight + panelRoot.wingW)
            y: panelRoot.isRightFlush ? (openShapeBottomFloating.barTopY - panelRoot.currentHeight + panelRoot.radius) : openShapeBottomFloating.barTopY
        }

        PathCubic {
            x: panelRoot.isRightFlush ? panelRoot.islandBarR : panelRoot.pRight
            y: panelRoot.isRightFlush ? (openShapeBottomFloating.barTopY - panelRoot.currentHeight + panelRoot.radius) : (openShapeBottomFloating.barTopY - panelRoot.wingH)
            control1X: panelRoot.isRightFlush ? panelRoot.islandBarR : (panelRoot.pRight + (panelRoot.wingW * (1 - panelRoot.wingK)))
            control1Y: panelRoot.isRightFlush ? (openShapeBottomFloating.barTopY - panelRoot.currentHeight + panelRoot.radius) : openShapeBottomFloating.barTopY
            control2X: panelRoot.isRightFlush ? panelRoot.islandBarR : panelRoot.pRight
            control2Y: panelRoot.isRightFlush ? (openShapeBottomFloating.barTopY - panelRoot.currentHeight + panelRoot.radius) : (openShapeBottomFloating.barTopY - (panelRoot.wingH * (1 - panelRoot.wingK)))
        }

        // Popout Top-Right Corner
        PathLine {
            x: panelRoot.isRightFlush ? panelRoot.islandBarR : panelRoot.pRight
            y: openShapeBottomFloating.barTopY - panelRoot.currentHeight + panelRoot.radius
        }

        PathArc {
            x: panelRoot.isRightFlush ? (panelRoot.islandBarR - panelRoot.radius) : (panelRoot.pRight - panelRoot.radius)
            y: openShapeBottomFloating.barTopY - panelRoot.currentHeight
            radiusX: Math.max(0.1, panelRoot.radius)
            radiusY: Math.max(0.1, panelRoot.radius)
            direction: PathArc.Counterclockwise
        }

        // Popout Top edge (Right to Left)
        PathLine {
            x: panelRoot.isLeftFlush ? (panelRoot.islandBarL + panelRoot.radius) : (panelRoot.pLeft + panelRoot.radius)
            y: openShapeBottomFloating.barTopY - panelRoot.currentHeight
        }

        PathArc {
            x: panelRoot.isLeftFlush ? panelRoot.islandBarL : panelRoot.pLeft
            y: openShapeBottomFloating.barTopY - panelRoot.currentHeight + panelRoot.radius
            radiusX: Math.max(0.1, panelRoot.radius)
            radiusY: Math.max(0.1, panelRoot.radius)
            direction: PathArc.Counterclockwise
        }

        // Popout Left side going down into bar
        PathLine {
            x: panelRoot.isLeftFlush ? panelRoot.islandBarL : panelRoot.pLeft
            y: panelRoot.isLeftFlush ? (panelCanvas.height - panelRoot.halfB - panelRoot.barRadius) : (openShapeBottomFloating.barTopY - panelRoot.wingH)
        }

        PathCubic {
            x: panelRoot.isLeftFlush ? panelRoot.islandBarL : (panelRoot.pLeft - panelRoot.wingW)
            y: panelRoot.isLeftFlush ? (panelCanvas.height - panelRoot.halfB - panelRoot.barRadius) : openShapeBottomFloating.barTopY
            control1X: panelRoot.isLeftFlush ? panelRoot.islandBarL : panelRoot.pLeft
            control1Y: panelRoot.isLeftFlush ? (panelCanvas.height - panelRoot.halfB - panelRoot.barRadius) : (openShapeBottomFloating.barTopY - (panelRoot.wingH * (1 - panelRoot.wingK)))
            control2X: panelRoot.isLeftFlush ? panelRoot.islandBarL : (panelRoot.pLeft - (panelRoot.wingW * (1 - panelRoot.wingK)))
            control2Y: panelRoot.isLeftFlush ? (panelCanvas.height - panelRoot.halfB - panelRoot.barRadius) : openShapeBottomFloating.barTopY
        }

        // Left outer transition down to the bottom corner
        PathLine {
            x: panelRoot.isLeftFlush ? panelRoot.islandBarL : (panelRoot.islandBarL + panelRoot.barRadius)
            y: panelRoot.isLeftFlush ? (panelCanvas.height - panelRoot.halfB - panelRoot.barRadius) : openShapeBottomFloating.barTopY
        }

        PathArc {
            x: panelRoot.islandBarL
            y: panelRoot.isLeftFlush ? (panelCanvas.height - panelRoot.halfB - panelRoot.barRadius) : (openShapeBottomFloating.barTopY + panelRoot.barRadius)
            radiusX: panelRoot.isLeftFlush ? 0 : panelRoot.barRadius
            radiusY: panelRoot.isLeftFlush ? 0 : panelRoot.barRadius
            direction: PathArc.Counterclockwise
        }

        PathLine {
            x: panelRoot.islandBarL
            y: panelCanvas.height - panelRoot.halfB - panelRoot.barRadius
        }

        PathArc {
            x: panelRoot.islandBarL + panelRoot.barRadius
            y: panelCanvas.height - panelRoot.halfB
            radiusX: panelRoot.barRadius
            radiusY: panelRoot.barRadius
            direction: PathArc.Counterclockwise
        }

    }

}
