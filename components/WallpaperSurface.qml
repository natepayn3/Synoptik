import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: parallaxScope

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: wpWindow
            required property var modelData

            screen: modelData
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
            mask: Region {}

            function getDisplayWallpaper() {
                let monName = modelData ? modelData.name : ""
                let wp = Config.getMonitorWallpaper(monName) || Config.activeWallpaperPath || ""
                let clean = wp.replace(/^file:\/\//, "")
                let ext = clean.split('.').pop().toLowerCase()
                
                if (ext === "mp4" || ext === "webm") {
                    let baseName = clean.split('/').pop().replace(/\.[^/.]+$/, "")
                    return "file://" + Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + baseName + ".jpg"
                }
                return clean !== "" ? (clean.startsWith("file://") ? clean : "file://" + clean) : ""
            }

            readonly property real intensity: Math.max(0.1, Config.wallpaperParallaxIntensity)
            readonly property real overscanX: (width * 0.16) * intensity
            readonly property real overscanY: (height * 0.10) * intensity

            // ---------------- 1. WORKSPACE PARALLAX ----------------
            readonly property int activeWsId: {
                if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) {
                    return Math.max(1, Hyprland.focusedMonitor.activeWorkspace.id)
                }
                return 1
            }

            readonly property int maxTrackedWorkspaces: 10

            readonly property real wsPanProgress: {
                if (!Config.wallpaperWorkspaceParallax) return 0.5
                let clampedWs = Math.min(maxTrackedWorkspaces, Math.max(1, activeWsId))
                return (clampedWs - 1) / (maxTrackedWorkspaces - 1)
            }

            readonly property real targetWsOffsetX: Config.wallpaperWorkspaceParallax ? (wsPanProgress - 0.5) * -overscanX : 0.0
            property real smoothWsOffsetX: targetWsOffsetX

            Behavior on smoothWsOffsetX {
                NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
            }

            // ---------------- 2. CURSOR MOTION PARALLAX ----------------
            property real cursorNormX: 0.5
            property real cursorNormY: 0.5

            readonly property real targetCursorOffsetX: Config.wallpaperCursorParallax ? (cursorNormX - 0.5) * (-overscanX * 0.35) : 0.0
            readonly property real targetCursorOffsetY: Config.wallpaperCursorParallax ? (cursorNormY - 0.5) * (-overscanY * 0.45) : 0.0

            property real smoothCursorOffsetX: targetCursorOffsetX
            property real smoothCursorOffsetY: targetCursorOffsetY

            Behavior on smoothCursorOffsetX { NumberAnimation { duration: 260; easing.type: Easing.OutQuad } }
            Behavior on smoothCursorOffsetY { NumberAnimation { duration: 260; easing.type: Easing.OutQuad } }

            Process {
                id: cursorTrackerProc
                running: Config.enableWallpaperParallax && Config.wallpaperCursorParallax
                command: [
                    "fish", "-c",
                    "while true; hyprctl cursorpos; sleep 0.033; end"
                ]

                stdout: SplitParser {
                    onRead: data => {
                        if (!data || data.length === 0) return
                        let parts = data.trim().split(",")
                        if (parts.length >= 2) {
                            let cx = parseFloat(parts[0].trim())
                            let cy = parseFloat(parts[1].trim())

                            if (!isNaN(cx) && !isNaN(cy) && wpWindow.modelData) {
                                let hMon = Hyprland.monitorFor(wpWindow.modelData)
                                let monX = hMon ? hMon.x : 0
                                let monY = hMon ? hMon.y : 0
                                let sw = (hMon && hMon.width) ? hMon.width : (wpWindow.modelData.width || 1920)
                                let sh = (hMon && hMon.height) ? hMon.height : (wpWindow.modelData.height || 1080)

                                let relX = (cx - monX) / sw
                                let relY = (cy - monY) / sh

                                wpWindow.cursorNormX = Math.max(0.0, Math.min(1.0, relX))
                                wpWindow.cursorNormY = Math.max(0.0, Math.min(1.0, relY))
                            }
                        }
                    }
                }
            }

            // ---------------- 3. WALLPAPER CANVAS ----------------
            Item {
                id: wallpaperCanvas
                anchors.centerIn: parent

                width: parent.width + (overscanX * 1.5)
                height: parent.height + overscanY

                transform: Translate {
                    x: wpWindow.smoothWsOffsetX + wpWindow.smoothCursorOffsetX
                    y: wpWindow.smoothCursorOffsetY
                }

                Image {
                    id: imgPrimary
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: wpWindow.getDisplayWallpaper()
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
    }
}