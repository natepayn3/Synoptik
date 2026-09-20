import QtQuick
import QtQuick.Layouts
import Quickshell
import "../lockscreen"
import ".."

SettingsPage {
    id: root

    title: "Lockscreen"
    description: "Unlock surface - password mask, clock format, wallpaper blur and what it shows."
    icon: "lock"

    // "Focused screen" plus one entry per attached output, in the one shape
    // SettingsSegmented wants. Config stores either the literal "focused" or
    // an output name, so the chip values are those same strings.
    readonly property var monitorOptions: {
        const opts = [{ label: "Focused Screen", value: "focused", icon: "center_focus_strong" }]
        for (const screen of Quickshell.screens) {
            if (screen && screen.name) {
                opts.push({ label: screen.name, value: screen.name, icon: "desktop_windows" })
            }
        }
        return opts
    }

    readonly property string datePreview: {
        const d = new Date()
        const mode = Config.lockscreenDateFormat || "long"
        if (mode === "standard") return Qt.formatDate(d, "ddd, MMM d, yyyy")
        if (mode === "iso") return Qt.formatDate(d, "yyyy-MM-dd")
        if (mode === "dayFirst") return Qt.formatDate(d, "d MMMM yyyy")
        return Qt.formatDate(d, "dddd, MMMM d, yyyy")
    }

    SettingsCard {
        title: "Live Password Bar"
        icon: "password"
        subtitle: "Type below to test the glyphs, animations and clearing behaviour."

        accessory: SettingsButton {
            label: "Test Lock"
            icon: "lock"
            variant: "accent"
            onClicked: Config.sessionLocked = true
        }

        LockscreenPasswordBar {
            id: previewPassBar
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            maskStyle: Config.lockscreenMaskStyle || "shapes"
            paletteMode: Config.lockscreenShapePalette || "vibrant"
            placeholderText: "Type to test password bar..."

            onSubmitPassword: (pass) => {
                previewPassBar.isAuthenticating = true
                previewSimTimer.restart()
            }
        }

        Timer {
            id: previewSimTimer
            interval: 500
            onTriggered: {
                previewPassBar.isAuthenticating = false
                previewPassBar.isSuccess = true
                previewResetTimer.restart()
            }
        }

        Timer {
            id: previewResetTimer
            interval: 700
            onTriggered: {
                previewPassBar.isSuccess = false
                previewPassBar.clearInput()
            }
        }
    }

    SettingsCard {
        title: "Active Display"
        icon: "desktop_windows"
        subtitle: "Which display renders the unlock UI. Every other display stays solid black."

        SettingsSegmented {
            currentValue: Config.lockscreenTargetMonitor || "focused"
            model: root.monitorOptions
            onSelected: value => Config.lockscreenTargetMonitor = value
        }
    }

    SettingsCard {
        title: "Password Mask"
        icon: "more_horiz"

        SettingsTileGrid {
            currentValue: Config.lockscreenMaskStyle || "shapes"
            columns: 4
            model: [
                { label: "Shapes",        value: "shapes",    icon: "category",            desc: "16 vector shapes",  preview: "\u25c6 \u25b2 \u25a0" },
                { label: "Dots",          value: "dots",      icon: "fiber_manual_record", desc: "Bullet discs",      preview: "\u25cf \u25cf \u25cf" },
                { label: "Asterisks",     value: "asterisks", icon: "emergency",           desc: "Classic asterisks", preview: "\u2731 \u2731 \u2731" },
                { label: "Special Chars", value: "special",   icon: "code",                desc: "Random symbols",    preview: "! @ # \u2605" }
            ]
            onSelected: value => Config.lockscreenMaskStyle = value
        }
    }

    SettingsCard {
        title: "Shape Palette"
        icon: "palette"
        subtitle: "Colour set the randomised mask glyphs are drawn from."

        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            spacing: SettingsStyle.tightGap

            Repeater {
                model: [
                    { id: "vibrant",    label: "Vibrant",    desc: "Cyber tones",  previewColor: "#00f0ff" },
                    { id: "accent",     label: "Accent",     desc: "Theme match",  previewColor: Config.accent },
                    { id: "neon",       label: "Neon High",  desc: "High contrast", previewColor: "#ff0055" },
                    { id: "pastel",     label: "Pastel",     desc: "Soft hues",    previewColor: "#c4b5fd" },
                    { id: "monochrome", label: "Monochrome", desc: "Silver/grey",  previewColor: "#ffffff" }
                ]

                delegate: Rectangle {
                    id: paletteChip

                    required property var modelData

                    readonly property bool isSelected:
                        (Config.lockscreenShapePalette || "vibrant") === paletteChip.modelData.id

                    implicitWidth: paletteRow.implicitWidth + 24
                    implicitHeight: 44
                    radius: SettingsStyle.controlRadius
                    color: paletteChip.isSelected
                        ? SettingsStyle.accentSoft
                        : (paletteHover.hovered ? SettingsStyle.controlBgHover : SettingsStyle.controlBg)
                    border.width: 1
                    border.color: paletteChip.isSelected ? SettingsStyle.accentLine : SettingsStyle.controlBorder

                    Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }

                    RowLayout {
                        id: paletteRow
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            implicitWidth: 16
                            implicitHeight: 16
                            radius: 8
                            color: paletteChip.modelData.previewColor
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.25)
                        }

                        ColumnLayout {
                            spacing: 0

                            Text {
                                text: paletteChip.modelData.label
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: true
                                color: paletteChip.isSelected ? Config.accent : Config.textMain
                            }

                            Text {
                                text: paletteChip.modelData.desc
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                color: Config.textMuted
                            }
                        }
                    }

                    TapHandler { onTapped: Config.lockscreenShapePalette = paletteChip.modelData.id }
                    HoverHandler { id: paletteHover; cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }

    SettingsCard {
        title: "Time & Date"
        icon: "schedule"

        SettingsField {
            label: "Time Mode"

            SettingsSegmented {
                currentValue: Config.lockscreenUse12Hour !== false
                itemWidth: 130
                model: [
                    { label: "12-Hour", value: true,  icon: "schedule" },
                    { label: "24-Hour", value: false, icon: "military_tech" }
                ]
                onSelected: value => Config.lockscreenUse12Hour = value
            }
        }

        SettingsField {
            label: "Clock Size"

            SettingsSegmented {
                currentValue: Config.lockscreenClockSize || 150
                itemWidth: 100
                model: [
                    { label: "100px", value: 100 },
                    { label: "150px", value: 150 },
                    { label: "200px", value: 200 }
                ]
                onSelected: value => Config.lockscreenClockSize = value
            }
        }

        SettingsToggleRow {
            title: "Show Seconds"
            subtitle: "Include seconds in the lockscreen clock"
            checked: Config.lockscreenShowSeconds !== false
            onToggled: Config.lockscreenShowSeconds = (Config.lockscreenShowSeconds === false)
        }

        SettingsToggleRow {
            title: "Show AM/PM"
            subtitle: "Show the AM/PM indicator beside the time"
            active: Config.lockscreenUse12Hour !== false
            checked: Config.lockscreenShowAmPm !== false
            onToggled: Config.lockscreenShowAmPm = (Config.lockscreenShowAmPm === false)
        }

        SettingsField {
            label: "Date Style"
            hint: "Preview: " + root.datePreview

            SettingsSegmented {
                currentValue: Config.lockscreenDateFormat || "long"
                itemWidth: 130
                model: [
                    { label: "Long",      value: "long" },
                    { label: "Standard",  value: "standard" },
                    { label: "Day First", value: "dayFirst" },
                    { label: "ISO 8601",  value: "iso" }
                ]
                onSelected: value => Config.lockscreenDateFormat = value
            }
        }
    }

    SettingsCard {
        title: "Display Options"
        icon: "tune"

        SettingsToggleRow {
            title: "Show Media Player Mini Controller"
            subtitle: "Currently playing track metadata and playback controls on the lock screen"
            checked: Config.lockscreenShowMedia !== false
            onToggled: Config.lockscreenShowMedia = (Config.lockscreenShowMedia === false)
        }

        SettingsToggleRow {
            title: "Show Power Actions"
            subtitle: "Suspend, reboot and power off directly from the lock surface"
            checked: Config.lockscreenShowPower !== false
            onToggled: Config.lockscreenShowPower = (Config.lockscreenShowPower === false)
        }

        SettingsField {
            label: "Wallpaper Blur"

            SettingsSegmented {
                currentValue: Config.lockscreenBlurRadius || 36
                itemWidth: 150
                model: [
                    { label: "Light (18px)",  value: 18 },
                    { label: "Medium (36px)", value: 36 },
                    { label: "Heavy (60px)",  value: 60 }
                ]
                onSelected: value => Config.lockscreenBlurRadius = value
            }
        }
    }
}
