import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: wallpaperRoot

    property var configRef: null

    // --- WALLHAVEN INTEGRATION ---
    property string wallhavenUsername: ""
    property string wallhavenApiKey: ""

    onWallhavenUsernameChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onWallhavenApiKeyChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    // --- WALLHAVEN SYNC (owned here, not by the settings panel, so it keeps
    // running - and its progress stays live - when WallpaperSettings.qml is
    // torn down by the settings Loader on panel close) ---
    property bool wallhavenSyncing: false
    property real wallhavenSyncProgress: 0.0
    property string wallhavenSyncStatus: "Idle"

    function startWallhavenSync() {
        if (wallhavenSyncProcess.running) return
        wallpaperRoot.wallhavenSyncing = true
        wallpaperRoot.wallhavenSyncProgress = 0.0
        wallpaperRoot.wallhavenSyncStatus = "Connecting..."
        wallhavenSyncProcess.running = true
    }

    property Process wallhavenSyncProcess: Process {
        id: wallhavenSyncProcess
        command: [
            Quickshell.env("HOME") + "/.config/quickshell/Synoptik/scripts/wallhaven_sync.sh",
            wallpaperRoot.wallhavenApiKey || "",
            wallpaperRoot.wallhavenUsername || "",
            Quickshell.env("HOME") + "/Pictures/Wallpapers"
        ]

        stdout: SplitParser {
            onRead: data => {
                let line = data.trim()
                if (line.startsWith("PROGRESS:")) {
                    let parts = line.split(":")
                    let current = parseInt(parts[1])
                    let total = parseInt(parts[2])
                    if (total > 0) wallpaperRoot.wallhavenSyncProgress = current / total
                    wallpaperRoot.wallhavenSyncStatus = `Downloading ${current}/${total}...`
                } else if (line.startsWith("STATUS:")) {
                    wallpaperRoot.wallhavenSyncStatus = line.replace("STATUS:", "")
                }
            }
        }

        onExited: (exitCode) => {
            wallpaperRoot.wallhavenSyncing = false
            if (exitCode === 0) {
                wallpaperRoot.wallhavenSyncProgress = 1.0
                wallpaperRoot.wallhavenSyncStatus = "Sync complete"
                wallpaperRoot.refreshWallpapers()
            } else {
                wallpaperRoot.wallhavenSyncStatus = "Sync failed"
            }
        }
    }

    // --- WALLPAPER CONFIG STATE & PERSISTENCE ---
    property var selectedWallpaperMonitors: []
    property string wallpaperTransitionType: "wipe"
    property string activeWallpaperPath: ""
    property var activeMonitorWallpapers: ({})
    property bool enableWallpaperParallax: true
    property bool wallpaperWorkspaceParallax: true
    property bool wallpaperCursorParallax: true
    property real wallpaperParallaxIntensity: 1.0

    onEnableWallpaperParallaxChanged: { if (configRef) configRef.saveSettings() }
    onWallpaperWorkspaceParallaxChanged: { if (configRef) configRef.saveSettings() }
    onWallpaperCursorParallaxChanged: { if (configRef) configRef.saveSettings() }
    onWallpaperParallaxIntensityChanged: { if (configRef) configRef.saveSettings() }

    function getMonitorWallpaper(screenName) {
        if (activeMonitorWallpapers && activeMonitorWallpapers[screenName]) {
            return activeMonitorWallpapers[screenName]
        }
        return activeWallpaperPath
    }

    property Process wallpaperQuerier: Process {
        id: wpQuerier
        command: [
            "python3", "-c",
            "import subprocess, json, re; out=subprocess.getoutput('awww query 2>/dev/null || swww query 2>/dev/null'); res={}; [res.update({m.group(1).strip(): m.group(2).strip()}) for m in re.finditer(r':\\s*([^:]+):.*currently displaying:\\s*(?:image|video):\\s*(.*)', out)]; print(json.dumps(res))"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(this.text)
                    if (parsed && typeof parsed === "object") {
                        wallpaperRoot.activeMonitorWallpapers = parsed
                        let keys = Object.keys(parsed)
                        if (keys.length > 0 && parsed[keys[0]]) {
                            wallpaperRoot.activeWallpaperPath = parsed[keys[0]]
                        }
                    }
                } catch (e) {}
            }
        }
    }

    function refreshActiveWallpapers() {
        wpQuerier.running = false
        wpQuerier.running = true
    }

    // --- BACKGROUND SLIDESHOW TIMER & RUNNER ---
    property bool slideshowActive: false
    property int slideshowMinutes: 5

    onSlideshowActiveChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onSlideshowMinutesChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    function triggerRandomWallpaperBackground() {
        configRef.wallpaperService.triggerRandomWallpaperBackground()
    }

    function applyWallpaperBackend(filePath, activeOnly) {
        configRef.wallpaperService.applyWallpaperBackend(filePath, activeOnly)
        refreshActiveWallpapers()
    }

    function toggleWallpaperMonitor(screenName) {
        configRef.wallpaperService.toggleWallpaperMonitor(screenName)
    }

    // --- STARTUP WALLPAPER & THUMBNAIL CACHER ---
    property var wallpapers: []
    property var tempPaths: []

    property Process wallpaperScanner: Process {
        id: scanner
        command: [
            "python3", "-c",
            "import os; d=os.path.expanduser('~/Pictures/Wallpapers'); (os.path.isdir(d) and [print(os.path.join(d, f)) for f in os.listdir(d) if f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp', '.mp4', '.webm'))])"
        ]

        stdout: SplitParser {
            onRead: data => {
                var trimmed = data.trim()
                if (trimmed.length > 0) wallpaperRoot.tempPaths.push(trimmed)
            }
        }

        onExited: (code, status) => {
            wallpaperRoot.wallpapers = wallpaperRoot.tempPaths
            thumbPreloader.running = true
        }

        Component.onCompleted: {
            wallpaperRoot.tempPaths = []
            running = true
        }
    }

    property Process thumbPreloader: Process {
        id: thumbPreloader
        running: false
        command: [
            "fish", "-c",
            "set -l cache_dir $HOME/.cache/wallpaper-thumbs; " +
            "test -d $cache_dir; or mkdir -p $cache_dir; " +
            "for f in ~/Pictures/Wallpapers/*.{png,jpg,jpeg,webp,mp4,webm}; " +
            "    test -f $f; or continue; " +
            "    set -l base_name (string replace -r '\\.[^.]+$' '' (path basename $f)); " +
            "    set -l target \"$cache_dir/$base_name.jpg\"; " +
            "    if not test -f $target; " +
            "        if string match -rq '\\.(mp4|webm)$' $f; " +
            "            nice -n 19 ffmpeg -y -ss 00:00:01 -i $f -vframes 1 -vf 'scale=960:-1:flags=lanczos' -q:v 2 $target >/dev/null 2>&1 &; " +
            "        else; " +
            "            nice -n 19 ffmpeg -y -i $f -vf 'scale=960:-1:flags=lanczos' -q:v 2 $target >/dev/null 2>&1 &; " +
            "        end; " +
            "    end; " +
            "end; " +
            "wait"
        ]
        onExited: {
            if (configRef && configRef.wallpaperService) {
                configRef.wallpaperService.thumbEpoch++
            }
        }
    }

    function refreshWallpapers() {
        if (!scanner.running) {
            tempPaths = []
            scanner.running = true
        }
    }
}
