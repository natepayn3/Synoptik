import QtQuick
import ".."

// Small pill-shaped action button reused across theme cards in
// GreeterSettings (Preview / Stop / Apply), so it isn't rebuilt inline
// three times with drifting styles.
Rectangle {
    id: control

    property string label: ""
    property bool highlighted: false
    signal clicked()

    implicitWidth: labelText.implicitWidth + 20
    implicitHeight: 26
    radius: 6
    opacity: control.enabled ? 1.0 : 0.4
    color: control.highlighted
        ? (hover.hovered ? Qt.lighter(Config.accent, 1.1) : Config.accent)
        : (hover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05))
    border.width: 1
    border.color: control.highlighted ? Config.accent : Qt.rgba(255, 255, 255, 0.12)

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        id: labelText
        anchors.centerIn: parent
        text: control.label
        color: control.highlighted ? Config.bgBase : Config.textMain
        font.family: Config.sysFont
        font.pixelSize: Config.size(Config.fontMicro)
        font.bold: true
    }

    TapHandler {
        enabled: control.enabled
        onTapped: control.clicked()
    }
    HoverHandler { id: hover; enabled: control.enabled; cursorShape: Qt.PointingHandCursor }
}
