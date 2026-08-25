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
    onMascotPhrasesChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    onFetchOnlineQuotesChanged: {
        if (!configRef || !configRef.isLoaded) return
        if (fetchOnlineQuotes) triggerQuoteFetch()
        configRef.saveSettings()
    }

    onQuoteSourceChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
}
