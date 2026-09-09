import QtQuick
import ".."

// Faint grid + highlighted target cell, shown over the whole desktop window
// while a widget is actively being dragged in grid-snap mode - draws once
// per relevant change rather than per frame, since the grid itself is static
// and only the highlighted cell moves.
//
// Also owns the screen-center guide lines: a 24px grid almost never lands
// exactly on a screen's true center (e.g. a 100px-wide widget centered on a
// 2560px display needs x=1230, which isn't a multiple of 24), so "snap to
// grid" alone can get a widget close to centered but never exactly. The
// center lines are a second, independent magnetic target - always at
// width/2 and height/2 regardless of grid size - that widgets check first
// via snappedX()/snappedY() before falling back to grid rounding.
Canvas {
    id: root

    property real gridSize: 24
    property bool active: false
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 0
    property real targetHeight: 0

    // How close a widget's own center has to get to the screen's center
    // (in px) before it magnetically locks to it instead of the grid.
    property real centerThreshold: 10

    readonly property bool centeredX: Math.abs((targetX + targetWidth / 2) - width / 2) < 0.6
    readonly property bool centeredY: Math.abs((targetY + targetHeight / 2) - height / 2) < 0.6

    // Where a widget of size (w, h) currently at (rawX, rawY) should land -
    // snapped to the screen center line if it's within centerThreshold of
    // it, otherwise rounded to the nearest grid cell. Widgets call these
    // both for their live preview target (bound into targetX/targetY below)
    // and for the actual position they commit to on drag release, so the
    // two always agree.
    function snappedX(rawX, w) {
        let screenCenterX = width / 2
        if (Math.abs((rawX + w / 2) - screenCenterX) <= centerThreshold) {
            return screenCenterX - w / 2
        }
        return Math.round(rawX / gridSize) * gridSize
    }

    function snappedY(rawY, h) {
        let screenCenterY = height / 2
        if (Math.abs((rawY + h / 2) - screenCenterY) <= centerThreshold) {
            return screenCenterY - h / 2
        }
        return Math.round(rawY / gridSize) * gridSize
    }

    opacity: active ? 1.0 : 0.0
    visible: opacity > 0.001
    Behavior on opacity { NumberAnimation { duration: 150 } }

    onActiveChanged: requestPaint()
    onTargetXChanged: if (active) requestPaint()
    onTargetYChanged: if (active) requestPaint()
    onTargetWidthChanged: if (active) requestPaint()
    onTargetHeightChanged: if (active) requestPaint()
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

        // Screen-center guide lines - dim by default, bright + thick once
        // the target rect is actually locked onto that axis.
        let accent = Qt.color(Config.accent)
        let cx = Math.round(width / 2) + 0.5
        let cy = Math.round(height / 2) + 0.5

        ctx.beginPath()
        ctx.moveTo(cx, 0)
        ctx.lineTo(cx, height)
        ctx.strokeStyle = centeredX ? Qt.rgba(accent.r, accent.g, accent.b, 0.9) : Qt.rgba(accent.r, accent.g, accent.b, 0.35)
        ctx.lineWidth = centeredX ? 2 : 1
        ctx.stroke()

        ctx.beginPath()
        ctx.moveTo(0, cy)
        ctx.lineTo(width, cy)
        ctx.strokeStyle = centeredY ? Qt.rgba(accent.r, accent.g, accent.b, 0.9) : Qt.rgba(accent.r, accent.g, accent.b, 0.35)
        ctx.lineWidth = centeredY ? 2 : 1
        ctx.stroke()

        // Highlight the cell the widget is currently snapped to
        ctx.fillStyle = Qt.rgba(accent.r, accent.g, accent.b, 0.18)
        ctx.strokeStyle = Qt.rgba(accent.r, accent.g, accent.b, 0.9)
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.rect(targetX + 0.75, targetY + 0.75, targetWidth - 1.5, targetHeight - 1.5)
        ctx.fill()
        ctx.stroke()
    }
}
