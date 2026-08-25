import QtQuick
import ".."

// mpris/cava wave: a smooth mirrored waveform line sampled down from shellRoot.cavaBars,
// drawn on a Canvas rather than discrete bars.
// Orientation-agnostic on purpose - reads fine whether the bar is horizontal or vertical.
Item {
    id: waveRoot

    // Passed in explicitly by the parent (e.g. shellRootRef: shellRoot) since a bare
    // "shellRoot" id from the root shell file does not resolve across separate QML
    // documents - it's only visible within the file that declares it.
    property var shellRootRef: (typeof shellRoot !== "undefined") ? shellRoot : null

    readonly property var bars: (waveRoot.shellRootRef && waveRoot.shellRootRef.cavaBars) ? waveRoot.shellRootRef.cavaBars : []
    readonly property int sampleCount: 12
    readonly property real amplitudeScale: 0.85

    onBarsChanged: waveCanvas.requestPaint()
    onWidthChanged: waveCanvas.requestPaint()
    onHeightChanged: waveCanvas.requestPaint()

    Canvas {
        id: waveCanvas
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Threaded

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var arr = waveRoot.bars
            if (!arr || arr.length === 0 || width <= 0 || height <= 0) return

            var n = waveRoot.sampleCount
            var midY = height / 2
            var maxAmp = midY * waveRoot.amplitudeScale

            var top = []
            var bottom = []

            for (var i = 0; i < n; i++) {
                var idx = Math.floor((i / (n - 1)) * (arr.length - 1))
                var v = Math.max(0, Math.min(1, arr[idx] || 0))
                var x = (i / (n - 1)) * width
                var amp = v * maxAmp
                top.push({ x: x, y: midY - amp })
                bottom.push({ x: x, y: midY + amp })
            }

            ctx.fillStyle = Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.25)
            ctx.strokeStyle = Config.accent
            ctx.lineWidth = 1.5
            ctx.lineJoin = "round"
            ctx.lineCap = "round"

            ctx.beginPath()
            ctx.moveTo(top[0].x, top[0].y)
            for (var j = 1; j < top.length - 1; j++) {
                var xc = (top[j].x + top[j + 1].x) / 2
                var yc = (top[j].y + top[j + 1].y) / 2
                ctx.quadraticCurveTo(top[j].x, top[j].y, xc, yc)
            }
            ctx.lineTo(top[top.length - 1].x, top[top.length - 1].y)

            for (var k = bottom.length - 1; k > 0; k--) {
                var bx = (bottom[k].x + bottom[k - 1].x) / 2
                var by = (bottom[k].y + bottom[k - 1].y) / 2
                ctx.quadraticCurveTo(bottom[k].x, bottom[k].y, bx, by)
            }
            ctx.lineTo(bottom[0].x, bottom[0].y)
            ctx.closePath()

            ctx.fill()
            ctx.stroke()
        }
    }
}
