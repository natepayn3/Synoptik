import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: iconIndexService

    // Cached system icon indexer (loads ~/.cache/quickshell_icon_map.json or
    // builds it in the background) - previously duplicated verbatim between
    // AppLauncher.qml and LauncherOSD.qml.
    property var iconMap: ({})

    property Process indexer: Process {
        id: iconIndexer
        command: ["python3", "-c", `
import os, json

cache_file = os.path.expanduser("~/.cache/quickshell_icon_map.json")
if os.path.exists(cache_file):
    try:
        with open(cache_file, "r") as f:
            print(f.read())
            exit(0)
    except Exception:
        pass

dirs = [
    os.path.expanduser("~/.local/share/icons"),
    os.path.expanduser("~/.icons"),
    "/usr/share/icons/Papirus",
    "/usr/share/icons/Papirus-Dark",
    "/usr/share/icons/Papirus-Light",
    "/usr/share/icons/breeze",
    "/usr/share/icons/breeze-dark",
    "/usr/share/icons/Adwaita",
    "/usr/share/icons/hicolor",
    "/usr/share/pixmaps"
]
icon_map = {}
for d in dirs:
    if not os.path.isdir(d): continue
    for root, _, files in os.walk(d):
        if any(s in root for s in ["/16x16/", "/22x22/", "/24x24/", "/32x32/", "/symbolic/"]): continue
        for f in files:
            if f.endswith((".svg", ".png", ".xpm")):
                name = os.path.splitext(f)[0]
                if name not in icon_map:
                    icon_map[name] = os.path.join(root, f)

dumped = json.dumps(icon_map)
try:
    with open(cache_file, "w") as f:
        f.write(dumped)
except Exception:
    pass
print(dumped)
        `]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let clean = this.text.trim()
                    if (clean) {
                        iconIndexService.iconMap = JSON.parse(clean)
                    }
                } catch(e) {}
            }
        }
    }

    function getAppIcon(iconName) {
        if (!iconName) return Quickshell.iconPath("application-x-executable", true) || ""
        if (iconName.startsWith("/") || iconName.startsWith("file://")) {
            return iconName.startsWith("/") ? "file://" + iconName : iconName
        }
        if (iconIndexService.iconMap && iconIndexService.iconMap[iconName]) {
            return "file://" + iconIndexService.iconMap[iconName]
        }
        let qsPath = Quickshell.iconPath(iconName, true)
        if (qsPath) return qsPath
        return Quickshell.iconPath("application-x-executable", true) || ""
    }
}
