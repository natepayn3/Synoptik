import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import ".."

Rectangle {
    id: leftCard

    property var rootRef
    signal popoutRequested(var item)

    // Map instantiated child items by icon key for PanelWindow origin tracking
    function getButton(key) {
        if (Config.leftCardCollapsed && !Config.isPinned(key)) return null
        for (let i = 0; i < repeater.count; i++) {
            let loader = repeater.itemAt(i)
            if (loader && loader.itemKey === key && loader.item && loader.visible) {
                return loader.item
            }
        }
        return null
    }

    readonly property real maxAllowedWidth: parent ? Math.max(100, parent.width - 260) : 1920
    readonly property real maxAllowedHeight: parent ? Math.max(100, parent.height - 260) : 1080

    readonly property real contentTargetWidth: Math.min(leftModules.implicitWidth + 8, maxAllowedWidth)
    readonly property real contentTargetHeight: Math.min(leftModules.implicitHeight + 8, maxAllowedHeight)

    width: (rootRef && rootRef.isHorizontal) ? contentTargetWidth : 36
    height: (rootRef && rootRef.isHorizontal) ? 36 : contentTargetHeight
    radius: Config.cornerRadius / 2
    color: Qt.rgba(255, 255, 255, 0.05)
    clip: true

    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    states: [
        State {
            name: "horizontal"
            when: rootRef.isHorizontal
            AnchorChanges {
                target: leftCard
                anchors.left: leftCard.parent.left
                anchors.verticalCenter: leftCard.parent.verticalCenter
                anchors.top: undefined
                anchors.horizontalCenter: undefined
            }
        },
        State {
            name: "vertical"
            when: !rootRef.isHorizontal
            AnchorChanges {
                target: leftCard
                anchors.top: leftCard.parent.top
                anchors.horizontalCenter: leftCard.parent.horizontalCenter
                anchors.left: undefined
                anchors.verticalCenter: undefined
            }
        }
    ]

    anchors.leftMargin: rootRef.isHorizontal ? 10 : 0
    anchors.topMargin: !rootRef.isHorizontal ? 10 : 0

    property bool iconsFullyExpanded: false

    Component.onCompleted: {
        if (!Config.leftCardCollapsed) {
            iconsFullyExpanded = true
        }
    }

    Connections {
        target: Config
        ignoreUnknownSignals: true
        function onLeftCardCollapsedChanged() {
            if (!Config.leftCardCollapsed) {
                iconsFullyExpanded = false
                expandTimer.restart()
            } else {
                iconsFullyExpanded = false
            }
        }
    }

    readonly property bool showUnpinnedLoaders: !Config.leftCardCollapsed

    Timer {
        id: expandTimer
        interval: 280
        repeat: false
        onTriggered: {
            if (!Config.leftCardCollapsed) {
                iconsFullyExpanded = true
            }
        }
    }

    GridLayout {
        id: leftModules
        anchors.left: (rootRef && rootRef.isHorizontal) ? parent.left : undefined
        anchors.leftMargin: (rootRef && rootRef.isHorizontal) ? 4 : 0
        anchors.verticalCenter: (rootRef && rootRef.isHorizontal) ? parent.verticalCenter : undefined

        anchors.top: (rootRef && !rootRef.isHorizontal) ? parent.top : undefined
        anchors.topMargin: (rootRef && !rootRef.isHorizontal) ? 4 : 0
        anchors.horizontalCenter: (rootRef && !rootRef.isHorizontal) ? parent.horizontalCenter : undefined

        columns: (rootRef && rootRef.isHorizontal) ? 99 : 1
        rows: (rootRef && rootRef.isHorizontal) ? 1 : 99
        columnSpacing: 8
        rowSpacing: 8

        Repeater {
            id: repeater
            model: Config.leftCardOrder || ["power", "recorder", "mirror", "screenshot", "notifications", "player", "wallpaper", "settings", "launcher", "audio", "batt", "network", "clipboard"]

            delegate: Loader {
                readonly property string itemKey: modelData
                
                visible: {
                    if (itemKey === "batt" && typeof shellRoot !== "undefined" && !shellRoot.hasBattery) return false
                    return leftCard.showUnpinnedLoaders || Config.isPinned(itemKey)
                }

                opacity: {
                    if (Config.isPinned(itemKey)) return 1.0
                    return leftCard.iconsFullyExpanded ? 1.0 : 0.0
                }

                Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.InOutQuad } }

                sourceComponent: {
                    switch(itemKey) {
                        case "power": return powerComp
                        case "recorder": return recorderComp
                        case "mirror": return mirrorComp
                        case "screenshot": return screenshotComp
                        case "notifications": return notifComp
                        case "player": return playerComp
                        case "wallpaper": return wallpaperComp
                        case "settings": return settingsComp
                        case "launcher": return launcherComp
                        case "audio": return audioComp
                        case "batt": return battComp
                        case "network": return networkComp
                        case "clipboard": return clipComp
                        default: return null
                    }
                }
            }
        }

        Rectangle {
            implicitWidth: 32; implicitHeight: 32; radius: 10
            color: "transparent"

            Item {
                anchors.centerIn: parent
                implicitWidth: chevronIconText.implicitWidth
                implicitHeight: chevronIconText.implicitHeight
                scale: chevronLeftHover.hovered ? 1.25 : 1.0

                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Glow {
                    anchors.fill: chevronIconText
                    source: chevronIconText
                    radius: chevronLeftHover.hovered ? 8 : 0
                    samples: 16
                    color: Config.accent
                    spread: 0.2
                    transparentBorder: true
                    visible: chevronLeftHover.hovered

                    Behavior on radius { NumberAnimation { duration: 180 } }
                }

                Text {
                    id: chevronIconText
                    anchors.centerIn: parent
                    text: {
                        if (rootRef.isHorizontal) return Config.leftCardCollapsed ? "chevron_right" : "chevron_left"
                        return Config.leftCardCollapsed ? "expand_more" : "expand_less"
                    }
                    color: chevronLeftHover.hovered ? Config.accent : Config.textMuted
                    font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            TapHandler { onTapped: Config.leftCardCollapsed = !Config.leftCardCollapsed }
            HoverHandler { id: chevronLeftHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: powerComp
        Rectangle {
            id: btnPower
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: Config.showPower ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                anchors.centerIn: parent
                implicitWidth: powerIconText.implicitWidth
                implicitHeight: powerIconText.implicitHeight
                scale: powerHover.hovered ? 1.25 : 1.0

                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Glow {
                    anchors.fill: powerIconText
                    source: powerIconText
                    radius: powerHover.hovered ? 8 : 0
                    samples: 16
                    color: Config.accent
                    spread: 0.2
                    transparentBorder: true
                    visible: powerHover.hovered

                    Behavior on radius { NumberAnimation { duration: 180 } }
                }

                Text {
                    id: powerIconText
                    anchors.centerIn: parent
                    text: Config.getIcon("power")
                    color: (Config.showPower || powerHover.hovered) ? Config.accent : Config.textMain
                    font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.leftCardCollapsed && Config.isPinned("power")
            }

            TapHandler { onTapped: { popoutRequested(btnPower); Config.showPower = !Config.showPower; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("power") }
            HoverHandler { id: powerHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: recorderComp
        Rectangle {
            id: btnRecorder
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: Config.showScreenRecorder ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                anchors.centerIn: parent
                implicitWidth: recordIconText.implicitWidth
                implicitHeight: recordIconText.implicitHeight
                scale: recordHover.hovered ? 1.25 : 1.0

                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Glow {
                    anchors.fill: recordIconText
                    source: recordIconText
                    radius: recordHover.hovered ? 8 : 0
                    samples: 16
                    color: Config.accent
                    spread: 0.2
                    transparentBorder: true
                    visible: recordHover.hovered

                    Behavior on radius { NumberAnimation { duration: 180 } }
                }

                Text {
                    id: recordIconText
                    anchors.centerIn: parent
                    text: (typeof shellRoot !== "undefined" && shellRoot.isRecording) ? "radio_button_checked" : Config.getIcon("recorder")
                    color: (typeof shellRoot !== "undefined" && shellRoot.isRecording) ? "#ef4444" : ((Config.showScreenRecorder || recordHover.hovered) ? Config.accent : Config.textMain)
                    font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.leftCardCollapsed && Config.isPinned("recorder")
            }

            TapHandler { onTapped: { popoutRequested(btnRecorder); Config.showScreenRecorder = !Config.showScreenRecorder; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("recorder") }
            HoverHandler { id: recordHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: playerComp
        Rectangle {
            id: btnPlayer
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: Config.showPlayer ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                anchors.centerIn: parent
                implicitWidth: playerIconText.implicitWidth
                implicitHeight: playerIconText.implicitHeight
                scale: playerHover.hovered ? 1.25 : 1.0

                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Glow {
                    anchors.fill: playerIconText
                    source: playerIconText
                    radius: playerHover.hovered ? 8 : 0
                    samples: 16
                    color: Config.accent
                    spread: 0.2
                    transparentBorder: true
                    visible: playerHover.hovered

                    Behavior on radius { NumberAnimation { duration: 180 } }
                }

                Text {
                    id: playerIconText
                    anchors.centerIn: parent
                    text: Config.getIcon("player")
                    color: (Config.showPlayer || playerHover.hovered) ? Config.accent : Config.textMain
                    font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.leftCardCollapsed && Config.isPinned("player")
            }

            // Direct in-memory toggle
            TapHandler { onTapped: Config.showPlayer = !Config.showPlayer }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("player") }
            HoverHandler { id: playerHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: mirrorComp
        Rectangle {
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: Config.showMirror ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                anchors.centerIn: parent
                implicitWidth: mirrorIconText.implicitWidth
                implicitHeight: mirrorIconText.implicitHeight
                scale: mirrorHover.hovered ? 1.25 : 1.0

                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Glow {
                    anchors.fill: mirrorIconText
                    source: mirrorIconText
                    radius: mirrorHover.hovered ? 8 : 0
                    samples: 16
                    color: Config.accent
                    spread: 0.2
                    transparentBorder: true
                    visible: mirrorHover.hovered

                    Behavior on radius { NumberAnimation { duration: 180 } }
                }

                Text {
                    id: mirrorIconText
                    anchors.centerIn: parent
                    text: Config.getIcon("mirror")
                    color: (Config.showMirror || mirrorHover.hovered) ? Config.accent : Config.textMain
                    font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.leftCardCollapsed && Config.isPinned("mirror")
            }

            // Direct in-memory toggle
            TapHandler { 
                onTapped: Config.showMirror = !Config.showMirror 
            }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("mirror") }
            HoverHandler { id: mirrorHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: screenshotComp
        Rectangle {
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                anchors.centerIn: parent
                implicitWidth: snapIconText.implicitWidth
                implicitHeight: snapIconText.implicitHeight
                scale: screenshotHover.hovered ? 1.25 : 1.0

                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Glow {
                    anchors.fill: snapIconText
                    source: snapIconText
                    radius: screenshotHover.hovered ? 8 : 0
                    samples: 16
                    color: Config.accent
                    spread: 0.2
                    transparentBorder: true
                    visible: screenshotHover.hovered

                    Behavior on radius { NumberAnimation { duration: 180 } }
                }

                Text {
                    id: snapIconText
                    anchors.centerIn: parent
                    text: Config.getIcon("screenshot")
                    color: screenshotHover.hovered ? Config.accent : Config.textMain
                    font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.leftCardCollapsed && Config.isPinned("screenshot")
            }

            TapHandler { onTapped: Quickshell.execDetached(["fish", "-c", "sleep 0.1; and grim -g (slurp) -t ppm - | satty --filename -"]) }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("screenshot") }
            HoverHandler { id: screenshotHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: notifComp
        Rectangle {
            id: btnNotifications
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: Config.showNotifications ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                anchors.centerIn: parent
                implicitWidth: notifIconText.implicitWidth
                implicitHeight: notifIconText.implicitHeight
                scale: notificationsHover.hovered ? 1.25 : 1.0

                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Glow {
                    anchors.fill: notifIconText
                    source: notifIconText
                    radius: notificationsHover.hovered ? 8 : 0
                    samples: 16
                    color: Config.accent
                    spread: 0.2
                    transparentBorder: true
                    visible: notificationsHover.hovered

                    Behavior on radius { NumberAnimation { duration: 180 } }
                }

                Text {
                    id: notifIconText
                    anchors.centerIn: parent
                    text: (typeof shellRoot !== "undefined" && shellRoot.activeNotifs > 0) ? "inbox_text" : Config.getIcon("notifications")
                    color: (Config.showNotifications || notificationsHover.hovered || (typeof shellRoot !== "undefined" && shellRoot.activeNotifs > 0)) ? Config.accent : Config.textMain
                    font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.leftCardCollapsed && Config.isPinned("notifications")
            }

            TapHandler { onTapped: { popoutRequested(btnNotifications); Config.showNotifications = !Config.showNotifications; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("notifications") }
            HoverHandler { id: notificationsHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: wallpaperComp
        Rectangle {
            id: btnWallpaper
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: Config.showWallpaper ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                anchors.centerIn: parent
                implicitWidth: wallIconText.implicitWidth
                implicitHeight: wallIconText.implicitHeight
                scale: wallpaperHover.hovered ? 1.25 : 1.0

                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Glow {
                    anchors.fill: wallIconText
                    source: wallIconText
                    radius: wallpaperHover.hovered ? 8 : 0
                    samples: 16
                    color: Config.accent
                    spread: 0.2
                    transparentBorder: true
                    visible: wallpaperHover.hovered

                    Behavior on radius { NumberAnimation { duration: 180 } }
                }

                Text {
                    id: wallIconText
                    anchors.centerIn: parent
                    text: Config.getIcon("wallpaper")
                    color: (Config.showWallpaper || wallpaperHover.hovered) ? Config.accent : Config.textMain
                    font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.leftCardCollapsed && Config.isPinned("wallpaper")
            }

            TapHandler { onTapped: { popoutRequested(btnWallpaper); Config.showWallpaper = !Config.showWallpaper; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("wallpaper") }
            HoverHandler { id: wallpaperHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: settingsComp
        Rectangle {
            id: btnSettings
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: Config.showSettings ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                anchors.centerIn: parent
                implicitWidth: settingsIconText.implicitWidth
                implicitHeight: settingsIconText.implicitHeight
                scale: settingsHover.hovered ? 1.25 : 1.0

                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Glow {
                    anchors.fill: settingsIconText
                    source: settingsIconText
                    radius: settingsHover.hovered ? 8 : 0
                    samples: 16
                    color: Config.accent
                    spread: 0.2
                    transparentBorder: true
                    visible: settingsHover.hovered

                    Behavior on radius { NumberAnimation { duration: 180 } }
                }

                Text {
                    id: settingsIconText
                    anchors.centerIn: parent
                    text: Config.getIcon("settings")
                    color: (Config.showSettings || settingsHover.hovered) ? Config.accent : Config.textMain
                    font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.leftCardCollapsed && Config.isPinned("settings")
            }

            TapHandler { onTapped: { popoutRequested(btnSettings); Config.showSettings = !Config.showSettings; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("settings") }
            HoverHandler { id: settingsHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: launcherComp
        Rectangle {
            id: btnLauncher
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: Config.showAppLauncher ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                anchors.centerIn: parent
                implicitWidth: launcherIconText.implicitWidth
                implicitHeight: launcherIconText.implicitHeight
                scale: launcherHover.hovered ? 1.25 : 1.0

                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Glow {
                    anchors.fill: launcherIconText
                    source: launcherIconText
                    radius: launcherHover.hovered ? 8 : 0
                    samples: 16
                    color: Config.accent
                    spread: 0.2
                    transparentBorder: true
                    visible: launcherHover.hovered

                    Behavior on radius { NumberAnimation { duration: 180 } }
                }

                Text {
                    id: launcherIconText
                    anchors.centerIn: parent
                    text: Config.getIcon("launcher")
                    color: (Config.showAppLauncher || launcherHover.hovered) ? Config.accent : Config.textMain
                    font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.leftCardCollapsed && Config.isPinned("launcher")
            }

            TapHandler { onTapped: { popoutRequested(btnLauncher); Config.showAppLauncher = !Config.showAppLauncher; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("launcher") }
            HoverHandler { id: launcherHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: audioComp
        Rectangle {
            id: btnAudio
            implicitWidth: 32; implicitHeight: 32; radius: 10
            color: Config.showAudio ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                anchors.centerIn: parent
                implicitWidth: audioIconText.implicitWidth; implicitHeight: audioIconText.implicitHeight
                scale: audioHover.hovered ? 1.25 : 1.0
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Glow {
                    anchors.fill: audioIconText; source: audioIconText
                    radius: audioHover.hovered ? 8 : 0; samples: 16
                    color: Config.accent; spread: 0.2; transparentBorder: true
                    visible: audioHover.hovered
                    Behavior on radius { NumberAnimation { duration: 180 } }
                }

                Text {
                    id: audioIconText
                    anchors.centerIn: parent
                    text: shellRoot.audioMuted ? "hearing_disabled" : (shellRoot.audioVolume === 0 ? "hearing_disabled" : Config.getIcon("audio"))
                    color: (Config.showAudio || audioHover.hovered) ? Config.accent : (shellRoot.audioMuted ? Config.textMuted : Config.textMain)
                    font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.leftCardCollapsed && Config.isPinned("audio")
            }

            TapHandler { onTapped: { popoutRequested(btnAudio); Config.showAudio = !Config.showAudio; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("audio") }
            HoverHandler { id: audioHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: battComp
        Rectangle {
            id: btnBatt
            implicitWidth: 32; implicitHeight: 32; radius: 10
            color: Config.showBattery ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                anchors.centerIn: parent
                implicitWidth: battIconText.implicitWidth; implicitHeight: battIconText.implicitHeight
                scale: battHover.hovered ? 1.25 : 1.0
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Glow {
                    anchors.fill: battIconText; source: battIconText
                    radius: battHover.hovered ? 8 : 0; samples: 16
                    color: Config.accent; spread: 0.2; transparentBorder: true
                    visible: battHover.hovered
                    Behavior on radius { NumberAnimation { duration: 180 } }
                }

                Text {
                    id: battIconText
                    anchors.centerIn: parent
                    text: {
                        if (shellRoot.battStatus === "Charging") return "battery_android_frame_bolt"
                        if (shellRoot.battCapacity <= 10) return "battery_android_0"
                        if (shellRoot.battCapacity <= 25) return "battery_android_frame_1"
                        if (shellRoot.battCapacity <= 40) return "battery_android_frame_2"
                        if (shellRoot.battCapacity <= 60) return "battery_android_frame_3"
                        if (shellRoot.battCapacity <= 75) return "battery_android_frame_4"
                        if (shellRoot.battCapacity <= 90) return "battery_android_frame_5"
                        if (shellRoot.battCapacity < 100) return "battery_android_frame_6"
                        return "battery_android_frame_full"
                    }
                    color: (Config.showBattery || battHover.hovered) ? Config.accent : (shellRoot.battCapacity <= 15 ? "#ef4444" : Config.textMain)
                    font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.leftCardCollapsed && Config.isPinned("batt")
            }

            TapHandler { onTapped: { popoutRequested(btnBatt); Config.showBattery = !Config.showBattery; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("batt") }
            HoverHandler { id: battHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: networkComp
        Rectangle {
            id: btnNetwork
            implicitWidth: 32; implicitHeight: 32; radius: 10
            color: Config.showNetwork ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                anchors.centerIn: parent
                implicitWidth: netIconText.implicitWidth; implicitHeight: netIconText.implicitHeight
                scale: networkHover.hovered ? 1.25 : 1.0
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Glow {
                    anchors.fill: netIconText; source: netIconText
                    radius: networkHover.hovered ? 8 : 0; samples: 16
                    color: Config.accent; spread: 0.2; transparentBorder: true
                    visible: networkHover.hovered
                    Behavior on radius { NumberAnimation { duration: 180 } }
                }

                Text {
                    id: netIconText
                    anchors.centerIn: parent
                    text: shellRoot.vpnActive ? "vpn_key" : Config.getIcon("network")
                    color: (Config.showNetwork || networkHover.hovered) ? Config.accent : Config.textMain
                    font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.leftCardCollapsed && Config.isPinned("network")
            }

            TapHandler { onTapped: { popoutRequested(btnNetwork); Config.showNetwork = !Config.showNetwork; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("network") }
            HoverHandler { id: networkHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: clipComp
        Rectangle {
            id: btnClipboard
            implicitWidth: 32; implicitHeight: 32; radius: 10
            color: Config.showClipboard ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                anchors.centerIn: parent
                implicitWidth: clipIconText.implicitWidth; implicitHeight: clipIconText.implicitHeight
                scale: clipHover.hovered ? 1.25 : 1.0
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Glow {
                    anchors.fill: clipIconText; source: clipIconText
                    radius: clipHover.hovered ? 8 : 0; samples: 16
                    color: Config.accent; spread: 0.2; transparentBorder: true
                    visible: clipHover.hovered
                    Behavior on radius { NumberAnimation { duration: 180 } }
                }

                Text {
                    id: clipIconText
                    anchors.centerIn: parent
                    text: Config.getIcon("clipboard")
                    color: (Config.showClipboard || clipHover.hovered) ? Config.accent : Config.textMain
                    font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.leftCardCollapsed && Config.isPinned("clipboard")
            }

            TapHandler { onTapped: { popoutRequested(btnClipboard); Config.showClipboard = !Config.showClipboard; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("clipboard") }
            HoverHandler { id: clipHover; cursorShape: Qt.PointingHandCursor }
        }
    }
}