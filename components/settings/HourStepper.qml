import QtQuick
import QtQuick.Layouts
import ".."

// A -/+ stepper over a 24-hour clock value, shown in 12-hour form.
// Extracted because the night-mode schedule in SlidersCard.qml spells this out
// twice, verbatim, for its start and end hours - the DND schedule would have
// made four copies of the same forty lines.
RowLayout {
    id: root

    property int hour: 0
    signal hourPicked(int hour)

    spacing: 4

    function hourLabel(h) {
        let period = h >= 12 ? "PM" : "AM"
        let hr = h % 12
        if (hr === 0) hr = 12
        return hr + " " + period
    }

    Rectangle {
        implicitWidth: 26
        implicitHeight: 26
        radius: 13
        color: minusHover.hovered ? SettingsStyle.controlBgHover : SettingsStyle.controlBg
        border.width: 1
        border.color: SettingsStyle.controlBorder
        Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }

        Text {
            anchors.centerIn: parent
            text: "remove"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 12
            color: Config.textMain
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            // +23 rather than -1 so the result is never negative: JS's % keeps
            // the sign of the left operand, so (0 - 1) % 24 is -1, not 23.
            onClicked: root.hourPicked((root.hour + 23) % 24)
        }
        HoverHandler { id: minusHover }
    }

    Rectangle {
        implicitWidth: 60
        implicitHeight: 26
        radius: SettingsStyle.controlRadius * 0.8
        color: SettingsStyle.controlBg
        border.width: 1
        border.color: SettingsStyle.accentLine

        Text {
            anchors.centerIn: parent
            text: root.hourLabel(root.hour)
            color: Config.accent
            font.family: Config.sysFont
            font.bold: true
            font.pixelSize: Config.size(Config.fontMicro)
        }
    }

    Rectangle {
        implicitWidth: 26
        implicitHeight: 26
        radius: 13
        color: plusHover.hovered ? SettingsStyle.controlBgHover : SettingsStyle.controlBg
        border.width: 1
        border.color: SettingsStyle.controlBorder
        Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }

        Text {
            anchors.centerIn: parent
            text: "add"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 12
            color: Config.textMain
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.hourPicked((root.hour + 1) % 24)
        }
        HoverHandler { id: plusHover }
    }
}
