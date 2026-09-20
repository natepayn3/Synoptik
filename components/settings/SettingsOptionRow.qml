import QtQuick
import QtQuick.Layouts
import ".."

// Full-width selectable row - one entry in a list of mutually exclusive
// choices (assistant backend, Wi-Fi network, Bluetooth device, greeter theme).
// Distinct from SettingsSegmented, which is for a handful of short labels that
// fit on one line; this is for entries that need a subtitle, a status and
// room for actions.
Rectangle {
    id: option

    property alias actions: actionRow.data

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property bool selected: false

    // Leading dot. Left transparent (and hidden) unless a page sets a colour -
    // used for "installed / not found", "connected", "paired" style state.
    property color statusColor: "transparent"
    property string statusText: ""

    signal clicked()

    Layout.fillWidth: true
    implicitHeight: Math.max(46, optionRow.implicitHeight + 16)
    radius: SettingsStyle.controlRadius
    color: option.selected
        ? SettingsStyle.accentSoft
        : (optionHover.hovered ? SettingsStyle.controlBgHover : SettingsStyle.controlBg)
    border.width: 1
    border.color: option.selected ? SettingsStyle.accentLine : SettingsStyle.controlBorder

    Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }
    Behavior on border.color { ColorAnimation { duration: SettingsStyle.animFast } }

    RowLayout {
        id: optionRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 8
            implicitHeight: 8
            radius: 4
            color: option.statusColor
            visible: option.statusColor.a > 0
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: option.icon
            color: option.selected ? Config.accent : Config.textMuted
            font.family: "Material Symbols Outlined"
            font.pixelSize: 19
            visible: option.icon !== ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: option.title
                color: option.selected ? Config.accent : Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: option.subtitle
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                elide: Text.ElideRight
                visible: option.subtitle !== ""
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: option.statusText
            color: option.statusColor.a > 0 ? option.statusColor : Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontMicro)
            font.bold: true
            visible: option.statusText !== ""
        }

        RowLayout {
            id: actionRow
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: false
            spacing: 6
        }
    }

    TapHandler { onTapped: option.clicked() }
    HoverHandler { id: optionHover; cursorShape: Qt.PointingHandCursor }
}
