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
    // The two shapes an SNI's `icon` can take, and the theme check one of them
    // needs, are documented on IconIndexService.resolveIconSpec() - notifications
    // hit the same problem, so the logic lives there rather than here.
    function resolveIconSpec(spec) {
        return configRef ? configRef.iconIndexService.resolveIconSpec(spec) : ""
    }

    function iconFor(item) {
        if (!item) return ""
        let resolved = resolveIconSpec(item.icon)
        if (resolved) return resolved

        // The app's own icon, looked up the way a window of theirs would be -
        // but strictly, so an app with no icon at all returns "" rather than
        // the icon theme's generic placeholder. Every surface that draws a tray
        // item has a Material glyph behind it (TrayGroup, TaskOverflow's
        // background-apps list, the settings list), and that glyph follows the
        // shell's colours, while the theme's generic icon is a fixed-palette
        // asset - Adwaita's is hardcoded GNOME blue - that clashes with any
        // accent that isn't blue.
        if (configRef) return configRef.appIconStrict(keyFor(item))
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
