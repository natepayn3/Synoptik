import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import ".."

SettingsPage {
    id: root

    title: "Appearance"
    description: "Shell geometry, borders, glass effects and colour themes."
    icon: "palette"

    // Reusable Geometric / Square Toggle Switch Component
    // Custom Thicker Horizontal Slider with Dot Handle
    component ThickHorizontalSlider : Slider {
        id: slider
        implicitHeight: 24

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            implicitHeight: 6
            height: implicitHeight
            radius: 3
            color: Qt.rgba(255, 255, 255, 0.1)

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                color: Config.accent
                radius: 3
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            implicitWidth: 16
            implicitHeight: 16
            radius: 8
            color: slider.pressed ? Config.accent : Config.textMain
            border.width: 2
            border.color: Config.bgBase
        }
    }

    // SECTION HEADER


    // ==========================================
    // 1. UNIFIED SURFACE GEOMETRY CARD
    // ==========================================
    SettingsCard {
        id: geomCol

        title: "Surface Geometry & Spacing"
        icon: "straighten"
        subtitle: "Adjust corner curvature, border line weights, and layout paddings."



        // Corners Slider
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                spacing: 6
                Layout.preferredWidth: 80
                Text {
                    text: "rounded_corner"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 16
                    color: Config.textMuted
                }
                Text {
                    text: "Corners"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }
            }

            ThickHorizontalSlider {
                id: cornersSlider
                Layout.fillWidth: true
                from: 0
                to: 40
                stepSize: 1
                value: Config.surfaceRadius
                onValueChanged: Config.surfaceRadius = value
            }

            Rectangle {
                implicitWidth: 42; implicitHeight: 22; radius: 6
                color: SettingsStyle.controlBg
                border.width: 1; border.color: Config.accent
                Text {
                    anchors.centerIn: parent
                    text: Math.round(cornersSlider.value) + "px"
                    color: Config.accent
                    font.family: Config.sysFont
                    font.bold: true
                    font.pixelSize: 10
                }
            }
        }

        // Border Slider
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                spacing: 6
                Layout.preferredWidth: 80
                Text {
                    text: "border_style"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 16
                    color: Config.textMuted
                }
                Text {
                    text: "Border"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }
            }

            ThickHorizontalSlider {
                id: borderSlider
                Layout.fillWidth: true
                from: 0
                to: 10
                stepSize: 1
                value: (Config.borderThickness !== undefined) ? Config.borderThickness : 3
                onValueChanged: Config.borderThickness = value
            }

            Rectangle {
                implicitWidth: 42; implicitHeight: 22; radius: 6
                color: SettingsStyle.controlBg
                border.width: 1; border.color: Config.accent
                Text {
                    anchors.centerIn: parent
                    text: Math.round(borderSlider.value) + "px"
                    color: Config.accent
                    font.family: Config.sysFont
                    font.bold: true
                    font.pixelSize: 10
                }
            }
        }

        // Margin Slider
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                spacing: 6
                Layout.preferredWidth: 80
                Text {
                    text: "padding"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 16
                    color: Config.textMuted
                }
                Text {
                    text: "Margin"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }
            }

            ThickHorizontalSlider {
                id: marginSlider
                Layout.fillWidth: true
                from: 0
                to: 32
                stepSize: 1
                value: (Config.cardMargin !== undefined) ? Config.cardMargin : 12
                onValueChanged: Config.cardMargin = value
            }

            Rectangle {
                implicitWidth: 42; implicitHeight: 22; radius: 6
                color: SettingsStyle.controlBg
                border.width: 1; border.color: Config.accent
                Text {
                    anchors.centerIn: parent
                    text: Math.round(marginSlider.value) + "px"
                    color: Config.accent
                    font.family: Config.sysFont
                    font.bold: true
                    font.pixelSize: 10
                }
            }
        }

        // Opacity Slider
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                spacing: 6
                Layout.preferredWidth: 80
                Text {
                    text: "opacity"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 16
                    color: Config.textMuted
                }
                Text {
                    text: "Opacity"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }
            }

            ThickHorizontalSlider {
                id: opacitySlider
                Layout.fillWidth: true
                from: 0.1
                to: 1.0
                value: Config.shellOpacity !== undefined ? Config.shellOpacity : 1.0
                onValueChanged: Config.shellOpacity = value
            }

            Rectangle {
                implicitWidth: 42; implicitHeight: 22; radius: 6
                color: SettingsStyle.controlBg
                border.width: 1; border.color: Config.accent
                Text {
                    anchors.centerIn: parent
                    text: Math.round(opacitySlider.value * 100) + "%"
                    color: Config.accent
                    font.family: Config.sysFont
                    font.bold: true
                    font.pixelSize: 10
                }
            }
        }
    }


    // ==========================================
    // 2. VISUAL EFFECTS & RENDERING ENGINES CARD
    // ==========================================
    SettingsCard {
        id: fxCol

        title: "Visual Effects & Rendering"
        icon: "blur_on"
        subtitle: "Toggle compositor shaders, backdrop filters, and dynamic themer."



        readonly property bool hasBorders: (Config.borderThickness !== undefined ? Config.borderThickness : 3) > 0

        // Reads the dependency into `checked` as well as `active`: with the
        // border width at 0 there is nothing to animate, so the switch should
        // show off rather than show a setting that isn't taking effect.
        SettingsToggleRow {
            title: "Animated Gradient Borders"
            subtitle: "Smooth animated color sweep along window borders (requires Border > 0px)"
            active: fxCol.hasBorders
            checked: fxCol.hasBorders && Config.animateGradient
            onToggled: Config.animateGradient = !Config.animateGradient
        }

        // 2. Background Blur Row
        SettingsToggleRow {
            title: "Background Blur"
            subtitle: "Hardware-accelerated frosted glass backdrop filtering"
            checked: Config.enableBlur
            onToggled: Config.enableBlur = !Config.enableBlur
        }

        SettingsToggleRow {
            title: "X-Ray Mode"
            subtitle: "Ultra-translucent window pass-through layer (requires Blur)"
            active: Config.enableBlur
            checked: Config.enableBlur && Config.enableXray
            onToggled: Config.enableXray = !Config.enableXray
        }

        // 4. Watermarks Row
        SettingsToggleRow {
            title: "Shell Watermarks"
            subtitle: "Show decorative branding glyphs on lockscreen and shell panels"
            checked: Config.showWatermarks
            onToggled: Config.showWatermarks = !Config.showWatermarks
        }

        SettingsToggleRow {
            title: "Floating Ambient Drift"
            subtitle: "Watermarks slowly drift within panel cards (requires Watermarks)"
            active: Config.showWatermarks
            checked: Config.showWatermarks && Config.bounceWatermarks
            onToggled: Config.bounceWatermarks = !Config.bounceWatermarks
        }

        // 6. Auto-Color (Iris) Row
        SettingsToggleRow {
            title: "Auto-Color (Iris)"
            subtitle: "Dynamically extract and apply theme colors from current wallpaper"
            checked: Config.enableIris
            onToggled: Config.enableIris = !Config.enableIris
        }

        // 6b. Iris Intensity Picker - how vivid the extracted accent
        // color is pushed, since Iris itself always returns one fixed
        // reading with no vibrance control of its own.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            spacing: 10
            visible: Config.enableIris

            Repeater {
                model: [
                    { name: "Subtle", desc: "Muted", value: "subtle" },
                    { name: "Medium", desc: "Iris default", value: "medium" },
                    { name: "Bold", desc: "Vivid", value: "bold" }
                ]

                delegate: Rectangle {
                    id: intensityBtn
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 40
                    radius: Config.cornerRadius / 2
                    readonly property bool isSelected: Config.irisIntensity === modelData.value
                    color: isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.16) : (intensityBtnHover.containsMouse ? SettingsStyle.controlBgHover : SettingsStyle.controlBg)
                    border.width: isSelected ? 1.5 : 1
                    border.color: isSelected ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.name
                            color: intensityBtn.isSelected ? Config.accent : Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: intensityBtn.isSelected
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.desc
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                        }
                    }

                    MouseArea {
                        id: intensityBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.irisIntensity = modelData.value
                    }
                }
            }
        }

        // 7. Desktop Widget Motion Row
        SettingsToggleRow {
            title: "Snap Desktop Widgets"
            subtitle: "On snaps desktop widgets to a grid while dragging, and locks them onto the screen's exact center line whenever you get close to it; off eases them smoothly to the exact cursor position"
            checked: Config.snapDesktopWidgets
            onToggled: Config.snapDesktopWidgets = !Config.snapDesktopWidgets
        }
    }


    // ==========================================
    // 3. COLOR THEMES & PALETTES CARD
    // ==========================================
    SettingsCard {
        id: themeCol

        title: "Color Palettes & Themes"
        icon: "palette"
        accessory: Rectangle {
                    implicitWidth: themeCountText.implicitWidth + 16
                    implicitHeight: 24
                    radius: 12
                    color: Qt.rgba(255, 255, 255, 0.08)

                    Text {
                        id: themeCountText
                        anchors.centerIn: parent
                        text: (Config.themes ? Config.themes.length : 0) + " Palettes"
                        font.family: Config.sysFont
                        font.pixelSize: 11
                        font.bold: true
                        color: Config.textMuted
                    }
                }



        // Palette Swatches Box
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: paletteGrid.implicitHeight + 20
            color: SettingsStyle.controlBg
            radius: Config.cornerRadius / 2
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.08)
            enabled: !Config.enableIris
            opacity: Config.enableIris ? 0.35 : (Config.useCustomColors ? 0.5 : 1.0)

            GridLayout {
                id: paletteGrid
                anchors.fill: parent
                anchors.margins: 12
                columns: 10
                rowSpacing: 10
                columnSpacing: 10

                Repeater {
                    model: {
                        let total = Config.themes ? Config.themes.length : 0
                        let cols = 10
                        let remainder = total % cols
                        let dummyCount = remainder === 0 ? 0 : (cols - remainder)

                        let list = []
                        for (let i = 0; i < total; i++) {
                            list.push({ theme: Config.themes[i], realIndex: i, isDummy: false })
                        }
                        for (let d = 0; d < dummyCount; d++) {
                            list.push({ theme: null, realIndex: -1, isDummy: true })
                        }
                        return list
                    }

                    delegate: Item {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32

                        readonly property var itemData: modelData
                        readonly property bool isDummy: itemData.isDummy
                        readonly property int themeIdx: itemData.realIndex
                        readonly property var themeObj: itemData.theme
                        readonly property bool isCustomTheme: !isDummy && themeObj && themeObj.isCustom === true
                        readonly property bool isSelected: !isDummy && !Config.useCustomColors && Config.currentThemeIndex === themeIdx

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: isDummy ? "transparent" : (themeObj.bgBase || Qt.rgba(0,0,0,0.5))
                            border.color: isSelected ? Config.accent : Qt.rgba(255, 255, 255, 0.15)
                            border.width: isSelected ? 2.5 : 1
                            visible: !isDummy

                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            // Inner Accent Pip
                            Rectangle {
                                anchors.centerIn: parent
                                width: 14; height: 14; radius: 7
                                color: themeObj ? themeObj.accent : "transparent"
                            }

                            TapHandler {
                                enabled: !isDummy
                                acceptedButtons: Qt.LeftButton
                                onTapped: {
                                    Config.useCustomColors = false
                                    Config.setTheme(themeIdx)
                                }
                            }

                            TapHandler {
                                enabled: !isDummy
                                acceptedButtons: Qt.RightButton
                                onTapped: {
                                    if (isCustomTheme) deletePalette(themeIdx)
                                }
                            }

                            HoverHandler {
                                id: pSwHover
                                enabled: !isDummy
                                cursorShape: Qt.PointingHandCursor
                            }

                            // Delete badge for custom palettes
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: -2
                                width: 14; height: 14; radius: 7
                                color: "#E74C3C"
                                visible: isCustomTheme && pSwHover.hovered

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: "white"
                                    font.pixelSize: 11
                                    font.bold: true
                                    anchors.verticalCenterOffset: -1
                                }

                                TapHandler {
                                    acceptedButtons: Qt.LeftButton
                                    onTapped: deletePalette(themeIdx)
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    // ==========================================
    // 4. CUSTOM HEX OVERRIDES CARD
    // ==========================================
    SettingsCard {
        id: hexCol

        title: "Custom Hex Overrides"
        icon: "colorize"
        subtitle: "Define custom hex values for surface backgrounds, panels, and accent highlights."
        accessory: ToggleSwitch {
                    checked: !Config.enableIris && Config.useCustomColors
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        enabled: !Config.enableIris
                        cursorShape: Config.enableIris ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                        onClicked: Config.useCustomColors = !Config.useCustomColors
                    }
                }



        // Custom Hex Inputs (Base, Panel, Accent)
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            enabled: Config.useCustomColors && !Config.enableIris
            opacity: (Config.useCustomColors && !Config.enableIris) ? 1.0 : 0.4

            // Base
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "Base Background"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: 11
                    font.bold: true
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Config.cornerRadius / 2
                    color: SettingsStyle.controlBg
                    border.color: baseInput.activeFocus ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        Rectangle {
                            implicitWidth: 16; implicitHeight: 16; radius: 8
                            color: Config.customBgBase || "#111111"
                            border.width: 1; border.color: Qt.rgba(255, 255, 255, 0.2)
                        }

                        TextInput {
                            id: baseInput
                            Layout.fillWidth: true
                            text: Config.customBgBase
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            selectByMouse: true
                            onEditingFinished: if (text.length > 0) Config.customBgBase = text
                            HoverHandler { cursorShape: Qt.IBeamCursor }
                        }
                    }
                }
            }

            // Panel
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "Panel Surface"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: 11
                    font.bold: true
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Config.cornerRadius / 2
                    color: SettingsStyle.controlBg
                    border.color: panelInput.activeFocus ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        Rectangle {
                            implicitWidth: 16; implicitHeight: 16; radius: 8
                            color: Config.customBgPanel || "#222222"
                            border.width: 1; border.color: Qt.rgba(255, 255, 255, 0.2)
                        }

                        TextInput {
                            id: panelInput
                            Layout.fillWidth: true
                            text: Config.customBgPanel
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            selectByMouse: true
                            onEditingFinished: if (text.length > 0) Config.customBgPanel = text
                            HoverHandler { cursorShape: Qt.IBeamCursor }
                        }
                    }
                }
            }

            // Accent
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "Accent Color"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: 11
                    font.bold: true
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Config.cornerRadius / 2
                    color: SettingsStyle.controlBg
                    border.color: accentInput.activeFocus ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        Rectangle {
                            implicitWidth: 16; implicitHeight: 16; radius: 8
                            color: Config.customAccent || "#00E676"
                            border.width: 1; border.color: Qt.rgba(255, 255, 255, 0.2)
                        }

                        TextInput {
                            id: accentInput
                            Layout.fillWidth: true
                            text: Config.customAccent
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            selectByMouse: true
                            onEditingFinished: if (text.length > 0) Config.customAccent = text
                            HoverHandler { cursorShape: Qt.IBeamCursor }
                        }
                    }
                }
            }
        }

        // Save Palette Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: Config.useCustomColors && !Config.enableIris

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: Config.cornerRadius / 2
                color: SettingsStyle.controlBg
                border.color: nameInput.activeFocus ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                border.width: 1

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    text: "Enter new palette name..."
                    color: Qt.rgba(255, 255, 255, 0.3)
                    font.family: Config.sysFont
                    font.pixelSize: 11
                    verticalAlignment: Text.AlignVCenter
                    visible: nameInput.text.length === 0 && !nameInput.activeFocus
                }

                TextInput {
                    id: nameInput
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    text: ""
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: 11
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    onAccepted: saveCurrentPalette()
                    HoverHandler { cursorShape: Qt.IBeamCursor }
                }
            }

            Rectangle {
                implicitWidth: 110
                implicitHeight: 32
                radius: Config.cornerRadius / 2
                color: saveHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Config.accent

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "save"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 14
                        color: saveHover.hovered ? Config.accent : Config.bgBase
                    }
                    Text {
                        text: "Save Palette"
                        font.family: Config.sysFont
                        font.pixelSize: 11
                        font.bold: true
                        color: saveHover.hovered ? Config.accent : Config.bgBase
                    }
                }

                TapHandler { onTapped: saveCurrentPalette() }
                HoverHandler { id: saveHover; cursorShape: Qt.PointingHandCursor }
            }
        }
    }


    Item { Layout.fillHeight: true; implicitHeight: 20 }
}
