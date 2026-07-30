pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "settings"

QtObject {
    id: root

    // --- INITIALIZATION GUARD ---
    property bool isLoaded: false

    // UI Toggle States
    property bool showSettings: false
    property bool showCalendar: false
    property bool showWallpaper: false
    property bool showAppLauncher: false
    property bool showNotifications: false
    property bool showNetwork: false
    property bool showAudio: false
    property bool showBluetooth: false
    property bool showWifi: false
    property bool showOSD: false
    property bool showWorkspacePreview: false
    property bool showNotificationOsd: false
    property bool showControlCenter: false
    property bool showBattery: false
    property bool showSystemMonitor: false
    property bool showPower: false
    property bool showClipboard: false
    property bool showScreenRecorder: false

    // --- WALLPAPER CONFIG STATE & PERSISTENCE ---
    property var selectedWallpaperMonitors: []
    property string wallpaperTransitionType: "wipe"

    function toggleWallpaperMonitor(screenName) {
        let current = selectedWallpaperMonitors ? selectedWallpaperMonitors.slice() : []
        let idx = current.indexOf(screenName)

        if (idx >= 0) {
            current.splice(idx, 1)
        } else {
            current.push(screenName)
        }

        selectedWallpaperMonitors = current
        saveSettings()
    }

    // --- GLOBAL WEATHER SERVICE ---
    property WeatherSettings weather: WeatherSettings {
        id: globalWeather
        zipcode: root.locationQuery || ""
        
        onZipcodeChanged: globalWeather.fetchWeather(true)
    }

    property Timer weatherTimer: Timer {
        interval: 900000 // 15 minutes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.weather.fetchWeather(true)
    }

    onSelectedWallpaperMonitorsChanged: { if (isLoaded) saveSettings() }
    onWallpaperTransitionTypeChanged: { if (isLoaded) saveSettings() }

    // --- ON-SCREEN KEYBOARD (OSK) STATE & PERSISTENCE ---
    property bool showOsk: false
    property string oskLayout: "Normal"

    // Global Visual Toggles
    property bool showBorders: true
    property bool animateGradient: true
    property bool showScreenFrame: false

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

    function addMascotPhrase(phrase) {
        if (!phrase) return
        var list = mascotPhrases ? mascotPhrases.slice() : []
        list.push(phrase)
        mascotPhrases = list
        saveSettings()
    }

    function removeMascotPhrase(index) {
        if (!mascotPhrases || index < 0 || index >= mascotPhrases.length) return
        var list = mascotPhrases.slice()
        list.splice(index, 1)
        mascotPhrases = list
        saveSettings()
    }

    property string rssFeedUrl: ""
    property var quoteFetchQueue: []

    property Process quoteFetcher: Process {
        id: qFetcher
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let text = this.text.trim()
                    if (text.length > 0) {
                        let fetchedQuote = ""

                        if (text.startsWith("{") || text.startsWith("[")) {
                            let json = JSON.parse(text)
                            if (Array.isArray(json) && json.length > 0 && json[0].q) {
                                fetchedQuote = json[0].q + " — " + json[0].a
                            } else if (json.setup && json.punchline) {
                                fetchedQuote = json.setup + " " + json.punchline
                            } else if (json.quote) {
                                fetchedQuote = json.quote + " — " + json.author
                            }
                        } else {
                            fetchedQuote = text
                        }

                        if (fetchedQuote.length > 0) {
                            root.addMascotPhrase(fetchedQuote)
                        }
                    }
                } catch (e) {
                    console.error("Failed to parse quote feed output:", e)
                }

                root.processQuoteQueue()
            }
        }
    }

    function processQuoteQueue() {
        let queue = quoteFetchQueue ? quoteFetchQueue.slice() : []
        if (queue.length === 0 || qFetcher.running || (mascotPhrases && mascotPhrases.length >= 20)) {
            quoteFetchQueue = []
            return
        }

        let nextSource = queue.shift()
        quoteFetchQueue = queue
        let cmd = ""

        if (nextSource === "zenquotes") {
            cmd = "curl -sS --max-time 5 'https://zenquotes.io/api/random'"
        } else if (nextSource === "jokeapi") {
            cmd = "curl -sS --max-time 5 'https://official-joke-api.appspot.com/random_joke'"
        } else if (nextSource === "rss" && rssFeedUrl !== "") {
            let pyParse = "import sys, xml.etree.ElementTree as ET, random; " +
                          "root = ET.fromstring(sys.stdin.read()); " +
                          "items = root.findall('.//item'); " +
                          "item = random.choice(items) if items else None; " +
                          "desc = item.find('description').text if item is not None and item.find('description') is not None else ''; " +
                          "title = item.find('title').text if item is not None and item.find('title') is not None else ''; " +
                          "print(f'{desc} — {title}' if desc and title else (desc or title))"
            
            cmd = "curl -sS -L --max-time 5 '" + rssFeedUrl + "' | python3 -c \"" + pyParse + "\""
        }

        if (cmd !== "") {
            qFetcher.command = ["fish", "-c", cmd]
            qFetcher.running = true
        } else {
            processQuoteQueue()
        }
    }

    function triggerQuoteFetch() {
        if (!fetchOnlineQuotes) return

        let currentCount = mascotPhrases ? mascotPhrases.length : 0
        let needed = 20 - currentCount
        if (needed <= 0) return

        let activeSources = []
        if (quoteSource === "both" || quoteSource === "zenquotes") activeSources.push("zenquotes")
        if (quoteSource === "both" || quoteSource === "jokeapi") activeSources.push("jokeapi")
        if (quoteSource === "rss" && rssFeedUrl !== "") activeSources.push("rss")

        if (activeSources.length === 0) return

        let newQueue = []
        if (activeSources.length > 1) {
            let share = Math.floor(needed / activeSources.length)
            let remainder = needed % activeSources.length

            for (let s = 0; s < activeSources.length; s++) {
                let count = share + (s < remainder ? 1 : 0)
                for (let c = 0; c < count; c++) {
                    newQueue.push(activeSources[s])
                }
            }
        } else {
            let src = activeSources[0]
            for (let k = 0; k < needed; k++) newQueue.push(src)
        }

        quoteFetchQueue = newQueue
        processQuoteQueue()
    }

    property Timer quoteFetchTimer: Timer {
        interval: 900000
        running: root.fetchOnlineQuotes && (!root.mascotPhrases || root.mascotPhrases.length < 20)
        repeat: true
        onTriggered: root.triggerQuoteFetch()
    }

    // --- BAR POSITION CONTROL ---
    property string barPosition: "top"

    function syncScreenFrame() {
        let frameMargin = showScreenFrame ? 12 : 0
        let cmd = "hyprctl keyword monitor ,addreserved," + frameMargin + "," + frameMargin + "," + frameMargin + "," + frameMargin
        writer.command = ["fish", "-c", cmd]
        writer.running = true
    }

    onShowScreenFrameChanged: {
        if (!isLoaded) return
        syncScreenFrame()
        saveSettings()
    }

    // Typography
    property string sysFont: ""
    property bool fontDropdownOpen: false
    property string fontSearchFilter: ""
    property int fontScaleIndex: 1 

    function fontStyle(fontObj) {
        if (!fontObj) return fontObj
        fontObj.hintingPreference = Font.PreferFullHinting
        fontObj.styleName = "Regular"
        return fontObj
    }

    property string locationQuery: ""
    property int currentThemeIndex: 0

    // Custom Colors
    property bool useCustomColors: false
    property string customBgBase: "#13141c"
    property string customBgPanel: "#1a1b26"
    property string customAccent: "#ff4da6"

    property color borderStart: accent
    property color borderEnd: Qt.lighter(accent, 1.5)

    property string windowStyle: "rounded"

    onWindowStyleChanged: { if (isLoaded) saveSettings() }
    onShowOskChanged: { if (isLoaded) saveSettings() }
    onOskLayoutChanged: { if (isLoaded) saveSettings() }
    onShowMascotChanged: { if (isLoaded) saveSettings() }
    onMascotPathChanged: { if (isLoaded) saveSettings() }
    onMascotPhrasesChanged: { if (isLoaded) saveSettings() }

    onFetchOnlineQuotesChanged: {
        if (!isLoaded) return
        if (fetchOnlineQuotes) triggerQuoteFetch()
        saveSettings()
    }

    onQuoteSourceChanged: { if (isLoaded) saveSettings() }
    onBarPositionChanged: { if (isLoaded) saveSettings() }
    onSysFontChanged: { if (isLoaded && sysFont !== "") saveSettings() }
    onFontScaleIndexChanged: { if (isLoaded) saveSettings() }
    onLocationQueryChanged: { if (isLoaded) saveSettings() }

    onShowBordersChanged: {
        if (!isLoaded) return
        syncHyprlandBorders()
        saveSettings()
    }

    onAnimateGradientChanged: {
        if (!isLoaded) return
        syncHyprlandBorders()
        saveSettings()
    }

    onCustomBgBaseChanged: {
        if (!isLoaded) return
        if (useCustomColors) bgBase = customBgBase
        saveSettings()
    }

    onCustomBgPanelChanged: {
        if (!isLoaded) return
        if (useCustomColors) bgPanel = customBgPanel
        saveSettings()
    }

    onCustomAccentChanged: {
        if (!isLoaded) return
        if (useCustomColors) {
            accent = customAccent
            syncHyprlandBorders()
        }
        saveSettings()
    }

    onUseCustomColorsChanged: {
        if (!isLoaded) return
        applyTheme(currentThemeIndex)
        saveSettings()
    }

    // Display Targets
    property var enabledBarScreens: []

    function toggleBarScreen(screenName) {
        let current = (enabledBarScreens.length === 0) 
            ? Quickshell.screens.map(s => s.name) 
            : enabledBarScreens.slice()

        let idx = current.indexOf(screenName)
        if (idx >= 0) {
            if (current.length > 1) current.splice(idx, 1)
        } else {
            current.push(screenName)
        }

        enabledBarScreens = current
        saveSettings()
    }

    function isBarEnabledForScreen(screenName) {
        if (!enabledBarScreens || enabledBarScreens.length === 0) return true
        return enabledBarScreens.includes(screenName)
    }

    // Hyprland Exporter
    property Process themeWriter: Process { id: writer }
    readonly property string hyprThemePath: Quickshell.env("HOME") + "/.config/hypr/theme_colors.lua"

    function syncHyprlandBorders() {
        let colorStart = "rgba(" + accent.toString().replace("#", "") + "ff)"
        let colorEnd = "rgba(" + borderEnd.toString().replace("#", "") + "ff)"
        let inactiveStr = "rgba(" + bgPanel.toString().replace("#", "") + "aa)"

        let activeStr = animateGradient 
            ? colorStart + " " + colorEnd + " 45deg"
            : colorStart

        let activeLua = animateGradient
            ? '{ colors = { "' + colorStart + '", "' + colorEnd + '" }, angle = 45 }'
            : '"' + colorStart + '"'

        let borderSize = showBorders ? 3 : 0

        let luaContent = 'return {\n' +
            '    active = ' + activeLua + ',\n' +
            '    inactive = "' + inactiveStr + '",\n' +
            '    size = ' + borderSize + '\n' +
            '}\n'

        let animCmd = animateGradient 
            ? " && hyprctl keyword animation 'borderangle, 1, 100, linear, loop'" 
            : " && hyprctl keyword animation 'borderangle, 0'"

        let cmd = "printf '%s' '" + luaContent.replace(/'/g, "'\\''") + "' > " + hyprThemePath + " && " +
                  "hyprctl keyword general:col.active_border '" + activeStr + "' && " +
                  "hyprctl keyword general:col.inactive_border '" + inactiveStr + "' && " +
                  "hyprctl keyword general:border_size " + borderSize + animCmd

        writer.command = ["fish", "-c", cmd]
        writer.running = true
    }

    // Wallpaper Scanner
    property var wallpapers: []
    property var tempPaths: []

    property Process wallpaperScanner: Process {
        id: scanner
        command: ["fish", "-c", "find ~/Pictures/Wallpapers -type f \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.webp' \\) 2>/dev/null"]
        
        stdout: SplitParser {
            onRead: data => {
                var trimmed = data.trim()
                if (trimmed.length > 0) root.tempPaths.push(trimmed)
            }
        }

        onExited: (code, status) => { root.wallpapers = root.tempPaths }
        Component.onCompleted: root.refreshWallpapers()
    }

    function refreshWallpapers() {
        if (!scanner.running) {
            tempPaths = []
            scanner.running = true
        }
    }

    // Persistence
    readonly property string settingsPath: Quickshell.shellDir.toString().replace(/^file:\/\//, "") + "/settings.json"
    property Process saveProcess: Process { id: saver }

    function saveSettings() {
        if (!isLoaded) return

        var customPalettes = themes.filter(function(t) { return t.isCustom === true })

        var data = {
            "selectedWallpaperMonitors": root.selectedWallpaperMonitors,
            "wallpaperTransitionType": root.wallpaperTransitionType,
            "showOsk": root.showOsk,
            "oskLayout": root.oskLayout,
            "showMascot": root.showMascot,
            "mascotPath": root.mascotPath,
            "mascotPhrases": root.mascotPhrases,
            "fetchOnlineQuotes": root.fetchOnlineQuotes,
            "quoteSource": root.quoteSource,
            "barPosition": root.barPosition,
            "showScreenFrame": root.showScreenFrame,
            "sysFont": root.sysFont,
            "fontScaleIndex": root.fontScaleIndex,
            "currentThemeIndex": root.currentThemeIndex,
            "locationQuery": root.locationQuery,
            "enabledBarScreens": root.enabledBarScreens,
            "useCustomColors": root.useCustomColors,
            "customBgBase": root.customBgBase.toString(),
            "customBgPanel": root.customBgPanel.toString(),
            "customAccent": root.customAccent.toString(),
            "showBorders": root.showBorders,
            "animateGradient": root.animateGradient,
            "customThemes": customPalettes,
            "windowStyle": root.windowStyle
        }

        var jsonStr = JSON.stringify(data)
        saver.command = ["fish", "-c", "echo '" + jsonStr.replace(/'/g, "'\\''") + "' > " + settingsPath]
        saver.running = true
    }

    property Process loaderProcess: Process {
        id: loader
        command: ["fish", "-c", "cat " + settingsPath + " 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data)
                    if (parsed.selectedWallpaperMonitors !== undefined && Array.isArray(parsed.selectedWallpaperMonitors)) root.selectedWallpaperMonitors = parsed.selectedWallpaperMonitors
                    if (parsed.wallpaperTransitionType !== undefined) root.wallpaperTransitionType = parsed.wallpaperTransitionType
                    if (parsed.showOsk !== undefined) root.showOsk = parsed.showOsk
                    if (parsed.oskLayout !== undefined) root.oskLayout = parsed.oskLayout
                    if (parsed.showMascot !== undefined) root.showMascot = parsed.showMascot
                    if (parsed.mascotPath !== undefined) root.mascotPath = parsed.mascotPath
                    if (parsed.mascotPhrases !== undefined && Array.isArray(parsed.mascotPhrases)) root.mascotPhrases = parsed.mascotPhrases
                    if (parsed.fetchOnlineQuotes !== undefined) root.fetchOnlineQuotes = parsed.fetchOnlineQuotes
                    if (parsed.quoteSource !== undefined) root.quoteSource = parsed.quoteSource
                    if (parsed.barPosition !== undefined) root.barPosition = parsed.barPosition
                    if (parsed.showScreenFrame !== undefined) root.showScreenFrame = parsed.showScreenFrame
                    if (parsed.sysFont !== undefined) root.sysFont = parsed.sysFont
                    if (parsed.fontScaleIndex !== undefined) root.fontScaleIndex = parsed.fontScaleIndex
                    if (parsed.locationQuery !== undefined) root.locationQuery = parsed.locationQuery
                    if (parsed.enabledBarScreens !== undefined && Array.isArray(parsed.enabledBarScreens)) root.enabledBarScreens = parsed.enabledBarScreens
                    if (parsed.useCustomColors !== undefined) root.useCustomColors = parsed.useCustomColors
                    if (parsed.customBgBase !== undefined) root.customBgBase = parsed.customBgBase
                    if (parsed.customBgPanel !== undefined) root.customBgPanel = parsed.customBgPanel
                    if (parsed.customAccent !== undefined) root.customAccent = parsed.customAccent
                    if (parsed.showBorders !== undefined) root.showBorders = parsed.showBorders
                    if (parsed.animateGradient !== undefined) root.animateGradient = parsed.animateGradient

                    if (parsed.customThemes && Array.isArray(parsed.customThemes)) {
                        var stockList = stockThemes.slice()
                        root.themes = stockList.concat(parsed.customThemes)
                    }

                    if (parsed.currentThemeIndex !== undefined) {
                        root.currentThemeIndex = Math.min(parsed.currentThemeIndex, root.themes.length - 1)
                    }

                    root.applyTheme(root.currentThemeIndex)
                } catch (e) {
                    console.error("Failed to parse settings JSON:", e)
                }
            }
        }
        
        onExited: {
            root.isLoaded = true
            root.syncHyprlandBorders()
            root.syncScreenFrame()
        }
        
        Component.onCompleted: loader.running = true
    }

    // Typography Engine
    function size(preset) { return preset[fontScaleIndex] }

    readonly property var fontMicro:   [10, 11, 12]
    readonly property var fontCaption: [11, 12, 13]
    readonly property var fontBody:    [12, 14, 15]
    readonly property var fontSubhead: [14, 16, 18]
    readonly property var fontTitle:   [19, 21, 23]
    readonly property var fontDisplay: [70, 82, 92]

    // Themes
    property color bgBase: "#13141c"
    property color bgPanel: "#1a1b26"
    property color accent: "#ff4da6"
    property color textMain: "#ffffff"
    property color textMuted: "#94a3b8"

    readonly property int barHeight: 46
    readonly property int barMargin: 12
    readonly property int cornerRadius: 16 

    readonly property var stockThemes: [
        { name: "Monochrome",     bgBase: "#121212", bgPanel: "#1e1e1e", accent: "#e0e0e0" },
        { name: "Classic Red",    bgBase: "#13141c", bgPanel: "#1a1b26", accent: "#ef4444" },
        { name: "Vibrant Orange", bgBase: "#13141c", bgPanel: "#1a1b26", accent: "#ff7b00" },
        { name: "Amber Yellow",   bgBase: "#13141c", bgPanel: "#1a1b26", accent: "#facc15" },
        { name: "Emerald Green",  bgBase: "#13141c", bgPanel: "#1a1b26", accent: "#10b981" },
        { name: "Cyber Cyan",     bgBase: "#13141c", bgPanel: "#1a1b26", accent: "#06b6d4" },
        { name: "Dodger Blue",    bgBase: "#13141c", bgPanel: "#1a1b26", accent: "#3b82f6" },
        { name: "Deep Purple",    bgBase: "#13141c", bgPanel: "#1a1b26", accent: "#a855f7" },
        { name: "Gruvbox Dark",   bgBase: "#282828", bgPanel: "#3c3836", accent: "#fe8019" },
        { name: "Catppuccin Mocha",bgBase: "#1e1e2e", bgPanel: "#181825", accent: "#f5c2e7" },
        { name: "Nord Slate",     bgBase: "#2e3440", bgPanel: "#3b4252", accent: "#88c0d0" },
        { name: "Tokyo Night",    bgBase: "#1a1b26", bgPanel: "#24283b", accent: "#7aa2f7" },
        { name: "Rosé Pine",      bgBase: "#191724", bgPanel: "#1f1d2e", accent: "#ebbcba" },
        { name: "Everforest",     bgBase: "#2d353b", bgPanel: "#343f44", accent: "#a7c080" },
        { name: "Solarized Dark", bgBase: "#002b36", bgPanel: "#073642", accent: "#268bd2" },
        { name: "Dracula",        bgBase: "#282a36", bgPanel: "#44475a", accent: "#ff79c6" },
        { name: "Neon Red",       bgBase: "#0d0202", bgPanel: "#1a0404", accent: "#ff0055" },
        { name: "Neon Orange",    bgBase: "#0f0800", bgPanel: "#1f1000", accent: "#ff5f00" },
        { name: "Neon Yellow",    bgBase: "#0f0f00", bgPanel: "#1f1f00", accent: "#ccff00" },
        { name: "Neon Lime",      bgBase: "#020f02", bgPanel: "#051f05", accent: "#00ff66" },
        { name: "Neon Cyan",      bgBase: "#000f0f", bgPanel: "#001f1f", accent: "#00f0ff" },
        { name: "Neon Blue",      bgBase: "#00050f", bgPanel: "#000a1f", accent: "#0066ff" },
        { name: "Neon Purple",    bgBase: "#0a000f", bgPanel: "#15001f", accent: "#bf00ff" },
        { name: "Neon Hot Pink",  bgBase: "#0f000a", bgPanel: "#1f0015", accent: "#ff00a0" }
    ]

    property var themes: stockThemes.slice()

    function addCustomTheme(themeObj) {
        var list = themes.slice()
        list.push(themeObj)
        themes = list
        setTheme(themes.length - 1)
    }

    function removeCustomTheme(index) {
        if (index < 0 || index >= themes.length) return
        if (!themes[index].isCustom) return

        var list = themes.slice()
        list.splice(index, 1)
        themes = list

        if (currentThemeIndex >= themes.length) {
            setTheme(Math.max(0, themes.length - 1))
        } else {
            setTheme(currentThemeIndex)
        }
    }

    function applyTheme(index) {
        if (useCustomColors) {
            bgBase = customBgBase
            bgPanel = customBgPanel
            accent = customAccent
            syncHyprlandBorders()
            return
        }

        var t = themes[index] || themes[0]
        bgBase = t.bgBase
        bgPanel = t.bgPanel
        accent = t.accent

        customBgBase = t.bgBase
        customBgPanel = t.bgPanel
        customAccent = t.accent

        syncHyprlandBorders()
    }

    function setTheme(index) {
        if (index < 0 || index >= themes.length) index = 0
        currentThemeIndex = index
        
        var t = themes[index]
        customBgBase = t.bgBase
        customBgPanel = t.bgPanel
        customAccent = t.accent

        applyTheme(index)
        saveSettings()
    }

    Component.onCompleted: {
        applyTheme(currentThemeIndex)
    }
}