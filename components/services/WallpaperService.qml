import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: wallpaperService

    property var configRef: null
    property var onlineResults: []
    property bool isFetchingOnline: false

    // Inline Comment: Global async thumbnail pre-generator running purely in Fish
    property Process batchThumbProcess: Process {
        id: thumbBatchProc
        command: [
            "fish", "-c",
            "set -l cache_dir $HOME/.cache/wallpaper-thumbs; " +
            "test -d $cache_dir; or mkdir -p $cache_dir; " +
            "for f in ~/Pictures/Wallpapers/*.{mp4,webm}; " +
            "    test -f $f; or continue; " +
            "    set -l name (string replace -r '[^a-zA-Z0-9]' '_' (path basename $f))'.jpg'; " +
            "    if not test -f $cache_dir/$name; " +
            "        ffmpeg -y -ss 00:00:01 -i $f -vframes 1 -vf 'scale=720:-1' $cache_dir/$name >/dev/null 2>&1 &; " +
            "    end; " +
            "end; " +
            "wait"
        ]
        running: true
    }

    // Background Slideshow Process
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

    // Interval Timer for slideshow
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
                if (configRef && configRef.refreshActiveWallpapers) {
                    configRef.refreshActiveWallpapers()
                }
            }
        }
    }

    // Unified wallpaper dispatcher for Wayland (awww + mpvpaper + iris)
    function applyWallpaperBackend(filePath, activeOnly) {
        if (!filePath || !configRef) return

        let cleanFilePath = (typeof filePath === "string" ? filePath : filePath.toString()).replace(/^file:\/\//, "")
        configRef.activeWallpaperPath = cleanFilePath

        let ext = cleanFilePath.split('.').pop().toLowerCase()
        let isVid = (ext === "mp4" || ext === "webm")
        let waylandDisplay = Quickshell.env("WAYLAND_DISPLAY") || "wayland-1"
        let sockPath = "/run/user/" + Quickshell.env("UID") + "/" + waylandDisplay + "-awww-daemon.sock"
        let targets = activeOnly ? [] : (configRef.selectedWallpaperMonitors || []).filter(mon => Quickshell.screens.some(s => s.name === mon))
        let transition = configRef.wallpaperTransitionType || "fade"

        // Inline Comment: Kill stale video background processes before applying new wallpaper
        let script = "killall -q mpvpaper 2>/dev/null; "

        if (activeOnly) {
            script += "set TARGET_MON (hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'); "
            if (isVid) {
                script += "awww clear -o \"$TARGET_MON\" 2>/dev/null; "
                script += "pkill -f 'mpvpaper' 2>/dev/null; "
                script += "nohup mpvpaper -vs -o 'input-terminal=no loop-file=inf no-audio panscan=1.0 video-unscaled=no' \"$TARGET_MON\" '" + cleanFilePath + "' < /dev/null >/dev/null 2>&1 & disown; "
            } else {
                script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; "
                script += "awww img -o \"$TARGET_MON\" '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; "
            }
        } else if (targets.length > 0) {
            for (let i = 0; i < targets.length; i++) {
                let mon = targets[i]
                if (isVid) {
                    script += "awww clear -o \"" + mon + "\" 2>/dev/null; "
                    script += "pkill -f 'mpvpaper' 2>/dev/null; "
                    script += "nohup mpvpaper -vs -o 'input-terminal=no loop-file=inf no-audio panscan=1.0 video-unscaled=no' \"" + mon + "\" '" + cleanFilePath + "' < /dev/null >/dev/null 2>&1 & disown; "
                } else {
                    script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; "
                    script += "awww img -o \"" + mon + "\" '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; "
                }
            }
        } else {
            if (isVid) {
                script += "awww kill 2>/dev/null; killall -9 -q awww-daemon 2>/dev/null; rm -f " + sockPath + "; "
                script += "nohup mpvpaper -vs -o 'input-terminal=no loop-file=inf no-audio panscan=1.0 video-unscaled=no' '*' '" + cleanFilePath + "' < /dev/null >/dev/null 2>&1 & disown; "
            } else {
                script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; "
                script += "awww img '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; "
            }
        }

        // Inline Comment: Extract video frame or pass image straight to Iris color extraction
        if (configRef.enableIris) {
            if (isVid) {
                let fileName = cleanFilePath.split('/').pop()
                let thumbName = fileName.replace(/[^a-zA-Z0-9]/g, "_") + ".png"
                let thumbPath = Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + thumbName
                
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

    // Toggle Monitor Filter Target
    function toggleWallpaperMonitor(screenName) {
        if (!configRef) return
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

    // Wallhaven REST Search Provider
    function searchWallhaven(query, onComplete) {
        isFetchingOnline = true
        let url = "https://wallhaven.cc/api/v1/search?q=" + encodeURIComponent(query || "") + "&sorting=toplist&ratios=16x9,21x9&purity=100"
        let req = new XMLHttpRequest()
        req.open("GET", url)
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE) {
                isFetchingOnline = false
                if (req.status === 200) {
                    try {
                        let json = JSON.parse(req.responseText)
                        wallpaperService.onlineResults = json.data || []
                        if (onComplete) onComplete(wallpaperService.onlineResults)
                    } catch(e) {
                        wallpaperService.onlineResults = []
                    }
                }
            }
        }
        req.send()
    }

    // Download Wallhaven item directly to disk and apply
    function downloadAndApplyOnline(url, activeOnly) {
        let filename = url.split('/').pop()
        let dest = Quickshell.env("HOME") + "/Pictures/Wallpapers/" + filename
        let script = "test -f '" + dest + "'; or curl -s -L '" + url + "' -o '" + dest + "'"
        
        let dlProc = Qt.createQmlObject('import Quickshell.Io; Process {}', wallpaperService)
        dlProc.command = ["fish", "-c", script]
        dlProc.onExited.connect((exitCode) => {
            if (exitCode === 0) {
                applyWallpaperBackend(dest, activeOnly)
            }
            dlProc.destroy()
        })
        dlProc.running = true
    }
}