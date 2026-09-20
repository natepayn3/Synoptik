pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

// Multi-select monitor chips - "show this widget on these displays".
// Clock, App Dock, Cava, SysInfo and Bar each had their own copy of this
// Repeater, with chip sizes of 90/100/110px, two different tick glyphs and
// two different ways of spelling the "empty list means every screen" rule.
//
// The empty-list convention is Config's, not this component's: an empty
// enabledScreens means the widget is shown everywhere, which is why a fresh
// install lights every chip rather than none.
Flow {
    id: picker

    property var enabledScreens: []
    signal toggle(string screenName)

    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    spacing: SettingsStyle.tightGap

    Repeater {
        model: Quickshell.screens

        delegate: Rectangle {
            id: chip

            required property var modelData

            readonly property bool isSelected: picker.enabledScreens.length === 0
                || picker.enabledScreens.includes(modelData.name)

            implicitWidth: chipRow.implicitWidth + 22
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
                    text: chip.isSelected ? "check_circle" : "add_circle"
                    color: chip.isSelected ? Config.accent : Config.textMuted
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 15
                }

                Text {
                    text: chip.modelData.name
                    color: chip.isSelected ? Config.accent : Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.bold: chip.isSelected
                }
            }

            TapHandler { onTapped: picker.toggle(chip.modelData.name) }
            HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
        }
    }
}
