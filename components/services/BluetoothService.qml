import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Single source of truth for Bluetooth state, shared by the Control Center's
// BluetoothCard and Settings' BluetoothSettings.
//
// Those two used to carry a complete implementation each - ~1,900 lines between
// them, with their own `bluetoothctl` Process sets, their own scan timers and
// their own copies of getDeviceIcon()/batteryGlyph()/batteryColor(). The copies
// had already drifted: a Bose QuietComfort matched "bose" in the *headphone*
// list in one file and the *speaker* list in the other, so the same device drew
// a different icon depending on which panel you opened, and only one of the two
// knew about laptops or Joy-Cons. The lists below are the merged union, kept
// once. This is the same failure the comment on Config.panelFlagByView
// describes for the old hand-maintained panel close lists.
//
// The process layer is gone entirely: Quickshell 0.3's Quickshell.Bluetooth
// talks to BlueZ over D-Bus directly, so there is no polling timer, no
// `bluetoothctl info` text parsing, no shell quoting of MAC addresses, and
// state changes arrive as property notifications instead of on a 2s tick.
QtObject {
    id: root

    property var configRef: null

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!root.adapter

    // BlueZ reports enabling/disabling as distinct states; treat both
    // transitional states as "on" so the toggle doesn't visibly bounce back
    // while the adapter is still coming up.
    readonly property bool powered: root.adapter
        ? (root.adapter.enabled
            || root.adapter.state === BluetoothAdapterState.Enabling)
        : false

    readonly property bool scanning: root.adapter ? root.adapter.discovering : false

    // MAC of the device currently mid-connect or mid-pair, for spinner state.
    // Derived from the devices themselves rather than set by the caller, so it
    // stays correct when a connection is initiated from outside the shell.
    property string connectingMac: ""

    // Comma-joined names of every connected device - what the collapsed card
    // subtitle shows.
    property string connectedNames: ""

    // ListModel rather than a plain array so both views keep their existing
    // `model: btModel` / `model.mac` delegates and their scroll position
    // across updates. Roles match what those delegates already expect.
    property ListModel devices: ListModel {}

    // --- ICONOGRAPHY (merged from the two drifted copies) ---

    // Material Symbols has a discrete glyph per battery level rather than one
    // fillable icon, so map the percentage onto the nearest bar. Mirrors the
    // levels the desktop battery module already uses.
    function batteryGlyph(pct) {
        if (pct < 0) return ""
        if (pct >= 95) return "battery_full"
        if (pct >= 85) return "battery_6_bar"
        if (pct >= 70) return "battery_5_bar"
        if (pct >= 55) return "battery_4_bar"
        if (pct >= 40) return "battery_3_bar"
        if (pct >= 25) return "battery_2_bar"
        if (pct >= 10) return "battery_1_bar"
        return "battery_alert"
    }

    function batteryColor(pct) {
        if (pct < 0) return Config.textMuted
        if (pct <= 10) return "#e0564f"
        if (pct <= 25) return "#e0a24f"
        return Config.textMuted
    }

    // BlueZ supplies a freedesktop icon name on every device, which is more
    // reliable than guessing from the product name - but it's coarse
    // ("audio-headset" covers every headset ever made) and some devices report
    // nothing at all. So: trust the BlueZ class first, fall back to the name
    // match. The name lists are the union of the two that had drifted apart.
    function getDeviceIcon(name, bluezIcon) {
        let hinted = root.iconFromBluez(bluezIcon)
        if (hinted !== "") return hinted

        let n = (name || "").toLowerCase()
        if (n.includes("headphone") || n.includes("headset") || n.includes("buds")
            || n.includes("airpod") || n.includes("pods") || n.includes("wh-")
            || n.includes("wf-") || n.includes("quietcomfort") || n.includes("bose")
            || n.includes("sony") || n.includes("audio") || n.includes("ear")
            || n.includes("freebuds")) return "headphones"
        if (n.includes("speaker") || n.includes("soundbar") || n.includes("echo")
            || n.includes("jbl") || n.includes("marshall")) return "speaker"
        if (n.includes("mouse") || n.includes("mx master") || n.includes("mx anywhere")
            || n.includes("trackball") || n.includes("trackpad")
            || n.includes("touchpad")) return "mouse"
        if (n.includes("keyboard") || n.includes("keychron") || n.includes("nuphy")
            || n.includes("logi k") || n.includes("magic keyboard")) return "keyboard"
        if (n.includes("watch") || n.includes("band") || n.includes("garmin")
            || n.includes("fitbit")) return "watch"
        if (n.includes("phone") || n.includes("iphone") || n.includes("pixel")
            || n.includes("galaxy") || n.includes("android")) return "smartphone"
        if (n.includes("tv") || n.includes("chromecast") || n.includes("appletv")) return "tv"
        if (n.includes("gamepad") || n.includes("controller") || n.includes("dualshock")
            || n.includes("dualsense") || n.includes("xbox") || n.includes("joy-con")
            || n.includes("switch")) return "sports_esports"
        if (n.includes("macbook") || n.includes("laptop") || n.includes("thinkpad")
            || n.includes("desktop") || n.includes("pc")) return "computer"
        return "bluetooth"
    }

    function iconFromBluez(bluezIcon) {
        let i = (bluezIcon || "").toLowerCase()
        if (i === "") return ""
        if (i.includes("headset") || i.includes("headphone")) return "headphones"
        if (i.includes("audio-card") || i.includes("speaker")) return "speaker"
        if (i.includes("input-mouse")) return "mouse"
        if (i.includes("input-keyboard")) return "keyboard"
        if (i.includes("input-gaming")) return "sports_esports"
        if (i.includes("input-tablet")) return "tablet"
        if (i.includes("phone")) return "smartphone"
        if (i.includes("video-display") || i.includes("tv")) return "tv"
        if (i.includes("computer")) return "computer"
        if (i.includes("watch")) return "watch"
        if (i.includes("printer")) return "print"
        return ""
    }

    // --- ACTIONS ---
    // Every one of these was a `sh -c "bluetoothctl <verb> '<mac>'"` spawn in
    // both view files. They are now direct D-Bus calls, which also removes the
    // MAC-into-shell-string interpolation those carried.

    function setPowered(on) {
        if (root.adapter) root.adapter.enabled = on
    }

    function togglePower() {
        root.setPowered(!root.powered)
    }

    function startScan() {
        if (!root.adapter || !root.powered || root.adapter.discovering) return
        root.adapter.discovering = true
        scanStopTimer.restart()
    }

    function stopScan() {
        if (root.adapter && root.adapter.discovering) root.adapter.discovering = false
        scanStopTimer.stop()
    }

    // bluetoothctl's `--timeout 6 scan on` bounded discovery for us; the D-Bus
    // API leaves it running until told otherwise, so keep the same bounded
    // behaviour rather than leaving the radio scanning indefinitely.
    property Timer scanStopTimer: Timer {
        interval: 12000
        repeat: false
        onTriggered: root.stopScan()
    }

    function deviceFor(mac) {
        if (!root.adapter) return null
        let list = root.adapter.devices.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].address === mac) return list[i]
        }
        return null
    }

    function connectDevice(mac) {
        let d = root.deviceFor(mac)
        if (!d) return
        root.connectingMac = mac
        d.connect()
    }

    function disconnectDevice(mac) {
        let d = root.deviceFor(mac)
        if (d) d.disconnect()
    }

    // bluetoothctl needed three chained verbs here (pair; trust; connect).
    // BlueZ auto-connects after a successful pair, so this only has to mark the
    // device trusted once pairing lands - see onPairedChanged in the watcher.
    function pairDevice(mac) {
        let d = root.deviceFor(mac)
        if (!d) return
        root.connectingMac = mac
        d.pair()
    }

    function forgetDevice(mac) {
        let d = root.deviceFor(mac)
        if (!d) return
        if (d.connected) d.disconnect()
        d.forget()
    }

    // --- DEVICE MODEL SYNC ---
    // Coalesced: a single connect can fire connected/state/battery/name
    // notifications in the same tick, and BlueZ churns properties hard during
    // discovery. One rebuild per event loop turn is plenty.
    property Timer syncTimer: Timer {
        interval: 0
        repeat: false
        onTriggered: root.syncNow()
    }

    function scheduleSync() { syncTimer.restart() }

    function syncNow() {
        if (!root.adapter || !root.powered) {
            root.devices.clear()
            root.connectedNames = ""
            root.connectingMac = ""
            return
        }

        let src = root.adapter.devices.values
        let rows = []
        let connected = []

        for (let i = 0; i < src.length; i++) {
            let d = src[i]
            if (!d || !d.address) continue

            // Quickshell reports battery as a 0.0-1.0 fraction and flags
            // whether the device exposes the service at all. -1 means "no
            // reading" so the UI omits the readout rather than showing a
            // misleading 0%.
            let batt = -1
            if (d.batteryAvailable && d.battery >= 0) {
                batt = Math.round(d.battery <= 1.0 ? d.battery * 100 : d.battery)
                if (isNaN(batt) || batt < 0 || batt > 100) batt = -1
            }

            let nm = d.name || d.deviceName || d.address

            // Unpaired devices only appear while discovery is running; once it
            // stops, BlueZ keeps reporting them for a while. Showing a stale
            // list of everything that walked past is worse than showing
            // nothing, so drop unpaired entries when not scanning.
            if (!d.paired && !d.bonded && !root.scanning && !d.connected) continue

            if (d.connected) connected.push(nm)

            rows.push({
                mac: d.address,
                name: nm,
                connected: d.connected,
                paired: d.paired || d.bonded,
                pairing: d.pairing,
                trusted: d.trusted,
                battery: batt,
                icon: root.getDeviceIcon(nm, d.icon),
                // Only Bluetooth audio devices have switchable card profiles;
                // this gates the profile row in the UI without every delegate
                // re-deriving it.
                isAudio: root.isAudioIcon(root.getDeviceIcon(nm, d.icon))
            })
        }

        // Connected first, then paired, then the rest - alphabetical inside
        // each band so the list doesn't reshuffle on every battery tick.
        rows.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.paired !== b.paired) return a.paired ? -1 : 1
            return a.name.localeCompare(b.name)
        })

        root.applyRows(rows)
        root.connectedNames = connected.length > 0 ? connected.join(", ") : ""

        // Clear the spinner once the device it referred to settled either way.
        if (root.connectingMac !== "") {
            let d = root.deviceFor(root.connectingMac)
            if (!d || (!d.pairing && d.state !== BluetoothDeviceState.Connecting)) {
                root.connectingMac = ""
            }
        }
    }

    function isAudioIcon(icon) {
        return icon === "headphones" || icon === "speaker"
    }

    // In-place reconciliation rather than clear()+append(): a ListView bound to
    // this keeps its scroll offset, its expanded row and its delegate instances
    // instead of rebuilding on every battery notification.
    function applyRows(rows) {
        let m = root.devices

        let existing = {}
        for (let i = 0; i < m.count; i++) existing[m.get(i).mac] = i

        let fresh = {}
        for (let i = 0; i < rows.length; i++) {
            let r = rows[i]
            fresh[r.mac] = true
            if (r.mac in existing) {
                let idx = existing[r.mac]
                let cur = m.get(idx)
                Object.keys(r).forEach(k => {
                    if (cur[k] !== r[k]) m.setProperty(idx, k, r[k])
                })
            } else {
                m.append(r)
            }
        }

        for (let i = m.count - 1; i >= 0; i--) {
            if (!fresh[m.get(i).mac]) m.remove(i)
        }
    }

    // One delegate per device, existing only to turn that device's property
    // notifications into a resync. Without this the model would only update
    // when devices are added or removed, never when one connects or its
    // battery moves.
    property Instantiator deviceWatcher: Instantiator {
        model: root.adapter ? root.adapter.devices : null
        delegate: QtObject {
            required property var modelData

            readonly property bool wConnected: modelData ? modelData.connected : false
            readonly property bool wPaired: modelData ? modelData.paired : false
            readonly property bool wBonded: modelData ? modelData.bonded : false
            readonly property bool wPairing: modelData ? modelData.pairing : false
            readonly property real wBattery: modelData ? modelData.battery : -1
            readonly property bool wBattAvail: modelData ? modelData.batteryAvailable : false
            readonly property string wName: modelData ? modelData.name : ""
            readonly property int wState: modelData ? modelData.state : 0

            onWConnectedChanged: {
                root.scheduleSync()
                // Card profiles only exist while the device is connected.
                root.refreshAudioProfiles()
            }
            onWPairedChanged: {
                // bluetoothctl's old pair/trust/connect chain trusted the
                // device explicitly; do the same here so it reconnects on its
                // own next time without re-pairing.
                if (wPaired && modelData && !modelData.trusted) modelData.trusted = true
                root.scheduleSync()
            }
            onWBondedChanged: root.scheduleSync()
            onWPairingChanged: root.scheduleSync()
            onWBatteryChanged: root.scheduleSync()
            onWBattAvailChanged: root.scheduleSync()
            onWNameChanged: root.scheduleSync()
            onWStateChanged: root.scheduleSync()
        }
        onObjectAdded: root.scheduleSync()
        onObjectRemoved: root.scheduleSync()
    }

    // Adapter-level changes (powered off, scan start/stop) also change what the
    // list should contain.
    property Connections adapterConn: Connections {
        target: root
        function onPoweredChanged() {
            root.scheduleSync()
            root.refreshAudioProfiles()
        }
        function onScanningChanged() { root.scheduleSync() }
        function onAvailableChanged() { root.scheduleSync() }
    }

    // ---------------------------------------------------------------
    // AUDIO PROFILE SWITCHING (A2DP <-> HSP/HFP)
    // ---------------------------------------------------------------
    // The gap this closes: joining a call switches a headset to the
    // headset-head-unit profile (16kHz mono, mic live) and nothing switches it
    // back, so music afterwards plays through a telephone. Every other desktop
    // exposes this; Synoptik previously required pavucontrol.
    //
    // PipeWire models it as a card profile, not a Bluetooth property, so this
    // is the one part of Bluetooth handling that still goes through pactl -
    // Quickshell.Services.Pipewire exposes nodes and links but not card
    // profiles. `pactl -f json` means no output-format parsing.

    // mac (colon form) -> { card: string, active: string, profiles: [{name, description}] }
    property var audioProfiles: ({})

    function profilesFor(mac) {
        let e = root.audioProfiles[mac]
        return e ? e.profiles : []
    }

    function activeProfileFor(mac) {
        let e = root.audioProfiles[mac]
        return e ? e.active : ""
    }

    function hasProfilesFor(mac) {
        return root.profilesFor(mac).length > 1
    }

    // Friendly label for a raw PipeWire profile name. The raw names leak codec
    // detail that isn't useful mid-call ("a2dp-sink-aptx_hd"), so lead with
    // what the profile is *for* and keep the codec as a suffix.
    function profileLabel(name) {
        let n = (name || "").toLowerCase()
        if (n === "off") return "Off"
        if (n.startsWith("a2dp-sink")) {
            let codec = n.replace("a2dp-sink", "").replace(/^[-_]/, "")
            return codec === "" ? "High Fidelity" : "High Fidelity (" + codec.toUpperCase().replace(/_/g, " ") + ")"
        }
        if (n.startsWith("headset-head-unit") || n.startsWith("handsfree-head-unit")) {
            let codec = n.replace(/^(headset|handsfree)-head-unit/, "").replace(/^[-_]/, "")
            return codec === "" ? "Headset (Mic)" : "Headset (" + codec.toUpperCase() + ")"
        }
        if (n.startsWith("a2dp-source")) return "Audio Source"
        return name
    }

    function profileIcon(name) {
        let n = (name || "").toLowerCase()
        if (n === "off") return "volume_off"
        if (n.startsWith("a2dp-sink")) return "graphic_eq"
        if (n.startsWith("headset") || n.startsWith("handsfree")) return "mic"
        return "tune"
    }

    function setAudioProfile(mac, profile) {
        let e = root.audioProfiles[mac]
        if (!e || !e.card || !profile) return

        // Optimistic local update so the selected pill highlights immediately;
        // the refresh below confirms it against what PipeWire actually did.
        let next = Object.assign({}, root.audioProfiles)
        next[mac] = Object.assign({}, e, { active: profile })
        root.audioProfiles = next

        // argv, not a shell string: the card name is derived from a MAC and the
        // profile from PipeWire, but neither needs quoting if there is no shell.
        profileSetProc.command = ["pactl", "set-card-profile", e.card, profile]
        profileSetProc.running = true
    }

    property Process profileSetProc: Process {
        id: profileSetProc
        running: false
        onExited: root.refreshAudioProfiles()
    }

    function refreshAudioProfiles() {
        if (!profileFetchProc.running) profileFetchProc.running = true
    }

    property Process profileFetchProc: Process {
        id: profileFetchProc
        command: ["pactl", "-f", "json", "list", "cards"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                profileFetchProc.running = false
                let map = {}
                try {
                    let cards = JSON.parse(this.text || "[]")
                    for (let i = 0; i < cards.length; i++) {
                        let c = cards[i]
                        let nm = c.name || ""
                        if (!nm.startsWith("bluez_card.")) continue

                        // bluez_card.AA_BB_CC_DD_EE_FF -> AA:BB:CC:DD:EE:FF
                        let mac = nm.substring("bluez_card.".length).replace(/_/g, ":").toUpperCase()

                        let profs = []
                        let raw = c.profiles || {}
                        Object.keys(raw).forEach(pn => {
                            let p = raw[pn] || {}
                            // available === false means the peer doesn't offer
                            // it right now; listing it would just produce a
                            // button that silently fails.
                            if (p.available === false) return
                            profs.push({ name: pn, description: p.description || pn })
                        })

                        // High fidelity first, then headset, then anything
                        // else, with Off last - matches how the pills read.
                        profs.sort((a, b) => root.profileRank(a.name) - root.profileRank(b.name))

                        map[mac] = {
                            card: nm,
                            active: c.active_profile || "",
                            profiles: profs
                        }
                    }
                } catch (e) {
                    console.error("BluetoothService: could not parse pactl card list:", e)
                    return
                }
                root.audioProfiles = map
            }
        }
    }

    function profileRank(name) {
        let n = (name || "").toLowerCase()
        if (n.startsWith("a2dp-sink")) return 0
        if (n.startsWith("headset") || n.startsWith("handsfree")) return 1
        if (n === "off") return 9
        return 5
    }

    Component.onCompleted: {
        root.scheduleSync()
        root.refreshAudioProfiles()
    }
}
