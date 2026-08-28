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
                text: "RETRO SCREEN SHADER CONFIGURATION"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontSubhead)
                font.bold: true
            }

            // MASTER TOGGLE
            SettingsToggleRow {
                title: "Enable Screen Shader"
                subtitle: "Apply custom post-processing fragment shaders across your displays"
                checked: Config.pixelShaderEnabled === true
                onToggled: {
                    Config.pixelShaderEnabled = !Config.pixelShaderEnabled
                    Config.updateShader()
                }
            }

            // OPTIONS CONTAINER
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                enabled: Config.pixelShaderEnabled === true
                opacity: Config.pixelShaderEnabled ? 1.0 : 0.4

                Behavior on opacity { NumberAnimation { duration: 160 } }

                // SHADER MODE SELECTOR
                ColumnLayout {
                    spacing: 6

                    Text {
                        text: "SHADER PRESET"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 8

                        Repeater {
                            model: [
                                { name: "Pixelate / 8-Bit", id: "pixelate" },
                                { name: "Arcade CRT", id: "crt" },
                                { name: "Macintosh 1-Bit", id: "mac1bit" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: 140
                                implicitHeight: 36
                                radius: Config.cornerRadius / 2

                                readonly property bool isSelected: (Config.pixelShaderMode || "pixelate") === modelData.id
                                color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (modeHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                                border.width: isSelected ? 2 : 0
                                border.color: Config.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: isSelected ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: isSelected
                                }

                                TapHandler { 
                                    onTapped: {
                                        Config.pixelShaderMode = modelData.id
                                        Config.updateShader()
                                    }
                                }
                                HoverHandler { id: modeHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }

                // PIXEL DENSITY / SCALE (PIXELATE ONLY)
                ColumnLayout {
                    spacing: 6
                    visible: (Config.pixelShaderMode || "pixelate") === "pixelate"

                    Text {
                        text: "PIXEL SCALE"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 8

                        Repeater {
                            model: [
                                { name: "Subtle (2px)", val: 2.0 },
                                { name: "Retro (3px)", val: 3.0 },
                                { name: "Chunky (4px)", val: 4.0 }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: 130
                                implicitHeight: 36
                                radius: Config.cornerRadius / 2

                                readonly property bool isSelected: (Config.pixelShaderSize || 2.0) === modelData.val
                                color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (szHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                                border.width: isSelected ? 2 : 0
                                border.color: Config.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: isSelected ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: isSelected
                                }

                                TapHandler { 
                                    onTapped: {
                                        Config.pixelShaderSize = modelData.val
                                        Config.updateShader()
                                    }
                                }
                                HoverHandler { id: szHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }

                // COLOR DEPTH (PIXELATE ONLY)
                ColumnLayout {
                    spacing: 6
                    visible: (Config.pixelShaderMode || "pixelate") === "pixelate"

                    Text {
                        text: "COLOR DEPTH"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 8

                        Repeater {
                            model: [
                                { name: "32 Steps (Clean)", val: 32.0 },
                                { name: "16 Steps (16-Bit)", val: 16.0 },
                                { name: "8 Steps (8-Bit)", val: 8.0 },
                                { name: "256 (True Color)", val: 256.0 }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: 130
                                implicitHeight: 36
                                radius: Config.cornerRadius / 2

                                readonly property bool isSelected: (Config.pixelShaderLevels || 32.0) === modelData.val
                                color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (clHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                                border.width: isSelected ? 2 : 0
                                border.color: Config.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: isSelected ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: isSelected
                                }

                                TapHandler { 
                                    onTapped: {
                                        Config.pixelShaderLevels = modelData.val
                                        Config.updateShader()
                                    }
                                }
                                HoverHandler { id: clHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }

                // PALETTE PRESET (PIXELATE ONLY)
                ColumnLayout {
                    spacing: 6
                    visible: (Config.pixelShaderMode || "pixelate") === "pixelate"

                    Text {
                        text: "COLOR PALETTE"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 8

                        Repeater {
                            model: [
                                { name: "RGB True", id: "default" },
                                { name: "Game Boy DMG", id: "gameboy" },
                                { name: "Amber CRT", id: "amber" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: 130
                                implicitHeight: 36
                                radius: Config.cornerRadius / 2

                                readonly property bool isSelected: (Config.pixelShaderPalette || "default") === modelData.id
                                color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (palHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                                border.width: isSelected ? 2 : 0
                                border.color: Config.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: isSelected ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: isSelected
                                }

                                TapHandler { 
                                    onTapped: {
                                        Config.pixelShaderPalette = modelData.id
                                        Config.updateShader()
                                    }
                                }
                                HoverHandler { id: palHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }

                // TOGGLE OPTIONS (PIXELATE ONLY)
                ColumnLayout {
                    spacing: 8
                    visible: (Config.pixelShaderMode || "pixelate") === "pixelate"

                    Text {
                        text: "SHADER OPTIONS"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    // BAYER DITHER
                    SettingsToggleRow {
                        title: "Ordered Bayer Dithering"
                        subtitle: "Cross-hatch color transitions instead of flat banding"
                        checked: Config.pixelShaderDither !== false
                        onToggled: {
                            Config.pixelShaderDither = (Config.pixelShaderDither === false)
                            Config.updateShader()
                        }
                    }

                    // PIXEL GRID
                    SettingsToggleRow {
                        title: "Pixel Grid Lines"
                        subtitle: "Simulate physical phosphor gaps between virtual pixels"
                        checked: Config.pixelShaderGrid === true
                        onToggled: {
                            Config.pixelShaderGrid = (Config.pixelShaderGrid !== true)
                            Config.updateShader()
                        }
                    }

                    // ARCADE CONTRAST
                    SettingsToggleRow {
                        title: "Arcade Contrast Boost"
                        subtitle: "Slightly lifts saturation and contrast on dark UI elements"
                        checked: Config.pixelShaderBoost !== false
                        onToggled: {
                            Config.pixelShaderBoost = (Config.pixelShaderBoost === false)
                            Config.updateShader()
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}