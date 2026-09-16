import QtQuick

// Resolves ONE current mascot state name out of the shell's existing live
// signals, and turns that name into a clip path.
//
// Split out of Mascot.qml rather than living in it because the widget is
// already 400+ lines of drag/snap/position logic, and because the state
// ladder is the part that will keep growing as clips get authored - every
// new animation is a row in `conditions` below, not a new branch threaded
// through the view.
//
// Deliberately NOT a Config service (Config.qml:71-109): the interesting
// inputs - battery, media, recording, audio - live on ShellRoot, which a
// singleton has no way to reach. Mascot.qml instantiates this with an
// explicit `shellRef: shellRoot` instead, the same way shell.qml already
// hands Lockscreen its `shellRef`.
QtObject {
    id: mascotState

    property var shellRef: null     // ShellRoot - battery/media/audio/recording
    property var configRef: null    // Config singleton - clip manifest, lock/idle

    // --- LIVE INPUTS PUSHED IN BY THE VIEW ---
    // Things only the widget itself knows. Kept as plain properties so the
    // ladder below can treat them exactly like any shell signal.
    property bool dragging: false
    property bool hovered: false

    // ------------------------------------------------------------------
    // CONDITION LADDER
    // ------------------------------------------------------------------
    // Evaluated top to bottom; the first match wins. Order IS the priority,
    // so a locked session beats a low battery beats music playing.
    //
    // `hold` is the minimum time in ms that a state must stay on screen once
    // entered, before anything of equal-or-lower priority may replace it.
    // Without it, a track that pauses for half a second between songs, or a
    // battery reading that straddles 30%, would swap the sprite twice in a
    // blink. Higher-priority states ignore the hold and preempt immediately -
    // if the session locks, the mascot should sleep now, not in 1.2 seconds.
    //
    // Every `when` is written defensively: this service runs before shellRef
    // is assigned on the first frame, and `hasBattery` stays false on a
    // desktop, where battCapacity is a meaningless 75.
    // The ranking runs in four bands, and mixing them up is the trap:
    //
    //   1. DIRECT INTERACTION - the user is touching the mascot right now.
    //      Nothing should ever swallow this.
    //   2. USER IS AWAY - locked or idled out. Outranks interaction because
    //      neither can genuinely happen while the session is away.
    //   3. URGENT / ACTIVE - something is happening worth reacting to.
    //   4. AMBIENT STATUS - true for hours at a time.
    //
    // Band 4 must sit at the bottom. An ambient condition placed high starves
    // everything under it for as long as it holds: `charging` was originally
    // above `dancing`, so a docked laptop could never show the dance clip at
    // all, and `petted` sat below every ambient row, so hovering did nothing
    // whenever one of them happened to be true.
    readonly property var conditions: [
        // 1. direct interaction
        { name: "grabbed",  hold:    0, when: function() { return mascotState.dragging } },
        // 2. user is away
        { name: "locked",   hold:    0, when: function() { return !!(mascotState.configRef && mascotState.configRef.sessionLocked) } },
        { name: "sleeping", hold:  800, when: function() { return !!(mascotState.configRef && mascotState.configRef.showScreensaver) } },
        { name: "petted",   hold:    0, when: function() { return mascotState.hovered } },
        // 3. urgent, then active
        { name: "critical", hold: 1200, when: function() { return mascotState.onBattery && mascotState.batteryPct <= 10 } },
        { name: "recording",hold:  800, when: function() { return !!(mascotState.shellRef && mascotState.shellRef.isRecording) } },
        { name: "dancing",  hold: 1500, when: function() { return !!(mascotState.shellRef && mascotState.shellRef.mediaPlaying) } },
        // 4. ambient status
        { name: "lowbattery",hold:1200, when: function() { return mascotState.onBattery && mascotState.batteryPct <= 30 } },
        // `charging`/`charged` stay ABOVE `muted`/`offline`, and widening
        // pluggedIn below does not change that. Both of those are ordinary
        // long-lived states here - muted audio and an unassociated radio can
        // each be true all day - and neither ships a clip of its own in the
        // built-in set, so winning the ladder means falling back to plain idle.
        // Demoting the glow under them therefore does not show a different
        // reaction, it shows no reaction: it disappears for the whole time you
        // are docked, which is the exact opposite of the resting look these
        // rows are here to provide.
        //
        // Two rows, not one, because charging.webp alternates between a soft
        // golden aura and a crackling-energy pose. That reads as work being
        // done, which is right while the cell is filling and wrong once it is
        // full - at which point it is just an animation running all day. So
        // `charged` holds charged.webp, a single static frame of the soft aura
        // alone (frame 0 of the same clip), for as long as the adapter stays
        // attached. `charged` tests only pluggedIn because `charging` is
        // evaluated first and takes everything still actually charging.
        { name: "charging", hold: 1200, when: function() { return mascotState.activelyCharging } },
        { name: "charged",  hold: 1200, when: function() { return mascotState.pluggedIn } },
        { name: "muted",    hold:  800, when: function() { return !!(mascotState.shellRef && mascotState.shellRef.audioMuted) } },
        { name: "offline",  hold: 2000, when: function() { return mascotState.networkDown } },
        { name: "idle",     hold:    0, when: function() { return true } }
    ]

    // Battery inputs normalised once, so the ladder rows stay one-liners and
    // the "no battery at all" case is handled in exactly one place.
    readonly property bool hasBattery: !!(shellRef && shellRef.hasBattery)
    // "Adapter attached", not "current is flowing into the cell". battStatus is
    // sysfs verbatim (shell.qml's battStatusReader), and a docked laptop only
    // reads "Charging" until the cell fills - after that it reads "Full", or
    // "Not charging" whenever a charge threshold is deliberately holding it
    // below 100%. Keying off "Charging" alone therefore glowed for an hour and
    // then quietly fell back to idle without the cable having moved.
    //
    // "Unknown" is left out on purpose: it is what an unreadable or not-yet-read
    // supply reports, so counting it would glow on a guess.
    readonly property bool pluggedIn: hasBattery
        && (shellRef.battStatus === "Charging"
            || shellRef.battStatus === "Full"
            || shellRef.battStatus === "Not charging")
    // Narrower than pluggedIn: true only while the cell is actually taking
    // charge, which is what separates the animated clip from the static one.
    readonly property bool activelyCharging: hasBattery && shellRef.battStatus === "Charging"
    readonly property bool onBattery: hasBattery && !pluggedIn
    readonly property int batteryPct: hasBattery ? shellRef.battCapacity : 100

    // Wi-Fi radio off, or on but not associated with anything. Bluetooth and
    // VPN deliberately don't count - neither one being down means "offline"
    // in any sense a character should react to.
    readonly property bool networkDown: !!(shellRef && (!shellRef.wifiPowered || shellRef.wifiSsid === ""))

    // ------------------------------------------------------------------
    // ONE-SHOT REACTIONS
    // ------------------------------------------------------------------
    // Fired imperatively (a notification landed, the user clicked) rather
    // than derived from a condition, and they outrank every condition while
    // they play. A reaction ends when the view reports the clip reached its
    // last frame - see Mascot.qml's onCurrentFrameChanged - or when the
    // safety timer below expires, whichever comes first.
    //
    // The timer matters: a clip that is missing, still decoding, or authored
    // as a single frame will never report a last frame, and without a
    // backstop the mascot would stick on that reaction forever.
    property string reaction: ""
    readonly property int reactionTimeoutMs: 4000

    // Per-frame delay the clips were generated with (mascot_sheet.py --delay,
    // in centiseconds, so 12 -> 120ms). A reaction's length is frameCount x
    // this, which is how long it is held for.
    //
    // Frame INDEX is deliberately not used to detect completion. Qt reports
    // frameCount correctly for these animated WebPs but does not advance
    // currentFrame in step with the clip's real timing - measured, a 7-frame
    // 840ms clip reported its last frame after 235ms - so an index-based
    // check cuts reactions off a third of the way through.
    property int frameMs: 120

    // Called once the reaction's own clip has loaded and its length is known.
    function holdReactionFor(frames) {
        if (reaction === "" || frames < 2) return
        reactionTimer.interval = Math.max(300, Math.min(frames * frameMs, reactionTimeoutMs))
        reactionTimer.restart()
    }

    property Timer reactionTimer: Timer {
        interval: mascotState.reactionTimeoutMs
        repeat: false
        onTriggered: mascotState.reaction = ""
    }

    // Called by the view when a one-shot clip finishes, and by anything that
    // wants to cut a reaction short.
    function endReaction() {
        reactionTimer.stop()
        reaction = ""
    }

    // Start a one-shot. Re-firing the same reaction restarts it, which is
    // what you want when three notifications land in a row: the character
    // reacts again rather than sitting through one animation and ignoring
    // the rest.
    function fire(name) {
        if (!name) return
        reaction = name
        reactionTimer.restart()
    }

    // ------------------------------------------------------------------
    // RESOLUTION
    // ------------------------------------------------------------------
    // The raw ladder result, before the dwell rule is applied.
    readonly property string rawCondition: {
        let rows = mascotState.conditions
        for (let i = 0; i < rows.length; i++) {
            let row = rows[i]
            let ok = false
            try { ok = row.when() } catch (e) { ok = false }
            if (ok) return row.name
        }
        return "idle"
    }

    // The condition actually showing, after minimum-dwell. Written by the
    // watcher below rather than bound, because "keep the previous value for
    // another N ms" is history, and a binding has none.
    property string condition: "idle"
    property double conditionSince: 0

    function priorityOf(name) {
        let rows = mascotState.conditions
        for (let i = 0; i < rows.length; i++) if (rows[i].name === name) return i
        return rows.length
    }

    function holdOf(name) {
        let rows = mascotState.conditions
        for (let i = 0; i < rows.length; i++) if (rows[i].name === name) return rows[i].hold
        return 0
    }

    function evaluate() {
        let next = mascotState.rawCondition
        if (next === mascotState.condition) return

        let now = Date.now()
        let elapsed = now - mascotState.conditionSince
        let heldLongEnough = elapsed >= mascotState.holdOf(mascotState.condition)
        // Lower index == higher priority.
        let preempts = mascotState.priorityOf(next) < mascotState.priorityOf(mascotState.condition)

        if (!heldLongEnough && !preempts) {
            // Too soon and not urgent: come back when the hold expires. The
            // ladder is re-read then, so if the condition has since gone away
            // this settles on whatever is true at that point, not on the
            // value that was pending now.
            settleTimer.interval = Math.max(16, mascotState.holdOf(mascotState.condition) - elapsed)
            settleTimer.restart()
            return
        }

        settleTimer.stop()
        mascotState.condition = next
        mascotState.conditionSince = now
    }

    property Timer settleTimer: Timer {
        repeat: false
        onTriggered: mascotState.evaluate()
    }

    // rawCondition is a binding over a dozen shell properties, so this fires
    // on every relevant change without a single explicit Connections block.
    property Connections ladderWatcher: Connections {
        target: mascotState
        function onRawConditionChanged() { mascotState.evaluate() }
    }

    // What the widget should be showing right now.
    //
    // Deliberately NOT a live binding ("readonly property string current:
    // reaction !== '' ? reaction : condition"), even though that reads more
    // naturally - currentClipPath and currentClipIsOwn below both derive
    // from current, and Qt's engine re-entering current's own expression
    // once for each of them in the same evaluation pass reliably printed
    // "Binding loop detected for property current" on every reload. Nothing
    // was actually wrong (current was never truly circular - condition and
    // reaction are always written imperatively, never from current itself),
    // but a plain property updated explicitly by the two things that can
    // change it sidesteps the false positive entirely, since it's no longer
    // a declarative expression another binding can re-enter.
    property string current: "idle"
    function updateCurrent() { current = reaction !== "" ? reaction : condition }
    onConditionChanged: updateCurrent()
    onReactionChanged: updateCurrent()

    // ------------------------------------------------------------------
    // CLIP MANIFEST
    // ------------------------------------------------------------------
    // Resolution order: the clip registered for this exact state, then the
    // set's own idle clip, then the built-in bundled idle clip directly.
    // That last step only matters for the instant before Config.qml's
    // first-load seeding has populated mascotClips (or a settings.json that
    // predates it) - the mascot is always this one character, never a blank.
    function clipPathFor(name) {
        if (!configRef) return ""
        let clips = configRef.mascotClips || {}
        if (name && clips[name]) return clips[name]
        if (clips["idle"]) return clips["idle"]
        return configRef.builtinMascotDir ? (configRef.builtinMascotDir + "/idle.webp") : ""
    }

    readonly property string currentClipPath: clipPathFor(current)

    // True when the state showing has a clip of its own, rather than having
    // fallen back. The view uses this to decide whether a reaction can be
    // one-shot at all: falling back to the looping idle clip and then
    // waiting for a "last frame" that a looping clip never meaningfully
    // reports would strand the reaction until the safety timer fires.
    readonly property bool currentClipIsOwn: {
        if (!configRef) return false
        let clips = configRef.mascotClips || {}
        return !!(current && clips[current])
    }

    // Names the settings UI and the validator script both need. Reactions are
    // listed separately because they carry an authoring constraint the
    // conditions don't: they must end on a pose that matches idle frame 0.
    readonly property var conditionNames: conditions.map(function(r) { return r.name })
    readonly property var reactionNames: ["notify", "poke"]
    readonly property var allStateNames: conditionNames.concat(reactionNames)

    Component.onCompleted: {
        conditionSince = Date.now()
        evaluate()
    }
}
