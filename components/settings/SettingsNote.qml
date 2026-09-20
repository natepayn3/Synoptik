import QtQuick
import QtQuick.Layouts
import ".."

// Inline explanatory / warning strip inside a card. `variant` is "info"
// (default), "warn" or "danger".
Rectangle {
    id: note

    property string text: ""
    property string variant: "info"

    readonly property color tone: variant === "danger"
        ? SettingsStyle.danger
        : (variant === "warn" ? "#f5a524" : Config.accent)

    readonly property string glyph: variant === "danger"
        ? "error"
        : (variant === "warn" ? "warning" : "info")

    Layout.fillWidth: true
    implicitHeight: noteRow.implicitHeight + 20
    radius: SettingsStyle.controlRadius
    color: Qt.rgba(note.tone.r, note.tone.g, note.tone.b, 0.1)
    border.width: 1
    border.color: Qt.rgba(note.tone.r, note.tone.g, note.tone.b, 0.28)

    RowLayout {
        id: noteRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 9

        Text {
            Layout.alignment: Qt.AlignTop
            text: note.glyph
            color: note.tone
            font.family: "Material Symbols Outlined"
            font.pixelSize: 17
        }

        Text {
            Layout.fillWidth: true
            text: note.text
            color: Config.textMain
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            wrapMode: Text.WordWrap
        }
    }
}
