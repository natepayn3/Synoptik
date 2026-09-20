import QtQuick
import QtQuick.Layouts
import ".."

// Hex colour entry with a live swatch. `committed` fires on Enter or focus
// loss, never per keystroke - otherwise every partially-typed "#ff" would be
// pushed into Config and repaint the widget mid-edit.
ColumnLayout {
    id: colorField

    property string label: ""
    property string value: "#ffffff"

    signal committed(string newValue)

    Layout.fillWidth: true
    spacing: 4

    Text {
        Layout.fillWidth: true
        text: colorField.label
        color: Config.textMuted
        font.family: Config.sysFont
        font.pixelSize: Config.size(Config.fontCaption)
        font.bold: true
        font.letterSpacing: 0.4
        visible: colorField.label !== ""
    }

    SettingsTextField {
        id: entry

        implicitHeight: 34
        text: colorField.value

        onEditingFinished: committedText => {
            if (committedText.length > 0) colorField.committed(committedText)
        }

        // Pushes an externally changed colour back into the field without
        // fighting the user mid-edit.
        Connections {
            target: colorField
            function onValueChanged() {
                if (!entry.input.activeFocus && entry.text !== colorField.value) {
                    entry.text = colorField.value
                }
            }
        }

        trailing: Rectangle {
            implicitWidth: 18
            implicitHeight: 18
            radius: 5
            color: colorField.value || "#111111"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.25)
        }
    }
}
