import QtQuick
import ".."

// Faint grid + highlighted target cell, shown over the whole desktop window
// while a widget is actively being dragged in grid-snap mode - draws once
// per relevant change rather than per frame, since the grid itself is static
// and only the highlighted cell moves.
Canvas {
    id: root

    property real gridSize: 24
    property bool active: false
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 0
    property real targetHeight: 0

    opacity: active ? 1.0 : 0.0
    visible: opacity > 0.001
    Behavior on opacity { NumberAnimation { duration: 150 } }

    onActiveChanged: requestPaint()
    onTargetXChanged: if (active) requestPaint()
    onTargetYChanged: if (active) requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        let ctx = getContext("2d")
        ctx.reset()
        if (!active) return

        ctx.strokeStyle = Qt.rgba(255, 255, 255, 0.08)
        ctx.lineWidth = 1
        ctx.beginPath()
        for (let x = 0; x <= width; x += gridSize) {
            ctx.moveTo(x + 0.5, 0)
            ctx.lineTo(x + 0.5, height)
        }
        for (let y = 0; y <= height; y += gridSize) {
            ctx.moveTo(0, y + 0.5)
            ctx.lineTo(width, y + 0.5)
        }
        ctx.stroke()

        // Highlight the cell the widget is currently snapped to
        let accent = Qt.color(Config.accent)
        ctx.fillStyle = Qt.rgba(accent.r, accent.g, accent.b, 0.18)
        ctx.strokeStyle = Qt.rgba(accent.r, accent.g, accent.b, 0.9)
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.rect(targetX + 0.75, targetY + 0.75, targetWidth - 1.5, targetHeight - 1.5)
        ctx.fill()
        ctx.stroke()
    }
}
