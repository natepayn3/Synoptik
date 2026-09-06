import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

// A normal resizable/draggable desktop panel showing a chat UI that shells
// out to a locally-installed CLI (Claude Code / Codex CLI / Gemini CLI) in
// its own one-shot headless mode - see backendCommand() below. Architecture
// is a direct copy of MediaCardWidget.qml's drag+resize model (itself
// explained at length in that file's header comment): a layer-shell
// PanelWindow, an invisible drag/resize anchor (assistantContainer) that
// tracks the cursor 1:1 and is also the window's input mask, and a separate
// visible skin (ghostBody) that follows it via a real binding so a Behavior
// can animate it - a MouseArea.drag.target's own writes don't reliably
// trigger a Behavior placed on that same item.
PanelWindow {
    id: assistantWindow
    visible: Config.showAssistant

    Component.onCompleted: {
        let activeName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        let found = Quickshell.screens.find(s => s.name === activeName)
        assistantWindow.screen = found || Quickshell.screens[0]

        claudeCheck.running = true
        codexCheck.running = true
        geminiCheck.running = true
        ollamaCheck.running = true
    }

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-assistant"
    // OnDemand only while the chat input actually has focus (or the widget
    // menu is open) - NOT for the whole time the panel is visible. Holding
    // OnDemand continuously, the whole panel's lifetime, collided with
    // Settings' own surface (also OnDemand the whole time it's open, see
    // UnifiedSurface.qml) - Hyprland doesn't like two layer-shell surfaces
    // both claiming exclusive keyboard focus at once, and force-closed
    // Settings as a result. A mouse click into the text field still works
    // fine even at WlrKeyboardFocus.None (pointer input isn't gated by
    // this), so this flips to OnDemand right as the field gains focus -
    // well before the user's next actual keystroke.
    WlrLayershell.keyboardFocus: ((typeof chatInput !== "undefined" && chatInput.activeFocus) || (typeof widgetMenu !== "undefined" && widgetMenu.visible))
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: -1

    readonly property size minCardSize: Qt.size(240, 280)
    readonly property size maxCardSize: Qt.size(560, 760)

    // See MediaCardWidget.qml's identical helper for why this exists - a
    // stray NaN (or a missing/undefined saved value) must fall back to a
    // safe size instead of silently producing an invisible zero-size card.
    function clampSize(value, lo, hi, fallback) {
        if (typeof value !== "number" || !isFinite(value)) return fallback
        return Math.max(lo, Math.min(hi, value))
    }

    // The third region only matters while the mouse is down - see
    // ClockWidget.qml's identical mask comment for why (fast flicks
    // outrunning a small input region on a layer-shell surface).
    mask: Region {
        Region { item: assistantContainer }
        Region { item: (typeof widgetMenu !== "undefined" && widgetMenu.visible) ? widgetMenu : null }
        Region { item: (typeof backendDropdown !== "undefined" && backendDropdown.visible) ? backendDropdown : null }
        Region { item: dragArea.pressed ? fullScreenDragCatch : null }
    }

    Item { id: fullScreenDragCatch; anchors.fill: parent }

    SnapGridOverlay {
        anchors.fill: parent
        gridSize: ghostBody.gridSize
        active: dragArea.drag.active && Config.snapDesktopWidgets
        targetX: ghostBody.x
        targetY: ghostBody.y
        targetWidth: ghostBody.width
        targetHeight: ghostBody.height
    }

    // Same normalization Mascot.qml uses for its image path - handles a
    // bare filesystem path, an already-formed file:// URL, or a path
    // relative to $HOME.
    function formatFileUrl(path) {
        if (!path) return ""
        if (path.startsWith("file://")) return path
        if (path.startsWith("/")) return "file://" + path
        return "file://" + Quickshell.env("HOME") + "/" + path
    }

    // Shared badge visual - used both in the header and inline next to each
    // assistant reply, so the "same badge image" the user configures shows
    // up in both places from one definition. Falls back to the smart_toy
    // glyph whenever no badge image is set or it fails to load. Circular
    // crop via OpacityMask, same pattern as MediaCardWidget.qml's album-art
    // disc.
    component AssistantBadge: Item {
        id: badge
        property real diameter: 24
        implicitWidth: diameter
        implicitHeight: diameter

        Text {
            anchors.centerIn: parent
            text: "smart_toy"
            font.family: "Material Symbols Outlined"
            font.pixelSize: badge.diameter * 0.72
            color: Config.accent
            visible: badgeImage.status !== AnimatedImage.Ready
        }

        AnimatedImage {
            id: badgeImage
            anchors.fill: parent
            source: Config.assistantBadgePath ? assistantWindow.formatFileUrl(Config.assistantBadgePath) : ""
            fillMode: Image.PreserveAspectCrop
            playing: true
            visible: false
            asynchronous: true
        }

        Rectangle {
            id: badgeMaskShape
            anchors.fill: parent
            radius: width / 2
            color: "black"
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: badgeImage
            maskSource: badgeMaskShape
            visible: badgeImage.status === AnimatedImage.Ready
        }
    }

    function backendLabel() {
        if (Config.assistantBackend === "codex") return "Codex CLI"
        if (Config.assistantBackend === "gemini") return "Gemini CLI"
        if (Config.assistantBackend === "ollama") return "Ollama"
        return "Claude Code"
    }

    // Detected the same way AssistantSettings.qml does (a `which` check per
    // CLI), kept separate from that page's own copy rather than shared via
    // Config - it's cheap to recompute and the two have independent
    // lifecycles (this runs once when the widget mounts; Settings' copy
    // runs whenever that page is opened).
    property bool claudeDetected: false
    property bool codexDetected: false
    property bool geminiDetected: false
    property bool ollamaDetected: false
    property bool backendMenuOpen: false

    readonly property var detectedBackends: {
        let list = []
        if (claudeDetected) list.push({ id: "claude", label: "Claude Code" })
        if (codexDetected) list.push({ id: "codex", label: "Codex CLI" })
        if (geminiDetected) list.push({ id: "gemini", label: "Gemini CLI" })
        if (ollamaDetected) list.push({ id: "ollama", label: "Ollama" })
        return list
    }

    Process {
        id: claudeCheck
        command: ["which", "claude"]
        onExited: (exitCode) => assistantWindow.claudeDetected = (exitCode === 0)
    }
    Process {
        id: codexCheck
        command: ["which", "codex"]
        onExited: (exitCode) => assistantWindow.codexDetected = (exitCode === 0)
    }
    Process {
        id: geminiCheck
        command: ["which", "gemini"]
        onExited: (exitCode) => assistantWindow.geminiDetected = (exitCode === 0)
    }
    Process {
        id: ollamaCheck
        command: ["which", "ollama"]
        onExited: (exitCode) => assistantWindow.ollamaDetected = (exitCode === 0)
    }


    // Each send is its own fresh, memory-less process - none of the three
    // backends share conversation state across separate invocations here -
    // so continuity has to come from the prompt text itself: prior turns are
    // rendered as a plain transcript ahead of the new message. Verified this
    // actually gives real continuity (asked it to remember a fact, then
    // asked it back two turns later in a fresh process - it recalled it)
    // rather than assuming it would work.
    function buildPrompt(history, newMessage) {
        if (!history || history.length === 0) return newMessage
        let lines = ["Here is our conversation so far. Respond naturally to my latest message at the end - don't repeat earlier context back to me, just continue the conversation."]
        for (let i = 0; i < history.length; i++) {
            lines.push((history[i].role === "user" ? "User" : "Assistant") + ": " + history[i].text)
        }
        lines.push("User: " + newMessage)
        return lines.join("\n\n")
    }

    // Maps the selected backend to its own CLI's one-shot headless
    // invocation - each of these already handles its own auth (a signed-in
    // personal subscription or an API key, whichever that CLI is configured
    // with), so nothing here ever touches a credential. Ollama is the
    // exception: no account of any kind, just a local (or self-hosted)
    // model - the model name is a required positional argument for it
    // rather than an optional --model flag, so it gets its own branch
    // instead of sharing modelArgs.
    function backendCommand(prompt) {
        if (Config.assistantBackend === "ollama") {
            let model = (Config.assistantModel && Config.assistantModel.length > 0) ? Config.assistantModel : "llama3.2"
            return ["ollama", "run", model, prompt]
        }
        let modelArgs = (Config.assistantModel && Config.assistantModel.length > 0) ? ["--model", Config.assistantModel] : []
        if (Config.assistantBackend === "codex") return ["codex", "exec"].concat(modelArgs).concat([prompt])
        if (Config.assistantBackend === "gemini") return ["gemini", "-p", prompt].concat(modelArgs)
        return ["claude", "-p", prompt].concat(modelArgs) // "claude" (default)
    }

    property bool assistantBusy: false

    // The backend CLIs don't stream their reply incrementally in this
    // invocation mode - confirmed empirically (claude -p writes its entire
    // response in one burst right before exiting, not token-by-token), so
    // there's no live text to preview. This ticks a plain elapsed-time
    // counter instead, so a long wait still shows continuous, honest proof
    // of life rather than a static "Waiting..." string that looks identical
    // whether it's been 2 seconds or 2 minutes.
    property real requestStartMs: 0
    property int elapsedSeconds: 0

    Timer {
        id: elapsedTicker
        interval: 1000
        repeat: true
        running: assistantWindow.assistantBusy
        onTriggered: assistantWindow.elapsedSeconds = Math.floor((Date.now() - assistantWindow.requestStartMs) / 1000)
    }

    function sendMessage(text) {
        let trimmed = (text || "").trim()
        if (!trimmed || assistantBusy) return
        let fullPrompt = assistantWindow.buildPrompt(Config.assistantMessages, trimmed)
        Config.appendAssistantMessage("user", trimmed)
        assistantBusy = true
        assistantWindow.requestStartMs = Date.now()
        assistantWindow.elapsedSeconds = 0
        assistantWatchdog.restart()
        assistantProcess.command = backendCommand(fullPrompt)
        assistantProcess.running = true
    }

    // Manual cancel - same "running = false" mechanism the watchdog timeout
    // below already uses to stop a hung/slow call. onExited's own
    // assistantBusy guard (set false here first) means the process's
    // eventual exit is a silent no-op instead of appending a second reply.
    function cancelRequest() {
        if (!assistantBusy) return
        assistantWatchdog.stop()
        assistantBusy = false
        assistantProcess.running = false
        Config.appendAssistantMessage("assistant", "Cancelled.")
    }

    Connections {
        target: Config
        function onAssistantMessagesChanged() {
            Qt.callLater(function() {
                if (typeof messageList !== "undefined") messageList.positionViewAtEnd()
            })
        }
    }

    // Last-resort safety net: a process that fails to start at all (binary
    // missing from PATH) never reaches onExited - there's no bindable
    // "process failed to start" signal on this Process type - so without
    // this, that case would leave assistantBusy stuck true forever with no
    // error shown. Also guards against a hung CLI (e.g. stuck waiting on a
    // login prompt it can't show in headless mode).
    Timer {
        id: assistantWatchdog
        interval: Config.assistantTimeoutSeconds * 1000
        onTriggered: {
            if (!assistantWindow.assistantBusy) return
            assistantWindow.assistantBusy = false
            assistantProcess.running = false
            Config.appendAssistantMessage("assistant", "Timed out waiting on " + assistantWindow.backendLabel() + " - check that it's installed, signed in, and on your PATH.")
        }
    }

    Process {
        id: assistantProcess
        stdout: StdioCollector { id: assistantStdout; waitForEnd: true }
        stderr: StdioCollector { id: assistantStderr; waitForEnd: true }

        onExited: (exitCode, exitStatus) => {
            if (!assistantWindow.assistantBusy) return
            assistantWatchdog.stop()
            assistantWindow.assistantBusy = false
            let outText = assistantStdout.text ? assistantStdout.text.trim() : ""
            let errText = assistantStderr.text ? assistantStderr.text.trim() : ""
            let reply = (exitCode === 0 && outText.length > 0)
                ? outText
                : ("Error running " + Config.assistantBackend + ": " + (errText.length > 0 ? errText : ("exit code " + exitCode)))
            Config.appendAssistantMessage("assistant", reply)
        }
    }

    // This item is the drag/resize anchor and always tracks the cursor 1:1 -
    // it's also the window's input mask, so hit-testing must never lag. The
    // visible skin lives on the sibling ghostBody item instead - see
    // MediaCardWidget.qml's identical note for why, and for why z is
    // elevated above ghostBody (the 8 ResizeEdges need to win hit-testing in
    // the narrow edge/corner strips against ghostBody's content).
    Item {
        id: assistantContainer
        z: 10

        property real dragX: 0
        property real dragY: 0
        property real cardWidth: 320
        property real cardHeight: 420
        property bool initialized: false

        x: dragX
        y: dragY
        width: cardWidth
        height: cardHeight

        Timer {
            id: sizeSaveDebounce
            interval: 400
            onTriggered: Config.saveAssistantSize(assistantContainer.cardWidth, assistantContainer.cardHeight)
        }
        onCardWidthChanged: sizeSaveDebounce.restart()
        onCardHeightChanged: sizeSaveDebounce.restart()

        Connections {
            target: assistantWindow
            function onWidthChanged() { assistantContainer.restorePosition() }
            function onHeightChanged() { assistantContainer.restorePosition() }
        }

        Connections {
            target: Config
            function onIsLoadedChanged() { if (Config.isLoaded) assistantContainer.restorePosition() }
        }

        function restorePosition() {
            if (initialized || assistantWindow.width <= 0 || assistantWindow.height <= 0 || !Config.isLoaded) return

            if (Config.assistantLastScreen && assistantWindow.screen && Config.assistantLastScreen !== assistantWindow.screen.name) {
                let savedScreen = Quickshell.screens.find(s => s.name === Config.assistantLastScreen)
                if (savedScreen) assistantWindow.screen = savedScreen
            }

            cardWidth = assistantWindow.clampSize(Config.assistantWidth, assistantWindow.minCardSize.width, assistantWindow.maxCardSize.width, 320)
            cardHeight = assistantWindow.clampSize(Config.assistantHeight, assistantWindow.minCardSize.height, assistantWindow.maxCardSize.height, 420)

            let defaultX = Math.max(0, assistantWindow.width - cardWidth - 60)
            let defaultY = Math.max(0, assistantWindow.height - cardHeight - 60)

            let savedPos = assistantWindow.screen
                ? Config.getAssistantPosition(assistantWindow.screen.name, defaultX, defaultY)
                : { x: defaultX, y: defaultY }

            dragX = savedPos.x
            dragY = savedPos.y
            initialized = true
        }

        Component.onCompleted: restorePosition()

        onXChanged: {
            checkScreenBoundary()
            if (initialized && assistantWindow.screen && (dragArea.drag.active || anyResizeActive)) {
                Config.saveAssistantPosition(assistantWindow.screen.name, dragX, dragY)
            }
        }
        onYChanged: {
            checkScreenBoundary()
            if (initialized && assistantWindow.screen && (dragArea.drag.active || anyResizeActive)) {
                Config.saveAssistantPosition(assistantWindow.screen.name, dragX, dragY)
            }
        }

        // Lets a drag carry the card across onto a different monitor - see
        // MediaCardWidget.qml's identical function for the full rationale
        // (re-parents the PanelWindow to the new screen and re-expresses
        // dragX/dragY in its local space, clamping back onto the current
        // screen if the cursor exits every screen's rect at once).
        function checkScreenBoundary() {
            if (!dragArea.drag.active || !assistantWindow.screen) return

            let cur = assistantWindow.screen
            let globalX = cur.x + assistantContainer.x
            let globalY = cur.y + assistantContainer.y

            let centerX = globalX + (assistantContainer.width / 2)
            let centerY = globalY + (assistantContainer.height / 2)

            if (centerX >= cur.x && centerX <= (cur.x + cur.width) &&
                centerY >= cur.y && centerY <= (cur.y + cur.height)) {
                return
            }

            for (let i = 0; i < Quickshell.screens.length; i++) {
                let s = Quickshell.screens[i]
                if (s === cur) continue

                if (centerX >= s.x && centerX <= (s.x + s.width) &&
                    centerY >= s.y && centerY <= (s.y + s.height)) {

                    let newLocalX = globalX - s.x
                    let newLocalY = globalY - s.y

                    assistantWindow.screen = s
                    assistantContainer.dragX = newLocalX
                    assistantContainer.dragY = newLocalY
                    return
                }
            }

            assistantContainer.dragX = Math.max(0, Math.min(cur.width - assistantContainer.width, assistantContainer.dragX))
            assistantContainer.dragY = Math.max(0, Math.min(cur.height - assistantContainer.height, assistantContainer.dragY))
        }

        // Called from drag.onActiveChanged, dragArea.onReleased, and every
        // ResizeEdge.onReleased below - same belt-and-suspenders as
        // MediaCardWidget.qml's commitGridSnap(). Idempotent, position-only.
        function commitGridSnap() {
            if (!Config.snapDesktopWidgets) return
            dragX = Math.round(dragX / ghostBody.gridSize) * ghostBody.gridSize
            dragY = Math.round(dragY / ghostBody.gridSize) * ghostBody.gridSize
            if (assistantWindow.screen) {
                Config.saveAssistantPosition(assistantWindow.screen.name, dragX, dragY)
            }
        }

        // True while any ResizeEdge below is mid-drag - a left/top-edge
        // resize moves dragX/dragY as a side effect (keeping the opposite
        // corner fixed), so those position writes need to persist too.
        property bool anyResizeActive: false

        // --- MANUAL RESIZE --- identical approach to MediaCardWidget.qml's
        // ResizeEdge - see that file's header comment for why this exists
        // instead of native xdg-toplevel resize (startSystemResize() turned
        // out to be a dead end for a layer-shell surface).
        component ResizeEdge: MouseArea {
            id: resizeEdge
            required property int edges

            hoverEnabled: true
            cursorShape: {
                if (edges === (Qt.LeftEdge | Qt.TopEdge) || edges === (Qt.RightEdge | Qt.BottomEdge)) return Qt.SizeFDiagCursor
                if (edges === (Qt.RightEdge | Qt.TopEdge) || edges === (Qt.LeftEdge | Qt.BottomEdge)) return Qt.SizeBDiagCursor
                if (edges === Qt.LeftEdge || edges === Qt.RightEdge) return Qt.SizeHorCursor
                return Qt.SizeVerCursor
            }

            property real startAbsX: 0
            property real startAbsY: 0
            property real startWidth: 0
            property real startHeight: 0
            property real startDragX: 0
            property real startDragY: 0

            onPressed: (mouse) => {
                let abs = mapToItem(fullScreenDragCatch, mouse.x, mouse.y)
                startAbsX = abs.x
                startAbsY = abs.y
                startWidth = assistantContainer.cardWidth
                startHeight = assistantContainer.cardHeight
                startDragX = assistantContainer.dragX
                startDragY = assistantContainer.dragY
                assistantContainer.anyResizeActive = true
            }

            onPositionChanged: (mouse) => {
                // hoverEnabled (needed so cursorShape updates before a click)
                // makes this fire on plain hover too - without this guard, a
                // mere hover runs the resize math against start* values that
                // were never initialized by an actual press.
                if (!resizeEdge.pressed) return

                let abs = mapToItem(fullScreenDragCatch, mouse.x, mouse.y)
                let deltaX = abs.x - startAbsX
                let deltaY = abs.y - startAbsY

                let newWidth = startWidth
                let newDragX = startDragX
                if (edges & Qt.RightEdge) {
                    newWidth = assistantWindow.clampSize(startWidth + deltaX, assistantWindow.minCardSize.width, assistantWindow.maxCardSize.width, startWidth)
                } else if (edges & Qt.LeftEdge) {
                    newWidth = assistantWindow.clampSize(startWidth - deltaX, assistantWindow.minCardSize.width, assistantWindow.maxCardSize.width, startWidth)
                    newDragX = startDragX + (startWidth - newWidth)
                }

                let newHeight = startHeight
                let newDragY = startDragY
                if (edges & Qt.BottomEdge) {
                    newHeight = assistantWindow.clampSize(startHeight + deltaY, assistantWindow.minCardSize.height, assistantWindow.maxCardSize.height, startHeight)
                } else if (edges & Qt.TopEdge) {
                    newHeight = assistantWindow.clampSize(startHeight - deltaY, assistantWindow.minCardSize.height, assistantWindow.maxCardSize.height, startHeight)
                    newDragY = startDragY + (startHeight - newHeight)
                }

                assistantContainer.cardWidth = newWidth
                assistantContainer.cardHeight = newHeight
                assistantContainer.dragX = newDragX
                assistantContainer.dragY = newDragY
            }

            onReleased: {
                assistantContainer.anyResizeActive = false
                assistantContainer.commitGridSnap()
            }
            onCanceled: assistantContainer.anyResizeActive = false
        }

        readonly property real edgeThickness: 6
        // Scales with the user's actual configured corner rounding rather
        // than a fixed guess - a corner grab zone sized to match/undercut
        // Config.cornerRadius would sit almost entirely inside the visually
        // rounded-away area, making it very hard to click. +8 keeps a
        // comfortable margin past the curve; the 18 floor covers square/
        // barely-rounded corners, where a tiny zone would be just as
        // annoying to hit precisely.
        readonly property real cornerSize: Math.max(18, Config.cornerRadius + 8)

        ResizeEdge {
            edges: Qt.TopEdge
            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: assistantContainer.cornerSize; rightMargin: assistantContainer.cornerSize }
            height: assistantContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.BottomEdge
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: assistantContainer.cornerSize; rightMargin: assistantContainer.cornerSize }
            height: assistantContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.LeftEdge
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: assistantContainer.cornerSize; bottomMargin: assistantContainer.cornerSize }
            width: assistantContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.RightEdge
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: assistantContainer.cornerSize; bottomMargin: assistantContainer.cornerSize }
            width: assistantContainer.edgeThickness
        }
        ResizeEdge {
            edges: Qt.LeftEdge | Qt.TopEdge
            anchors { top: parent.top; left: parent.left }
            width: assistantContainer.cornerSize; height: assistantContainer.cornerSize
        }
        ResizeEdge {
            edges: Qt.RightEdge | Qt.TopEdge
            anchors { top: parent.top; right: parent.right }
            width: assistantContainer.cornerSize; height: assistantContainer.cornerSize
        }
        ResizeEdge {
            edges: Qt.LeftEdge | Qt.BottomEdge
            anchors { bottom: parent.bottom; left: parent.left }
            width: assistantContainer.cornerSize; height: assistantContainer.cornerSize
        }
        ResizeEdge {
            edges: Qt.RightEdge | Qt.BottomEdge
            anchors { bottom: parent.bottom; right: parent.right }
            width: assistantContainer.cornerSize; height: assistantContainer.cornerSize
        }

        WidgetContextMenu { id: widgetMenu; hostWidgetId: "assistant" }

        // Quick backend switcher, filtered to only whatever CLIs are
        // actually detected on this machine (Settings still lets you pick
        // an undetected one to pre-configure). A plain child of
        // assistantContainer (not ghostBody/cardBg, which clips) so it
        // paints above the card's content and isn't cut off - same reason
        // widgetMenu lives here instead of inside cardBg.
        Rectangle {
            id: backendDropdown
            visible: assistantWindow.backendMenuOpen
            z: 999
            width: 150
            implicitHeight: dropdownColumn.implicitHeight + 8
            radius: Config.cornerRadius / 2
            color: Config.bgPanel
            border.width: Config.showBorders ? Config.borderThickness : 1
            border.color: (typeof shellRoot !== "undefined" && shellRoot.currentBorderColor) ? shellRoot.currentBorderColor : Qt.rgba(255, 255, 255, 0.1)

            // backendPill lives inside cardBg's own coordinate space -
            // mapped into assistantContainer's space here, the same
            // approach WidgetContextMenu.openAt() uses for its own popup.
            function reposition() {
                if (typeof backendPill === "undefined") return
                let pos = backendPill.mapToItem(assistantContainer, 0, backendPill.height + 4)
                backendDropdown.x = pos.x
                backendDropdown.y = pos.y
            }
            onVisibleChanged: if (visible) reposition()

            Column {
                id: dropdownColumn
                anchors.fill: parent
                anchors.margins: 4
                spacing: 2

                Repeater {
                    model: assistantWindow.detectedBackends

                    Rectangle {
                        width: dropdownColumn.width
                        implicitHeight: 28
                        radius: Config.cornerRadius / 3
                        color: Config.assistantBackend === modelData.id
                            ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.18)
                            : (backendRowHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent")

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                        }

                        TapHandler {
                            onTapped: {
                                Config.assistantBackend = modelData.id
                                assistantWindow.backendMenuOpen = false
                            }
                        }
                        HoverHandler { id: backendRowHover; cursorShape: Qt.PointingHandCursor }
                    }
                }

                Text {
                    visible: assistantWindow.detectedBackends.length === 0
                    width: dropdownColumn.width
                    text: "No CLIs detected - check Settings"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // Visible skin, decoupled from assistantContainer (the drag/resize
    // anchor / hit region above) precisely so Behavior can animate it - see
    // the note by assistantContainer.x. Deliberately lower z (default, 0)
    // than assistantContainer (10).
    Item {
        id: ghostBody
        readonly property real gridSize: 24

        x: (Config.snapDesktopWidgets && dragArea.drag.active) ? Math.round(assistantContainer.x / gridSize) * gridSize : assistantContainer.x
        y: (Config.snapDesktopWidgets && dragArea.drag.active) ? Math.round(assistantContainer.y / gridSize) * gridSize : assistantContainer.y
        // Size never grid-snaps (only position does) and never lags behind a
        // live resize - direct mirror, no Behavior.
        width: assistantContainer.cardWidth
        height: assistantContainer.cardHeight

        Behavior on x {
            enabled: !Config.snapDesktopWidgets
            NumberAnimation {
                duration: Config.motionService.durationFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Config.motionService.expressiveFastSpatialPoints
            }
        }
        Behavior on y {
            enabled: !Config.snapDesktopWidgets
            NumberAnimation {
                duration: Config.motionService.durationFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Config.motionService.expressiveFastSpatialPoints
            }
        }

        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: Config.cornerRadius
            color: Config.bgPanel
            border.width: Config.showBorders ? Config.borderThickness : 1
            border.color: (typeof shellRoot !== "undefined" && shellRoot.currentBorderColor) ? shellRoot.currentBorderColor : Qt.rgba(255, 255, 255, 0.1)
            clip: true

            Behavior on border.color { ColorAnimation { duration: 150 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Config.cardMargin
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AssistantBadge { diameter: 48 }

                    // Same title-glow pattern as Settings.qml/WidgetContextMenu.qml's
                    // headers - gated on Config.clockShowGlow, the shell-wide
                    // header-glow toggle despite the clock-specific name.
                    Item {
                        implicitWidth: assistantTitleText.implicitWidth
                        implicitHeight: assistantTitleText.implicitHeight

                        Glow {
                            anchors.fill: assistantTitleText
                            source: assistantTitleText
                            radius: 8
                            samples: 16
                            color: Config.accent
                            spread: 0.2
                            transparentBorder: true
                            visible: Config.clockShowGlow
                        }

                        Text {
                            id: assistantTitleText
                            anchors.fill: parent
                            text: "ASSISTANT"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontTitle)
                            font.bold: true
                            font.italic: true
                        }
                    }

                    Rectangle {
                        id: backendPill
                        implicitWidth: backendPillRow.implicitWidth + 16
                        implicitHeight: backendPillRow.implicitHeight + 6
                        radius: Config.cornerRadius / 3
                        color: backendPillHover.hovered ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.08)

                        RowLayout {
                            id: backendPillRow
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                id: backendBadgeText
                                text: assistantWindow.backendLabel()
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: true
                            }

                            Text {
                                text: "arrow_drop_down"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                                color: Config.textMuted
                            }
                        }

                        TapHandler { onTapped: assistantWindow.backendMenuOpen = !assistantWindow.backendMenuOpen }
                        HoverHandler { id: backendPillHover; cursorShape: Qt.PointingHandCursor }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "delete_sweep"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                        color: clearHover.hovered ? Config.accent : Config.textMuted
                        visible: Config.assistantMessages && Config.assistantMessages.length > 0

                        TapHandler { onTapped: Config.clearAssistantMessages() }
                        HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Config.cornerRadius / 2
                    color: Qt.rgba(0, 0, 0, 0.15)
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 32
                        visible: !Config.assistantMessages || Config.assistantMessages.length === 0
                        text: Config.assistantBackend === "ollama"
                            ? "Say hello - this runs your local Ollama model on this machine, no account needed."
                            : "Say hello - this runs " + assistantWindow.backendLabel() + " in headless mode, using whatever account it's already signed into on this machine."
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    ListView {
                        id: messageList
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6
                        clip: true
                        model: Config.assistantMessages || []

                        delegate: Item {
                            readonly property bool isUser: modelData.role === "user"
                            width: messageList.width
                            implicitHeight: contentRow.implicitHeight

                            RowLayout {
                                id: contentRow
                                width: parent.width
                                spacing: 6

                                // Only the assistant gets a badge - it's the
                                // assistant's own avatar, not the user's.
                                AssistantBadge {
                                    diameter: 48
                                    visible: !isUser
                                    Layout.alignment: Qt.AlignTop
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: bubbleText.implicitHeight + 16
                                    radius: Config.cornerRadius / 2
                                    color: isUser ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.22) : Qt.rgba(255, 255, 255, 0.06)

                                    Text {
                                        id: bubbleText
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        text: modelData.text
                                        color: Config.textMain
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontCaption)
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: assistantWindow.assistantBusy
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: "Waiting on " + assistantWindow.backendLabel() + "... (" + assistantWindow.elapsedSeconds + "s)"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.italic: true
                        font.pixelSize: Config.size(Config.fontMicro)
                    }

                    Text {
                        text: "CANCEL"
                        color: cancelWaitHover.hovered ? Config.accent : Config.textMuted
                        font.family: Config.sysFont
                        font.bold: true
                        font.pixelSize: Config.size(Config.fontMicro)

                        TapHandler { onTapped: assistantWindow.cancelRequest() }
                        HoverHandler { id: cancelWaitHover; cursorShape: Qt.PointingHandCursor }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: Config.cornerRadius / 2
                        color: Qt.rgba(0, 0, 0, 0.15)
                        border.width: 1
                        border.color: chatInput.activeFocus ? Config.accent : "transparent"
                        opacity: assistantWindow.assistantBusy ? 0.5 : 1.0
                        clip: true

                        TextInput {
                            id: chatInput
                            anchors.fill: parent
                            anchors.margins: 8
                            enabled: !assistantWindow.assistantBusy
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            clip: true

                            Text {
                                anchors.fill: parent
                                text: "Ask your assistant..."
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                verticalAlignment: Text.AlignVCenter
                                visible: chatInput.text.length === 0 && !chatInput.activeFocus
                            }

                            onAccepted: {
                                assistantWindow.sendMessage(text)
                                text = ""
                            }

                            HoverHandler { cursorShape: Qt.IBeamCursor }
                        }
                    }

                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: Config.cornerRadius / 2
                        opacity: assistantWindow.assistantBusy ? 0.5 : 1.0
                        color: sendHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: "send"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            color: sendHover.hovered ? Config.bgBase : Config.textMain
                        }

                        TapHandler {
                            onTapped: {
                                if (assistantWindow.assistantBusy) return
                                assistantWindow.sendMessage(chatInput.text)
                                chatInput.text = ""
                            }
                        }
                        HoverHandler { id: sendHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }

            // --- MOVE + RIGHT-CLICK WIDGET MENU --- declared after the
            // content above so it keeps click priority, z:-1 makes that
            // explicit too. Same pattern as MediaCardWidget.qml/Mascot.qml.
            MouseArea {
                id: dragArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                z: -1

                property bool dragMoved: false

                onPressed: dragMoved = false

                drag {
                    target: assistantContainer
                    axis: Drag.XAndYAxis
                    onActiveChanged: {
                        if (!drag.active) assistantContainer.commitGridSnap()
                    }
                }

                onReleased: if (dragMoved) assistantContainer.commitGridSnap()

                onPositionChanged: {
                    if (drag.active) {
                        dragMoved = true
                        assistantContainer.dragX = assistantContainer.x
                        assistantContainer.dragY = assistantContainer.y
                    }
                }

                onClicked: (mouse) => {
                    if (assistantWindow.backendMenuOpen) {
                        assistantWindow.backendMenuOpen = false
                        return
                    }
                    if (widgetMenu.visible) {
                        widgetMenu.close()
                        return
                    }
                    if (mouse.button === Qt.RightButton) {
                        widgetMenu.openAt(mouse.x, mouse.y, assistantContainer, assistantWindow.width, assistantWindow.height)
                        return
                    }
                    Config.closeWidgetMenus()
                }
            }
        }
    }
}
