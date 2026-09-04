import ".."
import QtQuick
import QtQuick.Shapes

Shape {
    id: openShapeTopFloating

    required property var panelRoot

    anchors.fill: parent
    visible: panelRoot.barPosition === "top" && !panelRoot.isScreenFrame && (panelRoot.progress > 0 || panelRoot.isPeeking)

    // Material fill: same slow radial drift as BarClosedShape, sized to
    // whichever is bigger right now - the collapsed pill or the fully open
    // panel - so the wash reads at both scales instead of vanishing into a
    // pinprick on the big panel or blowing out on the small pill.
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
        (panelRoot.barBottomY + panelRoot.currentHeight) - panelRoot.halfB,
        160)

    ShapePath {
        fillGradient: RadialGradient {
            centerX: panelRoot.islandBarL + (panelRoot.islandBarR - panelRoot.islandBarL) * (0.3 + openShapeTopFloating.materialDrift * 0.4)
            centerY: panelRoot.halfB
            centerRadius: openShapeTopFloating.materialSpan * 0.85
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
        startY: panelRoot.halfB

        PathLine {
            x: panelRoot.islandBarR - panelRoot.barRadius
            y: panelRoot.halfB
        }

        PathArc {
            x: panelRoot.islandBarR
            y: panelRoot.halfB + panelRoot.barRadius
            radiusX: panelRoot.barRadius
            radiusY: panelRoot.barRadius
            direction: PathArc.Clockwise
        }

        PathLine {
            x: panelRoot.islandBarR
            y: panelRoot.isRightFlush ? (panelRoot.barBottomY + panelRoot.currentHeight - panelRoot.radius) : (panelRoot.barBottomY - panelRoot.barRadius)
        }

        PathArc {
            x: panelRoot.isRightFlush ? panelRoot.islandBarR : (panelRoot.islandBarR - panelRoot.barRadius)
            y: panelRoot.isRightFlush ? (panelRoot.barBottomY + panelRoot.currentHeight - panelRoot.radius) : panelRoot.barBottomY
            radiusX: panelRoot.isRightFlush ? 0 : panelRoot.barRadius
            radiusY: panelRoot.isRightFlush ? 0 : panelRoot.barRadius
            direction: PathArc.Clockwise
        }

        PathLine {
            x: panelRoot.isRightFlush ? panelRoot.islandBarR : (panelRoot.pRight + panelRoot.wingW)
            y: panelRoot.isRightFlush ? (panelRoot.barBottomY + panelRoot.currentHeight - panelRoot.radius) : panelRoot.barBottomY
        }

        PathCubic {
            x: panelRoot.isRightFlush ? panelRoot.islandBarR : panelRoot.pRight
            y: panelRoot.isRightFlush ? (panelRoot.barBottomY + panelRoot.currentHeight - panelRoot.radius) : (panelRoot.barBottomY + panelRoot.wingH)
            control1X: panelRoot.isRightFlush ? panelRoot.islandBarR : (panelRoot.pRight + (panelRoot.wingW * (1 - panelRoot.wingK)))
            control1Y: panelRoot.isRightFlush ? (panelRoot.barBottomY + panelRoot.currentHeight - panelRoot.radius) : panelRoot.barBottomY
            control2X: panelRoot.isRightFlush ? panelRoot.islandBarR : panelRoot.pRight
            control2Y: panelRoot.isRightFlush ? (panelRoot.barBottomY + panelRoot.currentHeight - panelRoot.radius) : (panelRoot.barBottomY + (panelRoot.wingH * (1 - panelRoot.wingK)))
        }

        PathLine {
            x: panelRoot.isRightFlush ? panelRoot.islandBarR : panelRoot.pRight
            y: panelRoot.barBottomY + panelRoot.currentHeight - panelRoot.radius
        }

        PathCubic {
            x: panelRoot.isRightFlush ? (panelRoot.islandBarR - panelRoot.radius) : (panelRoot.pRight - panelRoot.radius)
            y: panelRoot.barBottomY + panelRoot.currentHeight
            control1X: panelRoot.isRightFlush ? panelRoot.islandBarR : panelRoot.pRight
            control1Y: panelRoot.barBottomY + panelRoot.currentHeight - panelRoot.radius * (1 - panelRoot.wingK)
            control2X: (panelRoot.isRightFlush ? panelRoot.islandBarR : panelRoot.pRight) - panelRoot.radius * (1 - panelRoot.wingK)
            control2Y: panelRoot.barBottomY + panelRoot.currentHeight
        }

        PathLine {
            x: panelRoot.isLeftFlush ? (panelRoot.islandBarL + panelRoot.radius) : (panelRoot.pLeft + panelRoot.radius)
            y: panelRoot.barBottomY + panelRoot.currentHeight
        }

        PathCubic {
            x: panelRoot.isLeftFlush ? panelRoot.islandBarL : panelRoot.pLeft
            y: panelRoot.barBottomY + panelRoot.currentHeight - panelRoot.radius
            control1X: (panelRoot.isLeftFlush ? panelRoot.islandBarL : panelRoot.pLeft) + panelRoot.radius * (1 - panelRoot.wingK)
            control1Y: panelRoot.barBottomY + panelRoot.currentHeight
            control2X: panelRoot.isLeftFlush ? panelRoot.islandBarL : panelRoot.pLeft
            control2Y: panelRoot.barBottomY + panelRoot.currentHeight - panelRoot.radius * (1 - panelRoot.wingK)
        }

        PathLine {
            x: panelRoot.isLeftFlush ? panelRoot.islandBarL : panelRoot.pLeft
            y: panelRoot.isLeftFlush ? (panelRoot.halfB + panelRoot.barRadius) : (panelRoot.barBottomY + panelRoot.wingH)
        }

        PathCubic {
            x: panelRoot.isLeftFlush ? panelRoot.islandBarL : (panelRoot.pLeft - panelRoot.wingW)
            y: panelRoot.isLeftFlush ? (panelRoot.halfB + panelRoot.barRadius) : panelRoot.barBottomY
            control1X: panelRoot.isLeftFlush ? panelRoot.islandBarL : panelRoot.pLeft
            control1Y: panelRoot.isLeftFlush ? (panelRoot.halfB + panelRoot.barRadius) : (panelRoot.barBottomY + (panelRoot.wingH * (1 - panelRoot.wingK)))
            control2X: panelRoot.isLeftFlush ? panelRoot.islandBarL : (panelRoot.pLeft - (panelRoot.wingW * (1 - panelRoot.wingK)))
            control2Y: panelRoot.isLeftFlush ? (panelRoot.halfB + panelRoot.barRadius) : panelRoot.barBottomY
        }

        PathLine {
            x: panelRoot.isLeftFlush ? panelRoot.islandBarL : (panelRoot.islandBarL + panelRoot.barRadius)
            y: panelRoot.isLeftFlush ? (panelRoot.halfB + panelRoot.barRadius) : panelRoot.barBottomY
        }

        PathArc {
            x: panelRoot.islandBarL
            y: panelRoot.isLeftFlush ? (panelRoot.halfB + panelRoot.barRadius) : (panelRoot.barBottomY - panelRoot.barRadius)
            radiusX: panelRoot.isLeftFlush ? 0 : panelRoot.barRadius
            radiusY: panelRoot.isLeftFlush ? 0 : panelRoot.barRadius
            direction: PathArc.Clockwise
        }

        PathLine {
            x: panelRoot.islandBarL
            y: panelRoot.halfB + panelRoot.barRadius
        }

        PathArc {
            x: panelRoot.islandBarL + panelRoot.barRadius
            y: panelRoot.halfB
            radiusX: panelRoot.barRadius
            radiusY: panelRoot.barRadius
            direction: PathArc.Clockwise
        }

    }

}
