import ".."
import "../services"
import QtQuick

// The bar, in every state (idle pill, open+merged with a popout, peeking),
// as one signed-distance-field blob - replacing BarClosedShape.qml and the
// four BarOpenShape{Top,Bottom,Left,Right}.qml Bezier files, which needed
// their own hand-tuned geometry per bar position and, separately, kept
// drifting out of sync with where the real bar content and popout content
// actually render (contentContainer's own x/y/width/height were computed by
// a parallel formula the shape files re-derived independently - any small
// difference between the two showed up as a gap or seam between the bar and
// the popout, which is what every earlier attempt at this kept hitting).
//
// The fix that actually matters here: barRect and popoutRect are read
// directly off barContentItem/popoutContentItem's own laid-out geometry,
// not recomputed from the same inputs a second time. Whatever those two
// items' real x/y/width/height are - through every animation, every bar
// position, peek included - is what the blob merges, so there is no second
// formula left to disagree with the first.
Item {
    id: sdfBar

    required property var panelRoot
    required property Item barContentItem
    required property Item popoutContentItem

    anchors.fill: parent
    visible: !panelRoot.isScreenFrame && !panelRoot.isLeftFlush && !panelRoot.isRightFlush

    readonly property bool hasPopoutNow: panelRoot.progress > 0.01 || panelRoot.isPeeking

    // barContentItem (barContent) really is inset from the bar's true outer
    // edge by half the border width on every side - its own x/y/width/height
    // formulas explicitly carve out that room for the border stroke, drawn
    // centred on that edge - so it's expanded back out by the same amount
    // here to recover the real outer silhouette.
    //
    // popoutContentItem (contentContainer) gets no such inset anywhere else
    // in the codebase: its width/height ARE the target size (currentWidth/
    // currentHeight, or peek's span/depth) with no border deducted, and its
    // x/y are placed to land exactly flush against barRect's expanded edge
    // already. Applying the same border expansion to popoutRect on every
    // side - which an earlier version of this file did, on the assumption
    // both items were inset the same way - inflates it by a full border
    // width all around. At full popout size that's a couple of stray pixels
    // nobody notices; at peek's ~6px depth it's most of the shape, which is
    // what was producing a disconnected, flickering peek border.
    readonly property real halfB: panelRoot.halfB

    readonly property rect barRect: Qt.rect(
        barContentItem.x - halfB,
        barContentItem.y - halfB,
        barContentItem.width + panelRoot.borderWidth,
        barContentItem.height + panelRoot.borderWidth
    )

    // smin only rounds off the reflex (concave) corner smin leaves behind
    // where a narrower popout meets a wider bar within uSmoothFactor of
    // BOTH surfaces - see blob.frag. If popoutRect touches barRect exactly
    // at their shared edge (zero overlap), that whole rounded notch sits
    // right on the visible silhouette, in open air, reading as an unwanted
    // inward curve at the two corners where the popout meets the bar - it's
    // most obvious on the peek nub because the notch's radius (wingW) is a
    // huge fraction of the nub's own depth there.
    //
    // The fix: push popoutRect's near edge - the one touching the bar - back
    // INTO the bar by roughly the current wing size (plus a hair extra as a
    // buffer). That moves the entire rounded-notch region up inside the
    // bar's own silhouette, where it's just "deep inside both shapes" and
    // invisible - so the only curve left showing on the outside is the
    // popout's own convex corner radius, further down where it's not
    // touching the bar at all. Only the touching edge is extended; the
    // other three edges stay exactly on the popout's real geometry, since
    // those are the ones that actually need to match the content precisely.
    readonly property real popoutOverlap: panelRoot.wingW + panelRoot.borderWidth

    readonly property rect popoutRect: {
        let ov = popoutOverlap
        let r = Qt.rect(popoutContentItem.x, popoutContentItem.y, popoutContentItem.width, popoutContentItem.height)
        if (panelRoot.isHorizontal) {
            if (panelRoot.isBottom) {
                r.height += ov // touches the bar along its bottom edge
            } else {
                r.y -= ov; r.height += ov // touches the bar along its top edge
            }
        } else {
            if (panelRoot.isRight) {
                r.width += ov // touches the bar along its right edge
            } else {
                r.x -= ov; r.width += ov // touches the bar along its left edge
            }
        }
        return r
    }

    SdfBlobSurface {
        anchors.fill: parent
        surfaceColor: Config.bgPanel
        borderColor: shellRoot.currentBorderColor
        borderWidth: panelRoot.borderWidth
        barCornerRadius: panelRoot.barRadius
        popoutCornerRadius: Math.max(0.1, panelRoot.radius)
        smoothFactor: Math.max(0.5, panelRoot.wingW)
        hasPopout: sdfBar.hasPopoutNow
        barRect: sdfBar.barRect
        popoutRect: sdfBar.hasPopoutNow ? sdfBar.popoutRect : Qt.rect(0, 0, 0, 0)
    }
}
