import QtQuick
import Quickshell

Item {
    id: root

    property color surfaceColor: "#1e1e2e"
    property color borderColor: "transparent"
    property real borderWidth: 0.0
    property real cornerRadius: 18.0
    property real smoothFactor: 16.0

    // Mode: "frame" (screen frame with inner cutout + bar + popout) or "bar" (floating bar + popout)
    property bool isScreenFrame: false

    // Screen frame inner cutout bounds
    property real frameLeft: 0
    property real frameRight: 0
    property real frameTop: 0
    property real frameBottom: 0

    // Geometry of the two merging boxes (Bar & Popout)
    property rect barRect: Qt.rect(0, 0, 0, 0)
    property rect popoutRect: Qt.rect(0, 0, 0, 0)
    property bool hasPopout: false

    ShaderEffect {
        anchors.fill: parent

        readonly property color uSurfaceColor: root.surfaceColor
        readonly property color uBorderColor: root.borderColor
        readonly property real uBorderWidth: root.borderWidth
        readonly property real uRadius: root.cornerRadius
        readonly property real uSmoothFactor: root.smoothFactor
        
        readonly property bool uIsScreenFrame: root.isScreenFrame
        readonly property vector4d uFramePads: Qt.vector4d(root.frameLeft, root.frameTop, root.frameRight, root.frameBottom)
        readonly property vector2d uScreenSize: Qt.vector2d(root.width, root.height)

        readonly property vector4d uBar: Qt.vector4d(root.barRect.x, root.barRect.y, root.barRect.width, root.barRect.height)
        readonly property vector4d uPopout: Qt.vector4d(root.popoutRect.x, root.popoutRect.y, root.popoutRect.width, root.popoutRect.height)
        readonly property bool uHasPopout: root.hasPopout

        fragmentShader: "
            #version 440
            layout(location = 0) in vec2 qt_TexCoord0;
            layout(location = 0) out vec4 fragColor;

            layout(std140, binding = 0) uniform buf {
                mat4 qt_Matrix;
                float qt_Opacity;
                vec4 uSurfaceColor;
                vec4 uBorderColor;
                float uBorderWidth;
                float uRadius;
                float uSmoothFactor;
                float uIsScreenFrame;
                vec4 uFramePads;
                vec2 uScreenSize;
                vec4 uBar;
                vec4 uPopout;
                float uHasPopout;
            };

            float sdBox(vec2 p, vec2 center, vec2 halfSize) {
                vec2 d = abs(p - center) - halfSize;
                return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
            }

            float sdRoundedBox(vec2 p, vec2 center, vec2 halfSize, float radius) {
                vec2 d = abs(p - center) - halfSize + vec2(radius);
                return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
            }

            // Circular smooth-minimum (Caelestia circular fillet)
            float smin(float a, float b, float k) {
                return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
            }

            // Circular smooth-maximum keeping 'a' razor-sharp (for outer frame edge)
            float smaxSharpA(float a, float b, float k) {
                float sm = min(-k, max(a, b)) + length(max(vec2(a, b) + vec2(k), vec2(0.0)));
                float blend = (sm - max(a, b)) * smoothstep(0.0, k * 0.5, -a);
                return max(a, b) + blend;
            }

            void main() {
                vec2 pixel = qt_TexCoord0 * uScreenSize;
                float mergedSdf = 1e10;

                // 1. Evaluate Bar
                if (uBar.z > 0.0 && uBar.w > 0.0) {
                    vec2 barCenter = uBar.xy + uBar.zw * 0.5;
                    vec2 barHalf = uBar.zw * 0.5;
                    float dBar = sdRoundedBox(pixel, barCenter, barHalf, uRadius);
                    mergedSdf = dBar;
                }

                // 2. Evaluate Popout & circular smin fillet into bar
                if (uHasPopout > 0.5 && uPopout.z > 0.0 && uPopout.w > 0.0) {
                    vec2 popCenter = uPopout.xy + uPopout.zw * 0.5;
                    vec2 popHalf = uPopout.zw * 0.5;
                    float dPopout = sdRoundedBox(pixel, popCenter, popHalf, uRadius);
                    mergedSdf = (mergedSdf < 1e9) ? smin(mergedSdf, dPopout, uSmoothFactor) : dPopout;
                }

                // 3. Evaluate Inverted Screen Frame (Donut Cutout with Circular Fillet)
                if (uIsScreenFrame > 0.5) {
                    // Outer bounding box (full screen, sharp outer edge)
                    vec2 outerCenter = uScreenSize * 0.5;
                    vec2 outerHalf = uScreenSize * 0.5;
                    float dOuter = sdBox(pixel, outerCenter, outerHalf) - 1.0;

                    // Inner workspace cutout (rounded rectangle cutout)
                    vec2 innerTL = vec2(uFramePads.x, uFramePads.y);
                    vec2 innerBR = uScreenSize - vec2(uFramePads.z, uFramePads.w);
                    vec2 innerSize = max(vec2(1.0), innerBR - innerTL);
                    vec2 innerCenter = innerTL + innerSize * 0.5;
                    vec2 innerHalf = innerSize * 0.5;
                    float dInner = sdRoundedBox(pixel, innerCenter, innerHalf, uRadius);

                    // Dynamic pocket sink for popouts penetrating the frame
                    if (uHasPopout > 0.5 && uPopout.z > 0.0 && uPopout.w > 0.0) {
                        vec2 pCtr = uPopout.xy + uPopout.zw * 0.5;
                        vec2 pHalf = uPopout.zw * 0.5;
                        float preOff = uSmoothFactor * (2.0 - sqrt(2.0)) * 0.5;

                        float inTop = innerCenter.y - innerHalf.y;
                        float inBot = innerCenter.y + innerHalf.y;
                        float inLeft = innerCenter.x - innerHalf.x;
                        float inRight = innerCenter.x + innerHalf.x;

                        float topPen = clamp(inTop - (pCtr.y + pHalf.y) - preOff, 0.0, uFramePads.y);
                        float botPen = clamp((pCtr.y - pHalf.y) - inBot - preOff, 0.0, uFramePads.w);
                        float leftPen = clamp(inLeft - (pCtr.x + pHalf.x) - preOff, 0.0, uFramePads.x);
                        float rightPen = clamp((pCtr.x - pHalf.x) - inRight - preOff, 0.0, uFramePads.z);

                        float hLat = max(abs(pixel.x - pCtr.x) - pHalf.x, 0.0);
                        float vLat = max(abs(pixel.y - pCtr.y) - pHalf.y, 0.0);

                        float s = uSmoothFactor * 2.0;
                        float sink = max(
                            max(topPen * smoothstep(s, 0.0, hLat), botPen * smoothstep(s, 0.0, hLat)),
                            max(leftPen * smoothstep(s, 0.0, vLat), rightPen * smoothstep(s, 0.0, vLat))
                        );
                        dInner -= sink;
                    }

                    // Inverted Frame with sharp outer edge and true circular inner arc fillet
                    float minThick = min(min(uFramePads.x, uFramePads.z), min(uFramePads.y, uFramePads.w));
                    float kFrame = clamp(min(uSmoothFactor, minThick - 1.0), 1.0, uSmoothFactor);
                    float dFrame = smaxSharpA(dOuter, -dInner, kFrame);

                    mergedSdf = smin(mergedSdf, dFrame, uSmoothFactor);
                }

                // Sub-pixel hardware derivative antialiasing (no stair-stepping)
                float fw = fwidth(mergedSdf);
                float alpha = 1.0 - smoothstep(-fw, fw, mergedSdf);

                if (alpha <= 0.001) {
                    discard;
                }

                vec4 col = uSurfaceColor;
                if (uBorderWidth > 0.0 && uBorderColor.a > 0.0) {
                    float borderMask = 1.0 - smoothstep(0.0, fw * 1.5, abs(mergedSdf + uBorderWidth * 0.5) - uBorderWidth * 0.5);
                    col = mix(col, uBorderColor, borderMask);
                }

                fragColor = vec4(col.rgb * alpha, alpha * col.a) * qt_Opacity;
            }
        "
    }
}
