import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

MorphingFlyout {
    id: root

    isOpen: Config.showAudio
    alignRight: true
    panelWidth: 360
    panelHeight: mainLayout.implicitHeight + 40

    property int systemVolume: 50
    property bool isMuted: false
    property int inputVolume: 50
    property bool isInputMuted: false

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 14

        // ==========================================
        // CARD 1: AUDIO OUTPUT
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: outputLayout.implicitHeight + 24
            color: outputCardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius

            Behavior on color { ColorAnimation { duration: 150 } }

            HoverHandler { id: outputCardHover }

            ColumnLayout {
                id: outputLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

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
                        text: root.isMuted ? "Muted" : root.systemVolume + "%"
                        color: Config.accent
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                    }
                }

                // Output Slider Block
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: root.isMuted ? "volume_off" : "volume_up"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 18
                        color: Config.accent

                        TapHandler {
                            onTapped: {
                                root.isMuted = !root.isMuted
                                muteWriteProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
                                muteWriteProc.running = true
                            }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }

                    Slider {
                        id: volumeSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: root.systemVolume

                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 4
                            width: volumeSlider.availableWidth
                            height: implicitHeight
                            radius: 2
                            color: Qt.rgba(255, 255, 255, 0.1)

                            Rectangle {
                                width: volumeSlider.visualPosition * parent.width
                                height: parent.height
                                color: Config.accent
                                radius: 2
                            }
                        }

                        handle: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            implicitWidth: 12
                            implicitHeight: 12
                            radius: 6
                            color: Config.textMain
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        onMoved: {
                            root.systemVolume = Math.round(value)
                            if (root.isMuted) root.isMuted = false
                            volumeWriteProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (value / 100).toFixed(2)]
                            volumeWriteProc.running = true
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
                            implicitHeight: 34
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
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: model.isDefault
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "✓"
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
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
            implicitHeight: inputLayout.implicitHeight + 24
            color: inputCardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius

            Behavior on color { ColorAnimation { duration: 150 } }

            HoverHandler { id: inputCardHover }

            ColumnLayout {
                id: inputLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

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
                        text: root.isInputMuted ? "Muted" : root.inputVolume + "%"
                        color: Config.accent
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                    }
                }

                // Input Slider Block
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: root.isInputMuted ? "mic_off" : "mic"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 18
                        color: Config.accent

                        TapHandler {
                            onTapped: {
                                root.isInputMuted = !root.isInputMuted
                                muteWriteProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
                                muteWriteProc.running = true
                            }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }

                    Slider {
                        id: micSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: root.inputVolume

                        background: Rectangle {
                            x: micSlider.leftPadding
                            y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 4
                            width: micSlider.availableWidth
                            height: implicitHeight
                            radius: 2
                            color: Qt.rgba(255, 255, 255, 0.1)

                            Rectangle {
                                width: micSlider.visualPosition * parent.width
                                height: parent.height
                                color: Config.accent
                                radius: 2
                            }
                        }

                        handle: Rectangle {
                            x: micSlider.leftPadding + micSlider.visualPosition * (micSlider.availableWidth - width)
                            y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
                            implicitWidth: 12
                            implicitHeight: 12
                            radius: 6
                            color: Config.textMain
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        onMoved: {
                            root.inputVolume = Math.round(value)
                            if (root.isInputMuted) root.isInputMuted = false
                            volumeWriteProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", (value / 100).toFixed(2)]
                            volumeWriteProc.running = true
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
                            implicitHeight: 34
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
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: model.isDefault
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "✓"
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
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

    // Backend Handlers
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
                    root.systemVolume = Math.round(parseFloat(match[1]) * 100)
                    root.isMuted = cleaned.includes("[MUTED]")
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
                    root.inputVolume = Math.round(parseFloat(match[1]) * 100)
                    root.isInputMuted = cleaned.includes("[MUTED]")
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
        running: root.isOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: audioQueryProc.running = true
    }
}