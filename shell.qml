//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtMultimedia
import Quickshell.Services.Notifications as Notifs
import "components"
import "components/bars"
import "components/lockscreen"
import "components/osds"
import "components/widgets"

ShellRoot {
    id: shellRoot

    // --- GLOBAL STATUS LISTENERS ---
    property bool wifiPowered: true
    property string wifiSsid: ""
    
    property bool btPowered: true
    property bool btConnected: false
    
    property bool isUserSettingVolume: false
    property bool audioMuted: false
    property int audioVolume: 50
    // Raw pactl subscribe lines, re-broadcast so other components (e.g. Audio.qml's
    // mic tracking and sink/source device list) can react without opening their own
    // second "pactl subscribe" process.
    signal audioSubscribeEvent(string data)
    
    property bool vpnActive: false

    // Recording State
    property bool isRecording: false

    // Lockscreen State
    property bool sessionLocked: Config.sessionLocked

    // Battery State
    property bool hasBattery: false
    property string battName: "BAT0"
    property int battCapacity: 75
    property string battStatus: "Discharging"

    // Continuous Palette Loop / Animation (Controlled by Config.animateGradient)
    property real animOffset: 0.0
    NumberAnimation on animOffset {
        from: 0.0
        to: 1.0
        duration: 4000
        loops: Animation.Infinite
        running: Config.showBorders && Config.animateGradient
    }

    // Dynamic Palette Interpolation (Cached Color Instances)
    readonly property color bStartColor: Qt.color(Config.borderStart)
    readonly property color bEndColor: Qt.color(Config.borderEnd)

    // Ambient audio breathing: a slow, smoothed 0..1 signal from bass energy
    // (see CavaService.breatheLevel), scaled by the user's chosen intensity.
    // Kept as its own property so any surface can opt into it later without
    // re-deriving the smoothing logic.
    readonly property real breathAmount: (Config.ambientBreatheEnabled && Config.cavaService)
        ? Config.cavaService.breatheLevel * Config.ambientBreatheIntensity
        : 0.0

    // Whole-bar throb: a small uniform scale pulse in time with breathAmount.
    // Kept as a shared multiplier so every bar shape variant scales in sync
    // instead of each computing its own factor slightly differently.
    readonly property real throbScale: 1.0 + (breathAmount * 0.04)

    readonly property color currentBorderColor: {
        if (!Config.showBorders) return "transparent"
        // Ambient breathing moved to a scale throb (see UnifiedSurface.qml's
        // barContent/BarClosedShape) - modulating alpha here read as a bad
        // flicker on a thin border, so this stays a plain steady color again.
        if (!Config.animateGradient) return bStartColor
        let c1 = bStartColor
        let c2 = bEndColor
        let progress = (Math.sin(shellRoot.animOffset * Math.PI * 2) + 1.0) / 2.0

        return Qt.rgba(
            c1.r + (c2.r - c1.r) * progress,
            c1.g + (c2.g - c1.g) * progress,
            c1.b + (c2.b - c1.b) * progress,
            1.0
        )
    }

    // Guard IPC Toggles
    readonly property bool isFocusedBarEnabled: {
        let activeMon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        return activeMon === "" || Config.isBarEnabledForScreen(activeMon)
    }

    // --- 1. BATTERY TELEMETRY (FileView on sysfs) ---
    Process {
        id: battDetectProc
        command: ["fish", "-c", "if test -d /sys/class/power_supply/BAT0; echo BAT0; else if test -d /sys/class/power_supply/BAT1; echo BAT1; end"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let name = this.text.trim().split("\n")[0]
                if (name && name.length > 0) {
                    shellRoot.hasBattery = true
                    shellRoot.battName = name
                } else {
                    shellRoot.hasBattery = false
                }
            }
        }
    }

    FileView {
        id: battCapacityReader
        path: shellRoot.hasBattery ? ("/sys/class/power_supply/" + shellRoot.battName + "/capacity") : ""
        onTextChanged: {
            let cap = parseInt(text().trim())
            if (!isNaN(cap)) shellRoot.battCapacity = cap
        }
    }

    FileView {
        id: battStatusReader
        path: shellRoot.hasBattery ? ("/sys/class/power_supply/" + shellRoot.battName + "/status") : ""
        onTextChanged: {
            let st = text().trim()
            if (st.length > 0) shellRoot.battStatus = st
        }
    }

    // Event-driven reload: sysfs itself doesn't emit inotify events, but the kernel
    // does emit a udev "change" event on the power_supply subsystem whenever capacity/
    // status actually changes - so block on that instead of polling on a fixed interval
    // (same long-lived Process+SplitParser pattern as networkMonitorProc/btMonitorProc
    // below). The 60s fallback Timer further down re-syncs everything as a safety net.
    Process {
        id: battUdevMonitor
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=power_supply"]
        running: shellRoot.hasBattery
        stdout: SplitParser {
            onRead: data => {
                battCapacityReader.reload()
                battStatusReader.reload()
            }
        }
    }

    // --- 2. WI-FI & NETWORK TELEMETRY (Event-driven via nmcli monitor) ---
    Process {
        id: networkMonitorProc
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                wifiStateProc.running = false
                wifiStateProc.running = true
                vpnStateProc.running = false
                vpnStateProc.running = true
            }
        }
    }

    Process {
        id: wifiStateProc
        command: ["nmcli", "radio", "wifi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let status = this.text.trim()
                if (status === "enabled") {
                    shellRoot.wifiPowered = true
                    wifiActiveProc.running = false
                    wifiActiveProc.running = true
                } else {
                    shellRoot.wifiPowered = false
                    shellRoot.wifiSsid = ""
                }
            }
        }
    }

    Process {
        id: wifiActiveProc
        running: false
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text.trim()
                let activeMatch = text.match(/yes:(.*)/)
                shellRoot.wifiSsid = activeMatch ? activeMatch[1] : ""
            }
        }
    }

    Process {
        id: vpnStateProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "connection", "show", "--active"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text.trim()
                shellRoot.vpnActive = text.includes("vpn") || text.includes("wireguard") || text.includes("tun")
            }
        }
    }

    // --- 3. BLUETOOTH TELEMETRY (Event-driven stream via bluetoothctl) ---
    Process {
        id: btMonitorProc
        command: ["stdbuf", "-oL", "bluetoothctl", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                btStateProc.running = false
                btStateProc.running = true
            }
        }
    }

    Process {
        id: btStateProc
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 'ON' || echo 'OFF'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                shellRoot.btPowered = this.text.trim() === "ON"
            }
        }
    }

    // --- 4. AUDIO TELEMETRY (Event-driven via PipeWire / pactl) ---
    Process {
        id: audioStateProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (shellRoot.isUserSettingVolume) return;

                let cleaned = this.text.trim()
                let match = cleaned.match(/Volume:\s+([0-9.]+)/)
                if (match) {
                    shellRoot.audioVolume = Math.round(parseFloat(match[1]) * 100)
                    shellRoot.audioMuted = cleaned.includes("[MUTED]")
                }
            }
        }
    }

    Process {
        id: audioSubscribeProc
        command: ["stdbuf", "-oL", "pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                shellRoot.audioSubscribeEvent(data)
                if (data.includes("sink")) {
                    audioStateProc.running = false
                    audioStateProc.running = true
                }
            }
        }
    }

    // --- 5. RECORDING STATUS ---
    Process {
        id: recordStatusProc
        command: ["pgrep", "-x", "wf-recorder"]
        running: false
        onExited: (code, status) => {
            shellRoot.isRecording = (code === 0)
        }
    }

    // --- 6. MEDIA / MPRIS TELEMETRY (Event-driven via playerctl --follow) ---
    // Runs continuously (not gated on Control Center being open) so the bar's
    // ActiveWindowCard can reflect "now playing" at all times. MediaCard binds
    // to these same properties instead of running its own separate follower.
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaStatus: "Stopped"
    property string mediaArtUrl: ""
    readonly property bool mediaPlaying: mediaStatus === "Playing"

    Process {
        id: mediaFollowerProc
        command: ["playerctl", "--player=%any,playerctld", "--follow", "--format", '{"title": "{{title}}", "artist": "{{artist}}", "status": "{{status}}", "art": "{{mpris:artUrl}}"}', "metadata"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    let parsed = JSON.parse(data.trim());
                    if (parsed.status === "Stopped" || !parsed.title || parsed.title.trim() === "") {
                        shellRoot.mediaTitle = "";
                        shellRoot.mediaArtist = "";
                        shellRoot.mediaStatus = "Stopped";
                        shellRoot.mediaArtUrl = "";
                    } else {
                        shellRoot.mediaTitle = parsed.title;
                        shellRoot.mediaArtist = parsed.artist || "Unknown Artist";
                        shellRoot.mediaStatus = parsed.status;
                        shellRoot.mediaArtUrl = parsed.art || "";
                    }
                } catch(e) {
                    shellRoot.mediaTitle = "";
                    shellRoot.mediaArtist = "";
                    shellRoot.mediaStatus = "Stopped";
                    shellRoot.mediaArtUrl = "";
                }
            }
        }
    }

    // Fallback sync check (relaxed to 60s since monitors handle real-time events)
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            wifiStateProc.running = false; wifiStateProc.running = true
            btStateProc.running = false; btStateProc.running = true
            vpnStateProc.running = false; vpnStateProc.running = true
            recordStatusProc.running = false; recordStatusProc.running = true
            mediaFollowerProc.running = false; mediaFollowerProc.running = true
            if (shellRoot.hasBattery) { battCapacityReader.reload(); battStatusReader.reload() }
        }
    }

    // --- NATIVE NOTIFICATION SERVER ---
    property alias notifServer: notifServer
    
    readonly property int activeNotifs: (notifServer.trackedNotifications && notifServer.trackedNotifications.values) 
        ? notifServer.trackedNotifications.values.length 
        : 0

    Notifs.NotificationServer {
        id: notifServer
        property bool dnd: false
        bodySupported: true
        actionsSupported: true

        onNotification: notif => {
            if (notif) {
                notif.tracked = true
                Config.recordNotification(notif)
            }
        }
    }

    // --- SCREEN-AWARE IPC HANDLERS ---
    IpcHandler {
        target: "power"
        function toggle(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            if (!Config.showPower) {
                Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false;
                Config.showLauncherOsd = false;
                Config.showCalendar = false; Config.showBattery = false;
                Config.showWorkspacePreview = false; Config.showControlCenter = false; Config.showScreenRecorder = false;
                Config.showClipboard = false; Config.showMirror = false;
            }
            Config.showPower = !Config.showPower
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            if (!Config.showAppLauncher) {
                Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false;
                Config.showLauncherOsd = false;
                Config.showCalendar = false; Config.showBattery = false;
                Config.showWorkspacePreview = false; Config.showControlCenter = false; Config.showScreenRecorder = false;
                Config.showClipboard = false; Config.showMirror = false;
            }
            Config.showAppLauncher = !Config.showAppLauncher
        }
    }

    IpcHandler {
        target: "launcherosd"
        function toggle(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            if (!Config.showLauncherOsd) {
                Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false;
                Config.showAppLauncher = false;
                Config.showCalendar = false; Config.showBattery = false;
                Config.showWorkspacePreview = false; Config.showControlCenter = false; Config.showScreenRecorder = false;
                Config.showClipboard = false; Config.showMirror = false;
            }
            Config.showLauncherOsd = !Config.showLauncherOsd
        }
        function open(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false;
            Config.showAppLauncher = false;
            Config.showCalendar = false; Config.showBattery = false;
            Config.showWorkspacePreview = false; Config.showControlCenter = false; Config.showScreenRecorder = false;
            Config.showClipboard = false; Config.showMirror = false;
            Config.showLauncherOsd = true
        }
        function hide(): void {
            Config.showLauncherOsd = false
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            if (!Config.showWallpaper) {
                Config.showPower = false; Config.showSettings = false; Config.showAppLauncher = false;
                Config.showLauncherOsd = false;
                Config.showCalendar = false; Config.showBattery = false;
                Config.showWorkspacePreview = false; Config.showControlCenter = false; Config.showScreenRecorder = false;
                Config.showClipboard = false; Config.showMirror = false;
            }
            Config.showWallpaper = !Config.showWallpaper
        }
    }

    IpcHandler {
        target: "workspaceoverview"
        function toggle(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            if (!Config.showWorkspacePreview) {
                Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false;
                Config.showAppLauncher = false; Config.showLauncherOsd = false; Config.showCalendar = false;
                Config.showBattery = false; Config.showControlCenter = false; Config.showScreenRecorder = false;
                Config.showClipboard = false; Config.showMirror = false;
            }
            Config.showWorkspacePreview = !Config.showWorkspacePreview
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            if (!Config.showSettings) {
                Config.showPower = false; Config.showWallpaper = false; Config.showAppLauncher = false;
                Config.showLauncherOsd = false;
                Config.showCalendar = false; Config.showBattery = false;
                Config.showWorkspacePreview = false; Config.showControlCenter = false; Config.showScreenRecorder = false;
                Config.showClipboard = false; Config.showMirror = false;
            }
            Config.showSettings = !Config.showSettings
        }
    }

    IpcHandler {
        target: "satty"
        function screenshot(): void {
            Config.captureScreenshot()
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            if (!Config.showClipboard) {
                Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false;
                Config.showAppLauncher = false; Config.showLauncherOsd = false; Config.showCalendar = false;
                Config.showBattery = false; Config.showWorkspacePreview = false; Config.showControlCenter = false;
                Config.showScreenRecorder = false; Config.showMirror = false;
            }
            Config.showClipboard = !Config.showClipboard
        }
    }

    IpcHandler {
        target: "recorder"
        function toggle(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            if (!Config.showScreenRecorder) {
                Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false;
                Config.showAppLauncher = false; Config.showLauncherOsd = false; Config.showCalendar = false;
                Config.showBattery = false; Config.showWorkspacePreview = false; Config.showControlCenter = false;
                Config.showClipboard = false; Config.showMirror = false;
            }
            Config.showScreenRecorder = !Config.showScreenRecorder
        }
    }

    IpcHandler {
        target: "mirror"
        function toggle(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            if (!Config.showMirror) {
                Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false;
                Config.showAppLauncher = false; Config.showLauncherOsd = false; Config.showCalendar = false;
                Config.showBattery = false; Config.showWorkspacePreview = false; Config.showControlCenter = false;
                Config.showClipboard = false; Config.showScreenRecorder = false;
            }
            Config.showMirror = !Config.showMirror
        }
    }

    IpcHandler {
        target: "lockscreen"
        function lock(): void {
            Config.sessionLocked = true
        }
        function unlock(): void {
            Config.sessionLocked = false
        }
        function toggle(): void {
            Config.sessionLocked = !Config.sessionLocked
        }
    }

    IpcHandler {
        target: "screensaver"
        function toggle(): void {
            Config.showScreensaver = !Config.showScreensaver
        }
        function start(): void {
            Config.showScreensaver = true
        }
        function stop(): void {
            Config.showScreensaver = false
        }
    }

    // --- CLOCK & DATE FORMATTING ---
    property string vertHour: {
        var h = new Date().getHours() % 12
        return (h === 0 ? 12 : h).toString()
    }
    property string vertMinute: Qt.formatTime(new Date(), "mm")
    property string vertAmPm: Qt.formatTime(new Date(), "ap").toLowerCase()
    property string vertMonth: Qt.formatDate(new Date(), "MMM")
    property string vertDay: Qt.formatDate(new Date(), "d")

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var d = new Date()
            var h = d.getHours() % 12
            vertHour = (h === 0 ? 12 : h).toString()
            vertMinute = Qt.formatTime(d, "mm")
            vertAmPm = Qt.formatTime(d, "ap").toLowerCase()
            vertMonth = Qt.formatDate(d, "MMM")
            vertDay = Qt.formatDate(d, "d")
        }
    }

    // --- MULTI-MONITOR UNIFIED SURFACE GENERATOR ---
    Variants {
        model: Quickshell.screens

        delegate: UnifiedSurface {
            id: mainSurface
            
            required property var modelData

            screen: modelData
            visible: Config.isBarEnabledForScreen(modelData.name)

            Loader {
                id: drawerLoader
                anchors.fill: parent
                active: mainSurface.activeView !== "none"
                focus: true

                onLoaded: {
                    mainSurface.activeDrawerItem = item
                    if (item && typeof item.forceActiveFocus === "function") {
                        item.forceActiveFocus()
                    }
                }

                sourceComponent: {
                    switch (mainSurface.activeView) {
                        case "workspacePreview": return workspacePreviewComp;
                        case "power": return powerComp;
                        case "wallpaper": return wallpaperComp;
                        case "appLauncher": return appLauncherComp;
                        case "calendar": return calendarComp;
                        case "audio": return audioComp;
                        case "network": return networkComp;
                        case "systemMonitor": return systemMonitorComp;
                        case "battery": return batteryComp;
                        case "clipboard": return clipboardComp;
                        case "screenRecorder": return screenRecorderComp;
                        case "controlCenter": return controlCenterComp;
                        case "settings": return settingsComp;
                        case "mirror": return mirrorComp;
                        default: return null;
                    }
                }
            }
        }
    }

    Component { id: workspacePreviewComp; WorkspacePreview {} }
    Component { id: powerComp; Power {} }
    Component { id: wallpaperComp; Wallpaper {} }
    Component { id: appLauncherComp; AppLauncher {} }
    Component { id: calendarComp; Calendar {} }
    Component { id: audioComp; Audio {} }
    Component { id: networkComp; Network {} }
    Component { id: batteryComp; Battery {} }
    Component { id: clipboardComp; Clipboard {} }
    Component { id: screenRecorderComp; ScreenRecorder {} }
    Component { id: controlCenterComp; ControlCenter {} }
    Component { id: settingsComp; Settings {} }
    Component { id: mirrorComp; Mirror {} }

    VolumeOSD { id: volumeOsd }
    NotificationOSD { id: notificationOsd }
    Mascot { id: mascotWidget }
    OSK { id: oskWidget }
    Screensaver { id: screensaverWidget }
    WallpaperSurface { id: wallpaperSurface }
    Lockscreen { id: lockscreenWidget; sessionLocked: Config.sessionLocked; shellRef: shellRoot }

    Variants {
        model: Quickshell.screens

        delegate: DesktopContextArea {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens

        delegate: ClockWidget {
            required property var modelData
            screen: modelData
            visible: Config.showDesktopClock && (modelData ? Config.isClockEnabledForScreen(modelData.name) : true)
        }
    }
    Variants {
        model: Quickshell.screens

        delegate: SystemInfoWidget {
            required property var modelData
            screen: modelData
            visible: (Config.showDesktopSysInfo !== false) && (modelData ? (Config.isSysInfoEnabledForScreen ? Config.isSysInfoEnabledForScreen(modelData.name) : true) : true)
        }
    }
    Variants {
        model: Quickshell.screens

        delegate: CavaWidget {
            required property var modelData
            screen: modelData
            visible: Config.showDesktopCava && (modelData ? Config.isCavaEnabledForScreen(modelData.name) : true)
        }
    }
}