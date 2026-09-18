import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."

// Hyprland general/animations/input knobs not already covered by Appearance
// (border color/thickness/rounding/blur/xray live there). Writes into
// hypr_style.lua via Config.syncHyprlandBorders() - see HyprlandConfig.qml.
Flickable {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    contentWidth: width
    contentHeight: mainColumn.implicitHeight + 32
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        active: root.moving || root.flicking
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

    // Shared "row of N labeled buttons, one active" picker used below for
    // layout mode and follow-mouse mode.
    component SegmentedPicker : RowLayout {
        id: pickerRoot
        Layout.fillWidth: true
        spacing: 8
        property var options: [] // [{ value, label }]
        property var current: null
        signal picked(var value)

        Repeater {
            model: pickerRoot.options
            delegate: Rectangle {
                id: segBtn
                Layout.fillWidth: true
                implicitHeight: 36
                radius: Config.cornerRadius / 2

                readonly property bool isCurrent: pickerRoot.current === modelData.value
                color: segBtn.isCurrent ? Qt.rgba(255, 255, 255, 0.12) : (segHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                border.width: segBtn.isCurrent ? 1 : 0
                border.color: Config.accent

                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: segBtn.isCurrent ? Config.accent : Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.bold: segBtn.isCurrent
                }

                TapHandler { onTapped: pickerRoot.picked(modelData.value) }
                HoverHandler { id: segHover; cursorShape: Qt.PointingHandCursor }
            }
        }
    }

    ColumnLayout {
        id: mainColumn
        width: Math.min(root.width - (root.cardMargin * 2), 620)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.cardMargin

        Text {
            Layout.fillWidth: true
            text: "HYPRLAND"
            color: Config.textMain
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontSubhead)
            font.bold: true
        }

        Text {
            text: "Window manager behavior - layout, gaps, animations, and input - written into hypr_style.lua alongside the border/theme sync."
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        // ==========================================
        // GENERAL & LAYOUT CARD
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: generalCol.implicitHeight + 28
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.05)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)

            ColumnLayout {
                id: generalCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Text {
                    text: "GENERAL & LAYOUT"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    font.bold: true
                }

                Text {
                    text: "Layout Mode"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }

                SegmentedPicker {
                    options: [
                        { value: "dwindle",   label: "Dwindle" },
                        { value: "master",    label: "Master" },
                        { value: "scrolling", label: "Scrolling" }
                    ]
                    current: Config.hyprLayoutMode
                    onPicked: (value) => Config.hyprLayoutMode = value
                }

                // Inner Gaps Slider
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    RowLayout {
                        spacing: 6
                        Layout.preferredWidth: 80
                        Text {
                            text: "grid_view"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            color: Config.textMuted
                        }
                        Text {
                            text: "Gaps"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                        }
                    }

                    ThickHorizontalSlider {
                        id: gapsSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 30
                        stepSize: 1
                        value: Config.hyprGapsIn
                        onValueChanged: Config.hyprGapsIn = value
                    }

                    Rectangle {
                        implicitWidth: 42; implicitHeight: 22; radius: 6
                        color: Qt.rgba(0, 0, 0, 0.3)
                        border.width: 1; border.color: Config.accent
                        Text {
                            anchors.centerIn: parent
                            text: Math.round(gapsSlider.value) + "px"
                            color: Config.accent
                            font.family: Config.sysFont
                            font.bold: true
                            font.pixelSize: 10
                        }
                    }
                }

                SettingsToggleRow {
                    title: "Resize From Border"
                    subtitle: "Grab a window's edge anywhere to resize it, not just its exact border line"
                    checked: Config.hyprResizeOnBorder === true
                    onToggled: Config.hyprResizeOnBorder = !Config.hyprResizeOnBorder
                }

                SettingsToggleRow {
                    title: "Allow Screen Tearing"
                    subtitle: "Lets fullscreen apps that opt in (e.g. some games) skip vsync for lower latency"
                    checked: Config.hyprAllowTearing === true
                    onToggled: Config.hyprAllowTearing = !Config.hyprAllowTearing
                }
            }
        }

        // ==========================================
        // ANIMATIONS CARD
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: animCol.implicitHeight + 28
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.05)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)

            ColumnLayout {
                id: animCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Text {
                    text: "ANIMATIONS"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    font.bold: true
                }

                SettingsToggleRow {
                    title: "Window Manager Animations"
                    subtitle: "Master switch for Hyprland's own window/workspace/layer animations"
                    checked: Config.hyprAnimationsEnabled !== false
                    onToggled: Config.hyprAnimationsEnabled = (Config.hyprAnimationsEnabled === false)
                }
            }
        }

        // ==========================================
        // INPUT CARD
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: inputCol.implicitHeight + 28
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.05)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)

            ColumnLayout {
                id: inputCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Text {
                    text: "INPUT"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    font.bold: true
                }

                // Sensitivity Slider
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    RowLayout {
                        spacing: 6
                        Layout.preferredWidth: 80
                        Text {
                            text: "mouse"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            color: Config.textMuted
                        }
                        Text {
                            text: "Sensitivity"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                        }
                    }

                    ThickHorizontalSlider {
                        id: sensSlider
                        Layout.fillWidth: true
                        from: -1.0
                        to: 1.0
                        stepSize: 0.05
                        value: Config.hyprSensitivity
                        onValueChanged: Config.hyprSensitivity = value
                    }

                    Rectangle {
                        implicitWidth: 46; implicitHeight: 22; radius: 6
                        color: Qt.rgba(0, 0, 0, 0.3)
                        border.width: 1; border.color: Config.accent
                        Text {
                            anchors.centerIn: parent
                            text: sensSlider.value.toFixed(2)
                            color: Config.accent
                            font.family: Config.sysFont
                            font.bold: true
                            font.pixelSize: 10
                        }
                    }
                }

                Text {
                    text: "Focus Follows Mouse"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }

                SegmentedPicker {
                    options: [
                        { value: 0, label: "Off" },
                        { value: 1, label: "On" },
                        { value: 2, label: "Loose" },
                        { value: 3, label: "Full" }
                    ]
                    current: Config.hyprFollowMouse
                    onPicked: (value) => Config.hyprFollowMouse = value
                }

                SettingsToggleRow {
                    title: "Natural Scroll (Touchpad)"
                    subtitle: "Reverses touchpad scroll direction to match touch-screen conventions"
                    checked: Config.hyprNaturalScroll === true
                    onToggled: Config.hyprNaturalScroll = !Config.hyprNaturalScroll
                }
            }
        }

        Item { Layout.preferredHeight: 8 }
    }
}
