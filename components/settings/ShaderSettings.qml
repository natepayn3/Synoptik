import QtQuick
import ".."

SettingsPage {
    id: root

    title: "Retro Shader"
    description: "Post-processing fragment shaders applied across your displays."
    icon: "videogame_asset"

    readonly property bool shaderEnabled: Config.pixelShaderEnabled === true
    readonly property string shaderMode: Config.pixelShaderMode || "pixelate"

    // Every option on this page has to call Config.updateShader() after the
    // assignment - the shader source is rebuilt from these values rather than
    // bound to them, so a write alone changes nothing on screen.
    function apply() {
        Config.updateShader()
    }

    SettingsCard {
        title: "Screen Shader"
        icon: "videogame_asset"

        SettingsToggleRow {
            title: "Enable Screen Shader"
            subtitle: "Apply custom post-processing fragment shaders across your displays"
            checked: Config.pixelShaderEnabled === true
            onToggled: {
                Config.pixelShaderEnabled = !Config.pixelShaderEnabled
                root.apply()
            }
        }

        SettingsField {
            label: "Preset"
            active: root.shaderEnabled

            SettingsSegmented {
                currentValue: root.shaderMode
                model: [
                    { label: "Pixelate / 8-Bit",  value: "pixelate", icon: "grid_view" },
                    { label: "Arcade CRT",        value: "crt",      icon: "tv_gen" },
                    { label: "Macintosh 1-Bit",   value: "mac1bit",  icon: "desktop_mac" }
                ]
                onSelected: value => {
                    Config.pixelShaderMode = value
                    root.apply()
                }
            }
        }
    }

    // The remaining cards drive uniforms that only the pixelate shader reads;
    // the CRT and 1-bit presets ignore them entirely, so they collapse rather
    // than sit there dimmed and misleading.
    SettingsCard {
        title: "Pixelation"
        icon: "grid_view"
        bodyEnabled: root.shaderEnabled
        visible: root.shaderMode === "pixelate"

        SettingsField {
            label: "Pixel Scale"

            SettingsSegmented {
                currentValue: Config.pixelShaderSize || 2.0
                model: [
                    { label: "Subtle (2px)", value: 2.0 },
                    { label: "Retro (3px)",  value: 3.0 },
                    { label: "Chunky (4px)", value: 4.0 }
                ]
                onSelected: value => {
                    Config.pixelShaderSize = value
                    root.apply()
                }
            }
        }

        SettingsField {
            label: "Colour Depth"

            SettingsSegmented {
                currentValue: Config.pixelShaderLevels || 32.0
                model: [
                    { label: "32 Steps (Clean)",   value: 32.0 },
                    { label: "16 Steps (16-Bit)",  value: 16.0 },
                    { label: "8 Steps (8-Bit)",    value: 8.0 },
                    { label: "256 (True Colour)",  value: 256.0 }
                ]
                onSelected: value => {
                    Config.pixelShaderLevels = value
                    root.apply()
                }
            }
        }

        SettingsField {
            label: "Palette"

            SettingsSegmented {
                currentValue: Config.pixelShaderPalette || "default"
                model: [
                    { label: "RGB True",     value: "default" },
                    { label: "Game Boy DMG", value: "gameboy" },
                    { label: "Amber CRT",    value: "amber" }
                ]
                onSelected: value => {
                    Config.pixelShaderPalette = value
                    root.apply()
                }
            }
        }
    }

    SettingsCard {
        title: "Shader Options"
        icon: "tune"
        bodyEnabled: root.shaderEnabled
        visible: root.shaderMode === "pixelate"

        SettingsToggleRow {
            title: "Ordered Bayer Dithering"
            subtitle: "Cross-hatch colour transitions instead of flat banding"
            checked: Config.pixelShaderDither !== false
            onToggled: {
                Config.pixelShaderDither = (Config.pixelShaderDither === false)
                root.apply()
            }
        }

        SettingsToggleRow {
            title: "Pixel Grid Lines"
            subtitle: "Simulate physical phosphor gaps between virtual pixels"
            checked: Config.pixelShaderGrid === true
            onToggled: {
                Config.pixelShaderGrid = (Config.pixelShaderGrid !== true)
                root.apply()
            }
        }

        SettingsToggleRow {
            title: "Arcade Contrast Boost"
            subtitle: "Slightly lifts saturation and contrast on dark UI elements"
            checked: Config.pixelShaderBoost !== false
            onToggled: {
                Config.pixelShaderBoost = (Config.pixelShaderBoost === false)
                root.apply()
            }
        }
    }
}
