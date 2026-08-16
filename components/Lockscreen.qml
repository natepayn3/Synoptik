import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import "./widgets"
import "."

Scope {
    id: lockscreenScope

    // Session lock state bound to ShellRoot or Config
    property bool sessionLocked: Config.sessionLocked
    property var shellRef: null

    // Active User Information
    readonly property string currentUsername: Quickshell.env("USER") || "user"
    property string realName: Quickshell.env("USER") || "User"
    property string userAvatarPath: ""

    // Fetch user real name from getent / passwd
    Process {
        id: userInfoProc
        command: ["bash", "-c", "getent passwd $USER | cut -d ':' -f 5 | cut -d ',' -f 1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let name = this.text.trim()
                if (name.length > 0) {
                    lockscreenScope.realName = name
                }
            }
        }
    }

    // Check for user avatar (.face, .face.icon, or AccountsService)
    Process {
        id: avatarDetectProc
        command: [
            "bash", "-c",
            "for p in \"$HOME/.face\" \"$HOME/.face.icon\" \"/var/lib/AccountsService/icons/$USER\"; do " +
            "if [ -f \"$p\" ]; then echo \"$p\"; break; fi; done"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let path = this.text.trim()
                if (path.length > 0) {
                    lockscreenScope.userAvatarPath = path
                }
            }
        }
    }

    // Media Control via MPRIS / Playerctl
    property string currentTrackTitle: ""
    property string currentTrackArtist: ""
    property string currentTrackStatus: "Stopped"
    property bool hasActiveMedia: currentTrackStatus === "Playing" || currentTrackStatus === "Paused"

    Process {
        id: mediaInfoProc
        command: ["playerctl", "metadata", "--format", "{{title}}|||{{artist}}|||{{status}}"]
        running: lockscreenScope.sessionLocked
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim()
                if (out.length > 0) {
                    let parts = out.split("|||")
                    lockscreenScope.currentTrackTitle = parts[0] || ""
                    lockscreenScope.currentTrackArtist = parts[1] || ""
                    lockscreenScope.currentTrackStatus = parts[2] || "Stopped"
                } else {
                    lockscreenScope.hasActiveMedia = false
                }
            }
        }
    }

    Timer {
        id: mediaPollTimer
        interval: 3000
        running: lockscreenScope.sessionLocked
        repeat: true
        onTriggered: {
            mediaInfoProc.running = false
            mediaInfoProc.running = true
        }
    }

    // PAM Authentication Context
    PamContext {
        id: pam
        user: lockscreenScope.currentUsername
        property string pendingPassword: ""
        property var activeBar: null
        property var activeSurface: null

        onResponseRequiredChanged: {
            if (responseRequired && pendingPassword !== "") {
                respond(pendingPassword)
                pendingPassword = ""
            }
        }

        onCompleted: (result) => {
            if (result === PamResult.Success) {
                if (activeSurface) activeSurface.authStatus = "Unlocked!"
                if (activeBar) activeBar.isSuccess = true

                // Hyprland session lock restore fix
                if (Quickshell.env("XDG_CURRENT_DESKTOP") === "Hyprland" || Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== "") {
                    Quickshell.execDetached(["hyprctl", "keyword", "misc:allow_session_lock_restore", "1"])
                }
                Quickshell.execDetached(["loginctl", "unlock-session"])

                unlockTimer.start()
            } else {
                if (activeBar) {
                    activeBar.isAuthenticating = false
                    activeBar.triggerErrorFeedback()
                }
                if (activeSurface) {
                    activeSurface.authStatus = "Incorrect password. Try again."
                }
                pendingPassword = ""
            }
        }
    }

    Timer {
        id: unlockTimer
        interval: 320
        repeat: false
        onTriggered: {
            Config.sessionLocked = false
            if (lockscreenScope.shellRef) lockscreenScope.shellRef.sessionLocked = false
        }
    }

    function authenticate(password, barItem, surfaceItem) {
        pam.activeBar = barItem
        pam.activeSurface = surfaceItem
        pam.pendingPassword = password
        if (barItem) barItem.isAuthenticating = true
        if (surfaceItem) surfaceItem.authStatus = "Verifying..."
        pam.start()
    }

    // ==========================================
    // WAYLAND SESSION LOCK
    // ==========================================
    WlSessionLock {
        id: sessionLock
        locked: lockscreenScope.sessionLocked

        surface: Component {
            WlSessionLockSurface {
                id: surfaceRoot

                property string authStatus: "System Locked"
                property var currentTime: new Date()

                // Resolve whether this surface is the selected lockscreen display
                readonly property bool isTargetScreen: {
                    let target = Config.lockscreenTargetMonitor || "focused"
                    if (target === "focused") {
                        let focused = (typeof Hyprland !== "undefined" && Hyprland.focusedMonitor) ? Hyprland.focusedMonitor.name : ""
                        return focused !== "" ? (screen && screen.name === focused) : (Quickshell.screens.length > 0 && Quickshell.screens[0] === screen)
                    }
                    if (target !== "") {
                        return screen && screen.name === target
                    }
                    return Quickshell.screens.length > 0 && Quickshell.screens[0] === screen
                }

                Timer {
                    interval: 1000
                    running: lockscreenScope.sessionLocked && surfaceRoot.isTargetScreen
                    repeat: true
                    onTriggered: surfaceRoot.currentTime = new Date()
                }

                // Default blackout canvas for all surfaces
                color: "#000000"

                // Absorb unhandled touch/gestures
                PinchHandler { target: null }
                WheelHandler { target: null }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    hoverEnabled: true
                    onWheel: (wheel) => { wheel.accepted = true }
                    onClicked: {
                        if (surfaceRoot.isTargetScreen && passBar) passBar.forceFocus()
                    }
                }

                // UI Container (Only visible and active on the designated display)
                Item {
                    anchors.fill: parent
                    visible: surfaceRoot.isTargetScreen

                    // 1. WALLPAPER BACKGROUND + GAUSSIAN BLUR
                    Item {
                        anchors.fill: parent

                        Image {
                            id: bgImage
                            anchors.fill: parent
                            source: Config.activeWallpaperPath ? "file://" + Config.activeWallpaperPath : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                        }

                        FastBlur {
                            id: blurredBg
                            anchors.fill: bgImage
                            source: bgImage
                            radius: (Config.lockscreenBlurRadius !== undefined ? Config.lockscreenBlurRadius : 36)
                            transparentBorder: false
                            visible: bgImage.status === Image.Ready
                        }

                        // Fallback gradient if no wallpaper loaded
                        Rectangle {
                            anchors.fill: parent
                            visible: bgImage.status !== Image.Ready
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.darker(Config.bgBase, 1.3) }
                                GradientStop { position: 1.0; color: Qt.darker(Config.bgPanel, 1.8) }
                            }
                        }

                        // Darkening / Vignette Overlay
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 0.58)
                        }

                        // Subtle Radial Ambient Accent Glow
                        RadialGradient {
                            anchors.centerIn: parent
                            width: parent.width * 1.2
                            height: parent.height * 1.2
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.12) }
                                GradientStop { position: 0.45; color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.03) }
                                GradientStop { position: 0.8; color: "transparent" }
                            }
                        }
                    }

                    // 2. TOP STATUS BAR (Battery, Time, Host)
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 48
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 24
                            anchors.rightMargin: 24

                            // Left: Battery Indicator
                            RowLayout {
                                spacing: 16

                                // Battery Pill
                                RowLayout {
                                    spacing: 6
                                    visible: lockscreenScope.shellRef ? lockscreenScope.shellRef.hasBattery : false

                                    Text {
                                        text: {
                                            if (!lockscreenScope.shellRef) return "battery_android_frame_full"
                                            let cap = lockscreenScope.shellRef.battCapacity
                                            let status = lockscreenScope.shellRef.battStatus
                                            if (status === "Charging") return "battery_android_frame_bolt"
                                            if (cap <= 10) return "battery_android_0"
                                            if (cap <= 25) return "battery_android_frame_1"
                                            if (cap <= 40) return "battery_android_frame_2"
                                            if (cap <= 60) return "battery_android_frame_3"
                                            if (cap <= 75) return "battery_android_frame_4"
                                            if (cap <= 90) return "battery_android_frame_5"
                                            if (cap < 100) return "battery_android_frame_6"
                                            return "battery_android_frame_full"
                                        }
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 18
                                        color: (lockscreenScope.shellRef && lockscreenScope.shellRef.battCapacity <= 20) ? "#ef4444" : Config.accent
                                    }

                                    Text {
                                        text: (lockscreenScope.shellRef ? lockscreenScope.shellRef.battCapacity : 100) + "%"
                                        color: Config.textMain
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontCaption)
                                        font.bold: true
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Right: Hostname & Session Badge
                            RowLayout {
                                spacing: 12

                                Rectangle {
                                    implicitWidth: hostRow.implicitWidth + 14
                                    implicitHeight: 24
                                    radius: 12
                                    color: Qt.rgba(255, 255, 255, 0.08)

                                    RowLayout {
                                        id: hostRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: "lock"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 12
                                            color: Config.accent
                                        }

                                        Text {
                                            text: "SYNOPTIK"
                                            font.family: Config.sysFont
                                            font.pixelSize: 9
                                            font.bold: true
                                            font.letterSpacing: 1
                                            color: Config.textMuted
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. MAIN CENTER AUTHENTICATION CARD
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 24
                        width: Math.min(520, surfaceRoot.width - 48)

                        // CLOCK & DATE SECTION
                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 6

                            // Large Digital Clock + AM/PM Row
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 8

                                Item {
                                    implicitWidth: lockTimeText.implicitWidth
                                    implicitHeight: lockTimeText.implicitHeight

                                    Glow {
                                        anchors.fill: lockTimeText
                                        source: lockTimeText
                                        radius: 18
                                        samples: 24
                                        color: Config.accent
                                        spread: 0.28
                                        transparentBorder: true
                                        visible: Config.clockShowGlow !== false
                                    }

                                    Text {
                                        id: lockTimeText
                                        text: {
                                            let d = surfaceRoot.currentTime
                                            let use12 = Config.lockscreenUse12Hour !== false
                                            let showSec = Config.lockscreenShowSeconds === true
                                            let min = Qt.formatTime(d, "mm")
                                            let sec = Qt.formatTime(d, "ss")
                                            let rawHours = d.getHours()
                                            let hour = ""
                                            if (use12) {
                                                let h12 = rawHours % 12
                                                hour = (h12 === 0 ? 12 : h12).toString()
                                            } else {
                                                hour = rawHours < 10 ? ("0" + rawHours) : rawHours.toString()
                                            }
                                            return showSec ? (hour + ":" + min + ":" + sec) : (hour + ":" + min)
                                        }
                                        color: Config.textMain
                                        font.family: Config.sysFont
                                        font.pixelSize: (Config.size(Config.fontDisplay) * 2) || 96
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: -2
                                    }
                                }

                                // AM / PM Pill Badge
                                Rectangle {
                                    visible: (Config.lockscreenUse12Hour !== false) && (Config.lockscreenShowAmPm !== false)
                                    implicitWidth: amPmText.implicitWidth + 14
                                    implicitHeight: 28
                                    radius: 14
                                    color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.18)
                                    border.width: 1
                                    border.color: Config.accent
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        id: amPmText
                                        anchors.centerIn: parent
                                        text: surfaceRoot.currentTime.getHours() >= 12 ? "PM" : "AM"
                                        font.family: Config.sysFont
                                        font.pixelSize: 11
                                        font.bold: true
                                        font.letterSpacing: 1
                                        color: Config.accent
                                    }
                                }
                            }

                            // Formatted Date
                            Text {
                                id: lockDateText
                                Layout.alignment: Qt.AlignHCenter
                                text: {
                                    let d = surfaceRoot.currentTime
                                    let mode = Config.lockscreenDateFormat || "long"
                                    if (mode === "standard") return Qt.formatDate(d, "ddd, MMM d, yyyy")
                                    if (mode === "iso") return Qt.formatDate(d, "yyyy-MM-dd")
                                    if (mode === "dayFirst") return Qt.formatDate(d, "d MMMM yyyy")
                                    return Qt.formatDate(d, "dddd, MMMM d, yyyy")
                                }
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontTitle)
                                font.weight: Font.Medium
                            }
                        }

                        // USER AVATAR & IDENTITY
                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 14

                            // Avatar Circle with Glowing Ring (200px)
                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 200
                                implicitHeight: 200

                                // Outer Glowing Ring
                                RectangularGlow {
                                    anchors.fill: avatarRing
                                    glowRadius: 16
                                    spread: 0.22
                                    color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.5)
                                    cornerRadius: 100
                                    visible: Config.clockShowGlow !== false
                                }

                                Rectangle {
                                    id: avatarRing
                                    anchors.fill: parent
                                    radius: 100
                                    color: Qt.rgba(Config.bgPanel.r, Config.bgPanel.g, Config.bgPanel.b, 0.8)
                                    border.width: 3
                                    border.color: Config.accent

                                    // Avatar Image or Fallback Icon
                                    Image {
                                        id: avatarImg
                                        anchors.fill: parent
                                        anchors.margins: 5
                                        source: lockscreenScope.userAvatarPath ? "file://" + lockscreenScope.userAvatarPath : ""
                                        fillMode: Image.PreserveAspectCrop
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: avatarImg.width
                                                height: avatarImg.height
                                                radius: width / 2
                                            }
                                        }
                                        visible: status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: avatarImg.status !== Image.Ready
                                        text: "person"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 104
                                        color: Config.accent
                                    }
                                }
                            }

                            // User Display Name
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: lockscreenScope.realName
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontTitle)
                                font.bold: true
                            }

                            // Auth Status Label
                            Text {
                                id: statusLabel
                                Layout.alignment: Qt.AlignHCenter
                                text: surfaceRoot.authStatus
                                color: surfaceRoot.authStatus.includes("Incorrect") 
                                    ? "#ef4444" 
                                    : (surfaceRoot.authStatus.includes("Unlocked") ? "#10b981" : Config.textMuted)
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.italic: true

                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                        }

                        // 4. THE PASSWORD INPUT BAR WITH RANDOMIZED SHAPES / GLYPHS
                        LockscreenPasswordBar {
                            id: passBar
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            maskStyle: Config.lockscreenMaskStyle || "shapes"
                            paletteMode: Config.lockscreenShapePalette || "vibrant"

                            onSubmitPassword: (pass) => {
                                lockscreenScope.authenticate(pass, passBar, surfaceRoot)
                            }

                            onClearRequested: {
                                surfaceRoot.authStatus = "System Locked"
                            }
                        }

                        // 5. MPRIS MEDIA MINI CONTROLLER (Optional / When Playing)
                        Rectangle {
                            id: mediaCard
                            visible: (Config.lockscreenShowMedia !== false) && lockscreenScope.hasActiveMedia
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: Math.min(380, parent.width - 20)
                            implicitHeight: 52
                            radius: 26
                            color: Qt.rgba(Config.bgPanel.r, Config.bgPanel.g, Config.bgPanel.b, 0.6)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.1)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10

                                // Music Icon
                                Rectangle {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    radius: 16
                                    color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.2)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "music_note"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 18
                                        color: Config.accent
                                    }
                                }

                                // Track Info
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: lockscreenScope.currentTrackTitle || "Unknown Track"
                                        color: Config.textMain
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontCaption)
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: lockscreenScope.currentTrackArtist || "Unknown Artist"
                                        color: Config.textMuted
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontMicro)
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                // Controls (Prev, Play/Pause, Next)
                                RowLayout {
                                    spacing: 4

                                    Rectangle {
                                        implicitWidth: 28; implicitHeight: 28; radius: 14
                                        color: prevHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                                        Text { anchors.centerIn: parent; text: "skip_previous"; font.family: "Material Symbols Outlined"; font.pixelSize: 18; color: Config.textMain }
                                        HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: Quickshell.execDetached(["playerctl", "previous"]) }
                                    }

                                    Rectangle {
                                        implicitWidth: 32; implicitHeight: 32; radius: 16
                                        color: playHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.12)
                                        Text {
                                            anchors.centerIn: parent
                                            text: lockscreenScope.currentTrackStatus === "Playing" ? "pause" : "play_arrow"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 20
                                            color: playHover.hovered ? Config.bgBase : Config.textMain
                                        }
                                        HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: Quickshell.execDetached(["playerctl", "play-pause"]) }
                                    }

                                    Rectangle {
                                        implicitWidth: 28; implicitHeight: 28; radius: 14
                                        color: nextHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                                        Text { anchors.centerIn: parent; text: "skip_next"; font.family: "Material Symbols Outlined"; font.pixelSize: 18; color: Config.textMain }
                                        HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: Quickshell.execDetached(["playerctl", "next"]) }
                                    }
                                }
                            }
                        }
                    }

                    // 6. BOTTOM POWER CONTROLS
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: powerRow.implicitWidth + 24
                        implicitHeight: 48
                        radius: 24
                        color: Qt.rgba(Config.bgPanel.r, Config.bgPanel.g, Config.bgPanel.b, 0.65)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.12)
                        visible: Config.lockscreenShowPower !== false

                        RowLayout {
                            id: powerRow
                            anchors.centerIn: parent
                            spacing: 12

                            Repeater {
                                model: [
                                    { icon: "bedtime", label: "Suspend", cmd: ["systemctl", "suspend"] },
                                    { icon: "restart_alt", label: "Reboot", cmd: ["systemctl", "reboot"] },
                                    { icon: "power_settings_new", label: "Power Off", cmd: ["systemctl", "poweroff"] }
                                ]

                                delegate: Rectangle {
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    radius: 18
                                    color: pwrHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 20
                                        color: pwrHover.hovered ? Config.accent : Config.textMuted
                                    }

                                    HoverHandler { id: pwrHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        onTapped: Quickshell.execDetached(modelData.cmd)
                                    }
                                }
                            }
                        }
                    }
                }

                Component.onCompleted: {
                    if (surfaceRoot.isTargetScreen && passBar) {
                        passBar.forceFocus()
                    }
                }
            }
        }
    }
}