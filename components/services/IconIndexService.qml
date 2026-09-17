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

    // appId (a Wayland app_id / X11 WM_CLASS) -> icon path, which is NOT the
    // same lookup as getAppIcon() below: an app_id is not an icon name. It has
    // to go through the desktop entry first, because the two agree far less
    // often than they look like they should - "org.gnome.Nautilus" ships its
    // icon as "org.gnome.Nautilus" but "Spotify" ships "com.spotify.Client",
    // and Chrome PWAs use a generated app_id no icon theme has ever heard of.
    //
    // Lives here rather than inline at each call site: this recipe was
    // copy-pasted verbatim three times (ActiveWindowCard's horizontal and
    // vertical layouts, and TaskOverflow's delegate), which meant a fix to the
    // fallback chain had to be made in three places and never was.
    function appIconFor(appId) {
        if (!appId) return genericIcon()

        let entry = DesktopEntries.heuristicLookup(appId)
        if (entry && entry.icon) {
            let themed = resolveIcon(entry.icon)
            if (themed) return themed
        }

        // No desktop entry, one with no Icon= key, or an Icon= naming a theme
        // entry that isn't actually installed: the app_id itself is still worth
        // trying as an icon name before giving up - plenty of terminal-launched
        // and Electron apps do match that way.
        return getAppIcon(appId)
    }

    // Shared body of getAppIcon(), minus its generic-executable fallback.
    // Returns "" when nothing resolves, so callers chaining several candidates
    // (see appIconFor) can tell "found nothing" apart from "found the generic
    // fallback" - getAppIcon alone cannot, since it answers with the fallback
    // icon either way.
    function resolveIcon(iconName) {
        if (!iconName) return ""
        if (iconName.startsWith("/") || iconName.startsWith("file://")) {
            return iconName.startsWith("/") ? "file://" + iconName : iconName
        }
        if (iconIndexService.iconMap && iconIndexService.iconMap[iconName]) {
            return "file://" + iconIndexService.iconMap[iconName]
        }
        return Quickshell.iconPath(iconName, true) || ""
    }

    function getAppIcon(iconName) {
        return resolveIcon(iconName) || genericIcon()
    }

    // Last-resort icon, resolved through the index FIRST.
    //
    // Quickshell.iconPath("application-x-executable", true) alone is not
    // enough: the `true` means "return nothing unless it exists", and whether
    // it exists depends on the active Qt icon theme rather than on what is
    // installed. On a box whose theme doesn't carry mimetype icons this
    // returned "", so every fallback path in the shell quietly produced an
    // empty source and drew nothing - which is how a tray item with an
    // unresolvable icon ended up as a blank gap in the task popout while the
    // bar, which happens to have a glyph of its own to fall back on, looked
    // fine. The index covers the icon directories on disk directly, so it
    // finds Adwaita's copy regardless of the theme setting.
    function genericIcon() {
        return resolveIcon("application-x-executable")
            || Quickshell.iconPath("application-x-executable", true)
            || ""
    }
}
