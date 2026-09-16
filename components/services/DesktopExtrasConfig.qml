import QtQuick

QtObject {
    property var configRef: null

    // --- ON-SCREEN KEYBOARD (OSK) STATE & PERSISTENCE ---
    property bool showOsk: false
    property string oskLayout: "Normal"

    // --- DESKTOP SCREENSAVER STATE & PERSISTENCE ---
    property bool showScreensaver: false
    property string screensaverText: "SYNOPTIK"
    property string screensaverMode: "text"
    property int screensaverFontSize: 54
    property real screensaverSpeed: 3.5
    property bool screensaverCornerCounter: true

    // --- DESKTOP MASCOT STATE & PERSISTENCE ---
    property bool showMascot: false
    property bool mascotAudioThrob: true

    // Per-state animation clips: { stateName: "/abs/path/clip.webp" }. State
    // names come from MascotState.allStateNames. The mascot is a single
    // fixed bundled character - there is no per-user custom image - so this
    // is always seeded with Config.builtinMascotDir's clip set on first load
    // (see Config.qml's applyLoadedSettings) and MascotState.clipPathFor()
    // falls back to that same built-in set if a name is ever missing here.
    //
    // Stored as paths rather than a set directory + naming convention so a
    // single clip can be swapped or borrowed from elsewhere without moving
    // files around; setMascotClipSet() below writes the conventional layout
    // into this same map for the common case.
    property var mascotClips: ({})

    function setMascotClip(stateName, path) {
        if (!stateName) return
        let next = Object.assign({}, mascotClips)
        if (!path || path === "") delete next[stateName]
        else next[stateName] = path
        mascotClips = next
        if (configRef) configRef.saveSettings()
    }

    function clearMascotClips() {
        mascotClips = ({})
        if (configRef) configRef.saveSettings()
    }

    // Bulk-register a conventionally laid out set: <dir>/<state>.<ext> for
    // every state named. Only states whose file the caller actually found
    // should be passed in - this does no existence checking of its own,
    // since QML has no synchronous stat and a wrong entry here would defeat
    // the fallback chain by pointing at a file that cannot load.
    function setMascotClipSet(dir, stateNames, ext) {
        if (!dir || !stateNames) return
        let suffix = ext || "webp"
        let base = dir.endsWith("/") ? dir : (dir + "/")
        let next = Object.assign({}, mascotClips)
        for (let i = 0; i < stateNames.length; i++) {
            next[stateNames[i]] = base + stateNames[i] + "." + suffix
        }
        mascotClips = next
        if (configRef) configRef.saveSettings()
    }
    // Per-screen saved drag position, same shape/pattern as Clock's
    // clockPositions in DesktopWidgetsConfig.qml. Unlike Clock/Cava (one
    // instance per enabled screen), the mascot is a single roaming instance
    // that has to pick ONE screen to live on at startup - mascotLastScreen
    // records which one, so it doesn't just fall back to whatever monitor
    // happens to be focused/first on a given launch.
    property var mascotPositions: ({})
    property string mascotLastScreen: ""

    // Wheel-adjusted size of the collapsed character, as the width in px (its
    // height follows from the clip's aspect ratio). Persisted for the same
    // reason assistantWidth/Height below are: the expanded panel remembered
    // the size you gave it across a reload while the character always snapped
    // back to 128, which reads as the shell forgetting rather than as a
    // deliberate difference between the two forms.
    property real mascotSize: 128

    function saveMascotSize(size) {
        mascotSize = Math.max(32, size)
        if (configRef) configRef.saveSettings()
    }

    function getMascotPosition(screenName, defaultX, defaultY) {
        if (mascotPositions && mascotPositions[screenName]) {
            return mascotPositions[screenName]
        }
        return { x: defaultX, y: defaultY }
    }

    function saveMascotPosition(screenName, x, y) {
        let current = Object.assign({}, mascotPositions)
        current[screenName] = { x: x, y: y }
        mascotPositions = current
        mascotLastScreen = screenName
        if (configRef) configRef.saveSettings()
    }

    // --- DESKTOP ASSISTANT STATE & PERSISTENCE ---
    // No credentials live here: the assistant shells out to a CLI the user
    // already has installed and signed into (Claude Code / Codex CLI /
    // Gemini CLI), each in its own one-shot headless mode - auth (whichever
    // personal subscription or API key that CLI is configured with) is
    // entirely that CLI's own business.
    property bool showAssistant: false
    property string assistantBackend: "claude" // "claude" | "codex" | "gemini" | "ollama"
    property string assistantModel: "" // optional --model override passed to claude/codex/gemini only
    // Ollama's own model selection lives separately from assistantModel
    // above - they used to share one field, which meant picking/pulling an
    // Ollama model (from the widget's own in-panel switcher) silently
    // overwrote whatever --model override was set for Claude/Codex/Gemini,
    // so switching back to one of those backends would try to launch it
    // with an Ollama model name (e.g. "claude --model llama3.2:latest",
    // which claude naturally rejects as an unknown model).
    property string assistantOllamaModel: ""

    // How long to wait for a reply before giving up - some backends/models/
    // questions genuinely take longer than a short fixed timeout. 120s (was
    // a hardcoded 45s) is a more realistic default given real usage already
    // hit that ceiling on an ordinary question.
    property int assistantTimeoutSeconds: 120

    // Text scale for the conversation area (message bubbles + input field) -
    // a single global value, not per-screen, since the assistant is a
    // single roaming instance like Mascot/the media card rather than one
    // instance per monitor.
    property real assistantFontScale: 1.0

    // A normal resizable/draggable desktop panel, same model as the detached
    // media card - see mediaCardWidth/mediaCardPositions above for the
    // pattern this mirrors.
    property real assistantWidth: 320
    property real assistantHeight: 420

    function saveAssistantSize(width, height) {
        assistantWidth = width
        assistantHeight = height
        if (configRef) configRef.saveSettings()
    }

    // Per-screen saved drag position, same shape/pattern as mediaCardPositions
    // above - the assistant is also a single roaming instance (not one per
    // enabled screen like Clock/Cava), so assistantLastScreen records which
    // screen to restore to at startup.
    property var assistantPositions: ({})
    property string assistantLastScreen: ""

    function getAssistantPosition(screenName, defaultX, defaultY) {
        if (assistantPositions && assistantPositions[screenName]) {
            return assistantPositions[screenName]
        }
        return { x: defaultX, y: defaultY }
    }

    function saveAssistantPosition(screenName, x, y) {
        let current = Object.assign({}, assistantPositions)
        current[screenName] = { x: x, y: y }
        assistantPositions = current
        assistantLastScreen = screenName
        if (configRef) configRef.saveSettings()
    }

    // Conversation history, persisted so it survives a shell reload - same
    // 100-entry cap as NotificationHistoryService's maxEntries, applied here
    // (not in a setter) so it's enforced regardless of what appends a
    // message.
    readonly property int assistantMaxMessages: 100
    property var assistantMessages: []

    // imagePath is a cache-file reference (not the image bytes themselves) -
    // keeps a pasted screenshot from bloating the persisted settings file
    // the same way the message text does. Optional so every existing
    // call site (plain text messages) doesn't need to change.
    function appendAssistantMessage(role, text, imagePath) {
        let list = assistantMessages ? assistantMessages.slice() : []
        list.push({ role: role, text: text, imagePath: imagePath || "" })
        if (list.length > assistantMaxMessages) list = list.slice(list.length - assistantMaxMessages)
        assistantMessages = list
    }

    function clearAssistantMessages() {
        assistantMessages = []
    }

    onAssistantMessagesChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    // --- DETACHED DESKTOP MEDIA CARD STATE & PERSISTENCE ---
    // A layer-shell PanelWindow like Clock/Mascot/etc, not a real xdg
    // toplevel - so position, size, and drag/resize are all ours to manage
    // and persist (same drag-anchor + snap-grid model as the rest).
    property bool showDesktopMediaCard: false
    property real mediaCardWidth: 232
    property real mediaCardHeight: 108

    function saveMediaCardSize(width, height) {
        mediaCardWidth = width
        mediaCardHeight = height
        if (configRef) configRef.saveSettings()
    }

    // Per-screen saved drag position, same shape/pattern as mascotPositions
    // above - the media card is also a single roaming instance (not one per
    // enabled screen like Clock/Cava), so mediaCardLastScreen records which
    // screen to restore to at startup.
    property var mediaCardPositions: ({})
    property string mediaCardLastScreen: ""

    function getMediaCardPosition(screenName, defaultX, defaultY) {
        if (mediaCardPositions && mediaCardPositions[screenName]) {
            return mediaCardPositions[screenName]
        }
        return { x: defaultX, y: defaultY }
    }

    function saveMediaCardPosition(screenName, x, y) {
        let current = Object.assign({}, mediaCardPositions)
        current[screenName] = { x: x, y: y }
        mediaCardPositions = current
        mediaCardLastScreen = screenName
        if (configRef) configRef.saveSettings()
    }

    onShowDesktopMediaCardChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    onShowScreensaverChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onScreensaverTextChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onScreensaverModeChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onScreensaverFontSizeChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onScreensaverSpeedChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onScreensaverCornerCounterChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onShowOskChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onOskLayoutChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onShowMascotChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onMascotAudioThrobChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    onShowAssistantChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onAssistantBackendChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onAssistantModelChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onAssistantTimeoutSecondsChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onAssistantFontScaleChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
}
