pragma Singleton
import QtQuick
import ".."

// Single source of truth for the Settings module's visual rhythm.
//
// Before this existed, every *Settings.qml re-typed its own card recipe inline
// (`radius: Config.cornerRadius`, `Qt.rgba(255, 255, 255, 0.05)`,
// `anchors.margins: 14`) and the numbers had drifted: card padding ranged from
// 12 to 18, content columns were capped at 560/620/unbounded, and a handful of
// pages had no card surface at all. Everything in the module now reads its
// spacing, radii and surface colours from here, so a change to the shell's
// corner radius or accent propagates without touching 24 files.
//
// Note on Qt.rgba: the existing code calls it with 255-scale arguments, which
// clamp to 1.0 and happen to produce white. These use 1.0 directly - same
// resulting colour, but it no longer looks like a latent bug.
QtObject {
    // --- Layout rhythm ---------------------------------------------------
    // Cap on the reading column. Settings text is left-aligned prose plus
    // controls; past ~720px the toggle on the right drifts so far from its
    // label that the pairing stops reading as one row.
    readonly property real contentMaxWidth: 720

    readonly property real pageGap: Math.max(10, Config.cardMargin || 12)
    readonly property real cardPadding: 16
    readonly property real rowGap: 14
    readonly property real tightGap: 8

    // Gap between adjacent surface rows in a list - Wi-Fi networks, Bluetooth
    // devices, assistant backends, keybinds. Deliberately much tighter than
    // rowGap: those rows already separate themselves with a border and a
    // radius, so rowGap's 14px makes them read as unrelated cards rather than
    // as one list.
    readonly property real listGap: 6

    // --- Card surface ----------------------------------------------------
    // Cards sit inside the already-rounded right pane, so they take a slightly
    // tighter radius than the shell - concentric corners rather than matching
    // ones, which is what keeps nested rounded rectangles from looking sloppy.
    readonly property real cardRadius: Math.max(10, (Config.cornerRadius || 18) * 0.8)
    readonly property real controlRadius: Math.max(6, cardRadius * 0.5)

    readonly property color cardBg: Qt.rgba(1, 1, 1, 0.045)
    readonly property color cardBorder: Qt.rgba(1, 1, 1, 0.09)
    readonly property color cardBorderHover: Qt.rgba(1, 1, 1, 0.14)
    readonly property color divider: Qt.rgba(1, 1, 1, 0.07)

    // --- Controls --------------------------------------------------------
    readonly property color controlBg: Qt.rgba(1, 1, 1, 0.04)
    readonly property color controlBgHover: Qt.rgba(1, 1, 1, 0.08)
    readonly property color controlBorder: Qt.rgba(1, 1, 1, 0.1)
    // The one genuinely recessed surface left: a slider's groove, which has to
    // read as cut into the card for the filled portion to look like a level.
    // Rows, inputs and container wells all sit on controlBg - they are content
    // surfaces, not tracks, and a dark fill made them read as holes punched in
    // the card rather than as part of it.
    readonly property color trackBg: Qt.rgba(0, 0, 0, 0.35)

    readonly property color accentSoft: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.16)
    readonly property color accentMed: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.28)
    readonly property color accentLine: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.38)

    readonly property color danger: "#ef4444"
    readonly property color dangerSoft: Qt.rgba(0.937, 0.267, 0.267, 0.18)

    // --- Motion ----------------------------------------------------------
    readonly property int animFast: 140
    readonly property int animMed: 220

    // Hover lift. Every card grows a touch under the pointer and catches a
    // moving highlight; these are the knobs for the whole module, so the
    // effect can be dialled back - or switched off with hoverScale: 1 and
    // sheenAlpha: 0 - in one place rather than across 86 card instances.
    //
    // Deliberately small. At 720px wide the card gains about 9px, which
    // registers as the card coming forward without shoving its neighbours
    // around or making the text visibly resample.
    readonly property real hoverScale: 1.012

    // Peak alpha of the specular band that tracks the pointer, and how far
    // it reaches to either side as a fraction of card width. Wide and faint:
    // tighter than this and it reads as a streak rather than a sheen.
    readonly property real sheenAlpha: 0.04
    readonly property real sheenSpread: 0.34

    // Opacity applied to a card body whose parent toggle is off. Kept here so
    // the "this section is inactive" signal is identical everywhere instead of
    // the 0.35 / 0.4 / 0.5 mix the pages had grown.
    readonly property real disabledOpacity: 0.38
}
