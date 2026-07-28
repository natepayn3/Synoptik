import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root

    property string iconName: ""
    property string iconPath: ""
    property bool isActive: false
    
    signal clicked()

    Layout.preferredWidth: 32
    Layout.preferredHeight: 32
    radius: 10
    color: buttonMouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

    Behavior on color { ColorAnimation { duration: 150 } }

    IconImage {
        anchors.centerIn: parent
        width: 20
        height: 20
        source: {
            if (root.iconPath !== "") return "file://" + root.iconPath;
            if (root.iconName !== "") {
                let lookup = Quickshell.iconPath(root.iconName);
                return lookup ? lookup : "";
            }
            return "";
        }
    }

    MouseArea {
        id: buttonMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}