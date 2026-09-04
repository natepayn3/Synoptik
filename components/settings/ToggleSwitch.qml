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

    onCheckedChanged: squash.restart()

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

        transform: Scale {
            id: thumbSquash
            origin.x: thumb.width / 2
            origin.y: thumb.height / 2
            xScale: 1.0
            yScale: 1.0
        }

        Behavior on x {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }
        }
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
    }

    // Every flip gives the thumb a quick lateral squash-and-recover, like it
    // took the impulse of the toggle rather than just easing to a new spot.
    ParallelAnimation {
        id: squash
        SequentialAnimation {
            NumberAnimation { target: thumbSquash; property: "xScale"; to: 1.45; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: thumbSquash; property: "xScale"; to: 1.0; duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
        }
        SequentialAnimation {
            NumberAnimation { target: thumbSquash; property: "yScale"; to: 0.62; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: thumbSquash; property: "yScale"; to: 1.0; duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
        }
    }
}
