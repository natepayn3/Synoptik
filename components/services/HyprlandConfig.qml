import QtQuick

// Hyprland general/animations/input settings not already covered by
// AppearanceConfig (border color/thickness/rounding/blur/xray). Written into
// hypr_style.lua by Config.syncHyprlandBorders(), which regenerates that
// file from scratch on every change - see that function for why.
QtObject {
    id: hyprlandRoot

    property var configRef: null

    // --- GENERAL / LAYOUT ---
    property int hyprGapsIn: 5
    property string hyprLayoutMode: "dwindle" // "dwindle" | "master" | "scrolling"
    property bool hyprResizeOnBorder: false
    property bool hyprAllowTearing: false

    // --- ANIMATIONS ---
    property bool hyprAnimationsEnabled: true

    // --- INPUT ---
    property real hyprSensitivity: 0.0 // -1.0 .. 1.0, Hyprland's own range
    property int hyprFollowMouse: 1
    property bool hyprNaturalScroll: false

    function sync() {
        if (!configRef || !configRef.isLoaded) return
        configRef.syncHyprlandBorders()
        configRef.saveSettings()
    }

    onHyprGapsInChanged: sync()
    onHyprLayoutModeChanged: sync()
    onHyprResizeOnBorderChanged: sync()
    onHyprAllowTearingChanged: sync()
    onHyprAnimationsEnabledChanged: sync()
    onHyprSensitivityChanged: sync()
    onHyprFollowMouseChanged: sync()
    onHyprNaturalScrollChanged: sync()
}
