import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: audioModule

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    implicitWidth: mainLayout.implicitWidth + (cardMargin * 2)
    implicitHeight: mainLayout.implicitHeight + (cardMargin * 2)

    property int systemVolume: 50
    property bool isMuted: false
    property int inputVolume: 50
    property bool isInputMuted: false

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: audioModule.cardMargin
        spacing: audioModule.cardMargin

        // ==========================================
        // CARD 1: AUDIO OUTPUT
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitWidth: 360 
            implicitHeight: outputLayout.implicitHeight + (audioModule.cardMargin * 2)
            color: outputCardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius
            clip: true

            Behavior on color { ColorAnimation { duration: 150 } }

            HoverHandler { id: outputCardHover }

            ColumnLayout {
                id: outputLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: audioModule.cardMargin
                spacing: audioModule.cardMargin

                // Audio Output Header
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "AUDIO OUTPUT"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontTitle)
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: audioModule.isMuted ? "Muted" : audioModule.systemVolume + "%"
                        color: Config.accent
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                    }
                }

                // Output Slider Block
                RowLayout {
                    Layout.fillWidth: true
                    spacing: audioModule.cardMargin

                    Text {
                        text: audioModule.isMuted ? "volume_off" : "volume_up"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 24
                        color: Config.accent

                        TapHandler {
                            onTapped: {
                                audioModule.isMuted = !audioModule.isMuted
                                muteWriteProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
                                muteWriteProc.running = true
                            }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }

                    Slider {
                        id: volumeSlider
                        Layout.fillWidth: true
                        implicitHeight: 32
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                        from: 0
                        to: 100
                        value: audioModule.systemVolume

                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding + (volumeSlider.availableHeight / 2) - (height / 2)
                            width: volumeSlider.availableWidth
                            height: 6
                            radius: 3
                            color: Qt.rgba(255, 255, 255, 0.12)

                            Rectangle {
                                width: volumeSlider.visualPosition * parent.width
                                height: parent.height
                                color: audioModule.isMuted ? Config.textMuted : Config.accent
                                radius: 3
                            }
                        }

                        handle: Rectangle {
                            id: outHandle

                            readonly property real baseWidth: 12
                            readonly property real baseHeight: 24

                            property real stretch: 0.0
                            property real popScale: 1.0

                            width: Math.max(8, baseWidth + (stretch * 18))
                            height: Math.max(16, baseHeight - (stretch * 11.67))
                            radius: height / 2
                            color: Config.textMain

                            transform: Scale {
                                origin.x: outHandle.width / 2
                                origin.y: outHandle.height / 2
                                xScale: outHandle.popScale
                                yScale: outHandle.popScale
                            }

                            x: volumeSlider.leftPadding + (volumeSlider.visualPosition * volumeSlider.availableWidth) - (width / 2)
                            y: volumeSlider.topPadding + (volumeSlider.availableHeight / 2) - (height / 2)

                            states: [
                                State {
                                    name: "dragging"
                                    when: volumeSlider.pressed
                                    PropertyChanges { target: outHandle; stretch: 1.2; popScale: 1.0 }
                                }
                            ]

                            transitions: [
                                Transition {
                                    from: "dragging"
                                    to: ""
                                    SequentialAnimation {
                                        ParallelAnimation {
                                            NumberAnimation { target: outHandle; property: "stretch"; to: -0.4; duration: 100; easing.type: Easing.OutQuad }
                                            NumberAnimation { target: outHandle; property: "popScale"; to: 1.25; duration: 100; easing.type: Easing.OutBack }
                                        }
                                        ParallelAnimation {
                                            NumberAnimation { target: outHandle; property: "stretch"; to: 0.0; duration: 250; easing.type: Easing.OutBack }
                                            NumberAnimation { target: outHandle; property: "popScale"; to: 1.0; duration: 250; easing.type: Easing.OutBack }
                                        }
                                    }
                                }
                            ]

                            Connections {
                                target: volumeSlider
                                function onValueChanged() {
                                    if (!volumeSlider.pressed) outExternalMorphAnim.restart()
                                }
                            }

                            SequentialAnimation {
                                id: outExternalMorphAnim
                                ParallelAnimation {
                                    NumberAnimation { target: outHandle; property: "stretch"; to: 1.2; duration: 120; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: outHandle; property: "popScale"; to: 1.0; duration: 120; easing.type: Easing.OutCubic }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: outHandle; property: "stretch"; to: -0.4; duration: 100; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: outHandle; property: "popScale"; to: 1.25; duration: 100; easing.type: Easing.OutBack }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: outHandle; property: "stretch"; to: 0.0; duration: 250; easing.type: Easing.OutBack }
                                    NumberAnimation { target: outHandle; property: "popScale"; to: 1.0; duration: 250; easing.type: Easing.OutBack }
                                }
                            }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        onMoved: {
                            audioModule.systemVolume = Math.round(value)
                            if (audioModule.isMuted) audioModule.isMuted = false
                            volWriteTimer.restart()
                        }
                    }
                }

                // Sink Devices List
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: ListModel { id: sinkModel }

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: model.isDefault ? 38 : 34
                            radius: Config.cornerRadius / 2
                            color: model.isDefault ? Qt.rgba(255, 255, 255, 0.12) : (itemHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")
                            border.color: model.isDefault ? Config.accent : "transparent"
                            border.width: model.isDefault ? 1 : 0

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                Text {
                                    text: model.sinkName
                                    color: model.isDefault ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: model.isDefault ? Config.size(Config.fontBody) : Config.size(Config.fontCaption)
                                    font.bold: model.isDefault
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "✓"
                                    font.family: Config.sysFont
                                    font.pixelSize: model.isDefault ? Config.size(Config.fontBody) : Config.size(Config.fontCaption)
                                    font.bold: true
                                    color: Config.accent
                                    visible: model.isDefault
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    sinkSetProc.command = ["wpctl", "set-default", model.sinkTarget]
                                    sinkSetProc.running = true
                                }
                            }
                            HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }
        }

        // ==========================================
        // CARD 2: AUDIO INPUT
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitWidth: 360
            implicitHeight: inputLayout.implicitHeight + (audioModule.cardMargin * 2)
            color: inputCardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius

            Behavior on color { ColorAnimation { duration: 150 } }

            HoverHandler { id: inputCardHover }

            ColumnLayout {
                id: inputLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: audioModule.cardMargin
                spacing: audioModule.cardMargin

                // Audio Input Header
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "AUDIO INPUT"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontTitle)
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: audioModule.isInputMuted ? "Muted" : audioModule.inputVolume + "%"
                        color: Config.accent
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                    }
                }

                // Input Slider Block
                RowLayout {
                    Layout.fillWidth: true
                    spacing: audioModule.cardMargin

                    Text {
                        text: audioModule.isInputMuted ? "mic_off" : "mic"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 24
                        color: Config.accent

                        TapHandler {
                            onTapped: {
                                audioModule.isInputMuted = !audioModule.isInputMuted
                                muteWriteProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
                                muteWriteProc.running = true
                            }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }

                    Slider {
                        id: micSlider
                        Layout.fillWidth: true
                        implicitHeight: 32
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                        from: 0
                        to: 100
                        value: audioModule.inputVolume

                        background: Rectangle {
                            x: micSlider.leftPadding
                            y: micSlider.topPadding + (micSlider.availableHeight / 2) - (height / 2)
                            width: micSlider.availableWidth
                            height: 6
                            radius: 3
                            color: Qt.rgba(255, 255, 255, 0.12)

                            Rectangle {
                                width: micSlider.visualPosition * parent.width
                                height: parent.height
                                color: audioModule.isInputMuted ? Config.textMuted : Config.accent
                                radius: 3
                            }
                        }

                        handle: Rectangle {
                            id: inHandle

                            readonly property real baseWidth: 12
                            readonly property real baseHeight: 24

                            property real stretch: 0.0
                            property real popScale: 1.0

                            width: Math.max(8, baseWidth + (stretch * 18))
                            height: Math.max(16, baseHeight - (stretch * 11.67))
                            radius: height / 2
                            color: Config.textMain

                            transform: Scale {
                                origin.x: inHandle.width / 2
                                origin.y: inHandle.height / 2
                                xScale: inHandle.popScale
                                yScale: inHandle.popScale
                            }

                            x: micSlider.leftPadding + (micSlider.visualPosition * micSlider.availableWidth) - (width / 2)
                            y: micSlider.topPadding + (micSlider.availableHeight / 2) - (height / 2)

                            states: [
                                State {
                                    name: "dragging"
                                    when: micSlider.pressed
                                    PropertyChanges { target: inHandle; stretch: 1.2; popScale: 1.0 }
                                }
                            ]

                            transitions: [
                                Transition {
                                    from: "dragging"
                                    to: ""
                                    SequentialAnimation {
                                        ParallelAnimation {
                                            NumberAnimation { target: inHandle; property: "stretch"; to: -0.4; duration: 100; easing.type: Easing.OutQuad }
                                            NumberAnimation { target: inHandle; property: "popScale"; to: 1.25; duration: 100; easing.type: Easing.OutBack }
                                        }
                                        ParallelAnimation {
                                            NumberAnimation { target: inHandle; property: "stretch"; to: 0.0; duration: 250; easing.type: Easing.OutBack }
                                            NumberAnimation { target: inHandle; property: "popScale"; to: 1.0; duration: 250; easing.type: Easing.OutBack }
                                        }
                                    }
                                }
                            ]

                            Connections {
                                target: micSlider
                                function onValueChanged() {
                                    if (!micSlider.pressed) inExternalMorphAnim.restart()
                                }
                            }

                            SequentialAnimation {
                                id: inExternalMorphAnim
                                ParallelAnimation {
                                    NumberAnimation { target: inHandle; property: "stretch"; to: 1.2; duration: 120; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: inHandle; property: "popScale"; to: 1.0; duration: 120; easing.type: Easing.OutCubic }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: inHandle; property: "stretch"; to: -0.4; duration: 100; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: inHandle; property: "popScale"; to: 1.25; duration: 100; easing.type: Easing.OutBack }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: inHandle; property: "stretch"; to: 0.0; duration: 250; easing.type: Easing.OutBack }
                                    NumberAnimation { target: inHandle; property: "popScale"; to: 1.0; duration: 250; easing.type: Easing.OutBack }
                                }
                            }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        onMoved: {
                            audioModule.inputVolume = Math.round(value)
                            if (audioModule.isInputMuted) audioModule.isInputMuted = false
                            micWriteTimer.restart()
                        }
                    }
                }

                // Source Devices List
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: ListModel { id: sourceModel }

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: model.isDefault ? 38 : 34
                            radius: Config.cornerRadius / 2
                            color: model.isDefault ? Qt.rgba(255, 255, 255, 0.12) : (itemHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")
                            border.color: model.isDefault ? Config.accent : "transparent"
                            border.width: model.isDefault ? 1 : 0

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                Text {
                                    text: model.sourceName
                                    color: model.isDefault ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: model.isDefault ? Config.size(Config.fontBody) : Config.size(Config.fontCaption)
                                    font.bold: model.isDefault
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "✓"
                                    font.family: Config.sysFont
                                    font.pixelSize: model.isDefault ? Config.size(Config.fontBody) : Config.size(Config.fontCaption)
                                    font.bold: true
                                    color: Config.accent
                                    visible: model.isDefault
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    sinkSetProc.command = ["wpctl", "set-default", model.sourceTarget]
                                    sinkSetProc.running = true
                                }
                            }
                            HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }
        }
    }

    // Backend Process Handlers
    Timer {
        id: volWriteTimer
        interval: 30
        repeat: false
        onTriggered: {
            volumeWriteProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (volumeSlider.value / 100).toFixed(2)]
            volumeWriteProc.running = true
        }
    }

    Timer {
        id: micWriteTimer
        interval: 30
        repeat: false
        onTriggered: {
            volumeWriteProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", (micSlider.value / 100).toFixed(2)]
            volumeWriteProc.running = true
        }
    }

    Timer {
        id: debounceAudioTimer
        interval: 150 
        running: false
        onTriggered: {
            volumeReadProc.running = true
            micReadProc.running = true
        }
    }

    Process {
        id: pulseEventStream
        command: ["stdbuf", "-oL", "pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("sink") || data.includes("source")) {
                    debounceAudioTimer.restart()
                }
            }
        }
    }

    Process {
        id: audioQueryProc
        command: ["wpctl", "status"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n")
                sinkModel.clear()
                sourceModel.clear()
                
                let seenSinkIds = {}
                let seenSourceIds = {}
                let targetBlock = 0
                let hasDefaultSink = false
                let hasDefaultSource = false

                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i]
                    if (line.includes("Sinks:")) { targetBlock = 1; continue; }
                    if (line.includes("Sources:")) { targetBlock = 2; continue; }
                    if (line.includes("Filters:") || line.includes("Streams:") || line.includes("Settings:")) { 
                        targetBlock = 0
                    }

                    if (line.includes("├─") || line.includes("└─")) continue;

                    let match = line.match(/(\*\s*)?\s*(\d+)\.\s+(.*)/)
                    if (match) {
                        let isDef = (match[1] !== undefined && match[1].includes("*"))
                        let id = match[2].trim()
                        let rawName = match[3].trim()
                        let cleanName = rawName.split("[")[0].replace(/[├─└─│]/g, "").trim()
                        if (cleanName === "") continue;

                        if (targetBlock === 1) {
                            if (seenSinkIds[id]) continue;
                            seenSinkIds[id] = true
                            let finalDef = isDef && !hasDefaultSink
                            if (finalDef) hasDefaultSink = true
                            sinkModel.append({ isDefault: finalDef, sinkTarget: id, sinkName: cleanName })
                        } else if (targetBlock === 2) {
                            if (seenSourceIds[id]) continue;
                            seenSourceIds[id] = true
                            let finalDef = isDef && !hasDefaultSource
                            if (finalDef) hasDefaultSource = true
                            sourceModel.append({ isDefault: finalDef, sourceTarget: id, sourceName: cleanName })
                        }
                    }
                }
                volumeReadProc.running = true
                micReadProc.running = true
            }
        }
    }

    Process {
        id: volumeReadProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let cleaned = this.text.trim()
                let match = cleaned.match(/Volume:\s+([0-9.]+)/)
                if (match) {
                    audioModule.systemVolume = Math.round(parseFloat(match[1]) * 100)
                    audioModule.isMuted = cleaned.includes("[MUTED]")
                }
            }
        }
    }

    Process {
        id: micReadProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let cleaned = this.text.trim()
                let match = cleaned.match(/Volume:\s+([0-9.]+)/)
                if (match) {
                    audioModule.inputVolume = Math.round(parseFloat(match[1]) * 100)
                    audioModule.isInputMuted = cleaned.includes("[MUTED]")
                }
            }
        }
    }

    Process { id: volumeWriteProc; running: false }
    Process { id: muteWriteProc; running: false }
    Process { id: sinkSetProc; running: false; onExited: audioQueryProc.running = true }

    Timer {
        id: pollTimer
        interval: 3000
        running: Config.showAudio
        repeat: true
        triggeredOnStart: true
        onTriggered: audioQueryProc.running = true
    }
}