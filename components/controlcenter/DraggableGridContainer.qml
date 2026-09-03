import QtQuick
import ".."

// Two-lane bento board. Each half-width card stacks top-to-bottom within
// lane 0 (left) or lane 1 (right); a card whose colSpan covers the full
// grid width is a "full-width" row spanning both lanes, splitting them into
// separate segments above and below it (e.g. the Media card).
//
// Height is never a fixed span: every card reports its own natural/minimum
// height (naturalHeight, bound to its real content's implicitHeight) and,
// within each segment, whichever lane is naturally taller sets that
// segment's height - the shorter lane's cards grow proportionally (never
// below their own natural height) to fill the gap, so both lanes always end
// up flush. layoutData is a plain computed property, not something anything
// assigns into directly, so it's always in sync with order/lanes/content -
// it reflows automatically if a card's own content grows or shrinks (e.g.
// Night Mode's schedule row toggling on/off), not just after a drag.
Item {
    id: root

    property int columns: 8
    property real spacing: 6
    property real gridWidth: 706

    property var order: []          // [cardId, ...] - top-to-bottom stacking sequence
    property var lanes: ({})        // { cardId: 0|1 } - which half a half-width card lives in

    signal arrangementCommitted()

    // False until the first arrangement has been applied - GridCard only
    // springs into a new spot once this is true, so the very first
    // placement (construction default of 0,0 -> real position) snaps
    // instantly instead of every card visibly flying in from the corner.
    property bool ready: false

    readonly property real columnWidth: columns > 0 ? (gridWidth - spacing * (columns - 1)) / columns : 0
    readonly property real colPitch: columnWidth + spacing
    readonly property int laneColumns: columns / 2

    width: gridWidth
    height: implicitHeight
    implicitHeight: {
        let maxY = 0
        for (let id in layoutData) {
            let e = layoutData[id]
            if (e) maxY = Math.max(maxY, e.y + e.height)
        }
        return maxY
    }

    function childFor(cardId) {
        for (let i = 0; i < children.length; i++) {
            let c = children[i]
            if (c && c.cardId === cardId) return c
        }
        return null
    }

    function isFullWidth(cardId) {
        let child = childFor(cardId)
        return !!child && child.colSpan >= columns
    }

    function naturalHeightOf(cardId) {
        let child = childFor(cardId)
        return child ? Math.max(child.naturalHeight, 1) : 1
    }

    function laneNaturalTotal(ids) {
        let sum = 0
        for (let j = 0; j < ids.length; j++) sum += naturalHeightOf(ids[j])
        return sum + spacing * Math.max(0, ids.length - 1)
    }

    // Lays out one lane's cards starting at pixel y, stretching them
    // proportionally to their own natural height so the lane's total comes
    // out to exactly targetHeight (never less than the lane's own natural
    // total, since targetHeight is always >= that).
    function placeLane(placed, ids, laneIndex, naturalTotal, targetHeight, y) {
        let extra = Math.max(0, targetHeight - naturalTotal)
        let sumNat = 0
        for (let j = 0; j < ids.length; j++) sumNat += naturalHeightOf(ids[j])

        let cursorY = y
        for (let j = 0; j < ids.length; j++) {
            let id = ids[j]
            let child = childFor(id)
            let nat = naturalHeightOf(id)
            let bonus = (sumNat > 0 && extra > 0) ? extra * (nat / sumNat) : 0
            let h = nat + bonus
            placed[id] = {
                x: laneIndex * laneColumns * colPitch,
                y: cursorY,
                width: child.colSpan * columnWidth + (child.colSpan - 1) * spacing,
                height: h
            }
            cursorY += h + spacing
        }
    }

    // The one place geometry ever gets computed - a plain derived property,
    // never assigned into from outside, so it can't go stale relative to
    // order/lanes/content.
    readonly property var layoutData: {
        let segments = []
        let lane0 = []
        let lane1 = []
        for (let i = 0; i < order.length; i++) {
            let id = order[i]
            let child = childFor(id)
            if (!child) continue
            if (child.colSpan >= columns) {
                if (lane0.length || lane1.length) segments.push({ lane0: lane0, lane1: lane1 })
                lane0 = []; lane1 = []
                segments.push({ full: id })
            } else if (lanes[id] === 1) {
                lane1.push(id)
            } else {
                lane0.push(id)
            }
        }
        if (lane0.length || lane1.length) segments.push({ lane0: lane0, lane1: lane1 })

        let placed = {}
        let y = 0
        for (let s = 0; s < segments.length; s++) {
            let seg = segments[s]
            if (seg.full !== undefined) {
                let child = childFor(seg.full)
                let h = naturalHeightOf(seg.full)
                placed[seg.full] = {
                    x: 0, y: y,
                    width: child.colSpan * columnWidth + (child.colSpan - 1) * spacing,
                    height: h
                }
                y += h + spacing
                continue
            }

            let nat0 = laneNaturalTotal(seg.lane0)
            let nat1 = laneNaturalTotal(seg.lane1)
            let target = Math.max(nat0, nat1)

            placeLane(placed, seg.lane0, 0, nat0, target, y)
            placeLane(placed, seg.lane1, 1, nat1, target, y)

            y += target + spacing
        }

        return placed
    }

    // Merges a saved arrangement over the compiled-in default (falling back
    // entirely to the default if the saved order doesn't match the current
    // set of cards, e.g. after a card was added/removed in an update).
    function initArrangement(defaultOrder, defaultLanes, saved) {
        let validSaved = saved && Array.isArray(saved.order) &&
            saved.order.length === defaultOrder.length &&
            defaultOrder.every(id => saved.order.includes(id))

        order = validSaved ? saved.order.slice() : defaultOrder.slice()
        lanes = (validSaved && saved.lanes) ? Object.assign({}, defaultLanes, saved.lanes) : Object.assign({}, defaultLanes)
        ready = true
    }

    // Called continuously while cardId is being dragged (centerX/centerY are
    // its live pixel center within this container). Works out which lane
    // it's hovering and which card it should land above, then splices it
    // into that spot in order - which is what makes every other card
    // cascade into its new position. Only actually re-splices when the
    // resolved target changes, so a drag doesn't thrash every frame.
    property string _lastTarget: ""

    function updateDragTarget(cardId, centerX, centerY) {
        let full = isFullWidth(cardId)
        let targetLane = full ? -1 : (centerX < gridWidth / 2 ? 0 : 1)

        let candidates = order.filter(id => {
            if (id === cardId) return false
            if (full) return true
            return lanes[id] === targetLane || isFullWidth(id)
        })

        // Topmost candidate still below the drag point - found by best match
        // rather than first-in-order, since a full-width drag's candidates
        // span both lanes and their y's aren't guaranteed to be sequence-
        // monotonic once the two lanes have drifted to different heights.
        let beforeId = ""
        let bestY = Infinity
        for (let i = 0; i < candidates.length; i++) {
            let e = layoutData[candidates[i]]
            if (!e) continue
            let mid = e.y + e.height / 2
            if (mid > centerY && mid < bestY) {
                bestY = mid
                beforeId = candidates[i]
            }
        }

        let sig = targetLane + "|" + beforeId
        if (sig === _lastTarget) return
        _lastTarget = sig

        let newOrder = order.filter(id => id !== cardId)
        let insertAt = beforeId ? newOrder.indexOf(beforeId) : -1
        if (insertAt === -1) newOrder.push(cardId)
        else newOrder.splice(insertAt, 0, cardId)

        let newLanes = lanes
        if (!full) {
            newLanes = Object.assign({}, lanes)
            newLanes[cardId] = targetLane
        }

        order = newOrder
        lanes = newLanes
    }

    function beginDrag() {
        _lastTarget = ""
    }

    function commit() {
        arrangementCommitted()
    }
}
