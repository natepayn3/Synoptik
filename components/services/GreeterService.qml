import QtQuick
import Quickshell.Io

// SDDM greeter theme state, lifted out of GreeterSettings.qml.
//
// The Settings panel lives inside a Loader that deactivates (destroying its
// whole component tree) whenever Config.closeAllPanels() runs - and that's
// exactly what the shell's own polkit dialog does on every authentication
// request, so the panel can't hide the password prompt behind it. A pkexec
// Process owned by the settings page was getting torn down mid-authentication
// the instant the prompt appeared, silently killing Apply/Delete before they
// could ever finish. Living here instead, as a child of the Config singleton,
// this survives panel open/close cycles - same reason BatteryService does.
QtObject {
    id: root

    property var themes: []
    property string activeThemeId: ""
    property string statusText: ""
    property bool statusIsError: false
    property string pendingActionId: ""

    // Only ids that came out of our own directory scan ever reach a shell
    // command, but this stays as a hard boundary check since that string
    // gets interpolated into a pkexec'd sed/printf script.
    function isSafeId(id) {
        return /^[A-Za-z0-9_.-]+$/.test(id)
    }

    function themeById(id) {
        for (let i = 0; i < root.themes.length; i++) {
            if (root.themes[i].id === id) return root.themes[i]
        }
        return null
    }

    function refreshThemes() { themeListProc.running = true }
    function refreshActiveTheme() { activeThemeProc.running = true }

    function applyTheme(id) {
        if (!isSafeId(id) || id === root.activeThemeId) return
        root.pendingActionId = id
        root.statusText = "Applying …"
        root.statusIsError = false
        let script = "f=/etc/sddm.conf.d/theme.conf\n" +
            "mkdir -p /etc/sddm.conf.d\n" +
            "if [ -f \"$f\" ] && grep -q '^Current=' \"$f\"; then\n" +
            "  sed -i 's/^Current=.*/Current=" + id + "/' \"$f\"\n" +
            "else\n" +
            "  printf '[Theme]\\nCurrent=" + id + "\\n' > \"$f\"\n" +
            "fi\n"
        applyProc.command = ["pkexec", "sh", "-c", script]
        applyProc.running = true
    }

    // Always kills whatever preview window is already open and launches a
    // fresh one - the greeter window takes focus immediately, so a manual
    // Stop button in the settings panel would be unreachable while it's up.
    function startPreview(id) {
        if (!isSafeId(id)) return
        if (previewProc.running) previewProc.running = false
        let dir = "/usr/share/sddm/themes/" + id
        // -x matches the exact process name (not the full command line) so this
        // can't match its own invoking `sh -c "..."` wrapper - that wrapper's
        // argv literally contains this script's text, including the target
        // binary's name, so a `pkill -f` pattern here would kill itself before
        // ever reaching `exec`.
        previewProc.command = ["sh", "-c",
            "pkill -x sddm-greeter-qt6 2>/dev/null; exec sddm-greeter-qt6 --test-mode --theme '" + dir + "'"]
        previewProc.running = true
    }

    // Never deletes a theme Synoptik ships (protected, see themeListProc)
    // or the one currently active - removing the active greeter's files
    // would leave SDDM with nothing valid to load at the next login.
    function deleteTheme(id) {
        if (!isSafeId(id) || id === root.activeThemeId) return
        let theme = root.themeById(id)
        if (!theme || theme.protected) return
        root.pendingActionId = id
        root.statusText = "Deleting …"
        root.statusIsError = false
        deleteProc.command = ["pkexec", "rm", "-rf", "/usr/share/sddm/themes/" + id]
        deleteProc.running = true
    }

    Component.onCompleted: {
        refreshThemes()
        refreshActiveTheme()
    }

    // Lists every /usr/share/sddm/themes/<id> that has a metadata.desktop,
    // pulling its display name and (when theme.conf points at a real image)
    // a preview path. Re-run by the Refresh button so a theme dropped in
    // after this panel was last opened shows up without restarting the shell.
    property Process themeListProc: Process {
        running: false
        command: ["sh", "-c",
            "for d in /usr/share/sddm/themes/*/; do " +
            "[ -f \"$d/metadata.desktop\" ] || continue; " +
            "id=$(basename \"$d\"); " +
            "name=$(grep -m1 '^Name=' \"$d/metadata.desktop\" | cut -d= -f2-); " +
            "[ -z \"$name\" ] && name=\"$id\"; " +
            "bg=$(grep -m1 '^background=' \"$d/theme.conf\" 2>/dev/null | cut -d= -f2-); " +
            "bgpath=\"\"; " +
            "if [ -n \"$bg\" ] && [ -f \"$d$bg\" ]; then bgpath=\"$d$bg\"; fi; " +
            "owned=$(grep -m1 '^X-Synoptik=' \"$d/metadata.desktop\" | cut -d= -f2-); " +
            "printf '%s\\t%s\\t%s\\t%s\\n' \"$id\" \"$name\" \"$bgpath\" \"$owned\"; " +
            "done"]

        stdout: StdioCollector {
            onStreamFinished: {
                let rows = this.text.split("\n").filter(l => l.trim() !== "")
                let list = rows.map(line => {
                    let parts = line.split("\t")
                    return {
                        id: parts[0] || "",
                        name: parts[1] || parts[0] || "",
                        bg: parts[2] || "",
                        // Themes we ship (sddm-theme/<id> in the repo) mark
                        // themselves with X-Synoptik=true in metadata.desktop
                        // so they're never offered for deletion here.
                        protected: (parts[3] || "").trim() === "true"
                    }
                })
                list.sort((a, b) => a.name.localeCompare(b.name))
                root.themes = list
            }
        }
    }

    // SDDM reads /etc/sddm.conf then each /etc/sddm.conf.d/*.conf in order,
    // later Current= values winning - `tail -1` mirrors that resolution.
    property Process activeThemeProc: Process {
        running: false
        command: ["sh", "-c",
            "grep -h '^Current=' /etc/sddm.conf /etc/sddm.conf.d/*.conf 2>/dev/null | tail -1 | cut -d= -f2"]

        stdout: StdioCollector {
            onStreamFinished: root.activeThemeId = this.text.trim()
        }
    }

    property Process applyProc: Process {
        running: false

        stderr: StdioCollector { id: applyError }

        onExited: (code) => {
            if (code === 0) {
                root.activeThemeId = root.pendingActionId
                root.statusText = "Greeter set. Takes effect at your next login."
                root.statusIsError = false
            } else {
                let err = applyError.text.trim()
                root.statusText = err.length > 0 ? err : "Could not apply the greeter (authentication cancelled?)."
                root.statusIsError = true
            }
            root.pendingActionId = ""
        }
    }

    property Process previewProc: Process {
        running: false
    }

    property Process deleteProc: Process {
        running: false

        stderr: StdioCollector { id: deleteError }

        onExited: (code) => {
            if (code === 0) {
                root.statusText = "Theme deleted."
                root.statusIsError = false
                root.refreshThemes()
            } else {
                let err = deleteError.text.trim()
                root.statusText = err.length > 0 ? err : "Could not delete the theme (authentication cancelled?)."
                root.statusIsError = true
            }
            root.pendingActionId = ""
        }
    }
}
