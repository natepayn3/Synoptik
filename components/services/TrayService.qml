import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// StatusNotifierItem host - the tray. Apps that close to a tray icon
// (Discord, Steam, Syncthing, KDE Connect, OBS) are invisible to everything
// else the shell knows about: Hyprland.toplevels only lists things that have a
// window, so TaskOverflow structurally cannot see them. This is the only
// surface that can.
//
// Quickshell's SystemTray singleton owns the D-Bus side. What lives here is
// the shell's own policy on top of it: which items ride the bar, which fold
// into the task popout, and how an item's icon is resolved when the app
// doesn't hand us a usable one.
QtObject {
    id: trayRoot

    property var configRef: null

    // --- PERSISTED PREFERENCES ---
    property bool showTray: true
    property bool trayCollapsed: false
    property var trayPinned: ({})

    // SNI's Passive status nominally means "nothing worth showing right now".
    // Off by default because the number of apps that set Passive and mean it is
    // smaller than the number that set it once at startup and never update it -
    // honouring it unconditionally makes icons vanish for no visible reason.
    property bool trayHidePassive: false

    onShowTrayChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onTrayCollapsedChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onTrayHidePassiveChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    // --- LIVE ITEMS ---
    readonly property var allItems: (SystemTray.items && SystemTray.items.values)
        ? SystemTray.items.values
        : []

    readonly property var items: {
        let list = allItems.slice()
        if (trayHidePassive) {
            list = list.filter(it => it && it.status !== Status.Passive)
        }
        // Stable ordering. The D-Bus registration order is whatever order apps
        // happened to start in, which means icons silently swap places after
        // every reboot; sorting by id keeps a given app in the same spot so the
        // muscle memory of "Discord is the third one" survives.
        list.sort((a, b) => trayRoot.keyFor(a).localeCompare(trayRoot.keyFor(b)))
        return list
    }

    // What actually rides the bar. Collapsed, that's the pinned items only;
    // everything else is still reachable in the task popout's tray section.
    readonly property var barItems: trayCollapsed
        ? items.filter(it => trayRoot.isPinned(it))
        : items

    readonly property int count: items.length

    // --- IDENTITY ---
    // The SNI id ("spotify", "steam", "chrome_status_icon_1") is the only
    // stable handle an item has across restarts - the D-Bus service name it
    // registers under is not, since it carries the PID. Title is the fallback
    // for the handful of items that register with an empty id.
    function keyFor(item) {
        if (!item) return ""
        return item.id || item.title || ""
    }

    function isPinned(item) {
        let k = keyFor(item)
        return k !== "" && !!trayPinned[k]
    }

    function togglePin(item) {
        let k = keyFor(item)
        if (k === "") return
        let next = Object.assign({}, trayPinned)
        if (next[k]) delete next[k]
        else next[k] = true
        trayPinned = next
        if (configRef) configRef.saveSettings()
    }

    // --- ICONS ---
    // An SNI hands over one of two very different things under the same
    // `icon` property, and they need opposite treatment:
    //
    //   image://icon/<name>  - a THEME NAME the app asked for. Quickshell will
    //       happily build this URL for a name the installed icon theme has
    //       never heard of, and the provider then answers with Qt's magenta
    //       "missing image" checkerboard. That is a successfully loaded image
    //       as far as Image.status is concerned, so a status-based fallback
    //       never fires and the bar shows two pink squares. The name has to be
    //       checked against the theme BEFORE the URL is handed to an Image.
    //
    //   image://qsimage/... - real pixmap data the app sent over D-Bus. Always
    //       usable, and always better than anything we could substitute.
    //
    // So: verify a theme name, and only then trust the URL. Anything that
    // doesn't resolve falls back through the shell's own icon index and then
    // the app-id lookup, the same path a window icon takes.
    readonly property string themeUrlPrefix: "image://icon/"

    // Shared by tray icons and by the icons on individual menu rows, which
    // arrive in exactly the same two forms and fail in exactly the same way.
    // Returns "" when nothing resolves, so callers can decide between a
    // fallback icon and drawing nothing at all.
    function resolveIconSpec(spec) {
        let ic = spec || ""
        if (ic === "") return ""

        if (ic.startsWith(themeUrlPrefix)) {
            let name = ic.substring(themeUrlPrefix.length)
            if (name !== "" && Quickshell.hasThemeIcon(name)) return ic
            // Named, but not installed. The shell's own index covers icon dirs
            // Qt's theme lookup doesn't (Papirus variants, pixmaps), so it gets
            // a turn before we give up on the name entirely.
            if (configRef) {
                let indexed = configRef.iconIndexService.resolveIcon(name)
                if (indexed) return indexed
            }
            return ""
        }

        if (ic.startsWith("image://") || ic.startsWith("file://") || ic.startsWith("/")) return ic
        if (configRef) return configRef.iconIndexService.resolveIcon(ic)
        return ""
    }

    function iconFor(item) {
        if (!item) return ""
        let resolved = resolveIconSpec(item.icon)
        if (resolved) return resolved
        // Nothing usable from the app: fall back to the same app-icon lookup a
        // window of theirs would get, rather than leaving a clickable blank.
        if (configRef) return configRef.appIconFor(keyFor(item))
        return ""
    }

    // Menu rows get no such fallback - a generic icon beside every row is
    // noisier than no icon at all, and the label already carries the meaning.
    function menuIconFor(spec) {
        return resolveIconSpec(spec)
    }

    // Tooltip text, preferring the tooltip the app supplies and falling back to
    // its title, so a hover always says something more useful than the id.
    function labelFor(item) {
        if (!item) return ""
        return item.tooltipTitle || item.title || keyFor(item)
    }

    function subLabelFor(item) {
        if (!item) return ""
        // tooltipDescription is allowed to contain a subset of HTML per the SNI
        // spec. Nothing here renders rich text, so strip tags rather than
        // printing "<b>3 unread</b>" at the user.
        return (item.tooltipDescription || "").replace(/<[^>]*>/g, "").trim()
    }

    // Left click. Items that advertise onlyMenu have no activate() behaviour at
    // all - invoking it is a no-op that reads as a dead icon, so those open
    // their menu instead. Callers pass openMenu so this one decision lives in
    // one place rather than in each surface that shows a tray icon.
    function primaryAction(item, openMenu) {
        if (!item) return
        if (item.onlyMenu || (!item.id && item.hasMenu)) {
            if (item.hasMenu && openMenu) openMenu(item)
            return
        }
        item.activate()
    }
}
