#version 440

// Liquid entrance distortion for the lockscreen wallpaper.
//
// A ring-shaped disturbance expands from the centre and settles, so the
// background behaves like water that has been dropped into rather than a
// picture being blurred. Companion to blob.frag; baked the same way:
//
//   qsb --qt6 -o shaders/lockwave.frag.qsb shaders/lockwave.frag
//
// run from components/services/, whenever this file changes.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // 0..1 entrance progress, the same driver the QML side staggers off.
    float uProgress;
    // Peak displacement in texture units, scaled down by the envelope below.
    float uAmplitude;
    // Ring count across the surface.
    float uFrequency;
    // Aspect ratio (w/h), so the rings stay circular on a non-square screen
    // rather than stretching into ellipses.
    float uAspect;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;

    // Work in aspect-corrected space so distance is true distance.
    vec2 centred = uv - vec2(0.5);
    centred.x *= uAspect;
    float dist = length(centred);

    // The wavefront sweeps outward. Beyond the far corner there is nothing
    // left to disturb, so the front travels a little past it and stops.
    float front = uProgress * 0.85;

    // Two envelopes multiplied:
    //   - a band around the wavefront, so only the region the wave has just
    //     passed through is moving, not the whole screen at once;
    //   - a global decay, so the surface is still by the time the entrance
    //     animation ends and the resting image is pixel-exact.
    float band = exp(-28.0 * (dist - front) * (dist - front));
    float decay = 1.0 - smoothstep(0.55, 1.0, uProgress);
    float envelope = band * decay;

    // Radial displacement. sin() of (distance - front) keeps the crests
    // travelling with the wavefront instead of standing still.
    float phase = (dist - front) * uFrequency * 6.28318;
    float offset = sin(phase) * uAmplitude * envelope;

    vec2 dir = dist > 0.0001 ? centred / dist : vec2(0.0);
    dir.x /= uAspect;

    vec2 sampleUv = uv + dir * offset;

    // The displacement can push a sample outside the image, which would clamp
    // to a smeared edge pixel. Mirroring back keeps the border coherent.
    sampleUv = abs(sampleUv);
    sampleUv = mix(sampleUv, 2.0 - sampleUv, step(1.0, sampleUv));

    fragColor = texture(source, sampleUv) * qt_Opacity;
}
