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
        implicitWidth: 22
        implicitHeight: 22
        radius: 11
        color: minusHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
        Behavior on color { ColorAnimation { duration: 150 } }

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
        implicitWidth: 54
        implicitHeight: 22
        radius: 6
        color: Qt.rgba(0, 0, 0, 0.3)
        border.width: 1
        border.color: Config.accent

        Text {
            anchors.centerIn: parent
            text: root.hourLabel(root.hour)
            color: Config.accent
            font.family: Config.sysFont
            font.bold: true
            font.pixelSize: 10
        }
    }

    Rectangle {
        implicitWidth: 22
        implicitHeight: 22
        radius: 11
        color: plusHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
        Behavior on color { ColorAnimation { duration: 150 } }

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
