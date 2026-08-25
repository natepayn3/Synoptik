import QtQuick

QtObject {
    property var configRef: null

    // --- WORKSPACES CONFIGURATION ---
    property string workspaceStyle: "pill"
    property bool workspaceGlow: true
    property bool workspaceScroll: true
    property bool workspaceTooltips: true
    property bool workspaceShowAddBtn: true
    property bool workspaceShowOverviewBtn: true
    property bool workspaceShowSpecial: true
    property string workspaceContainerStyle: "plain"

    onWorkspaceStyleChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onWorkspaceGlowChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onWorkspaceScrollChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onWorkspaceTooltipsChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onWorkspaceShowAddBtnChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onWorkspaceShowOverviewBtnChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onWorkspaceShowSpecialChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onWorkspaceContainerStyleChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
}
