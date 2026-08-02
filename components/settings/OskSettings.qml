import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    anchors.fill: parent
    spacing: 16

    Text {
        text: "ON-SCREEN KEYBOARD"
        color: Config.textMain
        font.family: Config.sysFont
        font.pixelSize: Config.size(Config.fontSubhead)
        font.bold: true
    }

    // CHECKBOX ROW
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 32
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            spacing: 8

            Rectangle {
                implicitWidth: 18
                implicitHeight: 18
                radius: 4
                color: Config.showOsk ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    color: Config.bgBase
                    visible: Config.showOsk
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            Text {
                text: "Enable Keyboard Overlay"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                Layout.fillWidth: true
            }
        }

        TapHandler {
            onTapped: Config.showOsk = !Config.showOsk
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    // LAYOUT SELECTION BUTTONS
    Text {
        text: "KEYBOARD LAYOUT"
        color: Config.textMuted
        font.family: Config.sysFont
        font.pixelSize: Config.size(Config.fontCaption)
        font.bold: true
        Layout.topMargin: 6
    }

    RowLayout {
        spacing: 8

        Repeater {
            model: [
                { name: "Normal",  icon: "keyboard" },
                { name: "Minimal", icon: "keyboard_keys" },
                { name: "Gamer",   icon: "sports_esports" }
            ]

            delegate: Rectangle {
                id: layoutBtn
                implicitWidth: 130
                implicitHeight: 36
                radius: Config.cornerRadius / 2

                readonly property bool isCurrent: Config.oskLayout === modelData.name
                color: layoutBtn.isCurrent ? Qt.rgba(255, 255, 255, 0.12) : (btnHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                border.width: layoutBtn.isCurrent ? 1 : 0
                border.color: Config.accent

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: modelData.icon
                        color: layoutBtn.isCurrent ? Config.accent : Config.textMuted
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                    }

                    Text {
                        text: modelData.name
                        color: layoutBtn.isCurrent ? Config.accent : Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: layoutBtn.isCurrent
                        elide: Text.ElideRight
                    }
                }

                TapHandler {
                    onTapped: Config.oskLayout = modelData.name
                }
                HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
            }
        }
    }

    Item { Layout.fillHeight: true }
}