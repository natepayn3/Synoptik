import QtQuick
import ".."

// A drag-reorderable tile on a DraggableGridContainer. colSpan is this
// card's fixed width (half the grid = a lane card, the full grid = a
// full-width row like Media); naturalHeight is its real minimum content
// height (bind it to the wrapped card's own implicitHeight) - the container
// reads both straight off these properties to lay every card out, stretching
// naturalHeight when its lane needs to grow to match its neighbor. Position
// and final height (entry.x/y/width/height) always come back from the
// container, never chosen here.
//
// The whole card is a drag target (DragHandler on root, covering the card's
// full bounds) - there's no separate "edit mode" or handle-only hit area.
// A DragHandler only takes its exclusive grab once the pointer moves past
// the platform's drag threshold, and a nested control that's already
// tracking its own gesture (the volume/brightness sliders' MouseArea use
// preventStealing, the process-kill/tap buttons are simple taps that never
// cross that threshold) keeps it - so ordinary clicks and slider drags on
// the card's own content are unaffected. No drag icon/handle is shown -
// the whole card is simply grabbable.
Item {
    id: root

    property var container: null
    property string cardId: ""
    property int colSpan: 4
    property real naturalHeight: 100

    default property alias content: contentHost.data

    readonly property var entry: (container && container.layoutData[cardId]) ? container.layoutData[cardId] : { x: 0, y: 0, width: implicitWidth, height: naturalHeight }

    readonly property real gridX: entry.x
    readonly property real gridY: entry.y
    readonly property real gridW: entry.width
    readonly property real gridH: entry.height

    readonly property bool isBeingDragged: dragHandler.active

    property real dragBaseX: 0
    property real dragBaseY: 0

    x: isBeingDragged ? (dragBaseX + dragHandler.translation.x) : gridX
    y: isBeingDragged ? (dragBaseY + dragHandler.translation.y) : gridY
    width: gridW
    height: gridH

    // Bouncy settle for every card except the one actively being dragged
    // (which tracks the cursor 1:1) - this is what makes displaced cards
    // spring into their new spot instead of just sliding there. height
    // needs the same treatment as x/y now, since a card's final height can
    // change whenever its own content or its lane-mate's does, not just on
    // a drag. Gated on container.ready so the very first placement
    // (construction default -> real position) snaps instantly instead of
    // every card visibly flying in from the corner on open.
    readonly property bool animated: !isBeingDragged && !!(container && container.ready)
    Behavior on x { enabled: root.animated; SpringAnimation { spring: 3.2; damping: 0.4; mass: 0.9 } }
    Behavior on y { enabled: root.animated; SpringAnimation { spring: 3.2; damping: 0.4; mass: 0.9 } }
    Behavior on height { enabled: root.animated; SpringAnimation { spring: 3.2; damping: 0.4; mass: 0.9 } }

    z: isBeingDragged ? 2000 : 1

    DragHandler {
        id: dragHandler
        target: null
        onActiveChanged: {
            if (active) {
                root.dragBaseX = root.gridX
                root.dragBaseY = root.gridY
                if (root.container) root.container.beginDrag()
            } else if (root.container) {
                root.container.commit()
            }
        }
        onTranslationChanged: {
            if (!active || !root.container) return
            let centerX = root.dragBaseX + translation.x + root.width / 2
            let centerY = root.dragBaseY + translation.y + root.height / 2
            root.container.updateDragTarget(root.cardId, centerX, centerY)
        }
    }

    Item {
        id: contentHost
        anchors.fill: parent
    }

    // Purely decorative accent outline while this card is being held - a
    // plain Rectangle with no handlers of its own, so it never eats clicks
    // even though it's visible on top of the card's content.
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
