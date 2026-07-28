import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."

ColumnLayout {
    id: root
    spacing: 14

    Text {
        text: "THEMES & COLORS"
        color: Config.textMuted
        font.family: Config.sysFont
        font.pixelSize: Config.size(Config.fontCaption)
        font.bold: true
    }

    // Border Toggles
    RowLayout {
        Layout.fillWidth: true
        spacing: 20

        RowLayout {
            spacing: 8
            Rectangle {
                implicitWidth: 18; implicitHeight: 18; radius: 4
                color: Config.showBorders ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                Text { anchors.centerIn: parent; text: "✓"; color: Config.bgBase; visible: Config.showBorders; font.pixelSize: 11; font.bold: true }
                TapHandler { onTapped: Config.showBorders = !Config.showBorders }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
            Text { text: "Borders"; color: Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption) }
        }

        RowLayout {
            spacing: 8
            opacity: Config.showBorders ? 1.0 : 0.4
            Rectangle {
                implicitWidth: 18; implicitHeight: 18; radius: 4
                color: (Config.showBorders && Config.animateGradient) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                Text { anchors.centerIn: parent; text: "✓"; color: Config.bgBase; visible: Config.showBorders && Config.animateGradient; font.pixelSize: 11; font.bold: true }
                TapHandler { onTapped: { if (Config.showBorders) Config.animateGradient = !Config.animateGradient } }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
            Text { text: "Gradient"; color: Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption) }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: "Color Palettes"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontMicro)
            font.bold: true
        }

        Text {
            text: "-"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontMicro)
            font.bold: true
        }

        Text {
            text: Config.useCustomColors ? "Custom (Unsaved)" : (Config.themes[Config.currentThemeIndex] ? Config.themes[Config.currentThemeIndex].name : "")
            color: Config.accent
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontMicro)
            font.bold: true
        }

        Item { Layout.fillWidth: true }
    }

    GridLayout {
        Layout.alignment: Qt.AlignHCenter
        columns: 8
        rowSpacing: 14
        columnSpacing: 14
        opacity: Config.useCustomColors ? 0.4 : 1.0

        Repeater {
            model: Config.themes
            delegate: Item {
                id: themeItem
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignHCenter

                property bool isCustomTheme: modelData.isCustom === true

                Rectangle {
                    anchors.centerIn: parent
                    width: 30; height: 30; radius: 15
                    color: modelData.accent
                    border.color: (!Config.useCustomColors && Config.currentThemeIndex === index) ? Config.textMain : "transparent"
                    border.width: (!Config.useCustomColors && Config.currentThemeIndex === index) ? 2 : 0

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: {
                            Config.useCustomColors = false
                            Config.setTheme(index)
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: {
                            if (themeItem.isCustomTheme) {
                                deletePalette(index)
                            }
                        }
                    }

                    HoverHandler { 
                        id: hover
                        cursorShape: Qt.PointingHandCursor 
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: -2
                        width: 12; height: 12; radius: 6
                        color: "#e74c3c"
                        visible: themeItem.isCustomTheme && hover.hovered

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: "white"
                            font.pixelSize: 10
                            font.bold: true
                            anchors.verticalCenterOffset: -1
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: deletePalette(index)
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: "Custom Hex Overrides"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontMicro)
            font.bold: true
            Layout.fillWidth: true
        }

        Rectangle {
            implicitWidth: 32; implicitHeight: 18; radius: 9
            color: Config.useCustomColors ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

            Rectangle {
                x: Config.useCustomColors ? 16 : 2
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14; radius: 7
                color: Config.useCustomColors ? Config.bgBase : Config.textMuted
                Behavior on x { NumberAnimation { duration: 150 } }
            }

            TapHandler { onTapped: Config.useCustomColors = !Config.useCustomColors }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        enabled: Config.useCustomColors
        opacity: Config.useCustomColors ? 1.0 : 0.4

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            spacing: 3

            Text { text: "Base"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro); Layout.alignment: Qt.AlignHCenter }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Config.cornerRadius / 2
                color: Qt.rgba(0, 0, 0, 0.25)
                border.color: baseInput.activeFocus ? Config.accent : "transparent"
                border.width: 1

                TextInput {
                    id: baseInput
                    anchors.fill: parent
                    anchors.margins: 4
                    text: Config.customBgBase
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    clip: true
                    selectByMouse: true
                    onEditingFinished: if (text.length > 0) Config.customBgBase = text

                    HoverHandler { cursorShape: Qt.IBeamCursor }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            spacing: 3

            Text { text: "Panel"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro); Layout.alignment: Qt.AlignHCenter }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Config.cornerRadius / 2
                color: Qt.rgba(0, 0, 0, 0.25)
                border.color: panelInput.activeFocus ? Config.accent : "transparent"
                border.width: 1

                TextInput {
                    id: panelInput
                    anchors.fill: parent
                    anchors.margins: 4
                    text: Config.customBgPanel
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    clip: true
                    selectByMouse: true
                    onEditingFinished: if (text.length > 0) Config.customBgPanel = text

                    HoverHandler { cursorShape: Qt.IBeamCursor }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            spacing: 3

            Text { text: "Accent"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontMicro); Layout.alignment: Qt.AlignHCenter }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Config.cornerRadius / 2
                color: Qt.rgba(0, 0, 0, 0.25)
                border.color: accentInput.activeFocus ? Config.accent : "transparent"
                border.width: 1

                TextInput {
                    id: accentInput
                    anchors.fill: parent
                    anchors.margins: 4
                    text: Config.customAccent
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    clip: true
                    selectByMouse: true
                    onEditingFinished: if (text.length > 0) Config.customAccent = text

                    HoverHandler { cursorShape: Qt.IBeamCursor }
                }
            }
        }
    }

    // Full-Width Save Palette Row
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: Config.useCustomColors

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 26
            radius: Config.cornerRadius / 2
            color: Qt.rgba(0, 0, 0, 0.25)
            border.color: nameInput.activeFocus ? Config.accent : "transparent"
            border.width: 1

            Text {
                anchors.fill: parent
                anchors.margins: 4
                text: "Palette Name..."
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                verticalAlignment: Text.AlignVCenter
                visible: nameInput.text.length === 0 && !nameInput.activeFocus
            }

            TextInput {
                id: nameInput
                anchors.fill: parent
                anchors.margins: 4
                text: ""
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                onAccepted: saveCurrentPalette()

                HoverHandler { cursorShape: Qt.IBeamCursor }
            }
        }

        Rectangle {
            implicitWidth: 90
            implicitHeight: 26
            radius: Config.cornerRadius / 2
            color: saveHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Config.accent

            Text {
                anchors.centerIn: parent
                text: "Save Palette"
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.bold: true
                color: saveHover.hovered ? Config.accent : Config.bgBase
            }

            TapHandler {
                onTapped: saveCurrentPalette()
            }

            HoverHandler { id: saveHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Item { Layout.fillHeight: true }

    // Helpers
    function saveCurrentPalette() {
        var paletteName = nameInput.text.trim()
        if (paletteName.length === 0) {
            paletteName = "Custom " + (Config.themes.length + 1)
        }

        var newTheme = {
            name: paletteName,
            bgBase: Config.customBgBase,
            bgPanel: Config.customBgPanel,
            accent: Config.customAccent,
            isCustom: true
        }

        Config.addCustomTheme(newTheme)
        nameInput.text = ""
        Config.useCustomColors = false
    }

    function deletePalette(idx) {
        Config.removeCustomTheme(idx)
    }
}