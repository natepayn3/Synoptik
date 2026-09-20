pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."

SettingsPage {
    id: root

    title: "Keyboard"
    description: "Global shortcuts and the on-screen keyboard overlay."
    icon: "keyboard"

    // Which binding is currently listening for a key combination, by id.
    // Empty means nothing is recording.
    property string recordingId: ""

    function beginRecording(bindId) {
        root.recordingId = bindId
        keyListener.forceActiveFocus()
    }

    detached: Item {
        id: keyListener

        focus: root.recordingId !== ""

        Keys.onPressed: event => {
            if (root.recordingId === "") return

            if (event.key === Qt.Key_Escape) {
                root.recordingId = ""
                event.accepted = true
                return
            }

            // Ignore standalone modifier presses - they're the prefix of a
            // combination, not a binding on their own.
            if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Meta, Qt.Key_Alt, Qt.Key_Super_L, Qt.Key_Super_R].includes(event.key)) {
                event.accepted = true
                return
            }

            // Strict allowlist validation and keysym conversion
            let keyStr = ""
            if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z) {
                keyStr = String.fromCharCode(event.key)
            } else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                keyStr = String.fromCharCode(event.key)
            } else if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F12) {
                keyStr = "F" + (event.key - Qt.Key_F1 + 1)
            } else {
                switch (event.key) {
                    case Qt.Key_Space:        keyStr = "Space"; break
                    case Qt.Key_Tab:
                    case Qt.Key_Backtab:      keyStr = "TAB"; break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:        keyStr = "Return"; break
                    case Qt.Key_Backspace:    keyStr = "BackSpace"; break
                    case Qt.Key_Delete:       keyStr = "Delete"; break
                    case Qt.Key_Left:         keyStr = "Left"; break
                    case Qt.Key_Right:        keyStr = "Right"; break
                    case Qt.Key_Up:           keyStr = "Up"; break
                    case Qt.Key_Down:         keyStr = "Down"; break
                    case Qt.Key_Home:         keyStr = "Home"; break
                    case Qt.Key_End:          keyStr = "End"; break
                    case Qt.Key_PageUp:       keyStr = "Page_Up"; break
                    case Qt.Key_PageDown:     keyStr = "Page_Down"; break
                    case Qt.Key_BracketLeft:  keyStr = "bracketleft"; break
                    case Qt.Key_BracketRight: keyStr = "bracketright"; break
                    case Qt.Key_Semicolon:    keyStr = "semicolon"; break
                    case Qt.Key_Apostrophe:   keyStr = "apostrophe"; break
                    case Qt.Key_Comma:        keyStr = "comma"; break
                    case Qt.Key_Period:       keyStr = "period"; break
                    case Qt.Key_Slash:        keyStr = "slash"; break
                    case Qt.Key_Backslash:    keyStr = "backslash"; break
                    case Qt.Key_Minus:        keyStr = "minus"; break
                    case Qt.Key_Equal:        keyStr = "equal"; break
                    case Qt.Key_QuoteLeft:    keyStr = "grave"; break
                    default:
                        event.accepted = true
                        return
                }
            }

            let mods = []
            if (event.modifiers & Qt.MetaModifier || event.modifiers === 0) mods.push("SUPER")
            if (event.modifiers & Qt.ControlModifier) mods.push("CTRL")
            if (event.modifiers & Qt.AltModifier) mods.push("ALT")
            if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT")

            Config.updateKeybind(root.recordingId, mods.join(" + "), keyStr)
            root.recordingId = ""
            event.accepted = true
        }
    }

    SettingsCard {
        title: "Widget Shortcuts"
        icon: "bolt"
        subtitle: root.recordingId !== ""
            ? "Press any key combination (Esc to cancel)…"
            : "Click a shortcut to remap it. Changes write to hypr_style.lua."

        accessory: SettingsButton {
            label: "Reset Defaults"
            icon: "restart_alt"
            onClicked: Config.resetKeybinds()
        }

        SettingsList {
            Repeater {
                model: [
                    { id: "launcherosd",       name: "Command Launcher",    icon: "bolt" },
                    { id: "settings",          name: "Settings Panel",      icon: "build" },
                    { id: "wallpaper",         name: "Wallpaper Picker",    icon: "wall_art" },
                    { id: "workspaceoverview", name: "Workspace Overview",  icon: "select_window_2" },
                    { id: "clipboard",         name: "Clipboard Manager",   icon: "content_paste" },
                    { id: "lockscreen",        name: "Lock Screen",         icon: "lock" },
                    { id: "shader",            name: "Retro Screen Shader", icon: "videogame_asset" }
                ]

                delegate: SettingsOptionRow {
                    id: bindRow

                    required property var modelData

                    readonly property bool isRecording: root.recordingId === bindRow.modelData.id

                    // Falls back to the compiled-in default so a binding that has
                    // never been customised still shows what it currently is,
                    // rather than an empty badge.
                    readonly property var bindData: (Config.keybinds
                            && Config.keybinds[bindRow.modelData.id]
                            && Config.keybinds[bindRow.modelData.id].key)
                        ? Config.keybinds[bindRow.modelData.id]
                        : (Config.defaultKeybinds[bindRow.modelData.id] || {})

                    title: bindRow.modelData.name
                    icon: bindRow.modelData.icon
                    selected: bindRow.isRecording
                    onClicked: root.beginRecording(bindRow.modelData.id)

                    actions: Rectangle {
                        implicitHeight: 28
                        implicitWidth: Math.max(88, keyLabel.implicitWidth + 20)
                        radius: SettingsStyle.controlRadius
                        color: bindRow.isRecording ? Config.accent : SettingsStyle.accentSoft
                        border.width: 1
                        border.color: SettingsStyle.accentLine

                        Behavior on color { ColorAnimation { duration: SettingsStyle.animFast } }

                        Text {
                            id: keyLabel

                            anchors.centerIn: parent
                            text: {
                                if (bindRow.isRecording) return "RECORDING…"
                                const m = bindRow.bindData.mod || "SUPER"
                                const k = bindRow.bindData.key || ""
                                return m + (k !== "" ? " + " + k : "")
                            }
                            color: bindRow.isRecording ? Config.bgBase : Config.accent
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                        }
                    }
                }
            }
        }
    }

    SettingsCard {
        title: "On-Screen Keyboard"
        icon: "keyboard"

        SettingsToggleRow {
            title: "Enable On-Screen Keyboard"
            subtitle: "Virtual touch-friendly keyboard overlay for touchscreens and quick input"
            checked: Config.showOsk !== false
            onToggled: Config.showOsk = (Config.showOsk === false)
        }

        SettingsField {
            label: "Layout Style"
            active: Config.showOsk !== false

            SettingsTileGrid {
                currentValue: Config.oskLayout || "Normal"
                columns: 3
                tileHeight: 64
                model: [
                    { label: "Normal",  value: "Normal",  icon: "keyboard",       desc: "Full standard" },
                    { label: "Minimal", value: "Minimal", icon: "keyboard_keys",  desc: "Compact view" },
                    { label: "Gamer",   value: "Gamer",   icon: "sports_esports", desc: "WASD oriented" }
                ]
                onSelected: value => Config.oskLayout = value
            }
        }
    }
}
