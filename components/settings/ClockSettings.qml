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
                text: "DESKTOP CLOCK CONFIGURATION"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontSubhead)
                font.bold: true
            }

            // TOGGLE: ENABLE WIDGET
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 0
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: "Enable Desktop Clock Widget"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Show the desktop clock overlay on your displays"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    implicitWidth: 44; implicitHeight: 24; radius: 12
                    color: (Config.showDesktopClock !== false) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: (Config.showDesktopClock !== false) ? 22 : 2
                        implicitWidth: 20; implicitHeight: 20; radius: 10
                        color: (Config.showDesktopClock !== false) ? Config.bgBase : Qt.rgba(255, 255, 255, 0.8)
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Config.showDesktopClock = (Config.showDesktopClock === false)
                            if (typeof Config.saveConfig === "function") Config.saveConfig()
                            else if (typeof Config.save === "function") Config.save()
                        }
                    }
                }
            }

            // STYLE SELECTOR
            ColumnLayout {
                spacing: 6
                visible: Config.showDesktopClock

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
                visible: Config.showDesktopClock
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
                visible: Config.showDesktopClock

                Text {
                    text: "DISPLAY OPTIONS"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                }

                // TOGGLE BORDER
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: "Show Border"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Draw a decorative border around the clock widget"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            wrapMode: Text.WordWrap
                        }
                    }

                    Rectangle {
                        implicitWidth: 44; implicitHeight: 24; radius: 12
                        color: (Config.clockShowBorder !== false) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: (Config.clockShowBorder !== false) ? 22 : 2
                            implicitWidth: 20; implicitHeight: 20; radius: 10
                            color: (Config.clockShowBorder !== false) ? Config.bgBase : Qt.rgba(255, 255, 255, 0.8)
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.clockShowBorder = (Config.clockShowBorder === false)
                                if (typeof Config.saveConfig === "function") Config.saveConfig()
                                else if (typeof Config.save === "function") Config.save()
                            }
                        }
                    }
                }

                // TOGGLE BACKGROUND
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: "Show Background"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Display a background panel behind the clock"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            wrapMode: Text.WordWrap
                        }
                    }

                    Rectangle {
                        implicitWidth: 44; implicitHeight: 24; radius: 12
                        color: (Config.clockShowBackground !== false) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: (Config.clockShowBackground !== false) ? 22 : 2
                            implicitWidth: 20; implicitHeight: 20; radius: 10
                            color: (Config.clockShowBackground !== false) ? Config.bgBase : Qt.rgba(255, 255, 255, 0.8)
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.clockShowBackground = (Config.clockShowBackground === false)
                                if (typeof Config.saveConfig === "function") Config.saveConfig()
                                else if (typeof Config.save === "function") Config.save()
                            }
                        }
                    }
                }

                // TOGGLE GLOW EFFECT
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: "Glow Effect"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Apply a soft glow effect to the clock display"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            wrapMode: Text.WordWrap
                        }
                    }

                    Rectangle {
                        implicitWidth: 44; implicitHeight: 24; radius: 12
                        color: (Config.clockShowGlow !== false) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: (Config.clockShowGlow !== false) ? 22 : 2
                            implicitWidth: 20; implicitHeight: 20; radius: 10
                            color: (Config.clockShowGlow !== false) ? Config.bgBase : Qt.rgba(255, 255, 255, 0.8)
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.clockShowGlow = (Config.clockShowGlow === false)
                                if (typeof Config.saveConfig === "function") Config.saveConfig()
                                else if (typeof Config.save === "function") Config.save()
                            }
                        }
                    }
                }

                // TOGGLE SECONDS
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: "Show Seconds"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Include seconds in the clock time display"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            wrapMode: Text.WordWrap
                        }
                    }

                    Rectangle {
                        implicitWidth: 44; implicitHeight: 24; radius: 12
                        color: (Config.clockShowSeconds !== false) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: (Config.clockShowSeconds !== false) ? 22 : 2
                            implicitWidth: 20; implicitHeight: 20; radius: 10
                            color: (Config.clockShowSeconds !== false) ? Config.bgBase : Qt.rgba(255, 255, 255, 0.8)
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.clockShowSeconds = (Config.clockShowSeconds === false)
                                if (typeof Config.saveConfig === "function") Config.saveConfig()
                                else if (typeof Config.save === "function") Config.save()
                            }
                        }
                    }
                }

                // TOGGLE 12-HOUR FORMAT
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: "Use 12-Hour Format"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Display time in 12-hour instead of 24-hour format"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            wrapMode: Text.WordWrap
                        }
                    }

                    Rectangle {
                        implicitWidth: 44; implicitHeight: 24; radius: 12
                        color: (Config.clockUse12Hour !== false) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: (Config.clockUse12Hour !== false) ? 22 : 2
                            implicitWidth: 20; implicitHeight: 20; radius: 10
                            color: (Config.clockUse12Hour !== false) ? Config.bgBase : Qt.rgba(255, 255, 255, 0.8)
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.clockUse12Hour = (Config.clockUse12Hour === false)
                                if (typeof Config.saveConfig === "function") Config.saveConfig()
                                else if (typeof Config.save === "function") Config.save()
                            }
                        }
                    }
                }

                // TOGGLE AM/PM (DIGITAL & 12-HOUR ONLY)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    visible: Config.clockUse12Hour && Config.clockStyle === "digital"

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: "Show AM/PM"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Show the AM/PM indicator next to the time (digital 12-hour mode only)"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            wrapMode: Text.WordWrap
                        }
                    }

                    Rectangle {
                        implicitWidth: 44; implicitHeight: 24; radius: 12
                        color: (Config.clockShowAmPm !== false) ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: (Config.clockShowAmPm !== false) ? 22 : 2
                            implicitWidth: 20; implicitHeight: 20; radius: 10
                            color: (Config.clockShowAmPm !== false) ? Config.bgBase : Qt.rgba(255, 255, 255, 0.8)
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.clockShowAmPm = (Config.clockShowAmPm === false)
                                if (typeof Config.saveConfig === "function") Config.saveConfig()
                                else if (typeof Config.save === "function") Config.save()
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}