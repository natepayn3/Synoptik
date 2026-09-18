import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets
import ".."

// Thin view over Config.greeter (components/services/GreeterService.qml).
// The actual state and pkexec Process objects live there, not here - this
// page's own component tree gets destroyed whenever Config.closeAllPanels()
// runs (which the polkit dialog does on every auth prompt), so anything
// mid-flight here would die with it.
Flickable {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + 32
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        active: root.moving || root.flicking
    }

    ColumnLayout {
        id: contentColumn
        width: root.width
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.topMargin: 16
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "SDDM GREETER"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontSubhead)
                    font.bold: true
                }

                Text {
                    text: "Choose the theme shown on your login screen"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }
            }

            PillButton {
                label: "Refresh"
                onClicked: { Config.greeter.refreshThemes(); Config.greeter.refreshActiveTheme() }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            visible: Config.greeter.statusText !== ""
            text: Config.greeter.statusText
            color: Config.greeter.statusIsError ? "#ef4444" : Config.accent
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            font.bold: true
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            implicitHeight: Math.max(200, themeGrid.contentHeight + 12)
            color: Qt.rgba(0, 0, 0, 0.3)
            radius: Config.cornerRadius / 2
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.08)
            clip: true

            Text {
                anchors.centerIn: parent
                visible: Config.greeter.themes.length === 0
                text: "No SDDM themes found in /usr/share/sddm/themes"
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
            }

            GridView {
                id: themeGrid
                anchors.fill: parent
                anchors.margins: 6
                cellWidth: width / 2
                cellHeight: Math.floor(cellWidth * (9 / 16)) + 66

                clip: true
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                model: Config.greeter.themes

                delegate: Item {
                    id: card
                    width: themeGrid.cellWidth
                    height: themeGrid.cellHeight

                    readonly property bool isActive: modelData.id === Config.greeter.activeThemeId

                    Item {
                        anchors.fill: parent
                        anchors.margins: 4

                        ClippingRectangle {
                            id: thumb
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: card.height - 58
                            radius: Config.cornerRadius / 2
                            color: Qt.rgba(255, 255, 255, 0.05)

                            Image {
                                anchors.fill: parent
                                visible: modelData.bg !== ""
                                source: modelData.bg !== "" ? ("file://" + modelData.bg) : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 320
                                sourceSize.height: 180
                                asynchronous: true
                                cache: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: modelData.bg === ""
                                text: "wallpaper"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 28
                                color: Config.textMuted
                            }

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: Config.accent
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                visible: card.isActive

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Config.bgBase
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: thumb
                            radius: Config.cornerRadius / 2
                            color: "transparent"
                            border.width: card.isActive ? 2.5 : 0
                            border.color: Config.accent
                        }

                        ColumnLayout {
                            anchors.top: thumb.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.topMargin: 6
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                spacing: 6

                                PillButton {
                                    label: "Preview"
                                    onClicked: Config.greeter.startPreview(modelData.id)
                                }

                                PillButton {
                                    label: card.isActive ? "Active" : "Set as Greeter"
                                    highlighted: !card.isActive
                                    enabled: !card.isActive && Config.greeter.pendingActionId === ""
                                    onClicked: Config.greeter.applyTheme(modelData.id)
                                }

                                PillButton {
                                    label: "Delete"
                                    danger: true
                                    visible: !modelData.protected && !card.isActive
                                    enabled: Config.greeter.pendingActionId === ""
                                    onClicked: Config.greeter.deleteTheme(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true; implicitHeight: 20 }
    }
}
