import QtQuick

// Compact pill used by GreeterSettings' theme cards (Preview / Stop / Apply).
// Kept as a named type because those call sites read better with
// `highlighted` / `danger` flags than with a variant string, but it is now a
// thin skin over SettingsButton so there is one button look in the module.
SettingsButton {
    id: control

    property bool highlighted: false
    property bool danger: false

    variant: control.danger ? "danger" : (control.highlighted ? "accent" : "quiet")
    implicitHeight: 26
}
