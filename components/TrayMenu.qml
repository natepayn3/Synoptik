import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

// A tray item's own menu, rendered as one of the bar's popouts rather than as
// a native Qt menu. StatusNotifierItem menus arrive over D-Bus as data
// (QsMenuOpener hands back entries, not widgets), which is what makes it
// possible to draw them in the shell's own language - the alternative,
// item.display(), pops a stock platform menu that would be the single
// un-themed surface on the screen.
Item {
    id: trayMenuRoot

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    // The SystemTrayItem whose menu is open. Set by whichever surface opened it
    // (bar group or task popout) before flipping Config.showTrayMenu.
    readonly property var trayItem: Config.trayMenuItem

    readonly property string itemLabel: Config.tray.labelFor(trayItem)
    readonly property string itemSubLabel: Config.tray.subLabelFor(trayItem)
    readonly property bool hasMenu: trayItem ? trayItem.hasMenu === true : false
    readonly property bool isPinned: Config.tray.isPinned(trayItem)

    readonly property real menuWidth: 240
    readonly property real maxListHeight: 420

    implicitWidth: mainLayout.implicitWidth + (cardMargin * 2)
    implicitHeight: mainLayout.implicitHeight + (cardMargin * 2)

    function close() {
        Config.showTrayMenu = false
    }

    // The opener is what actually asks the application to populate its menu, so
    // it is deliberately gated on visibility: an always-open opener would keep
    // every tray app's menu subscribed for the entire uptime of the shell.
    QsMenuOpener {
        id: rootOpener
        menu: (trayMenuRoot.visible && trayMenuRoot.trayItem) ? trayMenuRoot.trayItem.menu : null
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: trayMenuRoot.cardMargin
        spacing: trayMenuRoot.cardMargin

        ClippingRectangle {
            Layout.fillWidth: true
            implicitWidth: trayMenuRoot.menuWidth + (trayMenuRoot.cardMargin * 2)
            implicitHeight: cardContentLayout.implicitHeight + (trayMenuRoot.cardMargin * 2)
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.05)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)

            Watermark {
                icon: Config.getIcon("apps")
                iconSize: 120
                seed: 21
            }

            ColumnLayout {
                id: cardContentLayout
                anchors.fill: parent
                anchors.margins: trayMenuRoot.cardMargin
                spacing: 8

                // --- HEADER ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    IconImage {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        asynchronous: true
                        source: Config.tray.iconFor(trayMenuRoot.trayItem)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: headerText.implicitHeight

                            Glow {
                                anchors.fill: headerText
                                source: headerText
                                radius: 8
                                samples: 16
                                color: Config.accent
                                spread: 0.2
                                transparentBorder: true
                                visible: Config.clockShowGlow
                            }

                            Text {
                                id: headerText
                                anchors.fill: parent
                                text: trayMenuRoot.itemLabel.toUpperCase()
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontTitle)
                                font.bold: true
                                font.italic: true
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            visible: trayMenuRoot.itemSubLabel !== ""
                            text: trayMenuRoot.itemSubLabel
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Pin toggle. The menu is where you already are when you
                    // decide an icon does or doesn't deserve a permanent spot
                    // on the bar, so the control lives here rather than behind
                    // a separate settings trip.
                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: Config.cornerRadius / 2
                        color: pinHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: trayMenuRoot.isPinned ? "keep" : "keep_off"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 14
                            color: trayMenuRoot.isPinned ? Config.accent : Config.textMuted
                        }

                        TapHandler { onTapped: Config.tray.togglePin(trayMenuRoot.trayItem) }
                        HoverHandler { id: pinHover; cursorShape: Qt.PointingHandCursor }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Qt.rgba(255, 255, 255, 0.1)
                }

                // --- MENU BODY ---
                Text {
                    visible: !trayMenuRoot.hasMenu
                    text: "This app provides no tray menu."
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }

                ScrollView {
                    visible: trayMenuRoot.hasMenu
                    Layout.fillWidth: true
                    implicitHeight: Math.min(trayMenuRoot.maxListHeight, entryColumn.implicitHeight)
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                        id: entryColumn
                        width: trayMenuRoot.menuWidth
                        spacing: 2

                        Repeater {
                            model: rootOpener.children

                            delegate: TrayMenuEntry {
                                required property var modelData
                                entry: modelData
                                depth: 0
                                rowWidth: trayMenuRoot.menuWidth
                                Layout.fillWidth: true
                                onActivated: trayMenuRoot.close()
                            }
                        }
                    }
                }

                // --- FOOTER ACTIONS ---
                // secondaryActivate is middle-click in every other tray
                // implementation, which is undiscoverable and impossible on a
                // trackpad, so it also gets a real button here. Only shown when
                // the item actually claims a primary action to pair it with.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 6
                    visible: trayMenuRoot.trayItem && !trayMenuRoot.trayItem.onlyMenu

                    Repeater {
                        model: [
                            { label: "Open", glyph: "open_in_new", secondary: false },
                            { label: "Alt", glyph: "ads_click", secondary: true }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 26
                            radius: Config.cornerRadius / 2
                            color: actionHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.06)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: modelData.glyph
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 13
                                    color: actionHover.hovered ? Config.accent : Config.textMuted
                                }

                                Text {
                                    text: modelData.label
                                    color: actionHover.hovered ? Config.accent : Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: true
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    if (!trayMenuRoot.trayItem) return
                                    if (modelData.secondary) trayMenuRoot.trayItem.secondaryActivate()
                                    else trayMenuRoot.trayItem.activate()
                                    trayMenuRoot.close()
                                }
                            }
                            HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }
        }
    }
}
