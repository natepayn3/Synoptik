import QtQuick
import ".."

SettingsPage {
    id: root

    title: "On-Screen Keyboard"
    description: "Virtual keyboard overlay for touch and pen input."
    icon: "keyboard"

    SettingsCard {
        title: "Keyboard Overlay"
        icon: "keyboard"

        SettingsToggleRow {
            title: "Enable Keyboard Overlay"
            subtitle: "Show a virtual on-screen keyboard overlay"
            checked: Config.showOsk !== false
            onToggled: Config.showOsk = (Config.showOsk === false)
        }

        SettingsField {
            label: "Layout"
            active: Config.showOsk !== false

            SettingsSegmented {
                currentValue: Config.oskLayout
                model: [
                    { label: "Normal",  value: "Normal",  icon: "keyboard" },
                    { label: "Minimal", value: "Minimal", icon: "keyboard_keys" },
                    { label: "Gamer",   value: "Gamer",   icon: "sports_esports" }
                ]
                onSelected: value => Config.oskLayout = value
            }
        }
    }
}
