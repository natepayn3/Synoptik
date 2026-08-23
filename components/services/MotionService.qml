import QtQuick

QtObject {
    id: root

    // --- CURVE BEZIER CONTROL POINTS ---
    // Multi-segment / Single-segment Cubic Bezier tuples: [c1x, c1y, c2x, c2y, endX, endY, ...]
    readonly property var expressiveFastSpatialPoints: [0.42, 1.67, 0.21, 0.9, 1.0, 1.0]
    readonly property var expressiveDefaultSpatialPoints: [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
    readonly property var expressiveSlowSpatialPoints: [0.39, 1.29, 0.35, 0.98, 1.0, 1.0]

    readonly property var expressiveFastEffectsPoints: [0.31, 0.94, 0.34, 1.0, 1.0, 1.0]
    readonly property var expressiveDefaultEffectsPoints: [0.34, 0.8, 0.34, 1.0, 1.0, 1.0]
    readonly property var expressiveSlowEffectsPoints: [0.34, 0.88, 0.34, 1.0, 1.0, 1.0]

    readonly property var emphasizedPoints: [0.05, 0.0, 0.1333, 0.06, 0.1667, 0.4, 0.2083, 0.82, 0.25, 1.0, 1.0, 1.0]
    readonly property var emphasizedAccelPoints: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    readonly property var emphasizedDecelPoints: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property var standardPoints: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]

    // --- DURATION TOKENS (ms) ---
    readonly property int durationFastSpatial: 350
    readonly property int durationDefaultSpatial: 480
    readonly property int durationSlowSpatial: 650

    readonly property int durationFastEffects: 150
    readonly property int durationDefaultEffects: 200
    readonly property int durationSlowEffects: 300

    readonly property int durationSmall: 200
    readonly property int durationNormal: 400
    readonly property int durationLarge: 600
}
