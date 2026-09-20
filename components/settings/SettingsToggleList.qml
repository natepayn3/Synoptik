pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."

// A column of toggles driven straight off Config by property name - for the
// pages that expose a long list of independent on/off fields (System Info's
// identifiers, hardware specs, network metrics and gauges; Notifications'
// per-category switches).
//
// model entries: { key, label, desc?, icon?, def? }
//   key  - the Config property name to read and write
//   def  - value to show when Config doesn't define that property yet
//
// Writing back through Config[key] is what lets one component serve four
// groups that previously needed four near-identical 40-line Repeaters.
ColumnLayout {
    id: list

    property var model: []

    Layout.fillWidth: true
    spacing: SettingsStyle.rowGap

    Repeater {
        model: list.model

        delegate: SettingsToggleRow {
            required property var modelData

            readonly property bool fallback: modelData.def !== undefined ? modelData.def : true
            readonly property bool current: Config[modelData.key] !== undefined
                ? Config[modelData.key]
                : fallback

            title: modelData.label
            subtitle: modelData.desc !== undefined ? modelData.desc : ""
            icon: modelData.icon !== undefined ? modelData.icon : ""
            checked: current
            onToggled: Config[modelData.key] = !current
        }
    }
}
