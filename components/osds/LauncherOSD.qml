import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import ".."

Item {
    id: osdRoot

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    // Static bounds to prevent UnifiedSurface evaluation loops (see NotificationOSD)
    implicitWidth: mainLayout.implicitWidth + (cardMargin * 2)
    implicitHeight: mainLayout.implicitHeight + (cardMargin * 2)

    // --- MODE / QUERY STATE ---
    // "apps" (default) | "files" (# prefix) | "ipc" (> prefix, also settings
    // sections) | "emoji" (: prefix) | "wallpaper" (~ prefix) | "clipboard"
    // (^ prefix) | "calc" (auto-detected math)
    property string searchMode: "apps"
    property string queryText: ""
    property var filteredApps: []
    // "Browse apps" toggle - AppLauncher.qml's whole reason to exist was
    // showing the full app list with an empty query; this reuses the exact
    // same result rows/filtering instead of a second list implementation.
    property bool browsingAllApps: false

    // --- APP PINS (ported from AppLauncher.qml, same cache file so existing
    // pins carry over) ---
    property string pinFilePath: ""
    property var localPins: []

    FileView {
        id: pinCacheReader
        path: osdRoot.pinFilePath
        atomicWrites: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: osdRoot.localPins = []
        onTextChanged: {
            let cleanText = text().trim();
            if (!cleanText || cleanText === "[]") return;
            try {
                let parsed = JSON.parse(cleanText);
                if (parsed && parsed.pins) {
                    osdRoot.localPins = parsed.pins;
                    if (osdRoot.searchMode === "apps") osdRoot.updateModel();
                }
            } catch(e) {}
        }
    }

    function isAppPinned(app) {
        if (!app) return false;
        let pins = osdRoot.localPins;
        if (!pins || pins.length === 0) return false;
        let appId = app.id || "";
        return pins.includes(appId) || pins.some(p => p.endsWith("/" + appId + ".desktop") || p === appId);
    }

    function togglePin(app) {
        if (!app || !app.id) return;
        let appId = app.id;
        let currentPins = osdRoot.localPins.slice();
        let idx = currentPins.findIndex(p => p === appId || p.endsWith("/" + appId + ".desktop"));
        if (idx !== -1) {
            currentPins.splice(idx, 1);
        } else {
            currentPins.push(appId);
        }
        osdRoot.localPins = currentPins;
        osdRoot.updateModel();

        // Was an execDetached `sh -c "echo '<json>' > ~/.cache/..."`: not
        // atomic, and the payload was hand-escaped into a shell string. The
        // FileView above writes the same file atomically, and AppDock picks the
        // change up through its own watchChanges.
        pinCacheReader.setText(JSON.stringify({ "pins": currentPins }, null, 2));
    }
    property var filteredFiles: []
    property var filteredCommands: []
    property var filteredWallpapers: []
    property var filteredClipboard: []
    property var allClipboardItems: []

    // Mirrors Wallpaper.qml's getThumbPath - same cache convention, so
    // thumbnails preloaded by WallpaperConfig.qml's thumbPreloader are
    // reused here without any new generation step.
    function wallpaperThumbPath(filePath) {
        if (!filePath) return ""
        let clean = (typeof filePath === "string" ? filePath : filePath.toString()).replace(/^file:\/\//, "")
        let fileName = clean.split('/').pop()
        let baseName = fileName.replace(/\.[^/.]+$/, "")
        return Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + baseName + ".jpg"
    }

    readonly property int wallpaperGridColumns: 4
    readonly property int wallpaperCellWidth: 150
    readonly property int wallpaperCellHeight: 94

    // The clipboard list keeps its own selection (clipboardListView, declared
    // further down) rather than sharing resultList's - the preview pane needs
    // to read "whatever's selected" from plain property bindings, and ids
    // resolve file-wide in QML so this is safe to declare before that id exists.
    readonly property var clipboardCurrentItem: (osdRoot.searchMode === "clipboard"
        && clipboardListView.currentIndex >= 0
        && clipboardListView.currentIndex < osdRoot.currentResults.length)
        ? osdRoot.currentResults[clipboardListView.currentIndex] : null

    // A file-manager "copy" (Nautilus etc.) lands in cliphist as the plain
    // path, indistinguishable from ordinary copied text at the parsing stage
    // in clipboardFetchProc - this is what tells the preview pane to show
    // file details instead of just echoing the path back as "TEXT".
    function looksLikeFilePath(text) {
        if (!text) return false
        let t = ("" + text).trim()
        if (t.indexOf("\n") !== -1) return false
        return t.startsWith("/") || t.startsWith("file://")
    }

    readonly property bool clipboardCurrentIsFile: osdRoot.clipboardCurrentItem !== null
        && osdRoot.looksLikeFilePath(osdRoot.clipboardCurrentItem.previewText)

    function clipboardFileBasename(text) {
        let clean = ("" + text).replace(/^file:\/\//, "").trim()
        let parts = clean.split("/")
        return parts[parts.length - 1] || clean
    }

    // Row icon is a synchronous extension guess (no stat round-trip needed
    // just to draw the list) - the preview pane's mime type from the stat
    // script is the authoritative one.
    function clipboardRowIcon(item) {
        if (!item) return "description"
        if (item.isImage) return "image"
        if (!osdRoot.looksLikeFilePath(item.previewText)) return "description"
        let clean = osdRoot.clipboardFileBasename(item.previewText).toLowerCase()
        if (/\.(mp4|webm|mkv|mov|avi)$/.test(clean)) return "movie"
        if (/\.(mp3|wav|flac|ogg|m4a)$/.test(clean)) return "audiotrack"
        if (/\.pdf$/.test(clean)) return "picture_as_pdf"
        if (/\.(zip|tar|gz|7z|rar|xz)$/.test(clean)) return "folder_zip"
        if (/\.(lua|py|js|ts|qml|sh|c|cpp|rs|go|java|html|css|json|yaml|yml|toml)$/.test(clean)) return "code"
        return "insert_drive_file"
    }

    function clipboardRowLabel(item) {
        if (!item) return ""
        if (osdRoot.looksLikeFilePath(item.previewText)) return osdRoot.clipboardFileBasename(item.previewText)
        return item.previewText
    }

    function formatFileSize(bytes) {
        if (bytes === undefined || bytes === null) return ""
        if (bytes < 1024) return bytes + " B"
        let units = ["KB", "MB", "GB", "TB"]
        let val = bytes
        let i = -1
        do { val /= 1024; i++ } while (val >= 1024 && i < units.length - 1)
        return val.toFixed(1) + " " + units[i]
    }

    function formatModTime(epochSeconds) {
        if (!epochSeconds) return ""
        return Qt.formatDateTime(new Date(epochSeconds * 1000), "MMM d, yyyy · h:mm AP")
    }

    // --- CLIPBOARD FILE STAT (for entries that look like a copied file) ---
    // Path is passed as a process argument, never embedded in the script
    // text, same rule as fileSearchScript below.
    readonly property string clipboardStatScript: `
import sys, os, json, subprocess

path = sys.argv[1]
result = {"exists": False}
if os.path.exists(path):
    st = os.stat(path)
    result["exists"] = True
    result["isDir"] = os.path.isdir(path)
    result["size"] = st.st_size
    result["mtime"] = st.st_mtime
    try:
        mime = subprocess.run(["file", "--mime-type", "-b", path], capture_output=True, text=True, timeout=2).stdout.strip()
    except Exception:
        mime = ""
    result["mime"] = mime
print(json.dumps(result))
`

    property var clipboardFileInfo: null

    Process {
        id: clipboardStatProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    osdRoot.clipboardFileInfo = JSON.parse(this.text.trim())
                } catch (e) {
                    osdRoot.clipboardFileInfo = null
                }
            }
        }
    }

    onClipboardCurrentItemChanged: {
        let item = osdRoot.clipboardCurrentItem
        if (item && osdRoot.looksLikeFilePath(item.previewText)) {
            osdRoot.clipboardFileInfo = null
            let cleanPath = item.previewText.replace(/^file:\/\//, "").trim()
            clipboardStatProc.command = ["python3", "-c", osdRoot.clipboardStatScript, cleanPath]
            clipboardStatProc.running = false
            clipboardStatProc.running = true
        } else {
            osdRoot.clipboardFileInfo = null
        }
    }

    // --- EMOJI & GLYPH STATE ---
    // Fifth launcher mode, on the ":" prefix (the convention everywhere from
    // Slack to GitHub). The launcher already had mode switching for
    // apps/files/commands/calc, so this is a mode rather than a new surface.
    //
    // "Glyph" is the other half: the dataset carries typographic marks people
    // can't type directly - arrows, mathematical operators, currency, the Mac
    // modifier keys, Greek - alongside the emoji.
    property var emojiData: []
    property var filteredEmoji: []

    readonly property int emojiGridColumns: 10
    readonly property int emojiCellSize: 52

    // Qt's QML `font` value type exposes `family`, not `families`, so a
    // fallback chain can't be declared inline - pick the first emoji face that
    // is actually installed instead. Naming one unconditionally renders tofu
    // on any machine without it.
    //
    // Falling back to sysFont is not a failure case: the Glyphs half of the
    // dataset (arrows, mathematical operators, currency, Greek) renders fine in
    // a normal text face, and fontconfig will still substitute for emoji
    // codepoints if anything on the system covers them.
    readonly property string emojiFontFamily: {
        let avail = Qt.fontFamilies()
        let prefs = ["Noto Color Emoji", "Apple Color Emoji", "Segoe UI Emoji",
                     "Twemoji", "JoyPixels", "OpenMoji", "Noto Emoji"]
        for (let i = 0; i < prefs.length; i++) {
            if (avail.indexOf(prefs[i]) !== -1) return prefs[i]
        }
        return Config.sysFont
    }

    FileView {
        id: emojiDataFile
        path: Config.shellDir + "/assets/emoji.json"
        printErrors: false
        onLoaded: {
            try {
                osdRoot.emojiData = JSON.parse(emojiDataFile.text())
            } catch (e) {
                console.error("Could not parse emoji.json:", e)
                osdRoot.emojiData = []
            }
            if (osdRoot.searchMode === "emoji") osdRoot.updateModel()
        }
    }

    // Most-recently-used, persisted through Config so the picker is useful on
    // the second use rather than making you retype the same search.
    function recordEmojiUse(ch) {
        let recents = (Config.emojiRecents || []).slice()
        let idx = recents.indexOf(ch)
        if (idx !== -1) recents.splice(idx, 1)
        recents.unshift(ch)
        if (recents.length > 40) recents.length = 40
        Config.emojiRecents = recents
        Config.saveSettings()
    }

    function emojiEntryFor(ch) {
        for (let i = 0; i < osdRoot.emojiData.length; i++) {
            if (osdRoot.emojiData[i].c === ch) return osdRoot.emojiData[i]
        }
        return null
    }

    // Ranked rather than a flat filter: an exact name match has to beat a
    // substring hit, or searching "fire" buries the actual fire behind
    // firecracker and fire extinguisher.
    function searchEmoji(query) {
        let q = (query || "").trim().toLowerCase()

        if (q === "") {
            let out = []
            let seen = new Set()
            let recents = Config.emojiRecents || []
            for (let i = 0; i < recents.length; i++) {
                let e = osdRoot.emojiEntryFor(recents[i])
                if (e && !seen.has(e.c)) { out.push(e); seen.add(e.c) }
            }
            // Fill the rest of the grid with the default browse set, deduped
            // against recents - otherwise picking a single emoji shrinks the
            // whole grid down to just that one entry on the next open.
            let smileys = osdRoot.emojiData.filter(e => e.g === "Smileys")
            for (let i = 0; i < smileys.length && out.length < 60; i++) {
                if (!seen.has(smileys[i].c)) { out.push(smileys[i]); seen.add(smileys[i].c) }
            }
            return out
        }

        let scored = []
        for (let i = 0; i < osdRoot.emojiData.length; i++) {
            let e = osdRoot.emojiData[i]
            let name = e.n.toLowerCase()
            let score = -1

            if (name === q) score = 0
            else if (name.startsWith(q)) score = 1
            else if ((" " + name).includes(" " + q)) score = 2   // word-start
            else if (name.includes(q)) score = 3
            else if (e.k && e.k.includes(q)) score = 4

            if (score >= 0) scored.push({ e: e, s: score, l: name.length })
        }

        // Shorter names first within a tier - "Fire" over "Fire Engine".
        scored.sort((a, b) => (a.s - b.s) || (a.l - b.l))
        return scored.slice(0, 200).map(x => x.e)
    }

    // --- CALCULATOR STATE ---
    property string calcResultText: ""
    property bool calcValid: false

    readonly property var currentResults: {
        if (searchMode === "files") return filteredFiles
        if (searchMode === "ipc") return filteredCommands
        if (searchMode === "emoji") return filteredEmoji
        if (searchMode === "wallpaper") return filteredWallpapers
        if (searchMode === "clipboard") return filteredClipboard
        if (searchMode === "calc") return []
        return filteredApps
    }

    readonly property string modeBadge: {
        if (searchMode === "files") return "FILES"
        if (searchMode === "ipc") return "COMMANDS"
        if (searchMode === "emoji") return "EMOJI"
        if (searchMode === "wallpaper") return "WALLPAPERS"
        if (searchMode === "clipboard") return "CLIPBOARD"
        if (searchMode === "calc") return "CALC"
        return ""
    }

    readonly property string modeIcon: {
        if (searchMode === "files") return "folder_open"
        if (searchMode === "ipc") return "terminal"
        if (searchMode === "emoji") return "mood"
        if (searchMode === "wallpaper") return "wallpaper"
        if (searchMode === "clipboard") return "content_paste"
        if (searchMode === "calc") return "calculate"
        return "search"
    }

    readonly property string modePlaceholder: {
        if (searchMode === "files") return "Search files..."
        if (searchMode === "ipc") return "Search commands..."
        if (searchMode === "emoji") return "Search emoji & symbols..."
        if (searchMode === "wallpaper") return "Search wallpapers..."
        if (searchMode === "clipboard") return "Search clipboard history..."
        return "Search apps..."
    }

    // --- RESULTS AREA SIZING ---
    // Narrow (just the hint/status line) until there's an actual list to show,
    // then grows to fit up to maxVisibleRows before the list scrolls internally.
    readonly property int resultRowHeight: 56
    readonly property int maxVisibleRows: 5
    readonly property real resultsAreaHeight: {
        if (searchMode === "calc") return 68
        if (searchMode === "emoji") {
            // The emoji grid shows results for an empty query too (recents),
            // so it sizes off the result count rather than whether anything
            // has been typed.
            if (currentResults.length === 0) return 52
            let rows = Math.ceil(currentResults.length / emojiGridColumns)
            return Math.min(rows, 4) * emojiCellSize + 44
        }
        if (searchMode === "wallpaper") {
            if (currentResults.length === 0) return 52
            let rows = Math.ceil(currentResults.length / wallpaperGridColumns)
            return Math.min(rows, 2) * wallpaperCellHeight + 44
        }
        // Fixed rather than sized off row count - the right-hand preview
        // pane needs real room for an image regardless of how many/few
        // entries are in the list.
        if (searchMode === "clipboard") return currentResults.length === 0 ? 52 : 320
        if ((searchInput.text === "" && !browsingAllApps) || currentResults.length === 0) return 52
        return Math.min(currentResults.length, maxVisibleRows) * resultRowHeight + 16
    }

    // --- STATIC IPC COMMAND REGISTRY ---
    // Mirrors the IpcHandler targets/functions registered in shell.qml + Config.qml
    readonly property var ipcCommands: [
        { target: "settings",          fn: "toggle",     name: "Settings",          icon: "build" },
        { target: "wallpaper",         fn: "toggle",     name: "Wallpaper Picker",  icon: "wall_art" },
        { target: "workspaceoverview", fn: "toggle",     name: "Workspace Overview", icon: "select_window_2" },
        { target: "power",             fn: "toggle",     name: "Power Menu",        icon: "electrical_services" },
        { target: "clipboard",         fn: "toggle",     name: "Clipboard Manager", icon: "content_paste" },
        { target: "launcherosd",       fn: "emoji",      name: "Emoji & Symbols",   icon: "mood" },
        { target: "recorder",          fn: "toggle",     name: "Screen Recorder",   icon: "videocam" },
        { target: "mirror",            fn: "toggle",     name: "Camera Mirror",     icon: "photo_camera" },
        { target: "satty",             fn: "screenshot", name: "Take Screenshot (Satty)",   icon: "crop" },
        { target: "lockscreen",        fn: "lock",       name: "Lock Session",              icon: "lock" },
        { target: "screensaver",       fn: "start",      name: "Start Screensaver",         icon: "hourglass_empty" },
        { target: "screensaver",       fn: "stop",       name: "Stop Screensaver",          icon: "hourglass_disabled" },
        { target: "shader",            fn: "toggle",     name: "Retro Shader",              icon: "videogame_asset" }
    ]

    // Mirrors Settings.qml's sectionCatalog (name/icon/keywords only - id is
    // what Config.lastSettingsSection needs to jump straight to a section).
    // Kept as a separate array from ipcCommands rather than merged in because
    // activation is different (set a section + open Settings, not an IPC call).
    readonly property var settingsSections: [
        { sectionId: 0,  name: "Display",          icon: "aspect_ratio",    group: "VISUALS",      keywords: "monitor resolution refresh rate scale rotate rotation position arrangement hidpi screen vrr" },
        { sectionId: 16, name: "Bar",              icon: "dock",            group: "VISUALS",      keywords: "panel taskbar position top bottom left right autohide floating island frame height margin module" },
        { sectionId: 1,  name: "Appearance",       icon: "palette",         group: "VISUALS",      keywords: "theme color colour accent blur transparency opacity xray border gradient watermark iris night mode dark corner radius" },
        { sectionId: 17, name: "Workspaces",       icon: "view_carousel",   group: "VISUALS",      keywords: "workspace indicator style glow scroll tooltip special overview" },
        { sectionId: 2,  name: "Typography",       icon: "match_case",      group: "VISUALS",      keywords: "font family size scale text rendering antialias" },
        { sectionId: 3,  name: "Wallpaper",        icon: "wallpaper",       group: "VISUALS",      keywords: "background image slideshow parallax wallhaven transition swww awww" },
        { sectionId: 12, name: "Icons",            icon: "account_circle",  group: "VISUALS",      keywords: "icon glyph override module pin order material symbol" },
        { sectionId: 20, name: "Retro Shader",     icon: "videogame_asset", group: "VISUALS",      keywords: "pixel crt dither palette shader retro effect scanline" },
        { sectionId: 4,  name: "Network",          icon: "lan",             group: "CONNECTIVITY", keywords: "ethernet vpn ip dns gateway connection nmcli interface" },
        { sectionId: 5,  name: "Wi-Fi",            icon: "wifi",            group: "CONNECTIVITY", keywords: "wireless wlan ssid password psk scan connect hotspot" },
        { sectionId: 6,  name: "Bluetooth",        icon: "bluetooth",       group: "CONNECTIVITY", keywords: "bt pair device headset battery mouse keyboard" },
        { sectionId: 7,  name: "Weather",          icon: "thermostat",      group: "CONNECTIVITY", keywords: "forecast temperature location zip city climate" },
        { sectionId: 9,  name: "Clock",            icon: "schedule",        group: "WIDGETS",      keywords: "time date desktop 12 24 hour second" },
        { sectionId: 19, name: "System Info",      icon: "terminal",        group: "WIDGETS",      keywords: "sysinfo fetch neofetch cpu ram uptime kernel host gpu disk" },
        { sectionId: 21, name: "Audio Visualizer", icon: "graphic_eq",      group: "WIDGETS",      keywords: "cava spectrum bar equalizer visualiser music beat breathe ambient" },
        { sectionId: 22, name: "Assistant",        icon: "support_agent",   group: "WIDGETS",      keywords: "ai llm ollama claude codex gemini chat model prompt mascot pet character bounce avatar" },
        { sectionId: 23, name: "App Dock",         icon: "dock_to_bottom",  group: "WIDGETS",      keywords: "dock taskbar launcher pin pinned apps icons floating draggable" },
        { sectionId: 24, name: "Notifications",    icon: "notifications",   group: "SYSTEM",       keywords: "notification dnd do not disturb quiet hours schedule fullscreen silence tray systray status icon background apps pin rules mute per-app" },
        { sectionId: 13, name: "Sounds",           icon: "volume_up",       group: "SYSTEM",       keywords: "audio notification window sound effect volume wav" },
        { sectionId: 10, name: "Keyboard",         icon: "keyboard",        group: "SYSTEM",       keywords: "keybind shortcut hotkey osk on-screen layout binding" },
        { sectionId: 15, name: "Lockscreen",       icon: "lock",            group: "SYSTEM",       keywords: "lock password blur idle hypridle security" },
        { sectionId: 18, name: "Screensaver",      icon: "tv",              group: "SYSTEM",       keywords: "idle screen saver matrix bounce" },
        { sectionId: 11, name: "Shell",            icon: "terminal",        group: "SHELL",        keywords: "update git version reload restart about repository profile" }
    ]

    // Icon indexing is shared via Config.iconIndexService (see
    // components/services/IconIndexService.qml) - it used to be a verbatim
    // duplicate of AppLauncher.qml's copy.
    Connections {
        target: Config.iconIndexService
        function onIconMapChanged() { osdRoot.updateModel(); }
    }

    function getAppIcon(iconName) { return Config.getAppIcon(iconName); }

    // --- FILE SEARCH (# prefix) ---
    // Query is passed as a process argument (never embedded in the script text)
    // so arbitrary typed text can never break out of the python source.
    readonly property string fileSearchScript: `
import sys, os, json

query = sys.argv[1].lower()
home = os.path.expanduser("~")
skip_dirs = {".git", "node_modules", ".cache", ".npm", ".cargo", ".rustup", ".local"}
results = []

for root, dirs, files in os.walk(home):
    dirs[:] = [d for d in dirs if d not in skip_dirs]
    for name in files:
        if query in name.lower():
            results.append(os.path.join(root, name))
            if len(results) >= 40:
                print(json.dumps(results))
                sys.exit(0)

print(json.dumps(results))
`

    Process {
        id: fileSearchProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (osdRoot.searchMode !== "files") return;
                try {
                    let clean = this.text.trim();
                    osdRoot.filteredFiles = clean ? JSON.parse(clean) : [];
                } catch(e) {
                    osdRoot.filteredFiles = [];
                }
                resultList.currentIndex = osdRoot.filteredFiles.length > 0 ? 0 : -1;
            }
        }
    }

    Timer {
        id: fileSearchDebounce
        interval: 220
        repeat: false
        onTriggered: {
            if (osdRoot.searchMode !== "files") return;
            let q = osdRoot.queryText.trim();
            if (q === "") { osdRoot.filteredFiles = []; return; }
            fileSearchProc.command = ["python3", "-c", osdRoot.fileSearchScript, q];
            fileSearchProc.running = false;
            fileSearchProc.running = true;
        }
    }

    // --- CLIPBOARD SEARCH (^ prefix) ---
    // Fetch/parse logic mirrors Clipboard.qml's fetchProc verbatim so both
    // surfaces agree on what counts as an image vs text entry.
    Process {
        id: clipboardFetchProc
        running: false
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            id: clipboardFetchOut
            onStreamFinished: {
                let outText = clipboardFetchOut.text;
                let newItems = [];

                if (outText && outText.trim() !== "") {
                    let lines = outText.trim().split("\n");
                    for (let line of lines) {
                        if (!line) continue;
                        let firstTab = line.indexOf("\t");
                        if (firstTab === -1) continue;

                        let id = line.substring(0, firstTab).trim();
                        let text = line.substring(firstTab + 1).trim();

                        let isBinary = text.includes("binary data") || text.includes("image") || text.startsWith("[[");
                        let isBase64 = text.startsWith("data:image/");
                        let isWebUrl = /^https?:\/\/.*\.(png|jpg|jpeg|webp|gif|svg)(\?.*)?$/i.test(text);
                        let isLocalFile = (text.startsWith("/") || text.startsWith("file://")) &&
                                          /\.(png|jpg|jpeg|webp|gif|svg)$/i.test(text);

                        let finalImgPath = "";
                        if (isBinary || isBase64) finalImgPath = "";
                        else if (isWebUrl) finalImgPath = text;
                        else if (isLocalFile) finalImgPath = text.startsWith("file://") ? text : ("file://" + text);

                        let isVisualItem = isBinary || isBase64 || isWebUrl || isLocalFile;

                        newItems.push({
                            itemId: id,
                            previewText: text,
                            isImage: isVisualItem,
                            imagePath: finalImgPath
                        });
                    }
                }

                osdRoot.allClipboardItems = newItems;
                if (osdRoot.searchMode === "clipboard") osdRoot.updateModel();

                clipboardCacheProc.running = false;
                clipboardCacheProc.running = true;
            }
        }
    }

    // Thumbnail cache for image entries - same /tmp/cliphist convention as
    // Clipboard.qml, so thumbnails generated by either surface are reused by
    // the other.
    Process {
        id: clipboardCacheProc
        running: false
        command: [
            "sh", "-c",
            "mkdir -p /tmp/cliphist; " +
            "cliphist list | head -n 40 | while read -r id line; do " +
                "img_path=\"/tmp/cliphist/$id.png\"; " +
                "if [ -f \"$img_path\" ]; then " +
                    "echo \"$id\"; " +
                "else " +
                    "case \"$line\" in " +
                        "*\\[\\[*|*image*|*binary*) " +
                            "printf '%s\\t%s\\n' \"$id\" \"$line\" | cliphist decode > \"$img_path\" 2>/dev/null; " +
                            "[ -s \"$img_path\" ] && echo \"$id\"; " +
                            ";; " +
                    "esac; " +
                "fi; " +
            "done"
        ]

        stdout: StdioCollector {
            id: clipboardCacheOut
            onStreamFinished: {
                let out = clipboardCacheOut.text;
                if (!out) return;
                let generatedIds = out.trim().split("\n");
                if (generatedIds.length === 0 || !generatedIds[0]) return;

                osdRoot.allClipboardItems = osdRoot.allClipboardItems.map(item => {
                    if (generatedIds.includes(item.itemId)) {
                        return Object.assign({}, item, { imagePath: "file:///tmp/cliphist/" + item.itemId + ".png?t=" + Date.now() });
                    }
                    return item;
                });
                if (osdRoot.searchMode === "clipboard") osdRoot.updateModel();
            }
        }
    }

    Process {
        id: clipboardCopyProc
    }

    // --- CALCULATOR (auto-detected, no prefix) ---
    // Only treats input as math when it's unambiguously arithmetic: charset is
    // restricted to digits/operators/parens/whitespace, and there must be an
    // actual binary operation present (not just a lone leading "-5" or a bare
    // number like "2024" that's probably a search term, not a calculation).
    function looksLikeMath(str) {
        let t = str.trim();
        if (t.length === 0) return false;
        if (!/^[0-9+\-*/%^().\s]+$/.test(t)) return false;
        if (!/[0-9]/.test(t)) return false;
        if (/[*/%^]/.test(t)) return true;
        if (/[0-9)]\s*[+\-]\s*[-+]?\s*[0-9(.]/.test(t)) return true;
        return false;
    }

    // Small recursive-descent evaluator so typed text is never handed to
    // eval()/Function() - the grammar only understands numbers, + - * / % ^,
    // parens, and unary sign, so there's no way for input to do anything but
    // arithmetic. Throws on any malformed expression (unbalanced parens,
    // trailing garbage, division by zero).
    function evalMath(str) {
        let s = str.replace(/\s+/g, "");
        let pos = 0;

        function peek() { return s[pos]; }
        function consume() { return s[pos++]; }

        function parseExpression() {
            let value = parseTerm();
            while (pos < s.length && (peek() === "+" || peek() === "-")) {
                let op = consume();
                let rhs = parseTerm();
                value = op === "+" ? value + rhs : value - rhs;
            }
            return value;
        }

        function parseTerm() {
            let value = parseUnary();
            while (pos < s.length && (peek() === "*" || peek() === "/" || peek() === "%")) {
                let op = consume();
                let rhs = parseUnary();
                if (op === "*") value = value * rhs;
                else if (op === "/") {
                    if (rhs === 0) throw new Error("Division by zero");
                    value = value / rhs;
                } else {
                    value = value % rhs;
                }
            }
            return value;
        }

        function parseUnary() {
            if (peek() === "-") { consume(); return -parseUnary(); }
            if (peek() === "+") { consume(); return parseUnary(); }
            return parsePower();
        }

        function parsePower() {
            let base = parsePrimary();
            if (peek() === "^") {
                consume();
                return Math.pow(base, parseUnary());
            }
            return base;
        }

        function parsePrimary() {
            if (peek() === "(") {
                consume();
                let value = parseExpression();
                if (peek() !== ")") throw new Error("Expected )");
                consume();
                return value;
            }
            let start = pos;
            while (pos < s.length && /[0-9.]/.test(peek())) pos++;
            if (pos === start) throw new Error("Expected number");
            let num = parseFloat(s.slice(start, pos));
            if (isNaN(num)) throw new Error("Invalid number");
            return num;
        }

        if (s.length === 0) throw new Error("Empty expression");
        let result = parseExpression();
        if (pos !== s.length) throw new Error("Unexpected trailing characters");
        if (!isFinite(result)) throw new Error("Invalid result");
        return result;
    }

    // Strips float noise (e.g. 0.1+0.2 -> 0.30000000000000004) without
    // truncating legitimately large/precise results.
    function formatCalcResult(num) {
        if (Number.isInteger(num)) return num.toString();
        let rounded = Math.round(num * 1e10) / 1e10;
        return rounded.toString();
    }

    function copyCalcResult() {
        if (!osdRoot.calcValid) return;
        Quickshell.execDetached(["wl-copy", osdRoot.calcResultText]);
        Config.showLauncherOsd = false;
    }

    // --- MODE DETECTION + FILTERING ---
    function updateModel() {
        let raw = searchInput.text;

        if (raw.startsWith("#")) {
            osdRoot.searchMode = "files";
            osdRoot.queryText = raw.slice(1);
            fileSearchDebounce.restart();
        } else if (raw.startsWith(":")) {
            osdRoot.searchMode = "emoji";
            osdRoot.filteredEmoji = osdRoot.searchEmoji(raw.slice(1));
        } else if (raw.startsWith(">")) {
            osdRoot.searchMode = "ipc";
            let q = raw.slice(1).trim().toLowerCase();
            let ipcMatches = osdRoot.ipcCommands.filter(c => {
                if (q === "") return true;
                return c.name.toLowerCase().includes(q) || c.target.toLowerCase().includes(q) || c.fn.toLowerCase().includes(q);
            });
            let settingsMatches = osdRoot.settingsSections.filter(s => {
                if (q === "") return true;
                return s.name.toLowerCase().includes(q) || s.keywords.includes(q);
            });
            osdRoot.filteredCommands = ipcMatches.concat(settingsMatches);
        } else if (raw.startsWith("~")) {
            osdRoot.searchMode = "wallpaper";
            let q = raw.slice(1).trim().toLowerCase();
            let list = (Config.wallpaper && Config.wallpaper.wallpapers) ? Config.wallpaper.wallpapers : [];
            osdRoot.filteredWallpapers = list.filter(p => {
                if (q === "") return true;
                let base = ("" + p).split("/").pop().toLowerCase();
                return base.includes(q);
            });
        } else if (raw.startsWith("^")) {
            let wasClipboard = osdRoot.searchMode === "clipboard";
            osdRoot.searchMode = "clipboard";
            if (!wasClipboard) {
                clipboardFetchProc.running = false;
                clipboardFetchProc.running = true;
            }
            let q = raw.slice(1).trim().toLowerCase();
            osdRoot.filteredClipboard = osdRoot.allClipboardItems.filter(it => q === "" || it.previewText.toLowerCase().includes(q));
        } else if (osdRoot.looksLikeMath(raw)) {
            osdRoot.searchMode = "calc";
            try {
                osdRoot.calcResultText = osdRoot.formatCalcResult(osdRoot.evalMath(raw));
                osdRoot.calcValid = true;
            } catch (e) {
                osdRoot.calcResultText = "";
                osdRoot.calcValid = false;
            }
        } else {
            osdRoot.searchMode = "apps";
            let query = raw.trim().toLowerCase();

            if (query === "" && !osdRoot.browsingAllApps) {
                osdRoot.filteredApps = [];
            } else {
                let rawApps = DesktopEntries.applications ? DesktopEntries.applications.values : [];
                let apps = [];

                for (let i = 0; i < rawApps.length; i++) {
                    let app = rawApps[i];
                    if (app.noDisplay) continue;

                    if (query !== "") {
                        let nameMatch = app.name && app.name.toLowerCase().includes(query);
                        let genMatch = app.genericName && app.genericName.toLowerCase().includes(query);
                        let descMatch = app.comment && app.comment.toLowerCase().includes(query);
                        let catMatch = app.categories && app.categories.some(c => c.toLowerCase().includes(query));
                        let kwMatch = app.keywords && app.keywords.some(k => k.toLowerCase().includes(query));

                        if (!nameMatch && !genMatch && !descMatch && !catMatch && !kwMatch) continue;
                    }

                    apps.push(app);
                }

                // Pinned apps float to the top, same as AppLauncher.qml used to.
                let pinned = apps.filter(a => osdRoot.isAppPinned(a));
                let unpinned = apps.filter(a => !osdRoot.isAppPinned(a));
                pinned.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
                unpinned.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
                osdRoot.filteredApps = pinned.concat(unpinned);
            }
        }

        resultList.currentIndex = osdRoot.currentResults.length > 0 ? 0 : -1;
        emojiGrid.currentIndex = osdRoot.currentResults.length > 0 ? 0 : -1;
        wallpaperGrid.currentIndex = osdRoot.currentResults.length > 0 ? 0 : -1;
        clipboardListView.currentIndex = osdRoot.currentResults.length > 0 ? 0 : -1;
        resultList.positionViewAtBeginning();
    }

    // Reactively update application list when desktop entries are added, removed, or changed
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { if (osdRoot.searchMode === "apps") osdRoot.updateModel(); }
        function onModelReset() { if (osdRoot.searchMode === "apps") osdRoot.updateModel(); }
    }

    // Reset to the default app view every time the launcher is opened
    Connections {
        target: Config
        function onShowLauncherOsdChanged() {
            if (Config.showLauncherOsd) {
                osdRoot.browsingAllApps = false;
                searchInput.text = "";
                searchInput.forceActiveFocus();
                pinCacheReader.reload();
                osdRoot.updateModel();
            }
        }
    }

    Timer {
        running: Config.showLauncherOsd
        interval: 50
        onTriggered: searchInput.forceActiveFocus()
    }

    // A pending prefill (set by the `launcherosd emoji` IPC verb) is applied
    // once on open and then cleared, so reopening the launcher normally the
    // next time starts empty.
    Connections {
        target: Config
        function onShowLauncherOsdChanged() {
            if (!Config.showLauncherOsd) return
            if (Config.launcherPrefill === "") return
            searchInput.text = Config.launcherPrefill
            searchInput.cursorPosition = searchInput.text.length
            Config.launcherPrefill = ""
            osdRoot.updateModel()
        }
    }

    // --- ACTIONS ---
    function launchApp(app) {
        if (!app) return;
        if (typeof app.execute === "function") {
            app.execute();
        } else if (app.execString) {
            let cleanExec = app.execString.replace(/%[uUfFkKcCiI]/g, "").trim();
            Quickshell.execDetached(["sh", "-c", cleanExec]);
        }
        Config.showLauncherOsd = false;
    }

    function launchFile(path) {
        if (!path) return;
        Quickshell.execDetached(["xdg-open", path]);
        Config.showLauncherOsd = false;
    }

    // Copy to the clipboard rather than trying to type it: there is no
    // portable synthetic-input path on Wayland, and paste is one keystroke.
    function pickEmoji(entry) {
        if (!entry || !entry.c) return;
        Quickshell.execDetached(["wl-copy", "--", entry.c]);
        osdRoot.recordEmojiUse(entry.c);
        Config.showLauncherOsd = false;
    }

    // Handles both the static IPC verbs and the settingsSections entries -
    // the latter have no target/fn, just a sectionId to jump Settings to.
    function runIpcCommand(entry) {
        if (!entry) return;
        if (entry.sectionId !== undefined) {
            Config.lastSettingsSection = entry.sectionId;
            Config.showSettings = true;
        } else {
            Quickshell.execDetached(["qs", "-c", "Synoptik", "ipc", "call", entry.target, entry.fn]);
        }
        Config.showLauncherOsd = false;
    }

    function applyWallpaperResult(path) {
        if (!path) return;
        Config.applyWallpaperBackend(path, false);
        Config.showLauncherOsd = false;
    }

    // Mirrors Clipboard.qml's copyProc command exactly - itemId comes from
    // cliphist's own output, never from typed text.
    function copyClipboardItem(item) {
        if (!item || !item.itemId) return;
        clipboardCopyProc.command = ["sh", "-c", "cliphist list | awk 'BEGIN{FS=\"\\t\"} $1 == \"" + item.itemId + "\" {print $0}' | cliphist decode | wl-copy"];
        clipboardCopyProc.running = false;
        clipboardCopyProc.running = true;
        Config.showLauncherOsd = false;
    }

    function activateResult(item) {
        if (!item) return;
        if (osdRoot.searchMode === "files") osdRoot.launchFile(item);
        else if (osdRoot.searchMode === "ipc") osdRoot.runIpcCommand(item);
        else if (osdRoot.searchMode === "emoji") osdRoot.pickEmoji(item);
        else if (osdRoot.searchMode === "wallpaper") osdRoot.applyWallpaperResult(item);
        else if (osdRoot.searchMode === "clipboard") osdRoot.copyClipboardItem(item);
        else osdRoot.launchApp(item);
    }

    function activateCurrent() {
        // The grids and the clipboard list keep their own selection; the
        // shared resultList's currentIndex means nothing in those modes.
        if (osdRoot.searchMode === "emoji" || osdRoot.searchMode === "wallpaper") {
            let grid = osdRoot.searchMode === "wallpaper" ? wallpaperGrid : emojiGrid;
            if (grid.currentIndex < 0 || grid.currentIndex >= osdRoot.currentResults.length) return;
            osdRoot.activateResult(osdRoot.currentResults[grid.currentIndex]);
            return;
        }
        if (osdRoot.searchMode === "clipboard") {
            if (osdRoot.clipboardCurrentItem) osdRoot.activateResult(osdRoot.clipboardCurrentItem);
            return;
        }
        if (resultList.currentIndex < 0 || resultList.currentIndex >= osdRoot.currentResults.length) return;
        osdRoot.activateResult(osdRoot.currentResults[resultList.currentIndex]);
    }

    // --- RESULT FIELD HELPERS (shared delegate across modes) ---
    function resultTitle(item) {
        if (osdRoot.searchMode === "apps") return item.name || "";
        if (osdRoot.searchMode === "ipc") return item.name || "";
        let parts = ("" + item).split("/");
        return parts[parts.length - 1] || item;
    }

    function resultSubtitle(item) {
        if (osdRoot.searchMode === "apps") {
            return (item.comment && item.comment !== "") ? item.comment : ((item.genericName && item.genericName !== "") ? item.genericName : "Application");
        }
        if (osdRoot.searchMode === "ipc") {
            return item.sectionId !== undefined ? ("Settings — " + item.group) : ("> " + item.target + " " + item.fn);
        }
        let str = "" + item;
        let idx = str.lastIndexOf("/");
        let dir = idx >= 0 ? str.substring(0, idx) : "";
        return dir.replace(Quickshell.env("HOME"), "~");
    }

    Component.onCompleted: {
        // A `sh -c "[ -f ... ] || echo ... > ..."` Process used to create the
        // pin file just so pinCacheReader had something to open. A missing
        // file is the same as an empty pin list, so the spawn is gone.
        osdRoot.pinFilePath = Quickshell.env("HOME") + "/.cache/quickshell_launcher_pins.json"
        osdRoot.updateModel()
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: osdRoot.cardMargin
        spacing: 0

        // Single oversized bar — no title header, no boxed sub-panels.
        Rectangle {
            id: barCard
            Layout.fillWidth: true
            implicitWidth: 680
            implicitHeight: barContentLayout.implicitHeight
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.05)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)
            clip: true

            ColumnLayout {
                id: barContentLayout
                anchors.fill: parent
                spacing: 0

                // --- OVERSIZED SEARCH ROW ---
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68
                    Layout.leftMargin: 22
                    Layout.rightMargin: 18
                    spacing: 16

                    Text {
                        text: osdRoot.modeIcon
                        color: searchInput.activeFocus ? Config.accent : Config.textMuted
                        font { family: "Material Symbols Outlined"; pixelSize: 28 }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontTitle)
                        font.bold: true
                        clip: true
                        selectByMouse: true
                        focus: true

                        HoverHandler { cursorShape: Qt.IBeamCursor }

                        Text {
                            text: osdRoot.modePlaceholder
                            color: Qt.rgba(255, 255, 255, 0.32)
                            font.family: Config.sysFont
                            font.pixelSize: parent.font.pixelSize
                            font.italic: true
                            visible: parent.text === ""
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        onTextChanged: osdRoot.updateModel()

                        Keys.onPressed: (event) => {
                            // Emoji/wallpaper modes are grids, so they move in
                            // two axes and up/down steps a whole row rather
                            // than one item.
                            if ((osdRoot.searchMode === "emoji" || osdRoot.searchMode === "wallpaper")
                                && (event.key === Qt.Key_Down || event.key === Qt.Key_Up
                                    || event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                                let n = osdRoot.currentResults.length;
                                let grid = osdRoot.searchMode === "wallpaper" ? wallpaperGrid : emojiGrid;
                                let cols = osdRoot.searchMode === "wallpaper" ? osdRoot.wallpaperGridColumns : osdRoot.emojiGridColumns;
                                if (n > 0) {
                                    let i = Math.max(0, grid.currentIndex);
                                    if (event.key === Qt.Key_Right) i += 1;
                                    else if (event.key === Qt.Key_Left) i -= 1;
                                    else if (event.key === Qt.Key_Down) i += cols;
                                    else i -= cols;
                                    grid.currentIndex = Math.max(0, Math.min(n - 1, i));
                                    grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                if (osdRoot.searchMode === "clipboard") clipboardListView.incrementCurrentIndex();
                                else resultList.incrementCurrentIndex();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                if (osdRoot.searchMode === "clipboard") clipboardListView.decrementCurrentIndex();
                                else resultList.decrementCurrentIndex();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (osdRoot.searchMode === "calc") {
                                    osdRoot.copyCalcResult();
                                } else {
                                    osdRoot.activateCurrent();
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                Config.showLauncherOsd = false;
                                event.accepted = true;
                            }
                        }
                    }

                    // Mode badge pill (shown for every non-apps mode)
                    Rectangle {
                        visible: osdRoot.modeBadge !== ""
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: badgeText.implicitWidth + 20
                        implicitHeight: 26
                        radius: 13
                        color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.18)
                        border.width: 1
                        border.color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.45)

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: osdRoot.modeBadge
                            color: Config.accent
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            font.letterSpacing: 0.6
                        }
                    }

                    // Browse-all-apps toggle - the whole reason AppLauncher.qml
                    // used to exist separately was showing every installed app
                    // with an empty query; this just flips the same result list
                    // below into showing everything instead of building a
                    // second app-list UI.
                    Rectangle {
                        visible: osdRoot.searchMode === "apps"
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: browseRow.implicitWidth + 20
                        implicitHeight: 26
                        radius: 13
                        color: osdRoot.browsingAllApps
                            ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.22)
                            : (browseHover.hovered ? Qt.rgba(255, 255, 255, 0.1) : Qt.rgba(255, 255, 255, 0.05))
                        border.width: 1
                        border.color: osdRoot.browsingAllApps ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.45) : Qt.rgba(255, 255, 255, 0.1)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            id: browseRow
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: osdRoot.browsingAllApps ? "close" : "apps"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                                color: osdRoot.browsingAllApps ? Config.accent : Config.textMuted
                            }

                            Text {
                                text: osdRoot.browsingAllApps ? "Hide apps" : "Browse apps"
                                color: osdRoot.browsingAllApps ? Config.accent : Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: true
                            }
                        }

                        TapHandler {
                            onTapped: {
                                osdRoot.browsingAllApps = !osdRoot.browsingAllApps
                                osdRoot.updateModel()
                                searchInput.forceActiveFocus()
                            }
                        }
                        HoverHandler { id: browseHover; cursorShape: Qt.PointingHandCursor }
                    }
                }

                // Divider between the search row and the results
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 22
                    Layout.rightMargin: 22
                    implicitHeight: 1
                    color: Qt.rgba(255, 255, 255, 0.1)
                }

                // --- RESULTS ---
                // Narrow by default; only grows to a full list once there's something to show.
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: osdRoot.resultsAreaHeight

                    // --- CALCULATOR RESULT ROW ---
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 22
                        anchors.rightMargin: 22
                        visible: osdRoot.searchMode === "calc"
                        spacing: 12

                        Text {
                            text: "calculate"
                            color: osdRoot.calcValid ? Config.accent : Config.textMuted
                            font { family: "Material Symbols Outlined"; pixelSize: 22 }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: osdRoot.calcValid ? osdRoot.calcResultText : "Invalid expression"
                                color: osdRoot.calcValid ? Config.textMain : Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontTitle)
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: osdRoot.calcValid
                                text: "Press Enter to copy"
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                            }
                        }
                    }

                    // Empty-state clues — a single slim row, shown until the user types anything
                    RowLayout {
                        anchors.centerIn: parent
                        visible: searchInput.text === "" && !osdRoot.browsingAllApps
                            && osdRoot.searchMode !== "calc" && osdRoot.searchMode !== "emoji"
                        spacing: 22

                        Repeater {
                            model: [
                                { prefix: "#", desc: "files" },
                                { prefix: ">", desc: "commands" },
                                { prefix: ":", desc: "emoji" },
                                { prefix: "~", desc: "wallpapers" },
                                { prefix: "^", desc: "clipboard" }
                            ]

                            delegate: RowLayout {
                                spacing: 8

                                Text {
                                    text: modelData.prefix
                                    color: Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontBody)
                                }

                                Text {
                                    text: modelData.desc
                                    color: Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontSubhead)
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: (searchInput.text !== "" || osdRoot.browsingAllApps)
                            && osdRoot.currentResults.length === 0
                            && osdRoot.searchMode !== "calc" && osdRoot.searchMode !== "emoji"
                            && osdRoot.searchMode !== "wallpaper" && osdRoot.searchMode !== "clipboard"
                        text: osdRoot.searchMode === "files" && osdRoot.queryText.trim() === ""
                            ? "Type to search files..."
                            : (osdRoot.browsingAllApps ? "No apps found" : "No results")
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.italic: true
                    }

                    // --- EMOJI & GLYPH GRID ---
                    // A one-per-row list is the wrong shape for picking a
                    // character you recognise by sight, so emoji mode gets its
                    // own grid rather than reusing the result list.
                    Item {
                        anchors.fill: parent
                        anchors.margins: 8
                        visible: osdRoot.searchMode === "emoji"

                        Text {
                            anchors.centerIn: parent
                            visible: osdRoot.currentResults.length === 0
                            text: osdRoot.emojiData.length === 0
                                ? "Emoji data unavailable"
                                : "No matching emoji or symbols"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.italic: true
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 4
                            visible: osdRoot.currentResults.length > 0

                            GridView {
                                id: emojiGrid
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                cellWidth: osdRoot.emojiCellSize
                                cellHeight: osdRoot.emojiCellSize
                                boundsBehavior: Flickable.StopAtBounds
                                model: osdRoot.currentResults
                                currentIndex: 0

                                // Keep the cells centred instead of leaving a
                                // ragged gap on the right of a fixed grid.
                                leftMargin: Math.max(0, (width - (osdRoot.emojiGridColumns * cellWidth)) / 2)

                                delegate: Item {
                                    required property var modelData
                                    required property int index

                                    width: osdRoot.emojiCellSize
                                    height: osdRoot.emojiCellSize

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width - 6
                                        height: parent.height - 6
                                        radius: Config.cornerRadius / 2
                                        color: emojiGrid.currentIndex === index
                                            ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.25)
                                            : (cellHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent")
                                        border.width: emojiGrid.currentIndex === index ? 1 : 0
                                        border.color: Config.accent
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.c
                                            font.family: osdRoot.emojiFontFamily
                                            font.pixelSize: 24
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        HoverHandler {
                                            id: cellHover
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                        TapHandler {
                                            onTapped: {
                                                emojiGrid.currentIndex = index
                                                osdRoot.pickEmoji(modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            // Names the highlighted character, so a grid of
                            // near-identical faces is still navigable and the
                            // glyph half is legible at all.
                            Text {
                                Layout.fillWidth: true
                                Layout.leftMargin: 6
                                Layout.rightMargin: 6
                                text: {
                                    let i = emojiGrid.currentIndex
                                    let r = osdRoot.currentResults
                                    if (i < 0 || i >= r.length) return ""
                                    return r[i].c + "   " + r[i].n
                                }
                                color: Config.textMuted
                                font.family: osdRoot.emojiFontFamily
                                font.pixelSize: Config.size(Config.fontMicro)
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // --- WALLPAPER GRID ---
                    // Thumbnails, not a text row, so this reuses the emoji
                    // grid's structure rather than the shared resultList.
                    Item {
                        anchors.fill: parent
                        anchors.margins: 8
                        visible: osdRoot.searchMode === "wallpaper"

                        Text {
                            anchors.centerIn: parent
                            visible: osdRoot.currentResults.length === 0
                            text: "No matching wallpapers"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.italic: true
                        }

                        GridView {
                            id: wallpaperGrid
                            anchors.fill: parent
                            clip: true
                            visible: osdRoot.currentResults.length > 0
                            cellWidth: osdRoot.wallpaperCellWidth
                            cellHeight: osdRoot.wallpaperCellHeight
                            boundsBehavior: Flickable.StopAtBounds
                            model: osdRoot.currentResults
                            currentIndex: 0

                            // Same centering trick as the emoji grid - without it
                            // a row that doesn't fill every column sits flush
                            // left instead of centred.
                            leftMargin: Math.max(0, (width - (osdRoot.wallpaperGridColumns * cellWidth)) / 2)

                            delegate: Item {
                                required property var modelData
                                required property int index

                                width: osdRoot.wallpaperCellWidth
                                height: osdRoot.wallpaperCellHeight

                                // ClippingRectangle, not plain Rectangle - plain
                                // Rectangle.clip only clips to the square
                                // bounding box, so a square Image would blow
                                // past the rounded corners (see Clipboard.qml's
                                // watermark for the same fix).
                                ClippingRectangle {
                                    anchors.centerIn: parent
                                    width: parent.width - 8
                                    height: parent.height - 10
                                    radius: Config.cornerRadius / 2
                                    color: Qt.rgba(255, 255, 255, 0.04)
                                    border.width: wallpaperGrid.currentIndex === index ? 1 : 0
                                    border.color: Config.accent

                                    // Flush with the ClippingRectangle's own edge (no margin) -
                                    // an inset image is clipped by the same corner radius as
                                    // the border but from a smaller box, so its corner cut
                                    // looks tighter than the border's curve. Flush means both
                                    // share the exact same clipped boundary.
                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + osdRoot.wallpaperThumbPath(modelData)
                                        fillMode: Image.PreserveAspectCrop
                                        horizontalAlignment: Image.AlignHCenter
                                        verticalAlignment: Image.AlignVCenter
                                        asynchronous: true
                                        cache: true
                                    }

                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        onTapped: {
                                            wallpaperGrid.currentIndex = index
                                            osdRoot.activateResult(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // --- CLIPBOARD SPLIT VIEW ---
                    // A compact left-aligned list (like a file list) plus a
                    // dedicated preview pane, rather than reusing the shared
                    // resultList - clipboard entries need to show either an
                    // image or the full text, which a single-column row can't.
                    Item {
                        anchors.fill: parent
                        anchors.margins: 8
                        visible: osdRoot.searchMode === "clipboard"

                        Text {
                            anchors.centerIn: parent
                            visible: osdRoot.currentResults.length === 0
                            text: {
                                if (clipboardFetchProc.running) return "Loading clipboard history..."
                                if (osdRoot.allClipboardItems.length === 0) return "Clipboard history is empty"
                                return "No matching clipboard entries"
                            }
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.italic: true
                        }

                        RowLayout {
                            anchors.fill: parent
                            visible: osdRoot.currentResults.length > 0
                            spacing: 10

                            ListView {
                                id: clipboardListView
                                Layout.preferredWidth: 220
                                Layout.fillHeight: true
                                clip: true
                                spacing: 2
                                boundsBehavior: Flickable.StopAtBounds
                                model: osdRoot.currentResults
                                currentIndex: 0

                                delegate: Rectangle {
                                    id: clipRowDelegate
                                    required property var modelData
                                    required property int index

                                    width: clipboardListView.width
                                    implicitHeight: 32
                                    radius: Config.cornerRadius / 2
                                    color: clipboardListView.currentIndex === index
                                        ? Qt.rgba(255, 255, 255, 0.12)
                                        : (clipRowHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent")

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Text {
                                            text: osdRoot.clipboardRowIcon(clipRowDelegate.modelData)
                                            color: clipboardListView.currentIndex === clipRowDelegate.index ? Config.accent : Config.textMuted
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 15
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: osdRoot.clipboardRowLabel(clipRowDelegate.modelData)
                                            color: Config.textMain
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontCaption)
                                            horizontalAlignment: Text.AlignLeft
                                            elide: Text.ElideRight
                                        }
                                    }

                                    HoverHandler { id: clipRowHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        onTapped: {
                                            clipboardListView.currentIndex = clipRowDelegate.index
                                            osdRoot.activateResult(clipRowDelegate.modelData)
                                        }
                                    }
                                }

                                ScrollBar.vertical: ScrollBar {
                                    active: clipboardListView.moving || clipboardListView.flickableDirection
                                    policy: ScrollBar.AsNeeded
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true
                                color: Qt.rgba(255, 255, 255, 0.1)
                            }

                            // --- PREVIEW PANE ---
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: osdRoot.clipboardCurrentItem !== null

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 6

                                    Text {
                                        text: {
                                            if (!osdRoot.clipboardCurrentItem) return ""
                                            if (osdRoot.clipboardCurrentIsFile) return "FILE"
                                            return osdRoot.clipboardCurrentItem.isImage ? "IMAGE" : "TEXT"
                                        }
                                        color: Config.accent
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontMicro)
                                        font.bold: true
                                        font.letterSpacing: 0.6
                                    }

                                    // Filename + full path - the row already shows just the
                                    // basename, so this is where the rest of the path lives.
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        visible: osdRoot.clipboardCurrentIsFile

                                        Text {
                                            Layout.fillWidth: true
                                            text: osdRoot.clipboardCurrentItem ? osdRoot.clipboardFileBasename(osdRoot.clipboardCurrentItem.previewText) : ""
                                            color: Config.textMain
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontBody)
                                            font.bold: true
                                            elide: Text.ElideMiddle
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: osdRoot.clipboardCurrentItem
                                                ? osdRoot.clipboardCurrentItem.previewText.replace(/^file:\/\//, "").replace(Quickshell.env("HOME"), "~")
                                                : ""
                                            color: Config.textMuted
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontMicro)
                                            elide: Text.ElideMiddle
                                        }
                                    }

                                    ClippingRectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: Config.cornerRadius / 2
                                        color: Qt.rgba(255, 255, 255, 0.03)
                                        visible: osdRoot.clipboardCurrentItem
                                            && osdRoot.clipboardCurrentItem.isImage
                                            && osdRoot.clipboardCurrentItem.imagePath !== ""

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            source: (osdRoot.clipboardCurrentItem && osdRoot.clipboardCurrentItem.isImage)
                                                ? osdRoot.clipboardCurrentItem.imagePath : ""
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            cache: true
                                        }
                                    }

                                    // File details (size / modified / type) - fetched async by
                                    // the stat Process whenever selection lands on a file entry.
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        visible: osdRoot.clipboardCurrentIsFile

                                        Text {
                                            visible: osdRoot.clipboardFileInfo === null
                                            text: "Reading file info..."
                                            color: Config.textMuted
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontCaption)
                                            font.italic: true
                                        }

                                        Text {
                                            visible: osdRoot.clipboardFileInfo !== null && osdRoot.clipboardFileInfo.exists === false
                                            text: "This file no longer exists at that path"
                                            color: Config.textMuted
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontCaption)
                                            font.italic: true
                                        }

                                        Repeater {
                                            model: (osdRoot.clipboardFileInfo && osdRoot.clipboardFileInfo.exists) ? [
                                                { label: "Size", value: osdRoot.clipboardFileInfo.isDir ? "Folder" : osdRoot.formatFileSize(osdRoot.clipboardFileInfo.size) },
                                                { label: "Modified", value: osdRoot.formatModTime(osdRoot.clipboardFileInfo.mtime) },
                                                { label: "Type", value: osdRoot.clipboardFileInfo.mime || "unknown" }
                                            ] : []

                                            delegate: RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Text {
                                                    Layout.preferredWidth: 70
                                                    text: modelData.label
                                                    color: Config.textMuted
                                                    font.family: Config.sysFont
                                                    font.pixelSize: Config.size(Config.fontCaption)
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.value
                                                    color: Config.textMain
                                                    font.family: Config.sysFont
                                                    font.pixelSize: Config.size(Config.fontCaption)
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }

                                    Flickable {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        visible: osdRoot.clipboardCurrentItem && !osdRoot.clipboardCurrentItem.isImage && !osdRoot.clipboardCurrentIsFile
                                        clip: true
                                        contentWidth: width
                                        contentHeight: clipPreviewText.implicitHeight
                                        boundsBehavior: Flickable.StopAtBounds

                                        Text {
                                            id: clipPreviewText
                                            width: parent.width
                                            text: osdRoot.clipboardCurrentItem ? osdRoot.clipboardCurrentItem.previewText : ""
                                            color: Config.textMain
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontBody)
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ListView {
                        id: resultList
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        visible: osdRoot.searchMode !== "emoji" && osdRoot.searchMode !== "wallpaper" && osdRoot.searchMode !== "clipboard"
                            && (searchInput.text !== "" || osdRoot.browsingAllApps) && osdRoot.currentResults.length > 0
                        spacing: 2
                        keyNavigationEnabled: false
                        boundsBehavior: Flickable.StopAtBounds
                        model: osdRoot.currentResults

                        delegate: Rectangle {
                            id: resultDelegate
                            width: resultList.width
                            implicitHeight: 54
                            radius: Config.cornerRadius / 2
                            color: resultList.currentIndex === index
                                ? Qt.rgba(255, 255, 255, 0.12)
                                : (itemHover.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent")

                            property var resultItem: modelData
                            property bool isPinned: osdRoot.searchMode === "apps" && osdRoot.isAppPinned(modelData)

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Image {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    sourceSize.width: 32
                                    sourceSize.height: 32
                                    fillMode: Image.PreserveAspectFit
                                    visible: osdRoot.searchMode === "apps"
                                    source: osdRoot.searchMode === "apps" ? osdRoot.getAppIcon(modelData.icon) : ""
                                    asynchronous: true
                                }

                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    radius: 6
                                    visible: osdRoot.searchMode !== "apps"
                                    color: Qt.rgba(255, 255, 255, 0.05)

                                    Text {
                                        anchors.centerIn: parent
                                        text: osdRoot.searchMode === "ipc" ? (modelData.icon || "terminal") : "description"
                                        color: Config.accent
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 18
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        text: osdRoot.resultTitle(modelData)
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontBody)
                                        font.bold: resultDelegate.isPinned
                                        color: Config.textMain
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: osdRoot.resultSubtitle(modelData)
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontCaption)
                                        color: Config.textMuted
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    text: "keep"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 18
                                    color: Config.accent
                                    visible: resultDelegate.isPinned
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                id: itemHover
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                property int lastScreenX: -1
                                property int lastScreenY: -1

                                onPositionChanged: (mouse) => {
                                    let currentX = Math.floor(mouse.screenX);
                                    let currentY = Math.floor(mouse.screenY);
                                    let deltaX = Math.abs(currentX - lastScreenX);
                                    let deltaY = Math.abs(currentY - lastScreenY);
                                    if (lastScreenX !== -1 && (deltaX > 2 || deltaY > 2)) {
                                        if (resultList.currentIndex !== index) {
                                            resultList.currentIndex = index;
                                        }
                                    }
                                    lastScreenX = currentX;
                                    lastScreenY = currentY;
                                }

                                onExited: {
                                    lastScreenX = -1;
                                    lastScreenY = -1;
                                }

                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton && osdRoot.searchMode === "apps") {
                                        osdRoot.togglePin(resultDelegate.resultItem);
                                    } else {
                                        osdRoot.activateResult(resultDelegate.resultItem);
                                    }
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            active: resultList.moving || resultList.flickableDirection
                            policy: ScrollBar.AsNeeded
                        }
                    }
                }
            }
        }
    }
}
