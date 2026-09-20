pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."

SettingsPage {
    id: root

    title: "Notifications"
    description: "Do Not Disturb, the system tray, and per-app notification rules."
    icon: "notifications"

    SettingsCard {
        title: "Do Not Disturb"
        icon: "notifications_off"
        subtitle: "Silences popups and their sounds. Anything that arrives is still recorded in the Control Center's History tab, so nothing is lost - just deferred."

        // Current state spelled out: with three possible triggers it should
        // never be a guess which one is holding DND on.
        SettingsNote {
            variant: Config.dndActive ? "warn" : "info"
            text: {
                if (!Config.dndActive) return "Notifications are being shown."
                if (Config.dndReason === "schedule") return "Silenced by the schedule below."
                if (Config.dndReason === "fullscreen") return "Silenced - a window is fullscreen."
                return "Silenced manually."
            }
        }

        SettingsToggleRow {
            title: "Do Not Disturb"
            subtitle: "Turn it on now and leave it on until you turn it off"
            checked: Config.dndManual
            onToggled: Config.dndManual = !Config.dndManual
        }

        SettingsToggleRow {
            title: "Scheduled Quiet Hours"
            subtitle: "Silence notifications automatically between two times each day"
            checked: Config.dndScheduleEnabled
            onToggled: Config.dndScheduleEnabled = !Config.dndScheduleEnabled
        }

        SettingsField {
            label: "Quiet Hours"
            visible: Config.dndScheduleEnabled
            hint: Config.dndScheduleStart === Config.dndScheduleEnd
                ? "Start and end are the same - the schedule never runs."
                : ""

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                HourStepper {
                    hour: Config.dndScheduleStart
                    onHourPicked: h => Config.dndScheduleStart = h
                }

                Text {
                    text: "–"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }

                HourStepper {
                    hour: Config.dndScheduleEnd
                    onHourPicked: h => Config.dndScheduleEnd = h
                }

                Item { Layout.fillWidth: true }
            }
        }

        SettingsToggleRow {
            title: "Silence During Fullscreen"
            subtitle: "Hold notifications while a window on the focused workspace is fullscreen"
            checked: Config.dndWhenFullscreen
            onToggled: Config.dndWhenFullscreen = !Config.dndWhenFullscreen
        }

        SettingsToggleRow {
            title: "Let Critical Through"
            subtitle: "Urgent notifications - a dying battery, a failed backup - still appear while Do Not Disturb is on"
            checked: Config.dndAllowCritical
            onToggled: Config.dndAllowCritical = !Config.dndAllowCritical
        }
    }

    SettingsCard {
        title: "System Tray"
        icon: "deployed_code"
        subtitle: "Apps that close to a tray icon rather than a window. Their icons sit next to the bar's right-hand modules, and all of them are listed in the task popout."

        SettingsToggleRow {
            title: "Enable System Tray"
            subtitle: "Show tray icons on the bar and in the task popout"
            checked: Config.showTray
            onToggled: Config.showTray = !Config.showTray
        }

        SettingsToggleRow {
            title: "Collapse to Pinned Only"
            subtitle: "Keep only pinned icons on the bar; the rest stay in the task popout"
            active: Config.showTray
            checked: Config.trayCollapsed
            onToggled: Config.trayCollapsed = !Config.trayCollapsed
        }

        SettingsToggleRow {
            title: "Hide Inactive Icons"
            subtitle: "Respect an app's 'passive' status. Some apps set it once and never update it, so their icon will disappear for good"
            active: Config.showTray
            checked: Config.trayHidePassive
            onToggled: Config.trayHidePassive = !Config.trayHidePassive
        }

        SettingsField {
            label: "Detected Tray Apps"
            hint: Config.tray.count === 0
                ? "Nothing is registered right now. Icons appear here as apps that use one start up."
                : ""
            active: Config.showTray

            SettingsList {
                Repeater {
                    model: Config.tray.items

                    delegate: SettingsOptionRow {
                        id: trayItemRow

                        required property var modelData

                        readonly property bool pinned: Config.tray.isPinned(trayItemRow.modelData)

                        title: Config.tray.labelFor(trayItemRow.modelData)
                        subtitle: Config.tray.keyFor(trayItemRow.modelData)
                        onClicked: Config.tray.togglePin(trayItemRow.modelData)

                        actions: SettingsButton {
                            label: trayItemRow.pinned ? "Pinned" : "Pin"
                            icon: trayItemRow.pinned ? "keep" : "keep_off"
                            variant: trayItemRow.pinned ? "accent" : "quiet"
                            onClicked: Config.tray.togglePin(trayItemRow.modelData)
                        }
                    }
                }
            }
        }
    }

    SettingsCard {
        title: "Per-App Rules"
        icon: "rule"
        subtitle: "Do Not Disturb is all-or-nothing; this is the per-app version. The list is built from what has actually sent you something, so there is no app name to type."

        Text {
            Layout.fillWidth: true
            visible: Config.notifRules.knownApps.length === 0
            text: "Nothing has sent a notification yet."
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            wrapMode: Text.WordWrap
        }

        SettingsList {
            Repeater {
                model: Config.notifRules.knownApps

                delegate: Rectangle {
                    id: appCard

                    required property var modelData

                    readonly property string appKey: appCard.modelData.key
                    // ruleFor() reads notificationRules, so this binding
                    // re-evaluates on its own whenever a rule changes.
                    readonly property var rule: Config.notifRules.ruleFor(appCard.appKey)
                    readonly property bool hasRule: Config.notifRules.hasRule(appCard.appKey)
                    property bool expanded: false

                    // One line saying what the rule does, so a collapsed list is
                    // readable without opening every row.
                    readonly property string summary: {
                        if (!appCard.hasRule) return "Default"
                        const bits = []
                        if (appCard.rule.hide) bits.push("Hidden")
                        else if (appCard.rule.mute) bits.push("Muted")
                        if (appCard.rule.silent && !appCard.rule.mute && !appCard.rule.hide) bits.push("Silent")
                        if (appCard.rule.bypassDnd) bits.push("Ignores DND")
                        if (appCard.rule.urgency >= 0) bits.push(["Low", "Normal", "Critical"][appCard.rule.urgency])
                        if (appCard.rule.timeout > 0) bits.push((appCard.rule.timeout / 1000) + "s")
                        if (appCard.rule.sound !== "") bits.push(appCard.rule.sound.replace(".wav", ""))
                        return bits.length > 0 ? bits.join(" · ") : "Default"
                    }

                    Layout.fillWidth: true
                    implicitHeight: appCardCol.implicitHeight + 16
                    radius: SettingsStyle.controlRadius
                    color: SettingsStyle.controlBg
                    border.width: appCard.hasRule ? 1 : 1
                    border.color: appCard.hasRule ? SettingsStyle.accentLine : SettingsStyle.controlBorder

                    Behavior on border.color { ColorAnimation { duration: SettingsStyle.animFast } }

                    ColumnLayout {
                        id: appCardCol

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 8
                        spacing: SettingsStyle.tightGap

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: appCard.expanded ? "expand_more" : "chevron_right"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 16
                                color: Config.textMuted
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: appCard.modelData.label
                                    color: Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: appCard.summary
                                        + (appCard.modelData.count > 0 ? "  ·  " + appCard.modelData.count + " in history" : "")
                                    color: appCard.hasRule ? Config.accent : Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    elide: Text.ElideRight
                                }
                            }

                            SettingsButton {
                                label: "Reset"
                                visible: appCard.hasRule
                                onClicked: Config.notifRules.clearRule(appCard.appKey)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 24
                            spacing: SettingsStyle.tightGap
                            visible: appCard.expanded

                            Repeater {
                                model: [
                                    { field: "mute",      name: "Mute popups",         desc: "Still recorded in history" },
                                    { field: "silent",    name: "Silent",              desc: "Shows, but makes no sound" },
                                    { field: "bypassDnd", name: "Show during DND",     desc: "Ignores Do Not Disturb entirely" },
                                    { field: "hide",      name: "Keep out of history", desc: "No popup, no sound, no record" }
                                ]

                                delegate: SettingsToggleRow {
                                    required property var modelData

                                    title: modelData.name
                                    subtitle: modelData.desc
                                    checked: appCard.rule[modelData.field] === true
                                    onToggled: Config.notifRules.toggleRuleField(appCard.appKey, modelData.field)
                                }
                            }

                            SettingsField {
                                label: "Sound"
                                active: !appCard.rule.mute && !appCard.rule.hide && !appCard.rule.silent

                                // Cycles rather than opening a dropdown: ten options
                                // in a fixed order, and cycling keeps the row the
                                // same height whether or not it is open.
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 30
                                    radius: SettingsStyle.controlRadius
                                    color: soundHover.hovered ? SettingsStyle.controlBgHover : SettingsStyle.controlBg
                                    border.width: 1
                                    border.color: SettingsStyle.controlBorder

                                    Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: appCard.rule.sound === ""
                                            ? "Default (" + (Config.notificationSoundPath || "sound1.wav").replace(".wav", "") + ")"
                                            : appCard.rule.sound.replace(".wav", "")
                                        color: appCard.rule.sound === "" ? Config.textMuted : Config.accent
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontMicro)
                                        font.bold: appCard.rule.sound !== ""
                                    }

                                    TapHandler {
                                        onTapped: {
                                            const opts = ["", "sound1.wav", "sound2.wav", "sound3.wav", "sound4.wav",
                                                          "sound5.wav", "sound6.wav", "sound7.wav", "sound8.wav", "sound9.wav"]
                                            const i = opts.indexOf(appCard.rule.sound)
                                            Config.notifRules.setRuleField(appCard.appKey, "sound", opts[(i + 1) % opts.length])
                                        }
                                    }
                                    HoverHandler { id: soundHover; cursorShape: Qt.PointingHandCursor }
                                }
                            }

                            SettingsField {
                                label: "Lasts"
                                active: !appCard.rule.mute && !appCard.rule.hide

                                SettingsSegmented {
                                    currentValue: appCard.rule.timeout
                                    itemWidth: 80
                                    model: [
                                        { label: "Auto", value: 0 },
                                        { label: "3s",   value: 3000 },
                                        { label: "10s",  value: 10000 },
                                        { label: "30s",  value: 30000 }
                                    ]
                                    onSelected: value => Config.notifRules.setRuleField(appCard.appKey, "timeout", value)
                                }
                            }

                            SettingsField {
                                label: "Urgency"

                                SettingsSegmented {
                                    currentValue: appCard.rule.urgency
                                    itemWidth: 90
                                    model: [
                                        { label: "As sent",  value: -1 },
                                        { label: "Low",      value: 0 },
                                        { label: "Normal",   value: 1 },
                                        { label: "Critical", value: 2 }
                                    ]
                                    onSelected: value => Config.notifRules.setRuleField(appCard.appKey, "urgency", value)
                                }
                            }

                            // What the rule adds up to, in the same words the
                            // `notify explain` IPC uses - seven controls with
                            // precedence between them needs a plain answer.
                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                text: Config.notifRules.explain(appCard.appKey)
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.italic: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Only the header strip toggles. A handler on the whole card
                    // would collapse it on any tap that missed a control inside
                    // the expanded body.
                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 36

                        TapHandler { onTapped: appCard.expanded = !appCard.expanded }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }
}
