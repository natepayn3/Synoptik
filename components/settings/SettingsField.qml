import QtQuick
import QtQuick.Layouts
import ".."

// A labelled block for controls that need the full card width beneath their
// label - chip groups, sliders, text inputs, colour pickers - rather than
// sitting to the right of it like a SettingsRow.
ColumnLayout {
    id: field

    default property alias fieldContent: fieldBody.data

    property string label: ""
    property string hint: ""

    // See SettingsRow.active - same purpose, same reason it isn't a read of
    // `enabled`.
    property bool active: true

    Layout.fillWidth: true
    spacing: SettingsStyle.tightGap
    enabled: field.active
    opacity: field.active ? 1.0 : SettingsStyle.disabledOpacity

    Behavior on opacity { NumberAnimation { duration: SettingsStyle.animFast } }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        visible: field.label !== "" || field.hint !== ""

        Text {
            Layout.fillWidth: true
            text: field.label
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            font.bold: true
            font.letterSpacing: 0.4
            wrapMode: Text.WordWrap
            visible: field.label !== ""
        }

        Text {
            Layout.fillWidth: true
            text: field.hint
            color: Config.textMuted
            opacity: 0.75
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontMicro)
            wrapMode: Text.WordWrap
            visible: field.hint !== ""
        }
    }

    ColumnLayout {
        id: fieldBody
        Layout.fillWidth: true
        spacing: SettingsStyle.tightGap
    }
}
