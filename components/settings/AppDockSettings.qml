import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Item {
    id: root

    RowLayout {
        anchors.fill: parent
        spacing: 20

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            spacing: 12

            Text {
                text: "APP DOCK CONFIGURATION"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontSubhead)
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: "Shows the apps pinned from the app Launcher as a floating, draggable dock you can drop anywhere on the desktop."
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                wrapMode: Text.WordWrap
            }

            // TOGGLE: ENABLE WIDGET
            SettingsToggleRow {
                title: "Enable App Dock Widget"
                subtitle: "Show the pinned-apps dock overlay on your displays"
                checked: Config.showAppDock !== false
                onToggled: {
                    Config.showAppDock = (Config.showAppDock === false)
                    if (typeof Config.saveConfig === "function") Config.saveConfig()
                    else if (typeof Config.save === "function") Config.save()
                }
            }

            // SUB-OPTIONS WRAPPER (Dims and disables interaction when toggle is off)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                enabled: Config.showAppDock !== false
                opacity: enabled ? 1.0 : 0.35

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                // ORIENTATION SELECTOR
                ColumnLayout {
                    spacing: 6

                    Text {
                        text: "ORIENTATION"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 8

                        Repeater {
                            model: [
                                { name: "Horizontal", style: "horizontal" },
                                { name: "Vertical", style: "vertical" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: 130
                                implicitHeight: 36
                                radius: Config.cornerRadius / 2

                                readonly property bool isSelected: Config.appDockOrientation === modelData.style
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

                                TapHandler { onTapped: Config.appDockOrientation = modelData.style }
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
                        text: "SHOW APP DOCK ON THESE DISPLAYS:"
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

                                readonly property bool isSelected: Config.enabledAppDockScreens.length === 0 || Config.enabledAppDockScreens.includes(modelData.name)
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

                                TapHandler { onTapped: Config.toggleAppDockScreen(modelData.name) }
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

                    SettingsToggleRow {
                        title: "Show Border"
                        subtitle: "Draw a decorative border around the dock"
                        checked: Config.appDockShowBorder !== false
                        onToggled: {
                            Config.appDockShowBorder = (Config.appDockShowBorder === false)
                            if (typeof Config.saveConfig === "function") Config.saveConfig()
                            else if (typeof Config.save === "function") Config.save()
                        }
                    }

                    SettingsToggleRow {
                        title: "Show Background"
                        subtitle: "Display a background panel behind the dock icons"
                        checked: Config.appDockShowBackground !== false
                        onToggled: {
                            Config.appDockShowBackground = (Config.appDockShowBackground === false)
                            if (typeof Config.saveConfig === "function") Config.saveConfig()
                            else if (typeof Config.save === "function") Config.save()
                        }
                    }

                    SettingsToggleRow {
                        title: "Glow Effect"
                        subtitle: "Apply a soft glow effect to hovered icons"
                        checked: Config.appDockShowGlow !== false
                        onToggled: {
                            Config.appDockShowGlow = (Config.appDockShowGlow === false)
                            if (typeof Config.saveConfig === "function") Config.saveConfig()
                            else if (typeof Config.save === "function") Config.save()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Pin or unpin apps from the Launcher (the search icon in the bar) - right-click a result there to toggle its pin."
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.italic: true
                    wrapMode: Text.WordWrap
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
