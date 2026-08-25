import QtQuick

QtObject {
    property var configRef: null

    // --- SHELL KEYBIND CUSTOMIZATION (SUPER EXCLUSIVE) ---
    readonly property var defaultKeybinds: ({
        "wallpaper":         { mod: "SUPER",         key: "B",     cmd: "qs -c Synoptik ipc call wallpaper toggle" },
        "launcher":          { mod: "SUPER",         key: "A",     cmd: "qs -c Synoptik ipc call launcher toggle" },
        "launcherosd":       { mod: "SUPER",         key: "F",     cmd: "qs -c Synoptik ipc call launcherosd toggle" },
        "settings":          { mod: "SUPER",         key: "Space", cmd: "qs -c Synoptik ipc call settings toggle" },
        "workspaceoverview": { mod: "SUPER",         key: "TAB",   cmd: "qs -c Synoptik ipc call workspaceoverview toggle" },
        "clipboard":         { mod: "SUPER + SHIFT", key: "V",     cmd: "qs -c Synoptik ipc call clipboard toggle" },
        "lockscreen":        { mod: "SUPER",         key: "L",     cmd: "qs -c Synoptik ipc call lockscreen toggle" },
        "shader":            { mod: "CTRL + ALT",    key: "P",     cmd: "qs -c Synoptik ipc call shader toggle" }
    })

    property var keybinds: Object.assign({}, defaultKeybinds)

    function updateKeybind(action, mod, key) {
        let current = Object.assign({}, keybinds)
        let defaultCmd = defaultKeybinds[action] ? defaultKeybinds[action].cmd : ""
        let existingCmd = current[action] ? current[action].cmd : defaultCmd

        current[action] = {
            mod: mod,
            key: key,
            cmd: existingCmd
        }

        keybinds = current
        configRef.syncHyprlandBorders()
        configRef.saveSettings()
    }

    function resetKeybinds() {
        keybinds = Object.assign({}, defaultKeybinds)
        configRef.syncHyprlandBorders()
        configRef.saveSettings()
    }
}
