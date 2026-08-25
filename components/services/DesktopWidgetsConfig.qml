import QtQuick

QtObject {
    property var configRef: null

    // --- DESKTOP CLOCK STATE & PERSISTENCE ---
    property bool showDesktopClock: true
    property string clockStyle: "digital"
    property real clockScale: 1.0
    property bool clockShowSeconds: false
    property bool clockUse12Hour: true
    property bool clockShowAmPm: true
    property bool clockShowBorder: true
    property bool clockShowBackground: true
    property bool clockShowGlow: true

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
        if (configRef) configRef.saveSettings()
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
        if (configRef) configRef.saveSettings()
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
        if (configRef) configRef.saveSettings()
    }

    onShowDesktopClockChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onClockStyleChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onClockScaleChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onClockShowSecondsChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onClockUse12HourChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onClockShowAmPmChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onClockShowBorderChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onClockShowBackgroundChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onClockShowGlowChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    // --- DESKTOP SYSTEM INFO STATE & PERSISTENCE ---
    property bool showDesktopSysInfo: true
    property real sysInfoScale: 1.0

    // OS & System
    property bool sysInfoShowHost: true
    property bool sysInfoShowOs: true
    property bool sysInfoShowKernel: true
    property bool sysInfoShowUptime: true
    property bool sysInfoShowPackages: true
    property bool sysInfoShowWm: true

    // Hardware
    property bool sysInfoShowBoard: true
    property bool sysInfoShowCpu: true
    property bool sysInfoShowCores: true
    property bool sysInfoShowLoad: true
    property bool sysInfoShowGpu: true

    // Network
    property bool sysInfoShowIp: true
    property bool sysInfoShowGateway: true
    property bool sysInfoShowDns: true

    // Gauges & Styling
    property bool sysInfoShowRam: true
    property bool sysInfoShowSwap: true
    property bool sysInfoShowDisk: true
    property bool sysInfoShowDiskHome: true
    property bool sysInfoShowBg: true
    property bool sysInfoShowGlow: true
    property int sysInfoRefreshInterval: 3000

    property var sysInfoPositions: ({})
    property var sysInfoScales: ({})
    property var enabledSysInfoScreens: []

    function getSysInfoPosition(screenName, defaultX, defaultY) {
        if (sysInfoPositions && sysInfoPositions[screenName]) {
            return sysInfoPositions[screenName]
        }
        return { x: defaultX, y: defaultY }
    }

    function saveSysInfoPosition(screenName, x, y) {
        let current = Object.assign({}, sysInfoPositions)
        current[screenName] = { x: x, y: y }
        sysInfoPositions = current
        if (configRef) configRef.saveSettings()
    }

    function getSysInfoScale(screenName) {
        if (sysInfoScales && sysInfoScales[screenName] !== undefined) {
            return sysInfoScales[screenName]
        }
        return 1.0
    }

    function saveSysInfoScale(screenName, scale) {
        let current = Object.assign({}, sysInfoScales)
        current[screenName] = scale
        sysInfoScales = current
        if (configRef) configRef.saveSettings()
    }

    function isSysInfoEnabledForScreen(screenName) {
        if (!enabledSysInfoScreens || enabledSysInfoScreens.length === 0) return true
        return enabledSysInfoScreens.includes(screenName)
    }

    function toggleSysInfoScreen(screenName) {
        let current = (enabledSysInfoScreens || []).slice()
        let idx = current.indexOf(screenName)
        if (idx !== -1) {
            current.splice(idx, 1)
        } else {
            current.push(screenName)
        }
        enabledSysInfoScreens = current
        if (configRef) configRef.saveSettings()
    }

    onShowDesktopSysInfoChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoScaleChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowHostChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowOsChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowKernelChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowUptimeChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowPackagesChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowWmChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowBoardChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowCpuChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowCoresChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowLoadChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowGpuChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowIpChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowGatewayChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowDnsChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowRamChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowSwapChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowDiskChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowDiskHomeChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowBgChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoShowGlowChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSysInfoRefreshIntervalChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    // --- CAVA AUDIO VISUALIZER STATE & PERSISTENCE ---
    property bool showDesktopCava: false
    property string cavaStyle: "bars"          // "bars" | "mirrored" | "wave" | "radial"
    property string cavaColorMode: "accent"    // "accent" | "gradient" | "rainbow" | "solid"
    property string cavaGradientStart: "#7c3aed"
    property string cavaGradientEnd: "#22d3ee"
    property string cavaSolidColor: "#94a3b8"
    property real cavaRainbowSpeed: 12.0

    property int cavaBars: 40
    property int cavaFramerate: 60
    property int cavaSensitivity: 100
    property real cavaSmoothing: 0.77

    property real cavaBarWidth: 6.0
    property real cavaBarGap: 3.0
    property real cavaBarRadius: 2.0
    property real cavaMaxHeight: 140.0
    property real cavaRingRadius: 90.0

    property bool cavaShowGlow: true
    property bool cavaShowBackground: true
    property bool cavaShowBorder: true

    // Rotation is controlled directly on the widget (click it to reveal rotate
    // buttons), not from the Settings page -- still persisted like position/scale.
    property int cavaRotation: 0

    function rotateCava(direction) {
        // Deliberately left unbounded (not wrapped mod 360) so the widget's rotation
        // Behavior always animates the short way around instead of spinning back
        // through the whole circle when crossing the 0/360 boundary.
        cavaRotation += direction === "cw" ? 90 : -90
    }

    property var cavaPositions: ({})
    property var cavaScales: ({})
    property var enabledCavaScreens: []

    function getCavaPosition(screenName, defaultX, defaultY) {
        if (cavaPositions && cavaPositions[screenName]) {
            return cavaPositions[screenName]
        }
        return { x: defaultX, y: defaultY }
    }

    function saveCavaPosition(screenName, x, y) {
        let current = Object.assign({}, cavaPositions)
        current[screenName] = { x: x, y: y }
        cavaPositions = current
        if (configRef) configRef.saveSettings()
    }

    function getCavaScale(screenName) {
        if (cavaScales && cavaScales[screenName] !== undefined) {
            return cavaScales[screenName]
        }
        return 1.0
    }

    function saveCavaScale(screenName, scale) {
        let current = Object.assign({}, cavaScales)
        current[screenName] = scale
        cavaScales = current
        if (configRef) configRef.saveSettings()
    }

    function isCavaEnabledForScreen(screenName) {
        if (!enabledCavaScreens || enabledCavaScreens.length === 0) return true
        return enabledCavaScreens.includes(screenName)
    }

    function toggleCavaScreen(screenName) {
        let current = (enabledCavaScreens || []).slice()
        let idx = current.indexOf(screenName)
        if (idx !== -1) {
            current.splice(idx, 1)
        } else {
            current.push(screenName)
        }
        enabledCavaScreens = current
        if (configRef) configRef.saveSettings()
    }

    onShowDesktopCavaChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaStyleChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaColorModeChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaGradientStartChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaGradientEndChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaSolidColorChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaRainbowSpeedChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaBarWidthChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaBarGapChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaBarRadiusChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaMaxHeightChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaRingRadiusChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaShowGlowChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaShowBackgroundChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaShowBorderChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onCavaRotationChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    // These require the cava subprocess itself to be restarted with a new config
    onCavaBarsChanged: { if (configRef && configRef.isLoaded) { configRef.saveSettings(); configRef.cavaService.requestRestart() } }
    onCavaFramerateChanged: { if (configRef && configRef.isLoaded) { configRef.saveSettings(); configRef.cavaService.requestRestart() } }
    onCavaSensitivityChanged: { if (configRef && configRef.isLoaded) { configRef.saveSettings(); configRef.cavaService.requestRestart() } }
    onCavaSmoothingChanged: { if (configRef && configRef.isLoaded) { configRef.saveSettings(); configRef.cavaService.requestRestart() } }
}
