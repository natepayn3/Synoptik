import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import ".."

Item {
    id: root

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    // Flickable + ScrollBar with a centred, width-capped column - the same
    // wrapper AssistantSettings.qml and CavaSettings.qml use.
    //
    // This was a ScrollView that took a 12px right margin AND sized its column
    // to root.width - 24, so the two stacked: content sat flush against the
    // left edge with 24px of dead space down the right. Anchoring flush and
    // centring the column is what keeps the gutters equal at any panel width,
    // and the 620 cap stops the description paragraphs from running to
    // unreadable line lengths on a wide panel.
    Flickable {
        id: mainFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            active: mainFlickable.moving || mainFlickable.flicking
        }

        ColumnLayout {
            id: mainColumn
            width: Math.min(mainFlickable.width - (root.cardMargin * 2), 620)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            // =====================================================
            // DO NOT DISTURB
            // =====================================================
            Text {
                text: "DO NOT DISTURB"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontSubhead)
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: "Silences notification popups and their sounds. Anything that arrives while it's on is still recorded in the Control Center's History tab, so nothing is lost - just deferred."
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                wrapMode: Text.WordWrap
            }

            // Current state, spelled out - with three possible triggers it
            // should never be a guess which one is holding DND on.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: Config.cornerRadius / 2
                color: Config.dndActive ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.15) : Qt.rgba(0, 0, 0, 0.25)
                border.width: 1
                border.color: Config.dndActive ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: Config.dndActive ? "notifications_off" : "notifications"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                        color: Config.dndActive ? Config.accent : Config.textMuted
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!Config.dndActive) return "Notifications are being shown."
                            if (Config.dndReason === "schedule") return "Silenced by the schedule below."
                            if (Config.dndReason === "fullscreen") return "Silenced - a window is fullscreen."
                            return "Silenced manually."
                        }
                        color: Config.dndActive ? Config.accent : Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                        elide: Text.ElideRight
                    }
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

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                spacing: 10
                visible: Config.dndScheduleEnabled

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

                Text {
                    Layout.fillWidth: true
                    text: Config.dndScheduleStart === Config.dndScheduleEnd
                        ? "Start and end are the same - the schedule never runs."
                        : ""
                    color: "#f0ad4e"
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    wrapMode: Text.WordWrap
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

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                implicitHeight: 1
                color: Qt.rgba(255, 255, 255, 0.1)
            }

            // =====================================================
            // SYSTEM TRAY
            // =====================================================
            Text {
                text: "SYSTEM TRAY"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontSubhead)
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: "Apps that close to a tray icon rather than a window - chat clients, sync daemons, game launchers. Their icons sit next to the bar's right-hand modules, and all of them are listed in the task popout whether they're on the bar or not."
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                wrapMode: Text.WordWrap
            }

            SettingsToggleRow {
                title: "Enable System Tray"
                subtitle: "Show tray icons on the bar and in the task popout"
                checked: Config.showTray
                onToggled: Config.showTray = !Config.showTray
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                enabled: Config.showTray
                opacity: enabled ? 1.0 : 0.35

                Behavior on opacity { NumberAnimation { duration: 150 } }

                SettingsToggleRow {
                    title: "Collapse to Pinned Only"
                    subtitle: "Keep only pinned icons on the bar; the rest stay in the task popout"
                    checked: Config.trayCollapsed
                    onToggled: Config.trayCollapsed = !Config.trayCollapsed
                }

                SettingsToggleRow {
                    title: "Hide Inactive Icons"
                    subtitle: "Respect an app's 'passive' status. Some apps set it once and never update it, so their icon will disappear for good"
                    checked: Config.trayHidePassive
                    onToggled: Config.trayHidePassive = !Config.trayHidePassive
                }

                Text {
                    Layout.topMargin: 4
                    text: "DETECTED TRAY APPS"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    visible: Config.tray.count === 0
                    text: "Nothing is registered right now. Tray icons appear here as apps that use one start up."
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: Config.tray.items

                    delegate: Rectangle {
                        id: trayItemRow
                        required property var modelData

                        readonly property bool pinned: Config.tray.isPinned(modelData)

                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: Config.cornerRadius / 2
                        color: Qt.rgba(0, 0, 0, 0.25)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20

                                IconImage {
                                    id: settingsTrayIcon
                                    anchors.fill: parent
                                    asynchronous: true
                                    source: Config.tray.iconFor(trayItemRow.modelData)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: settingsTrayIcon.status !== Image.Ready
                                    text: "deployed_code"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 15
                                    color: Config.textMuted
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: Config.tray.labelFor(trayItemRow.modelData)
                                    color: Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: Config.tray.keyFor(trayItemRow.modelData)
                                    color: Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                implicitWidth: pinLabel.implicitWidth + 20
                                implicitHeight: 24
                                radius: 12
                                color: trayItemRow.pinned ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2) : Qt.rgba(255, 255, 255, 0.08)
                                border.width: 1
                                border.color: trayItemRow.pinned ? Config.accent : Qt.rgba(255, 255, 255, 0.12)

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    id: pinLabel
                                    anchors.centerIn: parent
                                    text: trayItemRow.pinned ? "Pinned" : "Pin"
                                    color: trayItemRow.pinned ? Config.accent : Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: true
                                }

                                TapHandler { onTapped: Config.tray.togglePin(trayItemRow.modelData) }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                implicitHeight: 1
                color: Qt.rgba(255, 255, 255, 0.1)
            }

            // =====================================================
            // PER-APP RULES
            // =====================================================
            Text {
                text: "PER-APP RULES"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontSubhead)
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: "Do Not Disturb is all-or-nothing; this is the per-app version. The list is built from what has actually sent you something, so there is no app name to type. You can also mute an app straight from its popup."
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: Config.notifRules.knownApps.length === 0
                text: "Nothing has sent a notification yet."
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: Config.notifRules.knownApps

                delegate: Rectangle {
                    id: appCard
                    required property var modelData

                    readonly property string appKey: modelData.key
                    // ruleFor() reads notificationRules, so this binding
                    // re-evaluates on its own whenever a rule changes.
                    readonly property var rule: Config.notifRules.ruleFor(appKey)
                    readonly property bool hasRule: Config.notifRules.hasRule(appKey)
                    property bool expanded: false

                    // One line saying what the rule does, so a collapsed list
                    // is readable without opening every row.
                    readonly property string summary: {
                        if (!hasRule) return "Default"
                        let bits = []
                        if (rule.hide) bits.push("Hidden")
                        else if (rule.mute) bits.push("Muted")
                        if (rule.silent && !rule.mute && !rule.hide) bits.push("Silent")
                        if (rule.bypassDnd) bits.push("Ignores DND")
                        if (rule.urgency >= 0) bits.push(["Low", "Normal", "Critical"][rule.urgency])
                        if (rule.timeout > 0) bits.push((rule.timeout / 1000) + "s")
                        if (rule.sound !== "") bits.push(rule.sound.replace(".wav", ""))
                        return bits.length > 0 ? bits.join(" · ") : "Default"
                    }

                    Layout.fillWidth: true
                    implicitHeight: appCardCol.implicitHeight + 16
                    radius: Config.cornerRadius / 2
                    color: Qt.rgba(0, 0, 0, 0.25)
                    border.width: appCard.hasRule ? 1 : 0
                    border.color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.4)

                    ColumnLayout {
                        id: appCardCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 8
                        spacing: 8

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
                                    text: appCard.modelData.label
                                    color: Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: appCard.summary
                                        + (appCard.modelData.count > 0 ? "  ·  " + appCard.modelData.count + " in history" : "")
                                    color: appCard.hasRule ? Config.accent : Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                visible: appCard.hasRule
                                implicitWidth: resetLabel.implicitWidth + 16
                                implicitHeight: 22
                                radius: 11
                                color: resetArea.containsMouse ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.06)

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    id: resetLabel
                                    anchors.centerIn: parent
                                    text: "Reset"
                                    color: Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: true
                                }

                                MouseArea {
                                    id: resetArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.notifRules.clearRule(appCard.appKey)
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 24
                            spacing: 8
                            visible: appCard.expanded

                            Repeater {
                                model: [
                                    { field: "mute",      name: "Mute popups",        desc: "Still recorded in history" },
                                    { field: "silent",    name: "Silent",             desc: "Shows, but makes no sound" },
                                    { field: "bypassDnd", name: "Show during DND",    desc: "Ignores Do Not Disturb entirely" },
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

                            // --- SOUND ---
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                enabled: !appCard.rule.mute && !appCard.rule.hide && !appCard.rule.silent
                                opacity: enabled ? 1.0 : 0.35

                                Text {
                                    text: "SOUND"
                                    color: Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: true
                                    Layout.preferredWidth: 60
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 26
                                    radius: Config.cornerRadius / 2
                                    color: soundArea.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)

                                    Behavior on color { ColorAnimation { duration: 150 } }

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

                                    // Cycles rather than opening a dropdown: ten
                                    // options in a fixed order, and cycling keeps
                                    // the row the same height whether or not it
                                    // is open.
                                    MouseArea {
                                        id: soundArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            let opts = ["", "sound1.wav", "sound2.wav", "sound3.wav", "sound4.wav",
                                                        "sound5.wav", "sound6.wav", "sound7.wav", "sound8.wav", "sound9.wav"]
                                            let i = opts.indexOf(appCard.rule.sound)
                                            Config.notifRules.setRuleField(appCard.appKey, "sound", opts[(i + 1) % opts.length])
                                        }
                                    }
                                }
                            }

                            // --- TIMEOUT ---
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                enabled: !appCard.rule.mute && !appCard.rule.hide
                                opacity: enabled ? 1.0 : 0.35

                                Text {
                                    text: "LASTS"
                                    color: Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: true
                                    Layout.preferredWidth: 60
                                }

                                Repeater {
                                    model: [
                                        { name: "Auto", ms: 0 },
                                        { name: "3s", ms: 3000 },
                                        { name: "10s", ms: 10000 },
                                        { name: "30s", ms: 30000 }
                                    ]

                                    delegate: Rectangle {
                                        id: timeoutChip
                                        required property var modelData
                                        readonly property bool isSelected: appCard.rule.timeout === modelData.ms

                                        Layout.fillWidth: true
                                        implicitHeight: 26
                                        radius: Config.cornerRadius / 2
                                        color: timeoutChip.isSelected
                                            ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.22)
                                            : (timeoutArea.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05))
                                        border.width: timeoutChip.isSelected ? 1 : 0
                                        border.color: Config.accent

                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: timeoutChip.modelData.name
                                            color: timeoutChip.isSelected ? Config.accent : Config.textMuted
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontMicro)
                                            font.bold: timeoutChip.isSelected
                                        }

                                        MouseArea {
                                            id: timeoutArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Config.notifRules.setRuleField(appCard.appKey, "timeout", timeoutChip.modelData.ms)
                                        }
                                    }
                                }
                            }

                            // --- URGENCY ---
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: "URGENCY"
                                    color: Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: true
                                    Layout.preferredWidth: 60
                                }

                                Repeater {
                                    model: [
                                        { name: "As sent", v: -1 },
                                        { name: "Low", v: 0 },
                                        { name: "Normal", v: 1 },
                                        { name: "Critical", v: 2 }
                                    ]

                                    delegate: Rectangle {
                                        id: urgencyChip
                                        required property var modelData
                                        readonly property bool isSelected: appCard.rule.urgency === modelData.v

                                        Layout.fillWidth: true
                                        implicitHeight: 26
                                        radius: Config.cornerRadius / 2
                                        color: urgencyChip.isSelected
                                            ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.22)
                                            : (urgencyArea.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05))
                                        border.width: urgencyChip.isSelected ? 1 : 0
                                        border.color: Config.accent

                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: urgencyChip.modelData.name
                                            color: urgencyChip.isSelected ? Config.accent : Config.textMuted
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontMicro)
                                            font.bold: urgencyChip.isSelected
                                        }

                                        MouseArea {
                                            id: urgencyArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Config.notifRules.setRuleField(appCard.appKey, "urgency", urgencyChip.modelData.v)
                                        }
                                    }
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
                                font.pixelSize: 9
                                font.italic: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    MouseArea {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 36
                        cursorShape: Qt.PointingHandCursor
                        onClicked: appCard.expanded = !appCard.expanded
                    }
                }
            }
        }
    }
}
