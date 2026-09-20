import QtQuick

// Title + optional subtitle paired with a ToggleSwitch - by far the most
// common row in the module. The Config mutation (and save) stays with the
// caller via onToggled, so this doesn't need to know which property it drives.
//
// Now a thin specialisation of SettingsRow rather than its own RowLayout, so
// toggle rows and every other row type share one set of typography and
// alignment rules.
SettingsRow {
    id: root

    property bool checked: false
    signal toggled()

    ToggleSwitch {
        checked: root.checked

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled()
        }
    }
}
