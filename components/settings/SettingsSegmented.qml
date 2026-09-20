pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."

// Chip group for picking one of a small set of values - clock style, bar edge,
// shader palette, notification position. Replaces the hand-rolled
// `Repeater { delegate: Rectangle { ... } }` chip blocks that appeared in most
// pages with subtly different sizes, radii and selected-state colours.
//
// Wraps via Flow rather than RowLayout: several of these have eight or more
// options (shader palettes, Hyprland layouts) and were overflowing the card on
// narrow windows. Layout.preferredHeight is bound explicitly because a Flow's
// implicitHeight only resolves once it has been given a width, and a
// ColumnLayout asks for the height first.
//
// model entries: { label, value, icon? }  -  icon is a Material Symbols name.
Flow {
    id: seg

    property var model: []
    property var currentValue: undefined
    property real itemWidth: 0   // 0 = size each chip to its own label

    signal selected(var value)

    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    spacing: SettingsStyle.tightGap

    Repeater {
        model: seg.model

        delegate: Rectangle {
            id: chip

            required property var modelData

            readonly property bool isSelected: seg.currentValue !== undefined
                && modelData.value === seg.currentValue

            implicitWidth: seg.itemWidth > 0 ? seg.itemWidth : chipRow.implicitWidth + 26
            implicitHeight: 34
            radius: SettingsStyle.controlRadius

            color: chip.isSelected
                ? SettingsStyle.accentSoft
                : (chipHover.hovered ? SettingsStyle.controlBgHover : SettingsStyle.controlBg)
            border.width: 1
            border.color: chip.isSelected ? SettingsStyle.accentLine : SettingsStyle.controlBorder

            Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }
            Behavior on border.color { ColorAnimation { duration: SettingsStyle.animFast } }

            RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: chip.modelData.icon !== undefined ? chip.modelData.icon : ""
                    color: chip.isSelected ? Config.accent : Config.textMuted
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 15
                    visible: text !== ""
                }

                Text {
                    text: chip.modelData.label
                    color: chip.isSelected ? Config.accent : Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.bold: chip.isSelected
                    elide: Text.ElideRight
                }
            }

            TapHandler { onTapped: seg.selected(chip.modelData.value) }
            HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
        }
    }
}
