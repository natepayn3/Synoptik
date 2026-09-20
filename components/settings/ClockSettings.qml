import QtQuick
import ".."

SettingsPage {
    id: root

    title: "Clock"
    description: "Desktop clock overlay, style and time formatting."
    icon: "schedule"

    // The dead `if (typeof Config.saveConfig === "function") ...` tails that
    // used to follow every assignment on this page are gone: neither
    // saveConfig nor save exists on Config, so they never ran. Persistence is
    // Config's own - DesktopWidgetsConfig fires saveSettings() from each
    // property's onChanged handler.
    readonly property bool clockEnabled: Config.showDesktopClock !== false

    SettingsCard {
        title: "Clock Widget"
        icon: "schedule"

        SettingsToggleRow {
            title: "Enable Desktop Clock"
            subtitle: "Show the desktop clock overlay on your displays"
            checked: Config.showDesktopClock !== false
            onToggled: Config.showDesktopClock = (Config.showDesktopClock === false)
        }

        SettingsField {
            label: "Target Displays"
            hint: "With none selected the clock appears on every display."
            active: root.clockEnabled

            SettingsScreenPicker {
                enabledScreens: Config.enabledClockScreens
                onToggle: screenName => Config.toggleClockScreen(screenName)
            }
        }
    }

    SettingsCard {
        title: "Style"
        icon: "style"
        bodyEnabled: root.clockEnabled

        SettingsSegmented {
            currentValue: Config.clockStyle
            model: [
                { label: "Digital", value: "digital", icon: "123" },
                { label: "Modern",  value: "modern",  icon: "timer" },
                { label: "Analog",  value: "analog",  icon: "schedule" }
            ]
            onSelected: value => Config.clockStyle = value
        }
    }

    SettingsCard {
        title: "Time Format"
        icon: "more_time"
        bodyEnabled: root.clockEnabled

        SettingsToggleRow {
            title: "Show Seconds"
            subtitle: "Include seconds in the clock time display"
            checked: Config.clockShowSeconds !== false
            onToggled: Config.clockShowSeconds = (Config.clockShowSeconds === false)
        }

        SettingsToggleRow {
            title: "Use 12-Hour Format"
            subtitle: "Display time in 12-hour instead of 24-hour format"
            checked: Config.clockUse12Hour !== false
            onToggled: Config.clockUse12Hour = (Config.clockUse12Hour === false)
        }

        SettingsToggleRow {
            // AM/PM only means anything on the digital face in 12-hour mode;
            // the modern and analog faces don't draw the indicator at all.
            active: Config.clockUse12Hour && Config.clockStyle === "digital"
            title: "Show AM/PM"
            subtitle: "Show the AM/PM indicator next to the time"
            checked: Config.clockShowAmPm !== false
            onToggled: Config.clockShowAmPm = (Config.clockShowAmPm === false)
        }
    }

    SettingsCard {
        title: "Appearance"
        icon: "palette"
        bodyEnabled: root.clockEnabled

        SettingsToggleRow {
            title: "Show Border"
            subtitle: "Draw a decorative border around the clock widget"
            checked: Config.clockShowBorder !== false
            onToggled: Config.clockShowBorder = (Config.clockShowBorder === false)
        }

        SettingsToggleRow {
            title: "Show Background"
            subtitle: "Display a background panel behind the clock"
            checked: Config.clockShowBackground !== false
            onToggled: Config.clockShowBackground = (Config.clockShowBackground === false)
        }

        SettingsToggleRow {
            title: "Glow Effect"
            subtitle: "Apply a soft glow effect to the clock display"
            checked: Config.clockShowGlow !== false
            onToggled: Config.clockShowGlow = (Config.clockShowGlow === false)
        }
    }
}
