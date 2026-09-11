import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Single source of truth for Wi-Fi state, shared by the Control Center's
// WifiCard and Settings' WifiSettings.
//
// Those two used to carry a complete implementation each - ~2,200 lines with
// their own nmcli Process sets, their own scan-timeout timers and their own
// copies of the connect/disconnect/forget state machine. Beyond the
// duplication that meant two concurrent `nmcli device wifi rescan` runs when
// both panels were open, and connecting state that one panel could show and
// the other couldn't.
//
// Replacing nmcli with Quickshell.Networking removes two whole classes of bug
// along with the duplication:
//
//   * The SSID no longer passes through a shell. The old code interpolated it
//     into `sh -c` / `fish -c` strings with a hand-rolled quote escaper that
//     was correct for sh but wrong for fish (fish honours \\ and \' inside
//     single quotes, so an SSID ending in a backslash broke the quoting), and
//     the same escaped value was fed to both.
//
//   * Forget and Disconnect no longer match SSIDs through `awk -v target=...`,
//     which runs escape-sequence processing over the value before the program
//     sees it - so any SSID containing a backslash failed to match and those
//     two actions silently did nothing while reporting success.
//
// Failure reporting is also real now: NetworkManager reports *why* a connect
// failed over connectionFailed(), rather than the old approach of grepping
// nmcli's stderr for "not found" and calling everything else a bad password.
QtObject {
    id: root

    property var configRef: null

    readonly property bool backendReady: Networking.backend !== NetworkBackendType.None

    // First wifi-capable device NetworkManager reports. Everything else hangs
    // off this; with no Wi-Fi hardware it stays null and the views show their
    // "no adapter" state.
    //
    // This MUST be a binding, not something resolved once at startup:
    // Networking.devices is empty for the first couple of seconds while
    // NetworkManager enumerates over D-Bus, so a Component.onCompleted lookup
    // finds nothing and never runs again. A binding re-evaluates when the
    // model fills in (verified: null -> wlp114s0 about 2.5s after launch).
    readonly property var wifiDevice: {
        let devs = Networking.devices ? Networking.devices.values : []
        for (let i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].type === DeviceType.Wifi) return devs[i]
        }
        return null
    }

    readonly property bool hasAdapter: !!root.wifiDevice
    readonly property bool powered: Networking.wifiEnabled
    readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled

    // Views gate their empty state on having actually looked once, so a fresh
    // panel doesn't flash "No networks found" before the first enumeration.
    // Deliberately not set on the first sync: that runs before NetworkManager
    // has reported any device at all, so it would light up the "No Wi-Fi
    // Networks Found" state a second after launch and leave it there.
    property bool hasPolledOnce: false

    property Timer pollGraceTimer: Timer {
        interval: 4000
        repeat: false
        running: true
        // Backstop for a machine with genuinely no Wi-Fi hardware, where the
        // device list stays empty forever and nothing else would ever flip this.
        onTriggered: root.hasPolledOnce = true
    }

    property bool scanning: false

    // --- SCANNER LIFETIME ---
    // NetworkManager only publishes the full list of visible access points
    // while a scanner is running. Without this the device reports exactly one
    // network - the one already connected - which is why the picker showed
    // "No Wi-Fi Networks Found" next to a live connection. Turning it on takes
    // the list from 1 to ~17 here.
    //
    // Scoped to when something is actually showing a network list rather than
    // left on permanently: a continuous scan costs power and briefly interrupts
    // throughput on some drivers. This is no more aggressive than the nmcli
    // poll it replaces, which ran every 3.5s for as long as the panel was open.
    readonly property bool listWanted: {
        if (!root.configRef) return false
        if (root.configRef.showControlCenter) return true
        if (root.configRef.showNetwork) return true
        if (root.configRef.showWifi) return true
        // Settings is one window with many pages; only the two that show
        // networks should hold the radio open. 4 = Network, 5 = Wi-Fi.
        if (root.configRef.showSettings) {
            let sec = root.configRef.lastSettingsSection
            return sec === 4 || sec === 5
        }
        return false
    }

    property Binding scannerBinding: Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.listWanted
        when: root.wifiDevice !== null
    }

    property string activeSsid: ""
    property string connectingSsid: ""
    property string disconnectingSsid: ""
    property string errorSsid: ""
    property string connectionError: ""

    // Two shapes of the same fact, because the two views want different ones:
    // the card tests membership, the settings page iterates.
    property var knownNetworks: ({})
    property var savedSsids: ([])

    // ListModel rather than a JS array so both views keep their existing
    // `model: wifiModel` / `model.ssid` delegates and their scroll position.
    // Roles are the union of what the two used: the card reads ssid/connected/
    // signalStrength/isSecure, the settings page also reads isSaved.
    property ListModel networks: ListModel {}

    // --- ACTIONS ---

    function setPowered(on) {
        Networking.wifiEnabled = on
    }

    function togglePower() {
        root.setPowered(!root.powered)
    }

    // WifiDevice exposes scannerEnabled but no explicit rescan, and NM's own
    // sweep while the scanner runs is on its own schedule - so an explicit
    // "Scan" tap would otherwise do nothing visible for up to ten seconds.
    // One argv spawn (no shell, nothing interpolated) forces a fresh sweep;
    // results still arrive through the model, not by parsing this.
    function scan() {
        if (!root.hasAdapter || root.scanning) return
        root.scanning = true
        rescanProc.running = false
        rescanProc.running = true
        scanTimer.restart()
    }

    property Process rescanProc: Process {
        id: rescanProc
        running: false
        command: ["nmcli", "device", "wifi", "rescan"]
    }

    property Timer scanTimer: Timer {
        interval: 6000
        repeat: false
        onTriggered: root.scanning = false
    }

    function networkFor(ssid) {
        if (!root.wifiDevice) return null
        let list = root.wifiDevice.networks.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === ssid) return list[i]
        }
        return null
    }

    function connectTo(ssid, password, isKnown) {
        let n = root.networkFor(ssid)
        if (!n) return

        root.connectingSsid = ssid
        root.errorSsid = ""
        root.connectionError = ""

        // A saved profile already holds its PSK, so connect() reuses it; only a
        // network we have no profile for needs the key handed over. The key
        // goes straight to NetworkManager over D-Bus and never reaches a
        // command line - the old code had to route it through an environment
        // variable specifically to keep it out of /proc/<pid>/cmdline.
        if (password && password.length > 0 && !(isKnown && n.known)) {
            n.connectWithPsk(password)
        } else {
            n.connect()
        }
    }

    function disconnect(ssid) {
        let n = root.networkFor(ssid)
        if (!n) return
        root.disconnectingSsid = ssid
        root.errorSsid = ""
        root.connectionError = ""
        n.disconnect()
    }

    function forget(ssid) {
        let n = root.networkFor(ssid)
        if (!n) return
        root.errorSsid = ""
        root.connectionError = ""
        n.forget()
    }

    function failReasonText(reason) {
        switch (reason) {
            case ConnectionFailReason.NoSecrets:              return "Invalid Password"
            case ConnectionFailReason.WifiAuthTimeout:        return "Authentication Timed Out"
            case ConnectionFailReason.WifiNetworkLost:        return "Network Not Found"
            case ConnectionFailReason.WifiClientDisconnected: return "Disconnected"
            case ConnectionFailReason.WifiClientFailed:       return "Connection Failed"
            default:                                          return "Connection Failed"
        }
    }

    // --- REACTIVE RESYNC ---
    // wifiDevice is a binding (see above), so resolution takes care of itself;
    // these just turn the surrounding state changes into a model rebuild.
    onWifiDeviceChanged: root.scheduleSync()
    onListWantedChanged: root.scheduleSync()

    property Connections networkingConn: Connections {
        target: Networking
        function onWifiEnabledChanged() { root.scheduleSync() }
    }

    // --- MODEL SYNC ---
    // Coalesced: NetworkManager churns signalStrength across every visible AP
    // during a scan, and a single connect fires state/connected/known on
    // several networks at once.
    property Timer syncTimer: Timer {
        interval: 0
        repeat: false
        onTriggered: root.syncNow()
    }

    function scheduleSync() { syncTimer.restart() }

    function syncNow() {
        if (!root.hasAdapter || !root.powered) {
            root.networks.clear()
            root.activeSsid = ""
            root.knownNetworks = ({})
            root.savedSsids = []
            // Only a definite answer counts: powered-off Wi-Fi on a real
            // adapter is one, "NM hasn't enumerated anything yet" is not.
            if (root.hasAdapter || Networking.backend === NetworkBackendType.None) {
                root.hasPolledOnce = true
            }
            return
        }

        let src = root.wifiDevice.networks.values
        let byName = {}
        let known = {}
        let saved = []
        let active = ""

        for (let i = 0; i < src.length; i++) {
            let n = src[i]
            if (!n || !n.name) continue
            let ssid = n.name

            if (n.known) {
                known[ssid] = true
                if (saved.indexOf(ssid) === -1) saved.push(ssid)
            }
            if (n.connected) active = ssid

            // NetworkManager reports strength as a percentage, but normalise a
            // 0.0-1.0 fraction too so the bars are right either way.
            let raw = n.signalStrength
            let strength = Math.round(raw > 0 && raw <= 1.0 ? raw * 100 : raw)
            if (isNaN(strength)) strength = 0

            let row = {
                ssid: ssid,
                connected: n.connected,
                signalStrength: strength,
                isSecure: root.isSecure(n.security),
                isSaved: n.known
            }

            // The same SSID shows up once per BSSID on a mesh or a repeater.
            // Collapse to the strongest, and let any connected copy win.
            let prev = byName[ssid]
            if (!prev) {
                byName[ssid] = row
            } else {
                if (row.connected) prev.connected = true
                if (row.isSaved) prev.isSaved = true
                if (row.signalStrength > prev.signalStrength) prev.signalStrength = row.signalStrength
            }
        }

        let rows = Object.keys(byName).map(k => byName[k])
        rows.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            return b.signalStrength - a.signalStrength
        })

        root.applyRows(rows)
        root.activeSsid = active
        root.knownNetworks = known
        root.savedSsids = saved
        root.hasPolledOnce = true

        // Clear transient state once the network it referred to settled.
        if (root.connectingSsid !== "") {
            let n = root.networkFor(root.connectingSsid)
            if (!n || (!n.stateChanging && n.state !== ConnectionState.Connecting)) {
                root.connectingSsid = ""
            }
        }
        if (root.disconnectingSsid !== "") {
            let n = root.networkFor(root.disconnectingSsid)
            if (!n || !n.connected) root.disconnectingSsid = ""
        }
    }

    function isSecure(sec) {
        return sec !== WifiSecurityType.Open && sec !== WifiSecurityType.Unknown
    }

    // In-place reconciliation rather than clear()+append(): the settings page
    // used to clear() its model on every poll, which is why it needed a
    // hasActiveInputFocus() guard to avoid yanking the password field out from
    // under the user mid-type. Updating in place removes the need for that.
    function applyRows(rows) {
        let m = root.networks

        let existing = {}
        for (let i = 0; i < m.count; i++) existing[m.get(i).ssid] = i

        let fresh = {}
        for (let i = 0; i < rows.length; i++) {
            let r = rows[i]
            fresh[r.ssid] = true
            if (r.ssid in existing) {
                let idx = existing[r.ssid]
                let cur = m.get(idx)
                Object.keys(r).forEach(k => {
                    if (cur[k] !== r[k]) m.setProperty(idx, k, r[k])
                })
            } else {
                m.append(r)
            }
        }

        for (let i = m.count - 1; i >= 0; i--) {
            if (!fresh[m.get(i).ssid]) m.remove(i)
        }
    }

    // One delegate per visible network, existing to turn that network's
    // property notifications into a resync and to surface connect failures.
    property Instantiator networkWatcher: Instantiator {
        model: root.wifiDevice ? root.wifiDevice.networks : null
        delegate: QtObject {
            required property var modelData

            readonly property bool wConnected: modelData ? modelData.connected : false
            readonly property bool wKnown: modelData ? modelData.known : false
            readonly property real wSignal: modelData ? modelData.signalStrength : 0
            readonly property bool wChanging: modelData ? modelData.stateChanging : false
            readonly property int wState: modelData ? modelData.state : 0

            onWConnectedChanged: root.scheduleSync()
            onWKnownChanged: root.scheduleSync()
            onWSignalChanged: root.scheduleSync()
            onWChangingChanged: root.scheduleSync()
            onWStateChanged: root.scheduleSync()

            property Connections failConn: Connections {
                target: modelData
                function onConnectionFailed(reason) {
                    root.connectingSsid = ""
                    root.errorSsid = modelData ? modelData.name : ""
                    root.connectionError = root.failReasonText(reason)
                    root.scheduleSync()
                }
                function onConnectedChanged() {
                    // A successful connect clears whatever error the previous
                    // attempt left on screen.
                    if (modelData && modelData.connected && root.errorSsid === modelData.name) {
                        root.errorSsid = ""
                        root.connectionError = ""
                    }
                }
            }
        }
        onObjectAdded: root.scheduleSync()
        onObjectRemoved: root.scheduleSync()
    }

}
