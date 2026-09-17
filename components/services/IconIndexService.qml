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

    readonly property string themeUrlPrefix: "image://icon/"

    // Resolve whatever an application hands over as "its icon", which arrives
    // in two very different shapes under one property:
    //
    //   image://icon/<name>  - a THEME NAME the app asked for. Quickshell will
    //       build this URL for a name the installed theme has never heard of,
    //       and the provider then answers with Qt's magenta missing-image
    //       pattern or nothing at all - either way Image.status says Ready, so
    //       nothing downstream can tell it failed. The name has to be checked
    //       against the theme BEFORE the URL reaches an Image.
    //   image://qsimage/... , file://... , /path  - real data. Always usable.
    //
    // Returns "" when nothing resolves, so callers can choose between a
    // fallback icon and drawing something else entirely.
    //
    // Lived in TrayService until notifications turned out to need it too: a
    // client passing `-i <name>` gets that same image://icon/ URL on
    // notif.image, so an unavailable name silently blanked the popup.
    function resolveIconSpec(spec) {
        let ic = spec || ""
        if (ic === "") return ""

        if (ic.startsWith(themeUrlPrefix)) {
            let name = ic.substring(themeUrlPrefix.length)
            if (name === "") return ""

            // The index is tried BEFORE the provider URL, because the two
            // disagree: hasThemeIcon("audio-headphones") answers true while the
            // provider then fails to produce a pixmap for it ("Could not load
            // icon ... from request"), presumably because the theme carries it
            // only at sizes the request doesn't match. The index resolves the
            // same icon to a concrete .svg on disk, which Image renders at any
            // size. A direct file is the more reliable of two paths to the same
            // artwork, so it wins.
            let indexed = resolveIcon(name)
            if (indexed) return indexed

            // Not indexed, but the theme claims it - worth letting the provider
            // try, since the index deliberately skips small and symbolic dirs.
            if (Quickshell.hasThemeIcon(name)) return ic
            return ""
        }

        if (ic.startsWith("image://") || ic.startsWith("file://") || ic.startsWith("/")) return ic
        return resolveIcon(ic)
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

    // appIconFor without the generic-executable last resort: "" when this app
    // has no icon of its own.
    //
    // Used wherever the surface has something better than a generic icon to
    // fall back to. The theme's generic icon is a fixed-palette asset -
    // Adwaita's is hardcoded GNOME blue - so it cannot follow the accent colour
    // and clashes with every theme that isn't blue; a Material glyph says the
    // same thing in the shell's own colours. Notifications and tray items both
    // draw such a glyph, so both resolve strictly.
    //
    // appIconFor() keeps the generic fallback for the callers that have no
    // glyph behind them - a window in the task list or on the bar, where an
    // empty source really would leave a blank.
    function appIconStrict(appId) {
        if (!appId) return ""
        let entry = DesktopEntries.heuristicLookup(appId)
        if (entry && entry.icon) {
            let themed = resolveIcon(entry.icon)
            if (themed) return themed
        }
        return resolveIcon(appId)
    }

    // The icon for one notification, wherever it is being drawn.
    //
    // Lives here because the popup and the Control Center list were resolving
    // it differently and disagreeing about the same notification: the OSD
    // handed notif.appIcon straight to an Image, which works for a path but
    // not for the icon NAME most clients send, so it silently fell through to
    // a glyph while the list - which resolved that name through the index -
    // showed the real thing.
    //
    // Takes a live Notification or a recorded history entry; both carry the
    // same four fields (NotificationHistoryService records them for exactly
    // this reason).
    function notificationIcon(notif) {
        if (!notif) return ""

        // What the client attached to THIS notification: album art, an avatar.
        // Most specific, so it wins - but only if it actually resolves, since
        // `notify-send -i <name>` lands here as an image://icon/ URL that may
        // name an icon the theme doesn't have.
        if (notif.image) {
            let attached = resolveIconSpec(notif.image)
            if (attached) return attached
        }

        // The icon the client declared for itself - a path or a theme name.
        if (notif.appIcon) {
            let declared = resolveIconSpec(notif.appIcon)
            if (declared) return declared
        }

        // Nothing declared: find the app. desktopEntry is the .desktop id and
        // so a far better lookup key than the display name, which is why it is
        // tried first.
        if (notif.desktopEntry) {
            let byEntry = appIconStrict(notif.desktopEntry.toLowerCase())
            if (byEntry) return byEntry
        }
        if (notif.appName) return appIconStrict(notif.appName.toLowerCase())

        // Deliberately no generic-executable fallback - see appIconStrict.
        return ""
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
