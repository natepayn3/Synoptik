import QtQuick
import Quickshell
import Quickshell.Hyprland

// Automatic display arrangement on dock/undock - the kanshi behaviour, built
// on the configuration profiles the shell already has.
//
// DisplaySettings.qml can already describe a monitor completely (mode,
// position, scale, transform, HDR, bit depth) and writes it out as hl.monitor
// blocks, and Config's profile system can already snapshot and restore the
// entire shell configuration, exposed over IPC as `profile load <name>`.
// What was missing was the trigger: plug a monitor in and you still had to go
// and apply the right arrangement by hand.
//
// So this is deliberately thin. It does not own any display state; it watches
// what is physically connected, and when that set changes to one the user has
// taught it about, it calls the existing Config.loadProfile().
QtObject {
    id: root

    property var configRef: null

    // topology key -> profile name. Persisted via Config.persistedKeys.
    property var displayProfileMap: ({})

    // Master switch, so someone who wants the mapping remembered but not acted
    // on (or who is mid-rearrangement) can stop it firing.
    property bool autoSwitchEnabled: true

    // A monitor's name (DP-1, HDMI-A-1) is assigned in connection order, so the
    // same physical display can come back as a different name after a reboot or
    // a dock swap. make/model/serial identify the panel itself. Serial is blank
    // on plenty of panels - this one included - so fall back through
    // description and finally name rather than collapsing every serial-less
    // display onto one key.
    function monitorKey(m) {
        if (!m) return ""
        let serial = (m.serial || "").trim()
        let make = (m.make || "").trim()
        let model = (m.model || "").trim()

        if (serial !== "" && model !== "") return make + "|" + model + "|" + serial
        let desc = (m.description || "").trim()
        if (desc !== "") return "desc:" + desc
        return "name:" + (m.name || "?")
    }

    // Sorted so the key describes the *set* of connected displays, not the
    // order Hyprland happened to enumerate them in.
    readonly property string topologyKey: {
        let mons = Hyprland.monitors ? Hyprland.monitors.values : []
        let keys = []
        for (let i = 0; i < mons.length; i++) {
            let k = root.monitorKey(mons[i])
            if (k !== "") keys.push(k)
        }
        keys.sort()
        return keys.join(" + ")
    }

    readonly property int monitorCount: Hyprland.monitors ? Hyprland.monitors.values.length : 0

    // A human-readable version of the current topology, for the settings UI.
    readonly property string topologyLabel: {
        let mons = Hyprland.monitors ? Hyprland.monitors.values : []
        let names = []
        for (let i = 0; i < mons.length; i++) {
            let m = mons[i]
            let model = (m.model || "").trim()
            names.push(model !== "" && !model.startsWith("0x") ? model : m.name)
        }
        names.sort()
        if (names.length === 0) return "No displays"
        return names.join(" + ")
    }

    readonly property string profileForCurrentTopology:
        root.displayProfileMap[root.topologyKey] || ""

    readonly property bool currentTopologyRemembered:
        root.profileForCurrentTopology !== ""

    // --- MAPPING ---

    function rememberCurrent(profileName) {
        if (!root.configRef) return
        let name = profileName || root.configRef.activeProfile
        if (!name || name === "") return
        if (root.topologyKey === "") return

        let next = Object.assign({}, root.displayProfileMap)
        next[root.topologyKey] = name
        root.displayProfileMap = next
        // Remembering the mapping is itself a setting, and it lives in
        // settings.json - which a profile load overwrites wholesale. Written
        // immediately so a load triggered moments later can't lose it.
        root.configRef.saveSettings()
    }

    function forgetCurrent() {
        if (!root.displayProfileMap[root.topologyKey]) return
        let next = Object.assign({}, root.displayProfileMap)
        delete next[root.topologyKey]
        root.displayProfileMap = next
        if (root.configRef) root.configRef.saveSettings()
    }

    function forgetKey(key) {
        if (!root.displayProfileMap[key]) return
        let next = Object.assign({}, root.displayProfileMap)
        delete next[key]
        root.displayProfileMap = next
        if (root.configRef) root.configRef.saveSettings()
    }

    readonly property var rememberedKeys: Object.keys(root.displayProfileMap || {})

    // --- AUTO-SWITCH ---

    property string lastAppliedTopology: ""

    // Hyprland emits a burst of monitor events during a hotplug (removed, then
    // added, then geometry), and applying a profile mid-burst can act on a
    // half-settled topology. Wait for it to stop moving.
    property Timer settleTimer: Timer {
        interval: 1200
        repeat: false
        onTriggered: root.applyForCurrentTopology()
    }

    function applyForCurrentTopology() {
        if (!root.autoSwitchEnabled) return
        if (!root.configRef || !root.configRef.isLoaded) return
        if (root.topologyKey === "") return

        // Nothing actually changed - a monitor property twitched, or we already
        // applied for this exact set.
        if (root.topologyKey === root.lastAppliedTopology) return

        let target = root.displayProfileMap[root.topologyKey]
        if (!target || target === "") {
            // Unknown topology: remember that we've seen it so a later
            // property twitch doesn't re-trigger, but change nothing.
            root.lastAppliedTopology = root.topologyKey
            return
        }

        // Already on that profile - loading it again would pointlessly rewrite
        // settings.json and restart the shell's whole appearance sync.
        if (root.configRef.activeProfile === target) {
            root.lastAppliedTopology = root.topologyKey
            return
        }

        root.lastAppliedTopology = root.topologyKey
        root.configRef.loadProfile(target)
    }

    onTopologyKeyChanged: {
        if (root.topologyKey === "") return
        settleTimer.restart()
    }

    // Settings load asynchronously, so the topology at startup is usually known
    // before displayProfileMap is. Re-check once it lands.
    property Connections configConn: Connections {
        target: root.configRef
        ignoreUnknownSignals: true
        function onIsLoadedChanged() {
            if (root.configRef && root.configRef.isLoaded) settleTimer.restart()
        }
    }
}
