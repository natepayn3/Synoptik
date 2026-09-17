import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import ".."

Item {
    id: root

    ScrollView {
        anchors.fill: parent
        anchors.rightMargin: 12
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: root.width - 24
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
        }
    }
}
