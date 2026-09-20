pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."

// Thin view over Config.greeter (components/services/GreeterService.qml).
// The actual state and pkexec Process objects live there, not here - this
// page's own component tree gets destroyed whenever Config.closeAllPanels()
// runs (which the polkit dialog does on every auth prompt), so anything
// mid-flight here would die with it.
SettingsPage {
    id: root

    title: "Greeter"
    description: "Theme shown on the SDDM login screen."
    icon: "login"

    headerAccessory: SettingsButton {
        label: "Refresh"
        icon: "refresh"
        onClicked: {
            Config.greeter.refreshThemes()
            Config.greeter.refreshActiveTheme()
        }
    }

    SettingsNote {
        text: Config.greeter.statusText
        variant: Config.greeter.statusIsError ? "danger" : "info"
        visible: Config.greeter.statusText !== ""
    }

    SettingsCard {
        title: "Installed Themes"
        icon: "wallpaper"
        subtitle: "Themes found in /usr/share/sddm/themes"

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(180, themeGrid.contentHeight + 12)
            color: SettingsStyle.controlBg
            radius: SettingsStyle.controlRadius
            border.width: 1
            border.color: SettingsStyle.controlBorder
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
                // The card list scrolls with the page, not on its own - a
                // nested scroll area inside a Flickable steals wheel events
                // and strands the rest of the page.
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                model: Config.greeter.themes

                delegate: Item {
                    id: card

                    required property var modelData

                    width: themeGrid.cellWidth
                    height: themeGrid.cellHeight

                    readonly property bool isActive: card.modelData.id === Config.greeter.activeThemeId

                    Item {
                        anchors.fill: parent
                        anchors.margins: 4

                        ClippingRectangle {
                            id: thumb

                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: card.height - 58
                            radius: SettingsStyle.controlRadius
                            color: SettingsStyle.controlBg

                            Image {
                                anchors.fill: parent
                                visible: card.modelData.bg !== ""
                                source: card.modelData.bg !== "" ? ("file://" + card.modelData.bg) : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 320
                                sourceSize.height: 180
                                asynchronous: true
                                cache: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: card.modelData.bg === ""
                                text: "wallpaper"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 28
                                color: Config.textMuted
                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                width: 22
                                height: 22
                                radius: 11
                                color: Config.accent
                                visible: card.isActive

                                Text {
                                    anchors.centerIn: parent
                                    text: "check"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 14
                                    color: Config.bgBase
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: thumb
                            radius: SettingsStyle.controlRadius
                            color: "transparent"
                            border.width: card.isActive ? 2 : 0
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
                                text: card.modelData.name
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
                                    onClicked: Config.greeter.startPreview(card.modelData.id)
                                }

                                PillButton {
                                    label: card.isActive ? "Active" : "Set as Greeter"
                                    highlighted: !card.isActive
                                    enabled: !card.isActive && Config.greeter.pendingActionId === ""
                                    onClicked: Config.greeter.applyTheme(card.modelData.id)
                                }

                                PillButton {
                                    label: "Delete"
                                    danger: true
                                    visible: !card.modelData.protected && !card.isActive
                                    enabled: Config.greeter.pendingActionId === ""
                                    onClicked: Config.greeter.deleteTheme(card.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
