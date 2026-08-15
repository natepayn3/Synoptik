import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: wallpaperService

    property var configRef: null

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
            "python3", "-c",
            "import os, random; d=os.path.expanduser('~/Pictures/Wallpapers'); files=[os.path.join(d, f) for f in os.listdir(d) if f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp', '.mp4', '.webm'))] if os.path.isdir(d) else []; print(random.choice(files) if files else '')"
        ]
        bgSlideshowProc.running = false
        bgSlideshowProc.running = true
    }

    property Process wallpaperApplyRunner: Process {
        id: wpApplyProc
        running: false
    }

    function applyWallpaperBackend(filePath, activeOnly) {
        if (!filePath || !configRef) return;

        let cleanFilePath = (typeof filePath === "string" ? filePath : filePath.toString()).replace(/^file:\/\//, "");
        configRef.activeWallpaperPath = cleanFilePath;

        let ext = cleanFilePath.split('.').pop().toLowerCase()
        let waylandDisplay = Quickshell.env("WAYLAND_DISPLAY") || "wayland-1"
        let sockPath = "/run/user/" + Quickshell.env("UID") + "/" + waylandDisplay + "-awww-daemon.sock"
        let targets = activeOnly ? [] : (configRef.selectedWallpaperMonitors || []).filter(mon => Quickshell.screens.some(s => s.name === mon));
        let transition = configRef.wallpaperTransitionType || "fade"

        let script = "killall -q mpvpaper 2>/dev/null; "

        if (activeOnly) {
            script += "set TARGET_MON (hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'); "
            if (ext === "mp4" || ext === "webm") {
                script += "awww clear -o \"$TARGET_MON\" 2>/dev/null; "
                script += "pkill -f 'mpvpaper' 2>/dev/null; "
                script += "nohup mpvpaper -vs -o 'input-terminal=no loop-file=inf no-audio panscan=1.0 video-unscaled=no' \"$TARGET_MON\" '" + cleanFilePath + "' < /dev/null >/dev/null 2>&1 & disown; "
            } else {
                script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; "
                script += "awww img -o \"$TARGET_MON\" '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; "
            }
        } else if (targets.length > 0) {
            for (let i = 0; i < targets.length; i++) {
                let mon = targets[i];
                if (ext === "mp4" || ext === "webm") {
                    script += "awww clear -o \"" + mon + "\" 2>/dev/null; "
                    script += "pkill -f 'mpvpaper' 2>/dev/null; "
                    script += "nohup mpvpaper -vs -o 'input-terminal=no loop-file=inf no-audio panscan=1.0 video-unscaled=no' \"" + mon + "\" '" + cleanFilePath + "' < /dev/null >/dev/null 2>&1 & disown; "
                } else {
                    script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; "
                    script += "awww img -o \"" + mon + "\" '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; "
                }
            }
        } else {
            if (ext === "mp4" || ext === "webm") {
                script += "awww kill 2>/dev/null; killall -9 -q awww-daemon 2>/dev/null; rm -f " + sockPath + "; "
                script += "nohup mpvpaper -vs -o 'input-terminal=no loop-file=inf no-audio panscan=1.0 video-unscaled=no' '*' '" + cleanFilePath + "' < /dev/null >/dev/null 2>&1 & disown; "
            } else {
                script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; "
                script += "awww img '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; "
            }
        }

        wpApplyProc.command = ["fish", "-c", script]
        wpApplyProc.running = false
        wpApplyProc.running = true
    }

    function toggleWallpaperMonitor(screenName) {
        if (!configRef) return;
        let current = configRef.selectedWallpaperMonitors ? configRef.selectedWallpaperMonitors.slice() : []
        let idx = current.indexOf(screenName)

        if (idx >= 0) {
            current.splice(idx, 1)
        } else {
            current.push(screenName)
        }

        configRef.selectedWallpaperMonitors = current
        configRef.saveSettings()
    }
}
