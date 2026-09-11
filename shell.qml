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

    // Safety net for any external kill (a plain `killall qs`/`killall
    // quickshell` in a terminal, not just the in-app Reload button, which
    // already flushes explicitly - see Config.flushSettings()) - Qt still
    // runs QML destruction handlers on a clean SIGTERM shutdown, so this
    // catches whatever was still sitting in the 400ms debounce window.
    Component.onDestruction: Config.flushSettings()

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
        command: ["sh", "-c", "if [ -d /sys/class/power_supply/BAT0 ]; then echo BAT0; elif [ -d /sys/class/power_supply/BAT1 ]; then echo BAT1; fi"]
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

    // Fallback sync check (relaxed to 60s since monitors handle real-time events).
    //
    // Everything restarted here is a one-shot that has already exited by the time
    // the timer fires, so the false -> true flip is safe. mediaFollowerProc is
    // deliberately NOT in this list: it's a long-lived `playerctl --follow` stream
    // that is always running, so flipping it here hit exactly the same-tick restart
    // CavaService.qml:launchCava() documents as broken (the old process needs real
    // wall-clock time to die). It also had nothing to re-sync - --follow is already
    // event-driven - so all the restart did was tear down a healthy stream every
    // minute and blank the media card until the next MPRIS event, which for a
    // paused player may never arrive.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            wifiStateProc.running = false; wifiStateProc.running = true
            btStateProc.running = false; btStateProc.running = true
            vpnStateProc.running = false; vpnStateProc.running = true
            recordStatusProc.running = false; recordStatusProc.running = true
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

        // actionsSupported changes client behaviour over D-Bus - Thunderbird,
        // Element and KDE Connect attach Reply / Mark read / Snooze buttons
        // when they see it, and some clients suppress their own fallback UI.
        // It was declared here while nothing in the shell ever read
        // notif.actions, so those buttons were promised and dropped.
        // NotificationOSD renders and invokes them now.
        actionsSupported: true

        // Lets clients send album art, avatars and app icons with the
        // notification; without this they don't bother, and the OSD had
        // nothing but a guessed-from-app-name glyph to show.
        imageSupported: true

        onNotification: notif => {
            if (notif) {
                notif.tracked = true
                Config.recordNotification(notif)
            }
        }
    }

    // --- SCREEN-AWARE IPC HANDLERS ---
    // Each panel verb is a one-liner over Config.togglePanel(), which closes
    // every other panel via the single flag table in Config.qml. These used to
    // be ten hand-maintained close lists - see the comment on Config.panelFlagByView
    // for the bug that drift caused.
    IpcHandler {
        target: "power"
        function toggle(): void { if (shellRoot.isFocusedBarEnabled) Config.togglePanel("power") }
    }

    IpcHandler {
        target: "launcherosd"
        function toggle(): void { if (shellRoot.isFocusedBarEnabled) Config.togglePanel("launcherOsd") }
        function open(): void {
            if (!shellRoot.isFocusedBarEnabled) return
            Config.closePanels("launcherOsd")
            Config.showLauncherOsd = true
        }
        function hide(): void { Config.showLauncherOsd = false }

        // Opens the launcher already in emoji/glyph mode, so a dedicated
        // keybind (SUPER+period, by convention) lands on the picker instead of
        // the app list. The ":" prefix is what LauncherOSD.updateModel()
        // switches on, so this is the same code path as typing it.
        function emoji(): void {
            if (!shellRoot.isFocusedBarEnabled) return
            Config.closePanels("launcherOsd")
            Config.launcherPrefill = ":"
            Config.showLauncherOsd = true
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { if (shellRoot.isFocusedBarEnabled) Config.togglePanel("wallpaper") }
    }

    IpcHandler {
        target: "workspaceoverview"
        function toggle(): void { if (shellRoot.isFocusedBarEnabled) Config.togglePanel("workspacePreview") }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { if (shellRoot.isFocusedBarEnabled) Config.togglePanel("settings") }
    }

    IpcHandler {
        target: "satty"
        function screenshot(): void {
            Config.captureScreenshot()
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { if (shellRoot.isFocusedBarEnabled) Config.togglePanel("clipboard") }
    }

    IpcHandler {
        target: "recorder"
        function toggle(): void { if (shellRoot.isFocusedBarEnabled) Config.togglePanel("screenRecorder") }
    }

    IpcHandler {
        target: "mirror"
        function toggle(): void { Config.showMirror = !Config.showMirror }
    }

    // Closes whatever drawer panel is open, whatever it is - the IPC twin of
    // the Escape key handler on the drawer Loader below.
    IpcHandler {
        target: "panel"
        function close(): void { Config.closeAllPanels() }
    }

    // Profiles are named snapshots of the whole settings file, so exposing them
    // over IPC means a Hyprland keybind (or a laptop-dock script) can switch the
    // entire shell layout in one call - which is the desktop-vs-laptop case these
    // exist for in the first place.
    IpcHandler {
        target: "profile"
        function save(name: string): void { Config.saveProfile(name) }
        function load(name: string): void { Config.loadProfile(name) }
        function remove(name: string): void { Config.deleteProfile(name) }
        function list(): string { return (Config.profileNames || []).join("\n") }
        function active(): string { return Config.activeProfile }
    }

    IpcHandler {
        target: "lockscreen"
        // Unlocking must only ever happen via successful PAM auth in Lockscreen.qml.
        // Do not add an unlock()/toggle() here - it would let any process running as
        // this user (or the SUPER+L keybind, which still fires while locked) bypass
        // the password prompt entirely.
        function lock(): void {
            Config.sessionLocked = true
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

    // These five strings feed the bar's clock module (RightModules.qml) and
    // nothing else, and not one of them displays seconds - so a 1Hz timer
    // rebuilt all five sixty times for every visible change. Worse, it ran
    // unconditionally: with no clock module on the bar it was a guaranteed
    // wakeup every second doing nothing at all, which on a laptop is exactly
    // what the rest of this file's event-driven telemetry exists to avoid.
    //
    // Now: one wakeup per minute, aligned to the minute boundary so the
    // display flips when the wall clock does rather than up to a second late,
    // and only while something is actually reading it. Recomputing the delay
    // on every fire also re-aligns it for free after a suspend/resume or a
    // timezone change.
    readonly property bool clockModuleActive: {
        let left = Config.leftCardOrder || []
        let right = Config.rightCardOrder || []
        return left.indexOf("clock") >= 0 || right.indexOf("clock") >= 0
    }

    function updateClockStrings() {
        var d = new Date()
        var h = d.getHours() % 12
        vertHour = (h === 0 ? 12 : h).toString()
        vertMinute = Qt.formatTime(d, "mm")
        vertAmPm = Qt.formatTime(d, "ap").toLowerCase()
        vertMonth = Qt.formatDate(d, "MMM")
        vertDay = Qt.formatDate(d, "d")
    }

    function msToNextMinute() {
        // +50ms so the timer lands just after the boundary, never a hair
        // before it (which would show the previous minute for one more tick).
        return 60000 - (Date.now() % 60000) + 50
    }

    Timer {
        id: clockTick
        repeat: false
        running: shellRoot.clockModuleActive
        onRunningChanged: if (running) interval = shellRoot.msToNextMinute()
        onTriggered: {
            shellRoot.updateClockStrings()
            interval = shellRoot.msToNextMinute()
            restart()
        }
        Component.onCompleted: interval = shellRoot.msToNextMinute()
    }

    // The bar can gain a clock module long after start-up (it is reorderable at
    // runtime), by which point the strings above are stale.
    onClockModuleActiveChanged: if (clockModuleActive) updateClockStrings()

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

                // One Escape handler for every drawer panel. Wallpaper handles
                // its own; Power, Clipboard, ControlCenter,
                // Settings, Network and Audio declared no Keys handler at all, so
                // Escape did nothing in half the shell depending on which panel
                // you happened to open. Focus already lands here (focus: true
                // above), and this fires only for panels that don't accept the
                // key themselves, so the launcher's own handler still wins.
                Keys.onEscapePressed: event => {
                    Config.closeAllPanels()
                    event.accepted = true
                }

                sourceComponent: {
                    switch (mainSurface.activeView) {
                        case "workspacePreview": return workspacePreviewComp;
                        case "power": return powerComp;
                        case "wallpaper": return wallpaperComp;
                        case "calendar": return calendarComp;
                        case "audio": return audioComp;
                        case "network": return networkComp;
                        case "battery": return batteryComp;
                        case "clipboard": return clipboardComp;
                        case "screenRecorder": return screenRecorderComp;
                        case "controlCenter": return controlCenterComp;
                        case "settings": return settingsComp;
                        default: return null;
                    }
                }
            }
        }
    }

    Component { id: workspacePreviewComp; WorkspacePreview {} }
    Component { id: powerComp; Power {} }
    Component { id: wallpaperComp; Wallpaper {} }
    Component { id: calendarComp; Calendar {} }
    Component { id: audioComp; Audio {} }
    Component { id: networkComp; Network {} }
    Component { id: batteryComp; Battery {} }
    Component { id: clipboardComp; Clipboard {} }
    Component { id: screenRecorderComp; ScreenRecorder {} }
    Component { id: controlCenterComp; ControlCenter {} }
    Component { id: settingsComp; Settings {} }

    VolumeOSD { id: volumeOsd }
    NotificationOSD { id: notificationOsd }
    Mascot { id: mascotWidget }
    AssistantWidget { id: assistantWidget }
    MediaCardWidget { id: mediaCardWidget }
    Mirror { id: mirrorWidget }
    OSK { id: oskWidget }
    PolkitDialog { id: polkitDialog }
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
            id: clockDelegate
            required property var modelData
            screen: modelData
            visible: clockDelegate.positionRestored && Config.showDesktopClock && (modelData ? Config.isClockEnabledForScreen(modelData.name) : true)
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
    Variants {
        model: Quickshell.screens

        delegate: AppDock {
            id: appDockDelegate
            required property var modelData
            screen: modelData
            visible: appDockDelegate.positionRestored && Config.showAppDock && (modelData ? Config.isAppDockEnabledForScreen(modelData.name) : true)
        }
    }
}