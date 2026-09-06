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
    property string mascotPath: ""
    property bool mascotAudioThrob: true
    property var mascotPhrases: [
        "I use Arch btw",
        "Hyprland is so comfy",
        "Need some coffee?",
        "Compiling...",
        "Look at me go!"
    ]

    property bool fetchOnlineQuotes: false
    property string quoteSource: "zenquotes"
    property string rssFeedUrl: ""

    // Per-screen saved drag position, same shape/pattern as Clock's
    // clockPositions in DesktopWidgetsConfig.qml. Unlike Clock/Cava (one
    // instance per enabled screen), the mascot is a single roaming instance
    // that has to pick ONE screen to live on at startup - mascotLastScreen
    // records which one, so it doesn't just fall back to whatever monitor
    // happens to be focused/first on a given launch.
    property var mascotPositions: ({})
    property string mascotLastScreen: ""

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
    property string assistantBackend: "claude" // "claude" | "codex" | "gemini"
    property string assistantModel: "" // optional --model override passed to the backend CLI

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

    // Badge image shown in the header and inline next to assistant replies,
    // same "" -> fall back to a default glyph pattern as mascotPath.
    property string assistantBadgePath: ""

    // Paths the user has browsed to and picked as a badge - NOT copies of
    // the files (those stay wherever they already are on disk), just
    // remembered paths, so they reappear as selectable thumbnails next to
    // the bundled "Default images" without needing to duplicate anything
    // into the shell's own (git-tracked, update-overwritten) assets folder.
    // settings.json itself is gitignored, so this list survives updates the
    // same way every other setting already does.
    property var assistantCustomBadges: []

    function addCustomBadge(path) {
        if (!path) return
        let list = assistantCustomBadges ? assistantCustomBadges.slice() : []
        if (list.indexOf(path) !== -1) return
        list.push(path)
        assistantCustomBadges = list
    }

    function removeCustomBadge(path) {
        let list = assistantCustomBadges ? assistantCustomBadges.slice() : []
        let idx = list.indexOf(path)
        if (idx === -1) return
        list.splice(idx, 1)
        assistantCustomBadges = list
    }

    onAssistantCustomBadgesChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

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

    function appendAssistantMessage(role, text) {
        let list = assistantMessages ? assistantMessages.slice() : []
        list.push({ role: role, text: text })
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

    function addMascotPhrase(phrase) {
        if (!phrase) return
        var list = mascotPhrases ? mascotPhrases.slice() : []
        list.push(phrase)
        mascotPhrases = list
        if (configRef) configRef.saveSettings()
    }

    function removeMascotPhrase(index) {
        if (!mascotPhrases || index < 0 || index >= mascotPhrases.length) return
        var list = mascotPhrases.slice()
        list.splice(index, 1)
        mascotPhrases = list
        if (configRef) configRef.saveSettings()
    }

    function processQuoteQueue() {
        if (configRef) configRef.quoteService.processQuoteQueue()
    }

    function triggerQuoteFetch() {
        if (configRef) configRef.quoteService.triggerQuoteFetch()
    }

    onShowScreensaverChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onScreensaverTextChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onScreensaverModeChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onScreensaverFontSizeChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onScreensaverSpeedChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onScreensaverCornerCounterChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onShowOskChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onOskLayoutChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onShowMascotChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onMascotPathChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onMascotAudioThrobChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onMascotPhrasesChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    onFetchOnlineQuotesChanged: {
        if (!configRef || !configRef.isLoaded) return
        if (fetchOnlineQuotes) triggerQuoteFetch()
        configRef.saveSettings()
    }

    onQuoteSourceChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    onShowAssistantChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onAssistantBackendChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onAssistantModelChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onAssistantBadgePathChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onAssistantTimeoutSecondsChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onAssistantFontScaleChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
}
