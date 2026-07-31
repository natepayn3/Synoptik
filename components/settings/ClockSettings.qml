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

            // CHECKBOX: ENABLE WIDGET
            RowLayout {
                spacing: 8

                Rectangle {
                    implicitWidth: 18; implicitHeight: 18; radius: 4
                    color: Config.showDesktopClock ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: Config.bgBase
                        visible: Config.showDesktopClock
                        font.pixelSize: 11
                        font.bold: true
                    }

                    TapHandler { onTapped: Config.showDesktopClock = !Config.showDesktopClock }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }

                Text {
                    text: "Enable Desktop Clock Widget"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)

                    TapHandler { onTapped: Config.showDesktopClock = !Config.showDesktopClock }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
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

                    Rectangle {
                        implicitWidth: 80; implicitHeight: 28; radius: Config.cornerRadius / 2
                        color: Config.clockStyle === "digital" ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: "Digital"
                            color: Config.clockStyle === "digital" ? Config.bgBase : Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: true
                        }

                        TapHandler { onTapped: Config.clockStyle = "digital" }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }

                    Rectangle {
                        implicitWidth: 80; implicitHeight: 28; radius: Config.cornerRadius / 2
                        color: Config.clockStyle === "analog" ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: "Analog"
                            color: Config.clockStyle === "analog" ? Config.bgBase : Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: true
                        }

                        TapHandler { onTapped: Config.clockStyle = "analog" }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
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
                    spacing: 8
                    Rectangle {
                        implicitWidth: 18; implicitHeight: 18; radius: 4
                        color: Config.clockShowBorder ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                        Text {
                            anchors.centerIn: parent; text: "✓"; color: Config.bgBase
                            visible: Config.clockShowBorder; font.pixelSize: 11; font.bold: true
                        }
                        TapHandler { onTapped: Config.clockShowBorder = !Config.clockShowBorder }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                    Text {
                        text: "Show Border"
                        color: Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption)
                        TapHandler { onTapped: Config.clockShowBorder = !Config.clockShowBorder }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }

                // TOGGLE BACKGROUND
                RowLayout {
                    spacing: 8
                    Rectangle {
                        implicitWidth: 18; implicitHeight: 18; radius: 4
                        color: Config.clockShowBackground ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                        Text {
                            anchors.centerIn: parent; text: "✓"; color: Config.bgBase
                            visible: Config.clockShowBackground; font.pixelSize: 11; font.bold: true
                        }
                        TapHandler { onTapped: Config.clockShowBackground = !Config.clockShowBackground }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                    Text {
                        text: "Show Background"
                        color: Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption)
                        TapHandler { onTapped: Config.clockShowBackground = !Config.clockShowBackground }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }

                // TOGGLE SECONDS
                RowLayout {
                    spacing: 8
                    Rectangle {
                        implicitWidth: 18; implicitHeight: 18; radius: 4
                        color: Config.clockShowSeconds ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                        Text {
                            anchors.centerIn: parent; text: "✓"; color: Config.bgBase
                            visible: Config.clockShowSeconds; font.pixelSize: 11; font.bold: true
                        }
                        TapHandler { onTapped: Config.clockShowSeconds = !Config.clockShowSeconds }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                    Text {
                        text: "Show Seconds"
                        color: Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption)
                        TapHandler { onTapped: Config.clockShowSeconds = !Config.clockShowSeconds }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }

                // TOGGLE 12-HOUR FORMAT
                RowLayout {
                    spacing: 8
                    Rectangle {
                        implicitWidth: 18; implicitHeight: 18; radius: 4
                        color: Config.clockUse12Hour ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                        Text {
                            anchors.centerIn: parent; text: "✓"; color: Config.bgBase
                            visible: Config.clockUse12Hour; font.pixelSize: 11; font.bold: true
                        }
                        TapHandler { onTapped: Config.clockUse12Hour = !Config.clockUse12Hour }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                    Text {
                        text: "Use 12-Hour Format"
                        color: Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption)
                        TapHandler { onTapped: Config.clockUse12Hour = !Config.clockUse12Hour }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }

                // TOGGLE AM/PM (DIGITAL & 12-HOUR ONLY)
                RowLayout {
                    spacing: 8
                    visible: Config.clockUse12Hour && Config.clockStyle === "digital"
                    Rectangle {
                        implicitWidth: 18; implicitHeight: 18; radius: 4
                        color: Config.clockShowAmPm ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                        Text {
                            anchors.centerIn: parent; text: "✓"; color: Config.bgBase
                            visible: Config.clockShowAmPm; font.pixelSize: 11; font.bold: true
                        }
                        TapHandler { onTapped: Config.clockShowAmPm = !Config.clockShowAmPm }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                    Text {
                        text: "Show AM/PM"
                        color: Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption)
                        TapHandler { onTapped: Config.clockShowAmPm = !Config.clockShowAmPm }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}