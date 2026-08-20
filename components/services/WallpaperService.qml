import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: wallpaperService

    property var configRef: null
    property var onlineResults: []
    property bool isFetchingOnline: false

    property int thumbEpoch: 0

    property Process slideshowRunner: Process {
        id: bgSlideshowProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let path = this.text ? this.text.trim() : ""
                if (path.length > 0) {
                    wallpaperService.applyWallpaperBackend(path, false)
                }
            }
        }
    }

    property Timer bgSlideshowTimer: Timer {
        id: bgTimer
        interval: Math.max(1, (configRef ? configRef.slideshowMinutes : 5)) * 60000
        running: (configRef ? (configRef.isLoaded && configRef.slideshowActive) : false)
        repeat: true
        onTriggered: wallpaperService.triggerRandomWallpaperBackground()
    }

    function triggerRandomWallpaperBackground() {
        bgSlideshowProc.command = [
            "fish", "-c",
            "set -l files ~/Pictures/Wallpapers/*.{jpg,jpeg,png,webp,mp4,webm}; " +
            "if test (count $files) -gt 0; " +
            "    random choice $files; " +
            "end"
        ]
        bgSlideshowProc.running = false
        bgSlideshowProc.running = true
    }

    property Process wallpaperApplyRunner: Process {
        id: wpApplyProc
        running: false
        property string pendingIrisPath: ""

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                if (configRef && configRef.enableIris && pendingIrisPath !== "") {
                    configRef.applyIrisColors(pendingIrisPath)
                    pendingIrisPath = ""
                }
            }
        }
    }

    function applyWallpaperBackend(filePath, activeOnly) {
        if (!filePath || !configRef) return

        let cleanFilePath = (typeof filePath === "string" ? filePath : filePath.toString()).replace(/^file:\/\//, "")
        configRef.activeWallpaperPath = cleanFilePath

        let ext = cleanFilePath.split('.').pop().toLowerCase()
        let isVid = (ext === "mp4" || ext === "webm")
        let useParallax = configRef.enableWallpaperParallax && (configRef.wallpaperWorkspaceParallax || configRef.wallpaperCursorParallax)
        let waylandDisplay = Quickshell.env("WAYLAND_DISPLAY") || "wayland-1"
        let sockPath = "/run/user/" + Quickshell.env("UID") + "/" + waylandDisplay + "-awww-daemon.sock"
        let targets = activeOnly ? [] : (configRef.selectedWallpaperMonitors || []).filter(mon => Quickshell.screens.some(s => s.name === mon))
        let transition = configRef.wallpaperTransitionType || "fade"

        // Wipe stale per-monitor overrides when setting global wallpaper
        if (!activeOnly && targets.length === 0) {
            configRef.activeMonitorWallpapers = ({})
        }

        let script = ""

        if (isVid) {
            // Kill existing daemons by exact binary name so fish script does not self-terminate
            script += "killall -9 -q awww-daemon awww mpvpaper 2>/dev/null; rm -f " + sockPath + "; "
            if (activeOnly) {
                script += "set TARGET_MON (hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'); "
                script += "nohup mpvpaper -vs -o 'input-terminal=no loop-file=inf no-audio panscan=1.0 video-unscaled=no' \"$TARGET_MON\" '" + cleanFilePath + "' < /dev/null >/dev/null 2>&1 & disown; "
            } else {
                script += "nohup mpvpaper -vs -o 'input-terminal=no loop-file=inf no-audio panscan=1.0 video-unscaled=no' '*' '" + cleanFilePath + "' < /dev/null >/dev/null 2>&1 & disown; "
            }
        } else if (useParallax) {
            // Parallax Mode: WallpaperSurface renders on Background; kill external daemons
            script += "killall -9 -q mpvpaper awww-daemon awww 2>/dev/null; rm -f " + sockPath + "; "
        } else {
            // Fallback static mode when parallax is disabled
            script += "killall -9 -q mpvpaper 2>/dev/null; "
            script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; "
            if (activeOnly) {
                script += "set TARGET_MON (hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'); "
                script += "awww img -o \"$TARGET_MON\" '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; "
            } else if (targets.length > 0) {
                for (let i = 0; i < targets.length; i++) {
                    script += "awww img -o \"" + targets[i] + "\" '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; "
                }
            } else {
                script += "awww img '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; "
            }
        }

        if (configRef.enableIris) {
            if (isVid) {
                let fileName = cleanFilePath.split('/').pop()
                let baseName = fileName.replace(/\.[^/.]+$/, "")
                let thumbPath = Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + baseName + ".jpg"
                wpApplyProc.pendingIrisPath = thumbPath
                script += "test -f '" + thumbPath + "'; or ffmpeg -y -ss 00:00:01 -i '" + cleanFilePath + "' -vframes 1 -vf 'scale=600:-1' '" + thumbPath + "' >/dev/null 2>&1; "
                script += "iris '" + thumbPath + "'; "
            } else {
                wpApplyProc.pendingIrisPath = cleanFilePath
                script += "iris '" + cleanFilePath + "'; "
            }
        }

        wpApplyProc.command = ["fish", "-c", script]
        wpApplyProc.running = false
        wpApplyProc.running = true
    }

    function toggleWallpaperMonitor(screenName) {
        if (!configRef) return
        let current = configRef.selectedWallpaperMonitors ? configRef.selectedWallpaperMonitors.slice() : []
        let idx = current.indexOf(screenName)
        if (idx >= 0) current.splice(idx, 1)
        else current.push(screenName)
        configRef.selectedWallpaperMonitors = current
        configRef.saveSettings()
    }
}