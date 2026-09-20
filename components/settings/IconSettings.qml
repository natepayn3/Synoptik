pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."

SettingsPage {
    id: root

    title: "Icons"
    description: "Override the Material Symbols glyph used by each bar module, and reorder them."
    icon: "account_circle"

    property string selectedIconId: ""
    property string searchQuery: ""
    property var allIconsList: []
    property bool isLoadingIcons: true

    // Reordering only applies to the modules that actually live in an ordered
    // card. "batt" and "cc" are fixed anchors of the bar, and the workspace
    // tokens aren't part of either order list.
    readonly property bool canMoveSelected: {
        if (!root.selectedIconId) return false
        if (root.selectedIconId === "batt" || root.selectedIconId === "cc") return false
        return Config.leftCardOrder.includes(root.selectedIconId)
            || Config.rightCardOrder.includes(root.selectedIconId)
    }

    function moveSelected(direction) {
        const isLeft = Config.leftCardOrder.includes(root.selectedIconId)
        Config.moveModule(isLeft ? "left" : "right", root.selectedIconId, direction)
    }

    Process {
        id: iconFetcher
        running: true
        command: ["fish", "-c", "
            if test -f /usr/share/fonts/material-symbols/MaterialSymbolsOutlined.codepoints;
                cat /usr/share/fonts/material-symbols/MaterialSymbolsOutlined.codepoints | cut -d' ' -f1;
            else if test -f ~/.local/share/fonts/MaterialSymbolsOutlined.codepoints;
                cat ~/.local/share/fonts/MaterialSymbolsOutlined.codepoints | cut -d' ' -f1;
            else
                curl -sS --max-time 10 'https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.codepoints' | cut -d' ' -f1;
            end
        "]

        stdout: StdioCollector {
            onStreamFinished: {
                const txt = this.text ? this.text.trim() : ""
                if (txt.length > 0) {
                    root.allIconsList = txt.split("\n").map(l => l.trim()).filter(l => l.length > 0)
                }
                root.isLoadingIcons = false
            }
        }
    }

    SettingsCard {
        title: "Bar Modules"
        icon: "dock"
        subtitle: "Click a module to select it, then pick a replacement glyph below."

        accessory: RowLayout {
            spacing: 4

            SettingsButton {
                icon: "arrow_back"
                enabled: root.canMoveSelected
                onClicked: root.moveSelected(-1)
            }

            SettingsButton {
                icon: "arrow_forward"
                enabled: root.canMoveSelected
                onClicked: root.moveSelected(1)
            }
        }

        SettingsField {
            label: "Left / Top Icons"

            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                spacing: 4

                Repeater {
                    model: (Config.leftCardOrder || ["power", "recorder", "network", "clipboard", "wallpaper", "audio", "settings", "screenshot"])
                        .filter(id => id !== "batt")

                    delegate: Rectangle {
                        id: leftChip

                        required property var modelData

                        readonly property bool isSelected: root.selectedIconId === leftChip.modelData

                        implicitWidth: 34
                        implicitHeight: 34
                        radius: SettingsStyle.controlRadius
                        color: leftChip.isSelected
                            ? SettingsStyle.accentSoft
                            : (leftHover.hovered ? SettingsStyle.controlBgHover : SettingsStyle.controlBg)
                        border.width: 1
                        border.color: leftChip.isSelected ? SettingsStyle.accentLine : SettingsStyle.controlBorder

                        Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: Config.getIcon(leftChip.modelData)
                            color: leftChip.isSelected ? Config.accent : Config.textMain
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                        }

                        TapHandler { onTapped: root.selectedIconId = leftChip.modelData }
                        HoverHandler { id: leftHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }

        SettingsField {
            label: "Right / Bottom Icons"

            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                spacing: 4

                Repeater {
                    model: [
                        { id: "search",         label: "Search" },
                        { id: "cc",             label: "Control Center" },
                        { id: "overview",       label: "Overview" },
                        { id: "magic",          label: "Magic" },
                        { id: "magic_active",   label: "Magic (Active)" },
                        { id: "music",          label: "Music" },
                        { id: "music_active",   label: "Music (Active)" },
                        { id: "private",        label: "Private" },
                        { id: "private_active", label: "Private (Active)" }
                    ]

                    delegate: Rectangle {
                        id: rightChip

                        required property var modelData

                        readonly property bool isSelected: root.selectedIconId === rightChip.modelData.id

                        implicitWidth: 34
                        implicitHeight: 34
                        radius: SettingsStyle.controlRadius
                        color: rightChip.isSelected
                            ? SettingsStyle.accentSoft
                            : (rightHover.hovered ? SettingsStyle.controlBgHover : SettingsStyle.controlBg)
                        border.width: 1
                        border.color: rightChip.isSelected ? SettingsStyle.accentLine : SettingsStyle.controlBorder

                        Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: Config.getIcon(rightChip.modelData.id)
                            color: rightChip.isSelected ? Config.accent : Config.textMain
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                        }

                        TapHandler { onTapped: root.selectedIconId = rightChip.modelData.id }
                        HoverHandler { id: rightHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }

    SettingsCard {
        title: "Glyph Picker"
        icon: "search"
        subtitle: root.selectedIconId === ""
            ? "Select a module above to assign it a glyph."
            : "Assigning a glyph to: " + root.selectedIconId

        accessory: SettingsButton {
            label: "Reset All"
            icon: "restart_alt"
            onClicked: Config.resetIcons()
        }

        SettingsTextField {
            placeholder: "Search Material Symbols — power, terminal, home, wifi…"
            icon: "search"
            onEdited: value => root.searchQuery = value.trim().toLowerCase()
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            color: SettingsStyle.controlBg
            radius: SettingsStyle.controlRadius
            border.width: 1
            border.color: SettingsStyle.controlBorder
            clip: true

            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.selectedIconId === ""
                    ? "Click a module above to start customising."
                    : "Loading the Material Symbols list…"
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontBody)
                visible: root.selectedIconId === ""
                    || (root.isLoadingIcons && root.allIconsList.length === 0)
            }

            GridView {
                id: iconGrid

                anchors.fill: parent
                anchors.margins: 8
                clip: true

                readonly property real minCellWidth: 44
                readonly property int columns: Math.max(1, Math.floor(width / minCellWidth))

                cellWidth: width / columns
                cellHeight: 46

                visible: root.selectedIconId !== ""
                    && (!root.isLoadingIcons || root.allIconsList.length > 0)

                // Capped at 300: the full codepoints list is several thousand
                // entries, and a GridView that size makes the whole panel
                // stutter while the user is still typing a search.
                model: root.searchQuery === ""
                    ? root.allIconsList.slice(0, 300)
                    : root.allIconsList.filter(name => name.includes(root.searchQuery)).slice(0, 300)

                delegate: Item {
                    id: glyphCell

                    required property var modelData

                    width: iconGrid.cellWidth
                    height: iconGrid.cellHeight

                    readonly property bool isAssigned: root.selectedIconId !== ""
                        && Config.getIcon(root.selectedIconId) === glyphCell.modelData

                    Rectangle {
                        anchors.centerIn: parent
                        width: 38
                        height: 38
                        radius: SettingsStyle.controlRadius
                        color: glyphCell.isAssigned
                            ? SettingsStyle.accentSoft
                            : (glyphHover.hovered ? SettingsStyle.controlBgHover : "transparent")
                        border.width: glyphCell.isAssigned ? 1 : 0
                        border.color: SettingsStyle.accentLine

                        Text {
                            anchors.centerIn: parent
                            text: glyphCell.modelData
                            color: glyphCell.isAssigned ? Config.accent : Config.textMain
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 20
                        }

                        TapHandler {
                            enabled: root.selectedIconId !== ""
                            onTapped: Config.setIconOverride(root.selectedIconId, glyphCell.modelData)
                        }
                        HoverHandler { id: glyphHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }

        SettingsNote {
            text: "Browse the full glyph catalogue at fonts.google.com/icons — the name shown there is what goes in the search box."
        }
    }
}
