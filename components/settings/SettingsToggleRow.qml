import QtQuick
import QtQuick.Layouts
import ".."

// Shared "toggle row" used across the Settings panel - a title + optional
// subtitle paired with a ToggleSwitch. Previously duplicated as inline
// RowLayout/ColumnLayout/ToggleSwitch blocks across most *Settings.qml
// files. The actual Config mutation (and save) is left entirely to the
// caller via onToggled, so this component doesn't need to know which
// Config property it's driving.
RowLayout {
    id: root
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    signal toggled()

    Layout.fillWidth: true
    spacing: 12

    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: 0
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Config.textMain
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontBody)
            font.bold: true
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            text: root.subtitle
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            wrapMode: Text.WordWrap
            visible: root.subtitle !== ""
        }
    }

    ToggleSwitch {
        checked: root.checked

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled()
        }
    }
}
