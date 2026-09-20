pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."

// Grid of picture-ish choice tiles: icon, label, a line of description and an
// optional ASCII preview of what the option looks like. For pickers where the
// options need explaining - workspace indicator styles, container frames, bar
// frame styles - as opposed to SettingsSegmented's one-word chips.
//
// model entries: { label, value, icon, desc?, preview? }
GridLayout {
    id: grid

    property var model: []
    property var currentValue: undefined
    property real tileHeight: 82

    signal selected(var value)

    Layout.fillWidth: true
    columns: 3
    rowSpacing: 10
    columnSpacing: 10

    Repeater {
        model: grid.model

        delegate: Rectangle {
            id: tile

            required property var modelData

            readonly property bool isSelected: grid.currentValue !== undefined
                && modelData.value === grid.currentValue

            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            implicitHeight: grid.tileHeight
            radius: SettingsStyle.controlRadius

            color: tile.isSelected
                ? SettingsStyle.accentSoft
                : (tileHover.hovered ? SettingsStyle.controlBgHover : SettingsStyle.controlBg)
            border.width: 1
            border.color: tile.isSelected ? SettingsStyle.accentLine : SettingsStyle.controlBorder

            Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }
            Behavior on border.color { ColorAnimation { duration: SettingsStyle.animFast } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    Text {
                        text: tile.modelData.icon !== undefined ? tile.modelData.icon : ""
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 18
                        color: tile.isSelected ? Config.accent : Config.textMuted
                        visible: text !== ""
                    }

                    Text {
                        Layout.fillWidth: true
                        text: tile.modelData.label
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                        color: tile.isSelected ? Config.accent : Config.textMain
                        elide: Text.ElideRight
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: tile.modelData.desc !== undefined ? tile.modelData.desc : ""
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    color: Config.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                Text {
                    Layout.fillWidth: true
                    text: tile.modelData.preview !== undefined ? tile.modelData.preview : ""
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.bold: true
                    color: tile.isSelected ? Config.accent : Qt.rgba(1, 1, 1, 0.4)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }

            TapHandler { onTapped: grid.selected(tile.modelData.value) }
            HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
        }
    }
}
