import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: pixelShaderRoot

    property var configRef: null

    // --- RETRO SCREEN SHADER STATE & PERSISTENCE ---
    property bool pixelShaderEnabled: false
    property string pixelShaderMode: "pixelate"
    property real pixelShaderSize: 2.0
    property real pixelShaderLevels: 32.0
    property string pixelShaderPalette: "default"
    property bool pixelShaderDither: true
    property bool pixelShaderGrid: false
    property bool pixelShaderBoost: true

    onPixelShaderEnabledChanged: { if (configRef && configRef.isLoaded) { configRef.saveSettings(); updateShader() } }
    onPixelShaderModeChanged: { if (configRef && configRef.isLoaded) { configRef.saveSettings(); updateShader() } }
    onPixelShaderSizeChanged: { if (configRef && configRef.isLoaded) { configRef.saveSettings(); updateShader() } }
    onPixelShaderLevelsChanged: { if (configRef && configRef.isLoaded) { configRef.saveSettings(); updateShader() } }
    onPixelShaderPaletteChanged: { if (configRef && configRef.isLoaded) { configRef.saveSettings(); updateShader() } }
    onPixelShaderDitherChanged: { if (configRef && configRef.isLoaded) { configRef.saveSettings(); updateShader() } }
    onPixelShaderGridChanged: { if (configRef && configRef.isLoaded) { configRef.saveSettings(); updateShader() } }
    onPixelShaderBoostChanged: { if (configRef && configRef.isLoaded) { configRef.saveSettings(); updateShader() } }

    // --- RETRO SHADER IPC HANDLER ---
    property IpcHandler shaderIpc: IpcHandler {
        target: "shader"

        function toggle() {
            pixelShaderRoot.pixelShaderEnabled = !pixelShaderRoot.pixelShaderEnabled
            pixelShaderRoot.updateShader()
        }
    }

    // Debounce timer for shader updates
    property Timer shaderDebounce: Timer {
        interval: 200
        repeat: false
        onTriggered: configRef.shaderService.updateShader()
    }

    function updateShader() {
        if (!configRef || !configRef.isLoaded) return
        configRef.saveSettings()
        shaderDebounce.restart()
    }
}
