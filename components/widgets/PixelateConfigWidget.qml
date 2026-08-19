import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: root

    // Reusable Geometric / Square Toggle Switch Component matching ClockWidget
    component ToggleSwitch : Rectangle {
        id: sw
        property bool checked: false
        
        implicitWidth: 40
        implicitHeight: 22
        radius: 6
        color: checked ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2) : Qt.rgba(0, 0, 0, 0.4)
        border.width: sw.checked ? 2 : 1
        border.color: checked ? Config.accent : Qt.rgba(255, 255, 255, 0.15)

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        // Square Thumb / Slider
        Rectangle {
            id: thumb
            x: sw.checked ? (sw.width - width - 3) : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: 4
            color: sw.checked ? Config.accent : Qt.rgba(255, 255, 255, 0.2)
            border.width: 0
            border.color: sw.checked ? Qt.lighter(Config.accent, 1.2) : Qt.rgba(255, 255, 255, 0.25)

            Behavior on x { 
                NumberAnimation { 
                    duration: 160
                    easing.type: Easing.OutCubic 
                } 
            }
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }
        }
    }

    // Helper process to apply shader in Hyprland via Lua config eval
    Process {
        id: shaderUpdater
        property string script: ""
        command: ["python3", "-c", script]
    }

    // Writes shader parameters dynamically to disk and instructs Hyprland to load it
    function updateShader() {
        if (typeof Config.saveSettings === "function") Config.saveSettings()
        else if (typeof Config.save === "function") Config.save()

        if (!Config.pixelShaderEnabled) {
            shaderUpdater.script = "import subprocess\nsubprocess.run(['hyprctl', 'eval', 'hl.config({ decoration = { screen_shader = \"\" } })'])"
            shaderUpdater.running = true
            return
        }

        const pixelSize = (Config.pixelShaderSize || 2.0).toFixed(1)
        const levels = (Config.pixelShaderLevels || 32.0).toFixed(1)
        const dither = Config.pixelShaderDither !== false
        const grid = Config.pixelShaderGrid === true
        const boost = Config.pixelShaderBoost !== false
        const palette = Config.pixelShaderPalette || "default"

        // Construct GLSL shader script with selected parameters
        let glsl = `#extension GL_OES_standard_derivatives : enable
precision highp float;
varying vec2 v_texcoord;
uniform sampler2D tex;

float get_bayer(vec2 coord) {
    int x = int(mod(coord.x, 4.0));
    int y = int(mod(coord.y, 4.0));
    vec4 row;
    if (y == 0)      row = vec4(0.0, 12.0, 3.0, 15.0);
    else if (y == 1) row = vec4(8.0, 4.0, 11.0, 7.0);
    else if (y == 2) row = vec4(2.0, 14.0, 1.0, 13.0);
    else             row = vec4(10.0, 6.0, 9.0, 5.0);
    float val = row.w;
    if (x == 0) val = row.x; else if (x == 1) val = row.y; else if (x == 2) val = row.z;
    return val / 16.0;
}

void main() {
    float pixel_size = ${pixelSize};
    float color_levels = ${levels};

    vec2 pixel_uv = vec2(abs(dFdx(v_texcoord.x)), abs(dFdy(v_texcoord.y)));
    vec2 step_size = pixel_uv * pixel_size;
    vec2 blockCoord = (floor(v_texcoord / step_size) + 0.5) * step_size;
    vec4 baseColor = texture2D(tex, blockCoord);

    vec2 grid_pos = floor(v_texcoord / step_size);
    ${dither ? "float dither = (get_bayer(grid_pos) - 0.5) * (1.0 / color_levels);" : "float dither = 0.0;"}

    vec3 color = floor((baseColor.rgb + dither) * color_levels) / color_levels;
    ${boost ? "color = clamp((color - 0.5) * 1.08 + 0.5, 0.0, 1.0);" : ""}
    ${grid ? `vec2 block_uv = fract(v_texcoord / step_size);
    float border = step(0.12, block_uv.x) * step(0.12, block_uv.y) * step(block_uv.x, 0.88) * step(block_uv.y, 0.88);
    color *= mix(0.85, 1.0, border);` : ""}

    ${palette === "gameboy" ? `float lum = dot(color, vec3(0.299, 0.587, 0.114));
    float shade = floor(lum * 4.0) / 3.0;
    color = mix(vec3(0.06, 0.22, 0.06), vec3(0.61, 0.73, 0.06), shade);` : ""}
    ${palette === "amber" ? `float lum = dot(color, vec3(0.299, 0.587, 0.114));
    color = vec3(lum * 1.0, lum * 0.7, lum * 0.1);` : ""}

    gl_FragColor = vec4(color, baseColor.a);
}`

        // Write file safely and invoke hyprctl eval without shell escape hazards
        let py = "import os, subprocess\n" +
            "p = os.path.expanduser('~/.config/hypr/shaders/pixelate.frag')\n" +
            "os.makedirs(os.path.dirname(p), exist_ok=True)\n" +
            "with open(p, 'w') as f:\n" +
            "    f.write(" + JSON.stringify(glsl) + ")\n" +
            "cmd = 'hl.config({ decoration = { screen_shader = \"' + p + '\" } })'\n" +
            "subprocess.run(['hyprctl', 'eval', cmd])\n"

        shaderUpdater.script = py
        shaderUpdater.running = true
    }

    RowLayout {
        anchors.fill: parent
        spacing: 20

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            spacing: 12

            Text {
                text: "8-BIT RETRO SHADER CONFIGURATION"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontSubhead)
                font.bold: true
            }

            // TOGGLE: ENABLE SHADER
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 0
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: "Enable 8-Bit Screen Shader"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Render displays through dynamic pixelation and color quantization"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        wrapMode: Text.WordWrap
                    }
                }

                ToggleSwitch {
                    checked: Config.pixelShaderEnabled === true

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Config.pixelShaderEnabled = !Config.pixelShaderEnabled
                            root.updateShader()
                        }
                    }
                }
            }

            // SUB-OPTIONS CONTAINER (Dimmed & Disabled when master toggle is OFF)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                enabled: Config.pixelShaderEnabled === true
                opacity: Config.pixelShaderEnabled ? 1.0 : 0.4

                Behavior on opacity { NumberAnimation { duration: 160 } }

                // PIXEL DENSITY / SCALE
                ColumnLayout {
                    spacing: 6

                    Text {
                        text: "PIXEL SCALE"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 8

                        Repeater {
                            model: [
                                { name: "Subtle (2px)", val: 2.0 },
                                { name: "Retro (3px)", val: 3.0 },
                                { name: "Chunky (4px)", val: 4.0 }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: 130
                                implicitHeight: 36
                                radius: Config.cornerRadius / 2

                                readonly property bool isSelected: (Config.pixelShaderSize || 2.0) === modelData.val
                                color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (szHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                                border.width: isSelected ? 2 : 0
                                border.color: Config.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: isSelected ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: isSelected
                                }

                                TapHandler { 
                                    onTapped: {
                                        Config.pixelShaderSize = modelData.val
                                        root.updateShader()
                                    }
                                }
                                HoverHandler { id: szHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }

                // COLOR QUANTIZATION (BIT DEPTH)
                ColumnLayout {
                    spacing: 6

                    Text {
                        text: "COLOR DEPTH"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 8

                        Repeater {
                            model: [
                                { name: "32 Steps (Clean)", val: 32.0 },
                                { name: "16 Steps (16-Bit)", val: 16.0 },
                                { name: "8 Steps (8-Bit)", val: 8.0 },
                                { name: "256 (True Color)", val: 256.0 }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: 130
                                implicitHeight: 36
                                radius: Config.cornerRadius / 2

                                readonly property bool isSelected: (Config.pixelShaderLevels || 32.0) === modelData.val
                                color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (clHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                                border.width: isSelected ? 2 : 0
                                border.color: Config.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: isSelected ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: isSelected
                                }

                                TapHandler { 
                                    onTapped: {
                                        Config.pixelShaderLevels = modelData.val
                                        root.updateShader()
                                    }
                                }
                                HoverHandler { id: clHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }

                // PALETTE PRESET
                ColumnLayout {
                    spacing: 6

                    Text {
                        text: "COLOR PALETTE"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 8

                        Repeater {
                            model: [
                                { name: "RGB True", id: "default" },
                                { name: "Game Boy DMG", id: "gameboy" },
                                { name: "Amber CRT", id: "amber" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: 130
                                implicitHeight: 36
                                radius: Config.cornerRadius / 2

                                readonly property bool isSelected: (Config.pixelShaderPalette || "default") === modelData.id
                                color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (palHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                                border.width: isSelected ? 2 : 0
                                border.color: Config.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: isSelected ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: isSelected
                                }

                                TapHandler { 
                                    onTapped: {
                                        Config.pixelShaderPalette = modelData.id
                                        root.updateShader()
                                    }
                                }
                                HoverHandler { id: palHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }

                // EFFECT OPTIONS
                ColumnLayout {
                    spacing: 8

                    Text {
                        text: "SHADER OPTIONS"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    // TOGGLE BAYER DITHERING
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.minimumWidth: 0
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: "Ordered Bayer Dithering"
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontBody)
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Cross-hatch color transitions instead of flat banding"
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                wrapMode: Text.WordWrap
                            }
                        }

                        ToggleSwitch {
                            checked: Config.pixelShaderDither !== false

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Config.pixelShaderDither = (Config.pixelShaderDither === false)
                                    root.updateShader()
                                }
                            }
                        }
                    }

                    // TOGGLE PIXEL GRID
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.minimumWidth: 0
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: "Pixel Grid Lines"
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontBody)
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Simulate physical phosphor gaps between virtual pixels"
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                wrapMode: Text.WordWrap
                            }
                        }

                        ToggleSwitch {
                            checked: Config.pixelShaderGrid === true

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Config.pixelShaderGrid = (Config.pixelShaderGrid !== true)
                                    root.updateShader()
                                }
                            }
                        }
                    }

                    // TOGGLE ARCADE CONTRAST
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.minimumWidth: 0
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: "Arcade Contrast Boost"
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontBody)
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Slightly lifts saturation and contrast on dark UI elements"
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                wrapMode: Text.WordWrap
                            }
                        }

                        ToggleSwitch {
                            checked: Config.pixelShaderBoost !== false

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Config.pixelShaderBoost = (Config.pixelShaderBoost === false)
                                    root.updateShader()
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}