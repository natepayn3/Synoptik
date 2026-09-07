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
        ollamaModelListProcess.running = true
    }

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-assistant"
    // OnDemand only while the chat input has focus, is merely hovered, or
    // the widget menu is open - NOT for the whole time the panel is
    // visible. Holding OnDemand continuously, the whole panel's lifetime,
    // collided with Settings' own surface (also OnDemand the whole time
    // it's open, see UnifiedSurface.qml) - Hyprland doesn't like two
    // layer-shell surfaces both claiming exclusive keyboard focus at once,
    // and force-closed Settings as a result.
    //
    // The hover condition (not just activeFocus) exists because granting
    // OnDemand is an async round-trip to the compositor - gating purely on
    // activeFocus meant the very first click's own keystrokes could arrive
    // before Hyprland finished the grant and get silently dropped, so
    // typing only "worked" after a second click gave the round-trip time to
    // finish. Requesting it on hover instead starts that round-trip while
    // the cursor is still moving toward the field, before the click even
    // happens - mouse/pointer input isn't gated by keyboardFocus at all, so
    // hovering and clicking both still work fine at None in the meantime.
    // modelMenuOpen covers newModelInput (the "pull new model" field) the
    // same way chatInput is covered above - granted for the dropdown's
    // whole time open rather than gated on hover/focus of the field itself,
    // since the dropdown has nothing else in it worth a pointer hover
    // happening before a click the way chatInput's own hover trick needs.
    WlrLayershell.keyboardFocus: ((typeof chatInput !== "undefined" && chatInput.activeFocus)
            || (typeof chatInputHover !== "undefined" && chatInputHover.hovered)
            || (typeof widgetMenu !== "undefined" && widgetMenu.visible)
            || assistantWindow.modelMenuOpen)
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

    function adjustFontScale(delta) {
        let next = Math.round((Config.assistantFontScale + delta) * 10) / 10
        Config.assistantFontScale = Math.max(0.75, Math.min(2.0, next))
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


    // Ollama's CLI does its own client-side line wrapping by writing a word,
    // then - if it decided that word doesn't fit - backing the cursor up
    // over it and erasing before rewriting it at the start of the next line
    // (confirmed empirically: captured raw output is littered with
    // "<partial word>\x1b[<n>D\x1b[K\n<full word>..." runs). Since the output
    // is captured as plain text rather than actually rendered in a
    // terminal, those bytes would otherwise show up as literal garbage
    // glyphs with the erased word fragment still stuck in the text.
    // Stripping the escape codes alone isn't enough - it'd leave the erased
    // fragment concatenated onto what replaced it - so this replays the two
    // control codes it actually uses (cursor-back and erase-to-end-of-line)
    // against a small per-line buffer to reconstruct what would really be
    // visible on a terminal.
    function stripOllamaLineWrapCodes(raw) {
        if (!raw || raw.indexOf("\x1b") === -1) return raw
        let lines = [""]
        let row = 0
        let col = 0
        let i = 0
        while (i < raw.length) {
            let ch = raw[i]
            if (ch === "\x1b" && raw[i + 1] === "[") {
                let j = i + 2
                let params = ""
                while (j < raw.length && /[0-9;]/.test(raw[j])) { params += raw[j]; j++ }
                let letter = raw[j]
                if (letter === "D") {
                    col = Math.max(0, col - (params.length > 0 ? parseInt(params) : 1))
                } else if (letter === "K") {
                    lines[row] = lines[row].slice(0, col)
                }
                i = j + 1
            } else if (ch === "\r") {
                col = 0
                i++
            } else if (ch === "\n") {
                row++
                lines[row] = ""
                col = 0
                i++
            } else {
                let line = lines[row]
                lines[row] = line.slice(0, col) + ch + line.slice(col + 1)
                col++
                i++
            }
        }
        return lines.join("\n")
    }

    // Each send is its own fresh, memory-less process - none of the three
    // backends share conversation state across separate invocations here -
    // so continuity has to come from the prompt text itself: prior turns are
    // rendered as a plain transcript ahead of the new message. Verified this
    // actually gives real continuity (asked it to remember a fact, then
    // asked it back two turns later in a fresh process - it recalled it)
    // rather than assuming it would work.
    //
    // Capped to the most recent maxPromptHistoryMessages (separate from -
    // and much smaller than - Config's own 100-message display/storage
    // cap): with no cap, every single send re-transmitted the *entire*
    // conversation so far, so a long-running chat meant an ever-growing
    // prompt on every turn - slower and more expensive on every hosted
    // backend, and eventually big enough to risk silently overflowing the
    // model's own context window. Recent history is what actually matters
    // for continuity anyway.
    readonly property int maxPromptHistoryMessages: 30
    function buildPrompt(history, newMessage) {
        if (!history || history.length === 0) return newMessage
        // Error/timeout/cancelled/info entries are diagnostics for the
        // person reading the chat, not real turns - dropped here so a past
        // failure (or a "downloading the model" notice) never gets fed back
        // in as if the assistant had said it.
        let realHistory = history.filter((m) => m.role !== "error" && m.role !== "info")
        if (realHistory.length === 0) return newMessage
        if (realHistory.length > assistantWindow.maxPromptHistoryMessages) {
            realHistory = realHistory.slice(realHistory.length - assistantWindow.maxPromptHistoryMessages)
        }
        let lines = ["Here is our conversation so far. Respond naturally to my latest message at the end - don't repeat earlier context back to me, just continue the conversation."]
        for (let i = 0; i < realHistory.length; i++) {
            lines.push((realHistory[i].role === "user" ? "User" : "Assistant") + ": " + realHistory[i].text)
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
        let modelArgs = (Config.assistantModel && Config.assistantModel.length > 0) ? ["--model", Config.assistantModel] : []
        if (Config.assistantBackend === "codex") return ["codex", "exec"].concat(modelArgs).concat([prompt])
        if (Config.assistantBackend === "gemini") return ["gemini", "-p", prompt].concat(modelArgs)
        return ["claude", "-p", prompt].concat(modelArgs) // "claude" (default)
    }

    // Actually launches assistantProcess for a generate call - the one place
    // all three call sites (a normal send, a send that had to pull the model
    // first, and a pull-then-generate) route through, so the Ollama stdin
    // workaround below only has to be written once.
    //
    // `ollama run` blocks forever reading stdin, waiting for piped input
    // that never comes, unless it actually gets EOF - confirmed empirically
    // that Quickshell's Process still leaves its own end of the stdin pipe
    // open even with stdinEnabled: false (the child's fd 0 stays a live pipe
    // whose write end the *parent* quietly keeps open), so disabling it
    // there doesn't help. Routing through a real shell that can redirect
    // stdin from /dev/null does - model and prompt travel as env vars rather
    // than being interpolated into the command string, so this stays just
    // as injection-safe as passing them as plain argv would be.
    function launchAssistantProcess(prompt) {
        if (Config.assistantBackend === "ollama") {
            assistantProcess.environment = { "OLLAMA_RUN_MODEL": assistantWindow.ollamaModelName(), "OLLAMA_RUN_PROMPT": prompt }
            assistantProcess.command = ["fish", "-c", "ollama run \"$OLLAMA_RUN_MODEL\" \"$OLLAMA_RUN_PROMPT\" < /dev/null"]
        } else {
            assistantProcess.command = assistantWindow.backendCommand(prompt)
        }
        assistantProcess.running = true
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

    // Ollama-only: the prompt is held here between the "is the model already
    // pulled" check and the actual generate call, since those are two
    // separate process launches for this backend only (see sendMessage).
    // Empty during a standalone pull triggered from the model switcher
    // (pullModelStandalone) rather than from an actual chat message - that's
    // how the pull-finished handler tells the two apart.
    property string pendingPrompt: ""
    property bool pullActive: false
    property int pullPercent: 0
    property string pullStatus: ""
    // Set while ollamaListCheck has come back unreachable and
    // ollamaServeProcess has been launched to bring the server up -
    // distinguishes "still starting, keep polling" from a fresh failure in
    // ollamaListCheck's own handler, and lets the watchdog/cancel paths know
    // there's a retry timer to stop too.
    property bool ollamaServeStarting: false
    property bool modelMenuOpen: false
    property var availableOllamaModels: []

    function refreshOllamaModelList() {
        ollamaModelListProcess.running = true
    }

    // Pulls a model on its own, outside of sending a chat message - used by
    // the model switcher's "pull new model" row. Reuses the same
    // startOllamaPull()/ollamaPullProcess machinery a chat send does; an
    // empty pendingPrompt is what tells the pull-finished handler not to
    // follow up with a generate call once it's done.
    function pullModelStandalone(modelName) {
        let trimmed = (modelName || "").trim()
        if (!trimmed || assistantWindow.assistantBusy) return
        Config.assistantModel = trimmed
        assistantWindow.pendingPrompt = ""
        assistantWindow.assistantBusy = true
        assistantWindow.requestStartMs = Date.now()
        assistantWindow.elapsedSeconds = 0
        assistantWindow.startOllamaPull()
    }

    function ollamaModelName() {
        return (Config.assistantModel && Config.assistantModel.length > 0) ? Config.assistantModel : "llama3.2"
    }

    // `ollama list`'s NAME column always carries a tag (bare "llama3.2" is
    // stored and shown as "llama3.2:latest") - a model name configured
    // without one still has to match that.
    function ollamaHasModel(listText) {
        let want = ollamaModelName()
        let candidates = want.indexOf(":") >= 0 ? [want] : [want, want + ":latest"]
        let lines = (listText || "").split("\n").slice(1)
        for (let i = 0; i < lines.length; i++) {
            let name = lines[i].trim().split(/\s+/)[0]
            if (name && candidates.indexOf(name) !== -1) return true
        }
        return false
    }

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
        assistantWindow.pendingPrompt = fullPrompt
        // Ollama needs an extra step first: unlike the other backends
        // (each already signed into a hosted account), a fresh Ollama model
        // is a multi-GB download that has never happened yet the first time
        // it's selected - checked here so that download gets its own
        // visible progress instead of just looking like a long, silent hang
        // (see startOllamaPull()).
        assistantWatchdog.restart()
        if (Config.assistantBackend === "ollama") {
            ollamaListCheck.running = true
        } else {
            assistantWindow.launchAssistantProcess(fullPrompt)
        }
    }

    // Called the first time ollamaListCheck comes back unreachable for this
    // request. `setsid -f` forks and starts a new session before execing
    // ollama, so the launcher command here exits immediately (confirmed via
    // `setsid --help`) while the actual server keeps running fully detached
    // from this Process object - it has to survive independently since the
    // widget's own process lifecycle is much shorter than a long-running
    // server. ollamaListCheck is then re-polled on a short timer until the
    // server answers or assistantWatchdog's own timeout gives up - a cold
    // start (CUDA/driver enumeration on first launch since boot, on a
    // discrete GPU especially) can take a lot longer than a warm one, so
    // there's no separate, tighter cap here duplicating the watchdog's job.
    function startOllamaServeAndRetry() {
        assistantWindow.ollamaServeStarting = true
        Config.appendAssistantMessage("info", "Ollama isn't running - starting it now.")
        // Routed through fish -c so stdout/stderr can be redirected to a log
        // file (`serve` logs continuously - every request, plus startup
        // GPU/model discovery - and setsid -f detaches it from this
        // Process's own pipes, which nothing here ever reads; once the
        // unread pipe's buffer fills, the detached process blocks on
        // write() and hangs forever mid-startup, exactly like `ollama run`
        // blocking on unread stdin above) and stdin closed for the same
        // never-read-it reason as that stdin workaround. `>` (not `>>`)
        // truncates on every attempt, so the log always reflects only the
        // most recent start - see reportOllamaServeTimeout() below, which
        // tails it if this never comes up.
        ollamaServeProcess.command = ["fish", "-c", "mkdir -p ~/.cache/synoptik; and setsid -f ollama serve > ~/.cache/synoptik/ollama-serve.log 2>&1 < /dev/null"]
        ollamaServeProcess.running = true
        assistantWatchdog.restart()
        ollamaServeRetryTimer.restart()
    }

    // Called from assistantWatchdog when it times out while
    // ollamaServeStarting is still true. The launcher process above always
    // exits successfully near-instantly regardless of whether the detached
    // `ollama serve` itself went on to actually start (see its comment), so
    // this is the only way to surface a real reason - tailing what it
    // logged (port already in use, permission denied, etc) instead of just
    // a generic "it didn't come up".
    function reportOllamaServeTimeout() {
        ollamaServeLogTail.command = ["fish", "-c", "tail -n 8 ~/.cache/synoptik/ollama-serve.log 2>/dev/null"]
        ollamaServeLogTail.running = true
    }

    function startOllamaPull() {
        assistantWindow.pullActive = true
        assistantWindow.pullPercent = 0
        assistantWindow.pullStatus = "pulling manifest"
        Config.appendAssistantMessage("info", assistantWindow.ollamaModelName() + " isn't downloaded yet - pulling it now. This only happens once.")
        assistantWatchdog.restart()
        ollamaPullProcess.command = ["curl", "-sN", "http://localhost:11434/api/pull", "-d", JSON.stringify({ model: assistantWindow.ollamaModelName(), stream: true })]
        ollamaPullProcess.running = true
    }

    // Manual cancel - same "running = false" mechanism the watchdog timeout
    // below already uses to stop a hung/slow call. onExited's own
    // assistantBusy guard (set false here first) means the process's
    // eventual exit is a silent no-op instead of appending a second reply.
    function cancelRequest() {
        if (!assistantBusy) return
        assistantWatchdog.stop()
        ollamaServeRetryTimer.stop()
        assistantWindow.ollamaServeStarting = false
        assistantBusy = false
        if (assistantWindow.pullActive) {
            assistantWindow.pullActive = false
            ollamaPullProcess.running = false
        } else {
            assistantProcess.running = false
        }
        Config.appendAssistantMessage("error", "Cancelled.")
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
            if (assistantWindow.ollamaServeStarting) {
                assistantWindow.ollamaServeStarting = false
                ollamaServeRetryTimer.stop()
                assistantWindow.reportOllamaServeTimeout()
            } else if (assistantWindow.pullActive) {
                assistantWindow.pullActive = false
                ollamaPullProcess.running = false
                Config.appendAssistantMessage("error", "Timed out downloading " + assistantWindow.ollamaModelName() + " - check your network connection and that " + assistantWindow.pullStatus + " isn't just stuck.")
            } else {
                assistantProcess.running = false
                Config.appendAssistantMessage("error", "Timed out waiting on " + assistantWindow.backendLabel() + " - check that it's installed, signed in, and on your PATH.")
            }
        }
    }

    // Ollama-only: checked before every send because a model can be switched
    // (or a fresh pull can be interrupted, leaving it half-downloaded) at any
    // time in Settings - so "is it already here" is asked fresh each time
    // rather than cached from an earlier check.
    Process {
        id: ollamaListCheck
        command: ["ollama", "list"]
        stdout: StdioCollector { id: ollamaListStdout; waitForEnd: true }
        onExited: (exitCode) => {
            if (!assistantWindow.assistantBusy) return
            if (exitCode === 0 && assistantWindow.ollamaHasModel(ollamaListStdout.text)) {
                assistantWindow.ollamaServeStarting = false
                ollamaServeRetryTimer.stop()
                assistantWatchdog.restart()
                assistantWindow.launchAssistantProcess(assistantWindow.pendingPrompt)
            } else if (exitCode !== 0) {
                // First failure this request: try bringing the server up
                // ourselves. A failure while ollamaServeStarting is already
                // true just means it isn't up *yet* - ollamaServeRetryTimer
                // is already polling, so there's nothing more to do here
                // than let it keep ticking.
                if (!assistantWindow.ollamaServeStarting) {
                    assistantWindow.startOllamaServeAndRetry()
                }
            } else {
                assistantWindow.ollamaServeStarting = false
                ollamaServeRetryTimer.stop()
                assistantWindow.startOllamaPull()
            }
        }
    }

    // Launches `ollama serve` detached (see startOllamaServeAndRetry's
    // comment) - this Process object's own exit just means the launcher
    // command returned, not that the server stopped.
    Process {
        id: ollamaServeProcess
    }

    // Reads back whatever startOllamaServeAndRetry's ollama-serve.log ended
    // up with - see reportOllamaServeTimeout() above.
    Process {
        id: ollamaServeLogTail
        stdout: StdioCollector { id: ollamaServeLogTailStdout; waitForEnd: true }
        onExited: {
            let tail = ollamaServeLogTailStdout.text ? ollamaServeLogTailStdout.text.trim() : ""
            Config.appendAssistantMessage("error", "Timed out waiting for Ollama to start - try running `ollama serve` yourself to see why."
                + (tail.length > 0 ? "\n\nLast lines from its log:\n" + tail : ""))
        }
    }

    // Repolls ollamaListCheck until the just-started server answers.
    // assistantWatchdog (restarted alongside this in
    // startOllamaServeAndRetry) is the only timeout that applies here - see
    // that function's comment for why a second, tighter one would be wrong.
    Timer {
        id: ollamaServeRetryTimer
        interval: 500
        repeat: true
        onTriggered: {
            if (!assistantWindow.assistantBusy || !assistantWindow.ollamaServeStarting) {
                ollamaServeRetryTimer.stop()
                return
            }
            if (!ollamaListCheck.running) ollamaListCheck.running = true
        }
    }

    // Powers the model switcher dropdown - refreshed whenever it's opened
    // and after any pull finishes, so a model just pulled from the switcher
    // itself shows up without needing to reopen the widget.
    Process {
        id: ollamaModelListProcess
        command: ["ollama", "list"]
        stdout: StdioCollector { id: ollamaModelListStdout; waitForEnd: true }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                assistantWindow.availableOllamaModels = []
                return
            }
            let lines = (ollamaModelListStdout.text || "").split("\n").slice(1)
            let names = []
            for (let i = 0; i < lines.length; i++) {
                let name = lines[i].trim().split(/\s+/)[0]
                if (name) names.push(name)
            }
            assistantWindow.availableOllamaModels = names
        }
    }

    // Streams `ollama pull`'s own progress (via its plain HTTP API instead of
    // the `ollama pull` CLI, whose progress bar is drawn with carriage
    // returns and ANSI escapes meant for a terminal, not for parsing) so a
    // first-time multi-GB model download shows real percentage instead of
    // just a growing elapsed-time counter that looks identical to a hang.
    Process {
        id: ollamaPullProcess
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim()
                if (!line) return
                assistantWatchdog.restart()
                let obj
                try { obj = JSON.parse(line) } catch (e) { return }
                if (obj.error) {
                    assistantWatchdog.stop()
                    assistantWindow.pullActive = false
                    assistantWindow.assistantBusy = false
                    ollamaPullProcess.running = false
                    Config.appendAssistantMessage("error", "Failed to download " + assistantWindow.ollamaModelName() + ": " + obj.error)
                    return
                }
                if (obj.status) assistantWindow.pullStatus = obj.status
                if (obj.total && obj.completed !== undefined) {
                    assistantWindow.pullPercent = Math.round((obj.completed / obj.total) * 100)
                }
                if (obj.status === "success") {
                    assistantWindow.pullActive = false
                    assistantWindow.refreshOllamaModelList()
                    // An empty pendingPrompt means this pull came from the
                    // model switcher, not from sending a message - nothing
                    // to follow up with, so just report it finished.
                    if (assistantWindow.pendingPrompt.length > 0) {
                        assistantWatchdog.restart()
                        assistantWindow.launchAssistantProcess(assistantWindow.pendingPrompt)
                    } else {
                        assistantWatchdog.stop()
                        assistantWindow.assistantBusy = false
                        Config.appendAssistantMessage("info", "Downloaded " + assistantWindow.ollamaModelName() + " - ready to chat.")
                    }
                }
            }
        }
        stderr: StdioCollector { id: ollamaPullStderr; waitForEnd: true }
        onExited: (exitCode) => {
            // A clean pull already flipped pullActive off from the
            // "success" status line above - this only fires for real for a
            // curl that died before that line ever arrived (network drop,
            // server not running, disk full, etc).
            if (!assistantWindow.assistantBusy || !assistantWindow.pullActive) return
            assistantWatchdog.stop()
            assistantWindow.pullActive = false
            assistantWindow.assistantBusy = false
            let err = ollamaPullStderr.text ? ollamaPullStderr.text.trim() : ""
            Config.appendAssistantMessage("error", "Failed to download " + assistantWindow.ollamaModelName() + (err.length > 0 ? ": " + err : " - curl exited " + exitCode + ". Is Ollama running? Try `ollama serve`."))
        }
    }

    Process {
        id: assistantProcess
        // Confirmed empirically: `ollama run <model> <prompt>` checks
        // whether stdin is a TTY and, if not, blocks waiting to read
        // additional piped input before it'll generate anything - and
        // Process's stdin defaults to an open, never-closed pipe (no EOF
        // ever arrives since nothing here writes to or closes it), so every
        // Ollama call hung forever until its own watchdog timeout killed it.
        // The other backends never read stdin at all, so disabling it here
        // is safe for all four.
        stdinEnabled: false
        stdout: StdioCollector { id: assistantStdout; waitForEnd: true }
        stderr: StdioCollector { id: assistantStderr; waitForEnd: true }

        // On a non-zero exit the CLIs still write their own human-readable
        // explanation to stdout before exiting (confirmed empirically - e.g.
        // Claude CLI's "usage limit reached" / "issue with the selected
        // model" messages land on stdout, not stderr) - previously that text
        // was thrown away whenever exitCode wasn't 0, leaving only a bare
        // "exit code 1" behind it. Now stdout wins whenever it has anything
        // in it, success or failure, and stderr is just the fallback for the
        // rarer case where the CLI died before printing anything useful.
        onExited: (exitCode, exitStatus) => {
            if (!assistantWindow.assistantBusy) return
            assistantWatchdog.stop()
            assistantWindow.assistantBusy = false
            let outText = assistantStdout.text ? assistantStdout.text.trim() : ""
            let errText = assistantStderr.text ? assistantStderr.text.trim() : ""
            if (Config.assistantBackend === "ollama") outText = assistantWindow.stripOllamaLineWrapCodes(outText)
            if (exitCode === 0 && outText.length > 0) {
                Config.appendAssistantMessage("assistant", outText)
            } else if (outText.length > 0) {
                Config.appendAssistantMessage("error", outText)
            } else if (errText.length > 0) {
                Config.appendAssistantMessage("error", errText)
            } else {
                Config.appendAssistantMessage("error", assistantWindow.backendLabel() + " exited with code " + exitCode + " and printed nothing.")
            }
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

        // Ollama model switcher: lists whatever's already pulled locally,
        // plus a field to pull a new one by name - so picking or fetching a
        // model never has to leave the widget for a terminal. Same
        // positioning approach as backendDropdown above.
        Rectangle {
            id: modelDropdown
            visible: assistantWindow.modelMenuOpen
            z: 999
            width: 200
            implicitHeight: modelDropdownColumn.implicitHeight + 8
            radius: Config.cornerRadius / 2
            color: Config.bgPanel
            border.width: Config.showBorders ? Config.borderThickness : 1
            border.color: (typeof shellRoot !== "undefined" && shellRoot.currentBorderColor) ? shellRoot.currentBorderColor : Qt.rgba(255, 255, 255, 0.1)

            // Right-aligned to the pill (unlike backendDropdown, which is
            // left-aligned) because modelPill sits near the card's right
            // edge - left-aligning a 200px-wide dropdown there ran it off
            // the edge of the card entirely. Still clamped into the card's
            // own width on top of that, in case the card gets resized down
            // narrower than the dropdown.
            function reposition() {
                if (typeof modelPill === "undefined") return
                let pos = modelPill.mapToItem(assistantContainer, modelPill.width, modelPill.height + 4)
                modelDropdown.x = Math.max(0, Math.min(pos.x - modelDropdown.width, assistantContainer.cardWidth - modelDropdown.width))
                modelDropdown.y = pos.y
            }
            onVisibleChanged: if (visible) reposition()

            Column {
                id: modelDropdownColumn
                anchors.fill: parent
                anchors.margins: 4
                spacing: 2

                Repeater {
                    model: assistantWindow.availableOllamaModels

                    Rectangle {
                        width: modelDropdownColumn.width
                        implicitHeight: 28
                        radius: Config.cornerRadius / 3
                        color: assistantWindow.ollamaModelName() === modelData
                            ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.18)
                            : (modelRowHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent")

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData
                            elide: Text.ElideRight
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                        }

                        TapHandler {
                            onTapped: {
                                Config.assistantModel = modelData
                                assistantWindow.modelMenuOpen = false
                            }
                        }
                        HoverHandler { id: modelRowHover; cursorShape: Qt.PointingHandCursor }
                    }
                }

                Text {
                    visible: assistantWindow.availableOllamaModels.length === 0
                    width: modelDropdownColumn.width
                    text: "No models pulled yet"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    width: modelDropdownColumn.width
                    height: 1
                    color: Qt.rgba(255, 255, 255, 0.08)
                }

                RowLayout {
                    width: modelDropdownColumn.width
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: Config.cornerRadius / 3
                        color: "transparent"
                        border.width: 1
                        border.color: newModelInput.activeFocus ? Config.accent : Qt.rgba(255, 255, 255, 0.12)
                        clip: true

                        TextInput {
                            id: newModelInput
                            anchors.fill: parent
                            anchors.margins: 6
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            clip: true

                            Text {
                                anchors.fill: parent
                                text: "pull new model..."
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                verticalAlignment: Text.AlignVCenter
                                visible: newModelInput.text.length === 0 && !newModelInput.activeFocus
                            }

                            onAccepted: {
                                let name = newModelInput.text.trim()
                                if (name.length === 0 || assistantWindow.assistantBusy) return
                                assistantWindow.modelMenuOpen = false
                                newModelInput.text = ""
                                assistantWindow.pullModelStandalone(name)
                            }
                            HoverHandler { cursorShape: Qt.IBeamCursor }
                        }
                    }

                    Text {
                        text: "download"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                        color: pullGoHover.hovered ? Config.accent : Config.textMuted

                        TapHandler {
                            onTapped: {
                                let name = newModelInput.text.trim()
                                if (name.length === 0 || assistantWindow.assistantBusy) return
                                assistantWindow.modelMenuOpen = false
                                newModelInput.text = ""
                                assistantWindow.pullModelStandalone(name)
                            }
                        }
                        HoverHandler { id: pullGoHover; cursorShape: Qt.PointingHandCursor }
                    }
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

                    Item { Layout.fillWidth: true }

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

                    // Ollama is the only backend with a local, switchable
                    // model - the others are a hosted account's own default
                    // (or an optional --model override set once in
                    // Settings), not something to flip between mid-chat.
                    Rectangle {
                        id: modelPill
                        visible: Config.assistantBackend === "ollama"
                        Layout.maximumWidth: 150
                        implicitWidth: Math.min(150, modelPillRow.implicitWidth + 16)
                        implicitHeight: modelPillRow.implicitHeight + 6
                        radius: Config.cornerRadius / 3
                        color: modelPillHover.hovered ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.08)

                        RowLayout {
                            id: modelPillRow
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                Layout.maximumWidth: 110
                                text: assistantWindow.ollamaModelName()
                                elide: Text.ElideRight
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

                        TapHandler {
                            onTapped: {
                                assistantWindow.modelMenuOpen = !assistantWindow.modelMenuOpen
                                if (assistantWindow.modelMenuOpen) assistantWindow.refreshOllamaModelList()
                            }
                        }
                        HoverHandler { id: modelPillHover; cursorShape: Qt.PointingHandCursor }
                    }

                    Text {
                        text: "text_decrease"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                        color: fontDecHover.hovered ? Config.accent : Config.textMuted

                        TapHandler { onTapped: assistantWindow.adjustFontScale(-0.1) }
                        HoverHandler { id: fontDecHover; cursorShape: Qt.PointingHandCursor }
                    }

                    Text {
                        text: "text_increase"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                        color: fontIncHover.hovered ? Config.accent : Config.textMuted

                        TapHandler { onTapped: assistantWindow.adjustFontScale(0.1) }
                        HoverHandler { id: fontIncHover; cursorShape: Qt.PointingHandCursor }
                    }

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
                        font.pixelSize: Config.size(Config.fontCaption) * Config.assistantFontScale
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
                            readonly property bool isError: modelData.role === "error"
                            readonly property bool isInfo: modelData.role === "info"
                            readonly property bool isDiagnostic: isError || isInfo
                            width: messageList.width
                            implicitHeight: contentRow.implicitHeight

                            RowLayout {
                                id: contentRow
                                width: parent.width
                                spacing: 6

                                // Only the assistant gets a badge - it's the
                                // assistant's own avatar, not the user's. A
                                // diagnostic (error or info) isn't the
                                // assistant talking either, so it gets a
                                // plain glyph instead.
                                AssistantBadge {
                                    diameter: 48
                                    visible: !isUser && !isDiagnostic
                                    Layout.alignment: Qt.AlignTop
                                }

                                Text {
                                    text: isError ? "warning" : "info"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 28
                                    color: Config.textMuted
                                    visible: isDiagnostic
                                    Layout.alignment: Qt.AlignTop
                                }

                                Rectangle {
                                    id: bubbleRect
                                    Layout.fillWidth: true
                                    implicitHeight: bubbleText.implicitHeight + 16
                                    radius: Config.cornerRadius / 2
                                    border.width: isDiagnostic ? 1 : 0
                                    border.color: isError ? Qt.rgba(1, 0.6, 0.3, 0.5) : Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.4)
                                    color: isUser
                                        ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.22)
                                        : (isError ? Qt.rgba(1, 0.6, 0.3, 0.12) : (isInfo ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.1) : Qt.rgba(255, 255, 255, 0.06)))

                                    HoverHandler { id: bubbleHover }

                                    Text {
                                        id: bubbleText
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        text: modelData.text
                                        color: isError ? "#ffb380" : Config.textMain
                                        font.family: Config.sysFont
                                        font.italic: isDiagnostic
                                        font.pixelSize: Config.size(Config.fontCaption) * Config.assistantFontScale
                                        wrapMode: Text.WordWrap
                                    }

                                    // Copy-to-clipboard for assistant replies
                                    // only - not the user's own typed text,
                                    // and not error/info diagnostics, which
                                    // aren't real replies. Hover-revealed
                                    // rather than a permanent icon on every
                                    // bubble, which would clutter a card
                                    // this narrow. Same wl-copy pattern
                                    // LauncherOSD.qml already uses for its
                                    // calculator result - execDetached's
                                    // argv array needs no shell escaping.
                                    Rectangle {
                                        visible: !isUser && !isDiagnostic && (bubbleHover.hovered || copyFeedback.running)
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 4
                                        width: 22
                                        height: 22
                                        radius: 5
                                        color: copyIconHover.hovered ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(0, 0, 0, 0.35)

                                        Text {
                                            anchors.centerIn: parent
                                            text: copyFeedback.running ? "check" : "content_copy"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 13
                                            color: copyFeedback.running ? "#8fdc9a" : Config.textMuted
                                        }

                                        TapHandler {
                                            onTapped: {
                                                Quickshell.execDetached(["wl-copy", modelData.text])
                                                copyFeedback.restart()
                                            }
                                        }
                                        HoverHandler { id: copyIconHover; cursorShape: Qt.PointingHandCursor }
                                    }

                                    Timer { id: copyFeedback; interval: 1200 }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: assistantWindow.assistantBusy
                    spacing: 4

                    // Real download progress, driven by the same pullPercent
                    // that streams in from ollamaPullProcess's parsed JSON
                    // (see that Process above) - a filled track instead of
                    // just a number, so a stalled download is visible as a
                    // stalled bar and not just a text string that happens to
                    // repeat. Only shown for the pull itself; a plain
                    // generate call has no percentage to report, just the
                    // elapsed-time text below.
                    Rectangle {
                        Layout.fillWidth: true
                        visible: assistantWindow.pullActive
                        implicitHeight: 5
                        radius: 2.5
                        color: Qt.rgba(255, 255, 255, 0.08)
                        clip: true

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            color: Config.accent
                            width: parent.width * Math.max(0, Math.min(100, assistantWindow.pullPercent)) / 100

                            Behavior on width {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            // A pulled-by-name model (e.g. a full hf.co/user/repo
                            // reference) can easily be longer than the whole
                            // card is wide - elided so it truncates instead of
                            // overflowing straight through the CANCEL text next
                            // to it.
                            elide: Text.ElideRight
                            text: assistantWindow.pullActive
                                ? (assistantWindow.pullPercent > 0
                                    ? (assistantWindow.ollamaModelName() + " - " + assistantWindow.pullPercent + "%")
                                    : (assistantWindow.ollamaModelName() + " - " + assistantWindow.pullStatus))
                                : (assistantWindow.ollamaServeStarting
                                    ? ("Starting Ollama... (" + assistantWindow.elapsedSeconds + "s)")
                                    : ("Waiting on " + assistantWindow.backendLabel() + "... (" + assistantWindow.elapsedSeconds + "s)"))
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
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Math.max(32, Config.size(Config.fontCaption) * Config.assistantFontScale + 16)
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
                            font.pixelSize: Config.size(Config.fontCaption) * Config.assistantFontScale
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            clip: true

                            Text {
                                anchors.fill: parent
                                text: "Ask your assistant..."
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption) * Config.assistantFontScale
                                verticalAlignment: Text.AlignVCenter
                                visible: chatInput.text.length === 0 && !chatInput.activeFocus
                            }

                            onAccepted: {
                                assistantWindow.sendMessage(text)
                                text = ""
                            }

                            HoverHandler { id: chatInputHover; cursorShape: Qt.IBeamCursor }
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
                    if (assistantWindow.modelMenuOpen) {
                        assistantWindow.modelMenuOpen = false
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
