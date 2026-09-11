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

    // Fired once per incoming notification (not per history entry - those
    // can differ if recording is ever batched) so reactive UI, like the
    // Mascot's bounce, can hook a single event instead of diffing entries.
    signal notificationArrived()

    // --- WALLPAPER (extracted to services/WallpaperConfig.qml) ---
    property WallpaperConfig wallpaper: WallpaperConfig { configRef: root }
    property alias wallhavenUsername: root.wallpaper.wallhavenUsername
    property alias wallhavenApiKey: root.wallpaper.wallhavenApiKey
    property alias wallhavenSyncing: root.wallpaper.wallhavenSyncing
    property alias wallhavenSyncProgress: root.wallpaper.wallhavenSyncProgress
    property alias wallhavenSyncStatus: root.wallpaper.wallhavenSyncStatus
    function startWallhavenSync() { root.wallpaper.startWallhavenSync() }
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
    property alias wallpaperColorMap: root.wallpaper.wallpaperColorMap
    property alias colorFilter: root.wallpaper.colorFilter
    property alias typeFilter: root.wallpaper.typeFilter
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

    // Wi-Fi and Bluetooth state, owned once and shared by the Control Center
    // cards and the Settings pages. Before these existed each of those four
    // views carried its own complete nmcli/bluetoothctl implementation - see
    // the header comments in both services for what that cost.
    property NetworkService network: NetworkService { configRef: root }
    property BluetoothService bluetooth: BluetoothService { configRef: root }

    // Time-to-empty/full, health and charge thresholds - see BatteryService.qml.
    property BatteryService battery: BatteryService { configRef: root }

    // Auto-applies a saved profile when the set of connected displays changes
    // (dock/undock). Built on the profile system below rather than duplicating
    // any display state - see DisplayProfileService.qml.
    property DisplayProfileService displayProfiles: DisplayProfileService { configRef: root }
    property alias displayProfileMap: root.displayProfiles.displayProfileMap
    property alias displayAutoSwitch: root.displayProfiles.autoSwitchEnabled
    function getAppIcon(iconName) { return iconIndexService.getAppIcon(iconName) }

    property bool showTaskOverflow: false

    // Most-recently-picked characters from the launcher's emoji/glyph mode,
    // so the picker opens on what you actually use.
    property var emojiRecents: []

    // Text the launcher should open with, used by the `launcherosd emoji` IPC
    // verb to land directly in a mode. Transient - deliberately not a
    // persistedKey, since a prefill is a one-shot, not a preference.
    property string launcherPrefill: ""

    // --- SCREENSHOT (extracted to services/ScreenshotService.qml) ---
    property ScreenshotService screenshotService: ScreenshotService {}
    function captureScreenshot() { screenshotService.capture() }

    // --- CAMERA / MIRROR (extracted to services/MirrorConfig.qml) ---
    property MirrorConfig mirror: MirrorConfig { configRef: root }
    property alias showMirror: root.mirror.showMirror
    property alias mirrorShowPanel: root.mirror.mirrorShowPanel
    property alias mirrorMirrored: root.mirror.mirrorMirrored
    property alias mirrorKeepAspect: root.mirror.mirrorKeepAspect
    property alias mirrorLoading: root.mirror.mirrorLoading
    property alias mirrorError: root.mirror.mirrorError
    property alias mirrorPositions: root.mirror.mirrorPositions
    property alias mirrorLastScreen: root.mirror.mirrorLastScreen
    property alias mirrorWidth: root.mirror.mirrorWidth
    property alias mirrorHeight: root.mirror.mirrorHeight
    readonly property alias mirrorCaptureSession: root.mirror.mirrorCaptureSession
    readonly property alias mirrorMediaDevices: root.mirror.mirrorMediaDevices
    function getMirrorPosition(screenName, defaultX, defaultY) { return mirror.getMirrorPosition(screenName, defaultX, defaultY) }
    function saveMirrorPosition(screenName, x, y) { mirror.saveMirrorPosition(screenName, x, y) }
    function saveMirrorSize(width, height) { mirror.saveMirrorSize(width, height) }

    // --- INITIALIZATION GUARD ---
    property bool isLoaded: false

    // UI Toggle States
    property bool showSettings: false
    property bool showCalendar: false
    property bool showWallpaper: false
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

    // --- MUTUALLY EXCLUSIVE PANEL ARBITRATION ---
    // Every drawer view maps to exactly one of these flags. This table is the
    // single source of truth for "what counts as a panel": UnifiedSurface's
    // closeOthers() and shell.qml's IpcHandlers both route through closePanels()
    // below instead of each re-listing the flags by hand.
    //
    // They used to. The ten IpcHandlers each carried their own hand-maintained
    // close list, and every one of them had drifted - none cleared showAudio,
    // showNetwork or showTaskOverflow. That was a live bug, not just repetition:
    // opening the Audio panel from the bar and then hitting the launcher keybind
    // left showAudio stuck true (the launcher just outranks it in
    // updateActiveView), so closing the launcher popped the Audio panel open
    // instead of closing the drawer. Adding an eleventh panel meant ten correct
    // edits; now it means one line here.
    // Keyed by the view name UnifiedSurface.activeView uses, so callers speak
    // one vocabulary ("power") rather than mixing view names and flag names.
    readonly property var panelFlagByView: ({
        "workspacePreview": "showWorkspacePreview",
        "power":            "showPower",
        "wallpaper":        "showWallpaper",
        "launcherOsd":      "showLauncherOsd",
        "calendar":         "showCalendar",
        "audio":            "showAudio",
        "network":          "showNetwork",
        "battery":          "showBattery",
        "clipboard":        "showClipboard",
        "screenRecorder":   "showScreenRecorder",
        "controlCenter":    "showControlCenter",
        "settings":         "showSettings",
        "taskOverflow":     "showTaskOverflow"
    })

    // The two OSDs deliberately sit outside the panel table: they're transient
    // takeovers layered over whatever panel is open, and closeOthers() has
    // always preserved the underlying panel state when one of them fires.
    readonly property var osdFlagByView: ({
        "osd":      "showOSD",
        "notifOsd": "showNotificationOsd"
    })

    // Clears every panel flag except the one backing `exceptView`. Pass "none"
    // or "" to close everything. An OSD view only clears the other OSD.
    function closePanels(exceptView) {
        let keep = exceptView || ""
        let isOsd = root.osdFlagByView.hasOwnProperty(keep)

        Object.keys(root.osdFlagByView).forEach(v => {
            if (v !== keep) root[root.osdFlagByView[v]] = false
        })
        if (isOsd) return

        Object.keys(root.panelFlagByView).forEach(v => {
            if (v === keep) return
            root[root.panelFlagByView[v]] = false
        })
    }

    // Opens `view` exclusively, or closes it if it's already the open one.
    function togglePanel(view) {
        let flag = root.panelFlagByView[view]
        if (!flag) return
        let wasOpen = root[flag] === true
        root.closePanels(wasOpen ? "" : view)
        root[flag] = !wasOpen
    }

    // Closes whatever drawer panel is currently open. Used by the Escape
    // handler in shell.qml and by the `hide` IPC verbs.
    function closeAllPanels() { root.closePanels("") }

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
    function recordNotification(notif) { notificationHistoryService.record(notif); notificationArrived() }
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

    // Saved ControlCenter card arrangement: { order: [cardId,...], lanes: {cardId: 0|1} }.
    // order is the top-to-bottom stacking sequence, lanes says which half
    // (left/right) each half-width card stacks in - full-width cards ignore
    // lanes. Left empty until the user actually drags a card - ControlCenter.qml
    // falls back to its own compiled-in default arrangement while this is {}.
    property var ccCardArrangement: ({})

    // Saved Calendar swap state: { forecastOnBottom, bigCardOnLeft, notesOnTop }
    // (all bool). Left empty until the user actually drags something -
    // Calendar.qml falls back to the compiled-in default (all false) while
    // this is {}.
    property var calendarArrangement: ({})

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

    property alias showAppDock: root.desktopWidgets.showAppDock
    property alias appDockOrientation: root.desktopWidgets.appDockOrientation
    property alias appDockScale: root.desktopWidgets.appDockScale
    property alias appDockShowBorder: root.desktopWidgets.appDockShowBorder
    property alias appDockShowBackground: root.desktopWidgets.appDockShowBackground
    property alias appDockShowGlow: root.desktopWidgets.appDockShowGlow
    property alias appDockPositions: root.desktopWidgets.appDockPositions
    property alias appDockScales: root.desktopWidgets.appDockScales
    property alias enabledAppDockScreens: root.desktopWidgets.enabledAppDockScreens
    function getAppDockPosition(screenName, defaultX, defaultY) { return desktopWidgets.getAppDockPosition(screenName, defaultX, defaultY) }
    function saveAppDockPosition(screenName, x, y) { desktopWidgets.saveAppDockPosition(screenName, x, y) }
    function getAppDockScale(screenName) { return desktopWidgets.getAppDockScale(screenName) }
    function saveAppDockScale(screenName, scale) { desktopWidgets.saveAppDockScale(screenName, scale) }
    function isAppDockEnabledForScreen(screenName) { return desktopWidgets.isAppDockEnabledForScreen(screenName) }
    function toggleAppDockScreen(screenName) { desktopWidgets.toggleAppDockScreen(screenName) }

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

    property alias bgSlideshowTimer: root.wallpaperService.bgSlideshowTimer
    property alias wallpaperApplyRunner: root.wallpaperService.wallpaperApplyRunner

    // --- GLOBAL WEATHER SERVICE ---
    property WeatherService weather: WeatherService {
        id: globalWeather
        zipcode: root.locationQuery
    }

    // Polls whenever Config is loaded - an empty locationQuery is the valid
    // "Auto IP Geolocation" mode, not "unconfigured", so it shouldn't block
    // the periodic refresh either.
    property Timer weatherTimer: Timer {
        interval: 900000
        running: root.isLoaded
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
    property alias mascotAudioThrob: root.desktopExtras.mascotAudioThrob
    property alias mascotPhrases: root.desktopExtras.mascotPhrases
    property alias mascotPositions: root.desktopExtras.mascotPositions
    property alias mascotLastScreen: root.desktopExtras.mascotLastScreen
    property alias fetchOnlineQuotes: root.desktopExtras.fetchOnlineQuotes
    property alias quoteSource: root.desktopExtras.quoteSource
    property alias rssFeedUrl: root.desktopExtras.rssFeedUrl
    function addMascotPhrase(phrase) { desktopExtras.addMascotPhrase(phrase) }
    function removeMascotPhrase(index) { desktopExtras.removeMascotPhrase(index) }
    function getMascotPosition(screenName, defaultX, defaultY) { return desktopExtras.getMascotPosition(screenName, defaultX, defaultY) }
    function saveMascotPosition(screenName, x, y) { desktopExtras.saveMascotPosition(screenName, x, y) }
    property alias showAssistant: root.desktopExtras.showAssistant
    property alias assistantBackend: root.desktopExtras.assistantBackend
    property alias assistantModel: root.desktopExtras.assistantModel
    property alias assistantOllamaModel: root.desktopExtras.assistantOllamaModel
    property alias assistantBadgePath: root.desktopExtras.assistantBadgePath
    property alias assistantCustomBadges: root.desktopExtras.assistantCustomBadges
    function addCustomBadge(path) { desktopExtras.addCustomBadge(path) }
    function removeCustomBadge(path) { desktopExtras.removeCustomBadge(path) }
    property alias assistantTimeoutSeconds: root.desktopExtras.assistantTimeoutSeconds
    property alias assistantFontScale: root.desktopExtras.assistantFontScale
    property alias assistantWidth: root.desktopExtras.assistantWidth
    property alias assistantHeight: root.desktopExtras.assistantHeight
    property alias assistantPositions: root.desktopExtras.assistantPositions
    property alias assistantLastScreen: root.desktopExtras.assistantLastScreen
    function saveAssistantSize(width, height) { desktopExtras.saveAssistantSize(width, height) }
    function getAssistantPosition(screenName, defaultX, defaultY) { return desktopExtras.getAssistantPosition(screenName, defaultX, defaultY) }
    function saveAssistantPosition(screenName, x, y) { desktopExtras.saveAssistantPosition(screenName, x, y) }
    property alias assistantMessages: root.desktopExtras.assistantMessages
    function appendAssistantMessage(role, text) { desktopExtras.appendAssistantMessage(role, text) }
    function clearAssistantMessages() { desktopExtras.clearAssistantMessages() }
    property alias showDesktopMediaCard: root.desktopExtras.showDesktopMediaCard
    property alias mediaCardWidth: root.desktopExtras.mediaCardWidth
    property alias mediaCardHeight: root.desktopExtras.mediaCardHeight
    property alias mediaCardPositions: root.desktopExtras.mediaCardPositions
    property alias mediaCardLastScreen: root.desktopExtras.mediaCardLastScreen
    function saveMediaCardSize(width, height) { desktopExtras.saveMediaCardSize(width, height) }
    function getMediaCardPosition(screenName, defaultX, defaultY) { return desktopExtras.getMediaCardPosition(screenName, defaultX, defaultY) }
    function saveMediaCardPosition(screenName, x, y) { desktopExtras.saveMediaCardPosition(screenName, x, y) }
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
    property alias irisIntensity: root.appearance.irisIntensity
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
    property alias snapDesktopWidgets: root.appearance.snapDesktopWidgets
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
            // Empty is the valid "Auto IP Geolocation" mode, not
            // "unconfigured" - clearing back to it should still save and
            // (via WeatherService's own onZipcodeChanged) still re-fetch.
            if (root.isLoaded) {
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
        command: ["sh", "-c", "hyprctl monitors -j"]
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
        const safeFallback = { width: defaultW, height: defaultH, refreshRate: 60.0, x: 0, y: 0, scale: "auto", transform: 0, cm: "auto", bitdepth: 8, sdrBrightness: 1.2, sdrSaturation: 0.98 }

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

                // Color management / HDR: cm and bitdepth only need stating when
                // off their defaults; sdrbrightness/sdrsaturation only mean
                // anything to Hyprland once cm is actually in an HDR mode.
                let cmVal = m.cm || "auto"
                let cmLine = (cmVal !== "auto") ? ',\n    cm = "' + cmVal + '"' : ''
                let bitdepthLine = (m.bitdepth === 10) ? ',\n    bitdepth = 10' : ''
                let isHdrMode = cmVal === "hdr" || cmVal === "hdredid"
                let sdrLine = isHdrMode
                    ? ',\n    sdrbrightness = ' + (m.sdrBrightness || 1.2).toFixed(2) + ',\n    sdrsaturation = ' + (m.sdrSaturation || 0.98).toFixed(2)
                    : ''

                let luaBlock = 'hl.monitor({\n' +
                    '    output = "' + k + '",\n' +
                    '    mode = "' + m.width + 'x' + m.height + '@' + (m.refreshRate || 60.0) + '",\n' +
                    '    position = "' + m.x + 'x' + m.y + '",\n' +
                    '    scale = ' + scaleVal + transformLine + cmLine + bitdepthLine + sdrLine + '\n' +
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

        writer.command = ["sh", "-c", cmd]
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
        let bindKeys = ["wallpaper", "launcherosd", "settings", "workspaceoverview", "clipboard", "lockscreen", "shader"]
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
            // Autostart hooks for session daemons Synoptik depends on
            // (idle handling, wallpaper daemon, clipboard history).
            // Regenerated here for the same reason as the Media
            // Card window_rule above - this function rewrites hypr_style.lua
            // from scratch on every sync, so anything not written here gets
            // wiped on the next appearance/keybind/theme change.
            //
            // hyprpolkitagent used to be started here. The shell registers as
            // the session's polkit agent itself now (components/widgets/
            // PolkitDialog.qml), so starting a second one just means whichever
            // registers last wins - and every privilege prompt in the session
            // arriving in a window Synoptik doesn't style was the one visual
            // seam left in it.
            "hl.on(\"hyprland.start\", function ()\n" +
            "    hl.exec_cmd(\"qs -c Synoptik\")\n" +
            "    hl.exec_cmd(\"hypridle\")\n" +
            "    hl.exec_cmd(\"awww-daemon\")\n" +
            "    hl.exec_cmd(\"wl-paste --watch cliphist store\")\n" +
            "end)\n\n" +
            "hl.layer_rule({\n" +
            "    name = \"synoptik-shell\",\n" +
            "    match = { namespace = \"^synoptik-shell.*\" },\n" +
            "    blur = " + (enableBlur ? "true" : "false") + ",\n" +
            "    xray = " + (enableXray ? "true" : "false") + ",\n" +
            "    ignore_alpha = 0.6\n" +
            "})\n\n" +
            // The detached Media Card widget is a real floating (xdg-toplevel)
            // window, not a layer-shell panel, so it needs its own window
            // rule to float instead of tile. Regenerated here (not just
            // appended once by install.sh) since this whole function
            // rewrites hypr_style.lua from scratch on every appearance/
            // keybind/theme change - anything not written here gets wiped
            // on the next sync.
            "hl.window_rule({\n" +
            "    name  = \"float-synoptik-media-card\",\n" +
            "    match = { title = \"^Synoptik Media Card\\$\" },\n" +
            "    float = true,\n" +
            "})\n\n" +
            bindsLua.replace(/\\/g, '\\\\').replace(/'/g, "\\'") + "\n'''\n\n" +
            "if existing_monitors:\n" +
            "    new_config += '\\n' + existing_monitors + '\\n'\n\n" +
            "with open(path, 'w') as f:\n" +
            "    f.write(new_config)\n"

        let cmd = "python3 -c \"" + pyScript.replace(/"/g, '\\"') + "\" && hyprctl reload"

        writer.command = ["sh", "-c", cmd]
        writer.running = true
    }


    // Persistence
    // Quickshell.shellDir comes back as a file:// URL, so every consumer has to
    // strip that prefix before handing it to Process/FileView. That stripping was
    // duplicated in three files and skipped entirely in two more (which hardcoded
    // "$HOME/.config/quickshell/Synoptik" and so broke under XDG_CONFIG_HOME or a
    // renamed checkout) - do it once here and let everything else use shellDir.
    readonly property string shellDir: Quickshell.shellDir.toString().replace(/^file:\/\//, "")
    readonly property string scriptsDir: root.shellDir + "/scripts"

    readonly property string settingsPath: root.shellDir + "/settings.json"

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
        "mascotPath", "mascotPhrases", "mascotPositions", "mascotLastScreen", "mascotAudioThrob", "fetchOnlineQuotes", "quoteSource",
        "showDesktopMediaCard", "mediaCardWidth", "mediaCardHeight", "mediaCardPositions", "mediaCardLastScreen", "barFrameStyle",
        "barPosition", "autoHideBar", "showScreenFrame", "sysFont", "nativeFontRendering",
        "fontScaleIndex", "locationQuery", "enabledBarScreens", "useCustomColors", "customBgBase",
        "customBgPanel", "customAccent", "animateGradient", "shellOpacity", "enableBlur", "enableXray",
        "enableIris", "irisIntensity", "showWatermarks", "bounceWatermarks", "windowStyle", "playWindowSounds",
        "playNotificationSounds", "windowSoundPath", "notificationSoundPath", "windowSoundVolume",
        "enableHoverPeek", "snapDesktopWidgets", "nightModeEnabled", "nightModeAuto", "nightModeScheduleStart",
        "nightModeScheduleEnd", "pixelShaderEnabled", "pixelShaderMode", "pixelShaderSize",
        "pixelShaderLevels", "pixelShaderPalette", "pixelShaderDither", "pixelShaderGrid",
        "pixelShaderBoost", "showMirror", "mirrorShowPanel", "mirrorMirrored", "mirrorKeepAspect",
        "mirrorPositions", "mirrorLastScreen", "mirrorWidth", "mirrorHeight", "leftCardOrder", "rightCardOrder",
        "leftCardCollapsed", "rightCardCollapsed", "pinnedIcons", "iconOverrides", "surfaceRadius",
        "borderThickness", "cardMargin", "ccCardArrangement", "calendarArrangement", "showDesktopClock", "clockStyle", "clockScale",
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
        "workspaceShowSpecial", "workspaceContainerStyle", "wallhavenUsername", "wallhavenApiKey",
        "showAssistant", "assistantBackend", "assistantModel", "assistantOllamaModel", "assistantBadgePath", "assistantCustomBadges", "assistantTimeoutSeconds", "assistantFontScale", "assistantWidth", "assistantHeight",
        "assistantPositions", "assistantLastScreen", "assistantMessages",
        "showAppDock", "appDockOrientation", "appDockScale", "appDockShowBorder", "appDockShowBackground",
        "appDockShowGlow", "appDockPositions", "appDockScales", "enabledAppDockScreens",
        "displayProfileMap", "displayAutoSwitch", "emojiRecents"
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

        // Write to a temp file and rename over the original, so a crash or a
        // `killall qs` mid-write can't leave a half-written settings.json
        // behind. Stated explicitly rather than relying on the default: this
        // file is ~190 keys of irreplaceable user preference, and the Reload
        // button in Settings deliberately SIGKILLs the shell moments after a
        // save can have been queued.
        atomicWrites: true

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
            property var mascotAudioThrob
            property var mascotPhrases
            property var mascotPositions
            property var mascotLastScreen
            property var showDesktopMediaCard
            property var mediaCardWidth
            property var mediaCardHeight
            property var mediaCardPositions
            property var mediaCardLastScreen
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
            property var irisIntensity
            property var showWatermarks
            property var bounceWatermarks
            property var windowStyle
            property var playWindowSounds
            property var playNotificationSounds
            property var windowSoundPath
            property var notificationSoundPath
            property var windowSoundVolume
            property var enableHoverPeek
            property var snapDesktopWidgets
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
            property var mirrorPositions
            property var mirrorLastScreen
            property var mirrorWidth
            property var mirrorHeight
            property var leftCardOrder
            property var rightCardOrder
            property var leftCardCollapsed
            property var rightCardCollapsed
            property var pinnedIcons
            property var iconOverrides
            property var surfaceRadius
            property var borderThickness
            property var cardMargin
            property var ccCardArrangement
            property var calendarArrangement
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
            property var showAssistant
            property var assistantBackend
            property var assistantModel
            property var assistantOllamaModel
            property var assistantBadgePath
            property var assistantCustomBadges
            property var assistantTimeoutSeconds
            property var assistantFontScale
            property var assistantWidth
            property var assistantHeight
            property var assistantPositions
            property var assistantLastScreen
            property var assistantMessages
            property var showAppDock
            property var appDockOrientation
            property var appDockScale
            property var appDockShowBorder
            property var appDockShowBackground
            property var appDockShowGlow
            property var appDockPositions
            property var appDockScales
            property var enabledAppDockScreens
            property var displayProfileMap
            property var displayAutoSwitch
            property var emojiRecents
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
                        let cmd = item.cmd || ""

                        // The lockscreen IPC handler dropped unlock()/toggle() - they
                        // let anything running as this user (or this very keybind,
                        // fired while the lock surface was up) skip PAM entirely and
                        // unlock with no password. Only lock() remains, so a
                        // settings.json saved before that fix still points this bind
                        // at a function that no longer exists and would silently do
                        // nothing. Rewritten here (not just in the shipped default)
                        // so existing installs self-heal instead of losing the bind.
                        if (/ipc call lockscreen (unlock|toggle)\b/.test(cmd)) {
                            cmd = cmd.replace(/ipc call lockscreen (unlock|toggle)\b/, "ipc call lockscreen lock")
                        }

                        // AppLauncher merged into LauncherOSD and its bar icon/
                        // keybind were retired outright (LauncherOSD is reachable
                        // from the search icon instead) - drop a leftover
                        // "launcher" bind from a settings.json saved before that
                        // rather than resurrect it pointing at anything.
                        if (k === "launcher") return

                        cleaned[k] = {
                            mod: (item.mod || "SUPER").replace(/mainMod/g, "SUPER").replace(/\.\./g, "").replace(/["']/g, "").trim(),
                            key: item.key || "",
                            cmd: cmd
                        }
                    })
                    root.keybinds = cleaned
                }

                let defaultLeft = ["power", "recorder", "screenshot", "wallpaper", "settings", "audio", "batt", "network", "clipboard"]
                let currentLeft = Array.isArray(root.leftCardOrder) ? root.leftCardOrder.slice() : []
                defaultLeft.forEach(mod => {
                    if (!currentLeft.includes(mod)) currentLeft.push(mod)
                })
                root.leftCardOrder = currentLeft

                // JsonAdapter re-serializes every declared property, so once this
                // shim has run the file carries `"isFloatingBar": null` forever -
                // `!= null` (loose, catches undefined too) keeps that written-back
                // null from reading as a real legacy value.
                if (settingsAdapter.isFloatingBar != null && settingsAdapter.barFrameStyle === undefined) {
                    root.barFrameStyle = settingsAdapter.isFloatingBar ? "floating" : "edge"
                }

                // assistantModel and assistantOllamaModel used to be the
                // same field - a saved settings.json from before that split
                // has whatever was last selected sitting in assistantModel
                // alone, regardless of which backend happens to be active
                // *now* (switching backends never cleared it, so it can
                // easily be a stale Ollama model name left behind after
                // switching back to Claude/Codex/Gemini - confirmed exactly
                // this in practice: assistantBackend "claude" saved
                // alongside assistantModel "llama3.2:latest", which
                // `claude -p --model llama3.2:latest` naturally rejects).
                // Checking the current backend at migration time is exactly
                // the wrong test - the widget's Ollama model switcher was
                // always the far more common way this field got a value in
                // the first place, so it's moved (not copied) unconditionally.
                // Falsy rather than strictly undefined, since an earlier cut
                // of this migration already wrote an explicit "" once,
                // which would otherwise permanently defeat an undefined
                // check on every future load.
                if (!settingsAdapter.assistantOllamaModel && settingsAdapter.assistantModel) {
                    root.assistantOllamaModel = settingsAdapter.assistantModel
                    root.assistantModel = ""
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

            // locationQuery empty is a valid "Auto IP Geolocation" mode
            // (WeatherService.getTargetUrl falls back to plain wttr.in),
            // not "unconfigured" - don't skip the startup fetch for it.
            if (root.weather) {
                root.weather.fetchWeather(true)
            }

            root.refreshActiveWallpapers()
        }

        // preload (default true) loads this automatically on startup - no manual
        // "running = true" trigger needed. onLoadFailed covers a fresh install with
        // no settings.json yet (settingsAdapter properties simply stay undefined, so
        // the generic copy loop above is a no-op and root keeps its compiled-in
        // defaults, same as before).
        // Fired once the settings write has actually landed on disk. A profile
        // snapshot is just a copy of that file, so waiting for this signal is
        // what keeps saveProfile() from racing the write it just requested.
        // Fast path: the settings write landed, so the file on disk is current
        // and the profile snapshot can be copied from it immediately.
        onSaved: root.commitProfileSave()
        onSaveFailed: root.pendingProfileSave = ""

        onLoaded: {
            applyLoadedSettings()
            // Snapshot only after a parse that actually succeeded, so the .bak
            // is always a known-good file rather than whatever was last written.
            root.backupSettings()
        }

        // A load failure used to fall straight through to applyLoadedSettings(),
        // which silently left every one of ~190 keys at its compiled-in default -
        // indistinguishable, from the user's side, from the shell having thrown
        // their entire configuration away with no message. Now a corrupt file is
        // rolled back to the last known-good snapshot and the user is told.
        onLoadFailed: (error) => {
            if (root.settingsRecoveryAttempted) {
                applyLoadedSettings()
                return
            }
            root.settingsRecoveryAttempted = true
            settingsRecoveryProc.running = true
        }
    }

    // Guards against a recover -> reload -> fail -> recover loop when both the
    // settings file and its backup are unreadable (or neither exists, which is
    // just a normal first run).
    property bool settingsRecoveryAttempted: false

    // --- CONFIGURATION PROFILES ---
    // Named snapshots of the whole settings file. A profile is literally a copy
    // of settings.json, so saving and loading reuse the exact same serialize and
    // apply paths the shell already uses at startup - there is no second list of
    // "what belongs in a profile" to drift out of sync with persistedKeys, and a
    // profile stays a plain JSON file the user can read, diff, or share.
    //
    // This is the desktop-vs-laptop split the README describes as the whole
    // reason Synoptik exists (bar on the left on one machine, a collapsed
    // auto-hiding pill on the other) - previously that meant reconfiguring by
    // hand every time.
    readonly property string profilesDir: root.shellDir + "/profiles"
    property var profileNames: []
    property string pendingProfileSave: ""

    // The active profile name is deliberately NOT a persistedKey: loading a
    // profile overwrites settings.json wholesale, so a name stored in there
    // would be clobbered by whatever the snapshot happened to contain. It gets
    // its own one-line marker file next to the profiles instead.
    property string activeProfile: ""
    readonly property string activeProfilePath: root.profilesDir + "/.active"

    onActiveProfileChanged: {
        if (!root.isLoaded) return
        activeProfileWriteProc.command = ["sh", "-c",
            "mkdir -p '" + root.profilesDir + "' && printf '%s' '"
            + root.sanitizeProfileName(root.activeProfile) + "' > '" + root.activeProfilePath + "'"]
        activeProfileWriteProc.running = true
    }

    property Process activeProfileWriteProc: Process { id: activeProfileWriteProc; running: false }

    property Process activeProfileReadProc: Process {
        id: activeProfileReadProc
        running: false
        command: ["sh", "-c", "cat '" + root.activeProfilePath + "' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let name = root.sanitizeProfileName(this.text.trim())
                // Only adopt it if that profile still exists on disk.
                if (name !== "" && root.profileNames.indexOf(name) >= 0) root.activeProfile = name
            }
        }
    }

    // Profile names become filenames, so anything that could escape profilesDir
    // or confuse the shell quoting is stripped rather than escaped.
    function sanitizeProfileName(name) {
        let clean = (name || "").replace(/[^A-Za-z0-9 _-]/g, "").trim().slice(0, 48)
        return clean
    }

    function saveProfile(name) {
        let clean = root.sanitizeProfileName(name)
        if (clean === "") return
        root.pendingProfileSave = clean
        // Force the write now rather than waiting out the 400ms debounce - the
        // snapshot has to reflect what the user is looking at right now.
        saveTimer.stop()
        root.writeSettingsNow()
        // ...but writeAdapter() is a no-op when the serialized data is byte-identical
        // to what's already on disk, and in that case FileView never emits saved().
        // That is the *normal* case here: clicking "Save profile" changes no setting,
        // so waiting on onSaved alone meant the snapshot was silently never written.
        // If saved() doesn't arrive, the file was already current and we copy anyway.
        profileSaveFallback.restart()
    }

    property Timer profileSaveFallback: Timer {
        id: profileSaveFallback
        interval: 250
        repeat: false
        onTriggered: root.commitProfileSave()
    }

    // Copies the (now current) settings.json to the profile. Guarded on
    // pendingProfileSave so it runs exactly once whether it was reached via
    // onSaved or via the fallback above, never twice.
    function commitProfileSave() {
        if (root.pendingProfileSave === "") return
        let name = root.pendingProfileSave
        root.pendingProfileSave = ""
        profileSaveFallback.stop()
        profileWriteProc.savedProfile = name
        profileWriteProc.command = ["sh", "-c",
            "mkdir -p '" + root.profilesDir + "' && cp -f '" + root.settingsPath
            + "' '" + root.profilesDir + "/" + name + ".json'"]
        profileWriteProc.running = false
        profileWriteProc.running = true
    }

    function loadProfile(name) {
        let clean = root.sanitizeProfileName(name)
        if (clean === "") return
        profileLoadProc.targetProfile = clean
        profileLoadProc.command = ["sh", "-c",
            "src='" + root.profilesDir + "/" + clean + ".json'; "
            + "[ -s \"$src\" ] || exit 1; cp -f \"$src\" '" + root.settingsPath + "'"]
        profileLoadProc.running = true
    }

    function deleteProfile(name) {
        let clean = root.sanitizeProfileName(name)
        if (clean === "") return
        profileDeleteProc.command = ["sh", "-c",
            "rm -f '" + root.profilesDir + "/" + clean + ".json'"]
        profileDeleteProc.running = true
        if (root.activeProfile === clean) root.activeProfile = ""
    }

    function refreshProfiles() {
        profileListProc.running = false
        profileListProc.running = true
    }

    property Process profileListProc: Process {
        id: profileListProc
        running: false
        command: ["sh", "-c",
            "ls -1 '" + root.profilesDir + "' 2>/dev/null | sed -n 's/\\.json$//p' | sort"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim()
                root.profileNames = out === "" ? [] : out.split("\n")
                // Resolved after the list so the marker can be validated against it.
                activeProfileReadProc.running = true
            }
        }
    }

    property Process profileWriteProc: Process {
        id: profileWriteProc
        running: false
        property string savedProfile: ""
        onExited: (exitCode) => {
            if (exitCode !== 0) return
            // Saving a snapshot of the current setup makes that profile the one
            // you're now on, so the card reflects it without a redundant Load.
            root.activeProfile = profileWriteProc.savedProfile
            root.refreshProfiles()
        }
    }

    property Process profileDeleteProc: Process {
        id: profileDeleteProc
        running: false
        onExited: root.refreshProfiles()
    }

    // Copying the profile over settings.json and reloading runs it through the
    // ordinary startup path (applyLoadedSettings -> theme/border/shader sync),
    // so a profile switch lands exactly like a fresh launch would.
    property Process profileLoadProc: Process {
        id: profileLoadProc
        running: false
        property string targetProfile: ""
        onExited: (exitCode) => {
            if (exitCode !== 0) return
            root.activeProfile = profileLoadProc.targetProfile
            root.settingsRecoveryAttempted = false
            settingsFileImpl.reload()
        }
    }

    function backupSettings() {
        settingsBackupProc.running = false
        settingsBackupProc.running = true
    }

    // Only overwrites the .bak when the live file is non-empty, so an empty or
    // truncated settings.json can never clobber a good snapshot.
    property Process settingsBackupProc: Process {
        id: settingsBackupProc
        running: false
        command: ["sh", "-c",
            "f=" + root.settingsPath + "; [ -s \"$f\" ] && cp -f \"$f\" \"$f.bak\" || true"]
    }

    // Exits 0 only when a backup was actually restored, so the reload below
    // (and the notification) fire only in the real recovery case.
    property Process settingsRecoveryProc: Process {
        id: settingsRecoveryProc
        running: false
        command: ["sh", "-c",
            "f=" + root.settingsPath + "; " +
            "if [ -s \"$f.bak\" ] && [ -s \"$f\" ]; then " +
            "  cp -f \"$f\" \"$f.corrupt\"; cp -f \"$f.bak\" \"$f\"; exit 0; " +
            "fi; exit 1"]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                Quickshell.execDetached(["notify-send", "-u", "critical", "Synoptik",
                    "settings.json was unreadable and has been restored from the last good backup. The unreadable copy was kept as settings.json.corrupt."])
                settingsFileImpl.reload()
            } else {
                // Nothing to restore - first run, or the backup is gone too.
                // applyLoadedSettings() is declared on the FileView itself, so
                // it has to be reached through its id from out here.
                settingsFileImpl.applyLoadedSettings()
            }
        }
    }

    function saveSettings() {
        if (!isLoaded) return
        saveTimer.restart()
    }

    // Writes immediately, skipping the debounce - call before anything that's
    // about to kill this process (a shell reload/restart), since the 400ms
    // debounce below would otherwise silently drop a save made just before
    // the kill signal arrives (e.g. dragging a desktop widget, then hitting
    // Settings' Reload button right after).
    function flushSettings() {
        if (!saveTimer.running) return
        saveTimer.stop()
        writeSettingsNow()
    }

    function writeSettingsNow() {
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

    property Timer saveTimer: Timer {
        interval: 400
        repeat: false
        onTriggered: root.writeSettingsNow()
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

    // persistedKeys and settingsAdapter's property list are two hand-maintained
    // parallel lists: adding a setting means declaring it on its service, aliasing
    // it here, adding a `property var` to the adapter AND adding the name to
    // persistedKeys. Miss the adapter line and the key silently stops persisting -
    // no error, no warning, the setting just quietly resets on every restart.
    //
    // This turns that silent failure into a loud one. It only reads (via `in`),
    // never assigns, so it can't perturb a load in progress. If the introspection
    // isn't supported at all it reports every key as missing, which is meaningless -
    // so that case is treated as "can't check" and stays quiet rather than crying
    // wolf on startup.
    function validatePersistedKeys() {
        let missing = []
        for (let i = 0; i < root.persistedKeys.length; i++) {
            let k = root.persistedKeys[i]
            if (!(k in settingsAdapter)) missing.push(k)
        }
        if (missing.length === 0 || missing.length === root.persistedKeys.length) return
        console.warn("Synoptik/Config: " + missing.length + " persisted key(s) have no matching "
            + "`property var` on settingsAdapter and will NOT be saved: " + missing.join(", "))
    }

    Component.onCompleted: {
        if (!enableIris) applyTheme(currentThemeIndex)
        validatePersistedKeys()
        refreshProfiles()
    }
}