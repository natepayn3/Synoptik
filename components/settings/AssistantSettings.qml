import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: root

    // Detected by running `which <binary>` for each backend CLI once on
    // load - no credentials are ever touched here. Auth (a signed-in
    // personal subscription or an API key) is entirely each CLI's own
    // business; this widget only shells out to whichever one is selected.
    property bool claudeDetected: false
    property bool codexDetected: false
    property bool geminiDetected: false
    property bool ollamaDetected: false

    function isBackendSelected(b) { return Config.assistantBackend === b }

    function formatFileUrl(path) {
        if (!path) return ""
        if (path.startsWith("file://")) return path
        if (path.startsWith("/")) return "file://" + path
        return "file://" + Quickshell.env("HOME") + "/" + path
    }

    Process {
        id: claudeCheck
        command: ["which", "claude"]
        onExited: (exitCode) => root.claudeDetected = (exitCode === 0)
    }
    Process {
        id: codexCheck
        command: ["which", "codex"]
        onExited: (exitCode) => root.codexDetected = (exitCode === 0)
    }
    Process {
        id: geminiCheck
        command: ["which", "gemini"]
        onExited: (exitCode) => root.geminiDetected = (exitCode === 0)
    }
    Process {
        id: ollamaCheck
        command: ["which", "ollama"]
        onExited: (exitCode) => root.ollamaDetected = (exitCode === 0)
    }

    Component.onCompleted: {
        claudeCheck.running = true
        codexCheck.running = true
        geminiCheck.running = true
        ollamaCheck.running = true
    }

    readonly property var backends: [
        { id: "claude", label: "Claude Code", sub: "Anthropic - Pro/Max or API key", detected: root.claudeDetected },
        { id: "codex", label: "Codex CLI", sub: "OpenAI - Plus/Pro or API key", detected: root.codexDetected },
        { id: "gemini", label: "Gemini CLI", sub: "Google - personal account or API key", detected: root.geminiDetected },
        { id: "ollama", label: "Ollama", sub: "Your own local or self-hosted model", detected: root.ollamaDetected }
    ]

    // --- STANDARD ASSISTANT SETTINGS VIEW ---
    // Flickable + ScrollBar wrapper, same pattern as CavaSettings.qml/the
    // other settings pages - this page grew tall enough (avatar + toggles,
    // backend rows, model/timeout fields, disclaimer) to overflow the panel
    // with no way to reach the bottom without it.
    Flickable {
        id: mainFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            active: mainFlickable.moving || mainFlickable.flicking
        }

        ColumnLayout {
        id: mainColumn
        width: parent.width - 8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        Text {
            text: "ASSISTANT CONFIGURATION"
            color: Config.textMain
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontSubhead)
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            text: "No API keys are stored here. Sending a message runs the selected CLI in headless mode on this machine - Claude Code/Codex CLI/Gemini CLI use whatever account or key they're already signed into, and Ollama talks to your own local or self-hosted model with no account at all. Install (and sign into, for the first three) whichever one shows as Not Found above."
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontMicro)
            wrapMode: Text.WordWrap
        }

        // AVATAR + master toggles, folded in from the old standalone Mascot
        // settings page - it's the same widget now (the character is just
        // its collapsed form), so there's no reason to manage it from a
        // separate page.
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Rectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
                Layout.alignment: Qt.AlignTop
                color: Qt.rgba(0, 0, 0, 0.2)
                radius: Config.cornerRadius
                border.color: Qt.rgba(255, 255, 255, 0.1)
                border.width: 1
                clip: true

                Image {
                    id: avatarImage
                    anchors.fill: parent
                    anchors.margins: 8
                    fillMode: Image.PreserveAspectFit
                    source: root.formatFileUrl(Config.builtinMascotDir + "/avatar.png")
                    visible: avatarImage.status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: avatarImage.status !== Image.Ready
                    text: "hide_image"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 28
                    color: Config.textMuted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 12

                // TOGGLE: ENABLE ASSISTANT
                // Master switch for the whole widget - character and chat
                // panel both. Open the Assistant Panel below only matters
                // while this is on.
                SettingsToggleRow {
                    title: "Enable Assistant"
                    subtitle: "Show the animated character on your desktop"
                    checked: Config.showMascot !== false
                    onToggled: Config.showMascot = (Config.showMascot === false)
                }

                // TOGGLE: AUDIO THROB
                SettingsToggleRow {
                    title: "Bop to the Beat"
                    subtitle: "Pulse the character with the same audio throb as the bar"
                    checked: Config.mascotAudioThrob !== false
                    onToggled: Config.mascotAudioThrob = (Config.mascotAudioThrob === false)
                }

                // TOGGLE: REACTION ANIMATIONS
                // Off keeps the character on-screen but pinned to its idle
                // pose - battery/media/lock signals etc. still work, they
                // just stop changing what's shown. The full off switch above
                // removes the character entirely; this is for someone who
                // wants it there but finds the dancing/cheering distracting.
                SettingsToggleRow {
                    title: "Animate Reactions"
                    subtitle: "Let the character dance, cheer, and react - off keeps it on its idle pose"
                    checked: Config.mascotAnimationsEnabled !== false
                    onToggled: Config.mascotAnimationsEnabled = (Config.mascotAnimationsEnabled === false)
                }
            }
        }

        // TOGGLE: EXPAND ASSISTANT PANEL
        SettingsToggleRow {
            title: "Open the Assistant Panel"
            subtitle: "Expand the desktop character into the full chat panel"
            checked: Config.showAssistant !== false
            onToggled: Config.showAssistant = (Config.showAssistant === false)
        }

        Text {
            text: "BACKEND"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontMicro)
            font.bold: true
        }

        // Each row picks which already-installed CLI the assistant shells
        // out to - it runs that CLI's own one-shot headless mode, so
        // whatever account/subscription it's already signed into is what
        // answers. Selectable even when not detected (the widget will just
        // surface a clear error if that binary isn't on PATH yet).
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.backends

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: Config.cornerRadius / 2
                    color: root.isBackendSelected(modelData.id)
                        ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.16)
                        : (rowHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(0, 0, 0, 0.15))
                    border.width: root.isBackendSelected(modelData.id) ? 1 : 0
                    border.color: Config.accent

                    Behavior on color { ColorAnimation { duration: 120 } }

                    // Plain anchors instead of RowLayout/ColumnLayout - the dot is
                    // pinned to the left edge, the status label to the right edge,
                    // and the title/subtitle column fills the space between them.
                    // Every row's dot and status label anchor to the same parent
                    // edges, so they land at identical x positions on every row
                    // regardless of how long any of the label text is.
                    Rectangle {
                        id: statusDot
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: modelData.detected ? "#4caf50" : Config.textMuted
                    }

                    Text {
                        id: statusLabel
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: modelData.detected ? "Installed" : "Not found"
                        color: modelData.detected ? "#4caf50" : Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    Column {
                        anchors.left: statusDot.right
                        anchors.leftMargin: 10
                        anchors.right: statusLabel.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            horizontalAlignment: Text.AlignLeft
                            text: modelData.label
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.bold: true
                            font.pixelSize: Config.size(Config.fontCaption)
                        }
                        Text {
                            horizontalAlignment: Text.AlignLeft
                            text: modelData.sub
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                        }
                    }

                    TapHandler { onTapped: Config.assistantBackend = modelData.id }
                    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                }
            }
        }

        // MODEL OVERRIDE FIELD (optional, passed as --model to the CLI) -
        // one field that reads/writes whichever of Config.assistantModel /
        // Config.assistantOllamaModel matches the currently selected
        // backend, since those are stored separately (see
        // assistantOllamaModel's own comment in DesktopExtrasConfig.qml for
        // why: they used to share one field, and picking/pulling an Ollama
        // model here or from the assistant widget's own switcher would
        // silently overwrite whatever --model override was set for
        // Claude/Codex/Gemini).
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: Config.assistantBackend === "ollama" ? "Model (required for Ollama)" : "Model override (optional)"
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Config.cornerRadius / 2
                color: Qt.rgba(0, 0, 0, 0.15)
                border.color: modelInput.activeFocus ? Config.accent : "transparent"
                border.width: 1
                clip: true

                TextInput {
                    id: modelInput
                    anchors.fill: parent
                    anchors.margins: 6
                    text: (Config.assistantBackend === "ollama" ? Config.assistantOllamaModel : Config.assistantModel) || ""
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    clip: true

                    Text {
                        anchors.fill: parent
                        text: Config.assistantBackend === "ollama" ? "e.g. gemma2:9b, mistral, qwen2.5 (defaults to gemma2:9b)" : "Leave blank to use the CLI's default model"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        verticalAlignment: Text.AlignVCenter
                        visible: modelInput.text.length === 0 && !modelInput.activeFocus
                    }

                    onEditingFinished: {
                        if (Config.assistantBackend === "ollama") Config.assistantOllamaModel = text.trim()
                        else Config.assistantModel = text.trim()
                    }
                    HoverHandler { cursorShape: Qt.IBeamCursor }
                }
            }
        }

        // RESPONSE TIMEOUT FIELD - how long to wait before giving up on a
        // reply. Some backends/models/questions genuinely take a while.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: "Response timeout (seconds)"
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
            }

            Rectangle {
                implicitWidth: 100
                implicitHeight: 30
                radius: Config.cornerRadius / 2
                color: Qt.rgba(0, 0, 0, 0.15)
                border.color: timeoutInput.activeFocus ? Config.accent : "transparent"
                border.width: 1
                clip: true

                TextInput {
                    id: timeoutInput
                    anchors.fill: parent
                    anchors.margins: 6
                    text: String(Config.assistantTimeoutSeconds || 120)
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    clip: true
                    validator: IntValidator { bottom: 5; top: 3600 }

                    onEditingFinished: {
                        let val = parseInt(text, 10)
                        Config.assistantTimeoutSeconds = (isNaN(val) || val < 5) ? 120 : Math.min(val, 3600)
                        text = String(Config.assistantTimeoutSeconds)
                    }
                    HoverHandler { cursorShape: Qt.IBeamCursor }
                }
            }
        }

        }
        }
    }

