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
    
    property bool vpnActive: false

    // Recording State
    property bool isRecording: false

    // Battery State
    property bool hasBattery: false
    property string battName: "BAT0"
    property int battCapacity: 75
    property string battStatus: "Discharging"

    // Continuous Palette Loop / Animation
    property real animOffset: 0.0
    NumberAnimation on animOffset {
        from: 0.0
        to: 1.0
        duration: 4000
        loops: Animation.Infinite
        running: Config.showBorders
    }

    // Dynamic Palette Interpolation
    readonly property color currentBorderColor: {
        if (!Config.showBorders) return "transparent"
        let c1 = Qt.color(Config.borderStart)
        let c2 = Qt.color(Config.borderEnd)
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

    // Check if wf-recorder is active
    Process {
        id: recordStatusProc
        command: ["pgrep", "-x", "wf-recorder"]
        running: true
        onExited: (code, status) => {
            shellRoot.isRecording = (code === 0)
        }
    }

    // Detect if BAT0 or BAT1 exists
    Process {
        id: battDetectProc
        command: ["fish", "-c", "test -d /sys/class/power_supply/BAT0 && echo 'BAT0'; or test -d /sys/class/power_supply/BAT1 && echo 'BAT1'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let name = this.text.trim()
                if (name.length > 0) {
                    shellRoot.hasBattery = true
                    shellRoot.battName = name
                    battStateProc.running = false
                    battStateProc.running = true
                } else {
                    shellRoot.hasBattery = false
                }
            }
        }
    }

    // Read Battery Capacity and Charging Status
    Process {
        id: battStateProc
        running: false
        command: ["fish", "-c", "cat /sys/class/power_supply/" + shellRoot.battName + "/capacity; and cat /sys/class/power_supply/" + shellRoot.battName + "/status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                if (lines.length >= 2) {
                    shellRoot.battCapacity = parseInt(lines[0]) || 0
                    shellRoot.battStatus = lines[1].trim()
                }
            }
        }
    }

    // Wi-Fi Status Query
    Process {
        id: wifiStateProc
        command: ["fish", "-c", "nmcli radio wifi"]
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
        command: ["fish", "-c", "nmcli -t -f ACTIVE,SSID dev wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text.trim()
                let activeMatch = text.match(/yes:(.*)/)
                shellRoot.wifiSsid = activeMatch ? activeMatch[1] : ""
            }
        }
    }

    // Audio Status Query via PipeWire
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

    // Event-driven Audio Poller via Pactl Subscribe
    Process {
        id: audioSubscribeProc
        command: ["stdbuf", "-oL", "pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("sink")) {
                    audioStateProc.running = false
                    audioStateProc.running = true
                }
            }
        }
    }

    // Bluetooth Status Query
    Process {
        id: btStateProc
        command: ["fish", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo 'ON' || echo 'OFF'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                shellRoot.btPowered = this.text.trim() === "ON"
            }
        }
    }

    // Network / VPN Connection Query
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

    // Global Status Poller Timer
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            recordStatusProc.running = false; recordStatusProc.running = true
            wifiStateProc.running = false; wifiStateProc.running = true
            audioStateProc.running = false; audioStateProc.running = true
            btStateProc.running = false; btStateProc.running = true
            vpnStateProc.running = false; vpnStateProc.running = true
            if (shellRoot.hasBattery) {
                battStateProc.running = false
                battStateProc.running = true
            }
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
                Config.showCalendar = false; Config.showNotifications = false; Config.showBattery = false;
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
                Config.showCalendar = false; Config.showNotifications = false; Config.showBattery = false;
                Config.showWorkspacePreview = false; Config.showControlCenter = false; Config.showScreenRecorder = false;
                Config.showClipboard = false; Config.showMirror = false;
            }
            Config.showAppLauncher = !Config.showAppLauncher
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            if (!Config.showWallpaper) {
                Config.showPower = false; Config.showSettings = false; Config.showAppLauncher = false;
                Config.showCalendar = false; Config.showNotifications = false; Config.showBattery = false;
                Config.showWorkspacePreview = false; Config.showControlCenter = false; Config.showScreenRecorder = false;
                Config.showClipboard = false; Config.showMirror = false;
            }
            Config.showWallpaper = !Config.showWallpaper
        }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            if (!Config.showNotifications) {
                Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false;
                Config.showAppLauncher = false; Config.showCalendar = false; Config.showBattery = false;
                Config.showWorkspacePreview = false; Config.showControlCenter = false; Config.showScreenRecorder = false;
                Config.showClipboard = false; Config.showMirror = false;
            }
            Config.showNotifications = !Config.showNotifications
        }
    }

    IpcHandler {
        target: "workspaceoverview"
        function toggle(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            if (!Config.showWorkspacePreview) {
                Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false;
                Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false;
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
                Config.showCalendar = false; Config.showNotifications = false; Config.showBattery = false;
                Config.showWorkspacePreview = false; Config.showControlCenter = false; Config.showScreenRecorder = false;
                Config.showClipboard = false; Config.showMirror = false;
            }
            Config.showSettings = !Config.showSettings
        }
    }

    IpcHandler {
        target: "satty"
        function screenshot(): void {
            Quickshell.execDetached(["fish", "-c", "sleep 0.1; grim -g (slurp) -t ppm - | satty --filename -"])
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            if (!Config.showClipboard) {
                Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false;
                Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false;
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
                Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false;
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
                Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false;
                Config.showBattery = false; Config.showWorkspacePreview = false; Config.showControlCenter = false;
                Config.showClipboard = false; Config.showScreenRecorder = false; Config.showPlayer = false;
            }
            Config.showMirror = !Config.showMirror
        }
    }

    IpcHandler {
        target: "player"
        function toggle(): void {
            if (!shellRoot.isFocusedBarEnabled) return;
            if (!Config.showPlayer) {
                Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false;
                Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false;
                Config.showBattery = false; Config.showWorkspacePreview = false; Config.showControlCenter = false;
                Config.showClipboard = false; Config.showScreenRecorder = false; Config.showMirror = false;
            }
            Config.showPlayer = !Config.showPlayer
        }
    }

    // --- CLOCK & DATE FORMATTING ---
    property string timeStr: Qt.formatTime(new Date(), "h:mm ap")
    property string shortDateStr: Qt.formatDate(new Date(), "MMM d")

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
            timeStr = Qt.formatTime(d, "h:mm ap")
            shortDateStr = Qt.formatDate(d, "MMM d")

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
                        case "notifications": return notificationsComp;
                        case "audio": return audioComp;
                        case "network": return networkComp;
                        case "systemMonitor": return systemMonitorComp;
                        case "battery": return batteryComp;
                        case "clipboard": return clipboardComp;
                        case "screenRecorder": return screenRecorderComp;
                        case "controlCenter": return controlCenterComp;
                        case "settings": return settingsComp;
                        case "player": return playerComp;
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
    Component { id: notificationsComp; Notifications {} }
    Component { id: audioComp; Audio {} }
    Component { id: networkComp; Network {} }
    Component { id: systemMonitorComp; SystemMonitor {} }
    Component { id: batteryComp; Battery {} }
    Component { id: clipboardComp; Clipboard {} }
    Component { id: screenRecorderComp; ScreenRecorder {} }
    Component { id: controlCenterComp; ControlCenter {} }
    Component { id: settingsComp; Settings {} }
    Component { id: playerComp; MediaPlayer {} }
    Component { id: mirrorComp; Mirror {} }

    VolumeOSD { id: volumeOsd }
    NotificationOSD { id: notificationOsd }
    Mascot { id: mascotWidget }
    OSK { id: oskWidget }

    VideoOutput {
        id: persistentVideoSink
        visible: false
        Component.onCompleted: {
            Config.inlinePlayer.videoOutput = persistentVideoSink
        }
    }

    MediaPlayer { 
        id: globalMediaPlayerWidget
        visible: Config.showPlayer
    }

    Variants {
        model: Quickshell.screens

        delegate: ClockWidget {
            required property var modelData
            screen: modelData
            visible: Config.showDesktopClock && Config.isClockEnabledForScreen(modelData.name)
        }
    }
}