import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import "./settings"
import "./widgets"

Item {
    id: settingsRoot

    implicitWidth: 1000
    implicitHeight: 700
    clip: true

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    property int activeSection: Config.lastSettingsSection
    property bool isMaximized: false
    property bool visualsExpanded: false
    property bool connectivityExpanded: false
    property bool widgetsExpanded: false

    // Single source of truth for every settings section. The id/name/icon/category
    // mapping used to live in four hand-maintained places - two switch statements
    // (getSectionName/getSectionIcon), two id-array functions
    // (getSectionCategory/expandActiveCategory) and three nav Repeater model
    // literals - which had already drifted: section 16 rendered as "sliders" in the
    // sidebar but "dock" in the breadcrumb, section 13 was "Sounds" in one and
    // "System Sounds" in the other, and 14 (a section that no longer exists) was
    // still listed in expandActiveCategory. Everything below derives from this.
    //
    // `keywords` exists for the sidebar filter: what someone types when they don't
    // remember which panel a setting lives under ("psk" -> Wi-Fi, "font" ->
    // Typography, "crt" -> Retro Shader).
    readonly property var sectionCatalog: [
        { id: 0,  name: "Display",          icon: "aspect_ratio",    group: "VISUALS",      keywords: "monitor resolution refresh rate scale rotate rotation position arrangement hidpi screen vrr" },
        { id: 16, name: "Bar",              icon: "dock",            group: "VISUALS",      keywords: "panel taskbar position top bottom left right autohide floating island frame height margin module" },
        { id: 1,  name: "Appearance",       icon: "palette",         group: "VISUALS",      keywords: "theme color colour accent blur transparency opacity xray border gradient watermark iris night mode dark corner radius" },
        { id: 17, name: "Workspaces",       icon: "view_carousel",   group: "VISUALS",      keywords: "workspace indicator style glow scroll tooltip special overview" },
        { id: 2,  name: "Typography",       icon: "match_case",      group: "VISUALS",      keywords: "font family size scale text rendering antialias" },
        { id: 3,  name: "Wallpaper",        icon: "wallpaper",       group: "VISUALS",      keywords: "background image slideshow parallax wallhaven transition swww awww" },
        { id: 12, name: "Icons",            icon: "account_circle",  group: "VISUALS",      keywords: "icon glyph override module pin order material symbol" },
        { id: 21, name: "Audio Visualizer", icon: "graphic_eq",      group: "VISUALS",      keywords: "cava spectrum bar equalizer visualiser music beat breathe ambient" },

        { id: 4,  name: "Network",          icon: "lan",             group: "CONNECTIVITY", keywords: "ethernet vpn ip dns gateway connection nmcli interface" },
        { id: 5,  name: "Wi-Fi",            icon: "wifi",            group: "CONNECTIVITY", keywords: "wireless wlan ssid password psk scan connect hotspot" },
        { id: 6,  name: "Bluetooth",        icon: "bluetooth",       group: "CONNECTIVITY", keywords: "bt pair device headset battery mouse keyboard" },
        { id: 7,  name: "Weather",          icon: "thermostat",      group: "CONNECTIVITY", keywords: "forecast temperature location zip city climate" },

        { id: 8,  name: "Mascot",           icon: "smart_toy",       group: "WIDGETS",      keywords: "pet gif character bounce phrase avatar" },
        { id: 9,  name: "Clock",            icon: "schedule",        group: "WIDGETS",      keywords: "time date desktop 12 24 hour second" },
        { id: 19, name: "System Info",      icon: "terminal",        group: "WIDGETS",      keywords: "sysinfo fetch neofetch cpu ram uptime kernel host gpu disk" },
        { id: 10, name: "Keyboard",         icon: "keyboard",        group: "WIDGETS",      keywords: "keybind shortcut hotkey osk on-screen layout binding" },
        { id: 13, name: "Sounds",           icon: "volume_up",       group: "WIDGETS",      keywords: "audio notification window sound effect volume wav" },
        { id: 15, name: "Lockscreen",       icon: "lock",            group: "WIDGETS",      keywords: "lock password blur idle hypridle security" },
        { id: 18, name: "Screensaver",      icon: "tv",              group: "WIDGETS",      keywords: "idle screen saver matrix bounce" },
        { id: 20, name: "Retro Shader",     icon: "videogame_asset", group: "WIDGETS",      keywords: "pixel crt dither palette shader retro effect scanline" },
        { id: 22, name: "Assistant",        icon: "support_agent",   group: "WIDGETS",      keywords: "ai llm ollama claude codex gemini chat model prompt" },

        { id: 11, name: "Shell",            icon: "terminal",        group: "SYSTEM",       keywords: "update git version reload restart about repository profile" }
    ]

    // Sidebar filter text. Empty = show everything, exactly as before.
    property string navFilter: ""

    function sectionById(sectionId) {
        for (let i = 0; i < sectionCatalog.length; i++) {
            if (sectionCatalog[i].id === sectionId) return sectionCatalog[i]
        }
        return null
    }

    function sectionsFor(group) {
        let q = navFilter.trim().toLowerCase()
        return sectionCatalog.filter(function(s) {
            if (s.group !== group) return false
            if (q === "") return true
            return s.name.toLowerCase().indexOf(q) !== -1 || s.keywords.indexOf(q) !== -1
        })
    }

    readonly property bool navFiltering: navFilter.trim() !== ""
    readonly property int navMatchCount: sectionsFor("VISUALS").length
        + sectionsFor("CONNECTIVITY").length + sectionsFor("WIDGETS").length

    function expandActiveCategory(sectionId) {
        let cat = sectionById(sectionId)
        if (!cat) return
        if (cat.group === "VISUALS") visualsExpanded = true
        else if (cat.group === "CONNECTIVITY") connectivityExpanded = true
        else if (cat.group === "WIDGETS") widgetsExpanded = true
    }

    function getSectionCategory(sectionId) {
        let cat = sectionById(sectionId)
        return cat ? cat.group : "GENERAL"
    }

    function getSectionName(sectionId) {
        let cat = sectionById(sectionId)
        return cat ? cat.name : "Settings"
    }

    function getSectionIcon(sectionId) {
        let cat = sectionById(sectionId)
        return cat ? cat.icon : "settings"
    }

    Component.onCompleted: {
        activeSection = Config.lastSettingsSection
        expandActiveCategory(activeSection)
    }

    Connections {
        target: Config
        function onLastSettingsSectionChanged() {
            if (settingsRoot.activeSection !== Config.lastSettingsSection) {
                settingsRoot.activeSection = Config.lastSettingsSection
                settingsRoot.expandActiveCategory(settingsRoot.activeSection)
            }
        }
    }

    onActiveSectionChanged: {
        if (Config.isLoaded && Config.lastSettingsSection !== activeSection) {
            Config.lastSettingsSection = activeSection
        }
        expandActiveCategory(activeSection)
        contentFadeAnim.restart()
        contentSlideAnim.restart()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: settingsRoot.cardMargin
        spacing: settingsRoot.cardMargin / 2

        // ================= HEADER & BREADCRUMB =================
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Title & Glowing Badge
            RowLayout {
                spacing: 10
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 8
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.32) }
                        GradientStop { position: 1.0; color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.08) }
                    }
                    border.width: 1
                    border.color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.3)

                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 2
                        radius: 10
                        samples: 21
                        color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.4)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "settings"
                        color: Config.accent
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 18
                    }
                }

                Item {
                    implicitWidth: settingsTitleText.implicitWidth
                    implicitHeight: settingsTitleText.implicitHeight

                    Glow {
                        anchors.fill: settingsTitleText
                        source: settingsTitleText
                        radius: 8
                        samples: 16
                        color: Config.accent
                        spread: 0.2
                        transparentBorder: true
                        visible: Config.clockShowGlow
                    }

                    Text {
                        id: settingsTitleText
                        anchors.fill: parent
                        text: "SETTINGS"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontTitle)
                        font.bold: true
                        font.italic: true
                    }
                }
            }

            // Dynamic Breadcrumb Chip
            Rectangle {
                implicitHeight: 26
                implicitWidth: breadcrumbRow.implicitWidth + 16
                radius: 13
                color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.08)
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: breadcrumbRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: settingsRoot.getSectionCategory(settingsRoot.activeSection)
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                    }

                    Text {
                        text: "chevron_right"
                        color: Config.textMuted
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 14
                    }

                    Text {
                        text: settingsRoot.getSectionName(settingsRoot.activeSection)
                        color: Config.accent
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Close Button
            Rectangle {
                implicitWidth: 32
                implicitHeight: 32
                radius: 16
                scale: closeMouseArea.pressed ? 0.9 : 1.0
                color: closeHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.04)
                border.width: 1
                border.color: closeHover.hovered ? Qt.rgba(255, 255, 255, 0.2) : Qt.rgba(255, 255, 255, 0.06)

                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: "close"
                    color: closeHover.hovered ? Config.textMain : Config.textMuted
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 18
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Config.showSettings = false
                        if (mascotSettingsLoader.item) mascotSettingsLoader.item.showBrowser = false
                    }
                }
                HoverHandler { id: closeHover }
            }
        }

        // ================= TWO-COLUMN MASTER / DETAIL =================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: settingsRoot.cardMargin / 2

            // ================= LEFT SIDEBAR =================
            Rectangle {
                Layout.preferredWidth: 260
                Layout.maximumWidth: 260
                Layout.fillHeight: true
                color: Qt.rgba(255, 255, 255, 0.03)
                radius: (Config.surfaceRadius || 18) * 0.75
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.06)
                clip: true

                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 6
                    radius: 24
                    samples: 33
                    color: Qt.rgba(0, 0, 0, 0.35)
                }

                Flickable {
                    id: navFlickable
                    anchors.fill: parent
                    anchors.margins: 10
                    contentHeight: leftNavColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        id: navScrollBar
                        parent: navFlickable.parent
                        anchors.top: parent.top
                        anchors.topMargin: 6
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        width: 4
                        policy: ScrollBar.AsNeeded
                        
                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: navScrollBar.pressed ? Config.accent : Qt.rgba(255, 255, 255, 0.2)
                        }
                    }

                    ColumnLayout {
                        id: leftNavColumn
                        width: parent.width - 8
                        spacing: 8

                        // Sidebar filter. 21 sections across three collapsed groups
                        // meant the only way to find a setting was to remember which
                        // group it lived under and expand them one at a time.
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: 8
                            color: Qt.rgba(255, 255, 255, 0.05)
                            border.width: 1
                            border.color: navSearchInput.activeFocus
                                ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.6)
                                : Qt.rgba(255, 255, 255, 0.08)

                            Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 6
                                spacing: 6

                                Text {
                                    text: "search"
                                    color: settingsRoot.navFiltering ? Config.accent : Config.textMuted
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 15
                                }

                                TextInput {
                                    id: navSearchInput
                                    Layout.fillWidth: true
                                    color: Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    clip: true
                                    selectByMouse: true
                                    verticalAlignment: TextInput.AlignVCenter

                                    onTextChanged: settingsRoot.navFilter = text

                                    // Escape clears the filter first and only closes the
                                    // panel on a second press, so a stray Escape while
                                    // searching doesn't throw the whole panel away.
                                    Keys.onEscapePressed: event => {
                                        if (text !== "") { text = ""; event.accepted = true }
                                        else event.accepted = false
                                    }

                                    // Enter jumps straight to the only remaining match.
                                    Keys.onReturnPressed: {
                                        if (settingsRoot.navMatchCount !== 1) return
                                        let hit = settingsRoot.sectionsFor("VISUALS")
                                            .concat(settingsRoot.sectionsFor("CONNECTIVITY"))
                                            .concat(settingsRoot.sectionsFor("WIDGETS"))[0]
                                        if (hit) settingsRoot.activeSection = hit.id
                                    }

                                    HoverHandler { cursorShape: Qt.IBeamCursor }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Search settings..."
                                        visible: navSearchInput.text === ""
                                        color: Qt.rgba(255, 255, 255, 0.3)
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontCaption)
                                        font.italic: true
                                    }
                                }

                                Text {
                                    text: "close"
                                    visible: settingsRoot.navFiltering
                                    color: clearHover.hovered ? Config.textMain : Config.textMuted
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 14

                                    HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: navSearchInput.text = "" }
                                }
                            }
                        }

                        // Shown instead of the (now empty) group list when nothing matches.
                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            visible: settingsRoot.navFiltering && settingsRoot.navMatchCount === 0
                            text: "No settings match \u201C" + settingsRoot.navFilter.trim() + "\u201D"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.italic: true
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // ---------------- CATEGORY 1: VISUALS ----------------
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            // A group with no matches drops out of the sidebar entirely
                            // while filtering, rather than sitting there as an empty header.
                            visible: settingsRoot.sectionsFor("VISUALS").length > 0
                            radius: 8
                            color: visualsCatHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent"

                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: "palette"
                                    color: settingsRoot.visualsExpanded ? Config.accent : Config.textMuted
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: "VISUALS"
                                    color: settingsRoot.visualsExpanded ? Config.textMain : Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: settingsRoot.visualsExpanded ? "expand_more" : "chevron_right"
                                    color: Config.textMuted
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 18
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsRoot.visualsExpanded = !settingsRoot.visualsExpanded
                            }
                            HoverHandler { id: visualsCatHover }
                        }

                        ColumnLayout {
                            // While filtering, groups auto-open so matches are visible
                            // without the user having to expand each one by hand.
                            visible: settingsRoot.navFiltering || settingsRoot.visualsExpanded
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            spacing: 3

                            Repeater {
                                model: settingsRoot.sectionsFor("VISUALS")

                                delegate: Rectangle {
                                    id: navDelegate1
                                    Layout.fillWidth: true
                                    implicitHeight: 36
                                    radius: 8
                                    readonly property bool isSelected: settingsRoot.activeSection === modelData.id
                                    scale: navMouse1.pressed ? 0.97 : 1.0
                                    color: navDelegate1.isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.14) : (navHover1.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                                    border.width: navDelegate1.isSelected ? 1 : 0
                                    border.color: navDelegate1.isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.25) : "transparent"

                                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                    Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 3
                                        height: 18
                                        radius: 1.5
                                        visible: navDelegate1.isSelected
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Qt.lighter(Config.accent, 1.35) }
                                            GradientStop { position: 1.0; color: Config.accent }
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Rectangle {
                                            implicitWidth: 24
                                            implicitHeight: 24
                                            radius: 6
                                            color: navDelegate1.isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2) : (navHover1.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.icon
                                                color: navDelegate1.isSelected ? Config.accent : Config.textMuted
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 15
                                            }
                                        }

                                        Text {
                                            text: modelData.name
                                            color: navDelegate1.isSelected ? Config.accent : Config.textMain
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontCaption)
                                            font.bold: navDelegate1.isSelected
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: navMouse1
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: settingsRoot.activeSection = modelData.id
                                    }
                                    HoverHandler { id: navHover1 }
                                }
                            }
                        }

                        // ---------------- CATEGORY 2: CONNECTIVITY ----------------
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            // A group with no matches drops out of the sidebar entirely
                            // while filtering, rather than sitting there as an empty header.
                            visible: settingsRoot.sectionsFor("CONNECTIVITY").length > 0
                            radius: 8
                            color: connCatHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent"

                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: "wifi_tethering"
                                    color: settingsRoot.connectivityExpanded ? Config.accent : Config.textMuted
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: "CONNECTIVITY"
                                    color: settingsRoot.connectivityExpanded ? Config.textMain : Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: settingsRoot.connectivityExpanded ? "expand_more" : "chevron_right"
                                    color: Config.textMuted
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 18
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsRoot.connectivityExpanded = !settingsRoot.connectivityExpanded
                            }
                            HoverHandler { id: connCatHover }
                        }

                        ColumnLayout {
                            // While filtering, groups auto-open so matches are visible
                            // without the user having to expand each one by hand.
                            visible: settingsRoot.navFiltering || settingsRoot.connectivityExpanded
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            spacing: 3

                            Repeater {
                                model: settingsRoot.sectionsFor("CONNECTIVITY")

                                delegate: Rectangle {
                                    id: navDelegate2
                                    Layout.fillWidth: true
                                    implicitHeight: 36
                                    radius: 8
                                    readonly property bool isSelected: settingsRoot.activeSection === modelData.id
                                    scale: navMouse2.pressed ? 0.97 : 1.0
                                    color: navDelegate2.isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.14) : (navHover2.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                                    border.width: navDelegate2.isSelected ? 1 : 0
                                    border.color: navDelegate2.isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.25) : "transparent"

                                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                    Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 3
                                        height: 18
                                        radius: 1.5
                                        visible: navDelegate2.isSelected
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Qt.lighter(Config.accent, 1.35) }
                                            GradientStop { position: 1.0; color: Config.accent }
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Rectangle {
                                            implicitWidth: 24
                                            implicitHeight: 24
                                            radius: 6
                                            color: navDelegate2.isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2) : (navHover2.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.icon
                                                color: navDelegate2.isSelected ? Config.accent : Config.textMuted
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 15
                                            }
                                        }

                                        Text {
                                            text: modelData.name
                                            color: navDelegate2.isSelected ? Config.accent : Config.textMain
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontCaption)
                                            font.bold: navDelegate2.isSelected
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: navMouse2
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: settingsRoot.activeSection = modelData.id
                                    }
                                    HoverHandler { id: navHover2 }
                                }
                            }
                        }

                        // ---------------- CATEGORY 3: WIDGETS ----------------
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            // A group with no matches drops out of the sidebar entirely
                            // while filtering, rather than sitting there as an empty header.
                            visible: settingsRoot.sectionsFor("WIDGETS").length > 0
                            radius: 8
                            color: widgetsCatHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent"

                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: "widgets"
                                    color: settingsRoot.widgetsExpanded ? Config.accent : Config.textMuted
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: "WIDGETS"
                                    color: settingsRoot.widgetsExpanded ? Config.textMain : Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: settingsRoot.widgetsExpanded ? "expand_more" : "chevron_right"
                                    color: Config.textMuted
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 18
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsRoot.widgetsExpanded = !settingsRoot.widgetsExpanded
                            }
                            HoverHandler { id: widgetsCatHover }
                        }

                        ColumnLayout {
                            // While filtering, groups auto-open so matches are visible
                            // without the user having to expand each one by hand.
                            visible: settingsRoot.navFiltering || settingsRoot.widgetsExpanded
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            spacing: 3

                            Repeater {
                                model: settingsRoot.sectionsFor("WIDGETS")

                                delegate: Rectangle {
                                    id: navDelegate3
                                    Layout.fillWidth: true
                                    implicitHeight: 36
                                    radius: 8
                                    readonly property bool isSelected: settingsRoot.activeSection === modelData.id
                                    scale: navMouse3.pressed ? 0.97 : 1.0
                                    color: navDelegate3.isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.14) : (navHover3.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                                    border.width: navDelegate3.isSelected ? 1 : 0
                                    border.color: navDelegate3.isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.25) : "transparent"

                                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                    Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 3
                                        height: 18
                                        radius: 1.5
                                        visible: navDelegate3.isSelected
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Qt.lighter(Config.accent, 1.35) }
                                            GradientStop { position: 1.0; color: Config.accent }
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Rectangle {
                                            implicitWidth: 24
                                            implicitHeight: 24
                                            radius: 6
                                            color: navDelegate3.isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2) : (navHover3.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.icon
                                                color: navDelegate3.isSelected ? Config.accent : Config.textMuted
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 15
                                            }
                                        }

                                        Text {
                                            text: modelData.name
                                            color: navDelegate3.isSelected ? Config.accent : Config.textMain
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontCaption)
                                            font.bold: navDelegate3.isSelected
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: navMouse3
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: settingsRoot.activeSection = modelData.id
                                    }
                                    HoverHandler { id: navHover3 }
                                }
                            }
                        }

                        // Divider before Shell
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Qt.rgba(255, 255, 255, 0.06)
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                        }

                        // ---------------- CATEGORY 4: SHELL & SYSTEM ----------------
                        Rectangle {
                            id: shellBtn
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: 8
                            readonly property bool isSelected: settingsRoot.activeSection === 11
                            scale: shellMouseArea.pressed ? 0.97 : 1.0
                            color: shellBtn.isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.14) : (shellNavHover.hovered ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                            border.width: shellBtn.isSelected ? 1 : 0
                            border.color: shellBtn.isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.25) : "transparent"

                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 18
                                radius: 1.5
                                visible: shellBtn.isSelected
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Qt.lighter(Config.accent, 1.35) }
                                    GradientStop { position: 1.0; color: Config.accent }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 8

                                Rectangle {
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    radius: 6
                                    color: shellBtn.isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2) : (shellNavHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")

                                    Text {
                                        anchors.centerIn: parent
                                        text: "terminal"
                                        color: shellBtn.isSelected ? Config.accent : Config.textMuted
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 15
                                    }
                                }

                                Text {
                                    text: "Shell & System"
                                    color: shellBtn.isSelected ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: shellBtn.isSelected
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: shellMouseArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsRoot.activeSection = 11
                            }
                            HoverHandler { id: shellNavHover }
                        }
                    }
                }
            }

            // ================= RIGHT CONTENT CONTAINER =================
            // ClippingRectangle (not plain Rectangle) so the watermark actually
            // respects the rounded corners instead of bleeding past them - plain
            // Rectangle.clip only clips to the square bounding box.
            ClippingRectangle {
                id: rightPaneRoot
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Qt.rgba(255, 255, 255, 0.03)
                radius: (Config.surfaceRadius || 18) * 0.75
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.06)

                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 6
                    radius: 24
                    samples: 33
                    color: Qt.rgba(0, 0, 0, 0.35)
                }

                property var currentFlickable: null
                readonly property bool canScrollDown: currentFlickable && (currentFlickable.contentHeight > (currentFlickable.height + 24)) && !currentFlickable.atYEnd && (currentFlickable.contentY < (currentFlickable.contentHeight - currentFlickable.height - 16))

                function findFlickable(item) {
                    if (!item) return null
                    if (item.contentHeight !== undefined && item.contentY !== undefined && item.height !== undefined) {
                        return item
                    }
                    if (item.children) {
                        for (let i = 0; i < item.children.length; i++) {
                            let child = item.children[i]
                            if (child && child.contentHeight !== undefined && child.contentY !== undefined && child.height !== undefined) {
                                return child
                            }
                        }
                    }
                    return null
                }

                function refreshActiveFlickable() {
                    for (let i = 0; i < contentPane.children.length; i++) {
                        let ch = contentPane.children[i]
                        if (ch && ch.active && ch.item) {
                            let f = findFlickable(ch.item)
                            if (f) {
                                currentFlickable = f
                                return
                            }
                        }
                    }
                    currentFlickable = null
                }

                Timer {
                    id: flickableSyncTimer
                    interval: 120
                    running: true
                    repeat: true
                    onTriggered: rightPaneRoot.refreshActiveFlickable()
                }

                Watermark {
                    icon: Config.getIcon("settings")
                    iconSize: 180
                    baseRotation: 12
                    seed: 16
                    baseOpacity: 0.05
                }

                Item {
                    id: contentPane
                    anchors.fill: parent
                    anchors.margins: settingsRoot.cardMargin

                    transform: Translate { id: contentSlideTransform; x: 0 }

                    NumberAnimation {
                        id: contentFadeAnim
                        target: contentPane
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 240
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        id: contentSlideAnim
                        target: contentSlideTransform
                        property: "x"
                        from: 14
                        to: 0
                        duration: 280
                        easing.type: Easing.OutCubic
                    }

                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 0; visible: active; sourceComponent: DisplaySettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 16; visible: active; sourceComponent: BarSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 1; visible: active; sourceComponent: AppearanceSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 17; visible: active; sourceComponent: WorkspaceSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 2; visible: active; sourceComponent: TypographySettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 3; visible: active; sourceComponent: WallpaperSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 4; visible: active; sourceComponent: NetworkSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 5; visible: active; sourceComponent: WifiSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 6; visible: active; sourceComponent: BluetoothSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 7; visible: active; sourceComponent: WeatherSettings {} }

                    Loader { id: mascotSettingsLoader; anchors.fill: parent; active: settingsRoot.activeSection === 8; visible: active; sourceComponent: MascotSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 9; visible: active; sourceComponent: ClockSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 19; visible: active; sourceComponent: SysInfoSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 10; visible: active; sourceComponent: KeyboardSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 20; visible: active; sourceComponent: ShaderSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 21; visible: active; sourceComponent: CavaSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 22; visible: active; sourceComponent: AssistantSettings {} }

                    // Shell View (Section 11)
                    Loader {
                        anchors.fill: parent
                        active: settingsRoot.activeSection === 11
                        visible: active
                        sourceComponent: Item {
                            id: shellView
                            anchors.fill: parent

                            property string statusText: "Ready"
                            property bool isBusy: false

                            readonly property string repoDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")

                            Process {
                                id: gitChecker
                                running: false

                                stdout: StdioCollector { id: checkOutput }
                                stderr: StdioCollector { id: checkError }

                                onExited: (code) => {
                                    if (code === 0) {
                                        let output = checkOutput.text
                                        if (output.includes("behind")) {
                                            shellView.statusText = "Updates available! Downloading..."
                                            gitPuller.command = ["fish", "-c",
                                                "cd '" + shellView.repoDir + "'; " +
                                                "and set OLD_HEAD (git rev-parse HEAD); " +
                                                "and git fetch origin main; " +
                                                "and git reset --hard origin/main; " +
                                                "and notify-send -u critical 'Synoptik Shell Updated' (git log --pretty=format:'• %s' $OLD_HEAD..origin/main | string collect)"]
                                            gitPuller.running = true
                                        } else {
                                            shellView.isBusy = false
                                            shellView.statusText = "Your shell is fully up to date."
                                        }
                                    } else {
                                        shellView.isBusy = false
                                        let err = checkError.text.trim()
                                        shellView.statusText = err.length > 0 ? err : "Error checking upstream repository."
                                    }
                                }
                            }

                            Process {
                                id: gitPuller
                                running: false

                                stderr: StdioCollector { id: pullError }

                                onExited: (code) => {
                                    shellView.isBusy = false
                                    if (code === 0) {
                                        shellView.statusText = "Updated! Click Reload to apply the new version."
                                    } else {
                                        let err = pullError.text.trim()
                                        shellView.statusText = err.length > 0 ? err : "Failed to apply updates."
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: settingsRoot.cardMargin

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Rectangle {
                                        implicitWidth: 44
                                        implicitHeight: 44
                                        radius: 10
                                        color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.15)
                                        border.width: 1
                                        border.color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.3)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "terminal"
                                            color: Config.accent
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 24
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: "SYNOPTIK SHELL"
                                            color: Config.textMain
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontSubhead)
                                            font.bold: true
                                        }

                                        Text {
                                            text: "Modular, hardware-accelerated desktop shell for Hyprland"
                                            color: Config.textMuted
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontCaption)
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 60
                                    radius: Config.cornerRadius / 2
                                    scale: gitHubMouseArea.pressed ? 0.98 : 1.0
                                    color: Qt.rgba(255, 255, 255, 0.04)
                                    border.width: 1
                                    border.color: gitHubHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                                    Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 12

                                        Rectangle {
                                            implicitWidth: 32
                                            implicitHeight: 32
                                            radius: 8
                                            color: Qt.rgba(255, 255, 255, 0.06)

                                            Text {
                                                anchors.centerIn: parent
                                                text: "code"
                                                color: Config.accent
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 18
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                text: "GitHub Repository"
                                                color: Config.textMain
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontBody)
                                                font.bold: true
                                            }

                                            Text {
                                                text: "github.com/natepayn3/Synoptik"
                                                color: Config.textMuted
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontCaption)
                                            }
                                        }

                                        Text {
                                            text: "open_in_new"
                                            color: gitHubHover.hovered ? Config.accent : Config.textMuted
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 18
                                        }
                                    }

                                    MouseArea {
                                        id: gitHubMouseArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/natepayn3/Synoptik"])
                                    }
                                    HoverHandler { id: gitHubHover }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: Math.max(68, statusRow.implicitHeight + 20)
                                    radius: Config.cornerRadius / 2
                                    color: Qt.rgba(255, 255, 255, 0.04)
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.08)

                                    RowLayout {
                                        id: statusRow
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        anchors.topMargin: 10
                                        anchors.bottomMargin: 10
                                        spacing: 12

                                        Rectangle {
                                            implicitWidth: 32
                                            implicitHeight: 32
                                            radius: 8
                                            color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.15)

                                            Text {
                                                anchors.centerIn: parent
                                                text: shellView.isBusy ? "sync" : "system_update"
                                                color: Config.accent
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 18

                                                RotationAnimation on rotation {
                                                    running: shellView.isBusy
                                                    from: 0
                                                    to: 360
                                                    duration: 1000
                                                    loops: Animation.Infinite
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: shellView.isBusy ? "Checking Upstream..." : "Repository Status"
                                                color: Config.textMain
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontBody)
                                                font.bold: true
                                            }

                                            Text {
                                                text: shellView.statusText
                                                color: Config.textMuted
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontCaption)
                                                Layout.fillWidth: true
                                                wrapMode: Text.WrapAnywhere
                                            }
                                        }

                                        RowLayout {
                                            spacing: 8
                                            Layout.alignment: Qt.AlignVCenter

                                            Rectangle {
                                                implicitWidth: 110
                                                implicitHeight: 32
                                                radius: Config.cornerRadius / 2
                                                scale: reloadMouseArea.pressed ? 0.95 : 1.0
                                                color: reloadBtnHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                                                border.color: Qt.rgba(255, 255, 255, 0.15)
                                                border.width: 1

                                                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                                                RowLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 4
                                                    Text { text: "restart_alt"; color: Config.textMain; font.family: "Material Symbols Outlined"; font.pixelSize: 14 }
                                                    Text { text: "Reload"; color: Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: true }
                                                }

                                                MouseArea {
                                                    id: reloadMouseArea
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    enabled: !shellView.isBusy
                                                    onClicked: {
                                                        Config.flushSettings()
                                                        Quickshell.execDetached(["fish", "-c", "killall qs; and qs -c Synoptik & disown"])
                                                    }
                                                }
                                                HoverHandler { id: reloadBtnHover }
                                            }

                                            Rectangle {
                                                implicitWidth: 120
                                                implicitHeight: 32
                                                radius: Config.cornerRadius / 2
                                                scale: updateMouseArea.pressed ? 0.95 : 1.0
                                                gradient: Gradient {
                                                    GradientStop { position: 0.0; color: updateBtnHover.hovered ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.4) : Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.26) }
                                                    GradientStop { position: 1.0; color: updateBtnHover.hovered ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.22) : Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.12) }
                                                }
                                                border.color: Config.accent
                                                border.width: 1

                                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                                                RowLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 4
                                                    Text { text: "sync"; color: Config.accent; font.family: "Material Symbols Outlined"; font.pixelSize: 14 }
                                                    Text { text: shellView.isBusy ? "Updating..." : "Check Updates"; color: Config.accent; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: true }
                                                }

                                                MouseArea {
                                                    id: updateMouseArea
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    enabled: !shellView.isBusy
                                                    onClicked: {
                                                        shellView.isBusy = true
                                                        shellView.statusText = "Checking for updates..."
                                                        gitChecker.command = ["fish", "-c", "cd '" + shellView.repoDir + "'; and git remote update; and git status -uno"]
                                                        gitChecker.running = true
                                                    }
                                                }
                                                HoverHandler { id: updateBtnHover }
                                            }
                                        }
                                    }
                                }

                                // ---------------- CONFIGURATION PROFILES ----------------
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    implicitHeight: profilesColumn.implicitHeight + 28
                                    radius: Config.cornerRadius / 2
                                    color: Qt.rgba(255, 255, 255, 0.04)
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.08)

                                    ColumnLayout {
                                        id: profilesColumn
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        anchors.topMargin: 14
                                        spacing: 10

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            Rectangle {
                                                implicitWidth: 32
                                                implicitHeight: 32
                                                radius: 8
                                                color: Qt.rgba(255, 255, 255, 0.06)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "bookmarks"
                                                    color: Config.accent
                                                    font.family: "Material Symbols Outlined"
                                                    font.pixelSize: 18
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    text: "Configuration Profiles"
                                                    color: Config.textMain
                                                    font.family: Config.sysFont
                                                    font.pixelSize: Config.size(Config.fontBody)
                                                    font.bold: true
                                                }

                                                Text {
                                                    text: Config.activeProfile !== ""
                                                        ? ("Active: " + Config.activeProfile + " • saved snapshots of every setting")
                                                        : "Save the current setup and switch between machines"
                                                    color: Config.textMuted
                                                    font.family: Config.sysFont
                                                    font.pixelSize: Config.size(Config.fontCaption)
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        // --- new profile name + save ---
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Rectangle {
                                                Layout.fillWidth: true
                                                implicitHeight: 32
                                                radius: Config.cornerRadius / 2
                                                color: Qt.rgba(255, 255, 255, 0.05)
                                                border.width: 1
                                                border.color: profileNameInput.activeFocus
                                                    ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.6)
                                                    : Qt.rgba(255, 255, 255, 0.1)

                                                TextInput {
                                                    id: profileNameInput
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    anchors.rightMargin: 10
                                                    color: Config.textMain
                                                    font.family: Config.sysFont
                                                    font.pixelSize: Config.size(Config.fontCaption)
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    clip: true
                                                    selectByMouse: true
                                                    onAccepted: {
                                                        Config.saveProfile(text)
                                                        text = ""
                                                    }
                                                    HoverHandler { cursorShape: Qt.IBeamCursor }

                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        visible: profileNameInput.text === ""
                                                        text: "Profile name (e.g. laptop)"
                                                        color: Qt.rgba(255, 255, 255, 0.3)
                                                        font.family: Config.sysFont
                                                        font.pixelSize: Config.size(Config.fontCaption)
                                                        font.italic: true
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                implicitWidth: 92
                                                implicitHeight: 32
                                                radius: Config.cornerRadius / 2
                                                opacity: Config.sanitizeProfileName(profileNameInput.text) === "" ? 0.4 : 1.0
                                                scale: saveProfMouse.pressed ? 0.95 : 1.0
                                                color: saveProfHover.hovered
                                                    ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.3)
                                                    : Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.18)
                                                border.width: 1
                                                border.color: Config.accent

                                                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                                                RowLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 4
                                                    Text { text: "save"; color: Config.accent; font.family: "Material Symbols Outlined"; font.pixelSize: 14 }
                                                    Text {
                                                        text: Config.profileNames.indexOf(Config.sanitizeProfileName(profileNameInput.text)) >= 0 ? "Replace" : "Save"
                                                        color: Config.accent
                                                        font.family: Config.sysFont
                                                        font.pixelSize: Config.size(Config.fontCaption)
                                                        font.bold: true
                                                    }
                                                }

                                                MouseArea {
                                                    id: saveProfMouse
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (Config.sanitizeProfileName(profileNameInput.text) === "") return
                                                        Config.saveProfile(profileNameInput.text)
                                                        profileNameInput.text = ""
                                                    }
                                                }
                                                HoverHandler { id: saveProfHover }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: Config.profileNames.length === 0
                                            text: "No profiles saved yet. Saving one snapshots every current setting to profiles/<name>.json."
                                            color: Config.textMuted
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontMicro)
                                            font.italic: true
                                            wrapMode: Text.WordWrap
                                        }

                                        // --- saved profiles ---
                                        Repeater {
                                            model: Config.profileNames

                                            delegate: Rectangle {
                                                id: profRow
                                                required property var modelData
                                                readonly property bool isActive: Config.activeProfile === profRow.modelData

                                                Layout.fillWidth: true
                                                implicitHeight: 36
                                                radius: Config.cornerRadius / 2
                                                color: isActive
                                                    ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.12)
                                                    : Qt.rgba(255, 255, 255, 0.03)
                                                border.width: 1
                                                border.color: isActive ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    anchors.rightMargin: 8
                                                    spacing: 8

                                                    Text {
                                                        text: profRow.isActive ? "radio_button_checked" : "bookmark"
                                                        color: profRow.isActive ? Config.accent : Config.textMuted
                                                        font.family: "Material Symbols Outlined"
                                                        font.pixelSize: 15
                                                    }

                                                    Text {
                                                        text: profRow.modelData
                                                        color: profRow.isActive ? Config.accent : Config.textMain
                                                        font.family: Config.sysFont
                                                        font.pixelSize: Config.size(Config.fontCaption)
                                                        font.bold: profRow.isActive
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }

                                                    Rectangle {
                                                        implicitWidth: 62
                                                        implicitHeight: 24
                                                        radius: Config.cornerRadius / 2
                                                        color: loadHover.hovered ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.06)
                                                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "Load"
                                                            color: Config.textMain
                                                            font.family: Config.sysFont
                                                            font.pixelSize: Config.size(Config.fontMicro)
                                                            font.bold: true
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: Config.loadProfile(profRow.modelData)
                                                        }
                                                        HoverHandler { id: loadHover }
                                                    }

                                                    Text {
                                                        text: "delete"
                                                        color: delHover.hovered ? "#e0564f" : Config.textMuted
                                                        font.family: "Material Symbols Outlined"
                                                        font.pixelSize: 16

                                                        HoverHandler { id: delHover; cursorShape: Qt.PointingHandCursor }
                                                        TapHandler { onTapped: Config.deleteProfile(profRow.modelData) }
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

                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 12; visible: active; sourceComponent: IconSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 13; visible: active; sourceComponent: SystemSounds {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 15; visible: active; sourceComponent: LockscreenSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 18; visible: active; sourceComponent: ScreensaverSettings {} }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 64
                    // ClippingRectangle's default property forwards children to an
                    // inner plain Item (contentItem), so `parent` here is that Item,
                    // not rightPaneRoot - parent.radius was silently undefined.
                    radius: rightPaneRoot.radius
                    visible: opacity > 0
                    opacity: rightPaneRoot.canScrollDown ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.65; color: Qt.rgba(Config.bgPanel.r, Config.bgPanel.g, Config.bgPanel.b, 0.85) }
                        GradientStop { position: 1.0; color: Qt.rgba(Config.bgPanel.r, Config.bgPanel.g, Config.bgPanel.b, 0.98) }
                    }
                }

                Rectangle {
                    id: scrollCuePill
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    z: 100
                    implicitWidth: scrollCueRow.implicitWidth + 24
                    implicitHeight: 32
                    radius: 16
                    visible: opacity > 0
                    opacity: rightPaneRoot.canScrollDown ? (scrollCueMouse.containsMouse ? 1.0 : 0.92) : 0.0
                    color: scrollCueMouse.containsMouse ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.25) : Qt.rgba(Config.bgBase.r, Config.bgBase.g, Config.bgBase.b, 0.92)
                    border.width: 1.5
                    border.color: scrollCueMouse.containsMouse ? Config.accent : Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.45)

                    Behavior on opacity { NumberAnimation { duration: 220 } }
                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }

                    SequentialAnimation on anchors.bottomMargin {
                        running: rightPaneRoot.canScrollDown
                        loops: Animation.Infinite
                        NumberAnimation { from: 14; to: 18; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 18; to: 14; duration: 700; easing.type: Easing.InOutSine }
                    }

                    RowLayout {
                        id: scrollCueRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "keyboard_double_arrow_down"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 17
                            color: Config.accent
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            text: "More"
                            font.family: Config.sysFont
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 0.5
                            color: Config.textMain
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: scrollCueMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (rightPaneRoot.currentFlickable) {
                                let f = rightPaneRoot.currentFlickable
                                let targetY = Math.min(f.contentHeight - f.height, f.contentY + f.height * 0.75)
                                scrollAnim.target = f
                                scrollAnim.to = targetY
                                scrollAnim.restart()
                            }
                        }
                    }
                }

                NumberAnimation {
                    id: scrollAnim
                    property: "contentY"
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}