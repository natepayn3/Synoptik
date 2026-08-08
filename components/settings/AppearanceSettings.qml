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
            radius: 4
            color: Qt.rgba(255, 255, 255, 0.1)

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                color: Config.accent
                radius: 4
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            implicitWidth: 16
            implicitHeight: 16
            radius: 8
            color: slider.pressed ? Config.accent : Config.textMain
        }
    }

    ColumnLayout {
        id: mainColumn
        width: parent.width
        spacing: 12

        // ==========================================
        // GEOMETRY SECTION
        // ==========================================
        Text {
            text: "UNIFIED SURFACE GEOMETRY"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            font.bold: true
        }

        // --- Corners Slider ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Corners"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                Layout.preferredWidth: 60
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

            Text {
                text: Math.round(cornersSlider.value).toString()
                color: Config.accent
                font.family: Config.sysFont
                font.bold: true
                font.pixelSize: Config.size(Config.fontCaption)
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 36
            }
        }

        // --- Border Slider ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Border"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                Layout.preferredWidth: 60
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

            Text {
                text: Math.round(borderSlider.value).toString()
                color: Config.accent
                font.family: Config.sysFont
                font.bold: true
                font.pixelSize: Config.size(Config.fontCaption)
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 36
            }
        }

        // --- Margin Slider ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Margin"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                Layout.preferredWidth: 60
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

            Text {
                text: Math.round(marginSlider.value).toString()
                color: Config.accent
                font.family: Config.sysFont
                font.bold: true
                font.pixelSize: Config.size(Config.fontCaption)
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 36
            }
        }

        Item { implicitHeight: 4 }

        // ==========================================
        // THEMES & COLORS SECTION
        // ==========================================
        Text {
            text: "THEMES & COLORS"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            font.bold: true
        }

        // Theme Toggles (Gradient, Blur, Xray, Iris)
        RowLayout {
            id: themeControlsRow
            Layout.fillWidth: true
            spacing: 16

            readonly property bool hasBorders: (Config.borderThickness !== undefined ? Config.borderThickness : 3) > 0

            RowLayout {
                spacing: 8
                opacity: themeControlsRow.hasBorders ? 1.0 : 0.4
                Rectangle {
                    implicitWidth: 18; implicitHeight: 18; radius: 4
                    color: (themeControlsRow.hasBorders && Config.animateGradient) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: Config.bgBase
                        visible: themeControlsRow.hasBorders && Config.animateGradient
                        font.pixelSize: 11
                        font.bold: true
                    }

                    TapHandler { onTapped: { if (themeControlsRow.hasBorders) Config.animateGradient = !Config.animateGradient } }
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

            // Inline Comment: Added Iris toggle row after Xray
            RowLayout {
                spacing: 8
                Rectangle {
                    implicitWidth: 18; implicitHeight: 18; radius: 4
                    color: Config.enableIris ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                    Text { anchors.centerIn: parent; text: "✓"; color: Config.bgBase; visible: Config.enableIris; font.pixelSize: 11; font.bold: true }
                    TapHandler { onTapped: Config.enableIris = !Config.enableIris }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                Text { text: "Auto-color (Iris)"; color: Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption) }
            }
        }

        // --- Opacity Slider ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Opacity"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                Layout.preferredWidth: 60
            }

            ThickHorizontalSlider {
                id: opacitySlider
                Layout.fillWidth: true
                from: 0.1
                to: 1.0
                value: Config.shellOpacity
                onValueChanged: Config.shellOpacity = value
            }

            Text {
                text: Math.round(opacitySlider.value * 100) + "%"
                color: Config.accent
                font.family: Config.sysFont
                font.bold: true
                font.pixelSize: Config.size(Config.fontCaption)
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 36
            }
        }

        // Palette Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            opacity: Config.enableIris ? 0.3 : 1.0

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
                text: Config.enableIris ? "Iris (Wallpaper Colors)" : (Config.useCustomColors ? "Custom (Unsaved)" : (Config.themes[Config.currentThemeIndex] ? Config.themes[Config.currentThemeIndex].name : ""))
                color: Config.accent
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.bold: true
            }

            Item { Layout.fillWidth: true }
        }

        // 10-Column Palette Grid (Disabled when Iris active)
        Item {
            Layout.fillWidth: true
            implicitHeight: paletteGrid.implicitHeight
            enabled: !Config.enableIris
            opacity: Config.enableIris ? 0.3 : (Config.useCustomColors ? 0.4 : 1.0)

            GridLayout {
                id: paletteGrid
                anchors.centerIn: parent
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

        // Custom Hex Overrides Header
        RowLayout {
            Layout.fillWidth: true
            opacity: Config.enableIris ? 0.3 : 1.0

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
                color: (!Config.enableIris && Config.useCustomColors) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                Rectangle {
                    x: (!Config.enableIris && Config.useCustomColors) ? 16 : 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14; radius: 7
                    color: (!Config.enableIris && Config.useCustomColors) ? Config.bgBase : Config.textMuted
                    Behavior on x { NumberAnimation { duration: 150 } }
                }

                TapHandler { enabled: !Config.enableIris; onTapped: Config.useCustomColors = !Config.useCustomColors }
                HoverHandler { cursorShape: Config.enableIris ? Qt.ForbiddenCursor : Qt.PointingHandCursor }
            }
        }

        // Custom Hex Inputs (Disabled when Iris active)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            enabled: Config.useCustomColors && !Config.enableIris
            opacity: (Config.useCustomColors && !Config.enableIris) ? 1.0 : 0.4

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

        // Save Palette Controls (Visible only when custom colors are active and Iris is disabled)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: Config.useCustomColors && !Config.enableIris

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