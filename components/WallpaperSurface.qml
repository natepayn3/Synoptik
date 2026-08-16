import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

PanelWindow {
    id: wpWindow

    visible: Config.enableWallpaperParallax && (Config.wallpaperWorkspaceParallax || Config.wallpaperCursorParallax)

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-wallpaper-parallax"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: -1

    // Completely click-through region so desktop icons, apps, and window clicks pass straight through
    mask: Region {}

    readonly property string currentWallpaper: {
        let monName = screen ? screen.name : ""
        let wp = Config.getMonitorWallpaper(monName)
        if (!wp || wp === "") return Config.activeWallpaperPath || ""
        return wp
    }

    // Overscan margins for parallax motion
    readonly property real intensity: Math.max(0.1, Config.wallpaperParallaxIntensity)
    readonly property real overscanX: (width * 0.16) * intensity
    readonly property real overscanY: (height * 0.10) * intensity

    // -------------------------------------------------------------
    // 1. WORKSPACE SWITCH PARALLAX
    // -------------------------------------------------------------
    readonly property int activeWsId: {
        if (!Hyprland.focusedWorkspace) return 1
        return Math.max(1, Hyprland.focusedWorkspace.id)
    }

    // Number of virtual spaces to span
    readonly property int maxTrackedWorkspaces: 10

    // Calculates target shift for workspace panning (-overscanX to +overscanX)
    readonly property real wsPanProgress: {
        if (!Config.wallpaperWorkspaceParallax) return 0.5
        let clampedWs = Math.min(maxTrackedWorkspaces, Math.max(1, activeWsId))
        return (clampedWs - 1) / (maxTrackedWorkspaces - 1)
    }

    property real smoothWsOffsetX: 0.0
    property real targetWsOffsetX: {
        if (!Config.wallpaperWorkspaceParallax) return 0.0
        // Maps 0.0..1.0 progress to -overscanX/2 ... +overscanX/2
        return (wsPanProgress - 0.5) * -overscanX
    }

    Behavior on smoothWsOffsetX {
        NumberAnimation {
            duration: 450
            easing.type: Easing.OutCubic
        }
    }

    onTargetWsOffsetXChanged: {
        smoothWsOffsetX = targetWsOffsetX
    }

    // -------------------------------------------------------------
    // 2. CURSOR / MOUSE MOTION PARALLAX
    // -------------------------------------------------------------
    property real cursorNormX: 0.5
    property real cursorNormY: 0.5

    property real smoothCursorOffsetX: 0.0
    property real smoothCursorOffsetY: 0.0

    readonly property real targetCursorOffsetX: {
        if (!Config.wallpaperCursorParallax) return 0.0
        return (cursorNormX - 0.5) * (-overscanX * 0.35)
    }

    readonly property real targetCursorOffsetY: {
        if (!Config.wallpaperCursorParallax) return 0.0
        return (cursorNormY - 0.5) * (-overscanY * 0.45)
    }

    Behavior on smoothCursorOffsetX {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutQuad
        }
    }

    Behavior on smoothCursorOffsetY {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutQuad
        }
    }

    onTargetCursorOffsetXChanged: smoothCursorOffsetX = targetCursorOffsetX
    onTargetCursorOffsetYChanged: smoothCursorOffsetY = targetCursorOffsetY

    // Continuous real-time cursor tracker process (active only when cursor parallax is enabled)
    Process {
        id: cursorTrackerProc
        running: Config.enableWallpaperParallax && Config.wallpaperCursorParallax
        command: [
            "python3", "-u", "-c",
            "import subprocess, time\nwhile True:\n    try:\n        out = subprocess.check_output(['hyprctl', 'cursorpos'], text=True).strip()\n        print(out, flush=True)\n    except:\n        pass\n    time.sleep(0.033)\n"
        ]

        stdout: SplitParser {
            onRead: data => {
                if (!data || data.length === 0) return
                let parts = data.trim().split(",")
                if (parts.length >= 2) {
                    let cx = parseFloat(parts[0].trim())
                    let cy = parseFloat(parts[1].trim())

                    if (!isNaN(cx) && !isNaN(cy) && wpWindow.screen) {
                        let sw = wpWindow.screen.width || 1920
                        let sh = wpWindow.screen.height || 1080
                        let sx = wpWindow.screen.x || 0
                        let sy = wpWindow.screen.y || 0

                        let relX = (cx - sx) / sw
                        let relY = (cy - sy) / sh

                        wpWindow.cursorNormX = Math.max(0.0, Math.min(1.0, relX))
                        wpWindow.cursorNormY = Math.max(0.0, Math.min(1.0, relY))
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------
    // 3. WALLPAPER CANVAS & CROSSFADE IMAGE ENGINE
    // -------------------------------------------------------------
    Item {
        id: wallpaperCanvas
        anchors.centerIn: parent

        // Expand canvas width to cover combined workspace (0.5) + cursor (0.175) peak shifts
        width: parent.width + (overscanX * 1.5)
        height: parent.height + overscanY

        // Combined parallax coordinate offset
        transform: Translate {
            x: wpWindow.smoothWsOffsetX + wpWindow.smoothCursorOffsetX
            y: wpWindow.smoothCursorOffsetY
        }

        Image {
            id: imgPrimary
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: wpWindow.currentWallpaper !== "" 
                ? (wpWindow.currentWallpaper.startsWith("file://") ? wpWindow.currentWallpaper : "file://" + wpWindow.currentWallpaper) 
                : ""
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.06
        }
    }
}
