import QtQuick
import ".."

// Shared toggle switch used across the Settings panel - previously a
// verbatim `component ToggleSwitch : Rectangle { ... }` block copy-pasted
// into 13 separate *Settings.qml files. Same-directory QML types resolve
// automatically, so every consumer just drops the local declaration and
// keeps using `ToggleSwitch { ... }` unchanged.
Rectangle {
    id: sw
    property bool checked: false

    implicitWidth: 40
    implicitHeight: 22
    radius: 6
    color: checked ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2) : Qt.rgba(0, 0, 0, 0.4)
    border.width: sw.checked ? 2 : 1
    border.color: checked ? Config.accent : Qt.rgba(255, 255, 255, 0.15)

    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    // Square Thumb / Slider
    Rectangle {
        id: thumb
        x: sw.checked ? (sw.width - width - 3) : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 4
        color: sw.checked ? Config.accent : Qt.rgba(255, 255, 255, 0.2)
        border.width: 0
        border.color: sw.checked ? Qt.lighter(Config.accent, 1.2) : Qt.rgba(255, 255, 255, 0.25)

        Behavior on x {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
    }
}
