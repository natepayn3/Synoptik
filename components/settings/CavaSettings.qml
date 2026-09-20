import QtQuick
import QtQuick.Layouts
import ".."

SettingsPage {
    id: root

    title: "Audio Visualizer"
    description: "Live audio spectrum powered by cava, rendered as a floating desktop widget."
    icon: "graphic_eq"

    readonly property bool cavaEnabled: Config.showDesktopCava === true

    SettingsCard {
        title: "Desktop Visualizer"
        icon: "graphic_eq"

        SettingsToggleRow {
            title: "Enable Desktop Visualizer"
            subtitle: "Runs cava in the background and renders a live audio-reactive overlay on your desktop"
            checked: Config.showDesktopCava === true
            onToggled: Config.showDesktopCava = !Config.showDesktopCava
        }

        SettingsNote {
            text: "Click and drag anywhere on the widget to reposition it. Scroll directly on it to scale."
        }
    }

    // Independent of the desktop widget above: this one only needs cava's
    // bass reading, so it stays available (and keeps cava running) even with
    // the visualizer switched off.
    SettingsCard {
        title: "Ambient Shell Breathing"
        icon: "blur_on"

        SettingsToggleRow {
            title: "Ambient Shell Breathing"
            subtitle: "Shell subtly bounces in time with bass energy. Runs cava in the background even if the desktop visualizer is off."
            checked: Config.ambientBreatheEnabled === true
            onToggled: Config.ambientBreatheEnabled = !Config.ambientBreatheEnabled
        }

        SettingsSlider {
            label: "Intensity"
            active: Config.ambientBreatheEnabled === true
            from: 0
            to: 1
            stepSize: 0.01
            decimals: 2
            value: Config.ambientBreatheIntensity
            onMoved: v => Config.ambientBreatheIntensity = v
        }
    }

    SettingsCard {
        title: "Layout"
        icon: "dashboard"
        bodyEnabled: root.cavaEnabled

        SettingsSegmented {
            currentValue: Config.cavaStyle
            itemWidth: 118
            model: [
                { label: "Bars",     value: "bars",     icon: "bar_chart" },
                { label: "Mirrored", value: "mirrored", icon: "flip" },
                { label: "Wave",     value: "wave",     icon: "waves" },
                { label: "Radial",   value: "radial",   icon: "donut_large" }
            ]
            onSelected: value => Config.cavaStyle = value
        }
    }

    SettingsCard {
        title: "Response"
        icon: "speed"
        bodyEnabled: root.cavaEnabled

        SettingsSlider {
            label: "Bars"
            from: 8
            to: 160
            stepSize: 1
            value: Config.cavaBars
            onMoved: v => Config.cavaBars = Math.round(v)
        }

        SettingsSlider {
            label: "Sensitivity"
            from: 10
            to: 400
            stepSize: 5
            suffix: "%"
            value: Config.cavaSensitivity
            onMoved: v => Config.cavaSensitivity = Math.round(v)
        }

        SettingsSlider {
            label: "Smoothing"
            from: 0
            to: 1
            stepSize: 0.01
            decimals: 2
            value: Config.cavaSmoothing
            onMoved: v => Config.cavaSmoothing = v
        }

        SettingsSlider {
            label: "Framerate"
            from: 24
            to: 144
            stepSize: 1
            suffix: " fps"
            value: Config.cavaFramerate
            onMoved: v => Config.cavaFramerate = Math.round(v)
        }
    }

    SettingsCard {
        title: "Bar Appearance"
        icon: "straighten"
        bodyEnabled: root.cavaEnabled

        SettingsSlider {
            label: "Bar Width"
            from: 2
            to: 24
            stepSize: 1
            suffix: "px"
            value: Config.cavaBarWidth
            onMoved: v => Config.cavaBarWidth = v
        }

        SettingsSlider {
            label: "Bar Gap"
            from: 0
            to: 16
            stepSize: 1
            suffix: "px"
            value: Config.cavaBarGap
            onMoved: v => Config.cavaBarGap = v
        }

        SettingsSlider {
            label: "Corner Radius"
            from: 0
            to: 12
            stepSize: 1
            suffix: "px"
            value: Config.cavaBarRadius
            onMoved: v => Config.cavaBarRadius = v
        }

        SettingsSlider {
            label: "Max Height"
            from: 40
            to: 400
            stepSize: 5
            suffix: "px"
            value: Config.cavaMaxHeight
            onMoved: v => Config.cavaMaxHeight = v
        }

        SettingsSlider {
            visible: Config.cavaStyle === "radial"
            label: "Ring Radius"
            from: 30
            to: 260
            stepSize: 5
            suffix: "px"
            value: Config.cavaRingRadius
            onMoved: v => Config.cavaRingRadius = v
        }
    }

    SettingsCard {
        title: "Colour"
        icon: "palette"
        bodyEnabled: root.cavaEnabled

        SettingsSegmented {
            currentValue: Config.cavaColorMode
            itemWidth: 118
            model: [
                { label: "Accent",   value: "accent" },
                { label: "Gradient", value: "gradient" },
                { label: "Rainbow",  value: "rainbow" },
                { label: "Solid",    value: "solid" }
            ]
            onSelected: value => Config.cavaColorMode = value
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: Config.cavaColorMode === "gradient"

            SettingsColorField {
                label: "Gradient Start"
                value: Config.cavaGradientStart
                onCommitted: v => Config.cavaGradientStart = v
            }

            SettingsColorField {
                label: "Gradient End"
                value: Config.cavaGradientEnd
                onCommitted: v => Config.cavaGradientEnd = v
            }
        }

        SettingsColorField {
            visible: Config.cavaColorMode === "solid"
            label: "Solid Colour"
            value: Config.cavaSolidColor
            onCommitted: v => Config.cavaSolidColor = v
        }

        SettingsSlider {
            visible: Config.cavaColorMode === "rainbow"
            label: "Cycle Speed"
            from: 0
            to: 60
            stepSize: 1
            suffix: "°/s"
            value: Config.cavaRainbowSpeed
            onMoved: v => Config.cavaRainbowSpeed = v
        }
    }

    SettingsCard {
        title: "Display Options"
        icon: "tune"
        bodyEnabled: root.cavaEnabled

        SettingsToggleRow {
            title: "Glow Effect"
            checked: Config.cavaShowGlow !== false
            onToggled: Config.cavaShowGlow = !Config.cavaShowGlow
        }

        SettingsToggleRow {
            title: "Show Background"
            checked: Config.cavaShowBackground !== false
            onToggled: Config.cavaShowBackground = !Config.cavaShowBackground
        }

        SettingsToggleRow {
            title: "Show Border"
            checked: Config.cavaShowBorder !== false
            onToggled: Config.cavaShowBorder = !Config.cavaShowBorder
        }

        SettingsField {
            label: "Target Displays"
            hint: "With none selected the visualizer appears on every display."

            SettingsScreenPicker {
                enabledScreens: Config.enabledCavaScreens
                onToggle: screenName => Config.toggleCavaScreen(screenName)
            }
        }
    }
}
