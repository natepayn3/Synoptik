import QtQuick
import Quickshell
import Quickshell.Io

// Persistent log of notifications as they arrive, independent of
// Quickshell's own trackedNotifications model - which drops a notification
// the moment it's dismissed or expires, leaving nothing to look back at.
// Capped by count (not time), kept until the user clears it - same model
// swaync/GNOME Shell/KDE Plasma use, as opposed to mako/dunst's small
// in-memory-only history that's wiped on daemon restart.
//
// Lives in its own file rather than settings.json: every new notification
// would otherwise trigger a full rewrite of the entire settings object just
// to append one log entry, which both bloats and adds needless write
// traffic to the file that's supposed to represent actual preferences.
QtObject {
    id: root

    readonly property int maxEntries: 100
    property var entries: [] // newest first
    property bool isLoaded: false

    // Deliberately NOT Config.shellDir: this service is constructed *by* the
    // Config singleton, so a binding that reads Config evaluates before the
    // singleton finishes constructing and throws "Config is not defined".
    // Quickshell.shellDir is the same value without the cycle.
    readonly property string historyPath:
        Quickshell.shellDir.toString().replace(/^file:\/\//, "") + "/notification_history.json"

    function record(notif) {
        if (!notif) return

        let entry = {
            appName: notif.appName || "System",
            summary: notif.summary || "",
            body: notif.body || "",
            timestamp: Date.now(),
            // shell.qml declares imageSupported/appIcon handling on the server
            // specifically so clients send album art, avatars and app icons -
            // and then none of it was recorded, so the History tab rendered a
            // wall of identical text while the OSD that had just shown the same
            // notification had artwork. Both are kept now; see sanitize() for
            // which of the two can survive a restart.
            appIcon: notif.appIcon || "",
            image: notif.image || "",
            // Urgency was read to drive the OSD's critical treatment and then
            // dropped on the floor here, so in the history list a
            // battery-critical warning was typographically identical to a
            // track change. Recorded as a plain int; Notifs.NotificationUrgency
            // is Low=0, Normal=1, Critical=2.
            urgency: (notif.urgency !== undefined) ? notif.urgency : 1
        }

        let list = entries.slice()
        list.unshift(entry)
        if (list.length > maxEntries) list.length = maxEntries
        entries = list
        save()
    }

    function clear() {
        if (entries.length === 0) return
        entries = []
        save()
    }

    function save() {
        if (!isLoaded) return
        saveTimer.restart()
    }

    // An entry's `image` is usually an image://qsimage/... URL backed by the
    // live Notification object's pixmap. That object is destroyed when the
    // notification is dismissed or expires, and the provider entry dies with
    // it, so writing that URL to disk would persist a link that resolves to
    // nothing the moment the shell restarts - worse than no image, because the
    // row would then reserve space for one.
    //
    // A real path (some clients pass image-path rather than raw pixel data)
    // does survive, and so does appIcon, which is a theme icon name or file
    // path rather than a handle to anything. So: keep everything in memory,
    // where the provider URL is still valid and the history list can use it,
    // and write only the parts that will still mean something next launch.
    function sanitize(list) {
        return list.map(e => {
            let img = e.image || ""
            let persistable = img.startsWith("/") || img.startsWith("file://")
            return {
                appName: e.appName,
                summary: e.summary,
                body: e.body,
                timestamp: e.timestamp,
                urgency: e.urgency,
                appIcon: e.appIcon || "",
                image: persistable ? img : ""
            }
        })
    }

    // Written through FileView rather than the `sh -c "printf '%s' '<json>' >
    // <path>"` Process this used to use - the same migration Config.qml's
    // settingsFile already went through, and for the same three reasons:
    //
    //   * atomicWrites. `>` truncates before it writes, so a crash or a
    //     `killall qs` mid-write left a half-written file and lost the lot.
    //     Settings' Reload button SIGKILLs the shell moments after a save can
    //     have been queued, which makes that window reachable in normal use.
    //
    //   * The path was interpolated into the command unquoted, so a checkout
    //     under a directory containing a space wrote nothing and scattered
    //     stray files - defeating the whole point of Config.shellDir, which
    //     exists so a renamed or XDG_CONFIG_HOME'd checkout keeps working.
    //
    //   * The entire JSON payload - up to 100 entries of arbitrary notification
    //     text - went through argv, hand-escaped.
    property FileView historyFile: FileView {
        id: historyFile
        path: root.historyPath
        atomicWrites: true
        printErrors: false

        onLoaded: {
            let text = historyFile.text()
            if (text && text.trim() !== "") {
                try {
                    let parsed = JSON.parse(text.trim())
                    if (Array.isArray(parsed)) root.entries = parsed
                } catch (e) {
                    console.error("Failed to parse notification history JSON:", e)
                }
            }
            root.isLoaded = true
        }

        // No history file yet is the normal first-run case, not an error.
        onLoadFailed: root.isLoaded = true
    }

    property Timer saveTimer: Timer {
        interval: 400
        repeat: false
        onTriggered: historyFile.setText(JSON.stringify(root.sanitize(root.entries), null, 2))
    }
}
