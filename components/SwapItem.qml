import QtQuick

// A single-axis drag-to-swap tile, much simpler than ControlCenter's
// GridCard: there's no dynamic resizing here, just a fixed target geometry
// (targetX/Y/Width/Height, computed by the caller from which of two fixed
// slots this item currently occupies) that this snaps/springs to. Dragging
// only tracks the one axis this item cares about (Qt.Horizontal or
// Qt.Vertical) - the caller listens to dragMoved and decides, based on
// whatever swap rule applies, when to flip its own slot-assignment state;
// this component has no idea what "the other slot" is.
Item {
    id: root

    property int axis: Qt.Vertical
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 100
    property real targetHeight: 100

    // False until the caller's arrangement has been applied at least once -
    // gates the spring so the very first placement snaps instantly instead
    // of flying in from a default position on open.
    property bool ready: false

    default property alias content: contentHost.data

    signal dragMoved(real dx, real dy)
    signal dragEnded()

    readonly property bool isBeingDragged: dragHandler.active
    property real dragBaseX: 0
    property real dragBaseY: 0

    x: (isBeingDragged && axis === Qt.Horizontal) ? (dragBaseX + dragHandler.translation.x) : targetX
    y: (isBeingDragged && axis === Qt.Vertical) ? (dragBaseY + dragHandler.translation.y) : targetY
    width: targetWidth
    height: targetHeight

    readonly property bool animated: !isBeingDragged && ready
    Behavior on x { enabled: root.animated; SpringAnimation { spring: 3.2; damping: 0.4; mass: 0.9 } }
    Behavior on y { enabled: root.animated; SpringAnimation { spring: 3.2; damping: 0.4; mass: 0.9 } }
    Behavior on width { enabled: root.animated; SpringAnimation { spring: 3.2; damping: 0.4; mass: 0.9 } }
    Behavior on height { enabled: root.animated; SpringAnimation { spring: 3.2; damping: 0.4; mass: 0.9 } }

    z: isBeingDragged ? 2000 : 1

    DragHandler {
        id: dragHandler
        target: null
        onActiveChanged: {
            if (active) {
                root.dragBaseX = root.targetX
                root.dragBaseY = root.targetY
            } else {
                root.dragEnded()
            }
        }
        onTranslationChanged: {
            if (active) root.dragMoved(translation.x, translation.y)
        }
    }

    Item {
        id: contentHost
        anchors.fill: parent
    }

    // Purely decorative accent outline while this item is being held - a
    // plain Rectangle with no handlers of its own, so it never eats clicks
    // even though it's visible on top of the content.
    Rectangle {
        anchors.fill: parent
        radius: Config.cornerRadius
        color: "transparent"
        border.width: 2
        border.color: Config.accent
        opacity: root.isBeingDragged ? 0.9 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}
