import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."

Flickable {
    id: root
    anchors.fill: parent
    contentHeight: mainColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: mainColumn
        width: parent.width
        spacing: 10

        Text {
            text: "UNIFIED SURFACE GEOMETRY"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                spacing: 6

                Text { 
                    text: "Wing & Corner Radius"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    Layout.alignment: Qt.AlignHCenter 
                }

                RowLayout {
                    spacing: 6
                    Layout.alignment: Qt.AlignHCenter

                    // Minus Button
                    Rectangle {
                        implicitWidth: 32; implicitHeight: 32
                        radius: 8
                        color: minusHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(0, 0, 0, 0.3)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1

                        Text { 
                            anchors.centerIn: parent 
                            text: "-" 
                            color: Config.textMain 
                            font.bold: true 
                            font.pixelSize: 16 
                        }

                        TapHandler { onTapped: Config.surfaceRadius = Math.max(0, Config.surfaceRadius - 1) }
                        HoverHandler { id: minusHover; cursorShape: Qt.PointingHandCursor }
                    }

                    // Value Box
                    Rectangle {
                        implicitWidth: 48; implicitHeight: 32
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.4)
                        border.color: Qt.rgba(255, 255, 255, 0.1)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: Config.surfaceRadius.toString()
                            color: Config.accent
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontSubhead)
                            font.bold: true
                        }
                    }

                    // Plus Button
                    Rectangle {
                        implicitWidth: 32; implicitHeight: 32
                        radius: 8
                        color: plusHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(0, 0, 0, 0.3)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1

                        Text { 
                            anchors.centerIn: parent 
                            text: "+" 
                            color: Config.textMain 
                            font.bold: true 
                            font.pixelSize: 16 
                        }

                        TapHandler { onTapped: Config.surfaceRadius = Config.surfaceRadius + 1 }
                        HoverHandler { id: plusHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        Text {
            text: "THEMES & COLORS"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            font.bold: true
        }

        // Border, Gradient, Blur, and Xray Controls
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

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

            RowLayout {
                spacing: 8
                Rectangle {
                    implicitWidth: 18; implicitHeight: 18; radius: 4
                    color: Config.enableBlur ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                    Text { anchors.centerIn: parent; text: "✓"; color: Config.bgBase; visible: Config.enableBlur; font.pixelSize: 11; font.bold: true }
                    TapHandler { onTapped: Config.enableBlur = !Config.enableBlur }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                Text { text: "Blur"; color: Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption) }
            }

            RowLayout {
                spacing: 8
                opacity: Config.enableBlur ? 1.0 : 0.4
                Rectangle {
                    implicitWidth: 18; implicitHeight: 18; radius: 4
                    color: (Config.enableBlur && Config.enableXray) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                    Text { anchors.centerIn: parent; text: "✓"; color: Config.bgBase; visible: Config.enableBlur && Config.enableXray; font.pixelSize: 11; font.bold: true }
                    TapHandler { onTapped: { if (Config.enableBlur) Config.enableXray = !Config.enableXray } }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                Text { text: "Xray"; color: Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption) }
            }
        }

        // Opacity Slider Block
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text { 
                text: "Opacity"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption) 
            }

            Slider {
                id: opacitySlider
                Layout.fillWidth: true
                from: 0.1
                to: 1.0
                value: Config.shellOpacity
                onValueChanged: Config.shellOpacity = value

                background: Rectangle {
                    x: opacitySlider.leftPadding
                    y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                    implicitWidth: 100
                    implicitHeight: 4
                    width: opacitySlider.availableWidth
                    height: implicitHeight
                    radius: 2
                    color: Qt.rgba(255, 255, 255, 0.1)

                    Rectangle {
                        width: opacitySlider.visualPosition * parent.width
                        height: parent.height
                        color: Config.accent
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: opacitySlider.leftPadding + opacitySlider.visualPosition * (opacitySlider.availableWidth - width)
                    y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                    implicitWidth: 14
                    implicitHeight: 14
                    radius: 7
                    color: opacitySlider.pressed ? Config.accent : Config.textMain
                }
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

        // EQUAL SPACING PALETTE GRID
        Item {
            Layout.fillWidth: true
            implicitHeight: paletteGrid.implicitHeight

            GridLayout {
                id: paletteGrid
                anchors.centerIn: parent
                columns: 10
                rowSpacing: 10
                columnSpacing: 10
                opacity: Config.useCustomColors ? 0.4 : 1.0

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
                        implicitWidth: 28
                        implicitHeight: 28

                        readonly property var itemData: modelData
                        readonly property bool isDummy: itemData.isDummy
                        readonly property int themeIdx: itemData.realIndex
                        readonly property var themeObj: itemData.theme
                        readonly property bool isCustomTheme: !isDummy && themeObj && themeObj.isCustom === true

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: isDummy ? "transparent" : themeObj.accent
                            border.color: (!isDummy && !Config.useCustomColors && Config.currentThemeIndex === themeIdx) ? Config.textMain : "transparent"
                            border.width: (!isDummy && !Config.useCustomColors && Config.currentThemeIndex === themeIdx) ? 2 : 0
                            visible: !isDummy

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
                                    if (isCustomTheme) {
                                        deletePalette(themeIdx)
                                    }
                                }
                            }

                            HoverHandler { 
                                id: hover
                                enabled: !isDummy
                                cursorShape: Qt.PointingHandCursor 
                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: -2
                                width: 12; height: 12; radius: 6
                                color: "#e74c3c"
                                visible: isCustomTheme && hover.hovered

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
                                    onTapped: deletePalette(themeIdx)
                                }
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
                    implicitHeight: 28
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
                    implicitHeight: 28
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
                    implicitHeight: 28
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
    }

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