import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: osdRoot

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    // Static bounds to prevent UnifiedSurface evaluation loops (see NotificationOSD)
    implicitWidth: mainLayout.implicitWidth + (cardMargin * 2)
    implicitHeight: mainLayout.implicitHeight + (cardMargin * 2)

    // --- MODE / QUERY STATE ---
    // "apps" (default) | "files" (# prefix) | "ipc" (> prefix) | "calc" (auto-detected math)
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

    Process {
        id: initPinFile
        command: ["sh", "-c", "[ -f ~/.cache/quickshell_launcher_pins.json ] || echo '{\"pins\":[]}' > ~/.cache/quickshell_launcher_pins.json"]
        running: true
        onExited: osdRoot.pinFilePath = Quickshell.env("HOME") + "/.cache/quickshell_launcher_pins.json"
    }

    FileView {
        id: pinCacheReader
        path: osdRoot.pinFilePath
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

        let jsonStr = JSON.stringify({ "pins": currentPins });
        Quickshell.execDetached(["sh", "-c", "echo '" + jsonStr.replace(/'/g, "'\\''") + "' > ~/.cache/quickshell_launcher_pins.json"]);
    }
    property var filteredFiles: []
    property var filteredCommands: []

    // --- CALCULATOR STATE ---
    property string calcResultText: ""
    property bool calcValid: false

    readonly property var currentResults: {
        if (searchMode === "files") return filteredFiles
        if (searchMode === "ipc") return filteredCommands
        if (searchMode === "calc") return []
        return filteredApps
    }

    readonly property string modeBadge: {
        if (searchMode === "files") return "FILES"
        if (searchMode === "ipc") return "COMMANDS"
        if (searchMode === "calc") return "CALC"
        return ""
    }

    readonly property string modeIcon: {
        if (searchMode === "files") return "folder_open"
        if (searchMode === "ipc") return "terminal"
        if (searchMode === "calc") return "calculate"
        return "search"
    }

    readonly property string modePlaceholder: {
        if (searchMode === "files") return "Search files..."
        if (searchMode === "ipc") return "Search commands..."
        return "Search apps..."
    }

    // --- RESULTS AREA SIZING ---
    // Narrow (just the hint/status line) until there's an actual list to show,
    // then grows to fit up to maxVisibleRows before the list scrolls internally.
    readonly property int resultRowHeight: 56
    readonly property int maxVisibleRows: 5
    readonly property real resultsAreaHeight: {
        if (searchMode === "calc") return 68
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
        { target: "recorder",          fn: "toggle",     name: "Screen Recorder",   icon: "videocam" },
        { target: "mirror",            fn: "toggle",     name: "Camera Mirror",     icon: "photo_camera" },
        { target: "satty",             fn: "screenshot", name: "Take Screenshot (Satty)",   icon: "crop" },
        { target: "lockscreen",        fn: "lock",       name: "Lock Session",              icon: "lock" },
        { target: "screensaver",       fn: "start",      name: "Start Screensaver",         icon: "hourglass_empty" },
        { target: "screensaver",       fn: "stop",       name: "Stop Screensaver",          icon: "hourglass_disabled" },
        { target: "shader",            fn: "toggle",     name: "Retro Shader",              icon: "videogame_asset" }
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
        } else if (raw.startsWith(">")) {
            osdRoot.searchMode = "ipc";
            let q = raw.slice(1).trim().toLowerCase();
            osdRoot.filteredCommands = osdRoot.ipcCommands.filter(c => {
                if (q === "") return true;
                return c.name.toLowerCase().includes(q) || c.target.toLowerCase().includes(q) || c.fn.toLowerCase().includes(q);
            });
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

    function runIpcCommand(entry) {
        if (!entry) return;
        Quickshell.execDetached(["qs", "-c", "Synoptik", "ipc", "call", entry.target, entry.fn]);
        Config.showLauncherOsd = false;
    }

    function activateResult(item) {
        if (!item) return;
        if (osdRoot.searchMode === "files") osdRoot.launchFile(item);
        else if (osdRoot.searchMode === "ipc") osdRoot.runIpcCommand(item);
        else osdRoot.launchApp(item);
    }

    function activateCurrent() {
        if (resultList.currentIndex < 0 || resultList.currentIndex >= osdRoot.currentResults.length) return;
        osdRoot.activateResult(osdRoot.currentResults[resultList.currentIndex]);
    }

    // --- RESULT FIELD HELPERS (shared delegate across all three modes) ---
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
        if (osdRoot.searchMode === "ipc") return "> " + item.target + " " + item.fn;
        let str = "" + item;
        let idx = str.lastIndexOf("/");
        let dir = idx >= 0 ? str.substring(0, idx) : "";
        return dir.replace(Quickshell.env("HOME"), "~");
    }

    Component.onCompleted: osdRoot.updateModel()

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
                            if (event.key === Qt.Key_Down) {
                                resultList.incrementCurrentIndex();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                resultList.decrementCurrentIndex();
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

                    // Mode badge pill (only shown for # files / > commands)
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
                        visible: searchInput.text === "" && !osdRoot.browsingAllApps && osdRoot.searchMode !== "calc"
                        spacing: 22

                        Repeater {
                            model: [
                                { prefix: "#", desc: "files" },
                                { prefix: ">", desc: "commands" }
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
                        visible: (searchInput.text !== "" || osdRoot.browsingAllApps) && osdRoot.currentResults.length === 0 && osdRoot.searchMode !== "calc"
                        text: osdRoot.searchMode === "files" && osdRoot.queryText.trim() === ""
                            ? "Type to search files..."
                            : (osdRoot.browsingAllApps ? "No apps found" : "No results")
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.italic: true
                    }

                    ListView {
                        id: resultList
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        visible: (searchInput.text !== "" || osdRoot.browsingAllApps) && osdRoot.currentResults.length > 0
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
