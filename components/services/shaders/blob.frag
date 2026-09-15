#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 uSurfaceColor;
    vec4 uBorderColor;
    float uBorderWidth;
    float uBarRadius;
    float uPopoutRadius;
    float uSmoothFactor;
    vec2 uScreenSize;
    vec4 uBar;
    vec4 uPopout;
    float uHasPopout;
};

float sdRoundedBox(vec2 p, vec2 center, vec2 halfSize, float radius) {
    vec2 d = abs(p - center) - halfSize + vec2(radius);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
}

// Circular smooth-minimum (ported from Caelestia's blob.frag): the blend
// fillet is a true circular arc of radius k, tangent to both surfaces - not
// a polynomial/squircle interpolation. It deviates from min(a, b) only in
// the corner region where BOTH a < k and b < k, and is always <= min(a, b).
float smin(float a, float b, float k) {
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

void main() {
    vec2 pixel = qt_TexCoord0 * uScreenSize;

    vec2 barCenter = uBar.xy + uBar.zw * 0.5;
    vec2 barHalf = uBar.zw * 0.5;
    float dBar = sdRoundedBox(pixel, barCenter, barHalf, uBarRadius);

    float mergedSdf = dBar;

    if (uHasPopout > 0.5) {
        vec2 popCenter = uPopout.xy + uPopout.zw * 0.5;
        vec2 popHalf = uPopout.zw * 0.5;
        float dPopout = sdRoundedBox(pixel, popCenter, popHalf, uPopoutRadius);
        mergedSdf = smin(dBar, dPopout, uSmoothFactor);
    }

    // Sub-pixel hardware derivative antialiasing (no stair-stepping).
    float fw = fwidth(mergedSdf);
    float alpha = 1.0 - smoothstep(-fw, fw, mergedSdf);

    if (alpha <= 0.001) {
        discard;
    }

    // Border fix: a single one-sided threshold on mergedSdf/fw, the exact
    // values already used for alpha above - never an independent
    // abs()-based ring computed on the side. Whatever this field's local
    // behaviour is (including however smin has distorted it right at the
    // wing), the border tints in lock step with the silhouette instead of
    // drifting from it.
    vec3 col = uSurfaceColor.rgb;
    if (uBorderWidth > 0.0 && uBorderColor.a > 0.0) {
        float borderMask = smoothstep(-uBorderWidth - fw, -uBorderWidth + fw, mergedSdf);
        col = mix(col, uBorderColor.rgb, uBorderColor.a * borderMask);
    }

    fragColor = vec4(col * alpha, alpha * uSurfaceColor.a) * qt_Opacity;
}
