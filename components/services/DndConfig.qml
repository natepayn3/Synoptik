import QtQuick
import Quickshell
import Quickshell.Hyprland

// Do Not Disturb.
//
// This used to be a bare `property bool dnd: false` hanging off the
// NotificationServer in shell.qml, which meant three things: it reset to off
// every time the shell reloaded, the only way to see its state was to open the
// Control Center and look at the card, and it could only ever be driven by
// hand. It is a preference now, like every other preference, with the two
// automatic triggers people actually want.
QtObject {
    id: dndRoot

    property var configRef: null

    // The explicit toggle. Kept separate from `active` so that a schedule
    // window ending doesn't silently clear a DND the user turned on themselves,
    // and so the Control Center card has something real to write to.
    property bool dndManual: false

    property bool dndScheduleEnabled: false
    property int dndScheduleStart: 22 // 10 PM, 24h clock
    property int dndScheduleEnd: 7    // 7 AM, 24h clock

    // Presenting, gaming, watching something: the notification you don't want
    // is almost always the one that lands on top of a fullscreen window.
    property bool dndWhenFullscreen: false

    onDndManualChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onDndWhenFullscreenChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onDndScheduleEnabledChanged: {
        if (configRef && configRef.isLoaded) configRef.saveSettings()
        evaluateSchedule()
    }
    onDndScheduleStartChanged: {
        if (configRef && configRef.isLoaded) configRef.saveSettings()
        evaluateSchedule()
    }
    onDndScheduleEndChanged: {
        if (configRef && configRef.isLoaded) configRef.saveSettings()
        evaluateSchedule()
    }

    property bool scheduleActive: false

    // Same window arithmetic as AppearanceConfig.evaluateNightSchedule(),
    // including the wrap past midnight (22 -> 7).
    function evaluateSchedule() {
        if (!dndScheduleEnabled) {
            scheduleActive = false
            return
        }
        let h = new Date().getHours()
        let start = dndScheduleStart
        let end = dndScheduleEnd
        scheduleActive = start === end
            ? false
            : (start < end ? (h >= start && h < end) : (h >= start || h < end))
    }

    property Timer scheduleTimer: Timer {
        interval: 60000
        running: dndRoot.dndScheduleEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: dndRoot.evaluateSchedule()
    }

    // --- FULLSCREEN ---
    readonly property bool fullscreenActive: {
        if (!dndWhenFullscreen) return false
        let mon = Hyprland.focusedMonitor
        let ws = mon ? mon.activeWorkspace : null
        let ipc = ws ? ws.lastIpcObject : null
        return !!(ipc && ipc.hasfullscreen)
    }

    // hasfullscreen only updates when the workspace object is re-read, and
    // Hyprland doesn't push workspace state on every fullscreen toggle - so the
    // event is what prompts the re-read that the binding above depends on.
    property Connections hyprEvents: Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event && event.name === "fullscreen") Hyprland.refreshWorkspaces()
        }
    }

    // What the notification server actually reads. Any one trigger is enough;
    // none of them can cancel another, which is why turning DND on by hand
    // during a schedule window and then leaving it stays on.
    readonly property bool active: dndManual || scheduleActive || fullscreenActive

    // Why it's on, for the Control Center card and the bar indicator. Manual
    // wins the label when several apply, since that's the one the user set and
    // the one they can turn off from here.
    readonly property string reason: {
        if (dndManual) return "manual"
        if (scheduleActive) return "schedule"
        if (fullscreenActive) return "fullscreen"
        return ""
    }

    function toggle() {
        // With an automatic trigger holding DND on, a tap on the card means
        // "make it stop" - so it clears the trigger that's holding it rather
        // than setting a manual flag that changes nothing visible.
        if (!dndManual && active) {
            if (scheduleActive) dndScheduleEnabled = false
            if (fullscreenActive) dndWhenFullscreen = false
            return
        }
        dndManual = !dndManual
    }
}
