import QtQuick

QtObject {
    id: appearanceRoot

    property var configRef: null

    // --- BAR / FRAME / RENDERING TOGGLES ---
    property string barFrameStyle: "floating"
    property bool animateGradient: true
    property bool showScreenFrame: false
    property real shellOpacity: 1.0
    property bool enableBlur: true
    property bool enableXray: true
    property bool enableIris: false
    property bool showWatermarks: true
    property bool bounceWatermarks: true

    onShowWatermarksChanged: { if (configRef) configRef.saveSettings() }
    onBounceWatermarksChanged: { if (configRef) configRef.saveSettings() }

    onEnableIrisChanged: {
        if (!configRef || !configRef.isLoaded) return
        if (enableIris) {
            applyIrisColors()
        } else {
            applyTheme(currentThemeIndex)
        }
        configRef.saveSettings()
    }

    function applyIrisColors(filePath) {
        configRef.irisService.applyIrisColors(filePath)
    }

    property bool enableHoverPeek: true
    onEnableHoverPeekChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    // Desktop widgets (Mascot, Clock, Cava, SysInfo) round their position to
    // a visible grid while dragging by default (a real, visibly discrete
    // snap). Turning this off drops the rounding and eases position changes
    // through MotionService's spatial curve instead, trailing smoothly to
    // the exact cursor position rather than jumping in grid steps.
    property bool snapDesktopWidgets: true
    onSnapDesktopWidgetsChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    property bool nightModeEnabled: false
    onNightModeEnabledChanged: { if (configRef && configRef.isLoaded) configRef.updateShader() }

    // --- NIGHT MODE SCHEDULE ---
    property bool nightModeAuto: false
    property int nightModeScheduleStart: 21 // 9 PM, 24h clock
    property int nightModeScheduleEnd: 6    // 6 AM, 24h clock

    onNightModeAutoChanged: {
        if (configRef && configRef.isLoaded) configRef.saveSettings()
        evaluateNightSchedule()
    }
    onNightModeScheduleStartChanged: {
        if (configRef && configRef.isLoaded) configRef.saveSettings()
        evaluateNightSchedule()
    }
    onNightModeScheduleEndChanged: {
        if (configRef && configRef.isLoaded) configRef.saveSettings()
        evaluateNightSchedule()
    }

    // Sets nightModeEnabled to match the schedule when Auto is on. Handles
    // windows that wrap past midnight (e.g. 21 -> 6) as well as ones that
    // don't (e.g. 8 -> 18).
    function evaluateNightSchedule() {
        if (!nightModeAuto) return
        let h = new Date().getHours()
        let start = nightModeScheduleStart
        let end = nightModeScheduleEnd
        let shouldBeOn = start === end ? false : (start < end ? (h >= start && h < end) : (h >= start || h < end))
        if (nightModeEnabled !== shouldBeOn) nightModeEnabled = shouldBeOn
    }

    property Timer nightScheduleTimer: Timer {
        interval: 60000
        running: appearanceRoot.nightModeAuto
        repeat: true
        triggeredOnStart: true
        onTriggered: appearanceRoot.evaluateNightSchedule()
    }

    readonly property bool isFloatingBar: barFrameStyle === "floating"

    // --- BAR POSITION CONTROL ---
    property string barPosition: "top"
    property bool autoHideBar: false

    onAutoHideBarChanged: {
        if (configRef && configRef.isLoaded) {
            configRef.syncHyprlandBorders()
            configRef.saveSettings()
        }
    }

    function syncScreenFrame() {
        if (configRef && configRef.isLoaded) {
            configRef.syncHyprlandBorders()
        }
    }

    onBarFrameStyleChanged: {
        if (configRef && configRef.isLoaded) {
            configRef.syncHyprlandBorders()
            configRef.saveSettings()
        }
    }

    onShowScreenFrameChanged: {
        if (!configRef || !configRef.isLoaded) return
        syncScreenFrame()
        configRef.saveSettings()
    }

    onShellOpacityChanged: {
        if (!configRef || !configRef.isLoaded) return
        if (enableIris) {
            applyIrisColors()
        } else {
            applyTheme(currentThemeIndex)
        }
        configRef.saveSettings()
    }

    onEnableBlurChanged: {
        if (!configRef || !configRef.isLoaded) return
        configRef.syncHyprlandBorders()
        configRef.saveSettings()
    }

    onEnableXrayChanged: {
        if (!configRef || !configRef.isLoaded) return
        configRef.syncHyprlandBorders()
        configRef.saveSettings()
    }

    // --- TYPOGRAPHY ---
    property string sysFont: ""
    property bool nativeFontRendering: true
    readonly property int textRenderType: nativeFontRendering ? Text.NativeRendering : Text.QtRendering
    property bool fontDropdownOpen: false
    property string fontSearchFilter: ""
    property int fontScaleIndex: 1

    onNativeFontRenderingChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    function fontStyle(fontObj) {
        if (!fontObj) return fontObj
        fontObj.hintingPreference = Font.PreferFullHinting
        fontObj.styleName = "Regular"
        return fontObj
    }

    property int currentThemeIndex: 0

    // Custom Colors
    property bool useCustomColors: false
    property string customBgBase: "#12131a"
    property string customBgPanel: "#1e202b"
    property string customAccent: "#94a3b8"

    property color borderStart: accent
    property color borderEnd: Qt.lighter(accent, 1.5)

    property string windowStyle: "rounded"

    onWindowStyleChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onBarPositionChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysFontChanged: { if (configRef && configRef.isLoaded && sysFont !== "") configRef.saveSettings() }
    onFontScaleIndexChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    onAnimateGradientChanged: {
        if (!configRef || !configRef.isLoaded) return
        configRef.syncHyprlandBorders()
        configRef.saveSettings()
    }

    onCustomBgBaseChanged: {
        if (!configRef || !configRef.isLoaded) return
        if (useCustomColors && !enableIris) applyTheme(currentThemeIndex)
        configRef.saveSettings()
    }

    onCustomBgPanelChanged: {
        if (!configRef || !configRef.isLoaded) return
        if (useCustomColors && !enableIris) applyTheme(currentThemeIndex)
        configRef.saveSettings()
    }

    onCustomAccentChanged: {
        if (!configRef || !configRef.isLoaded) return
        if (useCustomColors && !enableIris) {
            accent = customAccent
            configRef.syncHyprlandBorders()
        }
        configRef.saveSettings()
    }

    onUseCustomColorsChanged: {
        if (!configRef || !configRef.isLoaded) return
        if (!enableIris) applyTheme(currentThemeIndex)
        configRef.saveSettings()
    }

    // --- TYPOGRAPHY ENGINE ---
    function size(preset) { return preset[fontScaleIndex] }

    readonly property var fontMicro:   [8, 11, 14]
    readonly property var fontCaption: [9, 12, 15]
    readonly property var fontBody:    [11, 14, 17]
    readonly property var fontSubhead: [12, 16, 20]
    readonly property var fontTitle:   [16, 21, 26]
    readonly property var fontDisplay: [58, 82, 106]

    // --- THEMES ---
    property color bgBase: "#12131a"
    property color bgPanel: "#1e202b"
    property color accent: "#94a3b8"
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
        var accentColor = useCustomColors ? customAccent : (themes[index] || themes[0]).bgPanel ? (themes[index] || themes[0]).accent : "#94a3b8"

        bgBase = Qt.rgba(Qt.color(baseColor).r, Qt.color(baseColor).g, Qt.color(baseColor).b, shellOpacity)
        bgPanel = Qt.rgba(Qt.color(panelColor).r, Qt.color(panelColor).g, Qt.color(panelColor).b, shellOpacity)
        accent = accentColor

        if (!useCustomColors) {
            var t = themes[index] || themes[0]
            customBgBase = t.bgBase
            customBgPanel = t.bgPanel
            customAccent = t.accent
        }

        if (configRef) configRef.syncHyprlandBorders()
    }

    function setTheme(index) {
        if (index < 0 || index >= themes.length) index = 0
        currentThemeIndex = index

        var t = themes[index]
        customBgBase = t.bgBase
        customBgPanel = t.bgPanel
        customAccent = t.accent

        applyTheme(index)
        if (configRef) configRef.saveSettings()
    }
}
