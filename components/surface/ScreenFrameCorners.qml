import ".."
import QtQuick
import QtQuick.Shapes

Shape {
    required property var surfaceRoot
    readonly property bool popupActive: surfaceRoot.progress > 0.005 || surfaceRoot.peekActive
    readonly property bool hideTL: popupActive && ((surfaceRoot.barPosition === "left" && (surfaceRoot.isLeftFlush || (surfaceRoot.peekActive && surfaceRoot.isPeekLeftFlush))) || (surfaceRoot.barPosition === "top" && (surfaceRoot.isLeftFlush || (surfaceRoot.peekActive && surfaceRoot.isPeekLeftFlush))))
    readonly property bool hideTR: popupActive && ((surfaceRoot.barPosition === "right" && (surfaceRoot.isLeftFlush || (surfaceRoot.peekActive && surfaceRoot.isPeekLeftFlush))) || (surfaceRoot.barPosition === "top" && (surfaceRoot.isRightFlush || (surfaceRoot.peekActive && surfaceRoot.isPeekRightFlush))))
    readonly property bool hideBL: popupActive && ((surfaceRoot.barPosition === "left" && (surfaceRoot.isRightFlush || (surfaceRoot.peekActive && surfaceRoot.isPeekRightFlush))) || (surfaceRoot.barPosition === "bottom" && (surfaceRoot.isLeftFlush || (surfaceRoot.peekActive && surfaceRoot.isPeekLeftFlush))))
    readonly property bool hideBR: popupActive && ((surfaceRoot.barPosition === "right" && (surfaceRoot.isRightFlush || (surfaceRoot.peekActive && surfaceRoot.isPeekRightFlush))) || (surfaceRoot.barPosition === "bottom" && (surfaceRoot.isRightFlush || (surfaceRoot.peekActive && surfaceRoot.isPeekRightFlush))))

    anchors.fill: parent

    ShapePath {
        fillColor: hideTL ? "transparent" : Config.bgPanel
        strokeWidth: 0
        startX: surfaceRoot.inX
        startY: surfaceRoot.inY

        PathLine {
            x: surfaceRoot.inX + surfaceRoot.inRadi
            y: surfaceRoot.inY
        }

        PathCubic {
            x: surfaceRoot.inX
            y: surfaceRoot.inY + surfaceRoot.inRadi
            control1X: surfaceRoot.inX + surfaceRoot.inRadi * (1 - surfaceRoot.wingK)
            control1Y: surfaceRoot.inY
            control2X: surfaceRoot.inX
            control2Y: surfaceRoot.inY + surfaceRoot.inRadi * (1 - surfaceRoot.wingK)
        }

        PathLine {
            x: surfaceRoot.inX
            y: surfaceRoot.inY
        }

    }

    ShapePath {
        fillColor: hideTR ? "transparent" : Config.bgPanel
        strokeWidth: 0
        startX: surfaceRoot.inX + surfaceRoot.inW
        startY: surfaceRoot.inY

        PathLine {
            x: surfaceRoot.inX + surfaceRoot.inW - surfaceRoot.inRadi
            y: surfaceRoot.inY
        }

        PathCubic {
            x: surfaceRoot.inX + surfaceRoot.inW
            y: surfaceRoot.inY + surfaceRoot.inRadi
            control1X: surfaceRoot.inX + surfaceRoot.inW - surfaceRoot.inRadi * (1 - surfaceRoot.wingK)
            control1Y: surfaceRoot.inY
            control2X: surfaceRoot.inX + surfaceRoot.inW
            control2Y: surfaceRoot.inY + surfaceRoot.inRadi * (1 - surfaceRoot.wingK)
        }

        PathLine {
            x: surfaceRoot.inX + surfaceRoot.inW
            y: surfaceRoot.inY
        }

    }

    ShapePath {
        fillColor: hideBL ? "transparent" : Config.bgPanel
        strokeWidth: 0
        startX: surfaceRoot.inX
        startY: surfaceRoot.inY + surfaceRoot.inH

        PathLine {
            x: surfaceRoot.inX + surfaceRoot.inRadi
            y: surfaceRoot.inY + surfaceRoot.inH
        }

        PathCubic {
            x: surfaceRoot.inX
            y: surfaceRoot.inY + surfaceRoot.inH - surfaceRoot.inRadi
            control1X: surfaceRoot.inX + surfaceRoot.inRadi * (1 - surfaceRoot.wingK)
            control1Y: surfaceRoot.inY + surfaceRoot.inH
            control2X: surfaceRoot.inX
            control2Y: surfaceRoot.inY + surfaceRoot.inH - surfaceRoot.inRadi * (1 - surfaceRoot.wingK)
        }

        PathLine {
            x: surfaceRoot.inX
            y: surfaceRoot.inY + surfaceRoot.inH
        }

    }

    ShapePath {
        fillColor: hideBR ? "transparent" : Config.bgPanel
        strokeWidth: 0
        startX: surfaceRoot.inX + surfaceRoot.inW
        startY: surfaceRoot.inY + surfaceRoot.inH

        PathLine {
            x: surfaceRoot.inX + surfaceRoot.inW - surfaceRoot.inRadi
            y: surfaceRoot.inY + surfaceRoot.inH
        }

        PathCubic {
            x: surfaceRoot.inX + surfaceRoot.inW
            y: surfaceRoot.inY + surfaceRoot.inH - surfaceRoot.inRadi
            control1X: surfaceRoot.inX + surfaceRoot.inW - surfaceRoot.inRadi * (1 - surfaceRoot.wingK)
            control1Y: surfaceRoot.inY + surfaceRoot.inH
            control2X: surfaceRoot.inX + surfaceRoot.inW
            control2Y: surfaceRoot.inY + surfaceRoot.inH - surfaceRoot.inRadi * (1 - surfaceRoot.wingK)
        }

        PathLine {
            x: surfaceRoot.inX + surfaceRoot.inW
            y: surfaceRoot.inY + surfaceRoot.inH
        }

    }

}
