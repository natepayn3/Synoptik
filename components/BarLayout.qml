import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: topBar
            required property var modelData
            screen: modelData
            visible: modelData && modelData.name !== "" && Config.isBarEnabledForScreen(modelData.name)
            color: "transparent"

            readonly property string pos: Config.barPosition || "top"
            readonly property bool isVert: pos === "left" || pos === "right"

            anchors.left: pos === "left" || !isVert
            anchors.right: pos === "right" || !isVert
            anchors.top: pos === "top" || isVert
            anchors.bottom: pos === "bottom" || isVert

            implicitWidth: isVert ? Config.barHeight : screen.width
            implicitHeight: isVert ? screen.height : Config.barHeight

            margins {
                top: pos === "top" ? Config.barMargin : 0
                bottom: pos === "bottom" ? Config.barMargin : 0
                left: pos === "left" ? Config.barMargin : 0
                right: pos === "right" ? Config.barMargin : 0
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusiveZone: -1

            Item {
                id: barContainer
                anchors.fill: parent

                // HORIZONTAL BAR CONTENT LAYOUT
                Item {
                    anchors.fill: parent
                    visible: !isVert

                    RowLayout {
                        id: leftModules
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 10
                        }
                        spacing: 8
                        
                        // Notifications
                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showNotifications || notificationsHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: shellRoot.activeNotifs > 0 ? "mark_email_unread" : "mail"
                                color: (Config.showNotifications || shellRoot.activeNotifs > 0) ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showNotifications) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false; Config.showCalendar = false; Config.showBattery = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showNotifications = !Config.showNotifications
                                }
                            }
                            HoverHandler { id: notificationsHover; cursorShape: Qt.PointingHandCursor }
                        }

                        // Power
                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showPower || powerHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "electrical_services" 
                                color: Config.showPower ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showPower) {
                                        Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false; Config.showBattery = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showPower = !Config.showPower
                                }
                            }
                            HoverHandler { id: powerHover; cursorShape: Qt.PointingHandCursor }
                        }

                        // Wallpaper
                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showWallpaper || wallpaperHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "wall_art" 
                                color: Config.showWallpaper ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showWallpaper) {
                                        Config.showPower = false; Config.showSettings = false; Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false; Config.showBattery = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showWallpaper = !Config.showWallpaper
                                }
                            }
                            HoverHandler { id: wallpaperHover; cursorShape: Qt.PointingHandCursor }
                        }

                        // App Launcher
                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showAppLauncher || launcherHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "terminal_2" 
                                color: Config.showAppLauncher ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showAppLauncher) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showCalendar = false; Config.showNotifications = false; Config.showBattery = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showAppLauncher = !Config.showAppLauncher
                                }
                            }
                            HoverHandler { id: launcherHover; cursorShape: Qt.PointingHandCursor }
                        }

                        // Screenshot
                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: screenshotHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "crop"
                                color: Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                            }

                            TapHandler {
                                onTapped: {
                                    Quickshell.execDetached(["fish", "-c", "sleep 0.1; and grim -g (slurp) -t ppm - | satty --filename -"])
                                }
                            }
                            HoverHandler { id: screenshotHover; cursorShape: Qt.PointingHandCursor }
                        }

                        // Clipboard
                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showClipboard || clipHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "content_paste"
                                color: Config.showClipboard ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showClipboard) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false; Config.showBattery = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showClipboard = !Config.showClipboard
                                }
                            }
                            HoverHandler { id: clipHover; cursorShape: Qt.PointingHandCursor }
                        }

                        // Screen Recorder Toggle Icon
                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showScreenRecorder || recordHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: shellRoot.isRecording ? "videocam" : "movie"
                                color: shellRoot.isRecording ? "#ef4444" : (Config.showScreenRecorder ? Config.accent : Config.textMain)
                                font.family: "Material Symbols Outlined"
                                font.weight: Font.Bold
                                font.pixelSize: 20

                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            TapHandler {
                                onTapped: {
                                    let nextState = !Config.showScreenRecorder
                                    Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; 
                                    Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false; 
                                    Config.showBattery = false; Config.showWorkspacePreview = false; Config.showClipboard = false;
                                    Config.showScreenRecorder = nextState
                                }
                            }
                            HoverHandler { id: recordHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        implicitHeight: 32
                        implicitWidth: centerGroup.implicitWidth + 24
                        radius: Config.cornerRadius / 2
                        color: Qt.rgba(255, 255, 255, 0.05)

                        RowLayout {
                            id: centerGroup
                            anchors.centerIn: parent
                            spacing: 16

                            WorkspaceIndicators {
                                isVertical: false
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item {
                                id: taskbarContainerH
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: horizTaskbarLoader.item ? horizTaskbarLoader.item.implicitWidth : 0
                                implicitHeight: horizTaskbarLoader.item ? horizTaskbarLoader.item.implicitHeight : 0

                                Timer {
                                    id: horizBootTimer
                                    interval: 350
                                    running: true
                                    repeat: false
                                    onTriggered: horizTaskbarLoader.active = true
                                }

                                Loader {
                                    id: horizTaskbarLoader
                                    active: false
                                    anchors.fill: parent

                                    sourceComponent: Taskbar {
                                        isVertical: false
                                        activeScreenName: topBar.screen.name
                                    }
                                }
                            }
                        }

                        TapHandler {
                            onTapped: {
                                if (!Config.showWorkspacePreview) {
                                    Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; 
                                    Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false; 
                                    Config.showAudio = false; Config.showNetwork = false; Config.showSystemMonitor = false; 
                                    Config.showBattery = false; Config.showClipboard = false; Config.showControlCenter = false;
                                    Config.showScreenRecorder = false;
                                }
                                Config.showWorkspacePreview = !Config.showWorkspacePreview
                            }
                        }
                    }

                    RowLayout {
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 10
                        }
                        spacing: 8

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showAudio || audioHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: shellRoot.audioMuted ? "hearing_disabled" : (shellRoot.audioVolume === 0 ? "hearing_disabled" : (shellRoot.audioVolume < 50 ? "hearing" : "ear_sound"))
                                color: Config.showAudio ? Config.accent : (shellRoot.audioMuted ? Config.textMuted : Config.textMain)
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showAudio) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false;
                                        Config.showCalendar = false; Config.showNotifications = false; Config.showWifi = false;
                                        Config.showNetwork = false; Config.showBluetooth = false; Config.showBattery = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showAudio = !Config.showAudio
                                }
                            }
                            HoverHandler { id: audioHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showNetwork || networkHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: shellRoot.vpnActive ? "vpn_key" : "lan"
                                color: Config.showNetwork ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showNetwork) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false;
                                        Config.showCalendar = false; Config.showNotifications = false; Config.showWifi = false;
                                        Config.showAudio = false; Config.showBluetooth = false; Config.showNetwork = false; Config.showBattery = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showNetwork = !Config.showNetwork
                                }
                            }
                            HoverHandler { id: networkHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showSystemMonitor || sysHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "neurology"
                                color: Config.showSystemMonitor ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showSystemMonitor) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false;
                                        Config.showCalendar = false; Config.showNotifications = false; Config.showWifi = false;
                                        Config.showAudio = false; Config.showBluetooth = false; Config.showNetwork = false;
                                        Config.showBattery = false; Config.showControlCenter = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showSystemMonitor = !Config.showSystemMonitor
                                }
                            }
                            HoverHandler { id: sysHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            visible: shellRoot.hasBattery
                            color: (Config.showBattery || battHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (shellRoot.battStatus === "Charging") return "battery_android_frame_bolt"
                                    if (shellRoot.battCapacity <= 10) return "battery_android_frame_alert"
                                    if (shellRoot.battCapacity <= 25) return "battery_android_frame_1"
                                    if (shellRoot.battCapacity <= 40) return "battery_android_frame_2"
                                    if (shellRoot.battCapacity <= 55) return "battery_android_frame_3"
                                    if (shellRoot.battCapacity <= 70) return "battery_android_frame_4"
                                    if (shellRoot.battCapacity <= 85) return "battery_android_frame_5"
                                    if (shellRoot.battCapacity < 100) return "battery_android_frame_6"
                                    return "battery_android_frame_full"
                                }
                                color: Config.showBattery ? Config.accent : (shellRoot.battCapacity <= 15 ? "#ef4444" : Config.textMain)
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showBattery) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false;
                                        Config.showCalendar = false; Config.showNotifications = false; Config.showWifi = false;
                                        Config.showAudio = false; Config.showBluetooth = false; Config.showNetwork = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showBattery = !Config.showBattery
                                }
                            }
                            HoverHandler { id: battHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showControlCenter || ccHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "widgets"
                                color: Config.showControlCenter ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                            }

                            TapHandler { 
                                onTapped: {
                                    if (!Config.showControlCenter) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false; Config.showAudio = false; Config.showNetwork = false; Config.showSystemMonitor = false; Config.showBattery = false; Config.showClipboard = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showControlCenter = !Config.showControlCenter
                                }
                            }
                            HoverHandler { id: ccHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32
                            implicitHeight: dateCol.implicitHeight + 12
                            radius: 10
                            color: (Config.showCalendar || clockHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            ColumnLayout {
                                id: dateCol
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: shellRoot.vertHour || (new Date().getHours() % 12 || 12).toString()
                                    color: Config.showCalendar ? Config.accent : Config.textMain
                                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: Config.size(Config.fontTitle)
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: shellRoot.vertMinute || Qt.formatTime(new Date(), "mm")
                                    color: Config.showCalendar ? Config.accent : Config.textMain
                                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: Config.size(Config.fontTitle)
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: shellRoot.vertAmPm || Qt.formatTime(new Date(), "ap").toLowerCase()
                                    color: Config.accent
                                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: Config.size(Config.fontCaption)
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: (shellRoot.vertMonth || Qt.formatDate(new Date(), "MMM")) + " " + (shellRoot.vertDay || Qt.formatDate(new Date(), "d"))
                                    color: Config.showCalendar ? Config.accent : Config.textMuted
                                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: Config.size(Config.fontCaption)
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            TapHandler { 
                                onTapped: {
                                    if (!Config.showCalendar) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; 
                                        Config.showAppLauncher = false; Config.showNotifications = false; Config.showAudio = false; 
                                        Config.showNetwork = false; Config.showSystemMonitor = false; Config.showBattery = false; 
                                        Config.showClipboard = false; Config.showControlCenter = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showCalendar = !Config.showCalendar
                                }
                            }
                            HoverHandler { id: clockHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }

                // VERTICAL BAR CONTENT LAYOUT
                Item {
                    anchors.fill: parent
                    visible: isVert

                    ColumnLayout {
                        id: topVertModules
                        anchors {
                            top: parent.top
                            horizontalCenter: parent.horizontalCenter
                            topMargin: 10
                        }
                        spacing: 8

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showNotifications || vNotifHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: shellRoot.activeNotifs > 0 ? "mark_email_unread" : "mail"
                                color: (Config.showNotifications || shellRoot.activeNotifs > 0) ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showNotifications) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false; Config.showCalendar = false; Config.showBattery = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showNotifications = !Config.showNotifications
                                }
                            }
                            HoverHandler { id: vNotifHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showPower || vPowerHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "electrical_services"
                                color: Config.showPower ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showPower) {
                                        Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false; Config.showBattery = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showPower = !Config.showPower
                                }
                            }
                            HoverHandler { id: vPowerHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showWallpaper || vWallHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "wall_art"
                                color: Config.showWallpaper ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showWallpaper) {
                                        Config.showPower = false; Config.showSettings = false; Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false; Config.showBattery = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showWallpaper = !Config.showWallpaper
                                }
                            }
                            HoverHandler { id: vWallHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showAppLauncher || vLaunchHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "terminal_2"
                                color: Config.showAppLauncher ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showAppLauncher) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showCalendar = false; Config.showNotifications = false; Config.showBattery = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showAppLauncher = !Config.showAppLauncher
                                }
                            }
                            HoverHandler { id: vLaunchHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: vShotHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "crop"
                                color: Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                            }

                            TapHandler {
                                onTapped: {
                                    Quickshell.execDetached(["fish", "-c", "sleep 0.1; and grim -g (slurp) -t ppm - | satty --filename -"])
                                }
                            }
                            HoverHandler { id: vShotHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showClipboard || vClipHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "content_paste"
                                color: Config.showClipboard ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showClipboard) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false; Config.showBattery = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showClipboard = !Config.showClipboard
                                }
                            }
                            HoverHandler { id: vClipHover; cursorShape: Qt.PointingHandCursor }
                        }

                        // Screen Recorder Toggle Icon (Vertical)
                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showScreenRecorder || vRecordHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: shellRoot.isRecording ? "videocam" : "movie"
                                color: shellRoot.isRecording ? "#ef4444" : (Config.showScreenRecorder ? Config.accent : Config.textMain)
                                font.family: "Material Symbols Outlined"
                                font.weight: Font.Bold
                                font.pixelSize: 20

                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            TapHandler {
                                onTapped: {
                                    let nextState = !Config.showScreenRecorder
                                    Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; 
                                    Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false; 
                                    Config.showBattery = false; Config.showWorkspacePreview = false; Config.showClipboard = false;
                                    Config.showScreenRecorder = nextState
                                }
                            }
                            HoverHandler { id: vRecordHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        implicitWidth: 32
                        implicitHeight: centerVertGroup.implicitHeight + 24
                        radius: Config.cornerRadius / 2
                        color: Qt.rgba(255, 255, 255, 0.05)

                        ColumnLayout {
                            id: centerVertGroup
                            anchors.centerIn: parent
                            spacing: 16

                            WorkspaceIndicators {
                                isVertical: true
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Item {
                                id: taskbarContainerV
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: vertTaskbarLoader.item ? vertTaskbarLoader.item.implicitWidth : 0
                                implicitHeight: vertTaskbarLoader.item ? vertTaskbarLoader.item.implicitHeight : 0

                                Timer {
                                    id: vertBootTimer
                                    interval: 350
                                    running: true
                                    repeat: false
                                    onTriggered: vertTaskbarLoader.active = true
                                }

                                Loader {
                                    id: vertTaskbarLoader
                                    active: false
                                    anchors.fill: parent

                                    sourceComponent: Taskbar {
                                        isVertical: true
                                        activeScreenName: topBar.screen.name
                                    }
                                }
                            }
                        }

                        TapHandler {
                            onTapped: {
                                if (!Config.showWorkspacePreview) {
                                    Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false;
                                    Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false;
                                    Config.showAudio = false; Config.showNetwork = false; Config.showSystemMonitor = false;
                                    Config.showBattery = false; Config.showClipboard = false; Config.showControlCenter = false;
                                    Config.showScreenRecorder = false;
                                }
                                Config.showWorkspacePreview = !Config.showWorkspacePreview
                            }
                        }
                    }

                    ColumnLayout {
                        anchors {
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                            bottomMargin: 10
                        }
                        spacing: 8

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showAudio || vAudioHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: shellRoot.audioMuted ? "hearing_disabled" : (shellRoot.audioVolume === 0 ? "hearing_disabled" : (shellRoot.audioVolume < 50 ? "hearing" : "ear_sound"))
                                color: Config.showAudio ? Config.accent : (shellRoot.audioMuted ? Config.textMuted : Config.textMain)
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showAudio) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false;
                                        Config.showCalendar = false; Config.showNotifications = false; Config.showWifi = false;
                                        Config.showNetwork = false; Config.showBluetooth = false; Config.showBattery = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showAudio = !Config.showAudio
                                }
                            }
                            HoverHandler { id: vAudioHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showNetwork || vNetHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: shellRoot.vpnActive ? "vpn_key" : "lan"
                                color: Config.showNetwork ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showNetwork) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false;
                                        Config.showCalendar = false; Config.showNotifications = false; Config.showWifi = false;
                                        Config.showAudio = false; Config.showBluetooth = false; Config.showNetwork = false; Config.showBattery = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showNetwork = !Config.showNetwork
                                }
                            }
                            HoverHandler { id: vNetHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showSystemMonitor || vSysHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "neurology"
                                color: Config.showSystemMonitor ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showSystemMonitor) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false;
                                        Config.showCalendar = false; Config.showNotifications = false; Config.showWifi = false;
                                        Config.showAudio = false; Config.showBluetooth = false; Config.showNetwork = false;
                                        Config.showBattery = false; Config.showControlCenter = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showSystemMonitor = !Config.showSystemMonitor
                                }
                            }
                            HoverHandler { id: vSysHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            visible: shellRoot.hasBattery
                            color: (Config.showBattery || vBattHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (shellRoot.battStatus === "Charging") return "battery_android_frame_bolt"
                                    if (shellRoot.battCapacity <= 10) return "battery_android_frame_alert"
                                    if (shellRoot.battCapacity <= 25) return "battery_android_frame_1"
                                    if (shellRoot.battCapacity <= 40) return "battery_android_frame_2"
                                    if (shellRoot.battCapacity <= 55) return "battery_android_frame_3"
                                    if (shellRoot.battCapacity <= 70) return "battery_android_frame_4"
                                    if (shellRoot.battCapacity <= 85) return "battery_android_frame_5"
                                    if (shellRoot.battCapacity < 100) return "battery_android_frame_6"
                                    return "battery_android_frame_full"
                                }
                                color: Config.showBattery ? Config.accent : (shellRoot.battCapacity <= 15 ? "#ef4444" : Config.textMain)
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                            }

                            TapHandler {
                                onTapped: {
                                    if (!Config.showBattery) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false;
                                        Config.showCalendar = false; Config.showNotifications = false; Config.showWifi = false;
                                        Config.showAudio = false; Config.showBluetooth = false; Config.showNetwork = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showBattery = !Config.showBattery
                                }
                            }
                            HoverHandler { id: vBattHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32; radius: 10
                            color: (Config.showControlCenter || vCcHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "widgets"
                                color: Config.showControlCenter ? Config.accent : Config.textMain
                                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
                            }

                            TapHandler { 
                                onTapped: {
                                    if (!Config.showControlCenter) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; Config.showAppLauncher = false; Config.showCalendar = false; Config.showNotifications = false; Config.showAudio = false; Config.showNetwork = false; Config.showSystemMonitor = false; Config.showBattery = false; Config.showClipboard = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showControlCenter = !Config.showControlCenter
                                }
                            }
                            HoverHandler { id: vCcHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 32
                            implicitHeight: vDateCol.implicitHeight + 12
                            radius: 10
                            color: (Config.showCalendar || vClockHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            ColumnLayout {
                                id: vDateCol
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: shellRoot.vertHour || (new Date().getHours() % 12 || 12).toString()
                                    color: Config.showCalendar ? Config.accent : Config.textMain
                                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: Config.size(Config.fontTitle)
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: shellRoot.vertMinute || Qt.formatTime(new Date(), "mm")
                                    color: Config.showCalendar ? Config.accent : Config.textMain
                                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: Config.size(Config.fontTitle)
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: shellRoot.vertAmPm || Qt.formatTime(new Date(), "ap").toLowerCase()
                                    color: Config.accent
                                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: Config.size(Config.fontCaption)
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: (shellRoot.vertMonth || Qt.formatDate(new Date(), "MMM")) + " " + (shellRoot.vertDay || Qt.formatDate(new Date(), "d"))
                                    color: Config.showCalendar ? Config.accent : Config.textMuted
                                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: Config.size(Config.fontCaption)
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            TapHandler { 
                                onTapped: {
                                    if (!Config.showCalendar) {
                                        Config.showPower = false; Config.showSettings = false; Config.showWallpaper = false; 
                                        Config.showAppLauncher = false; Config.showNotifications = false; Config.showAudio = false; 
                                        Config.showNetwork = false; Config.showSystemMonitor = false; Config.showBattery = false; 
                                        Config.showClipboard = false; Config.showControlCenter = false; Config.showWorkspacePreview = false; Config.showScreenRecorder = false;
                                    }
                                    Config.showCalendar = !Config.showCalendar
                                }
                            }
                            HoverHandler { id: vClockHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }
        }
    }
}