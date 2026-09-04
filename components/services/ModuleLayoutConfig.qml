import QtQuick

QtObject {
    property var configRef: null

    // --- ICON MAP & OVERRIDES ---
    property var iconOverrides: ({})

    readonly property var defaultIcons: ({
        "power": "electrical_services",
        "recorder": "videocam",
        "mirror": "photo_camera",
        "screenshot": "crop",
        "wallpaper": "wall_art",
        "settings": "build",
        "launcher": "terminal_2",
        "audio": "ear_sound",
        "sys": "neurology",
        "batt": "battery_android_frame_full",
        "cc": "widgets",
        "search": "search",
        "network": "lan",
        "notifications": "inbox",
        "clipboard": "content_paste",
        "clock": "calendar_month",
        "overview": "select_window_2",
        "apps": "view_apps",
        "magic": "kid_star",
        "magic_active": "family_star",
        "music": "music_note",
        "music_active": "genres",
        "private": "lock",
        "private_active": "lock_open"
    })

    function getIcon(iconId) {
        if (iconOverrides && iconOverrides[iconId]) {
            return iconOverrides[iconId]
        }
        return defaultIcons[iconId] || "help_outline"
    }

    function setIconOverride(iconId, glyphName) {
        let current = Object.assign({}, iconOverrides)
        current[iconId] = glyphName
        iconOverrides = current
        if (configRef) configRef.saveSettings()
    }

    function resetIcons() {
        iconOverrides = {}
        if (configRef) configRef.saveSettings()
    }

    // --- ICON GROUPS COLLAPSE & PINNING STATE ---
    property bool leftCardCollapsed: false
    property bool rightCardCollapsed: false
    property var pinnedIcons: ({})

    function togglePin(iconId) {
        let temp = Object.assign({}, pinnedIcons)
        temp[iconId] = !temp[iconId]
        pinnedIcons = temp
        if (configRef) configRef.saveSettings()
    }

    function isPinned(iconId) {
        return !!pinnedIcons[iconId]
    }

    onLeftCardCollapsedChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onRightCardCollapsedChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }

    // --- DYNAMIC MODULE ORDERING ---
    property var leftCardOrder: ["power", "settings", "wallpaper", "launcher", "recorder", "mirror", "audio", "batt", "network", "clipboard", "screenshot"]
    property var rightCardOrder: ["clock", "cc"]

    function moveModule(cardKey, iconId, direction) {
        let list = (cardKey === "left" ? leftCardOrder : rightCardOrder).slice()
        let idx = list.indexOf(iconId)
        if (idx === -1) return

        let targetIdx = idx + direction
        if (targetIdx < 0 || targetIdx >= list.length) return

        let item = list.splice(idx, 1)[0]
        list.splice(targetIdx, 0, item)

        if (cardKey === "left") leftCardOrder = list
        else rightCardOrder = list

        if (configRef) configRef.saveSettings()
    }
}
