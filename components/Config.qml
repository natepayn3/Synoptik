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

    // --- SYSTEM SOUNDS CONFIGURATION ---
    property bool playWindowSounds: true
    property bool playNotificationSounds: true
    property string windowSoundPath: "sound1.mp3"
    property string notificationSoundPath: "sound1.mp3"

    onPlayWindowSoundsChanged: { if (isLoaded) saveSettings() }
    onPlayNotificationSoundsChanged: { if (isLoaded) saveSettings() }
    onWindowSoundPathChanged: { if (isLoaded) saveSettings() }
    onNotificationSoundPathChanged: { if (isLoaded) saveSettings() }

    // --- ICON MAP & OVERRIDES ---
    property var iconOverrides: ({})

    readonly property var defaultIcons: ({
        "power": "electrical_services",
        "recorder": "videocam",
        "screenshot": "crop",
        "notifications": "inbox",
        "wallpaper": "wall_art",
        "settings": "build",
        "launcher": "terminal_2",
        "audio": "ear_sound",
        "sys": "neurology",
        "batt": "battery_android_frame_full",
        "cc": "widgets",
        "network": "lan",
        "clipboard": "content_paste",
        "overview": "select_window_2",
        "magic": "kid_star",
        "magic_active": "family_star",
        "music": "music_note",
        "music_active": "genres",
        "private": "lock",
        "private_active": "lock_open"
    })

    function getIcon(iconId) {
        if (iconOverrides && iconOverrides[iconId]) {
            return iconOverrides[iconId]
        }
        return defaultIcons[iconId] || "help_outline"
    }

    function setIconOverride(iconId, glyphName) {
        let current = Object.assign({}, iconOverrides)
        current[iconId] = glyphName
        iconOverrides = current
        saveSettings()
    }

    function resetIcons() {
        iconOverrides = {}
        saveSettings()
    }

    // --- ICON GROUPS COLLAPSE & PINNING STATE ---
    property bool leftCardCollapsed: false
    property bool rightCardCollapsed: false
    property var pinnedIcons: ({})

    function togglePin(iconId) {
        let temp = Object.assign({}, pinnedIcons)
        temp[iconId] = !temp[iconId]
        pinnedIcons = temp
        saveSettings()
    }

    function isPinned(iconId) {
        return !!pinnedIcons[iconId]
    }

    onLeftCardCollapsedChanged: { if (isLoaded) saveSettings() }
    onRightCardCollapsedChanged: { if (isLoaded) saveSettings() }

    // --- UNIFIED SURFACE GEOMETRY ---
    property real surfaceRadius: 18.0
    property int borderThickness: 3
    property real cardMargin: 12.0

    readonly property bool showBorders: borderThickness > 0

    onSurfaceRadiusChanged: { 
        if (isLoaded) {
            syncHyprlandBorders()
            saveSettings()
        }
    }

    onBorderThicknessChanged: {
        if (isLoaded) {
            syncHyprlandBorders()
            saveSettings()
        }
    }
    onCardMarginChanged: { if (isLoaded) saveSettings() }

    readonly property real cornerRadius: surfaceRadius
    readonly property real surfaceWingSize: surfaceRadius

    // --- DESKTOP CLOCK STATE & PERSISTENCE ---
    property bool showDesktopClock: true
    property string clockStyle: "digital"
    property real clockScale: 1.0
    property bool clockShowSeconds: false
    property bool clockUse12Hour: true
    property bool clockShowAmPm: true
    property bool clockShowBorder: true
    property bool clockShowBackground: true

    property var clockPositions: ({})
    property var clockScales: ({})
    property var enabledClockScreens: []

    function getClockPosition(screenName, defaultX, defaultY) {
        if (clockPositions && clockPositions[screenName]) {
            return clockPositions[screenName]
        }
        return { x: defaultX, y: defaultY }
    }

    function saveClockPosition(screenName, x, y) {
        let current = Object.assign({}, clockPositions)
        current[screenName] = { x: x, y: y }
        clockPositions = current
        saveSettings()
    }

    function getClockScale(screenName) {
        if (clockScales && clockScales[screenName] !== undefined) {
            return clockScales[screenName]
        }
        return 1.0
    }

    function saveClockScale(screenName, scale) {
        let current = Object.assign({}, clockScales)
        current[screenName] = scale
        clockScales = current
        saveSettings()
    }

    function isClockEnabledForScreen(screenName) {
        if (!enabledClockScreens || enabledClockScreens.length === 0) return true
        return enabledClockScreens.includes(screenName)
    }

    function toggleClockScreen(screenName) {
        let current = (enabledClockScreens || []).slice()
        let idx = current.indexOf(screenName)
        if (idx !== -1) {
            current.splice(idx, 1)
        } else {
            current.push(screenName)
        }
        enabledClockScreens = current
        saveSettings()
    }

    // --- WALLPAPER CONFIG STATE & PERSISTENCE ---
    property var selectedWallpaperMonitors: []
    property string wallpaperTransitionType: "wipe"
    property string activeWallpaperPath: ""

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
        zipcode: root.locationQuery
    }

    property Timer weatherTimer: Timer {
        interval: 900000
        running: root.isLoaded
        repeat: true
        onTriggered: root.weather.fetchWeather(true)
    }

    onSelectedWallpaperMonitorsChanged: { if (isLoaded) saveSettings() }
    onWallpaperTransitionTypeChanged: { if (isLoaded) saveSettings() }

    onShowDesktopClockChanged: { if (isLoaded) saveSettings() }
    onClockStyleChanged: { if (isLoaded) saveSettings() }
    onClockScaleChanged: { if (isLoaded) saveSettings() }
    onClockShowSecondsChanged: { if (isLoaded) saveSettings() }
    onClockUse12HourChanged: { if (isLoaded) saveSettings() }
    onClockShowAmPmChanged: { if (isLoaded) saveSettings() }
    onClockShowBorderChanged: { if (isLoaded) saveSettings() }
    onClockShowBackgroundChanged: { if (isLoaded) saveSettings() }

    // --- ON-SCREEN KEYBOARD (OSK) STATE & PERSISTENCE ---
    property bool showOsk: false
    property string oskLayout: "Normal"

    property string barFrameStyle: "floating"
    property bool animateGradient: true
    property bool showScreenFrame: false
    property real shellOpacity: 1.0
    property bool enableBlur: true
    property bool enableXray: true
    property bool enableIris: false

    // Process to run Iris, redirect stderr, and parse JSON colors reliably
    property Process irisRunner: Process {
        id: runner
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let text = this.text ? this.text.trim() : ""
                    if (text.length > 0) {
                        let match = text.match(/\{[\s\S]*\}/)
                        if (match) {
                            let jsonStr = match[0]

                            if (jsonStr.includes('"bg"') || jsonStr.includes('"surface"') || jsonStr.includes('"accent"')) {
                                let parsed = JSON.parse(jsonStr)

                                let baseCol = parsed.bg || "#13141c"
                                let panelCol = parsed.surface || "#1a1b26"
                                let accentCol = parsed.accent || "#ff4da6"

                                root.customBgBase = baseCol
                                root.customBgPanel = panelCol
                                root.customAccent = accentCol

                                root.bgBase = Qt.rgba(Qt.color(baseCol).r, Qt.color(baseCol).g, Qt.color(baseCol).b, root.shellOpacity)
                                root.bgPanel = Qt.rgba(Qt.color(panelCol).r, Qt.color(panelCol).g, Qt.color(panelCol).b, root.shellOpacity)
                                root.accent = accentCol

                                root.syncHyprlandBorders()
                            }
                        }
                    }
                } catch (e) {
                    console.error("Failed to parse Iris JSON colors:", e)
                }
            }
        }
    }

    onEnableIrisChanged: {
        if (!isLoaded) return
        if (enableIris) {
            applyIrisColors()
        } else {
            applyTheme(currentThemeIndex)
        }
        saveSettings()
    }

    onActiveWallpaperPathChanged: {
        if (isLoaded && enableIris && activeWallpaperPath !== "") {
            applyIrisColors(activeWallpaperPath)
        }
    }

    function applyIrisColors(filePath) {
        if (!enableIris) return

        let path = filePath || root.activeWallpaperPath

        if (!path && root.wallpapers && root.wallpapers.length > 0) {
            path = root.wallpapers[0]
        }

        if (!path) {
            let cmd = "set W (find ~/Pictures/Wallpapers -type f \\( -name '*.jpg' -o -name '*.png' -o -name '*.webp' \\) 2>/dev/null | head -n 1); if test -n \"$W\"; iris --json-only \"$W\" 2>/dev/null; end"
            runner.command = ["fish", "-c", cmd]
        } else {
            let cmd = "iris --json-only '" + path + "' 2>/dev/null"
            runner.command = ["fish", "-c", cmd]
        }

        // Inline Comment: Reset running state to false first so Quickshell re-executes the process
        runner.running = false
        runner.running = true
    }

    readonly property bool isFloatingBar: barFrameStyle === "floating"

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

    onBarFrameStyleChanged: { 
        if (isLoaded) {
            syncHyprlandBorders()
            saveSettings()
        }
    }

    onShowScreenFrameChanged: {
        if (!isLoaded) return
        syncScreenFrame()
        saveSettings()
    }

    onShellOpacityChanged: {
        if (!isLoaded) return
        if (enableIris) {
            applyIrisColors()
        } else {
            applyTheme(currentThemeIndex)
        }
        saveSettings()
    }

    onEnableBlurChanged: {
        if (!isLoaded) return
        syncHyprlandBorders()
        saveSettings()
    }

    onEnableXrayChanged: {
        if (!isLoaded) return
        syncHyprlandBorders()
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
    onLocationQueryChanged: {
        if (root.weather) {
            root.weather.zipcode = root.locationQuery;
            if (root.isLoaded) {
                root.weather.fetchWeather(true);
                root.saveSettings();
            }
        }
    }

    onAnimateGradientChanged: {
        if (!isLoaded) return
        syncHyprlandBorders()
        saveSettings()
    }

    onCustomBgBaseChanged: {
        if (!isLoaded) return
        if (useCustomColors && !enableIris) applyTheme(currentThemeIndex)
        saveSettings()
    }

    onCustomBgPanelChanged: {
        if (!isLoaded) return
        if (useCustomColors && !enableIris) applyTheme(currentThemeIndex)
        saveSettings()
    }

    onCustomAccentChanged: {
        if (!isLoaded) return
        if (useCustomColors && !enableIris) {
            accent = customAccent
            syncHyprlandBorders()
        }
        saveSettings()
    }

    onUseCustomColorsChanged: {
        if (!isLoaded) return
        if (!enableIris) applyTheme(currentThemeIndex)
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

    // --- MONITOR DETECTOR PROCESS ---
    property var detectedModes: ({})

    property Process monitorDetector: Process {
        id: monDetector
        command: ["fish", "-c", "hyprctl monitors -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text)
                    let modesMap = {}
                    data.forEach(m => {
                        if (m.availableModes) {
                            modesMap[m.name] = m.availableModes.map(modeStr => {
                                let parts = modeStr.split("@")
                                let res = parts[0].split("x")
                                let rateStr = parts[1] ? parts[1].replace("Hz", "") : "60.00"
                                return {
                                    text: modeStr,
                                    w: parseInt(res[0]),
                                    h: parseInt(res[1]),
                                    r: parseFloat(rateStr)
                                }
                            })
                        }
                    })
                    root.detectedModes = modesMap
                } catch (e) {
                    console.error("Failed to parse hyprctl monitors output:", e)
                }
            }
        }
        Component.onCompleted: monDetector.running = true
    }

    // --- HYPRLAND SCALE VALIDATION HELPERS ---
    function isScaleValid(width, height, scale) {
        if (scale === "auto" || !scale) return true
        
        let logicalW = width / scale
        let logicalH = height / scale
        
        let isWInt = Math.abs(logicalW - Math.round(logicalW)) < 0.001
        let isHInt = Math.abs(logicalH - Math.round(logicalH)) < 0.001
        
        return isWInt && isHInt
    }

    function getNearestValidScale(width, height, desiredScale) {
        if (desiredScale === "auto" || !desiredScale) return "auto"
        if (isScaleValid(width, height, desiredScale)) return desiredScale
        
        let bestScale = 1.0
        let minDiff = Number.MAX_VALUE
        
        for (let s = 0.5; s <= 3.0; s = Math.round((s + 0.05) * 100) / 100) {
            if (isScaleValid(width, height, s)) {
                let diff = Math.abs(s - desiredScale)
                if (diff < minDiff) {
                    minDiff = diff
                    bestScale = s
                }
            }
        }
        return bestScale
    }

    // --- MONITOR LAYOUT & DRAFT STATE MANAGEMENT ---
    property string selectedScreenConfig: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "DP-1"
    property var monitorConfigs: ({})
    property var draftMonitorConfigs: ({})

    function getMonitorConfig(screenName) {
        const safeFallback = { width: 1920, height: 1080, refreshRate: 60.0, x: 0, y: 0, scale: "auto", transform: 0 }

        if (!screenName) return safeFallback
        
        if (draftMonitorConfigs && draftMonitorConfigs[screenName]) {
            return draftMonitorConfigs[screenName]
        }
        if (monitorConfigs && monitorConfigs[screenName]) {
            return monitorConfigs[screenName]
        }

        return safeFallback
    }

    function normalizeMonitorPositions() {
        let keys = Object.keys(monitorConfigs)
        if (keys.length === 0) return

        let minX = Number.MAX_VALUE
        keys.forEach(k => {
            let cfg = monitorConfigs[k]
            if (cfg && cfg.x < minX) minX = cfg.x
        })

        if (minX !== Number.MAX_VALUE && minX !== 0) {
            let updated = Object.assign({}, monitorConfigs)
            keys.forEach(k => {
                updated[k].x = updated[k].x - minX
            })
            monitorConfigs = updated
        }
    }

    function getOtherMonitorConfig(currentScreenName) {
        let screens = Quickshell.screens
        let otherScreen = screens.find(s => s.name !== currentScreenName)
        if (otherScreen) {
            return getMonitorConfig(otherScreen.name)
        }
        return { width: 1920, height: 1080, refreshRate: 60.0, x: 0, y: 0, scale: "auto", transform: 0 }
    }

    function updateDraftMonitorConfig(screenName, newOpts) {
        if (!screenName) return
        let current = Object.assign({}, draftMonitorConfigs)
        let existing = getMonitorConfig(screenName)
        let updated = Object.assign({}, existing, newOpts)

        if (updated.scale && updated.scale !== "auto") {
            updated.scale = getNearestValidScale(updated.width, updated.height, updated.scale)
        }

        current[screenName] = updated
        draftMonitorConfigs = current
    }

    function applyMonitorConfigs() {
        let current = Object.assign({}, monitorConfigs)
        Object.keys(draftMonitorConfigs).forEach(k => {
            current[k] = draftMonitorConfigs[k]
        })
        monitorConfigs = current

        normalizeMonitorPositions()
        saveSettings()
        syncHyprlandBorders()
    }

    function resetDraftMonitorConfigs() {
        draftMonitorConfigs = Object.assign({}, monitorConfigs)
    }

    // Hyprland Exporter
    property Process themeWriter: Process { id: writer }
    readonly property string hyprThemePath: Quickshell.env("HOME") + "/.config/hypr/hypr_style.lua"

    function syncHyprlandBorders() {
        if (!isLoaded) return

        function toOpaqueHex(c) {
            let str = Qt.color(c).toString().replace("#", "")
            return str.length === 8 ? str.substring(2) : str
        }

        let hexAccent = toOpaqueHex(root.accent)
        let hexEnd = toOpaqueHex(root.borderEnd)
        let hexInactive = toOpaqueHex(root.bgPanel)

        let colorStart = "rgba(" + hexAccent + "ff)"
        let colorEnd = "rgba(" + hexEnd + "ff)"
        let inactiveStr = "rgba(" + hexInactive + "aa)"

        let activeStr = animateGradient 
            ? colorStart + " " + colorEnd + " 45deg"
            : colorStart

        let activeLua = animateGradient
            ? '{ colors = { "' + colorStart + '", "' + colorEnd + '" }, angle = 45 }'
            : '"' + colorStart + '"'

        let borderSize = root.borderThickness

        let gapsOut = (barFrameStyle === "screen") ? 30 : 20
        let roundingVal = Math.round(surfaceRadius)

        let monitorLuaBlocks = []
        let hyprctlMonitorCmds = []

        let keys = Object.keys(monitorConfigs)
        if (keys.length === 0 && Quickshell.screens) {
            Quickshell.screens.forEach(s => keys.push(s.name))
        }

        keys.forEach(k => {
            let m = getMonitorConfig(k)
            
            let safeScale = (m.scale === "auto" || !m.scale) ? "auto" : getNearestValidScale(m.width, m.height, m.scale)
            let scaleVal = (safeScale === "auto") ? "auto" : parseFloat(safeScale).toFixed(2)
            
            let luaBlock = 'hl.monitor({\n' +
                '    output = "' + k + '",\n' +
                '    mode = "' + m.width + 'x' + m.height + '@' + (m.refreshRate || 60.0) + '",\n' +
                '    position = "' + m.x + 'x' + m.y + '",\n' +
                '    scale = ' + (scaleVal === "auto" ? '"auto"' : scaleVal) +
                (m.transform !== undefined && m.transform !== 0 ? ',\n    transform = ' + m.transform : '') + '\n' +
                '})'
            
            monitorLuaBlocks.push(luaBlock)

            let transformStr = m.transform !== undefined ? ',transform,' + m.transform : ''
            let ruleStr = k + ',' + m.width + 'x' + m.height + '@' + (m.refreshRate || 60.0) + ',' + m.x + 'x' + m.y + ',' + scaleVal + transformStr
            hyprctlMonitorCmds.push("hyprctl keyword monitor '" + ruleStr + "'")
        })

        let luaContent = 'hl.config({\n' +
            '    general = {\n' +
            '        gaps_out = ' + gapsOut + ',\n' +
            '        border_size = ' + borderSize + ',\n' +
            '        col = {\n' +
            '            active_border = ' + activeLua + ',\n' +
            '            inactive_border = "' + inactiveStr + '"\n' +
            '        }\n' +
            '    },\n' +
            '    decoration = {\n' +
            '        rounding = ' + roundingVal + '\n' +
            '    }\n' +
            '})\n\n' +
            'hl.layer_rule({\n' +
            '    name = "synoptik-shell",\n' +
            '    match = { namespace = "^synoptik-shell.*" },\n' +
            '    blur = ' + (enableBlur ? "true" : "false") + ',\n' +
            '    xray = ' + (enableXray ? "true" : "false") + ',\n' +
            '    ignore_alpha = 0.6\n' +
            '})\n\n' +
            monitorLuaBlocks.join('\n\n') + '\n'

        let animCmd = animateGradient 
            ? " && hyprctl keyword animation 'borderangle, 1, 100, linear, loop'" 
            : " && hyprctl keyword animation 'borderangle, 0'"

        let monExecCmd = hyprctlMonitorCmds.length > 0 ? " && " + hyprctlMonitorCmds.join(" && ") : ""

        let cmd = "printf '%s' '" + luaContent.replace(/'/g, "'\\''") + "' > " + hyprThemePath + " && " +
                "hyprctl keyword general:gaps_out " + gapsOut + " && " +
                "hyprctl keyword decoration:rounding " + roundingVal + " && " +
                "hyprctl keyword general:col.active_border '" + activeStr + "' && " +
                "hyprctl keyword general:inactive_border '" + inactiveStr + "' && " +
                "hyprctl keyword general:border_size " + borderSize + animCmd + monExecCmd

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

    property Timer saveTimer: Timer {
        interval: 400
        repeat: false
        onTriggered: {
            if (saver.running) {
                saveTimer.restart()
                return
            }

            var customPalettes = themes.filter(function(t) { return t.isCustom === true })

            var data = {
                "monitorConfigs": root.monitorConfigs,
                "selectedWallpaperMonitors": root.selectedWallpaperMonitors,
                "wallpaperTransitionType": root.wallpaperTransitionType,
                "activeWallpaperPath": root.activeWallpaperPath,
                "showOsk": root.showOsk,
                "oskLayout": root.oskLayout,
                "showMascot": root.showMascot,
                "mascotPath": root.mascotPath,
                "mascotPhrases": root.mascotPhrases,
                "fetchOnlineQuotes": root.fetchOnlineQuotes,
                "quoteSource": root.quoteSource,
                "barFrameStyle": root.barFrameStyle,
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
                "animateGradient": root.animateGradient,
                "shellOpacity": root.shellOpacity,
                "enableBlur": root.enableBlur,
                "enableXray": root.enableXray,
                "enableIris": root.enableIris,
                "customThemes": customPalettes,
                "windowStyle": root.windowStyle,
                "playWindowSounds": root.playWindowSounds,
                "playNotificationSounds": root.playNotificationSounds,
                "windowSoundPath": root.windowSoundPath,
                "notificationSoundPath": root.notificationSoundPath,

                "leftCardCollapsed": root.leftCardCollapsed,
                "rightCardCollapsed": root.rightCardCollapsed,
                "pinnedIcons": root.pinnedIcons,
                "iconOverrides": root.iconOverrides,

                "surfaceRadius": root.surfaceRadius,
                "borderThickness": root.borderThickness,
                "cardMargin": root.cardMargin,

                "showDesktopClock": root.showDesktopClock,
                "clockStyle": root.clockStyle,
                "clockScale": root.clockScale,
                "clockShowSeconds": root.clockShowSeconds,
                "clockUse12Hour": root.clockUse12Hour,
                "clockShowAmPm": root.clockShowAmPm,
                "clockShowBorder": root.clockShowBorder,
                "clockShowBackground": root.clockShowBackground,
                "clockPositions": root.clockPositions,
                "clockScales": root.clockScales,
                "enabledClockScreens": root.enabledClockScreens
            }

            var jsonStr = JSON.stringify(data)
            saver.command = ["fish", "-c", "printf '%s' '" + jsonStr.replace(/'/g, "'\\''") + "' > " + settingsPath]
            saver.running = true
        }
    }

    function saveSettings() {
        if (!isLoaded) return
        saveTimer.restart()
    }

    property Process loaderProcess: Process {
        id: loader
        command: ["fish", "-c", "cat " + settingsPath + " 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text ? this.text.trim() : ""
                if (text !== "") {
                    try {
                        var parsed = JSON.parse(text)

                        let props = [
                            "monitorConfigs", "selectedWallpaperMonitors", "wallpaperTransitionType", "activeWallpaperPath", "showOsk", "oskLayout",
                            "showMascot", "mascotPath", "mascotPhrases", "fetchOnlineQuotes", "quoteSource",
                            "barFrameStyle", "barPosition", "showScreenFrame", "sysFont", "fontScaleIndex", "locationQuery",
                            "enabledBarScreens", "useCustomColors", "customBgBase", "customBgPanel",
                            "customAccent", "animateGradient", "shellOpacity", "enableBlur",
                            "enableXray", "enableIris", "surfaceRadius", "borderThickness", "cardMargin", "showDesktopClock", "clockStyle", "clockScale", 
                            "clockShowSeconds", "clockUse12Hour", "clockShowAmPm", "clockShowBorder", 
                            "clockShowBackground", "clockPositions", "clockScales", "enabledClockScreens",
                            "leftCardCollapsed", "rightCardCollapsed", "pinnedIcons", "iconOverrides",
                            "playWindowSounds", "playNotificationSounds", "windowSoundPath", "notificationSoundPath"
                        ]

                        props.forEach(p => {
                            if (parsed[p] !== undefined) root[p] = parsed[p]
                        })

                        if (parsed.isFloatingBar !== undefined && parsed.barFrameStyle === undefined) {
                            root.barFrameStyle = parsed.isFloatingBar ? "floating" : "edge"
                        }

                        if (parsed.customThemes && Array.isArray(parsed.customThemes)) {
                            var stockList = stockThemes.slice()
                            root.themes = stockList.concat(parsed.customThemes)
                        }

                        if (parsed.currentThemeIndex !== undefined) {
                            root.currentThemeIndex = Math.min(parsed.currentThemeIndex, root.themes.length - 1)
                        }

                        if (root.enableIris) {
                            root.applyIrisColors()
                        } else {
                            root.applyTheme(root.currentThemeIndex)
                        }
                    } catch (e) {
                        console.error("Failed to parse settings JSON:", e)
                    }
                }

                root.normalizeMonitorPositions()
                root.isLoaded = true
                root.resetDraftMonitorConfigs()
                root.syncHyprlandBorders()
                root.syncScreenFrame()
                
                if (root.weather) {
                    root.weather.fetchWeather(true)
                }
            }
        }
        
        Component.onCompleted: loader.running = true
    }

    // Typography Engine
    function size(preset) { return preset[fontScaleIndex] }

    readonly property var fontMicro:   [8, 11, 14]
    readonly property var fontCaption: [9, 12, 15]
    readonly property var fontBody:    [11, 14, 17]
    readonly property var fontSubhead: [12, 16, 20]
    readonly property var fontTitle:   [16, 21, 26]
    readonly property var fontDisplay: [58, 82, 106]

    // Themes
    property color bgBase: "#13141c"
    property color bgPanel: "#1a1b26"
    property color accent: "#ff4da6"
    property color textMain: "#ffffff"
    property color textMuted: "#94a3b8"

    readonly property int barHeight: 54
    readonly property int barMargin: 12

    readonly property var stockThemes: [
        { name: "Monochrome",       bgBase: "#121212", bgPanel: "#1e1e1e", accent: "#e0e0e0" },
        { name: "Classic Red",      bgBase: "#13141c", bgPanel: "#1a1b26", accent: "#ef4444" },
        { name: "Vibrant Orange",   bgBase: "#13141c", bgPanel: "#1a1b26", accent: "#ff7b00" },
        { name: "Amber Yellow",     bgBase: "#13141c", bgPanel: "#1a1b26", accent: "#facc15" },
        { name: "Emerald Green",    bgBase: "#13141c", bgPanel: "#1a1b26", accent: "#10b981" },
        { name: "Cyber Cyan",       bgBase: "#13141c", bgPanel: "#1a1b26", accent: "#06b6d4" },
        { name: "Dodger Blue",      bgBase: "#13141c", bgPanel: "#1a1b26", accent: "#3b82f6" },
        { name: "Deep Purple",      bgBase: "#13141c", bgPanel: "#1a1b26", accent: "#a855f7" },
        { name: "Gruvbox Dark",     bgBase: "#282828", bgPanel: "#3c3836", accent: "#fe8019" },
        { name: "Catppuccin Mocha", bgBase: "#1e1e2e", bgPanel: "#181825", accent: "#f5c2e7" },
        { name: "Nord Slate",       bgBase: "#2e3440", bgPanel: "#3b4252", accent: "#88c0d0" },
        { name: "Tokyo Night",      bgBase: "#1a1b26", bgPanel: "#24283b", accent: "#7aa2f7" },
        { name: "Rosé Pine",        bgBase: "#191724", bgPanel: "#1f1d2e", accent: "#ebbcba" },
        { name: "Everforest",       bgBase: "#2d353b", bgPanel: "#343f44", accent: "#a7c080" },
        { name: "Solarized Dark",   bgBase: "#002b36", bgPanel: "#073642", accent: "#268bd2" },
        { name: "Dracula",          bgBase: "#282a36", bgPanel: "#44475a", accent: "#ff79c6" },
        { name: "Cyberpunk 2077",   bgBase: "#000b1e", bgPanel: "#12002b", accent: "#ff0055" },
        { name: "Catppuccin Latte", bgBase: "#eff1f5", bgPanel: "#e6e9ef", accent: "#8839ef" },
        { name: "Monokai Pro",      bgBase: "#2d2a2e", bgPanel: "#403e41", accent: "#ffd866" },
        { name: "Synthwave '84",    bgBase: "#262335", bgPanel: "#241b2f", accent: "#ff7edb" },
        { name: "Kanagawa",         bgBase: "#1f1f28", bgPanel: "#2a2a37", accent: "#7e9cd8" },
        { name: "Ayu Dark",         bgBase: "#0f1419", bgPanel: "#131721", accent: "#ffb454" },
        { name: "Solarized Light",  bgBase: "#fdf6e3", bgPanel: "#eee8d5", accent: "#b58900" },
        { name: "One Dark",         bgBase: "#282c34", bgPanel: "#21252b", accent: "#61afef" },
        { name: "Neon Red",         bgBase: "#0d0202", bgPanel: "#1a0404", accent: "#ff0055" },
        { name: "Neon Orange",      bgBase: "#0f0800", bgPanel: "#1f1000", accent: "#ff5f00" },
        { name: "Neon Yellow",      bgBase: "#0f0f00", bgPanel: "#1f1f00", accent: "#ccff00" },
        { name: "Neon Lime",        bgBase: "#020f02", bgPanel: "#051f05", accent: "#00ff66" },
        { name: "Neon Cyan",        bgBase: "#000f0f", bgPanel: "#001f1f", accent: "#00f0ff" },
        { name: "Neon Blue",        bgBase: "#00050f", bgPanel: "#000a1f", accent: "#0066ff" },
        { name: "Neon Purple",      bgBase: "#0a000f", bgPanel: "#15001f", accent: "#bf00ff" },
        { name: "Neon Hot Pink",    bgBase: "#0f000a", bgPanel: "#1f0015", accent: "#ff00a0" },
        { name: "Laserwave",        bgBase: "#1b192e", bgPanel: "#272140", accent: "#40e0d0" },
        { name: "Matrix Deep",      bgBase: "#020a02", bgPanel: "#051405", accent: "#00ff41" },
        { name: "Outrun Sunset",    bgBase: "#11001c", bgPanel: "#220038", accent: "#ff2a6d" },
        { name: "Vaporwave Pink",   bgBase: "#1a001a", bgPanel: "#2e002e", accent: "#ff71ce" },
        { name: "Midnight City",    bgBase: "#090a10", bgPanel: "#121420", accent: "#00d2ff" },
        { name: "Toxic Emerald",    bgBase: "#01120a", bgPanel: "#022414", accent: "#00ff87" },
        { name: "Inferno Glow",     bgBase: "#140200", bgPanel: "#260500", accent: "#ff3300" },
        { name: "Ultra Violet",     bgBase: "#0d0614", bgPanel: "#180b26", accent: "#9900ff" }
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
        if (enableIris) return

        var baseColor = useCustomColors ? customBgBase : (themes[index] || themes[0]).bgBase
        var panelColor = useCustomColors ? customBgPanel : (themes[index] || themes[0]).bgPanel
        var accentColor = useCustomColors ? customAccent : (themes[index] || themes[0]).bgPanel ? (themes[index] || themes[0]).accent : "#ff4da6"

        bgBase = Qt.rgba(Qt.color(baseColor).r, Qt.color(baseColor).g, Qt.color(baseColor).b, shellOpacity)
        bgPanel = Qt.rgba(Qt.color(panelColor).r, Qt.color(panelColor).g, Qt.color(panelColor).b, shellOpacity)
        accent = accentColor

        if (!useCustomColors) {
            var t = themes[index] || themes[0]
            customBgBase = t.bgBase
            customBgPanel = t.bgPanel
            customAccent = t.accent
        }

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
        if (!enableIris) applyTheme(currentThemeIndex)
    }
}