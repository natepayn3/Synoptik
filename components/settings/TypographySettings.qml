import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."

SettingsPage {
    id: root

    title: "Typography"
    description: "Global shell font family, type scale and font rasterisation."
    icon: "match_case"

    readonly property var allFonts: Qt.fontFamilies()
    readonly property var filteredFonts: {
        const filter = Config.fontSearchFilter ? Config.fontSearchFilter.trim().toLowerCase() : ""
        if (filter === "") return root.allFonts
        return root.allFonts.filter(f => f.toLowerCase().includes(filter))
    }

    SettingsCard {
        title: "Live Type Specimen"
        icon: "text_fields"
        subtitle: "Real-time preview of the active font family and scaling."

        accessory: SettingsButton {
            label: "Reset Font"
            icon: "restart_alt"
            visible: Config.sysFont !== ""
            onClicked: Config.sysFont = ""
        }

        // Interactive Specimen Board
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: specimenContent.implicitHeight + 24
            radius: Config.cornerRadius - 2
            color: SettingsStyle.controlBg
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.08)

            ColumnLayout {
                id: specimenContent
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Active Font Name Banner
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        implicitWidth: 24; implicitHeight: 24; radius: 6
                        color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.18)
                        border.width: 1
                        border.color: Config.accent
                        Text {
                            anchors.centerIn: parent
                            text: "font_download"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 14
                            color: Config.accent
                        }
                    }

                    Text {
                        text: Config.sysFont !== "" ? Config.sysFont : "System Default (Sans-Serif)"
                        color: Config.accent
                        font.family: Config.sysFont !== "" ? Config.sysFont : "system-ui"
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        implicitWidth: scaleLabel.implicitWidth + 14
                        implicitHeight: 22
                        radius: 11
                        color: Qt.rgba(255, 255, 255, 0.08)

                        Text {
                            id: scaleLabel
                            anchors.centerIn: parent
                            text: Config.fontScaleIndex === 0 ? "Compact 85%" : (Config.fontScaleIndex === 2 ? "Large 120%" : "Standard 100%")
                            font.family: Config.sysFont
                            font.pixelSize: 10
                            font.bold: true
                            color: Config.textMuted
                        }
                    }
                }

                // Headline Specimen
                Text {
                    Layout.fillWidth: true
                    text: "The quick brown fox jumps over the lazy dog."
                    color: Config.textMain
                    font.family: Config.sysFont !== "" ? Config.sysFont : "system-ui"
                    font.pixelSize: Config.size(Config.fontTitle)
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                // Subtitle & Body Specimen
                Text {
                    Layout.fillWidth: true
                    text: "Sphinx of black quartz, judge my vow. 0123456789 — $ € £ ¥ • @ # % & * ( ) [ ] { }"
                    color: Config.textMuted
                    font.family: Config.sysFont !== "" ? Config.sysFont : "system-ui"
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.letterSpacing: 0.5
                    wrapMode: Text.WordWrap
                }

                // Mini UI Widgets Preview Mockup
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 18
                    color: Qt.rgba(255, 255, 255, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.08)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 10

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "schedule"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 15
                                color: Config.accent
                            }
                            Text {
                                text: Qt.formatTime(new Date(), "hh:mm ap")
                                font.family: Config.sysFont !== "" ? Config.sysFont : "system-ui"
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: true
                                color: Config.textMain
                            }
                        }

                        Item { Layout.fillWidth: true }

                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: ["1", "2", "3", "4"]
                                delegate: Rectangle {
                                    implicitWidth: 20; implicitHeight: 20; radius: 10
                                    color: index === 0 ? Config.accent : Qt.rgba(255, 255, 255, 0.08)
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.family: Config.sysFont !== "" ? Config.sysFont : "system-ui"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: index === 0 ? Config.bgBase : Config.textMain
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "battery_charging_full"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 15
                                color: "#00E676"
                            }
                            Text {
                                text: "98%"
                                font.family: Config.sysFont !== "" ? Config.sysFont : "system-ui"
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: true
                                color: Config.textMain
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsCard {
        title: "UI Font Scaling"
        icon: "format_size"

        SettingsTileGrid {
            currentValue: Config.fontScaleIndex
            columns: 3
            tileHeight: 64
            model: [
                { label: "Small",  value: 0, icon: "text_decrease", desc: "Compact (85%)" },
                { label: "Normal", value: 1, icon: "text_fields",   desc: "Standard (100%)" },
                { label: "Large",  value: 2, icon: "text_increase", desc: "Comfortable (120%)" }
            ]
            onSelected: value => Config.fontScaleIndex = value
        }
    }

    SettingsCard {
        title: "Rasterisation"
        icon: "blur_on"

        SettingsToggleRow {
            title: "Crisp Native Font Rendering"
            subtitle: "Bypasses Qt distance-field rendering for native FreeType subpixel antialiasing and stem hinting"
            checked: Config.nativeFontRendering
            onToggled: Config.nativeFontRendering = !Config.nativeFontRendering
        }
    }

    SettingsCard {
        title: "Font Library"
        icon: "font_download"
        subtitle: "Pick any installed family to apply shell-wide."

        accessory: Rectangle {
            implicitWidth: fontCountText.implicitWidth + 16
            implicitHeight: 24
            radius: SettingsStyle.controlRadius * 0.8
            color: SettingsStyle.controlBg

            Text {
                id: fontCountText
                anchors.centerIn: parent
                text: root.filteredFonts.length + " fonts"
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.bold: true
                color: Config.textMuted
            }
        }

        SettingsTextField {
            id: fontSearch

            text: Config.fontSearchFilter
            placeholder: "Search fonts by name…"
            icon: "search"
            onEdited: value => Config.fontSearchFilter = value

            trailing: Text {
                text: "close"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 16
                color: clearFontHover.hovered ? Config.textMain : Config.textMuted
                visible: fontSearch.text.length > 0

                TapHandler {
                    onTapped: {
                        fontSearch.text = ""
                        Config.fontSearchFilter = ""
                    }
                }
                HoverHandler { id: clearFontHover; cursorShape: Qt.PointingHandCursor }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 320
            color: SettingsStyle.controlBg
            radius: SettingsStyle.controlRadius
            border.width: 1
            border.color: SettingsStyle.controlBorder
            clip: true

            ListView {
                id: fontListView

                anchors.fill: parent
                anchors.margins: 4
                spacing: 3
                clip: true
                model: root.filteredFonts

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    active: fontListView.moving || fontListView.flicking
                }

                delegate: Rectangle {
                    id: fontRow

                    required property string modelData

                    readonly property bool isSelected: Config.sysFont === fontRow.modelData

                    width: ListView.view.width
                    implicitHeight: 42
                    radius: SettingsStyle.controlRadius
                    color: fontRow.isSelected
                        ? SettingsStyle.accentSoft
                        : (fontRowHover.hovered ? SettingsStyle.controlBgHover : "transparent")
                    border.width: fontRow.isSelected ? 1 : 0
                    border.color: SettingsStyle.accentLine

                    Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 2
                            text: fontRow.modelData
                            color: fontRow.isSelected ? Config.accent : Config.textMain
                            font.family: fontRow.modelData
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: fontRow.isSelected
                            elide: Text.ElideRight
                        }

                        // Specimen rendered in the family itself, so the list
                        // shows what each font actually looks like.
                        Text {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            text: "Aa Bb Gg 123"
                            font.family: fontRow.modelData
                            font.pixelSize: Config.size(Config.fontBody)
                            color: fontRow.isSelected ? Config.accent : Qt.rgba(1, 1, 1, 0.6)
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: "check_circle"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 17
                            color: Config.accent
                            visible: fontRow.isSelected
                        }
                    }

                    TapHandler { onTapped: Config.sysFont = fontRow.modelData }
                    HoverHandler { id: fontRowHover; cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }
}
