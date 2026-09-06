import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
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

    // Default badge images live in the shell's own assets/badges folder - drop
    // image files there and they show up here automatically. Quickshell.shellDir
    // is a plain filesystem path (QString), not a URL - Qt.resolvedUrl(...)
    // is what turns it into the file:// URL FolderListModel.folder actually
    // needs, same as UnifiedSurface.qml/SystemSounds.qml's identical
    // baseDir + "assets/" construction.
    readonly property string badgesDir: {
        let baseDir = Quickshell.shellDir.toString()
        if (!baseDir.endsWith("/")) baseDir += "/"
        return Qt.resolvedUrl(baseDir + "assets/badges")
    }

    property bool showBrowser: false
    property string currentBrowserPath: "file://" + Quickshell.env("HOME")

    // --- STANDARD ASSISTANT SETTINGS VIEW ---
    // Flickable + ScrollBar wrapper, same pattern as CavaSettings.qml/the
    // other settings pages - this page grew tall enough (backend rows,
    // model/timeout fields, badge preview + image galleries, disclaimer) to
    // overflow the panel with no way to reach the bottom without it.
    Flickable {
        id: mainFlickable
        anchors.fill: parent
        visible: !root.showBrowser
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

        // TOGGLE: ENABLE ASSISTANT
        SettingsToggleRow {
            title: "Enable Desktop Assistant"
            subtitle: "Show the draggable assistant bubble on your desktop"
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

        // MODEL OVERRIDE FIELD (optional, passed as --model to the CLI)
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
                    text: Config.assistantModel || ""
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    clip: true

                    Text {
                        anchors.fill: parent
                        text: Config.assistantBackend === "ollama" ? "e.g. llama3.2, mistral, qwen2.5 (defaults to llama3.2)" : "Leave blank to use the CLI's default model"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        verticalAlignment: Text.AlignVCenter
                        visible: modelInput.text.length === 0 && !modelInput.activeFocus
                    }

                    onEditingFinished: Config.assistantModel = text.trim()
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

        // --- BADGE: shown in the header and inline next to every assistant
        // reply, same image both places (AssistantWidget.qml's AssistantBadge
        // component reads this same Config.assistantBadgePath).
        Text {
            text: "BADGE"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontMicro)
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item {
                implicitWidth: 72
                implicitHeight: 72

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(0, 0, 0, 0.2)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.15)
                }

                Text {
                    anchors.centerIn: parent
                    text: "smart_toy"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 34
                    color: Config.accent
                    visible: previewImg.status !== AnimatedImage.Ready
                }

                AnimatedImage {
                    id: previewImg
                    anchors.fill: parent
                    anchors.margins: 4
                    source: Config.assistantBadgePath ? root.formatFileUrl(Config.assistantBadgePath) : ""
                    fillMode: Image.PreserveAspectCrop
                    playing: true
                    visible: false
                }

                Rectangle {
                    id: previewMask
                    anchors.fill: previewImg
                    radius: width / 2
                    color: "black"
                    visible: false
                }

                OpacityMask {
                    anchors.fill: previewImg
                    source: previewImg
                    maskSource: previewMask
                    visible: previewImg.status === AnimatedImage.Ready
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: Config.assistantBadgePath ? Config.assistantBadgePath.replace(/^file:\/\//, "") : "Using default icon"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 8

                    Rectangle {
                        implicitWidth: browseText.implicitWidth + 24
                        implicitHeight: 26
                        radius: Config.cornerRadius / 2
                        color: browseHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                        Text {
                            id: browseText
                            anchors.centerIn: parent
                            text: "BROWSE"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            color: browseHover.hovered ? Config.bgBase : Config.textMain
                        }

                        TapHandler { onTapped: root.showBrowser = true }
                        HoverHandler { id: browseHover; cursorShape: Qt.PointingHandCursor }
                    }

                    Rectangle {
                        visible: Config.assistantBadgePath !== ""
                        implicitWidth: resetText.implicitWidth + 24
                        implicitHeight: 26
                        radius: Config.cornerRadius / 2
                        color: resetHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.08)

                        Text {
                            id: resetText
                            anchors.centerIn: parent
                            text: "USE DEFAULT ICON"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            color: Config.textMuted
                        }

                        TapHandler { onTapped: Config.assistantBadgePath = "" }
                        HoverHandler { id: resetHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }

        // Bundled gallery - scans assets/badges/ in this shell's own install,
        // so dropping image files there is all that's needed to add more.
        // This folder ships with the shell and gets overwritten on updates,
        // so it's only ever used for the shell's own bundled presets - see
        // "Your images" below for anything the user adds.
        Text {
            text: "DEFAULT IMAGES"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontMicro)
            font.bold: true
        }

        FolderListModel {
            id: defaultBadges
            folder: root.badgesDir
            showDirs: false
            nameFilters: ["*.gif", "*.png", "*.jpg", "*.jpeg", "*.webp"]
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: defaultBadges

                Rectangle {
                    id: defaultThumb
                    width: 64
                    height: 64
                    radius: 32
                    color: Qt.rgba(0, 0, 0, 0.2)
                    border.width: Config.assistantBadgePath === filePath ? 2 : 1
                    border.color: Config.assistantBadgePath === filePath ? Config.accent : Qt.rgba(255, 255, 255, 0.15)

                    AnimatedImage {
                        id: defaultThumbImg
                        anchors.fill: parent
                        anchors.margins: 3
                        source: fileUrl
                        fillMode: Image.PreserveAspectCrop
                        playing: false
                        visible: false
                    }

                    Rectangle {
                        id: defaultThumbMask
                        anchors.fill: defaultThumbImg
                        radius: width / 2
                        color: "black"
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: defaultThumbImg
                        source: defaultThumbImg
                        maskSource: defaultThumbMask
                    }

                    TapHandler { onTapped: Config.assistantBadgePath = filePath }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }

            Text {
                visible: defaultBadges.count === 0
                text: "No default images yet - drop image files into the shell's assets/badges folder, or browse for one below."
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                wrapMode: Text.WordWrap
                width: 260
            }
        }

        // User-uploaded gallery - remembers the path of anything browsed to
        // below (not a copy of the file; it stays wherever it already was)
        // so it comes back as a selectable thumbnail instead of a one-off
        // pick. Stored in settings.json, which - unlike assets/badges/ - is
        // gitignored and untouched by shell updates.
        Text {
            text: "YOUR IMAGES"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontMicro)
            font.bold: true
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: Config.assistantCustomBadges || []

                Rectangle {
                    id: customThumb
                    width: 64
                    height: 64
                    radius: 32
                    color: Qt.rgba(0, 0, 0, 0.2)
                    border.width: Config.assistantBadgePath === modelData ? 2 : 1
                    border.color: Config.assistantBadgePath === modelData ? Config.accent : Qt.rgba(255, 255, 255, 0.15)

                    AnimatedImage {
                        id: customThumbImg
                        anchors.fill: parent
                        anchors.margins: 3
                        source: root.formatFileUrl(modelData)
                        fillMode: Image.PreserveAspectCrop
                        playing: false
                        visible: false
                    }

                    Rectangle {
                        id: customThumbMask
                        anchors.fill: customThumbImg
                        radius: width / 2
                        color: "black"
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: customThumbImg
                        source: customThumbImg
                        maskSource: customThumbMask
                    }

                    TapHandler { onTapped: Config.assistantBadgePath = modelData }
                    HoverHandler { id: customThumbHover; cursorShape: Qt.PointingHandCursor }

                    // Remove from the list (never deletes the actual file -
                    // this only ever remembered its path).
                    Rectangle {
                        visible: customThumbHover.hovered
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: -2
                        width: 18
                        height: 18
                        radius: 9
                        color: Qt.rgba(0, 0, 0, 0.7)

                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 11
                            color: "#ffffff"
                        }

                        TapHandler {
                            onTapped: {
                                if (Config.assistantBadgePath === modelData) Config.assistantBadgePath = ""
                                Config.removeCustomBadge(modelData)
                            }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }

            Rectangle {
                visible: !Config.assistantCustomBadges || Config.assistantCustomBadges.length === 0
                implicitWidth: emptyCustomText.implicitWidth + 20
                implicitHeight: emptyCustomText.implicitHeight + 20
                radius: Config.cornerRadius / 2
                color: Qt.rgba(0, 0, 0, 0.15)

                Text {
                    id: emptyCustomText
                    anchors.centerIn: parent
                    text: "No custom images uploaded yet"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                }
            }
        }
        }
    }

    // --- INTEGRATED FILE BROWSER VIEW (custom badge upload) ---
    // Same structure as MascotSettings.qml's image browser.
    ColumnLayout {
        anchors.fill: parent
        visible: root.showBrowser
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "SELECT BADGE IMAGE"
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontTitle)
                font.bold: true
                color: Config.textMain
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: cancelText.implicitWidth + 16
                implicitHeight: 22
                radius: Config.cornerRadius / 2
                color: cancelHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                Text {
                    id: cancelText
                    anchors.centerIn: parent
                    text: "CANCEL"
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                    color: cancelHover.hovered ? Config.bgBase : Config.textMuted
                }

                TapHandler { onTapped: root.showBrowser = false }
                HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor }
            }
        }

        Text {
            text: root.currentBrowserPath.replace("file://", "")
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            color: Config.textMuted
            elide: Text.ElideLeft
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(0, 0, 0, 0.15)
            radius: Config.cornerRadius / 2
            border.color: Qt.rgba(255, 255, 255, 0.1)
            border.width: 1
            clip: true

            ListView {
                id: fileListView
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2
                clip: true

                model: FolderListModel {
                    folder: root.currentBrowserPath
                    showDirsFirst: true
                    showDotAndDotDot: true
                    nameFilters: ["*.gif", "*.png", "*.jpg", "*.jpeg", "*.webp"]
                }

                delegate: Rectangle {
                    width: fileListView.width
                    implicitHeight: fileName === "." ? 0 : 34
                    visible: fileName !== "."
                    radius: Config.cornerRadius / 2
                    color: fileHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent"

                    RowLayout {
                        spacing: 8
                        anchors.fill: parent
                        anchors.leftMargin: 8

                        Text {
                            text: fileIsDir ? "folder" : "image"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            color: Config.accent
                        }

                        Text {
                            text: fileName
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            color: Config.textMain
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    TapHandler {
                        onTapped: {
                            if (fileIsDir) {
                                root.currentBrowserPath = fileUrl.toString()
                            } else {
                                let urlString = fileUrl.toString()
                                let parsedPath = urlString.startsWith("file:///") ? urlString.substring(7) : urlString.replace("file://", "")

                                Config.assistantBadgePath = parsedPath
                                Config.addCustomBadge(parsedPath)
                                root.showBrowser = false
                            }
                        }
                    }

                    HoverHandler { id: fileHover; cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }
}
