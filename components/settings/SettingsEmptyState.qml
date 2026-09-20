import QtQuick
import QtQuick.Layouts
import ".."

// "Nothing here yet" panel - a glyph, a headline and a line telling the user
// what to do about it. Bluetooth, Wi-Fi and Network each grew their own.
Rectangle {
    id: empty

    property string icon: "info"
    property string title: ""
    property string hint: ""

    Layout.fillWidth: true
    implicitHeight: emptyCol.implicitHeight + 44
    radius: SettingsStyle.controlRadius
    color: SettingsStyle.controlBg
    border.width: 1
    border.color: SettingsStyle.controlBorder

    ColumnLayout {
        id: emptyCol

        anchors.centerIn: parent
        width: parent.width - 48
        spacing: SettingsStyle.tightGap

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: empty.icon
            font.family: "Material Symbols Outlined"
            font.pixelSize: 36
            color: Config.textMuted
        }

        Text {
            Layout.fillWidth: true
            text: empty.title
            horizontalAlignment: Text.AlignHCenter
            font.family: Config.sysFont
            font.bold: true
            font.pixelSize: Config.size(Config.fontBody)
            color: Config.textMain
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            text: empty.hint
            horizontalAlignment: Text.AlignHCenter
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            color: Config.textMuted
            wrapMode: Text.WordWrap
            visible: empty.hint !== ""
        }
    }
}
