import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import ".."

ColumnLayout {
    id: root
    spacing: 16

    Text {
        text: "BAR ORIENTATION"
        color: Config.textMuted
        font.family: Config.sysFont
        font.pixelSize: Config.size(Config.fontCaption)
        font.bold: true
    }

    // Interactive Wireframe Monitor Preview
    Rectangle {
        id: monitorFrame
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 180
        implicitHeight: 108
        color: "transparent"
        border.color: Config.textMain
        border.width: 2
        radius: 12

        Rectangle { anchors.centerIn: parent; width: 24; height: 1; color: Config.textMain; opacity: 0.2 }
        Rectangle { anchors.centerIn: parent; width: 1; height: 24; color: Config.textMain; opacity: 0.2 }

        Item {
            anchors.fill: parent
            anchors.margins: 6

            Rectangle {
                id: miniActiveBar
                color: Config.accent
                radius: 4

                states: [
                    State {
                        name: "top"
                        when: Config.barPosition === "top"
                        PropertyChanges { target: miniActiveBar; x: 0; y: 0; width: parent.width; height: 8 }
                    },
                    State {
                        name: "bottom"
                        when: Config.barPosition === "bottom"
                        PropertyChanges { target: miniActiveBar; x: 0; y: parent.height - 8; width: parent.width; height: 8 }
                    },
                    State {
                        name: "left"
                        when: Config.barPosition === "left"
                        PropertyChanges { target: miniActiveBar; x: 0; y: 0; width: 8; height: parent.height }
                    },
                    State {
                        name: "right"
                        when: Config.barPosition === "right"
                        PropertyChanges { target: miniActiveBar; x: parent.width - 8; y: 0; width: 8; height: parent.height }
                    }
                ]

                transitions: [
                    Transition {
                        from: "*"; to: "*"
                        ParallelAnimation {
                            NumberAnimation { properties: "x,y,width,height"; duration: 150; easing.type: Easing.OutCubic }
                        }
                    }
                ]
            }
        }

        TapHandler {
            onTapped: (point) => {
                let localX = point.position.x
                let localY = point.position.y
                let xPct = Math.max(0.0, Math.min(1.0, localX / monitorFrame.width))
                let yPct = Math.max(0.0, Math.min(1.0, localY / monitorFrame.height))
                let dists = [yPct, 1.0 - yPct, xPct, 1.0 - xPct]
                let minIdx = dists.indexOf(Math.min(...dists))
                let edges = ["top", "bottom", "left", "right"]
                Config.barPosition = edges[minIdx]
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    Item { Layout.fillHeight: false }

    // Centered Active Bar Displays Target Section
    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        Text {
            text: "Show Bar On These Displays:"
            color: Config.textMain
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontBody)
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Repeater {
                model: Quickshell.screens

                delegate: Rectangle {
                    required property var modelData
                    implicitWidth: 90
                    implicitHeight: 32
                    radius: Config.cornerRadius / 2

                    readonly property bool isSelected: Config.enabledBarScreens.length === 0 || Config.enabledBarScreens.includes(modelData.name)
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

                    TapHandler { onTapped: Config.toggleBarScreen(modelData.name) }
                    HoverHandler { id: dispHover; cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }
}