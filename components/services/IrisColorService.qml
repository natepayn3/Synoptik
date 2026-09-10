import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: irisService

    property var configRef: null

    // Safely embed an arbitrary string (wallpaper path) as a single fish argument.
    function fishQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function hexByte(v) {
        return Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0")
    }

    // customAccent/Config.accent both flow through as plain "#rrggbb"
    // strings elsewhere (see the Iris JSON parsing below and the stock
    // theme table), so this returns the same shape rather than a QML color
    // value - relying on implicit color-to-string coercion here would risk
    // an "#aarrggbb" mismatch against everything that expects "#rrggbb".
    function colorToHex(c) {
        return "#" + hexByte(c.r) + hexByte(c.g) + hexByte(c.b)
    }

    // WCAG relative luminance/contrast ratio - used to enforce a legibility
    // floor on Iris's text colors below, since Iris's own "fg"/"dim" picks
    // are only lightly contrast-aware and can land as low as ~1.5:1 against
    // its own "surface" (should be 4.5:1+ for body text, 3:1+ for secondary/
    // caption text - see ensureContrast).
    function srgbChannel(v) {
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
    }

    function relativeLuminance(c) {
        return 0.2126 * srgbChannel(c.r) + 0.7152 * srgbChannel(c.g) + 0.0722 * srgbChannel(c.b)
    }

    function contrastRatio(c1, c2) {
        let l1 = relativeLuminance(c1)
        let l2 = relativeLuminance(c2)
        return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05)
    }

    // Nudges candidateHex's HSL lightness away from bgHex - in whichever
    // direction it's already leaning, so a warm-toned candidate stays warm
    // rather than collapsing to flat black/white - until it clears minRatio
    // against bgHex, or until it hits a lightness clamp. Hue and saturation
    // are left alone, so this keeps Iris's actual color choice, it just
    // stops it from being unreadably close to the background.
    function ensureContrast(candidateHex, bgHex, minRatio) {
        let bg = Qt.color(bgHex)
        let c = Qt.color(candidateHex)
        if (contrastRatio(c, bg) >= minRatio) return candidateHex

        let hue = c.hslHue
        let sat = c.hslSaturation
        let light = c.hslLightness
        let direction = light >= bg.hslLightness ? 1 : -1

        for (let i = 0; i < 30; i++) {
            light = Math.max(0.03, Math.min(0.97, light + direction * 0.03))
            let candidate = Qt.hsla(hue, sat, light, 1.0)
            if (contrastRatio(candidate, bg) >= minRatio) return colorToHex(candidate)
            if (light <= 0.03 || light >= 0.97) break
        }
        // Ran out of room in that direction (bg itself is near black/white) -
        // pin to the extreme rather than return something that never met the floor.
        return colorToHex(Qt.hsla(hue, sat, direction > 0 ? 0.97 : 0.03, 1.0))
    }

    // Iris itself has no vibrance knob - it always hands back one fixed
    // reading of the wallpaper's accent color. "Subtle"/"Bold" are applied
    // here afterward, as an HSL saturation (and mild lightness) push on top
    // of that raw reading. "Medium" is Iris's own output, untouched, so it
    // stays the same as before this setting existed.
    function adjustAccentForIntensity(hexColor, intensity) {
        let c = Qt.color(hexColor)
        let sat = c.hslSaturation
        let light = c.hslLightness

        if (intensity === "subtle") {
            sat *= 0.45
            light += (0.55 - light) * 0.3
        } else if (intensity === "bold") {
            sat = Math.min(1.0, sat * 1.5)
            light += (light > 0.5 ? 0.08 : -0.08)
        }

        light = Math.max(0.15, Math.min(0.85, light))
        return colorToHex(Qt.hsla(c.hslHue, sat, light, 1.0))
    }

    property Process irisRunner: Process {
        id: runner
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let text = this.text ? this.text.trim() : ""
                    if (text.length > 0 && configRef) {
                        let match = text.match(/\{[\s\S]*\}/)
                        if (match) {
                            let jsonStr = match[0]

                            if (jsonStr.includes('"bg"') || jsonStr.includes('"surface"') || jsonStr.includes('"accent"')) {
                                let parsed = JSON.parse(jsonStr)

                                let baseCol = parsed.bg || "#12131a"
                                let panelCol = parsed.surface || "#1e202b"
                                let accentCol = irisService.adjustAccentForIntensity(parsed.accent || "#94a3b8", configRef.irisIntensity)

                                // Iris computes its own contrast-safe text pair per
                                // wallpaper (dark fg on a light bg, light fg on a
                                // dark one) - this is what was missing before: Iris
                                // colors were applied everywhere except text, so a
                                // light wallpaper kept the shell's fixed white text
                                // and washed out against its own light panel. Only
                                // fall back to the same luminance heuristic the
                                // stock theme table uses if a result is ever
                                // missing these keys.
                                // Iris's own fg/dim are only lightly contrast-aware
                                // (a real wallpaper measured at 1.56:1 for dim, 3.9:1
                                // for fg, against its own surface - both unreadable/
                                // marginal). ensureContrast enforces a floor without
                                // discarding Iris's actual color choice, and the two
                                // different floors keep fg/dim visually distinct from
                                // each other rather than both converging on the same
                                // corrected value.
                                let fallbackText = configRef.appearance.textColorsForBackground(panelCol)
                                let fgCol = irisService.ensureContrast(parsed.fg || fallbackText.main, panelCol, 4.5)
                                let dimCol = irisService.ensureContrast(parsed.dim || fallbackText.muted, panelCol, 3.0)

                                configRef.customBgBase = baseCol
                                configRef.customBgPanel = panelCol
                                configRef.customAccent = accentCol

                                configRef.bgBase = Qt.rgba(Qt.color(baseCol).r, Qt.color(baseCol).g, Qt.color(baseCol).b, configRef.shellOpacity)
                                configRef.bgPanel = Qt.rgba(Qt.color(panelCol).r, Qt.color(panelCol).g, Qt.color(panelCol).b, configRef.shellOpacity)
                                configRef.accent = accentCol
                                configRef.textMain = fgCol
                                configRef.textMuted = dimCol

                                configRef.syncHyprlandBorders()
                            }
                        }
                    }
                } catch (e) {
                    console.error("Failed to parse Iris JSON colors:", e)
                }
            }
        }
    }

    function applyIrisColors(filePath) {
        if (!configRef || !configRef.enableIris) return

        let rawPath = filePath || configRef.activeWallpaperPath

        if (!rawPath && configRef.wallpapers && configRef.wallpapers.length > 0) {
            rawPath = configRef.wallpapers[0]
        }

        if (!rawPath || rawPath === "") return

        let cleanPath = rawPath.replace(/^file:\/\//, "")
        let ext = cleanPath.split('.').pop().toLowerCase()
        let targetPath = cleanPath

        if (ext === "mp4" || ext === "webm") {
            let fileName = cleanPath.split('/').pop()
            let thumbName = fileName.replace(/[^a-zA-Z0-9]/g, "_") + ".png"
            targetPath = Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + thumbName
        }

        let cmd = "if not test -f " + fishQuote(targetPath) + "; ffmpeg -y -ss 00:00:00 -i " + fishQuote(cleanPath) + " -vframes 1 -vf 'scale=600:-1' " + fishQuote(targetPath) + " >/dev/null 2>&1; end; "
        cmd += "if test -f " + fishQuote(targetPath) + "; iris --json-only " + fishQuote(targetPath) + " 2>/dev/null; end"

        runner.command = ["fish", "-c", cmd]
        runner.running = false
        runner.running = true
    }
}
