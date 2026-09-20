pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

SettingsPage {
    id: root

    title: "Assistant"
    description: "Desktop character and the CLI that answers its chat panel."
    icon: "support_agent"

    // Detected by running `which <binary>` for each backend CLI once on load -
    // no credentials are ever touched here. Auth (a signed-in personal
    // subscription or an API key) is entirely each CLI's own business; this
    // widget only shells out to whichever one is selected.
    property bool claudeDetected: false
    property bool codexDetected: false
    property bool geminiDetected: false
    property bool ollamaDetected: false

    readonly property bool usingOllama: Config.assistantBackend === "ollama"

    readonly property var backends: [
        { id: "claude", label: "Claude Code", sub: "Anthropic - Pro/Max or API key",          detected: root.claudeDetected },
        { id: "codex",  label: "Codex CLI",   sub: "OpenAI - Plus/Pro or API key",            detected: root.codexDetected },
        { id: "gemini", label: "Gemini CLI",  sub: "Google - personal account or API key",    detected: root.geminiDetected },
        { id: "ollama", label: "Ollama",      sub: "Your own local or self-hosted model",     detected: root.ollamaDetected }
    ]

    function formatFileUrl(path) {
        if (!path) return ""
        if (path.startsWith("file://")) return path
        if (path.startsWith("/")) return "file://" + path
        return "file://" + Quickshell.env("HOME") + "/" + path
    }

    Process {
        id: claudeCheck
        command: ["which", "claude"]
        onExited: exitCode => root.claudeDetected = (exitCode === 0)
    }
    Process {
        id: codexCheck
        command: ["which", "codex"]
        onExited: exitCode => root.codexDetected = (exitCode === 0)
    }
    Process {
        id: geminiCheck
        command: ["which", "gemini"]
        onExited: exitCode => root.geminiDetected = (exitCode === 0)
    }
    Process {
        id: ollamaCheck
        command: ["which", "ollama"]
        onExited: exitCode => root.ollamaDetected = (exitCode === 0)
    }

    Component.onCompleted: {
        claudeCheck.running = true
        codexCheck.running = true
        geminiCheck.running = true
        ollamaCheck.running = true
    }

    // The character and the chat panel are one widget - the character is just
    // its collapsed form - so they're configured together rather than from the
    // separate Mascot page this replaced.
    // The character and the chat panel are one widget - the character is just
    // its collapsed form - so they're configured together rather than from the
    // separate Mascot page this replaced.
    SettingsCard {
        title: "Desktop Character"
        icon: "emoji_emotions"

        // Hero band: the avatar gets its own row with a caption, so the four
        // toggles below can all start at the card's left edge. Previously the
        // avatar sat in a column beside the first three rows, which left the
        // fourth row alone on a different left edge and stranded the avatar's
        // bottom edge ~50px above the stack it was supposed to align with.
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 120
                radius: SettingsStyle.controlRadius
                color: SettingsStyle.controlBg
                border.width: 1
                border.color: SettingsStyle.controlBorder
                clip: true

                Image {
                    id: avatarImage
                    anchors.fill: parent
                    anchors.margins: 8
                    fillMode: Image.PreserveAspectFit
                    // The asset is a square 128px PNG; sizing the decode to the
                    // box it is drawn in keeps it crisp without a full-res
                    // decode on every page open.
                    sourceSize.width: 120
                    sourceSize.height: 120
                    source: root.formatFileUrl(Config.builtinMascotDir + "/avatar.png")
                    visible: avatarImage.status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: avatarImage.status !== Image.Ready
                    text: "hide_image"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 32
                    color: Config.textMuted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: Config.showMascot !== false ? "Shown on your desktop" : "Hidden"
                    color: Config.showMascot !== false ? Config.accent : Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    text: "Drag the character anywhere on the desktop. Click it to expand the chat panel."
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    wrapMode: Text.WordWrap
                }
            }
        }

        SettingsSeparator {}

        SettingsToggleRow {
            title: "Enable Assistant"
            subtitle: "Show the animated character on your desktop"
            checked: Config.showMascot !== false
            onToggled: Config.showMascot = (Config.showMascot === false)
        }

        SettingsToggleRow {
            title: "Bop to the Beat"
            subtitle: "Pulse the character with the same audio throb as the bar"
            checked: Config.mascotAudioThrob !== false
            onToggled: Config.mascotAudioThrob = (Config.mascotAudioThrob === false)
            active: Config.showMascot !== false
        }

        // Off keeps the character on-screen but pinned to its idle pose -
        // battery/media/lock signals still arrive, they just stop changing
        // what's shown. For someone who wants it there but finds the dancing
        // distracting.
        SettingsToggleRow {
            title: "Animate Reactions"
            subtitle: "Let the character dance, cheer and react - off pins it to its idle pose"
            checked: Config.mascotAnimationsEnabled !== false
            onToggled: Config.mascotAnimationsEnabled = (Config.mascotAnimationsEnabled === false)
            active: Config.showMascot !== false
        }

        SettingsToggleRow {
            title: "Open the Assistant Panel"
            subtitle: "Expand the desktop character into the full chat panel"
            checked: Config.showAssistant !== false
            onToggled: Config.showAssistant = (Config.showAssistant === false)
            active: Config.showMascot !== false
        }
    }

    // Each row picks which already-installed CLI the assistant shells out to -
    // it runs that CLI's own one-shot headless mode, so whatever account it is
    // already signed into is what answers. Selectable even when not detected;
    // the widget surfaces a clear error if the binary isn't on PATH yet.
    SettingsCard {
        title: "Backend"
        icon: "terminal"

        SettingsList {
            Repeater {
                model: root.backends

                delegate: SettingsOptionRow {
                    required property var modelData

                    title: modelData.label
                    subtitle: modelData.sub
                    selected: Config.assistantBackend === modelData.id
                    statusColor: modelData.detected ? "#4caf50" : Config.textMuted
                    statusText: modelData.detected ? "Installed" : "Not found"
                    onClicked: Config.assistantBackend = modelData.id
                }
            }
        }

        SettingsNote {
            text: "No API keys are stored here. Sending a message runs the selected CLI in headless mode on this machine. Install - and for the first three, sign into - whichever one shows as Not found."
        }
    }

    SettingsCard {
        title: "Model & Timeout"
        icon: "tune"

        // One field that reads and writes whichever of Config.assistantModel /
        // Config.assistantOllamaModel matches the selected backend. They are
        // stored separately on purpose: they used to share one field, and
        // picking an Ollama model here or from the widget's own switcher
        // silently overwrote the --model override set for Claude/Codex/Gemini.
        SettingsField {
            label: root.usingOllama ? "Model (required for Ollama)" : "Model override (optional)"

            SettingsTextField {
                text: (root.usingOllama ? Config.assistantOllamaModel : Config.assistantModel) || ""
                placeholder: root.usingOllama
                    ? "e.g. gemma2:9b, mistral, qwen2.5 (defaults to gemma2:9b)"
                    : "Leave blank to use the CLI's default model"
                icon: "smart_toy"

                onEditingFinished: value => {
                    if (root.usingOllama) Config.assistantOllamaModel = value.trim()
                    else Config.assistantModel = value.trim()
                }
            }
        }

        // How long to wait before giving up on a reply - some backends,
        // models and questions genuinely take a while.
        SettingsField {
            label: "Response Timeout"
            hint: "Seconds to wait for a reply before giving up. 5-3600."

            SettingsTextField {
                id: timeoutField

                Layout.preferredWidth: 120
                Layout.fillWidth: false
                text: String(Config.assistantTimeoutSeconds || 120)
                icon: "timer"
                validator: IntValidator { bottom: 5; top: 3600 }

                onEditingFinished: value => {
                    const parsed = parseInt(value, 10)
                    Config.assistantTimeoutSeconds = (isNaN(parsed) || parsed < 5) ? 120 : Math.min(parsed, 3600)
                    timeoutField.text = String(Config.assistantTimeoutSeconds)
                }
            }
        }
    }
}
