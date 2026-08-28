pragma Singleton
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import "settings"
import "services"

QtObject {
    id: root

    // Broadcast so every open WidgetContextMenu instance (one per desktop
    // widget window, plus the screen-wide DesktopContextArea) closes itself
    // whenever any of them registers a new click - keeps only one open at a time.
    signal closeWidgetMenus()

    // --- WALLPAPER (extracted to services/WallpaperConfig.qml) ---
    property WallpaperConfig wallpaper: WallpaperConfig { configRef: root }
    property alias wallhavenUsername: root.wallpaper.wallhavenUsername
    property alias wallhavenApiKey: root.wallpaper.wallhavenApiKey
    property alias selectedWallpaperMonitors: root.wallpaper.selectedWallpaperMonitors
    property alias wallpaperTransitionType: root.wallpaper.wallpaperTransitionType
    property alias activeWallpaperPath: root.wallpaper.activeWallpaperPath
    property alias activeMonitorWallpapers: root.wallpaper.activeMonitorWallpapers
    property alias enableWallpaperParallax: root.wallpaper.enableWallpaperParallax
    property alias wallpaperWorkspaceParallax: root.wallpaper.wallpaperWorkspaceParallax
    property alias wallpaperCursorParallax: root.wallpaper.wallpaperCursorParallax
    property alias wallpaperParallaxIntensity: root.wallpaper.wallpaperParallaxIntensity
    property alias wallpaperQuerier: root.wallpaper.wallpaperQuerier
    property alias slideshowActive: root.wallpaper.slideshowActive
    property alias slideshowMinutes: root.wallpaper.slideshowMinutes
    property alias wallpapers: root.wallpaper.wallpapers
    property alias tempPaths: root.wallpaper.tempPaths
    function getMonitorWallpaper(screenName) { return wallpaper.getMonitorWallpaper(screenName) }
    function refreshActiveWallpapers() { wallpaper.refreshActiveWallpapers() }
    function triggerRandomWallpaperBackground() { wallpaper.triggerRandomWallpaperBackground() }
    function applyWallpaperBackend(filePath, activeOnly) { wallpaper.applyWallpaperBackend(filePath, activeOnly) }
    function toggleWallpaperMonitor(screenName) { wallpaper.toggleWallpaperMonitor(screenName) }
    function refreshWallpapers() { wallpaper.refreshWallpapers() }

    // --- RETRO SCREEN SHADER STATE & PERSISTENCE (extracted to services/PixelShaderConfig.qml) ---
    property PixelShaderConfig pixelShaderConfig: PixelShaderConfig { configRef: root }
    property alias pixelShaderEnabled: root.pixelShaderConfig.pixelShaderEnabled
    property alias pixelShaderMode: root.pixelShaderConfig.pixelShaderMode
    property alias pixelShaderSize: root.pixelShaderConfig.pixelShaderSize
    property alias pixelShaderLevels: root.pixelShaderConfig.pixelShaderLevels
    property alias pixelShaderPalette: root.pixelShaderConfig.pixelShaderPalette
    property alias pixelShaderDither: root.pixelShaderConfig.pixelShaderDither
    property alias pixelShaderGrid: root.pixelShaderConfig.pixelShaderGrid
    property alias pixelShaderBoost: root.pixelShaderConfig.pixelShaderBoost
    function updateShader() { pixelShaderConfig.updateShader() }

    // --- EXTRACTED BACKGROUND SERVICES ---
    property WallpaperService wallpaperService: WallpaperService { configRef: root }
    property QuoteService quoteService: QuoteService { configRef: root }
    property IrisColorService irisService: IrisColorService { configRef: root }
    property ShaderService shaderService: ShaderService { configRef: root }
    property MotionService motionService: MotionService {}
    property CavaService cavaService: CavaService { configRef: root }
    property IconIndexService iconIndexService: IconIndexService {}
    function getAppIcon(iconName) { return iconIndexService.getAppIcon(iconName) }

    property bool showTaskOverflow: false

    // --- SCREENSHOT (extracted to services/ScreenshotService.qml) ---
    property ScreenshotService screenshotService: ScreenshotService {}
    function captureScreenshot() { screenshotService.capture() }

    // --- CAMERA / MIRROR (extracted to services/MirrorConfig.qml) ---
    property MirrorConfig mirror: MirrorConfig { configRef: root }
    property alias showMirror: root.mirror.showMirror
    property alias mirrorShowPanel: root.mirror.mirrorShowPanel
    property alias mirrorMirrored: root.mirror.mirrorMirrored
    property alias mirrorKeepAspect: root.mirror.mirrorKeepAspect
    property alias mirrorExpanded: root.mirror.mirrorExpanded
    property alias mirrorPinned: root.mirror.mirrorPinned
    property alias mirrorAnchorPos: root.mirror.mirrorAnchorPos
    property alias mirrorLoading: root.mirror.mirrorLoading
    property alias mirrorError: root.mirror.mirrorError
    readonly property alias mirrorCaptureSession: root.mirror.mirrorCaptureSession
    readonly property alias mirrorMediaDevices: root.mirror.mirrorMediaDevices
    function cycleMirrorAnchor(direction) { mirror.cycleMirrorAnchor(direction) }

    // --- INITIALIZATION GUARD ---
    property bool isLoaded: false

    // UI Toggle States
    property bool showSettings: false
    property bool showCalendar: false
    property bool showWallpaper: false
    property bool showAppLauncher: false
    property bool showLauncherOsd: false
    property bool showNetwork: false
    property bool showAudio: false
    property bool showBluetooth: false
    property bool showWifi: false
    property bool showOSD: false
    property bool showWorkspacePreview: false
    property bool showNotificationOsd: false
    property bool showControlCenter: false
    property bool showBattery: false
    property bool showPower: false
    property bool showClipboard: false
    property bool showScreenRecorder: false

    // --- NAVIGATION PERSISTENCE ---
    property int lastSettingsSection: 0
    onLastSettingsSectionChanged: { if (isLoaded) saveSettings() }

    // --- SHELL KEYBIND CUSTOMIZATION (extracted to services/KeybindsConfig.qml) ---
    property KeybindsConfig keybindsConfig: KeybindsConfig { configRef: root }
    readonly property alias defaultKeybinds: root.keybindsConfig.defaultKeybinds
    property alias keybinds: root.keybindsConfig.keybinds
    function updateKeybind(action, mod, key) { keybindsConfig.updateKeybind(action, mod, key) }
    function resetKeybinds() { keybindsConfig.resetKeybinds() }

    // --- SYSTEM SOUNDS CONFIGURATION (extracted to services/SoundsConfig.qml) ---
    property SoundsConfig sounds: SoundsConfig { configRef: root }
    property alias playWindowSounds: root.sounds.playWindowSounds
    property alias playNotificationSounds: root.sounds.playNotificationSounds
    property alias windowSoundPath: root.sounds.windowSoundPath
    property alias notificationSoundPath: root.sounds.notificationSoundPath
    property alias windowSoundVolume: root.sounds.windowSoundVolume

    // --- NOTIFICATION HISTORY (extracted to services/NotificationHistoryService.qml) ---
    // Persists to its own notification_history.json, not settings.json - see
    // that file for why.
    property NotificationHistoryService notificationHistoryService: NotificationHistoryService {}
    property alias notificationHistory: root.notificationHistoryService.entries
    function recordNotification(notif) { notificationHistoryService.record(notif) }
    function clearNotificationHistory() { notificationHistoryService.clear() }

    // --- LOCKSCREEN STATE ---
    property bool sessionLocked: false

    // --- LOCKSCREEN CONFIGURATION (extracted to services/LockscreenConfig.qml) ---
    property LockscreenConfig lockscreenConfig: LockscreenConfig { configRef: root }
    property alias lockscreenBlurRadius: root.lockscreenConfig.lockscreenBlurRadius
    property alias lockscreenShowMedia: root.lockscreenConfig.lockscreenShowMedia
    property alias lockscreenShowPower: root.lockscreenConfig.lockscreenShowPower
    property alias lockscreenMaskStyle: root.lockscreenConfig.lockscreenMaskStyle
    property alias lockscreenShapePalette: root.lockscreenConfig.lockscreenShapePalette
    property alias lockscreenUse12Hour: root.lockscreenConfig.lockscreenUse12Hour
    property alias lockscreenShowSeconds: root.lockscreenConfig.lockscreenShowSeconds
    property alias lockscreenShowAmPm: root.lockscreenConfig.lockscreenShowAmPm
    property alias lockscreenDateFormat: root.lockscreenConfig.lockscreenDateFormat
    property alias lockscreenClockSize: root.lockscreenConfig.lockscreenClockSize
    property alias lockscreenTargetMonitor: root.lockscreenConfig.lockscreenTargetMonitor

    // --- WORKSPACES CONFIGURATION (extracted to services/WorkspacesConfig.qml) ---
    property WorkspacesConfig workspacesConfig: WorkspacesConfig { configRef: root }
    property alias workspaceStyle: root.workspacesConfig.workspaceStyle
    property alias workspaceGlow: root.workspacesConfig.workspaceGlow
    property alias workspaceScroll: root.workspacesConfig.workspaceScroll
    property alias workspaceTooltips: root.workspacesConfig.workspaceTooltips
    property alias workspaceShowAddBtn: root.workspacesConfig.workspaceShowAddBtn
    property alias workspaceShowOverviewBtn: root.workspacesConfig.workspaceShowOverviewBtn
    property alias workspaceShowSpecial: root.workspacesConfig.workspaceShowSpecial
    property alias workspaceContainerStyle: root.workspacesConfig.workspaceContainerStyle

    // --- CAFFEINE STATE & TIMER (extracted to services/CaffeineConfig.qml) ---
    property CaffeineConfig caffeine: CaffeineConfig { configRef: root }
    property alias caffeineHasHypridle: root.caffeine.caffeineHasHypridle
    property alias caffeineState: root.caffeine.caffeineState
    property alias caffeineTimerEndTime: root.caffeine.caffeineTimerEndTime
    property alias caffeineRemainingTimeString: root.caffeine.caffeineRemainingTimeString
    function addCaffeineMinutes(minutes) { caffeine.addCaffeineMinutes(minutes) }
    function cycleCaffeine() { caffeine.cycleCaffeine() }
    function startCaffeineTimer(minutes) { caffeine.startCaffeineTimer(minutes) }
    function setIndefiniteCaffeine() { caffeine.setIndefiniteCaffeine() }

    // --- ICON MAP, MODULE COLLAPSE/PINNING & ORDERING (extracted to services/ModuleLayoutConfig.qml) ---
    property ModuleLayoutConfig moduleLayout: ModuleLayoutConfig { configRef: root }
    property alias iconOverrides: root.moduleLayout.iconOverrides
    readonly property alias defaultIcons: root.moduleLayout.defaultIcons
    property alias leftCardCollapsed: root.moduleLayout.leftCardCollapsed
    property alias rightCardCollapsed: root.moduleLayout.rightCardCollapsed
    property alias pinnedIcons: root.moduleLayout.pinnedIcons
    property alias leftCardOrder: root.moduleLayout.leftCardOrder
    property alias rightCardOrder: root.moduleLayout.rightCardOrder
    function getIcon(iconId) { return moduleLayout.getIcon(iconId) }
    function setIconOverride(iconId, glyphName) { moduleLayout.setIconOverride(iconId, glyphName) }
    function resetIcons() { moduleLayout.resetIcons() }
    function togglePin(iconId) { moduleLayout.togglePin(iconId) }
    function isPinned(iconId) { return moduleLayout.isPinned(iconId) }
    function moveModule(cardKey, iconId, direction) { moduleLayout.moveModule(cardKey, iconId, direction) }

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

    // --- DESKTOP WIDGETS: CLOCK / SYSINFO / CAVA (extracted to services/DesktopWidgetsConfig.qml) ---
    property DesktopWidgetsConfig desktopWidgets: DesktopWidgetsConfig { configRef: root }
    property alias showDesktopClock: root.desktopWidgets.showDesktopClock
    property alias clockStyle: root.desktopWidgets.clockStyle
    property alias clockScale: root.desktopWidgets.clockScale
    property alias clockShowSeconds: root.desktopWidgets.clockShowSeconds
    property alias clockUse12Hour: root.desktopWidgets.clockUse12Hour
    property alias clockShowAmPm: root.desktopWidgets.clockShowAmPm
    property alias clockShowBorder: root.desktopWidgets.clockShowBorder
    property alias clockShowBackground: root.desktopWidgets.clockShowBackground
    property alias clockShowGlow: root.desktopWidgets.clockShowGlow
    property alias clockPositions: root.desktopWidgets.clockPositions
    property alias clockScales: root.desktopWidgets.clockScales
    property alias enabledClockScreens: root.desktopWidgets.enabledClockScreens
    function getClockPosition(screenName, defaultX, defaultY) { return desktopWidgets.getClockPosition(screenName, defaultX, defaultY) }
    function saveClockPosition(screenName, x, y) { desktopWidgets.saveClockPosition(screenName, x, y) }
    function getClockScale(screenName) { return desktopWidgets.getClockScale(screenName) }
    function saveClockScale(screenName, scale) { desktopWidgets.saveClockScale(screenName, scale) }
    function isClockEnabledForScreen(screenName) { return desktopWidgets.isClockEnabledForScreen(screenName) }
    function toggleClockScreen(screenName) { desktopWidgets.toggleClockScreen(screenName) }

    property alias showDesktopSysInfo: root.desktopWidgets.showDesktopSysInfo
    property alias sysInfoScale: root.desktopWidgets.sysInfoScale
    property alias sysInfoShowHost: root.desktopWidgets.sysInfoShowHost
    property alias sysInfoShowOs: root.desktopWidgets.sysInfoShowOs
    property alias sysInfoShowKernel: root.desktopWidgets.sysInfoShowKernel
    property alias sysInfoShowUptime: root.desktopWidgets.sysInfoShowUptime
    property alias sysInfoShowPackages: root.desktopWidgets.sysInfoShowPackages
    property alias sysInfoShowWm: root.desktopWidgets.sysInfoShowWm
    property alias sysInfoShowBoard: root.desktopWidgets.sysInfoShowBoard
    property alias sysInfoShowCpu: root.desktopWidgets.sysInfoShowCpu
    property alias sysInfoShowCores: root.desktopWidgets.sysInfoShowCores
    property alias sysInfoShowLoad: root.desktopWidgets.sysInfoShowLoad
    property alias sysInfoShowGpu: root.desktopWidgets.sysInfoShowGpu
    property alias sysInfoShowIp: root.desktopWidgets.sysInfoShowIp
    property alias sysInfoShowGateway: root.desktopWidgets.sysInfoShowGateway
    property alias sysInfoShowDns: root.desktopWidgets.sysInfoShowDns
    property alias sysInfoShowRam: root.desktopWidgets.sysInfoShowRam
    property alias sysInfoShowSwap: root.desktopWidgets.sysInfoShowSwap
    property alias sysInfoShowDisk: root.desktopWidgets.sysInfoShowDisk
    property alias sysInfoShowDiskHome: root.desktopWidgets.sysInfoShowDiskHome
    property alias sysInfoShowBg: root.desktopWidgets.sysInfoShowBg
    property alias sysInfoShowGlow: root.desktopWidgets.sysInfoShowGlow
    property alias sysInfoRefreshInterval: root.desktopWidgets.sysInfoRefreshInterval
    property alias sysInfoPositions: root.desktopWidgets.sysInfoPositions
    property alias sysInfoScales: root.desktopWidgets.sysInfoScales
    property alias enabledSysInfoScreens: root.desktopWidgets.enabledSysInfoScreens
    function getSysInfoPosition(screenName, defaultX, defaultY) { return desktopWidgets.getSysInfoPosition(screenName, defaultX, defaultY) }
    function saveSysInfoPosition(screenName, x, y) { desktopWidgets.saveSysInfoPosition(screenName, x, y) }
    function getSysInfoScale(screenName) { return desktopWidgets.getSysInfoScale(screenName) }
    function saveSysInfoScale(screenName, scale) { desktopWidgets.saveSysInfoScale(screenName, scale) }
    function isSysInfoEnabledForScreen(screenName) { return desktopWidgets.isSysInfoEnabledForScreen(screenName) }
    function toggleSysInfoScreen(screenName) { desktopWidgets.toggleSysInfoScreen(screenName) }

    property alias showDesktopCava: root.desktopWidgets.showDesktopCava
    property alias cavaStyle: root.desktopWidgets.cavaStyle
    property alias cavaColorMode: root.desktopWidgets.cavaColorMode
    property alias cavaGradientStart: root.desktopWidgets.cavaGradientStart
    property alias cavaGradientEnd: root.desktopWidgets.cavaGradientEnd
    property alias cavaSolidColor: root.desktopWidgets.cavaSolidColor
    property alias cavaRainbowSpeed: root.desktopWidgets.cavaRainbowSpeed
    property alias cavaBars: root.desktopWidgets.cavaBars
    property alias cavaFramerate: root.desktopWidgets.cavaFramerate
    property alias cavaSensitivity: root.desktopWidgets.cavaSensitivity
    property alias cavaSmoothing: root.desktopWidgets.cavaSmoothing
    property alias ambientBreatheEnabled: root.desktopWidgets.ambientBreatheEnabled
    property alias ambientBreatheIntensity: root.desktopWidgets.ambientBreatheIntensity
    property alias cavaBarWidth: root.desktopWidgets.cavaBarWidth
    property alias cavaBarGap: root.desktopWidgets.cavaBarGap
    property alias cavaBarRadius: root.desktopWidgets.cavaBarRadius
    property alias cavaMaxHeight: root.desktopWidgets.cavaMaxHeight
    property alias cavaRingRadius: root.desktopWidgets.cavaRingRadius
    property alias cavaShowGlow: root.desktopWidgets.cavaShowGlow
    property alias cavaShowBackground: root.desktopWidgets.cavaShowBackground
    property alias cavaShowBorder: root.desktopWidgets.cavaShowBorder
    property alias cavaRotation: root.desktopWidgets.cavaRotation
    property alias cavaPositions: root.desktopWidgets.cavaPositions
    property alias cavaScales: root.desktopWidgets.cavaScales
    property alias enabledCavaScreens: root.desktopWidgets.enabledCavaScreens
    function rotateCava(direction) { desktopWidgets.rotateCava(direction) }
    function getCavaPosition(screenName, defaultX, defaultY) { return desktopWidgets.getCavaPosition(screenName, defaultX, defaultY) }
    function saveCavaPosition(screenName, x, y) { desktopWidgets.saveCavaPosition(screenName, x, y) }
    function getCavaScale(screenName) { return desktopWidgets.getCavaScale(screenName) }
    function saveCavaScale(screenName, scale) { desktopWidgets.saveCavaScale(screenName, scale) }
    function isCavaEnabledForScreen(screenName) { return desktopWidgets.isCavaEnabledForScreen(screenName) }
    function toggleCavaScreen(screenName) { desktopWidgets.toggleCavaScreen(screenName) }

    property alias slideshowRunner: root.wallpaperService.slideshowRunner
    property alias bgSlideshowTimer: root.wallpaperService.bgSlideshowTimer
    property alias wallpaperApplyRunner: root.wallpaperService.wallpaperApplyRunner

    // --- GLOBAL WEATHER SERVICE ---
    property WeatherService weather: WeatherService {
        id: globalWeather
        zipcode: root.locationQuery
    }

    // Only poll weather if loaded and a valid location query exists
    property Timer weatherTimer: Timer {
        interval: 900000
        running: root.isLoaded && root.locationQuery.trim().length > 0
        repeat: true
        onTriggered: root.weather.fetchWeather(true)
    }

    onSelectedWallpaperMonitorsChanged: { if (isLoaded) saveSettings() }
    onWallpaperTransitionTypeChanged: { if (isLoaded) saveSettings() }

    // --- OSK / SCREENSAVER / MASCOT (extracted to services/DesktopExtrasConfig.qml) ---
    property DesktopExtrasConfig desktopExtras: DesktopExtrasConfig { configRef: root }
    property alias showOsk: root.desktopExtras.showOsk
    property alias oskLayout: root.desktopExtras.oskLayout
    property alias showScreensaver: root.desktopExtras.showScreensaver
    property alias screensaverText: root.desktopExtras.screensaverText
    property alias screensaverMode: root.desktopExtras.screensaverMode
    property alias screensaverFontSize: root.desktopExtras.screensaverFontSize
    property alias screensaverSpeed: root.desktopExtras.screensaverSpeed
    property alias screensaverCornerCounter: root.desktopExtras.screensaverCornerCounter
    property alias showMascot: root.desktopExtras.showMascot
    property alias mascotPath: root.desktopExtras.mascotPath
    property alias mascotPhrases: root.desktopExtras.mascotPhrases
    property alias fetchOnlineQuotes: root.desktopExtras.fetchOnlineQuotes
    property alias quoteSource: root.desktopExtras.quoteSource
    property alias rssFeedUrl: root.desktopExtras.rssFeedUrl
    function addMascotPhrase(phrase) { desktopExtras.addMascotPhrase(phrase) }
    function removeMascotPhrase(index) { desktopExtras.removeMascotPhrase(index) }
    function processQuoteQueue() { desktopExtras.processQuoteQueue() }
    function triggerQuoteFetch() { desktopExtras.triggerQuoteFetch() }

    // --- BAR / FRAME / RENDERING TOGGLES + TYPOGRAPHY + THEMES (extracted to services/AppearanceConfig.qml) ---
    property AppearanceConfig appearance: AppearanceConfig { configRef: root }
    property alias barFrameStyle: root.appearance.barFrameStyle
    property alias animateGradient: root.appearance.animateGradient
    property alias showScreenFrame: root.appearance.showScreenFrame
    property alias shellOpacity: root.appearance.shellOpacity
    property alias enableBlur: root.appearance.enableBlur
    property alias enableXray: root.appearance.enableXray
    property alias enableIris: root.appearance.enableIris
    property alias showWatermarks: root.appearance.showWatermarks
    property alias bounceWatermarks: root.appearance.bounceWatermarks
    function applyIrisColors(filePath) { appearance.applyIrisColors(filePath) }

    // activeWallpaperPath lives in the wallpaper group, so this stays here (aliases still fire their own onChanged)
    onActiveWallpaperPathChanged: {
        if (isLoaded && enableIris && activeWallpaperPath !== "") {
            applyIrisColors(activeWallpaperPath)
        }
    }

    property alias enableHoverPeek: root.appearance.enableHoverPeek
    property alias nightModeEnabled: root.appearance.nightModeEnabled
    property alias nightModeAuto: root.appearance.nightModeAuto
    property alias nightModeScheduleStart: root.appearance.nightModeScheduleStart
    property alias nightModeScheduleEnd: root.appearance.nightModeScheduleEnd
    readonly property alias isFloatingBar: root.appearance.isFloatingBar

    property alias quoteFetchQueue: root.quoteService.quoteFetchQueue
    property alias quoteFetcher: root.quoteService.quoteFetcher
    property alias quoteFetchTimer: root.quoteService.quoteFetchTimer

    property alias barPosition: root.appearance.barPosition
    property alias autoHideBar: root.appearance.autoHideBar
    function syncScreenFrame() { appearance.syncScreenFrame() }

    property alias sysFont: root.appearance.sysFont
    property alias nativeFontRendering: root.appearance.nativeFontRendering
    readonly property alias textRenderType: root.appearance.textRenderType
    property alias fontDropdownOpen: root.appearance.fontDropdownOpen
    property alias fontSearchFilter: root.appearance.fontSearchFilter
    property alias fontScaleIndex: root.appearance.fontScaleIndex
    function fontStyle(fontObj) { return appearance.fontStyle(fontObj) }

    property string locationQuery: ""
    property alias currentThemeIndex: root.appearance.currentThemeIndex

    property alias useCustomColors: root.appearance.useCustomColors
    property alias customBgBase: root.appearance.customBgBase
    property alias customBgPanel: root.appearance.customBgPanel
    property alias customAccent: root.appearance.customAccent
    property alias borderStart: root.appearance.borderStart
    property alias borderEnd: root.appearance.borderEnd
    property alias windowStyle: root.appearance.windowStyle

    onLocationQueryChanged: {
        if (root.weather) {
            root.weather.zipcode = root.locationQuery;
            if (root.isLoaded && root.locationQuery.trim().length > 0) {
                root.weather.fetchWeather(true);
                root.saveSettings();
            }
        }
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
        let actualScreen = (Quickshell.screens && screenName) ? Quickshell.screens.find(s => s.name === screenName) : null
        let defaultW = actualScreen ? actualScreen.width : 1920
        let defaultH = actualScreen ? actualScreen.height : 1080
        const safeFallback = { width: defaultW, height: defaultH, refreshRate: 60.0, x: 0, y: 0, scale: "auto", transform: 0 }

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
        let actualScreen = (Quickshell.screens && Quickshell.screens.length > 0) ? Quickshell.screens[0] : null
        let defaultW = actualScreen ? actualScreen.width : 1920
        let defaultH = actualScreen ? actualScreen.height : 1080
        return { width: defaultW, height: defaultH, refreshRate: 60.0, x: 0, y: 0, scale: "auto", transform: 0 }
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

        let monitorLuaBlocks = []
        if (monitorConfigs && Object.keys(monitorConfigs).length > 0) {
            Object.keys(monitorConfigs).forEach(k => {
                let m = monitorConfigs[k]
                if (!m) return
                let safeScale = (m.scale === "auto" || !m.scale) ? "auto" : getNearestValidScale(m.width, m.height, m.scale)
                let scaleVal = (safeScale === "auto") ? '"auto"' : parseFloat(safeScale).toFixed(2)
                let transformLine = (m.transform !== undefined && m.transform !== 0) ? ',\n    transform = ' + m.transform : ''
                
                let luaBlock = 'hl.monitor({\n' +
                    '    output = "' + k + '",\n' +
                    '    mode = "' + m.width + 'x' + m.height + '@' + (m.refreshRate || 60.0) + '",\n' +
                    '    position = "' + m.x + 'x' + m.y + '",\n' +
                    '    scale = ' + scaleVal + transformLine + '\n' +
                    '})'
                monitorLuaBlocks.push(luaBlock)
            })
        }

        let pyScript = "import os, re\n" +
            "path = os.path.expanduser('~/.config/hypr/hypr_style.lua')\n" +
            "content = ''\n" +
            "if os.path.exists(path):\n" +
            "    with open(path, 'r') as f:\n" +
            "        content = f.read()\n" +
            "content = re.sub(r'hl\\.monitor\\(\\{[^}]+\\}\\)\\n*', '', content).strip()\n" +
            "new_monitors = '''" + monitorLuaBlocks.join("\n\n") + "'''\n" +
            "full_content = content + '\\n\\n' + new_monitors + '\\n'\n" +
            "with open(path, 'w') as f:\n" +
            "    f.write(full_content)\n"

        let cmd = "python3 -c \"" + pyScript.replace(/"/g, '\\"') + "\" && hyprctl reload"

        writer.command = ["fish", "-c", cmd]
        writer.running = true
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

        let activeLua = animateGradient
            ? '{ colors = { "' + colorStart + '", "' + colorEnd + '" }, angle = 45 }'
            : '"' + colorStart + '"'

        let borderSize = root.borderThickness
        let gapsOut = (barFrameStyle === "screen") ? 32 : 20
        let roundingVal = Math.round(surfaceRadius)
        let shaderPath = (root.pixelShaderEnabled || root.nightModeEnabled)
            ? (Quickshell.env("HOME") + "/.config/hypr/shaders/pixelate.frag")
            : ""

        let bindLines = []
        let bindKeys = ["wallpaper", "launcher", "launcherosd", "settings", "workspaceoverview", "clipboard", "lockscreen", "shader"]
        bindKeys.forEach(bk => {
            let b = (root.keybinds && root.keybinds[bk]) ? root.keybinds[bk] : root.defaultKeybinds[bk]
            if (b) {
                let modStr = (b.mod || "SUPER").replace(/mainMod/g, "SUPER").replace(/\.\./g, "").replace(/["']/g, "").trim()
                let keyStr = (b.key || "").trim()
                let combo = modStr.length > 0 ? (modStr + " + " + keyStr) : keyStr
                combo = combo.replace(/\+\s*\+/g, "+").trim()
                bindLines.push('hl.bind("' + combo + '", hl.dsp.exec_cmd("' + b.cmd + '"))')
            }
        })
        let bindsLua = bindLines.join('\n')

        let pyScript = "import os, re\n" +
            "path = os.path.expanduser('~/.config/hypr/hypr_style.lua')\n" +
            "existing_monitors = ''\n" +
            "if os.path.exists(path):\n" +
            "    with open(path, 'r') as f:\n" +
            "        content = f.read()\n" +
            "        mons = re.findall(r'hl\\.monitor\\(\\{[^}]+\\}\\)', content, re.DOTALL)\n" +
            "        if mons:\n" +
            "            existing_monitors = '\\n\\n'.join(mons)\n\n" +
            "new_config = '''hl.config({\n" +
            "    general = {\n" +
            "        gaps_out = " + gapsOut + ",\n" +
            "        border_size = " + borderSize + ",\n" +
            "        col = {\n" +
            "            active_border = " + activeLua + ",\n" +
            "            inactive_border = \"" + inactiveStr + "\"\n" +
            "        }\n" +
            "    },\n" +
            "    decoration = {\n" +
            "        rounding = " + roundingVal + ",\n" +
            "        screen_shader = \"" + shaderPath + "\"\n" +
            "    }\n" +
            "})\n\n" +
            "hl.layer_rule({\n" +
            "    name = \"synoptik-shell\",\n" +
            "    match = { namespace = \"^synoptik-shell.*\" },\n" +
            "    blur = " + (enableBlur ? "true" : "false") + ",\n" +
            "    xray = " + (enableXray ? "true" : "false") + ",\n" +
            "    ignore_alpha = 0.6\n" +
            "})\n\n" +
            bindsLua.replace(/\\/g, '\\\\').replace(/'/g, "\\'") + "\n'''\n\n" +
            "if existing_monitors:\n" +
            "    new_config += '\\n' + existing_monitors + '\\n'\n\n" +
            "with open(path, 'w') as f:\n" +
            "    f.write(new_config)\n"

        let cmd = "python3 -c \"" + pyScript.replace(/"/g, '\\"') + "\" && hyprctl reload"

        writer.command = ["fish", "-c", cmd]
        writer.running = true
    }


    // Persistence
    readonly property string settingsPath: Quickshell.shellDir.toString().replace(/^file:\/\//, "") + "/settings.json"

    // Every plain key persisted to settings.json - shared by both the save and load
    // directions below via settingsAdapter. This used to be two independently
    // hand-typed lists (a save-side object literal and a load-side array) that had to
    // be kept in sync by hand; a key added to one and not the other silently dropped
    // data on the next restart. Unifying them here fixed two such drifts already:
    // "windowStyle" was written but never read back, and "rightCardOrder" was read
    // but never written.
    //
    // "keybinds", "customThemes" and "currentThemeIndex" are deliberately left out -
    // they need extra normalization/clamping on load, handled separately below.
    readonly property var persistedKeys: [
        "lastSettingsSection", "monitorConfigs", "selectedWallpaperMonitors", "wallpaperTransitionType",
        "activeWallpaperPath", "enableWallpaperParallax", "wallpaperWorkspaceParallax",
        "wallpaperCursorParallax", "wallpaperParallaxIntensity", "slideshowActive", "slideshowMinutes",
        "showScreensaver", "screensaverText", "screensaverMode", "screensaverFontSize",
        "screensaverSpeed", "screensaverCornerCounter", "showOsk", "oskLayout", "showMascot",
        "mascotPath", "mascotPhrases", "fetchOnlineQuotes", "quoteSource", "barFrameStyle",
        "barPosition", "autoHideBar", "showScreenFrame", "sysFont", "nativeFontRendering",
        "fontScaleIndex", "locationQuery", "enabledBarScreens", "useCustomColors", "customBgBase",
        "customBgPanel", "customAccent", "animateGradient", "shellOpacity", "enableBlur", "enableXray",
        "enableIris", "showWatermarks", "bounceWatermarks", "windowStyle", "playWindowSounds",
        "playNotificationSounds", "windowSoundPath", "notificationSoundPath", "windowSoundVolume",
        "enableHoverPeek", "nightModeEnabled", "nightModeAuto", "nightModeScheduleStart",
        "nightModeScheduleEnd", "pixelShaderEnabled", "pixelShaderMode", "pixelShaderSize",
        "pixelShaderLevels", "pixelShaderPalette", "pixelShaderDither", "pixelShaderGrid",
        "pixelShaderBoost", "showMirror", "mirrorShowPanel", "mirrorMirrored", "mirrorKeepAspect",
        "mirrorExpanded", "mirrorPinned", "mirrorAnchorPos", "leftCardOrder", "rightCardOrder",
        "leftCardCollapsed", "rightCardCollapsed", "pinnedIcons", "iconOverrides", "surfaceRadius",
        "borderThickness", "cardMargin", "showDesktopClock", "clockStyle", "clockScale",
        "clockShowSeconds", "clockUse12Hour", "clockShowAmPm", "clockShowBorder", "clockShowBackground",
        "clockShowGlow", "clockPositions", "clockScales", "enabledClockScreens", "showDesktopSysInfo",
        "sysInfoScale", "sysInfoShowHost", "sysInfoShowOs", "sysInfoShowKernel", "sysInfoShowUptime",
        "sysInfoShowPackages", "sysInfoShowWm", "sysInfoShowBoard", "sysInfoShowCpu",
        "sysInfoShowCores", "sysInfoShowLoad", "sysInfoShowGpu", "sysInfoShowIp", "sysInfoShowGateway",
        "sysInfoShowDns", "sysInfoShowRam", "sysInfoShowSwap", "sysInfoShowDisk", "sysInfoShowDiskHome",
        "sysInfoShowBg", "sysInfoShowGlow", "sysInfoRefreshInterval", "sysInfoPositions",
        "sysInfoScales", "enabledSysInfoScreens", "showDesktopCava", "cavaStyle", "cavaColorMode",
        "cavaGradientStart", "cavaGradientEnd", "cavaSolidColor", "cavaRainbowSpeed", "cavaBars",
        "cavaFramerate", "cavaSensitivity", "cavaSmoothing", "ambientBreatheEnabled",
        "ambientBreatheIntensity", "cavaBarWidth", "cavaBarGap", "cavaBarRadius", "cavaMaxHeight",
        "cavaRingRadius", "cavaShowGlow", "cavaShowBackground", "cavaShowBorder", "cavaRotation",
        "cavaPositions", "cavaScales", "enabledCavaScreens", "lockscreenBlurRadius",
        "lockscreenShowMedia", "lockscreenShowPower", "lockscreenMaskStyle", "lockscreenShapePalette",
        "lockscreenUse12Hour", "lockscreenShowSeconds", "lockscreenShowAmPm", "lockscreenDateFormat",
        "lockscreenClockSize", "lockscreenTargetMonitor", "workspaceStyle", "workspaceGlow",
        "workspaceScroll", "workspaceTooltips", "workspaceShowAddBtn", "workspaceShowOverviewBtn",
        "workspaceShowSpecial", "workspaceContainerStyle", "wallhavenUsername", "wallhavenApiKey"
    ]

    // Settings are stored as JSON via Quickshell's own FileView+JsonAdapter instead of a
    // hand-rolled `fish -c "printf ... > path"` / `cat path` Process pair: no shell
    // escaping (and no shell-injection surface) for arbitrary string values like wallpaper
    // paths or mascot phrases, no manual JSON.stringify/parse, and no busy-wait
    // re-entrancy guard around the write (that was only ever needed because a raw
    // Process can't safely have its command swapped out from under an in-flight run -
    // FileView's writer handles that internally).
    property FileView settingsFile: FileView {
        id: settingsFileImpl
        path: root.settingsPath

        JsonAdapter {
            id: settingsAdapter
            property var lastSettingsSection
            property var monitorConfigs
            property var selectedWallpaperMonitors
            property var wallpaperTransitionType
            property var activeWallpaperPath
            property var enableWallpaperParallax
            property var wallpaperWorkspaceParallax
            property var wallpaperCursorParallax
            property var wallpaperParallaxIntensity
            property var slideshowActive
            property var slideshowMinutes
            property var showScreensaver
            property var screensaverText
            property var screensaverMode
            property var screensaverFontSize
            property var screensaverSpeed
            property var screensaverCornerCounter
            property var showOsk
            property var oskLayout
            property var showMascot
            property var mascotPath
            property var mascotPhrases
            property var fetchOnlineQuotes
            property var quoteSource
            property var barFrameStyle
            property var barPosition
            property var autoHideBar
            property var showScreenFrame
            property var sysFont
            property var nativeFontRendering
            property var fontScaleIndex
            property var locationQuery
            property var enabledBarScreens
            property var useCustomColors
            property var customBgBase
            property var customBgPanel
            property var customAccent
            property var animateGradient
            property var shellOpacity
            property var enableBlur
            property var enableXray
            property var enableIris
            property var showWatermarks
            property var bounceWatermarks
            property var windowStyle
            property var playWindowSounds
            property var playNotificationSounds
            property var windowSoundPath
            property var notificationSoundPath
            property var windowSoundVolume
            property var enableHoverPeek
            property var nightModeEnabled
            property var nightModeAuto
            property var nightModeScheduleStart
            property var nightModeScheduleEnd
            property var pixelShaderEnabled
            property var pixelShaderMode
            property var pixelShaderSize
            property var pixelShaderLevels
            property var pixelShaderPalette
            property var pixelShaderDither
            property var pixelShaderGrid
            property var pixelShaderBoost
            property var showMirror
            property var mirrorShowPanel
            property var mirrorMirrored
            property var mirrorKeepAspect
            property var mirrorExpanded
            property var mirrorPinned
            property var mirrorAnchorPos
            property var leftCardOrder
            property var rightCardOrder
            property var leftCardCollapsed
            property var rightCardCollapsed
            property var pinnedIcons
            property var iconOverrides
            property var surfaceRadius
            property var borderThickness
            property var cardMargin
            property var showDesktopClock
            property var clockStyle
            property var clockScale
            property var clockShowSeconds
            property var clockUse12Hour
            property var clockShowAmPm
            property var clockShowBorder
            property var clockShowBackground
            property var clockShowGlow
            property var clockPositions
            property var clockScales
            property var enabledClockScreens
            property var showDesktopSysInfo
            property var sysInfoScale
            property var sysInfoShowHost
            property var sysInfoShowOs
            property var sysInfoShowKernel
            property var sysInfoShowUptime
            property var sysInfoShowPackages
            property var sysInfoShowWm
            property var sysInfoShowBoard
            property var sysInfoShowCpu
            property var sysInfoShowCores
            property var sysInfoShowLoad
            property var sysInfoShowGpu
            property var sysInfoShowIp
            property var sysInfoShowGateway
            property var sysInfoShowDns
            property var sysInfoShowRam
            property var sysInfoShowSwap
            property var sysInfoShowDisk
            property var sysInfoShowDiskHome
            property var sysInfoShowBg
            property var sysInfoShowGlow
            property var sysInfoRefreshInterval
            property var sysInfoPositions
            property var sysInfoScales
            property var enabledSysInfoScreens
            property var showDesktopCava
            property var cavaStyle
            property var cavaColorMode
            property var cavaGradientStart
            property var cavaGradientEnd
            property var cavaSolidColor
            property var cavaRainbowSpeed
            property var cavaBars
            property var cavaFramerate
            property var cavaSensitivity
            property var cavaSmoothing
            property var ambientBreatheEnabled
            property var ambientBreatheIntensity
            property var cavaBarWidth
            property var cavaBarGap
            property var cavaBarRadius
            property var cavaMaxHeight
            property var cavaRingRadius
            property var cavaShowGlow
            property var cavaShowBackground
            property var cavaShowBorder
            property var cavaRotation
            property var cavaPositions
            property var cavaScales
            property var enabledCavaScreens
            property var lockscreenBlurRadius
            property var lockscreenShowMedia
            property var lockscreenShowPower
            property var lockscreenMaskStyle
            property var lockscreenShapePalette
            property var lockscreenUse12Hour
            property var lockscreenShowSeconds
            property var lockscreenShowAmPm
            property var lockscreenDateFormat
            property var lockscreenClockSize
            property var lockscreenTargetMonitor
            property var workspaceStyle
            property var workspaceGlow
            property var workspaceScroll
            property var workspaceTooltips
            property var workspaceShowAddBtn
            property var workspaceShowOverviewBtn
            property var workspaceShowSpecial
            property var workspaceContainerStyle
            property var wallhavenUsername
            property var wallhavenApiKey
            property var keybinds
            property var customThemes
            property var currentThemeIndex
            property var isFloatingBar  // legacy pre-barFrameStyle key, load-only migration
        }

        function applyLoadedSettings() {
            try {
                root.persistedKeys.forEach(p => {
                    if (settingsAdapter[p] !== undefined) root[p] = settingsAdapter[p]
                })

                if (settingsAdapter.keybinds && typeof settingsAdapter.keybinds === "object") {
                    let cleaned = {}
                    Object.keys(settingsAdapter.keybinds).forEach(k => {
                        let item = settingsAdapter.keybinds[k]
                        cleaned[k] = {
                            mod: (item.mod || "SUPER").replace(/mainMod/g, "SUPER").replace(/\.\./g, "").replace(/["']/g, "").trim(),
                            key: item.key || "",
                            cmd: item.cmd || ""
                        }
                    })
                    root.keybinds = cleaned
                }

                let defaultLeft = ["power", "recorder", "mirror", "screenshot", "wallpaper", "settings", "launcher", "audio", "batt", "network", "clipboard"]
                let currentLeft = Array.isArray(root.leftCardOrder) ? root.leftCardOrder.slice() : []
                defaultLeft.forEach(mod => {
                    if (!currentLeft.includes(mod)) currentLeft.push(mod)
                })
                root.leftCardOrder = currentLeft

                if (settingsAdapter.isFloatingBar !== undefined && settingsAdapter.barFrameStyle === undefined) {
                    root.barFrameStyle = settingsAdapter.isFloatingBar ? "floating" : "edge"
                }

                if (settingsAdapter.customThemes !== undefined && Array.isArray(settingsAdapter.customThemes)) {
                    var stockList = stockThemes.slice()
                    root.themes = stockList.concat(settingsAdapter.customThemes)
                }

                if (settingsAdapter.currentThemeIndex !== undefined) {
                    root.currentThemeIndex = Math.min(settingsAdapter.currentThemeIndex, root.themes.length - 1)
                }

                if (root.enableIris) {
                    root.applyIrisColors()
                } else {
                    root.applyTheme(root.currentThemeIndex)
                }
            } catch (e) {
                console.error("Failed to apply loaded settings:", e)
            }

            root.normalizeMonitorPositions()
            root.isLoaded = true
            root.resetDraftMonitorConfigs()
            root.syncHyprlandBorders()
            root.syncScreenFrame()

            if (root.pixelShaderEnabled || root.nightModeEnabled) {
                root.updateShader()
            }

            if (root.weather && root.locationQuery.trim().length > 0) {
                root.weather.fetchWeather(true)
            }

            root.refreshActiveWallpapers()
        }

        // preload (default true) loads this automatically on startup - no manual
        // "running = true" trigger needed. onLoadFailed covers a fresh install with
        // no settings.json yet (settingsAdapter properties simply stay undefined, so
        // the generic copy loop above is a no-op and root keeps its compiled-in
        // defaults, same as before).
        onLoaded: applyLoadedSettings()
        onLoadFailed: (error) => applyLoadedSettings()
    }

    function saveSettings() {
        if (!isLoaded) return
        saveTimer.restart()
    }

    property Timer saveTimer: Timer {
        interval: 400
        repeat: false
        onTriggered: {
            root.persistedKeys.forEach(p => { settingsAdapter[p] = root[p] })

            // color-typed properties need an explicit string form to serialize sanely
            settingsAdapter.customBgBase = root.customBgBase.toString()
            settingsAdapter.customBgPanel = root.customBgPanel.toString()
            settingsAdapter.customAccent = root.customAccent.toString()

            settingsAdapter.keybinds = root.keybinds
            settingsAdapter.customThemes = root.themes.filter(function(t) { return t.isCustom === true })
            settingsAdapter.currentThemeIndex = root.currentThemeIndex

            settingsFileImpl.writeAdapter()
        }
    }

    readonly property alias fontMicro: root.appearance.fontMicro
    readonly property alias fontCaption: root.appearance.fontCaption
    readonly property alias fontBody: root.appearance.fontBody
    readonly property alias fontSubhead: root.appearance.fontSubhead
    readonly property alias fontTitle: root.appearance.fontTitle
    readonly property alias fontDisplay: root.appearance.fontDisplay
    function size(preset) { return appearance.size(preset) }

    property alias bgBase: root.appearance.bgBase
    property alias bgPanel: root.appearance.bgPanel
    property alias accent: root.appearance.accent
    property alias textMain: root.appearance.textMain
    property alias textMuted: root.appearance.textMuted
    readonly property alias barHeight: root.appearance.barHeight
    readonly property alias barMargin: root.appearance.barMargin
    readonly property alias stockThemes: root.appearance.stockThemes
    property alias themes: root.appearance.themes
    function addCustomTheme(themeObj) { appearance.addCustomTheme(themeObj) }
    function removeCustomTheme(index) { appearance.removeCustomTheme(index) }
    function applyTheme(index) { appearance.applyTheme(index) }
    function setTheme(index) { appearance.setTheme(index) }

    Component.onCompleted: {
        if (!enableIris) applyTheme(currentThemeIndex)
    }
}