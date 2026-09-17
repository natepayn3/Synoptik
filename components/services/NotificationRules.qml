import QtQuick
import Quickshell
import Quickshell.Services.Notifications as Notifs

// The single place the shell decides what to do with an arriving notification.
//
// That decision used to be spread across two independent subscribers to the
// same signal: shell.qml recorded every notification to history unconditionally,
// while NotificationOSD separately checked DND, played the sound and picked a
// timeout - and both set notif.tracked, neither knowing about the other. Four
// questions ("log it?", "show it?", "make noise?", "for how long?") answered in
// four places is the same shape as the drifted panel-close lists that
// Config.panelFlagByView exists to prevent.
//
// decide() answers all four at once and is pure, so the callers can keep their
// own subscriptions and simply ask. Per-app rules then have exactly one place
// to apply, rather than needing every caller to agree about them.
QtObject {
    id: rulesRoot

    property var configRef: null

    // key -> sparse rule object. Only fields that differ from ruleDefaults are
    // stored, so the file stays small and a default can be changed later
    // without rewriting everyone's saved rules.
    property var notificationRules: ({})

    // Critical is the urgency a client picks for "your battery is about to die"
    // and "your build broke the deploy". Letting a scheduled quiet-hours window
    // swallow those is how people learn not to trust Do Not Disturb, so by
    // default it doesn't - this is the switch for anyone who disagrees.
    property bool dndAllowCritical: true

    onDndAllowCriticalChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    readonly property var ruleDefaults: ({
        mute: false,       // no popup
        silent: false,     // no sound
        bypassDnd: false,  // shows even while DND is on
        hide: false,       // not even recorded in history
        sound: "",         // "" = the global notification sound
        timeout: 0,        // 0 = derive one; otherwise milliseconds
        urgency: -1        // -1 = as the app sent it; else Low/Normal/Critical
    })

    // --- IDENTITY ---
    // desktopEntry over appName wherever the client sends one: appName is a
    // display string that changes between releases ("discord" -> "Discord")
    // and takes every rule keyed on it out of service when it does, while
    // desktopEntry is the app's stable .desktop id.
    function keyFor(notif) {
        if (!notif) return ""
        let k = notif.desktopEntry || notif.appName || ""
        return k.trim().toLowerCase()
    }

    function keyForEntry(entry) {
        if (!entry) return ""
        let k = entry.desktopEntry || entry.appName || ""
        return k.trim().toLowerCase()
    }

    function ruleFor(key) {
        let stored = (key && notificationRules[key]) ? notificationRules[key] : {}
        let merged = {}
        Object.keys(ruleDefaults).forEach(f => {
            merged[f] = (stored[f] !== undefined) ? stored[f] : ruleDefaults[f]
        })
        return merged
    }

    function hasRule(key) {
        let r = notificationRules[key]
        return !!r && Object.keys(r).length > 0
    }

    function setRuleField(key, field, value) {
        if (!key || ruleDefaults[field] === undefined) return
        let all = Object.assign({}, notificationRules)
        let rule = Object.assign({}, all[key] || {})

        // Storing a value equal to the default would pin this rule to today's
        // default forever, so it's dropped instead - and a rule with nothing
        // left in it is removed entirely, which is what makes "has a rule"
        // meaningful in the UI.
        if (value === ruleDefaults[field]) delete rule[field]
        else rule[field] = value

        if (Object.keys(rule).length === 0) delete all[key]
        else all[key] = rule

        notificationRules = all
        if (configRef) configRef.saveSettings()
    }

    function toggleRuleField(key, field) {
        setRuleField(key, field, !ruleFor(key)[field])
    }

    function clearRule(key) {
        if (!notificationRules[key]) return
        let all = Object.assign({}, notificationRules)
        delete all[key]
        notificationRules = all
        if (configRef) configRef.saveSettings()
    }

    // --- THE DECISION ---
    function decide(notif) {
        let d = {
            key: "",
            label: "",
            record: true,
            osd: true,
            sound: true,
            soundPath: "",
            timeout: 0,
            urgency: Notifs.NotificationUrgency.Normal,
            reason: ""
        }
        if (!notif) {
            d.record = false; d.osd = false; d.sound = false
            return d
        }

        d.key = keyFor(notif)
        d.label = notif.appName || d.key
        let rule = ruleFor(d.key)

        // Resolved first: everything below keys off the effective urgency, so
        // an app promoted to Critical also gets Critical's DND treatment and
        // its stay-on-screen behaviour.
        d.urgency = (rule.urgency >= 0) ? rule.urgency : notif.urgency
        let isCritical = d.urgency === Notifs.NotificationUrgency.Critical

        // The sender marking a notification transient means "this is a status
        // blip, not a record" - a volume step, a progress tick. Logging those
        // pushes real notifications out of a 100-entry history.
        if (notif.transient) d.record = false

        if (rule.hide) {
            d.record = false; d.osd = false; d.sound = false
            d.reason = "hidden: " + d.label
            return d
        }

        if (rule.mute) {
            d.osd = false; d.sound = false
            d.reason = "muted: " + d.label
            return d
        }

        let dndOn = configRef ? configRef.dndActive : false
        if (dndOn && !rule.bypassDnd && !(isCritical && dndAllowCritical)) {
            d.osd = false; d.sound = false
            d.reason = "dnd" + (configRef && configRef.dndReason ? ": " + configRef.dndReason : "")
            return d
        }

        d.sound = !rule.silent && (configRef ? configRef.playNotificationSounds !== false : true)
        d.soundPath = rule.sound || (configRef ? configRef.notificationSoundPath : "")
        d.timeout = timeoutFor(notif, rule, isCritical)
        return d
    }

    // How long the popup stays up, most specific source first:
    //
    //   1. an explicit per-app override,
    //   2. Critical, which stays until dismissed - the existing behaviour,
    //   3. the expireTimeout the client asked for, which was being ignored
    //      outright. Per the freedesktop spec 0 means "never expire" and -1
    //      means "server decides", so a client asking for a sticky notification
    //      was getting four seconds,
    //   4. the old default: longer when there are buttons, since a card with a
    //      decision on it has to outlast a card that's just a receipt.
    //
    // Returns 0 for "never expire".
    function timeoutFor(notif, rule, isCritical) {
        if (rule.timeout > 0) return rule.timeout
        if (isCritical) return 0

        let asked = notif.expireTimeout
        if (asked === 0) return 0
        if (asked > 0) return asked

        let actions = notif.actions ? notif.actions : []
        return actions.length > 0 ? 9000 : 4000
    }

    // Plain-language account of what would happen to a normal-urgency
    // notification from `key` right now, rule and current DND state included.
    // decide() takes a live Notification, so there is otherwise no way to ask
    // "why didn't that show up?" without waiting for it to happen again.
    function explain(key) {
        let rule = ruleFor(key)
        let dndOn = configRef ? configRef.dndActive : false
        let lines = []

        if (rule.hide) lines.push("hidden - no popup, no sound, not recorded in history")
        else if (rule.mute) lines.push("muted - recorded in history only")
        else if (dndOn && !rule.bypassDnd) {
            lines.push("suppressed by Do Not Disturb"
                + (configRef && configRef.dndReason ? " (" + configRef.dndReason + ")" : "")
                + " - recorded in history only")
        } else {
            let soundOff = rule.silent || (configRef && configRef.playNotificationSounds === false)
            lines.push("popup shown" + (soundOff ? ", silent" : ", with sound"
                + (rule.sound ? " " + rule.sound : "")))
        }

        if (rule.urgency >= 0) lines.push("urgency forced to " + ["Low", "Normal", "Critical"][rule.urgency])
        if (rule.timeout > 0) lines.push("popup lasts " + (rule.timeout / 1000) + "s")
        if (rule.bypassDnd) lines.push("ignores Do Not Disturb")
        if (!hasRule(key)) lines.push("(no per-app rule set - shell defaults)")

        return lines.join("\n")
    }

    // --- APPS SEEN ---
    // The rules UI lists what has actually sent you something rather than
    // asking anyone to type an app id by hand. History is the only record of
    // that, so it doubles as the app registry; apps with a rule but no history
    // entry are folded back in so a rule never becomes uneditable just because
    // its app hasn't spoken recently.
    readonly property var knownApps: {
        let seen = {}
        let entries = (configRef && configRef.notificationHistory) ? configRef.notificationHistory : []

        for (let i = 0; i < entries.length; i++) {
            let e = entries[i]
            let key = keyForEntry(e)
            if (key === "") continue
            if (!seen[key]) seen[key] = { key: key, label: e.appName || key, count: 0 }
            seen[key].count++
        }

        Object.keys(notificationRules).forEach(key => {
            if (!seen[key]) seen[key] = { key: key, label: key, count: 0 }
        })

        let list = Object.keys(seen).map(k => seen[k])
        list.sort((a, b) => b.count - a.count || a.label.localeCompare(b.label))
        return list
    }
}
