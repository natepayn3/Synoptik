import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Rectangle {
    id: leftCard

    property var rootRef
    signal popoutRequested(var item)

    // Inline Comment: Map instantiated child items by icon key for PanelWindow origin tracking
    function getButton(key) {
        for (let i = 0; i < repeater.count; i++) {
            let loader = repeater.itemAt(i)
            if (loader && loader.itemKey === key && loader.item) {
                return loader.item
            }
        }
        return leftCard
    }

    width: rootRef.isHorizontal ? (leftModules.implicitWidth + 4) : 36
    height: rootRef.isHorizontal ? 36 : (leftModules.implicitHeight + 4)
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

    GridLayout {
        id: leftModules
        anchors.centerIn: parent
        columns: rootRef.isHorizontal ? 99 : 1
        rows: rootRef.isHorizontal ? 1 : 99
        columnSpacing: 8
        rowSpacing: 8

        Repeater {
            id: repeater
            model: Config.leftCardOrder || ["power", "recorder", "screenshot", "notifications", "wallpaper", "settings", "launcher"]

            delegate: Loader {
                readonly property string itemKey: modelData
                sourceComponent: {
                    switch(itemKey) {
                        case "power": return powerComp
                        case "recorder": return recorderComp
                        case "screenshot": return screenshotComp
                        case "notifications": return notifComp
                        case "wallpaper": return wallpaperComp
                        case "settings": return settingsComp
                        case "launcher": return launcherComp
                        default: return null
                    }
                }
            }
        }

        Rectangle {
            implicitWidth: 32; implicitHeight: 32; radius: 10
            color: chevronLeftHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: {
                    if (rootRef.isHorizontal) return Config.leftCardCollapsed ? "chevron_right" : "chevron_left"
                    return Config.leftCardCollapsed ? "expand_more" : "expand_less"
                }
                color: Config.textMuted
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
            }

            TapHandler { onTapped: Config.leftCardCollapsed = !Config.leftCardCollapsed }
            HoverHandler { id: chevronLeftHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: powerComp
        Rectangle {
            id: btnPower
            visible: !Config.leftCardCollapsed || Config.isPinned("power")
            opacity: visible ? 1.0 : 0.0
            implicitWidth: visible ? 32 : 0
            implicitHeight: visible ? 32 : 0
            radius: 10
            color: (Config.showPower || powerHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: Config.getIcon("power")
                color: Config.showPower ? Config.accent : Config.textMain
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
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
            visible: !Config.leftCardCollapsed || Config.isPinned("recorder")
            opacity: visible ? 1.0 : 0.0
            implicitWidth: visible ? 32 : 0
            implicitHeight: visible ? 32 : 0
            radius: 10
            color: (Config.showScreenRecorder || recordHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: (typeof shellRoot !== "undefined" && shellRoot.isRecording) ? "radio_button_checked" : Config.getIcon("recorder")
                color: (typeof shellRoot !== "undefined" && shellRoot.isRecording) ? "#ef4444" : (Config.showScreenRecorder ? Config.accent : Config.textMain)
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
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
        id: screenshotComp
        Rectangle {
            visible: !Config.leftCardCollapsed || Config.isPinned("screenshot")
            opacity: visible ? 1.0 : 0.0
            implicitWidth: visible ? 32 : 0
            implicitHeight: visible ? 32 : 0
            radius: 10
            color: screenshotHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: Config.getIcon("screenshot")
                color: Config.textMain
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
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
            visible: !Config.leftCardCollapsed || Config.isPinned("notifications")
            opacity: visible ? 1.0 : 0.0
            implicitWidth: visible ? 32 : 0
            implicitHeight: visible ? 32 : 0
            radius: 10
            color: (Config.showNotifications || notificationsHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: (typeof shellRoot !== "undefined" && shellRoot.activeNotifs > 0) ? "inbox_text" : Config.getIcon("notifications")
                color: (Config.showNotifications || (typeof shellRoot !== "undefined" && shellRoot.activeNotifs > 0)) ? Config.accent : Config.textMain
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18

                Behavior on color { ColorAnimation { duration: 150 } }
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
            visible: !Config.leftCardCollapsed || Config.isPinned("wallpaper")
            opacity: visible ? 1.0 : 0.0
            implicitWidth: visible ? 32 : 0
            implicitHeight: visible ? 32 : 0
            radius: 10
            color: (Config.showWallpaper || wallpaperHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: Config.getIcon("wallpaper")
                color: Config.showWallpaper ? Config.accent : Config.textMain
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
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
            visible: !Config.leftCardCollapsed || Config.isPinned("settings")
            opacity: visible ? 1.0 : 0.0
            implicitWidth: visible ? 32 : 0
            implicitHeight: visible ? 32 : 0
            radius: 10
            color: (Config.showSettings || settingsHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: Config.getIcon("settings")
                color: Config.showSettings ? Config.accent : Config.textMain
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
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
            visible: !Config.leftCardCollapsed || Config.isPinned("launcher")
            opacity: visible ? 1.0 : 0.0
            implicitWidth: visible ? 32 : 0
            implicitHeight: visible ? 32 : 0
            radius: 10
            color: (Config.showAppLauncher || launcherHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: Config.getIcon("launcher")
                color: Config.showAppLauncher ? Config.accent : Config.textMain
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
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
}