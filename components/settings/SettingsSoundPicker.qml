pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."

// Radio grid over the bundled sound assets. Both cards on the Sounds page use
// it, with the same nine files and the same "picking previews it" behaviour.
GridLayout {
    id: picker

    property var files: [
        "sound1.wav", "sound2.wav", "sound3.wav",
        "sound4.wav", "sound5.wav", "sound6.wav",
        "sound7.wav", "sound8.wav", "sound9.wav"
    ]
    property string current: ""

    signal picked(string fileName)

    function label(fileName) {
        const clean = fileName.replace(".wav", "")
        return clean.charAt(0).toUpperCase() + clean.slice(1).replace(/(\d+)/, " $1")
    }

    Layout.fillWidth: true
    columns: 3
    columnSpacing: SettingsStyle.tightGap
    rowSpacing: SettingsStyle.tightGap

    Repeater {
        model: picker.files

        delegate: Rectangle {
            id: soundChip

            required property string modelData

            readonly property bool isSelected: picker.current === soundChip.modelData

            Layout.fillWidth: true
            implicitHeight: 34
            radius: SettingsStyle.controlRadius
            color: soundChip.isSelected
                ? SettingsStyle.accentSoft
                : (soundHover.hovered ? SettingsStyle.controlBgHover : SettingsStyle.controlBg)
            border.width: 1
            border.color: soundChip.isSelected ? SettingsStyle.accentLine : SettingsStyle.controlBorder

            Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6

                Text {
                    text: soundChip.isSelected ? "radio_button_checked" : "radio_button_unchecked"
                    color: soundChip.isSelected ? Config.accent : Config.textMuted
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 15
                }

                Text {
                    Layout.fillWidth: true
                    text: picker.label(soundChip.modelData)
                    color: soundChip.isSelected ? Config.accent : Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.bold: soundChip.isSelected
                    elide: Text.ElideRight
                }
            }

            TapHandler { onTapped: picker.picked(soundChip.modelData) }
            HoverHandler { id: soundHover; cursorShape: Qt.PointingHandCursor }
        }
    }
}
