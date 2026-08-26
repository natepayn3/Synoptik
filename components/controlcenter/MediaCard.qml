import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import ".."

Item {
    id: cardRoot

    readonly property bool isStopped: mediaStatus === "Stopped" || mediaTitle === "Not Playing" || mediaTitle === ""

    Layout.fillWidth: true
    implicitHeight: mediaContainer.implicitHeight
    Layout.preferredHeight: implicitHeight

    property Item controlCenterPanel: null

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    // Bound to shellRoot's always-on playerctl follower (shell.qml) rather than
    // owning a separate Process here, so state stays fresh even while this
    // card isn't visible and matches what the bar's ActiveWindowCard shows.
    readonly property string mediaTitle: (typeof shellRoot !== "undefined" && shellRoot.mediaTitle) ? shellRoot.mediaTitle : "Not Playing"
    readonly property string mediaArtist: (typeof shellRoot !== "undefined" && shellRoot.mediaArtist) ? shellRoot.mediaArtist : "---"
    readonly property string mediaStatus: (typeof shellRoot !== "undefined" && shellRoot.mediaStatus) ? shellRoot.mediaStatus : "Stopped"
    readonly property string mediaArtUrl: (typeof shellRoot !== "undefined" && shellRoot.mediaArtUrl) ? shellRoot.mediaArtUrl : ""
    property var cavaBars: []

    // Per-track accent sampled from the album art (falls back to the theme
    // accent when there's no art, or until sampling completes).
    property color dynamicAccent: Config.accent
    onMediaArtUrlChanged: if (mediaArtUrl === "") dynamicAccent = Config.accent

    // Progress State
    property double trackPosition: 0
    property double trackLength: 0
    property string activePlayerName: ""

    signal sendCommand(var cmd)

    // Position Poller
    Process {
        id: mediaPosProc
        command: ["fish", "-c", "playerctl position; playerctl metadata mpris:length; playerctl metadata --format '{{playerName}}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                if (lines.length >= 1 && lines[0] !== "") {
                    let pos = parseFloat(lines[0]);
                    if (!isNaN(pos)) cardRoot.trackPosition = pos;
                }
                if (lines.length >= 2 && lines[1] !== "") {
                    let len = parseFloat(lines[1]);
                    if (!isNaN(len)) cardRoot.trackLength = len / 1000000.0;
                }
                if (lines.length >= 3 && lines[2].trim() !== "") {
                    cardRoot.activePlayerName = lines[2].trim();
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: Config.showControlCenter && cardRoot.mediaStatus === "Playing"
        repeat: true
        triggeredOnStart: true
        onTriggered: mediaPosProc.running = true
    }

    function formatTime(sec) {
        if (isNaN(sec) || sec <= 0) return "0:00";
        let m = Math.floor(sec / 60);
        let s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function seekRelative(offsetSec) {
        let sign = offsetSec >= 0 ? "+" : "-";
        let val = Math.abs(offsetSec);
        sendCommand(["playerctl", "position", `${val}${sign}`]);
        cardRoot.trackPosition = Math.max(0, cardRoot.trackPosition + offsetSec);
    }

    // Tiny hidden canvas used purely to sample an average color out of the
    // currently loaded album art. Downscaling onto a few pixels and averaging
    // them is a cheap approximation of "dominant color" - good enough to
    // drive a bold, per-track accent without a real clustering algorithm.
    Canvas {
        id: colorSampler
        width: 8
        height: 8
        visible: false
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        function sample() {
            if (artImage.status !== Image.Ready) return
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            try {
                ctx.drawImage(artImage, 0, 0, width, height)
                var data = ctx.getImageData(0, 0, width, height).data
                var r = 0, g = 0, b = 0, n = 0
                for (var i = 0; i < data.length; i += 4) {
                    if (data[i + 3] < 16) continue
                    r += data[i]; g += data[i + 1]; b += data[i + 2]
                    n++
                }
                if (n === 0) return
                var avg = Qt.rgba((r / n) / 255, (g / n) / 255, (b / n) / 255, 1.0)

                // Boost saturation and clamp lightness so muddy or near-black
                // covers still produce a bold, legible accent.
                var sat = Math.max(avg.hslSaturation, 0.5)
                var light = Math.min(Math.max(avg.hslLightness, 0.4), 0.62)
                cardRoot.dynamicAccent = Qt.hsla(avg.hslHue, sat, light, 1.0)
            } catch (e) {
                // Pixel readback can fail for some image sources - keep the
                // previous accent rather than breaking the card.
            }
        }
    }

    Connections {
        target: artImage
        function onStatusChanged() {
            if (artImage.status === Image.Ready) colorSampler.sample()
        }
    }

    // Ambient elevation glow - lifts the card off the panel, blooms harder
    // when a track is actually alive so idle state stays quiet.
    RectangularGlow {
        id: cardElevationGlow
        anchors.fill: mediaContainer
        glowRadius: 34
        spread: 0.14
        color: cardRoot.dynamicAccent
        cornerRadius: mediaContainer.radius
        opacity: cardRoot.isStopped ? 0.0 : (cardHover.hovered ? 0.5 : 0.3)

        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 400 } }
    }

    // ClippingRectangle (not plain Rectangle) so the blurred art backdrop
    // below actually respects the rounded corners instead of bleeding past
    // them - plain Rectangle.clip only clips to the square bounding box.
    ClippingRectangle {
        id: mediaContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: cardRoot.isStopped ? 48 : (contentCluster.implicitHeight + (cardRoot.cardMargin * 2))
        radius: Config.cornerRadius

        Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        color: cardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
        border.width: 1
        border.color: cardRoot.isStopped
            ? Qt.rgba(255, 255, 255, 0.1)
            : Qt.rgba(cardRoot.dynamicAccent.r, cardRoot.dynamicAccent.g, cardRoot.dynamicAccent.b, cardHover.hovered ? 0.5 : 0.24)

        HoverHandler { id: cardHover }

        // Full-bleed blurred album art backdrop - the real "wow" layer.
        // Mirrors the same fade-blur pattern used by Wallpaper.qml.
        Item {
            id: backdropLayer
            anchors.fill: parent
            visible: !cardRoot.isStopped && cardRoot.mediaArtUrl !== ""

            Image {
                id: backdropImage
                anchors.fill: parent
                source: cardRoot.mediaArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: 0.5

                Behavior on source {
                    SequentialAnimation {
                        NumberAnimation { target: backdropImage; property: "opacity"; to: 0.0; duration: 120 }
                        PropertyAction { target: backdropImage; property: "source" }
                        NumberAnimation { target: backdropImage; property: "opacity"; to: 0.5; duration: 300 }
                    }
                }
            }

            FastBlur {
                anchors.fill: backdropImage
                source: backdropImage
                radius: 64
            }

            // Legibility scrim, lightly duotoned with the extracted accent.
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.03 + cardRoot.dynamicAccent.r * 0.05, 0.03 + cardRoot.dynamicAccent.g * 0.05, 0.03 + cardRoot.dynamicAccent.b * 0.07, 0.58)

                Behavior on color { ColorAnimation { duration: 400 } }
            }
        }

        // Decorative glyph watermark - only needed when there's no real
        // photo doing that job for us.
        Watermark {
            icon: Config.getIcon("cc")
            iconSize: cardRoot.isStopped ? 60 : 150
            seed: 1
            activeVisible: cardRoot.isStopped || cardRoot.mediaArtUrl === ""
        }

        // ==========================================
        // 1. MINIMAL COMPACT BAR (WHEN STOPPED)
        // ==========================================
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            visible: cardRoot.isStopped
            opacity: cardRoot.isStopped ? 1.0 : 0.0
            spacing: 12
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Text {
                text: "music_off"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: Config.textMuted
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: "No Media Playing"
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            // Standby Play Trigger
            Item {
                implicitWidth: 32
                implicitHeight: 32
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: "play_arrow"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 22
                    color: idlePlayHover.hovered ? Config.accent : Config.textMuted
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                TapHandler { onTapped: cardRoot.sendCommand(["playerctl", "play-pause"]) }
                HoverHandler { id: idlePlayHover; cursorShape: Qt.PointingHandCursor }
            }
        }

        // ==========================================
        // 2. ACTIVE MEDIA VIEW (WHEN PLAYING / PAUSED)
        // ==========================================
        RowLayout {
            id: contentCluster
            anchors.centerIn: parent
            width: Math.min(parent.width - (cardRoot.cardMargin * 2), 620)
            spacing: 24
            visible: !cardRoot.isStopped
            opacity: !cardRoot.isStopped ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            // --- CIRCULAR VISUALIZER & ART ---
            Item {
                id: artContainer
                implicitWidth: 130
                implicitHeight: 130
                Layout.alignment: Qt.AlignVCenter

                Canvas {
                    id: visualizerCanvas
                    anchors.fill: parent
                    antialiasing: true

                    readonly property bool isVisualizerActive: cardRoot.visible
                        && cardRoot.mediaStatus === "Playing"

                    property real rotationAngle: 0.0

                    PropertyAnimation on rotationAngle {
                        from: 0.0
                        to: 2 * Math.PI
                        duration: 20000
                        loops: Animation.Infinite
                        running: visualizerCanvas.isVisualizerActive
                    }

                    onRotationAngleChanged: if (isVisualizerActive) requestPaint()
                    onWidthChanged: if (isVisualizerActive) requestPaint()
                    onHeightChanged: if (isVisualizerActive) requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        if (!visualizerCanvas.isVisualizerActive || !cardRoot.cavaBars || cardRoot.cavaBars.length === 0) return;

                        var centerX = width / 2;
                        var centerY = height / 2;
                        var innerRadius = 46;
                        var barCount = cardRoot.cavaBars.length;
                        var maxBarLength = 14;
                        var barWidth = 2.5;

                        ctx.save();
                        ctx.fillStyle = cardRoot.dynamicAccent;

                        for (var i = 0; i < barCount; i++) {
                            var angle = ((i * 2 * Math.PI) / barCount) + visualizerCanvas.rotationAngle;
                            var value = cardRoot.cavaBars[i] / 255.0;
                            var barLength = value * maxBarLength;

                            ctx.save();
                            ctx.translate(centerX, centerY);
                            ctx.rotate(angle);

                            var startY = innerRadius + 2;
                            var endY = startY + barLength;

                            var baseRadius = barWidth / 2;
                            var tipRadius = baseRadius + (value * 1.2);

                            ctx.beginPath();
                            ctx.moveTo(-baseRadius, startY);
                            ctx.lineTo(-tipRadius, endY);
                            ctx.arc(0, endY, tipRadius, Math.PI, 0, true);
                            ctx.lineTo(baseRadius, startY);
                            ctx.closePath();
                            ctx.fill();

                            ctx.restore();
                        }
                        ctx.restore();
                    }

                    Connections {
                        target: cardRoot
                        function onCavaBarsChanged() {
                            if (visualizerCanvas.isVisualizerActive) {
                                visualizerCanvas.requestPaint();
                            }
                        }
                        function onDynamicAccentChanged() {
                            if (visualizerCanvas.isVisualizerActive) {
                                visualizerCanvas.requestPaint();
                            }
                        }
                    }
                }

                // Halo behind the art - blooms brighter while actively playing
                RectangularGlow {
                    anchors.centerIn: parent
                    width: 96
                    height: 96
                    glowRadius: 20
                    spread: 0.25
                    color: cardRoot.dynamicAccent
                    cornerRadius: 48
                    opacity: visualizerCanvas.isVisualizerActive ? 0.6 : 0.25

                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    Behavior on color { ColorAnimation { duration: 400 } }
                }

                Item {
                    id: artDisc
                    width: 88
                    height: 88
                    anchors.centerIn: parent

                    // Slow vinyl-style spin while playing; freezes in place on pause.
                    // (0 -> 360 is visually seamless, so the per-loop reset never shows.)
                    PropertyAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 16000
                        loops: Animation.Infinite
                        running: visualizerCanvas.isVisualizerActive
                    }

                    Image {
                        id: artImage
                        anchors.fill: parent
                        source: cardRoot.mediaArtUrl ? cardRoot.mediaArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }

                    Rectangle {
                        id: maskTarget
                        anchors.fill: parent
                        radius: width / 2
                        color: "black"
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: parent
                        source: artImage
                        maskSource: maskTarget
                        visible: artImage.status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "music_note"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 34
                        color: Config.textMuted
                        visible: artImage.status !== Image.Ready
                    }

                    // Thin accent ring so the disc reads as a distinct object, not a cutout
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 1.5
                        border.color: Qt.rgba(255, 255, 255, 0.18)
                    }
                }
            }

            // --- METADATA, PROGRESS & CONTROLS ---
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 10

                // Track Info & Player Source - big, bold, left-aligned poster
                // treatment instead of a small centered caption.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        id: titleText
                        text: cardRoot.mediaTitle
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontTitle) * 1.25
                        font.weight: Font.Black
                        font.letterSpacing: -0.5
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft

                        layer.enabled: Config.clockShowGlow && cardRoot.mediaStatus === "Playing"
                        layer.effect: Glow {
                            radius: 10
                            samples: 20
                            color: cardRoot.dynamicAccent
                            spread: 0.2
                            transparentBorder: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            id: artistText
                            text: cardRoot.mediaArtist
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Player Source Badge
                        Rectangle {
                            implicitWidth: playerBadgeText.implicitWidth + 10
                            implicitHeight: 16
                            radius: 8
                            color: Qt.rgba(cardRoot.dynamicAccent.r, cardRoot.dynamicAccent.g, cardRoot.dynamicAccent.b, 0.18)
                            visible: cardRoot.activePlayerName !== ""

                            Behavior on color { ColorAnimation { duration: 400 } }

                            Text {
                                id: playerBadgeText
                                anchors.centerIn: parent
                                text: cardRoot.activePlayerName.toUpperCase()
                                color: cardRoot.dynamicAccent
                                font.family: Config.sysFont
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }
                    }
                }

                // Progress - a bold full-width spectrum bar doubling as the
                // scrub control, instead of a thin flat line.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: cardRoot.trackLength > 0

                    Text {
                        text: cardRoot.formatTime(cardRoot.trackPosition)
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        color: Config.textMuted
                    }

                    Item {
                        id: progressBarTrack
                        Layout.fillWidth: true
                        implicitHeight: 32

                        HoverHandler {
                            id: progressHover
                            onHoveredChanged: spectrumCanvas.requestPaint()
                        }

                        Canvas {
                            id: spectrumCanvas
                            anchors.fill: parent
                            antialiasing: true

                            readonly property real playedRatio: cardRoot.trackLength > 0
                                ? Math.min(1.0, cardRoot.trackPosition / cardRoot.trackLength)
                                : 0

                            // Eased per-bin amplitudes, retained across paints so the
                            // waveform flows toward new values instead of jumping.
                            property var smoothed: []

                            onPlayedRatioChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            Connections {
                                target: cardRoot
                                function onCavaBarsChanged() { spectrumCanvas.requestPaint() }
                                function onDynamicAccentChanged() { spectrumCanvas.requestPaint() }
                            }

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                var bars = cardRoot.cavaBars;
                                var binCount = (bars && bars.length > 0) ? bars.length : 32;

                                if (spectrumCanvas.smoothed.length !== binCount) {
                                    var seed = [];
                                    for (var k = 0; k < binCount; k++) seed.push(0);
                                    spectrumCanvas.smoothed = seed;
                                }

                                var midY = height / 2;
                                var maxAmp = Math.max(2, height / 2 - 2);
                                var step = width / binCount;
                                var points = [];

                                for (var i = 0; i < binCount; i++) {
                                    var raw = (bars && bars.length > 0) ? bars[i] / 255.0 : 0.08;
                                    // Exponential ease toward the latest sample - this is
                                    // what makes the shape flow rather than snap per-frame.
                                    spectrumCanvas.smoothed[i] += (raw - spectrumCanvas.smoothed[i]) * 0.35;
                                    var amp = Math.max(0.05, spectrumCanvas.smoothed[i]) * maxAmp;
                                    points.push({ x: (i + 0.5) * step, amp: amp });
                                }

                                // Trace a smooth closed blob through the top/bottom mirrored
                                // amplitudes using quadratic curves between bin midpoints -
                                // no hard bar edges anywhere.
                                function traceBlob() {
                                    ctx.beginPath();
                                    ctx.moveTo(0, midY - points[0].amp);
                                    var p;
                                    for (p = 1; p < points.length; p++) {
                                        var xc = (points[p - 1].x + points[p].x) / 2;
                                        var yc = midY - (points[p - 1].amp + points[p].amp) / 2;
                                        ctx.quadraticCurveTo(points[p - 1].x, midY - points[p - 1].amp, xc, yc);
                                    }
                                    ctx.lineTo(width, midY - points[points.length - 1].amp);
                                    ctx.lineTo(width, midY + points[points.length - 1].amp);
                                    for (p = points.length - 1; p > 0; p--) {
                                        var xc2 = (points[p].x + points[p - 1].x) / 2;
                                        var yc2 = midY + (points[p].amp + points[p - 1].amp) / 2;
                                        ctx.quadraticCurveTo(points[p].x, midY + points[p].amp, xc2, yc2);
                                    }
                                    ctx.lineTo(0, midY + points[0].amp);
                                    ctx.closePath();
                                }

                                var playedX = width * spectrumCanvas.playedRatio;
                                var accent = cardRoot.dynamicAccent;

                                // Played portion - soft vertical glow gradient for a liquid feel
                                ctx.save();
                                ctx.beginPath();
                                ctx.rect(0, 0, Math.max(0, playedX), height);
                                ctx.clip();
                                traceBlob();
                                var grad = ctx.createLinearGradient(0, midY - maxAmp, 0, midY + maxAmp);
                                grad.addColorStop(0.0, Qt.rgba(accent.r, accent.g, accent.b, 0.15));
                                grad.addColorStop(0.5, accent);
                                grad.addColorStop(1.0, Qt.rgba(accent.r, accent.g, accent.b, 0.15));
                                ctx.fillStyle = grad;
                                ctx.fill();
                                ctx.restore();

                                // Unplayed portion - flat, dim
                                ctx.save();
                                ctx.beginPath();
                                ctx.rect(playedX, 0, Math.max(0, width - playedX), height);
                                ctx.clip();
                                traceBlob();
                                ctx.fillStyle = Qt.rgba(255, 255, 255, progressHover.hovered ? 0.22 : 0.13);
                                ctx.fill();
                                ctx.restore();
                            }
                        }

                        MouseArea {
                            id: progressSeekArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (cardRoot.trackLength > 0) {
                                    let targetSec = (mouse.x / width) * cardRoot.trackLength;
                                    cardRoot.sendCommand(["playerctl", "position", targetSec.toFixed(2)]);
                                    cardRoot.trackPosition = targetSec;
                                }
                            }
                        }
                    }

                    Text {
                        text: cardRoot.formatTime(cardRoot.trackLength)
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        color: Config.textMuted
                    }
                }

                // Transport Controls with 10s Replay / Forward
                RowLayout {
                    spacing: 16
                    Layout.alignment: Qt.AlignHCenter

                    // Replay 10s
                    Item {
                        implicitWidth: 32
                        implicitHeight: 32
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: cardRoot.dynamicAccent
                            opacity: replayHover.hovered ? 0.14 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "replay_10"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 20
                            color: replayHover.hovered ? cardRoot.dynamicAccent : Config.textMuted
                            scale: replayHover.hovered ? 1.1 : 1.0
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        }

                        TapHandler { onTapped: cardRoot.seekRelative(-10) }
                        HoverHandler { id: replayHover; cursorShape: Qt.PointingHandCursor }
                    }

                    // Previous
                    Item {
                        implicitWidth: 34
                        implicitHeight: 34
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: cardRoot.dynamicAccent
                            opacity: prevHover.hovered ? 0.14 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "skip_previous"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 24
                            color: prevHover.hovered ? cardRoot.dynamicAccent : Config.textMain
                            scale: prevHover.hovered ? 1.1 : 1.0
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        }

                        TapHandler { onTapped: cardRoot.sendCommand(["playerctl", "previous"]) }
                        HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                    }

                    // Play / Pause - the focal point: a solid accent disc instead of a bare glyph
                    Item {
                        implicitWidth: 52
                        implicitHeight: 52
                        Layout.alignment: Qt.AlignVCenter

                        RectangularGlow {
                            anchors.fill: playCircle
                            glowRadius: 18
                            spread: 0.3
                            color: cardRoot.dynamicAccent
                            cornerRadius: playCircle.radius
                            opacity: cardRoot.mediaStatus === "Playing" ? 0.6 : 0.35
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Behavior on color { ColorAnimation { duration: 400 } }
                        }

                        Rectangle {
                            id: playCircle
                            anchors.centerIn: parent
                            width: playHover.hovered ? 48 : 44
                            height: width
                            radius: width / 2
                            color: cardRoot.dynamicAccent

                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 400 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: cardRoot.mediaStatus === "Playing" ? "pause" : "play_arrow"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 24
                            color: Config.bgBase
                        }

                        TapHandler { onTapped: cardRoot.sendCommand(["playerctl", "play-pause"]) }
                        HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
                    }

                    // Next
                    Item {
                        implicitWidth: 34
                        implicitHeight: 34
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: cardRoot.dynamicAccent
                            opacity: nextHover.hovered ? 0.14 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "skip_next"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 24
                            color: nextHover.hovered ? cardRoot.dynamicAccent : Config.textMain
                            scale: nextHover.hovered ? 1.1 : 1.0
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        }

                        TapHandler { onTapped: cardRoot.sendCommand(["playerctl", "next"]) }
                        HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                    }

                    // Forward 10s
                    Item {
                        implicitWidth: 32
                        implicitHeight: 32
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: cardRoot.dynamicAccent
                            opacity: forwardHover.hovered ? 0.14 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "forward_10"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 20
                            color: forwardHover.hovered ? cardRoot.dynamicAccent : Config.textMuted
                            scale: forwardHover.hovered ? 1.1 : 1.0
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        }

                        TapHandler { onTapped: cardRoot.seekRelative(10) }
                        HoverHandler { id: forwardHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }
}
