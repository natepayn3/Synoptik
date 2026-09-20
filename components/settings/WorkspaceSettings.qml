import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import ".."

SettingsPage {
    id: root

    title: "Workspaces"
    description: "Workspace indicator style, container frame and interaction behaviour."
    icon: "view_carousel"

    // Fake state for the live preview card only - never touches Hyprland.
    property int previewActiveWs: 2
    property bool previewOverviewActive: false
    property bool previewMagicActive: false
    readonly property var previewWorkspaces: [
        { id: 1, name: "Code",   windows: 2, icon: "terminal", appIcon: "utilities-terminal", activeApp: "Ghostty" },
        { id: 2, name: "Web",    windows: 4, icon: "globe",    appIcon: "firefox",            activeApp: "Firefox" },
        { id: 3, name: "Design", windows: 1, icon: "palette",  appIcon: "inkscape",           activeApp: "Figma" },
        { id: 4, name: "Chat",   windows: 3, icon: "chat",     appIcon: "discord",            activeApp: "Discord" }
    ]

    SettingsCard {
        title: "Live Preview"
        icon: "preview"
        subtitle: "Click the icons to test interactions - this preview is not your real workspaces."

        // Simulated Bar Container
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 64
            radius: Config.cornerRadius / 2
            color: Qt.rgba(0, 0, 0, 0.35)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.08)

            // Capsule wrapper (if enabled)
            Rectangle {
                anchors.centerIn: parent
                implicitHeight: 40
                implicitWidth: previewRow.implicitWidth + (Config.workspaceContainerStyle === "plain" ? 0 : 20)
                radius: (Config.workspaceContainerStyle === "bordered") ? 8 : 20
                color: Config.workspaceContainerStyle === "capsule" 
                    ? Qt.rgba(255, 255, 255, 0.08) 
                    : (Config.workspaceContainerStyle === "bordered" ? Qt.rgba(0, 0, 0, 0.18) : "transparent")
                border.width: Config.workspaceContainerStyle === "bordered" ? 1.5 : (Config.workspaceContainerStyle === "capsule" ? 1 : 0)
                border.color: Config.workspaceContainerStyle === "bordered" ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.5) : Qt.rgba(255, 255, 255, 0.12)

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    id: previewRow
                    anchors.centerIn: parent
                    spacing: 8

                    // Workspaces Group
                    RowLayout {
                        spacing: 8

                        Repeater {
                            model: root.previewWorkspaces

                            delegate: Rectangle {
                                id: previewPillItem
                                readonly property bool isActive: root.previewActiveWs === modelData.id
                                readonly property string style: Config.workspaceStyle || "pill"

                                // Width depends on selected style
                                implicitWidth: {
                                    if (style === "sliding") return isActive ? 32 : 10
                                    if (style === "numeric") return isActive ? 34 : 22
                                    if (style === "app_icons") return isActive ? 44 : 26
                                    if (style === "window_pips") return isActive ? 36 : 24
                                    if (style === "geometric") return isActive ? 32 : 14
                                    return isActive ? 32 : 10 // default pill
                                }
                                implicitHeight: {
                                    if (style === "sliding") return isActive ? 12 : 20
                                    if (style === "app_icons" || style === "numeric" || style === "window_pips") return 22
                                    return 12
                                }
                                radius: (style === "sliding") ? height / 3 : ((style === "geometric") ? 3 : height / 2)

                                color: {
                                    if (style === "geometric") {
                                        return isActive 
                                            ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.35) 
                                            : (pMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent")
                                    }
                                    return isActive ? Config.accent : (pMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.18) : "transparent")
                                }

                                border.width: (style === "sliding") ? (isActive ? 0 : 3) : (isActive ? (style === "geometric" ? 2 : 0) : 2)
                                border.color: (style === "sliding")
                                    ? (isActive ? "transparent" : (pMouse.containsMouse ? Config.accent : Qt.rgba(255, 255, 255, 0.3)))
                                    : (isActive 
                                        ? (style === "geometric" ? Config.accent : "transparent") 
                                        : (pMouse.containsMouse ? Config.accent : Qt.rgba(255, 255, 255, 0.3)))

                                Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                // Glow on active/hovered
                                Glow {
                                    anchors.fill: parent
                                    source: previewPillItem
                                    radius: (Config.workspaceGlow !== false && (isActive || pMouse.containsMouse)) ? 8 : 0
                                    samples: 16
                                    color: Config.accent
                                    spread: 0.2
                                    transparentBorder: true
                                    visible: Config.workspaceGlow !== false && (isActive || pMouse.containsMouse)
                                    Behavior on radius { NumberAnimation { duration: 150 } }
                                }

                                // Content inside the pill (Numbers, Pips, App Icons)
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    // 1. NUMERIC STYLE
                                    Text {
                                        visible: (style === "numeric")
                                        text: modelData.id
                                        font.family: Config.sysFont
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: isActive ? Config.bgBase : Config.textMain
                                    }

                                    // 2. APP ICONS STYLE
                                    Text {
                                        visible: (style === "app_icons")
                                        text: modelData.icon === "terminal" ? "terminal" : (modelData.icon === "globe" ? "language" : (modelData.icon === "palette" ? "brush" : "forum"))
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 13
                                        color: isActive ? Config.bgBase : Config.textMain
                                    }

                                    // 3. WINDOW DENSITY PIPS
                                    Row {
                                        visible: (style === "window_pips")
                                        spacing: 2
                                        Repeater {
                                            model: Math.min(modelData.windows, 3)
                                            Rectangle {
                                                width: 3; height: 3; radius: 1.5
                                                color: isActive ? Config.bgBase : Config.accent
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: pMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.previewActiveWs = modelData.id
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        implicitWidth: 1
                        implicitHeight: 16
                        color: Qt.rgba(255, 255, 255, 0.15)
                        visible: (Config.workspaceShowAddBtn !== false) || (Config.workspaceShowOverviewBtn !== false) || (Config.workspaceShowSpecial !== false)
                    }

                    // Actions Group
                    RowLayout {
                        spacing: 4

                        // Add Button
                        Rectangle {
                            implicitWidth: 26; implicitHeight: 26; radius: 13
                            visible: Config.workspaceShowAddBtn !== false
                            color: addHover.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                font.family: Config.sysFont
                                font.pixelSize: 16
                                font.bold: true
                                color: addHover.containsMouse ? Config.accent : Qt.rgba(255, 255, 255, 0.5)
                            }

                            MouseArea {
                                id: addHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.previewWorkspaces.length < 6) {
                                        let nextId = root.previewWorkspaces.length + 1
                                        root.previewWorkspaces.push({ id: nextId, name: "New", windows: 1, icon: "terminal", appIcon: "terminal", activeApp: "App" })
                                        root.previewActiveWs = nextId
                                    }
                                }
                            }
                        }

                        // Overview Button
                        Rectangle {
                            implicitWidth: 26; implicitHeight: 26; radius: 13
                            visible: Config.workspaceShowOverviewBtn !== false
                            color: root.previewOverviewActive ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.3) : (ovHover.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent")
                            border.width: root.previewOverviewActive ? 1 : 0
                            border.color: Config.accent

                            Text {
                                anchors.centerIn: parent
                                text: Config.getIcon("overview")
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 15
                                color: (root.previewOverviewActive || ovHover.containsMouse) ? Config.accent : Qt.rgba(255, 255, 255, 0.5)
                            }

                            MouseArea {
                                id: ovHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.previewOverviewActive = !root.previewOverviewActive
                            }
                        }

                        // Special Workspace (Magic)
                        Rectangle {
                            implicitWidth: 26; implicitHeight: 26; radius: 13
                            visible: Config.workspaceShowSpecial !== false
                            color: root.previewMagicActive ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.3) : (magicHover.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent")
                            border.width: root.previewMagicActive ? 1 : 0
                            border.color: Config.accent

                            Text {
                                anchors.centerIn: parent
                                text: Config.getIcon("magic")
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 15
                                color: (root.previewMagicActive || magicHover.containsMouse) ? Config.accent : Qt.rgba(255, 255, 255, 0.5)
                            }

                            MouseArea {
                                id: magicHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.previewMagicActive = !root.previewMagicActive
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsCard {
        title: "Indicator Style"
        icon: "style"

        SettingsTileGrid {
            currentValue: Config.workspaceStyle || "pill"
            columns: 3
            model: [
                { label: "App Micro-Icons", value: "app_icons",   icon: "apps",       desc: "Running client icons",     preview: "term \u00b7 web \u00b7 chat" },
                { label: "Numeric Badges",  value: "numeric",     icon: "tag",        desc: "Bold index numbers",       preview: "1  [2]  3" },
                { label: "Window Pips",     value: "window_pips", icon: "more_horiz", desc: "Density micro-dots",       preview: "\u2022 \u2022\u2022\u2022 \u2022" },
                { label: "Dynamic Pill",    value: "pill",        icon: "view_stream",desc: "Morphing accent capsule",  preview: "\u25cf \u2501\u2501 \u25cf" },
                { label: "Morphing Pillar", value: "sliding",     icon: "swap_horiz", desc: "Narrow tall / wide short", preview: "\u25ae  \u2501\u2501  \u25ae" },
                { label: "Cyber Geometric", value: "geometric",   icon: "diamond",    desc: "Segmented wireframe",      preview: "\u25c7  \u25c6  \u25c7" }
            ]
            onSelected: value => Config.workspaceStyle = value
        }
    }

    SettingsCard {
        title: "Container Frame"
        icon: "crop_free"

        SettingsTileGrid {
            currentValue: Config.workspaceContainerStyle || "plain"
            columns: 3
            tileHeight: 68
            model: [
                { label: "Frameless Minimal", value: "plain",    icon: "border_clear", desc: "No surrounding pill frame" },
                { label: "Frosted Capsule",   value: "capsule",  icon: "view_stream",  desc: "Rounded glass capsule" },
                { label: "Cyber Frame",       value: "bordered", icon: "border_style", desc: "Sharp bordered outline" }
            ]
            onSelected: value => Config.workspaceContainerStyle = value
        }
    }

    SettingsCard {
        title: "Interaction & Motion"
        icon: "motion_photos_on"

        SettingsToggleRow {
            title: "Ambient Indicator Glow"
            subtitle: "Soft accent bloom surrounding active and hovered workspace pills"
            checked: Config.workspaceGlow !== false
            onToggled: Config.workspaceGlow = (Config.workspaceGlow === false)
        }

        SettingsToggleRow {
            title: "Mouse Wheel Quick-Switch"
            subtitle: "Scroll the mouse wheel over the workspace strip to cycle through desktops"
            checked: Config.workspaceScroll !== false
            onToggled: Config.workspaceScroll = (Config.workspaceScroll === false)
        }

        SettingsToggleRow {
            title: "Workspace Hover Tooltips"
            subtitle: "Floating badge with workspace name, window count and active application on hover"
            checked: Config.workspaceTooltips !== false
            onToggled: Config.workspaceTooltips = (Config.workspaceTooltips === false)
        }
    }

    SettingsCard {
        title: "Buttons & Scratchpads"
        icon: "add_box"

        SettingsToggleRow {
            title: "Show Add Workspace Button (+)"
            subtitle: "Spawn and focus the next available empty workspace"
            checked: Config.workspaceShowAddBtn !== false
            onToggled: Config.workspaceShowAddBtn = (Config.workspaceShowAddBtn === false)
        }

        SettingsToggleRow {
            title: "Show Overview Button"
            subtitle: "Trigger the full-screen spatial Workspace Overview popup"
            checked: Config.workspaceShowOverviewBtn !== false
            onToggled: Config.workspaceShowOverviewBtn = (Config.workspaceShowOverviewBtn === false)
        }

        SettingsToggleRow {
            title: "Show Special Workspaces (Scratchpads)"
            subtitle: "Shortcut tokens for the magic, music and private scratchpads when active or occupied"
            checked: Config.workspaceShowSpecial !== false
            onToggled: Config.workspaceShowSpecial = (Config.workspaceShowSpecial === false)
        }
    }
}
