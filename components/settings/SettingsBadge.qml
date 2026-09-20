import QtQuick
import QtQuick.Layouts
import ".."

// Small status pill - PAIRED, CONNECTED, 84%, a device count. `tone` is the
// accent colour when highlighted and the muted text colour otherwise.
Rectangle {
    id: badge

    property string text: ""
    property string icon: ""
    property bool highlighted: false
    property color tone: badge.highlighted ? Config.accent : Config.textMuted

    implicitWidth: badgeRow.implicitWidth + 12
    implicitHeight: 18
    radius: 9
    color: Qt.rgba(badge.tone.r, badge.tone.g, badge.tone.b, badge.highlighted ? 0.2 : 0.1)
    border.width: 1
    border.color: Qt.rgba(badge.tone.r, badge.tone.g, badge.tone.b, badge.highlighted ? 0.6 : 0.2)

    RowLayout {
        id: badgeRow
        anchors.centerIn: parent
        spacing: 3

        Text {
            text: badge.icon
            font.family: "Material Symbols Outlined"
            font.pixelSize: 11
            color: badge.tone
            visible: badge.icon !== ""
        }

        Text {
            text: badge.text
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontMicro)
            font.bold: true
            color: badge.tone
        }
    }
}
