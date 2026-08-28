import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Item {
    id: root

    // Reusable Geometric / Square Toggle Switch Component
    RowLayout {
        anchors.fill: parent
        spacing: 20

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            spacing: 12

            Text {
                text: "DESKTOP CLOCK CONFIGURATION"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontSubhead)
                font.bold: true
            }

            // TOGGLE: ENABLE WIDGET
            SettingsToggleRow {
                title: "Enable Desktop Clock Widget"
                subtitle: "Show the desktop clock overlay on your displays"
                checked: Config.showDesktopClock !== false
                onToggled: {
                    Config.showDesktopClock = (Config.showDesktopClock === false)
                    if (typeof Config.saveConfig === "function") Config.saveConfig()
                    else if (typeof Config.save === "function") Config.save()
                }
            }

            // SUB-OPTIONS WRAPPER (Dims and disables interaction when clock toggle is off)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                enabled: Config.showDesktopClock !== false
                opacity: enabled ? 1.0 : 0.35

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                // STYLE SELECTOR
                ColumnLayout {
                    spacing: 6

                    Text {
                        text: "CLOCK STYLE"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 8

                        Repeater {
                            model: [
                                { name: "Digital", style: "digital" },
                                { name: "Modern", style: "modern" },
                                { name: "Analog", style: "analog" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: 130
                                implicitHeight: 36
                                radius: Config.cornerRadius / 2

                                readonly property bool isSelected: Config.clockStyle === modelData.style
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

                                TapHandler { onTapped: Config.clockStyle = modelData.style }
                                HoverHandler { id: styleHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }

                // TARGET DISPLAYS SECTION
                ColumnLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    Text {
                        text: "SHOW CLOCK ON THESE DISPLAYS:"
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

                                readonly property bool isSelected: Config.enabledClockScreens.length === 0 || Config.enabledClockScreens.includes(modelData.name)
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

                            TapHandler { onTapped: Config.toggleClockScreen(modelData.name) }
                            HoverHandler { id: dispHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

                // DISPLAY OPTIONS
                ColumnLayout {
                    spacing: 8

                    Text {
                        text: "DISPLAY OPTIONS"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    // TOGGLE BORDER
                    SettingsToggleRow {
                        title: "Show Border"
                        subtitle: "Draw a decorative border around the clock widget"
                        checked: Config.clockShowBorder !== false
                        onToggled: {
                            Config.clockShowBorder = (Config.clockShowBorder === false)
                            if (typeof Config.saveConfig === "function") Config.saveConfig()
                            else if (typeof Config.save === "function") Config.save()
                        }
                    }

                    // TOGGLE BACKGROUND
                    SettingsToggleRow {
                        title: "Show Background"
                        subtitle: "Display a background panel behind the clock"
                        checked: Config.clockShowBackground !== false
                        onToggled: {
                            Config.clockShowBackground = (Config.clockShowBackground === false)
                            if (typeof Config.saveConfig === "function") Config.saveConfig()
                            else if (typeof Config.save === "function") Config.save()
                        }
                    }

                    // TOGGLE GLOW EFFECT
                    SettingsToggleRow {
                        title: "Glow Effect"
                        subtitle: "Apply a soft glow effect to the clock display"
                        checked: Config.clockShowGlow !== false
                        onToggled: {
                            Config.clockShowGlow = (Config.clockShowGlow === false)
                            if (typeof Config.saveConfig === "function") Config.saveConfig()
                            else if (typeof Config.save === "function") Config.save()
                        }
                    }

                    // TOGGLE SECONDS
                    SettingsToggleRow {
                        title: "Show Seconds"
                        subtitle: "Include seconds in the clock time display"
                        checked: Config.clockShowSeconds !== false
                        onToggled: {
                            Config.clockShowSeconds = (Config.clockShowSeconds === false)
                            if (typeof Config.saveConfig === "function") Config.saveConfig()
                            else if (typeof Config.save === "function") Config.save()
                        }
                    }

                    // TOGGLE 12-HOUR FORMAT
                    SettingsToggleRow {
                        title: "Use 12-Hour Format"
                        subtitle: "Display time in 12-hour instead of 24-hour format"
                        checked: Config.clockUse12Hour !== false
                        onToggled: {
                            Config.clockUse12Hour = (Config.clockUse12Hour === false)
                            if (typeof Config.saveConfig === "function") Config.saveConfig()
                            else if (typeof Config.save === "function") Config.save()
                        }
                    }

                    // TOGGLE AM/PM (DIGITAL & 12-HOUR ONLY)
                    SettingsToggleRow {
                        visible: Config.clockUse12Hour && Config.clockStyle === "digital"
                        title: "Show AM/PM"
                        subtitle: "Show the AM/PM indicator next to the time (digital 12-hour mode only)"
                        checked: Config.clockShowAmPm !== false
                        onToggled: {
                            Config.clockShowAmPm = (Config.clockShowAmPm === false)
                            if (typeof Config.saveConfig === "function") Config.saveConfig()
                            else if (typeof Config.save === "function") Config.save()
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}