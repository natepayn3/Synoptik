import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: control

    implicitHeight: 58

    background: Rectangle {
        radius: 14
        color: control.activeFocus || control.popup.visible ? "#26ffffff" : "#14ffffff"
        border.color: control.activeFocus || control.popup.visible ? "#ffd88a" : "#40ffffff"
        border.width: 1.5
    }

    contentItem: Text {
        text: control.displayText
        color: "#fdf6ec"
        leftPadding: 18
        rightPadding: 38
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font.pixelSize: 18
    }

    indicator: Text {
        text: "⌄"
        color: "#ffd88a"
        font.pixelSize: 20
        x: control.width - width - 16
        y: (control.height - height) / 2
    }

    delegate: ItemDelegate {
        id: delegateItem
        required property string name
        required property int index
        width: control.width
        highlighted: control.highlightedIndex === index

        contentItem: Text {
            text: delegateItem.name
            color: "#fdf6ec"
            leftPadding: 18
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 18
        }

        background: Rectangle {
            radius: 10
            color: delegateItem.highlighted ? "#33ffd88a" : "transparent"
        }
    }

    popup: Popup {
        y: control.height + 4
        width: control.width
        implicitHeight: popupListView.contentHeight + 8
        padding: 4

        background: Rectangle {
            radius: 14
            color: "#2a1a3d"
            opacity: 0.96
            border.color: "#40ffffff"
        }

        contentItem: ListView {
            id: popupListView
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
        }
    }
}
