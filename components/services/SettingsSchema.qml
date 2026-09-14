import QtQuick

// The controllable vocabulary of Synoptik's settings: which keys can be set
// from outside the Settings UI, what each one means in plain language, and
// what counts as a legal value.
//
// This table is deliberately a curated subset of Config.persistedKeys rather
// than all ~190 of them. Positions, per-screen maps, window sizes, cached
// model lists and other machine-written state are settable by the UI that
// understands them and by nothing else - what belongs here is the handful of
// settings a person would ask for out loud.
//
// It does three jobs at once, which is why the descriptions are written for a
// reader rather than as code comments:
//   1. validation for Config.setSetting() (and therefore the settings IPC),
//   2. the vocabulary handed to the assistant backend, verbatim,
//   3. eventually, enough metadata to generate Settings rows from.
//
// Every key here must also appear in Config.persistedKeys or the change would
// apply and then vanish on restart; Config.validatePersistedKeys() checks that
// on startup and says so loudly.
QtObject {
    id: schemaRoot

    // hints: extra words a person might use for this setting that appear nowhere
    //   in its name or description - "cramped" for cardMargin, "see-through"
    //   for shellOpacity. Matched against, never shown.
    // type: bool | int | real | enum | color | string
    // requires: names another key that must be true for this one to have any
    //   visible effect. Setting a gated key on its own is legal and persists -
    //   it just does nothing yet - so this drives a warning rather than a
    //   rejection, and tells the assistant to send the gate in the same block.
    // Ranges mirror the sliders on the matching Settings page - a value the UI
    // cannot produce is not a value this should accept either.
    readonly property var entries: ({
        // --- BAR ---
        "barPosition": { hints: "move side edge top bottom left right", type: "enum", values: ["top", "bottom", "left", "right"], group: "bar",
            desc: "Which screen edge the bar occupies" },
        "barFrameStyle": { hints: "shape island floating frame pill", type: "enum", values: ["floating", "island", "edge", "screen"], group: "bar",
            desc: "Bar shape - floating = detached capsule with a gap around it; island = short pill centred on one edge; edge = full-width panel sitting flush against the edge; screen = thin frame running around the whole screen" },
        "autoHideBar": { hints: "hide hidden away out of the way", type: "bool", group: "bar",
            desc: "Hide the bar until the pointer reaches its edge" },
        "showScreenFrame": { type: "bool", group: "bar",
            desc: "Draw an accent frame around the screen edge" },
        "enableHoverPeek": { type: "bool", group: "bar",
            desc: "Let bar modules preview their panel on hover instead of requiring a click" },

        // --- SHAPE & SURFACE ---
        "surfaceRadius": { hints: "corners rounded round sharp square", type: "real", min: 0, max: 40, group: "look",
            desc: "Corner rounding of the bar and every panel, in pixels" },
        "borderThickness": { hints: "outline edge line", type: "int", min: 0, max: 10, group: "look",
            desc: "Accent border thickness, in pixels; 0 removes borders" },
        "cardMargin": { hints: "spacing padding gap tighter looser cramped", type: "real", min: 0, max: 32, group: "look",
            desc: "Gap between cards inside panels, in pixels" },
        "shellOpacity": { hints: "transparent transparency see-through solid opaque", type: "real", min: 0.1, max: 1.0, group: "look",
            desc: "Opacity of every shell surface, 0.1 (nearly invisible) to 1.0 (solid)" },
        "enableBlur": { hints: "blurry frosted glass", type: "bool", group: "look",
            desc: "Blur the desktop behind shell surfaces" },
        "enableXray": { hints: "see through wallpaper showing", type: "bool", group: "look",
            desc: "Let the wallpaper show through shell surfaces" },
        "animateGradient": { hints: "moving animated shifting", type: "bool", group: "look",
            desc: "Animate the border colour between the accent and its lighter partner" },
        "showWatermarks": { type: "bool", group: "look",
            desc: "Show the decorative watermark shapes inside panels" },
        "bounceWatermarks": { type: "bool", group: "look",
            desc: "Let watermark shapes drift around instead of sitting still" },

        // --- COLOUR & TYPE ---
        "useCustomColors": { hints: "colour color theme custom", type: "bool", group: "colour",
            desc: "Use the custom colours below instead of the selected theme" },
        "customBgBase": { type: "color", group: "colour", requires: "useCustomColors",
            desc: "Custom background colour, as #rrggbb; needs useCustomColors" },
        "customBgPanel": { type: "color", group: "colour", requires: "useCustomColors",
            desc: "Custom panel colour, as #rrggbb; needs useCustomColors" },
        "customAccent": { hints: "highlight colour color theme", type: "color", group: "colour", requires: "useCustomColors",
            desc: "Custom accent colour, as #rrggbb; needs useCustomColors" },
        "enableIris": { hints: "match wallpaper colour color automatic theme", type: "bool", group: "colour",
            desc: "Derive the whole palette from the current wallpaper, with a contrast floor applied" },
        "irisIntensity": { type: "enum", values: ["subtle", "medium", "bold"], group: "colour",
            desc: "How vivid the wallpaper-derived accent is pushed" },
        "fontScaleIndex": { hints: "text size bigger smaller font readable", type: "int", min: 0, max: 2, group: "colour",
            desc: "Global text size: 0 small, 1 normal, 2 large" },
        "sysFont": { hints: "font typeface", type: "string", group: "colour",
            desc: "Font family used across the shell; empty means the default" },
        "nativeFontRendering": { type: "bool", group: "colour",
            desc: "Render text with the native rasteriser (sharper) rather than Qt's (smoother)" },

        // --- NIGHT MODE & SHADERS ---
        "nightModeEnabled": { hints: "warm warmer orange eyes night evening blue light", type: "bool", group: "night",
            desc: "Warm the screen colour temperature now" },
        "nightModeAuto": { type: "bool", group: "night",
            desc: "Turn night mode on and off on a schedule" },
        "nightModeScheduleStart": { type: "int", min: 0, max: 23, group: "night",
            desc: "Hour night mode starts, 24-hour clock" },
        "nightModeScheduleEnd": { type: "int", min: 0, max: 23, group: "night",
            desc: "Hour night mode ends, 24-hour clock" },
        "pixelShaderEnabled": { hints: "retro crt pixel filter effect", type: "bool", group: "night",
            desc: "Apply a full-screen compositor shader" },
        "pixelShaderMode": { type: "enum", values: ["pixelate", "crt", "mac1bit"], group: "night",
            desc: "Which full-screen shader: chunky pixels, arcade CRT, or 1-bit Macintosh" },

        // --- DESKTOP WIDGETS ---
        "showDesktopClock": { hints: "time clock", type: "bool", group: "widgets", desc: "Show the desktop clock widget" },
        "clockStyle": { type: "enum", values: ["digital", "analog", "modern"], group: "widgets",
            desc: "Desktop clock face" },
        "clockScale": { type: "real", min: 0.5, max: 3.0, group: "widgets",
            desc: "Desktop clock size multiplier" },
        "clockShowSeconds": { type: "bool", group: "widgets", desc: "Show seconds on the desktop clock" },
        "clockUse12Hour": { type: "bool", group: "widgets", desc: "12-hour desktop clock instead of 24-hour" },
        "clockShowAmPm": { type: "bool", group: "widgets", desc: "Show AM/PM on the desktop clock" },
        "showDesktopSysInfo": { type: "bool", group: "widgets", desc: "Show the system info / fetch widget" },
        "sysInfoScale": { type: "real", min: 0.5, max: 3.0, group: "widgets",
            desc: "System info widget size multiplier" },
        "showDesktopCava": { hints: "visualizer visualiser music audio bars spectrum", type: "bool", group: "widgets", desc: "Show the audio visualiser widget" },
        "cavaStyle": { type: "enum", values: ["bars", "mirrored", "wave", "radial"], group: "widgets",
            desc: "Audio visualiser shape" },
        "cavaColorMode": { type: "enum", values: ["accent", "gradient", "rainbow", "solid"], group: "widgets",
            desc: "How the audio visualiser is coloured" },
        "showAppDock": { hints: "dock icons apps launcher shortcuts", type: "bool", group: "widgets", desc: "Show the app dock of pinned launcher apps" },
        "appDockOrientation": { type: "enum", values: ["horizontal", "vertical"], group: "widgets",
            desc: "App dock direction" },
        "appDockScale": { type: "real", min: 0.5, max: 3.0, group: "widgets",
            desc: "App dock size multiplier" },
        "showMascot": { hints: "mascot character pet gif", type: "bool", group: "widgets", desc: "Show the desktop mascot" },
        "showDesktopMediaCard": { type: "bool", group: "widgets", desc: "Show the detached now-playing card" },
        "showAssistant": { type: "bool", group: "widgets", desc: "Show the assistant widget" },
        "showOsk": { type: "bool", group: "widgets", desc: "Show the on-screen keyboard" },
        "snapDesktopWidgets": { hints: "snap grid align", type: "bool", group: "widgets",
            desc: "Snap desktop widgets to a grid while dragging them" },

        // --- AUDIO REACTIVITY ---
        "ambientBreatheEnabled": { hints: "pulse beat music react bounce", type: "bool", group: "ambient",
            desc: "Let the whole shell pulse gently in time with the music's bass" },
        "ambientBreatheIntensity": { type: "real", min: 0.0, max: 1.0, group: "ambient",
            desc: "How strongly the shell pulses with the bass, 0 to 1" },

        // --- SOUND ---
        "playWindowSounds": { type: "bool", group: "sound", desc: "Play a sound when panels open and close" },
        "playNotificationSounds": { hints: "sound noise beep alert", type: "bool", group: "sound", desc: "Play a sound when a notification arrives" },

        // --- SCREENSAVER ---
        "showScreensaver": { hints: "screensaver idle", type: "bool", group: "screensaver", desc: "Start the screensaver now" },
        "screensaverMode": { type: "enum", values: ["text", "dvd", "activate"], group: "screensaver",
            desc: "Screensaver content: custom text, bouncing DVD logo, or an Activate Linux parody" },
        "screensaverText": { type: "string", group: "screensaver", desc: "Text the screensaver bounces around" },

        // --- WALLPAPER ---
        "slideshowActive": { hints: "rotate cycle shuffle wallpapers automatically", type: "bool", group: "wallpaper", desc: "Rotate through wallpapers automatically" },
        "slideshowMinutes": { type: "int", min: 1, max: 1440, group: "wallpaper",
            desc: "Minutes between wallpaper changes while the slideshow runs" },
        "wallpaperTransitionType": { type: "enum", values: ["fade", "wipe"], group: "wallpaper",
            desc: "How one wallpaper gives way to the next" },
        "enableWallpaperParallax": { type: "bool", group: "wallpaper",
            desc: "Drift the wallpaper as workspaces and the pointer move" },

        // --- ASSISTANT ---
        "assistantBackend": { type: "enum", values: ["claude", "codex", "gemini", "ollama"], group: "assistant",
            desc: "Which assistant CLI backend answers" }
    })

    // --- ACTIONS ---
    // Things worth asking for that are not a settings write: they run a
    // function rather than assigning a property, and their argument is a
    // choice from a set the shell computes at runtime rather than a fixed
    // enum. Same discipline as the settings above - a fixed name, a documented
    // argument, and no free-form command anywhere in the path.
    readonly property var actions: ({
        "wallpaper": { arg: "colour or subject",
            desc: "Change the desktop wallpaper to one matching the colour or subject given." }
    })

    readonly property var actionNames: Object.keys(actions)

    // Where the shell falls back when a request matches nothing by wording -
    // "make it cosier", "too much going on". These are the settings a person is
    // most likely to have meant, and a dozen plausible options beats sixty
    // unsorted ones for a model that has to pick blind either way.
    readonly property var defaultTargets: [
        "barPosition", "barFrameStyle", "autoHideBar", "surfaceRadius", "cardMargin",
        "shellOpacity", "enableBlur", "customAccent", "useCustomColors", "enableIris",
        "fontScaleIndex", "wallpaper"
    ]
    function hasAction(name) { return actions.hasOwnProperty(name) }

    readonly property var keys: Object.keys(entries)

    function has(key) { return entries.hasOwnProperty(key) }
    function entry(key) { return has(key) ? entries[key] : null }

    // Turns whatever arrived - always a string over IPC, possibly already typed
    // from a QML caller - into the value this key actually holds. `current` is
    // passed in so "toggle" can work on booleans without the schema needing a
    // way to read live config.
    //
    // Returns { ok: true, value } or { ok: false, error } with a message that
    // names the legal values, since the caller on the other end may well be a
    // language model that can correct itself given one.
    function coerce(key, raw, current) {
        let e = entry(key)
        if (!e) return { ok: false, error: "unknown setting \"" + key + "\"" }

        let text = String(raw).trim()

        if (e.type === "bool") {
            let lowered = text.toLowerCase()
            if (lowered === "toggle") return { ok: true, value: !current }
            if (["true", "1", "on", "yes", "enable", "enabled"].indexOf(lowered) >= 0) return { ok: true, value: true }
            if (["false", "0", "off", "no", "disable", "disabled"].indexOf(lowered) >= 0) return { ok: true, value: false }
            return { ok: false, error: key + " expects true or false (got \"" + text + "\")" }
        }

        if (e.type === "int" || e.type === "real") {
            let num = Number(text)
            if (text === "" || isNaN(num)) return { ok: false, error: key + " expects a number (got \"" + text + "\")" }
            if (e.type === "int") num = Math.round(num)
            if (num < e.min || num > e.max) {
                return { ok: false, error: key + " must be between " + e.min + " and " + e.max + " (got " + num + ")" }
            }
            return { ok: true, value: num }
        }

        if (e.type === "enum") {
            let match = e.values.find(v => v.toLowerCase() === text.toLowerCase())
            if (!match) {
                return { ok: false, error: key + " expects one of: " + e.values.join(", ") + " (got \"" + text + "\")" }
            }
            return { ok: true, value: match }
        }

        if (e.type === "color") {
            if (!/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(text)) {
                return { ok: false, error: key + " expects a hex colour like #1e202b (got \"" + text + "\")" }
            }
            return { ok: true, value: text }
        }

        return { ok: true, value: text }
    }
}
