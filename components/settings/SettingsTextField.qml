import QtQuick
import QtQuick.Layouts
import ".."

// Text input styled to match the rest of the module. Built from TextInput
// inside a Rectangle rather than a Controls TextField, matching how the
// project already writes inputs (Weather, Wallpaper, Assistant) and avoiding a
// style-specific Controls import in a file that every page includes.
//
// `text` is deliberately not two-way bound to Config by the caller: bind
// `text` in and handle `edited`/`accepted` out, or the cursor jumps to the end
// on every keystroke as the round trip through Config re-sets the property.
Rectangle {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property string icon: ""
    property bool passwordMode: false
    property bool readOnlyField: false
    property alias validator: input.validator
    // Trailing slot for a swatch, a unit label or a small action button.
    property alias trailing: trailingRow.data
    property alias horizontalAlignment: input.horizontalAlignment

    signal edited(string text)
    signal accepted(string text)
    // Fires on Enter and on focus loss - the right hook for a field whose
    // value should only be committed once the user is done typing (a model
    // name, a timeout, a ZIP code), rather than on every keystroke.
    signal editingFinished(string text)

    Layout.fillWidth: true
    implicitHeight: 38
    radius: SettingsStyle.controlRadius
    color: SettingsStyle.controlBg
    border.width: 1
    border.color: input.activeFocus ? SettingsStyle.accentLine : SettingsStyle.controlBorder

    Behavior on border.color { ColorAnimation { duration: SettingsStyle.animFast } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        Text {
            text: root.icon
            color: input.activeFocus ? Config.accent : Config.textMuted
            font.family: "Material Symbols Outlined"
            font.pixelSize: 17
            visible: root.icon !== ""
        }

        TextInput {
            id: input

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            verticalAlignment: Text.AlignVCenter
            color: Config.textMain
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontBody)
            selectByMouse: true
            readOnly: root.readOnlyField
            clip: true
            echoMode: root.passwordMode ? TextInput.Password : TextInput.Normal
            selectionColor: SettingsStyle.accentMed
            selectedTextColor: Config.textMain

            onTextEdited: root.edited(input.text)
            onAccepted: root.accepted(input.text)
            onEditingFinished: root.editingFinished(input.text)

            HoverHandler { cursorShape: Qt.IBeamCursor }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                text: root.placeholder
                color: Config.textMuted
                opacity: 0.6
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontBody)
                visible: input.text === "" && !input.activeFocus
            }
        }

        RowLayout {
            id: trailingRow
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: false
            spacing: 6
        }
    }
}
