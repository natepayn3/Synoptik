import QtQuick
import QtQuick.Layouts
import ".."

// Hairline rule between groups of rows inside one card, for the few places a
// card holds two distinct clusters that don't each warrant their own card.
Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 1
    color: SettingsStyle.divider
}
