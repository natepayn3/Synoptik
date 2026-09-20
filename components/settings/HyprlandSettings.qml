import QtQuick
import ".."

// Hyprland general/animations/input knobs not already covered by Appearance
// (border colour/thickness/rounding/blur/xray live there). Writes into
// hypr_style.lua via Config.syncHyprlandBorders() - see HyprlandConfig.qml.
SettingsPage {
    id: root

    title: "Hyprland"
    description: "Window manager behaviour - layout, gaps, animations and input."
    icon: "window"

    SettingsCard {
        title: "General & Layout"
        icon: "dashboard"

        SettingsField {
            label: "Layout Mode"

            SettingsSegmented {
                currentValue: Config.hyprLayoutMode
                itemWidth: 128
                model: [
                    { label: "Dwindle",   value: "dwindle",   icon: "account_tree" },
                    { label: "Master",    value: "master",    icon: "view_sidebar" },
                    { label: "Scrolling", value: "scrolling", icon: "swipe_right" }
                ]
                onSelected: value => Config.hyprLayoutMode = value
            }
        }

        SettingsSlider {
            label: "Gaps"
            from: 0
            to: 30
            stepSize: 1
            suffix: "px"
            value: Config.hyprGapsIn
            onMoved: v => Config.hyprGapsIn = v
        }

        SettingsToggleRow {
            title: "Resize From Border"
            subtitle: "Grab a window's edge anywhere to resize it, not just its exact border line"
            icon: "open_with"
            checked: Config.hyprResizeOnBorder === true
            onToggled: Config.hyprResizeOnBorder = !Config.hyprResizeOnBorder
        }

        SettingsToggleRow {
            title: "Allow Screen Tearing"
            subtitle: "Lets fullscreen apps that opt in - some games - skip vsync for lower latency"
            icon: "bolt"
            checked: Config.hyprAllowTearing === true
            onToggled: Config.hyprAllowTearing = !Config.hyprAllowTearing
        }
    }

    SettingsCard {
        title: "Animations"
        icon: "motion_photos_on"

        SettingsToggleRow {
            title: "Window Manager Animations"
            subtitle: "Master switch for Hyprland's own window, workspace and layer animations"
            icon: "animation"
            checked: Config.hyprAnimationsEnabled !== false
            onToggled: Config.hyprAnimationsEnabled = (Config.hyprAnimationsEnabled === false)
        }
    }

    SettingsCard {
        title: "Input"
        icon: "mouse"

        SettingsSlider {
            label: "Pointer Sensitivity"
            hint: "0 is the device default; negative slows the pointer, positive speeds it up."
            from: -1.0
            to: 1.0
            stepSize: 0.05
            decimals: 2
            value: Config.hyprSensitivity
            onMoved: v => Config.hyprSensitivity = v
        }

        SettingsField {
            label: "Focus Follows Mouse"

            SettingsSegmented {
                currentValue: Config.hyprFollowMouse
                itemWidth: 92
                model: [
                    { label: "Off",   value: 0 },
                    { label: "On",    value: 1 },
                    { label: "Loose", value: 2 },
                    { label: "Full",  value: 3 }
                ]
                onSelected: value => Config.hyprFollowMouse = value
            }
        }

        SettingsToggleRow {
            title: "Natural Scroll (Touchpad)"
            subtitle: "Reverses touchpad scroll direction to match touch-screen conventions"
            icon: "swipe_vertical"
            checked: Config.hyprNaturalScroll === true
            onToggled: Config.hyprNaturalScroll = !Config.hyprNaturalScroll
        }
    }
}
