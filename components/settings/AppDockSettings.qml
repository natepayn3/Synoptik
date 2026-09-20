import QtQuick
import ".."

SettingsPage {
    id: root

    title: "App Dock"
    description: "Floating, draggable dock of the apps you pinned from the Launcher."
    icon: "dock_to_bottom"

    readonly property bool dockEnabled: Config.showAppDock !== false

    SettingsCard {
        title: "App Dock Widget"
        icon: "dock_to_bottom"

        SettingsToggleRow {
            title: "Enable App Dock Widget"
            subtitle: "Show the pinned-apps dock overlay on your displays"
            checked: Config.showAppDock !== false
            onToggled: Config.showAppDock = (Config.showAppDock === false)
        }

        SettingsField {
            label: "Target Displays"
            hint: "With none selected the dock appears on every display."
            active: root.dockEnabled

            SettingsScreenPicker {
                enabledScreens: Config.enabledAppDockScreens
                onToggle: screenName => Config.toggleAppDockScreen(screenName)
            }
        }

        SettingsNote {
            text: "Pin or unpin apps from the Launcher - the search icon in the bar. Right-click a result there to toggle its pin."
        }
    }

    SettingsCard {
        title: "Orientation"
        icon: "screen_rotation_alt"
        bodyEnabled: root.dockEnabled

        SettingsSegmented {
            currentValue: Config.appDockOrientation
            model: [
                { label: "Horizontal", value: "horizontal", icon: "view_week" },
                { label: "Vertical",   value: "vertical",   icon: "view_day" }
            ]
            onSelected: value => Config.appDockOrientation = value
        }
    }

    SettingsCard {
        title: "Appearance"
        icon: "palette"
        bodyEnabled: root.dockEnabled

        SettingsToggleRow {
            title: "Show Border"
            subtitle: "Draw a decorative border around the dock"
            checked: Config.appDockShowBorder !== false
            onToggled: Config.appDockShowBorder = (Config.appDockShowBorder === false)
        }

        SettingsToggleRow {
            title: "Show Background"
            subtitle: "Display a background panel behind the dock icons"
            checked: Config.appDockShowBackground !== false
            onToggled: Config.appDockShowBackground = (Config.appDockShowBackground === false)
        }

        SettingsToggleRow {
            title: "Glow Effect"
            subtitle: "Apply a soft glow effect to hovered icons"
            checked: Config.appDockShowGlow !== false
            onToggled: Config.appDockShowGlow = (Config.appDockShowGlow === false)
        }
    }
}
