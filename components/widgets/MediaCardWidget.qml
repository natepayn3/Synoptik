import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import ".."

// Detached floating counterpart to controlcenter/MediaCard.qml - a small
// panel showing the same thumbnail art + radial cava visualizer + transport
// controls, so playback stays visible/controllable without keeping Control
// Center open.
//
// A real FloatingWindow (an xdg-shell toplevel), not a PanelWindow - moving
// and resizing hand off to startSystemMove()/startSystemResize() so Hyprland
// itself drives the interaction exactly like any other floating window
// (snapping, cursor tracking, min/max-size clamping all included for free).
// An earlier version reimplemented drag-resize by hand on a layer-shell
// PanelWindow; that never tracked the cursor as cleanly as the compositor's
// own implementation does. Because it's a normal toplevel, Hyprland's window
// rules decide float/size/position, not us - see hyprland.lua for a
// `title:^(Synoptik Media Card)$` float rule.
FloatingWindow {
    id: mediaCardWindow
    title: "Synoptik Media Card"
    visible: Config.showDesktopMediaCard

    readonly property size minCardSize: Qt.size(160, 90)
    readonly property size maxCardSize: Qt.size(480, 420)
    minimumSize: minCardSize
    maximumSize: maxCardSize

    // Only the initial/preferred size, not the live one - Quickshell treats
    // `width`/`height` as read-write output tracking the actual (possibly
    // still-being-dragged) size, and warns if a binding drives them directly.
    // Clamped defensively - a still-open earlier bug in this file let a
    // stored size balloon past these bounds once already.
    implicitWidth: Math.max(minCardSize.width, Math.min(maxCardSize.width, Config.mediaCardWidth > 0 ? Config.mediaCardWidth : 232))
    implicitHeight: Math.max(minCardSize.height, Math.min(maxCardSize.height, Config.mediaCardHeight > 0 ? Config.mediaCardHeight : 108))

    color: "transparent"

    readonly property real cardPad: 10
    readonly property bool isVertical: height > width

    // Debounced so a live native resize (which fires width/heightChanged
    // continuously) doesn't spam writes - Config.saveSettings() itself also
    // debounces, but this avoids even touching the in-memory Config each
    // frame of the drag.
    Timer {
        id: sizeSaveDebounce
        interval: 400
        onTriggered: Config.saveMediaCardSize(mediaCardWindow.width, mediaCardWindow.height)
    }
    onWidthChanged: sizeSaveDebounce.restart()
    onHeightChanged: sizeSaveDebounce.restart()

    readonly property bool isStopped: mediaTitle === "Not Playing" || mediaTitle === "" || mediaStatus === "Stopped"
    readonly property string mediaTitle: (typeof shellRoot !== "undefined" && shellRoot.mediaTitle) ? shellRoot.mediaTitle : "Not Playing"
    readonly property string mediaArtist: (typeof shellRoot !== "undefined" && shellRoot.mediaArtist) ? shellRoot.mediaArtist : "---"
    readonly property string mediaStatus: (typeof shellRoot !== "undefined" && shellRoot.mediaStatus) ? shellRoot.mediaStatus : "Stopped"
    readonly property string mediaArtUrl: (typeof shellRoot !== "undefined" && shellRoot.mediaArtUrl) ? shellRoot.mediaArtUrl : ""
    property var cavaBars: []

    // Per-track accent sampled from the album art, same approach as
    // MediaCard.qml's colorSampler below.
    property color dynamicAccent: Config.accent
    onMediaArtUrlChanged: if (mediaArtUrl === "") dynamicAccent = Config.accent

    property double trackPosition: 0
    property double trackLength: 0

    function formatTime(sec) {
        if (isNaN(sec) || sec <= 0) return "0:00"
        let m = Math.floor(sec / 60)
        let s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function sendCommand(cmd) {
        mediaControlProc.command = cmd
        mediaControlProc.running = true
    }

    function seekRelative(offsetSec) {
        let sign = offsetSec >= 0 ? "+" : "-"
        let val = Math.abs(offsetSec)
        sendCommand(["playerctl", "position", `${val}${sign}`])
        mediaCardWindow.trackPosition = Math.max(0, mediaCardWindow.trackPosition + offsetSec)
    }

    Process { id: mediaControlProc; running: false }

    Process {
        id: mediaPosProc
        command: ["fish", "-c", "playerctl position; playerctl metadata mpris:length"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                if (lines.length >= 1 && lines[0] !== "") {
                    let pos = parseFloat(lines[0])
                    if (!isNaN(pos)) mediaCardWindow.trackPosition = pos
                }
                if (lines.length >= 2 && lines[1] !== "") {
                    let len = parseFloat(lines[1])
                    if (!isNaN(len)) mediaCardWindow.trackLength = len / 1000000.0
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: Config.showDesktopMediaCard && mediaCardWindow.mediaStatus === "Playing"
        repeat: true
        triggeredOnStart: true
        onTriggered: mediaPosProc.running = true
    }

    // Dedicated cava feed scaled 0-255 (not the shared Config.cavaService,
    // whose bars are pre-normalized 0-1 for the desktop visualizer/ambient
    // breathing) - same config shape as ControlCenter.qml's MediaCard feed,
    // gated on this panel's own visibility instead of Control Center's.
    Process {
        id: cavaProc
        command: ["fish", "-c", "printf '[general]\\nbars = 32\\nsensitivity = 150\\n[output]\\nmethod = raw\\ndata_format = ascii\\nascii_max_range = 255\\nbar_delimiter = 59\\nframe_delimiter = 10\\n' | cava -p /dev/stdin"]
        running: Config.showDesktopMediaCard && mediaCardWindow.mediaStatus === "Playing"

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                let clean = data.trim()
                if (!clean) return
                let points = clean.split(';')
                let arr = []
                for (let i = 0; i < points.length; i++) {
                    if (points[i] !== "") arr.push(parseInt(points[i], 10) || 0)
                }
                if (arr.length > 0) mediaCardWindow.cavaBars = arr
            }
        }
    }

    // Tiny hidden canvas used purely to sample an average color out of the
    // currently loaded album art - identical approach to MediaCard.qml.
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
            // getContext() can momentarily return null right as this Canvas
            // is created (this widget mounts immediately at startup, unlike
            // MediaCard.qml's copy which only ever mounts once Control
            // Center is already open and settled).
            if (!ctx) return
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
                var sat = Math.max(avg.hslSaturation, 0.5)
                var light = Math.min(Math.max(avg.hslLightness, 0.4), 0.62)
                mediaCardWindow.dynamicAccent = Qt.hsla(avg.hslHue, sat, light, 1.0)
            } catch (e) {
                // Pixel readback can fail for some image sources - keep the
                // previous accent rather than breaking the widget.
            }
        }
    }

    Connections {
        target: artImage
        function onStatusChanged() {
            if (artImage.status === Image.Ready) colorSampler.sample()
        }
    }

    // ClippingRectangle (not plain Rectangle) so the blurred art backdrop
    // respects the rounded corners - same reasoning as MediaCard.qml.
    ClippingRectangle {
        id: cardBg
        anchors.fill: parent
        radius: Config.cornerRadius

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        color: cardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.05)
        border.width: 1
        border.color: mediaCardWindow.isStopped
            ? Qt.rgba(255, 255, 255, 0.1)
            : Qt.rgba(mediaCardWindow.dynamicAccent.r, mediaCardWindow.dynamicAccent.g, mediaCardWindow.dynamicAccent.b, cardHover.hovered ? 0.5 : 0.24)

        HoverHandler { id: cardHover }

        // Full-bleed blurred album art backdrop, same as MediaCard.qml.
        Item {
            anchors.fill: parent
            visible: !mediaCardWindow.isStopped && mediaCardWindow.mediaArtUrl !== ""

            Image {
                id: backdropImage
                anchors.fill: parent
                source: mediaCardWindow.mediaArtUrl
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
                radius: 48
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.03 + mediaCardWindow.dynamicAccent.r * 0.05, 0.03 + mediaCardWindow.dynamicAccent.g * 0.05, 0.03 + mediaCardWindow.dynamicAccent.b * 0.07, 0.6)
                Behavior on color { ColorAnimation { duration: 400 } }
            }
        }

        Watermark {
            icon: Config.getIcon("cc")
            iconSize: mediaCardWindow.isStopped ? 26 : 60
            seed: 7
            activeVisible: mediaCardWindow.isStopped || mediaCardWindow.mediaArtUrl === ""
        }

        // ==========================================
        // 1. MINIMAL COMPACT BAR (WHEN STOPPED)
        // ==========================================
        RowLayout {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 24)
            visible: mediaCardWindow.isStopped
            opacity: mediaCardWindow.isStopped ? 1.0 : 0.0
            spacing: 8
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Text {
                text: "music_off"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 16
                color: Config.textMuted
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: "No Media Playing"
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.bold: true
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
            }
        }

        // ==========================================
        // 2. ACTIVE MEDIA VIEW (WHEN PLAYING / PAUSED)
        // ==========================================
        // GridLayout (not RowLayout) so resizing the panel into a taller-
        // than-wide shape naturally reflows this from side-by-side to
        // stacked - columns: 2 sits art+metadata side by side, columns: 1
        // drops metadata onto its own row underneath the art.
        GridLayout {
            id: contentCluster
            anchors.fill: parent
            anchors.margins: mediaCardWindow.cardPad
            columns: mediaCardWindow.isVertical ? 1 : 2
            columnSpacing: 14
            rowSpacing: 8
            visible: !mediaCardWindow.isStopped
            opacity: !mediaCardWindow.isStopped ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            // --- CIRCULAR VISUALIZER & ART (smaller version of MediaCard.qml's) ---
            // Sized directly off mediaCardWindow's own resized width/height
            // (not off contentCluster/Layout.fill*) so it grows or shrinks
            // to fill its row (side-by-side layout) or column (stacked
            // layout) as the panel is resized, without any circular
            // layout->size->layout feedback.
            Item {
                id: artContainer

                readonly property real availW: mediaCardWindow.width - (mediaCardWindow.cardPad * 2)
                readonly property real availH: mediaCardWindow.height - (mediaCardWindow.cardPad * 2)
                // Side-by-side: art is square, capped to a fraction of the
                // row's width so the metadata column keeps room to breathe.
                // Stacked: art is square, capped to a fraction of the
                // column's height so title/controls keep room underneath.
                readonly property real artSize: Math.max(40, mediaCardWindow.isVertical
                    ? Math.min(availW, availH * 0.62)
                    : Math.min(availH, availW * 0.46))

                implicitWidth: artSize
                implicitHeight: artSize
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

                Canvas {
                    id: visualizerCanvas
                    anchors.fill: parent
                    antialiasing: true

                    readonly property bool isVisualizerActive: mediaCardWindow.visible
                        && mediaCardWindow.mediaStatus === "Playing"

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

                        if (!visualizerCanvas.isVisualizerActive || !mediaCardWindow.cavaBars || mediaCardWindow.cavaBars.length === 0) return;

                        var centerX = width / 2;
                        var centerY = height / 2;
                        var innerRadius = artContainer.artSize * 0.346;
                        var barCount = mediaCardWindow.cavaBars.length;
                        var maxBarLength = artContainer.artSize * 0.115;
                        var barWidth = Math.max(1.5, artContainer.artSize * 0.0257);

                        ctx.save();
                        ctx.fillStyle = mediaCardWindow.dynamicAccent;

                        for (var i = 0; i < barCount; i++) {
                            var angle = ((i * 2 * Math.PI) / barCount) + visualizerCanvas.rotationAngle;
                            var value = mediaCardWindow.cavaBars[i] / 255.0;
                            var barLength = value * maxBarLength;

                            ctx.save();
                            ctx.translate(centerX, centerY);
                            ctx.rotate(angle);

                            var startY = innerRadius + 1;
                            var endY = startY + barLength;

                            var baseRadius = barWidth / 2;
                            var tipRadius = baseRadius + (value * 0.9);

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
                        target: mediaCardWindow
                        function onCavaBarsChanged() {
                            if (visualizerCanvas.isVisualizerActive) visualizerCanvas.requestPaint();
                        }
                        function onDynamicAccentChanged() {
                            if (visualizerCanvas.isVisualizerActive) visualizerCanvas.requestPaint();
                        }
                    }
                }

                RectangularGlow {
                    anchors.centerIn: parent
                    width: artContainer.artSize * 0.744
                    height: width
                    glowRadius: Math.max(8, artContainer.artSize * 0.18)
                    spread: 0.25
                    color: mediaCardWindow.dynamicAccent
                    cornerRadius: width / 2
                    opacity: visualizerCanvas.isVisualizerActive ? 0.6 : 0.25

                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    Behavior on color { ColorAnimation { duration: 400 } }
                }

                Item {
                    id: artDisc
                    width: artContainer.artSize * 0.692
                    height: width
                    anchors.centerIn: parent

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
                        source: mediaCardWindow.mediaArtUrl ? mediaCardWindow.mediaArtUrl : ""
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
                        font.pixelSize: Math.max(14, artContainer.artSize * 0.256)
                        color: Config.textMuted
                        visible: artImage.status !== Image.Ready
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.18)
                    }
                }
            }

            // --- METADATA, PROGRESS & CONTROLS ---
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: mediaCardWindow.mediaTitle
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro) + 1
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: mediaCardWindow.mediaArtist
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro) - 1
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Slim progress / scrub bar
                Item {
                    id: progressTrack
                    Layout.fillWidth: true
                    implicitHeight: 12
                    visible: mediaCardWindow.trackLength > 0

                    readonly property real playedRatio: mediaCardWindow.trackLength > 0
                        ? Math.min(1.0, mediaCardWindow.trackPosition / mediaCardWindow.trackLength)
                        : 0

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 3
                        radius: 1.5
                        color: Qt.rgba(255, 255, 255, 0.15)
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * progressTrack.playedRatio
                        height: 3
                        radius: 1.5
                        color: mediaCardWindow.dynamicAccent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (mediaCardWindow.trackLength > 0) {
                                let targetSec = (mouse.x / width) * mediaCardWindow.trackLength;
                                mediaCardWindow.sendCommand(["playerctl", "position", targetSec.toFixed(2)]);
                                mediaCardWindow.trackPosition = targetSec;
                            }
                        }
                    }
                }

                // Transport Controls
                RowLayout {
                    spacing: 10
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2

                    // Previous
                    Item {
                        implicitWidth: 24
                        implicitHeight: 24
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: mediaCardWindow.dynamicAccent
                            opacity: prevHover.hovered ? 0.14 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "skip_previous"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            color: prevHover.hovered ? mediaCardWindow.dynamicAccent : Config.textMain
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        TapHandler { onTapped: mediaCardWindow.sendCommand(["playerctl", "previous"]) }
                        HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                    }

                    // Play / Pause
                    Item {
                        implicitWidth: 34
                        implicitHeight: 34
                        Layout.alignment: Qt.AlignVCenter

                        RectangularGlow {
                            anchors.fill: playCircle
                            glowRadius: 12
                            spread: 0.3
                            color: mediaCardWindow.dynamicAccent
                            cornerRadius: playCircle.radius
                            opacity: mediaCardWindow.mediaStatus === "Playing" ? 0.6 : 0.35
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Behavior on color { ColorAnimation { duration: 400 } }
                        }

                        Rectangle {
                            id: playCircle
                            anchors.centerIn: parent
                            width: playHover.hovered ? 32 : 30
                            height: width
                            radius: width / 2
                            color: mediaCardWindow.dynamicAccent

                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 400 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: mediaCardWindow.mediaStatus === "Playing" ? "pause" : "play_arrow"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 17
                            color: Config.bgBase
                        }

                        TapHandler { onTapped: mediaCardWindow.sendCommand(["playerctl", "play-pause"]) }
                        HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
                    }

                    // Next
                    Item {
                        implicitWidth: 24
                        implicitHeight: 24
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: mediaCardWindow.dynamicAccent
                            opacity: nextHover.hovered ? 0.14 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "skip_next"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            color: nextHover.hovered ? mediaCardWindow.dynamicAccent : Config.textMain
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        TapHandler { onTapped: mediaCardWindow.sendCommand(["playerctl", "next"]) }
                        HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }

        // Re-attach / close button - always on top so it never falls
        // through to the move/resize areas beneath it.
        Item {
            id: closeButton
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 5
            implicitWidth: 18
            implicitHeight: 18
            z: 50
            opacity: closeHover.hovered ? 1.0 : 0.45
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(0, 0, 0, 0.45)
            }

            Text {
                anchors.centerIn: parent
                text: "close"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 12
                color: "#ffffff"
            }

            TapHandler { onTapped: Config.showDesktopMediaCard = false }
            HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
        }

        // --- NATIVE RESIZE EDGES/CORNERS ---
        // Handing off to startSystemResize() means Hyprland's own resize
        // implementation drives the whole interaction - same code path as
        // any other floating window - so there's no custom drag math left
        // to go janky.
        component ResizeEdge: MouseArea {
            required property int edges

            hoverEnabled: true
            z: 100
            cursorShape: {
                if (edges === (Qt.LeftEdge | Qt.TopEdge) || edges === (Qt.RightEdge | Qt.BottomEdge)) return Qt.SizeFDiagCursor
                if (edges === (Qt.RightEdge | Qt.TopEdge) || edges === (Qt.LeftEdge | Qt.BottomEdge)) return Qt.SizeBDiagCursor
                if (edges === Qt.LeftEdge || edges === Qt.RightEdge) return Qt.SizeHorCursor
                return Qt.SizeVerCursor
            }
            onPressed: mediaCardWindow.startSystemResize(edges)
        }

        readonly property real edgeThickness: 6
        readonly property real cornerSize: 14

        ResizeEdge {
            edges: Qt.TopEdge
            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: cardBg.cornerSize; rightMargin: cardBg.cornerSize }
            height: cardBg.edgeThickness
        }
        ResizeEdge {
            edges: Qt.BottomEdge
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: cardBg.cornerSize; rightMargin: cardBg.cornerSize }
            height: cardBg.edgeThickness
        }
        ResizeEdge {
            edges: Qt.LeftEdge
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: cardBg.cornerSize; bottomMargin: cardBg.cornerSize }
            width: cardBg.edgeThickness
        }
        ResizeEdge {
            edges: Qt.RightEdge
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: cardBg.cornerSize; bottomMargin: cardBg.cornerSize }
            width: cardBg.edgeThickness
        }
        ResizeEdge {
            edges: Qt.LeftEdge | Qt.TopEdge
            anchors { top: parent.top; left: parent.left }
            width: cardBg.cornerSize; height: cardBg.cornerSize
        }
        ResizeEdge {
            edges: Qt.RightEdge | Qt.TopEdge
            anchors { top: parent.top; right: parent.right }
            width: cardBg.cornerSize; height: cardBg.cornerSize
        }
        ResizeEdge {
            edges: Qt.LeftEdge | Qt.BottomEdge
            anchors { bottom: parent.bottom; left: parent.left }
            width: cardBg.cornerSize; height: cardBg.cornerSize
        }
        ResizeEdge {
            edges: Qt.RightEdge | Qt.BottomEdge
            anchors { bottom: parent.bottom; right: parent.right }
            width: cardBg.cornerSize; height: cardBg.cornerSize
        }

        // --- MOVE (native) + RIGHT-CLICK WIDGET MENU ---
        // Declared after the visuals/controls/resize edges above so they
        // keep click priority, but z:-1 makes that explicit too.
        MouseArea {
            id: dragArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            z: -1

            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) mediaCardWindow.startSystemMove()
            }

            onClicked: (mouse) => {
                if (widgetMenu.visible) {
                    widgetMenu.close()
                    return
                }
                if (mouse.button === Qt.RightButton) {
                    widgetMenu.openAt(mouse.x, mouse.y, cardBg, mediaCardWindow.width, mediaCardWindow.height)
                    return
                }
                Config.closeWidgetMenus()
            }
        }

        WidgetContextMenu { id: widgetMenu }
    }
}
