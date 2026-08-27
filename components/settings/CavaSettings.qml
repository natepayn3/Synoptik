import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import ".."

Flickable {
    id: flickable
    Layout.fillWidth: true
    Layout.fillHeight: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + 32
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        active: flickable.moving || flickable.flicking
    }

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    component ThickHorizontalSlider : Slider {
        id: slider
        implicitHeight: 24

        HoverHandler { cursorShape: Qt.PointingHandCursor }

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

    component SettingsCard : Rectangle {
        default property alias content: col.children
        property alias colSpacing: col.spacing
        Layout.fillWidth: true
        implicitHeight: col.implicitHeight + 28
        radius: Config.cornerRadius
        color: Qt.rgba(255, 255, 255, 0.05)
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.1)

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
        }
    }

    component SliderRow : RowLayout {
        id: sliderRow
        property string label: ""
        property string icon: ""
        property real from: 0
        property real to: 100
        property real stepSize: 1
        property real value: 0
        property string suffix: ""
        property int decimals: 0
        signal changed(real newValue)

        Layout.fillWidth: true
        spacing: 12

        RowLayout {
            spacing: 6
            Layout.preferredWidth: 96
            Text {
                text: sliderRow.icon
                font.family: "Material Symbols Outlined"
                font.pixelSize: 16
                color: Config.textMuted
                visible: sliderRow.icon !== ""
            }
            Text {
                text: sliderRow.label
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        ThickHorizontalSlider {
            id: innerSlider
            Layout.fillWidth: true
            from: sliderRow.from
            to: sliderRow.to
            stepSize: sliderRow.stepSize
            value: sliderRow.value
            onValueChanged: sliderRow.changed(value)
        }

        Rectangle {
            implicitWidth: 54; implicitHeight: 22; radius: 6
            color: Qt.rgba(0, 0, 0, 0.3)
            border.width: 1; border.color: Config.accent
            Text {
                anchors.centerIn: parent
                text: innerSlider.value.toFixed(sliderRow.decimals) + sliderRow.suffix
                color: Config.accent
                font.family: Config.sysFont
                font.bold: true
                font.pixelSize: 10
            }
        }
    }

    component ColorField : ColumnLayout {
        id: colorField
        property string label: ""
        property string value: "#ffffff"
        signal committed(string newValue)

        Layout.fillWidth: true
        spacing: 4

        Text {
            text: colorField.label
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: 11
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 34
            radius: Config.cornerRadius / 2
            color: Qt.rgba(0, 0, 0, 0.3)
            border.color: colorInput.activeFocus ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                Rectangle {
                    implicitWidth: 16; implicitHeight: 16; radius: 8
                    color: colorField.value || "#111111"
                    border.width: 1; border.color: Qt.rgba(255, 255, 255, 0.2)
                }

                TextInput {
                    id: colorInput
                    Layout.fillWidth: true
                    text: colorField.value
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: 12
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    selectByMouse: true
                    onEditingFinished: if (text.length > 0) colorField.committed(text)
                    HoverHandler { cursorShape: Qt.IBeamCursor }
                }
            }
        }
    }

    ColumnLayout {
        id: contentColumn
        width: Math.min(flickable.width - (flickable.cardMargin * 2), 620)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: flickable.cardMargin

        Text {
            Layout.fillWidth: true
            text: "AUDIO VISUALIZER (CAVA)"
            color: Config.textMain
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontSubhead)
            font.bold: true
        }

        Text {
            text: "A live audio spectrum visualizer powered by cava, rendered as a floating desktop widget. Choose a layout, tune its response, and style it to match your theme."
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        // ==========================================
        // 1. MASTER TOGGLE
        // ==========================================
        SettingsCard {
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 0
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: "Enable Desktop Visualizer"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Runs cava in the background and renders a live audio-reactive overlay on your desktop."
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        wrapMode: Text.WordWrap
                    }
                }

                ToggleSwitch {
                    checked: Config.showDesktopCava === true

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.showDesktopCava = !Config.showDesktopCava
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: Config.cornerRadius / 2
                color: Qt.rgba(0, 0, 0, 0.25)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "mouse"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 15
                        color: Config.accent
                    }

                    Text {
                        text: "Click + Drag anywhere to reposition. Scroll wheel directly on the widget to scale."
                        font.family: Config.sysFont
                        font.pixelSize: 11
                        color: Config.textMuted
                    }
                }
            }
        }

        // ==========================================
        // AMBIENT SHELL BREATHING
        // ==========================================
        SettingsCard {
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 0
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: "Ambient Shell Breathing"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Subtly dims and brightens the shell's border in time with bass energy. Runs cava in the background even if the desktop visualizer above is off."
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        wrapMode: Text.WordWrap
                    }
                }

                ToggleSwitch {
                    checked: Config.ambientBreatheEnabled === true

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.ambientBreatheEnabled = !Config.ambientBreatheEnabled
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                enabled: Config.ambientBreatheEnabled === true
                opacity: enabled ? 1.0 : 0.35

                Behavior on opacity { NumberAnimation { duration: 150 } }

                SliderRow {
                    label: "Intensity"
                    icon: "graphic_eq"
                    from: 0; to: 1; stepSize: 0.01
                    value: Config.ambientBreatheIntensity
                    decimals: 2
                    onChanged: (v) => Config.ambientBreatheIntensity = v
                }
            }
        }

        // Sub-options wrapper, dimmed when disabled
        ColumnLayout {
            Layout.fillWidth: true
            spacing: flickable.cardMargin
            enabled: Config.showDesktopCava === true
            opacity: enabled ? 1.0 : 0.35

            Behavior on opacity { NumberAnimation { duration: 150 } }

            // ==========================================
            // 2. LAYOUT STYLE
            // ==========================================
            SettingsCard {
                Text {
                    text: "LAYOUT STYLE"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 8
                    rowSpacing: 8

                    Repeater {
                        model: [
                            { name: "Bars",     style: "bars" },
                            { name: "Mirrored", style: "mirrored" },
                            { name: "Wave",      style: "wave" },
                            { name: "Radial",   style: "radial" }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: Config.cornerRadius / 2

                            readonly property bool isSelected: Config.cavaStyle === modelData.style
                            color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (styleHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                            border.width: isSelected ? 1 : 0
                            border.color: Config.accent

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                color: isSelected ? Config.accent : Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: isSelected
                            }

                            TapHandler { onTapped: Config.cavaStyle = modelData.style }
                            HoverHandler { id: styleHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

            // ==========================================
            // 3. RESPONSE / BEHAVIOR
            // ==========================================
            SettingsCard {
                Text {
                    text: "RESPONSE"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                }

                SliderRow {
                    label: "Bars"
                    icon: "bar_chart"
                    from: 8; to: 160; stepSize: 1
                    value: Config.cavaBars
                    decimals: 0
                    onChanged: (v) => Config.cavaBars = Math.round(v)
                }

                SliderRow {
                    label: "Sensitivity"
                    icon: "speed"
                    from: 10; to: 400; stepSize: 5
                    value: Config.cavaSensitivity
                    suffix: "%"
                    decimals: 0
                    onChanged: (v) => Config.cavaSensitivity = Math.round(v)
                }

                SliderRow {
                    label: "Smoothing"
                    icon: "blur_on"
                    from: 0; to: 1; stepSize: 0.01
                    value: Config.cavaSmoothing
                    decimals: 2
                    onChanged: (v) => Config.cavaSmoothing = v
                }

                SliderRow {
                    label: "Framerate"
                    icon: "speed"
                    from: 24; to: 144; stepSize: 1
                    value: Config.cavaFramerate
                    suffix: " fps"
                    decimals: 0
                    onChanged: (v) => Config.cavaFramerate = Math.round(v)
                }
            }

            // ==========================================
            // 4. APPEARANCE
            // ==========================================
            SettingsCard {
                Text {
                    text: "BAR APPEARANCE"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                }

                SliderRow {
                    label: "Bar Width"
                    icon: "width"
                    from: 2; to: 24; stepSize: 1
                    value: Config.cavaBarWidth
                    suffix: "px"
                    decimals: 0
                    onChanged: (v) => Config.cavaBarWidth = v
                }

                SliderRow {
                    label: "Bar Gap"
                    icon: "space_bar"
                    from: 0; to: 16; stepSize: 1
                    value: Config.cavaBarGap
                    suffix: "px"
                    decimals: 0
                    onChanged: (v) => Config.cavaBarGap = v
                }

                SliderRow {
                    label: "Corner Radius"
                    icon: "rounded_corner"
                    from: 0; to: 12; stepSize: 1
                    value: Config.cavaBarRadius
                    suffix: "px"
                    decimals: 0
                    onChanged: (v) => Config.cavaBarRadius = v
                }

                SliderRow {
                    label: "Max Height"
                    icon: "height"
                    from: 40; to: 400; stepSize: 5
                    value: Config.cavaMaxHeight
                    suffix: "px"
                    decimals: 0
                    onChanged: (v) => Config.cavaMaxHeight = v
                }

                SliderRow {
                    visible: Config.cavaStyle === "radial"
                    label: "Ring Radius"
                    icon: "radio_button_unchecked"
                    from: 30; to: 260; stepSize: 5
                    value: Config.cavaRingRadius
                    suffix: "px"
                    decimals: 0
                    onChanged: (v) => Config.cavaRingRadius = v
                }
            }

            // ==========================================
            // 5. COLOR
            // ==========================================
            SettingsCard {
                Text {
                    text: "COLOR"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 8
                    rowSpacing: 8

                    Repeater {
                        model: [
                            { name: "Accent",   mode: "accent" },
                            { name: "Gradient", mode: "gradient" },
                            { name: "Rainbow",  mode: "rainbow" },
                            { name: "Solid",    mode: "solid" }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: Config.cornerRadius / 2

                            readonly property bool isSelected: Config.cavaColorMode === modelData.mode
                            color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (colorHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                            border.width: isSelected ? 1 : 0
                            border.color: Config.accent

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                color: isSelected ? Config.accent : Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: isSelected
                            }

                            TapHandler { onTapped: Config.cavaColorMode = modelData.mode }
                            HoverHandler { id: colorHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    visible: Config.cavaColorMode === "gradient"

                    ColorField {
                        label: "GRADIENT START"
                        value: Config.cavaGradientStart
                        onCommitted: (v) => Config.cavaGradientStart = v
                    }
                    ColorField {
                        label: "GRADIENT END"
                        value: Config.cavaGradientEnd
                        onCommitted: (v) => Config.cavaGradientEnd = v
                    }
                }

                ColorField {
                    Layout.fillWidth: true
                    visible: Config.cavaColorMode === "solid"
                    label: "SOLID COLOR"
                    value: Config.cavaSolidColor
                    onCommitted: (v) => Config.cavaSolidColor = v
                }

                SliderRow {
                    visible: Config.cavaColorMode === "rainbow"
                    label: "Cycle Speed"
                    icon: "cyclone"
                    from: 0; to: 60; stepSize: 1
                    value: Config.cavaRainbowSpeed
                    suffix: "°/s"
                    decimals: 0
                    onChanged: (v) => Config.cavaRainbowSpeed = v
                }
            }

            // ==========================================
            // 6. DISPLAY OPTIONS
            // ==========================================
            SettingsCard {
                Text {
                    text: "DISPLAY OPTIONS"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        Layout.fillWidth: true
                        text: "Glow Effect"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                    }
                    ToggleSwitch {
                        checked: Config.cavaShowGlow !== false
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.cavaShowGlow = !Config.cavaShowGlow
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        Layout.fillWidth: true
                        text: "Show Background"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                    }
                    ToggleSwitch {
                        checked: Config.cavaShowBackground !== false
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.cavaShowBackground = !Config.cavaShowBackground
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        Layout.fillWidth: true
                        text: "Show Border"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                    }
                    ToggleSwitch {
                        checked: Config.cavaShowBorder !== false
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.cavaShowBorder = !Config.cavaShowBorder
                        }
                    }
                }
            }

            // ==========================================
            // 7. TARGET DISPLAYS
            // ==========================================
            SettingsCard {
                Text {
                    text: "SHOW VISUALIZER ON THESE DISPLAYS"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                }

                RowLayout {
                    spacing: 8

                    Repeater {
                        model: Quickshell.screens

                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: 90
                            implicitHeight: 32
                            radius: Config.cornerRadius / 2

                            readonly property bool isSelected: Config.enabledCavaScreens.length === 0 || Config.enabledCavaScreens.includes(modelData.name)
                            color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (dispHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                            border.width: isSelected ? 1 : 0
                            border.color: Config.accent

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: modelData.name
                                    color: isSelected ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: isSelected
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: isSelected ? "✓" : "+"
                                    color: isSelected ? Config.accent : Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: isSelected
                                }
                            }

                            TapHandler { onTapped: Config.toggleCavaScreen(modelData.name) }
                            HoverHandler { id: dispHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }
        }
    }
}
