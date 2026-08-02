import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."

ColumnLayout {
    id: root
    spacing: 14

    property var allFonts: Qt.fontFamilies()
    property var filteredFonts: {
        if (Config.fontSearchFilter.trim() === "") return allFonts
        return allFonts.filter(f => f.toLowerCase().includes(Config.fontSearchFilter.toLowerCase()))
    }

    Text {
        text: "TYPOGRAPHY & SCALING"
        color: Config.textMuted
        font.family: Config.sysFont
        font.pixelSize: Config.size(Config.fontCaption)
        font.bold: true
    }

    Text { text: "Font Scaling"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro); font.bold: true }

    RowLayout {
        spacing: 8

        Repeater {
            model: ["Small", "Normal", "Large"]
            delegate: Rectangle {
                implicitWidth: 130
                implicitHeight: 36
                radius: Config.cornerRadius / 2

                readonly property bool isSelected: Config.fontScaleIndex === index
                color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (scaleHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                border.width: isSelected ? 1 : 0
                border.color: Config.accent

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: isSelected ? Config.accent : Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.bold: isSelected
                }

                TapHandler { onTapped: Config.fontScaleIndex = index }
                HoverHandler { id: scaleHover; cursorShape: Qt.PointingHandCursor }
            }
        }
    }

    Text { text: "Filter Fonts"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro); font.bold: true }

    // SEARCH FIELD CONTAINER
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 36
        radius: Config.cornerRadius / 2
        color: fontInputHover.hovered || fontSearchInput.activeFocus ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.15)
        border.color: fontSearchInput.activeFocus ? Config.accent : "transparent"
        border.width: 1

        HoverHandler { id: fontInputHover }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            spacing: 8

            Text {
                text: "search"
                color: Config.textMuted
                font.family: "Material Symbols Outlined"
                font.pixelSize: 18
            }

            TextInput {
                id: fontSearchInput
                Layout.fillWidth: true
                text: Config.fontSearchFilter
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontBody)
                clip: true
                selectByMouse: true
                onTextChanged: Config.fontSearchFilter = text
            }

            Text {
                text: "close"
                color: Config.textMuted
                font.family: "Material Symbols Outlined"
                font.pixelSize: 16
                visible: fontSearchInput.text.length > 0

                TapHandler {
                    onTapped: {
                        fontSearchInput.text = ""
                        Config.fontSearchFilter = ""
                    }
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }
    }

    // FONT LIST CONTAINER
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Qt.rgba(0, 0, 0, 0.15)
        radius: Config.cornerRadius / 2
        clip: true

        ListView {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 2
            model: root.filteredFonts

            delegate: Rectangle {
                required property string modelData
                width: ListView.view.width
                implicitHeight: 32
                radius: Config.cornerRadius / 2

                readonly property bool isSelected: Config.sysFont === modelData
                color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (fHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10

                    Text {
                        text: modelData
                        color: isSelected ? Config.accent : Config.textMain
                        font.family: modelData
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: isSelected
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: "✓"
                        color: Config.accent
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        visible: isSelected
                    }
                }

                TapHandler { onTapped: Config.sysFont = modelData }
                HoverHandler { id: fHover; cursorShape: Qt.PointingHandCursor }
            }

            ScrollBar.vertical: ScrollBar { active: true }
        }
    }
}