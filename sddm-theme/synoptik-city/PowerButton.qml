import QtQuick
import QtQuick.Controls.Basic

Button {
    id: control

    property string iconText: ""

    implicitWidth: 52
    implicitHeight: 52

    background: Rectangle {
        radius: width / 2
        color: control.hovered ? "#33ffd88a" : "#14ffffff"
        border.color: control.hovered ? "#ffd88a" : "#40ffffff"
        border.width: 1.5
    }

    contentItem: Text {
        text: control.iconText
        color: "#fdf6ec"
        font.pixelSize: 23
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
