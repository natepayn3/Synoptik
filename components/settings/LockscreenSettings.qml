import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import "../widgets"
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

    ColumnLayout {
        id: contentColumn
        width: parent.width
        spacing: flickable.cardMargin

        Text {
            text: "LOCKSCREEN CONFIGURATION"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontSubhead)
                font.bold: true
            }

            Text {
                text: "Configure the Wayland session lockscreen, randomized shape password bar, clock typography, and privacy settings."
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            // ==========================================
            // 1. INTERACTIVE LIVE PREVIEW CARD
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: previewCol.implicitHeight + 28
                radius: Config.cornerRadius
                color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.1)

                ColumnLayout {
                    id: previewCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "LIVE PASSWORD BAR PREVIEW"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        // RELIABLE TEST LOCK BUTTON
                        Rectangle {
                            id: testLockBtn
                            implicitWidth: testLockRow.implicitWidth + 16
                            implicitHeight: 30
                            radius: 15
                            color: testLockMouse.containsMouse ? Config.accent : Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.18)
                            border.width: 1.5
                            border.color: Config.accent

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                id: testLockRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "lock"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 15
                                    color: testLockMouse.containsMouse ? Config.bgBase : Config.accent
                                }

                                Text {
                                    text: "Test Lock Now"
                                    font.family: Config.sysFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: testLockMouse.containsMouse ? Config.bgBase : Config.accent
                                }
                            }

                            MouseArea {
                                id: testLockMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Config.sessionLocked = true
                                }
                            }
                        }
                    }

                    Text {
                        text: "Type below to test live glyphs, animations, and clearing mechanics:"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                    }

                    // Interactive Preview Bar
                    LockscreenPasswordBar {
                        id: previewPassBar
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        maskStyle: Config.lockscreenMaskStyle || "shapes"
                        paletteMode: Config.lockscreenShapePalette || "vibrant"
                        placeholderText: "Type to test password bar..."

                        onSubmitPassword: (pass) => {
                            previewPassBar.isAuthenticating = true
                            previewSimTimer.restart()
                        }
                    }

                    Timer {
                        id: previewSimTimer
                        interval: 500
                        onTriggered: {
                            previewPassBar.isAuthenticating = false
                            previewPassBar.isSuccess = true
                            previewResetTimer.restart()
                        }
                    }

                    Timer {
                        id: previewResetTimer
                        interval: 700
                        onTriggered: {
                            previewPassBar.isSuccess = false
                            previewPassBar.clearInput()
                        }
                    }
                }
            }

            // ==========================================
            // 2. PASSWORD MASK STYLE SELECTOR
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: maskStyleCol.implicitHeight + 28
                radius: Config.cornerRadius
                color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.1)

                ColumnLayout {
                    id: maskStyleCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "PASSWORD MASK STYLE"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { id: "shapes",    label: "Shapes",        icon: "category",            desc: "16 vector shapes", preview: "◆ ▲ ■" },
                                { id: "dots",      label: "Dots",          icon: "fiber_manual_record", desc: "Bullet discs",     preview: "● ● ●" },
                                { id: "asterisks", label: "Asterisks",     icon: "emergency",           desc: "Classic asterisks", preview: "✱ ✱ ✱" },
                                { id: "special",   label: "Special Chars", icon: "code",                desc: "Random symbols",   preview: "! @ # ★" }
                            ]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: 68
                                radius: Config.cornerRadius / 2

                                readonly property bool isSelected: (Config.lockscreenMaskStyle || "shapes") === modelData.id

                                color: isSelected 
                                    ? Qt.rgba(255, 255, 255, 0.14) 
                                    : (maskHover.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2))
                                border.width: isSelected ? 1.5 : 1
                                border.color: isSelected ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                                Behavior on color { ColorAnimation { duration: 150 } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 6

                                        Text {
                                            text: modelData.icon
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 16
                                            color: isSelected ? Config.accent : Config.textMuted
                                        }

                                        Text {
                                            text: modelData.label
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontCaption)
                                            font.bold: true
                                            color: isSelected ? Config.accent : Config.textMain
                                        }
                                    }

                                    Text {
                                        text: modelData.preview
                                        font.family: Config.sysFont
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: isSelected ? Config.accent : Qt.rgba(255, 255, 255, 0.5)
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    id: maskHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Config.lockscreenMaskStyle = modelData.id
                                        previewPassBar.maskStyle = modelData.id
                                        previewPassBar.shuffleShapes()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 3. PALETTE & COLOR THEME
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: paletteCol.implicitHeight + 28
                radius: Config.cornerRadius
                color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.1)

                ColumnLayout {
                    id: paletteCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "RANDOMIZED SHAPE PALETTE"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { id: "vibrant", label: "Vibrant", desc: "Multicolor cyber tones", previewColor: "#00f0ff" },
                                { id: "accent", label: "Accent Flow", desc: "Active theme colors", previewColor: Config.accent },
                                { id: "neon", label: "Neon High", desc: "High-contrast neon", previewColor: "#ff0055" },
                                { id: "pastel", label: "Pastel Dream", desc: "Soft pastel hues", previewColor: "#c4b5fd" },
                                { id: "monochrome", label: "Monochrome", desc: "Platinum & silver", previewColor: "#ffffff" }
                            ]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: 64
                                radius: Config.cornerRadius / 2

                                readonly property bool isSelected: (Config.lockscreenShapePalette || "vibrant") === modelData.id

                                color: isSelected 
                                    ? Qt.rgba(255, 255, 255, 0.14) 
                                    : (palHover.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2))
                                border.width: isSelected ? 1.5 : 1
                                border.color: isSelected ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                                Behavior on color { ColorAnimation { duration: 150 } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 6

                                        Rectangle {
                                            implicitWidth: 12; implicitHeight: 12; radius: 6
                                            color: modelData.previewColor
                                        }

                                        Text {
                                            text: modelData.label
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontCaption)
                                            font.bold: true
                                            color: isSelected ? Config.accent : Config.textMain
                                        }
                                    }

                                    Text {
                                        text: modelData.desc
                                        font.family: Config.sysFont
                                        font.pixelSize: 10
                                        color: Config.textMuted
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    id: palHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Config.lockscreenShapePalette = modelData.id
                                        previewPassBar.shuffleShapes()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 4. TIME & DATE FORMAT CONFIGURATION
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: timeFormatCol.implicitHeight + 28
                radius: Config.cornerRadius
                color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.1)

                ColumnLayout {
                    id: timeFormatCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    Text {
                        text: "TIME & DATE FORMAT"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    // TIME FORMAT (12-HOUR VS 24-HOUR) & CLOCK SIZE
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        // 12-Hour vs 24-Hour Compact Pills
                        RowLayout {
                            spacing: 8

                            Text {
                                text: "Time Mode:"
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: true
                            }

                            Repeater {
                                model: [
                                    { label: "12-Hour", use12: true, icon: "schedule" },
                                    { label: "24-Hour", use12: false, icon: "military_tech" }
                                ]

                                delegate: Rectangle {
                                    implicitWidth: 100
                                    implicitHeight: 30
                                    radius: 15

                                    readonly property bool isSelected: (Config.lockscreenUse12Hour !== false) === modelData.use12

                                    color: isSelected 
                                        ? Config.accent 
                                        : (hourModeHover.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(0, 0, 0, 0.2))

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: modelData.icon
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 15
                                            color: isSelected ? Config.bgBase : Config.accent
                                        }

                                        Text {
                                            text: modelData.label
                                            font.family: Config.sysFont
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: isSelected ? Config.bgBase : Config.textMain
                                        }
                                    }

                                    MouseArea {
                                        id: hourModeHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Config.lockscreenUse12Hour = modelData.use12
                                        }
                                    }
                                }
                            }
                        }

                        // CLOCK TYPOGRAPHY SIZE
                        RowLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignRight

                            Text {
                                text: "Clock Size:"
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: true
                            }

                            Repeater {
                                model: [
                                    { label: "72px", size: 72 },
                                    { label: "96px", size: 96 },
                                    { label: "120px", size: 120 }
                                ]

                                delegate: Rectangle {
                                    implicitWidth: 64
                                    implicitHeight: 30
                                    radius: 15
                                    readonly property bool isSelected: (Config.lockscreenClockSize || 96) === modelData.size
                                    color: isSelected ? Config.accent : (sizeHover.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(0, 0, 0, 0.2))

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: Config.sysFont
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: isSelected ? Config.bgBase : Config.textMain
                                    }

                                    MouseArea {
                                        id: sizeHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Config.lockscreenClockSize = modelData.size
                                    }
                                }
                            }
                        }
                    }

                    // TIME DISPLAY CHECKBOXES (SECONDS & AM/PM)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24

                        // SHOW SECONDS
                        RowLayout {
                            spacing: 8

                            Rectangle {
                                implicitWidth: 18; implicitHeight: 18; radius: 4
                                color: (Config.lockscreenShowSeconds === true) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: Config.bgBase
                                    visible: Config.lockscreenShowSeconds === true
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.lockscreenShowSeconds = !Config.lockscreenShowSeconds
                                }
                            }

                            Text {
                                text: "Show Seconds (10:42:30)"
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.lockscreenShowSeconds = !Config.lockscreenShowSeconds
                                }
                            }
                        }

                        // SHOW AM/PM BADGE
                        RowLayout {
                            spacing: 8
                            visible: Config.lockscreenUse12Hour !== false

                            Rectangle {
                                implicitWidth: 18; implicitHeight: 18; radius: 4
                                color: (Config.lockscreenShowAmPm !== false) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: Config.bgBase
                                    visible: Config.lockscreenShowAmPm !== false
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.lockscreenShowAmPm = (Config.lockscreenShowAmPm === false)
                                }
                            }

                            Text {
                                text: "Show AM/PM Badge"
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.lockscreenShowAmPm = (Config.lockscreenShowAmPm === false)
                                }
                            }
                        }
                    }

                    // DATE FORMAT SELECTOR
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "Date Display Style:"
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            // Live Date Preview String
                            RowLayout {
                                spacing: 6

                                Text {
                                    text: "Preview:"
                                    color: Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: 11
                                }

                                Text {
                                    text: {
                                        let d = new Date()
                                        let mode = Config.lockscreenDateFormat || "long"
                                        if (mode === "standard") return Qt.formatDate(d, "ddd, MMM d, yyyy")
                                        if (mode === "iso") return Qt.formatDate(d, "yyyy-MM-dd")
                                        if (mode === "dayFirst") return Qt.formatDate(d, "d MMMM yyyy")
                                        return Qt.formatDate(d, "dddd, MMMM d, yyyy")
                                    }
                                    color: Config.accent
                                    font.family: Config.sysFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                        }

                        // Compact Segmented Pills
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: [
                                    { id: "long", label: "Long" },
                                    { id: "standard", label: "Standard" },
                                    { id: "dayFirst", label: "Day First" },
                                    { id: "iso", label: "ISO 8601" }
                                ]

                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    implicitHeight: 32
                                    radius: 16

                                    readonly property bool isSelected: (Config.lockscreenDateFormat || "long") === modelData.id
                                    color: isSelected ? Config.accent : (dateHover.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(0, 0, 0, 0.2))

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: Config.sysFont
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: isSelected ? Config.bgBase : Config.textMain
                                    }

                                    MouseArea {
                                        id: dateHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Config.lockscreenDateFormat = modelData.id
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 5. LOCKSCREEN VISUALS & TOGGLES
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: togglesCol.implicitHeight + 28
                radius: Config.cornerRadius
                color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.1)

                ColumnLayout {
                    id: togglesCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "LOCKSCREEN DISPLAY OPTIONS"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    // TOGGLE 1: MEDIA CONTROLLER
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            implicitWidth: 20; implicitHeight: 20; radius: 4
                            color: (Config.lockscreenShowMedia !== false) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: Config.bgBase
                                visible: Config.lockscreenShowMedia !== false
                                font.pixelSize: 12
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.lockscreenShowMedia = (Config.lockscreenShowMedia === false)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Show Media Player Mini Controller"
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontBody)
                                font.bold: true
                            }

                            Text {
                                text: "Display currently playing track metadata and playback controls on the lock screen."
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                            }
                        }
                    }

                    // TOGGLE 2: POWER CONTROLS
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            implicitWidth: 20; implicitHeight: 20; radius: 4
                            color: (Config.lockscreenShowPower !== false) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: Config.bgBase
                                visible: Config.lockscreenShowPower !== false
                                font.pixelSize: 12
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.lockscreenShowPower = (Config.lockscreenShowPower === false)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Show Power Actions on Lockscreen"
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontBody)
                                font.bold: true
                            }

                            Text {
                                text: "Allow suspending, rebooting, and powering off the system directly from the lock surface."
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                            }
                        }
                    }

                    // BLUR RADIUS PRESETS
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "Wallpaper Blur Effect:"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: true
                        }

                        Repeater {
                            model: [
                                { label: "Light (18px)", value: 18 },
                                { label: "Standard (36px)", value: 36 },
                                { label: "Heavy (60px)", value: 60 }
                            ]

                            delegate: Rectangle {
                                implicitWidth: 120
                                implicitHeight: 30
                                radius: 15
                                readonly property bool isSelected: (Config.lockscreenBlurRadius || 36) === modelData.value
                                color: isSelected ? Config.accent : (blurHover.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(0, 0, 0, 0.2))

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.family: Config.sysFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: isSelected ? Config.bgBase : Config.textMain
                                }

                                MouseArea {
                                    id: blurHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.lockscreenBlurRadius = modelData.value
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true; implicitHeight: 20 }
        }
    }
