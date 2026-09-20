import QtQuick
import QtQuick.Layouts
import ".."

// Vertical stack of surface rows at list spacing rather than the card's row
// spacing. Wrap a Repeater in this whenever its delegates are full-width rows
// with their own background - Wi-Fi networks, Bluetooth devices, assistant
// backends, keybinds, VPN profiles.
//
// ColumnLayout's default property is already `data`, so children declared
// inside this land in the layout with no alias needed.
ColumnLayout {
    Layout.fillWidth: true
    spacing: SettingsStyle.listGap
}
