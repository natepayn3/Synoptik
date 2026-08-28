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

    readonly property string historyPath: Quickshell.shellDir.toString().replace(/^file:\/\//, "") + "/notification_history.json"

    function record(notif) {
        if (!notif) return

        let entry = {
            appName: notif.appName || "System",
            summary: notif.summary || "",
            body: notif.body || "",
            timestamp: Date.now()
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

    property Process saveProcess: Process { id: saver }

    property Timer saveTimer: Timer {
        interval: 400
        repeat: false
        onTriggered: {
            if (saver.running) {
                saveTimer.restart()
                return
            }
            let jsonStr = JSON.stringify(root.entries, null, 2)
            saver.command = ["fish", "-c", "printf '%s' '" + jsonStr.replace(/'/g, "'\\''") + "' > " + root.historyPath]
            saver.running = true
        }
    }

    property Process loaderProcess: Process {
        id: loader
        command: ["fish", "-c", "cat " + root.historyPath + " 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text ? this.text.trim() : ""
                if (text !== "") {
                    try {
                        let parsed = JSON.parse(text)
                        if (Array.isArray(parsed)) root.entries = parsed
                    } catch (e) {
                        console.error("Failed to parse notification history JSON:", e)
                    }
                }
                root.isLoaded = true
            }
        }
        Component.onCompleted: running = true
    }
}
