import QtQuick

Item {
    id: root

    Image {
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.width
        sourceSize.height: root.height
    }

    LoginPanel {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.width * 0.06
        anchors.bottomMargin: root.height * 0.08
    }
}
