import QtQuick

// A bar+popout "blob" surface rendered as a merged signed-distance-field
// shape, instead of the hand-authored Bezier wing geometry in
// components/surface/*.qml. Revived from an earlier attempt (deleted at
// 25ab0a6) that got the fill/merge geometry right - ported faithfully from
// Caelestia's own blob.frag, down to the circular smin - but rendered its
// border as an independent "onion ring" (abs(d ± w/2) - w/2, then its own
// smoothstep), which blurred exactly on the curved wing where two rects
// smin-blend: an abs() creates a fold in the field, fwidth() of a fold is
// unreliable wherever the gradient direction is also changing (i.e.
// wherever the shape curves), and a smin blend is itself only an
// approximate distance field to begin with - so the wing is exactly where
// both problems are worst at once.
//
// Ryoku (a fork of Caelestia's blob plugin) solves it by never computing an
// independent ring at all: the border is a one-sided smoothstep threshold
// on the SAME mergedSdf and the SAME fwidth-derived width already used for
// the silhouette's own antialiasing, so the border can only ever be as
// blurry as the silhouette edge already is - never a separately-computed,
// separately-blurred shape layered on top of it. That's the fix applied
// here (see the border block in the fragment shader below).
Item {
    id: root

    property color surfaceColor: "#1e1e2e"
    property color borderColor: "transparent"
    property real borderWidth: 0.0

    // Bar and popout keep their own corner radius (they usually differ -
    // barRadius from Config.cornerRadius, popout radius from
    // Config.surfaceRadius) - the wing itself is governed by smoothFactor,
    // independently of either.
    property real barCornerRadius: 12.0
    property real popoutCornerRadius: 18.0
    property real smoothFactor: 16.0

    // Local-item-space rects (same coordinate space as this Item itself),
    // matching what the Bezier shapes' own panelRoot geometry already is.
    property rect barRect: Qt.rect(0, 0, 0, 0)
    property rect popoutRect: Qt.rect(0, 0, 0, 0)
    property bool hasPopout: false

    ShaderEffect {
        anchors.fill: parent

        readonly property color uSurfaceColor: root.surfaceColor
        readonly property color uBorderColor: root.borderColor
        readonly property real uBorderWidth: root.borderWidth
        readonly property real uBarRadius: root.barCornerRadius
        readonly property real uPopoutRadius: root.popoutCornerRadius
        // smin divides by k in effect (via the max(k, ...) term) - 0 would
        // be a divide-by-a-degenerate-blend, not a hard union, so floor it.
        readonly property real uSmoothFactor: Math.max(0.01, root.smoothFactor)

        readonly property vector2d uScreenSize: Qt.vector2d(root.width, root.height)
        readonly property vector4d uBar: Qt.vector4d(root.barRect.x, root.barRect.y, root.barRect.width, root.barRect.height)
        readonly property vector4d uPopout: Qt.vector4d(root.popoutRect.x, root.popoutRect.y, root.popoutRect.width, root.popoutRect.height)
        // QML bool -> GLSL uniform: kept as a float (0.0/1.0), matching the
        // pattern the pre-deletion version of this file already used
        // successfully, rather than relying on native bool uniform support.
        readonly property real uHasPopout: root.hasPopout ? 1.0 : 0.0

        // Qt 6's ShaderEffect does not accept inline GLSL - fragmentShader
        // must be a URL to a .qsb file pre-baked by the qsb tool (source of
        // truth: shaders/blob.frag, baked via
        // `qsb --qt6 -o shaders/blob.frag.qsb shaders/blob.frag`, run from
        // this file's directory whenever blob.frag changes). Assigning raw
        // GLSL source here silently fails: Qt treats the string as a
        // (nonexistent) file URL, logs a WARN to the quickshell log - never
        // to stdout - and the effect renders fully transparent, which looks
        // identical to "the shape just didn't show up."
        fragmentShader: "shaders/blob.frag.qsb"
    }
}
