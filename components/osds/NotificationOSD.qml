import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Notifications as Notifs
import ".."

Item {
    id: osdRoot

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    // Static bounds to prevent UnifiedSurface evaluation loops
    implicitWidth: 500
    implicitHeight: Math.max(80, contentColumn.implicitHeight + (cardMargin * 4))

    property string notifTitle: ""
    property string notifBody: ""
    property string notifApp: ""
    property int notifUrgency: Notifs.NotificationUrgency.Normal

    // The live Notification object behind the OSD, kept so its actions can
    // actually be invoked. The server advertises actionsSupported over D-Bus,
    // which changes how clients behave - Thunderbird, Element and KDE Connect
    // all attach Reply / Mark read / Snooze buttons when they see it - and
    // nothing here ever read notif.actions, so those buttons were promised and
    // then silently dropped.
    property var currentNotif: null

    readonly property var notifActions: {
        if (!currentNotif) return []
        let a = currentNotif.actions
        return a ? a : []
    }

    // Notification images (album art from a music player, an avatar from a
    // chat client) were dropped too - imageSupported was never declared, so
    // clients didn't send them.
    readonly property string notifImage: currentNotif ? (currentNotif.image || "") : ""
    readonly property string notifAppIcon: currentNotif ? (currentNotif.appIcon || "") : ""

    SoundEffect {
        id: notifSoundPlayer
        // Inline Comment: Dynamically target notification sound WAV asset from Quickshell directory
        source: Qt.resolvedUrl(Quickshell.shellDir.toString() + "/assets/" + (Config.notificationSoundPath || "sound1.wav"))
        volume: 0.25
    }

    function playNotificationSound() {
        if (!Config.playNotificationSounds) return
        // Inline Comment: Instant sample trigger without FFmpeg demuxer buffer rewinds
        notifSoundPlayer.play()
    }

    readonly property string appIcon: {
        let app = osdRoot.notifApp.toLowerCase()
        if (app.includes("discord") || app.includes("vesktop")) return "forum"
        if (app.includes("spotify") || app.includes("music")) return "music_note"
        if (app.includes("terminal") || app.includes("kitty") || app.includes("foot")) return "terminal"
        if (app.includes("code") || app.includes("nvim")) return "code"
        if (app.includes("firefox") || app.includes("chrome") || app.includes("browser")) return "language"
        if (app.includes("steam") || app.includes("game")) return "sports_esports"
        return "notifications_active"
    }

    Connections {
        target: (typeof notifServer !== "undefined" && notifServer !== null) ? notifServer : null
        ignoreUnknownSignals: true

        function onNotification(notif) {
            if (!notif) return;
            notif.tracked = true;

            // Block OSD if DND is active
            if (typeof notifServer !== "undefined" && notifServer && notifServer.dnd) return;

            osdRoot.currentNotif = notif;
            osdRoot.notifApp = notif.appName ? notif.appName : "System";
            osdRoot.notifTitle = notif.summary ? notif.summary : "Notification";
            osdRoot.notifBody = notif.body ? notif.body : "";
            osdRoot.notifUrgency = notif.urgency;

            osdRoot.trigger();
        }
    }

    function invokeAction(action) {
        if (!action) return
        action.invoke()
        // Invoking an action resolves the notification, so take the OSD down
        // with it rather than leaving a card whose buttons now do nothing.
        osdRoot.dismiss()
    }

    function trigger() {
        osdHideTimer.stop()
        Config.showNotificationOsd = true

        // Play notification arrival sound effect
        osdRoot.playNotificationSound()
        rippleAnim.restart()

        // A card with buttons has to stay up long enough to actually click
        // one; 4s is fine for a receipt, not for a decision.
        osdHideTimer.interval = osdRoot.notifActions.length > 0 ? 9000 : 4000
        if (osdRoot.notifUrgency !== Notifs.NotificationUrgency.Critical) {
            osdHideTimer.restart()
        }
    }

    function dismiss() {
        Config.showNotificationOsd = false
        osdHideTimer.stop()
        osdRoot.currentNotif = null
    }

    Timer {
        id: osdHideTimer
        interval: 4000
        repeat: false
        onTriggered: osdRoot.dismiss()
    }

    // Click-to-dismiss sits behind the content (z: -1) so it can't swallow
    // taps aimed at the action buttons layered above it.
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: osdRoot.dismiss()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: osdRoot.cardMargin
        spacing: osdRoot.cardMargin

        Rectangle {
            implicitWidth: 48
            implicitHeight: 48
            radius: Config.cornerRadius / 2
            color: Qt.rgba(255, 255, 255, 0.06)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: osdRoot.appIcon
                visible: !notifImageView.visible
                color: osdRoot.notifUrgency === Notifs.NotificationUrgency.Critical ? "#ef4444" : Config.accent
                font.family: "Material Symbols Outlined"
                font.pixelSize: 24
            }

            // Album art, an avatar, whatever the client attached. Falls back to
            // the app-name glyph above when there is no image or it won't load.
            Image {
                id: notifImageView
                anchors.fill: parent
                anchors.margins: 1
                source: osdRoot.notifImage !== "" ? osdRoot.notifImage : osdRoot.notifAppIcon
                visible: source != "" && status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                // Decode at the size actually drawn - an avatar or cover from a
                // client can be 1000px+, and this tile is 48.
                sourceSize.width: 96
                sourceSize.height: 96

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: notifImageView.width
                        height: notifImageView.height
                        radius: Config.cornerRadius / 2
                    }
                }
            }

            // Ripple pulse on arrival - a ring of accent color expanding out of
            // the icon tile and fading, so a new notification announces itself
            // in color rather than just popping the OSD into view.
            Rectangle {
                id: notifyRipple
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: parent.radius
                color: "transparent"
                border.width: 2
                border.color: osdRoot.notifUrgency === Notifs.NotificationUrgency.Critical ? "#ef4444" : Config.accent
                opacity: 0
                scale: 1.0

                ParallelAnimation {
                    id: rippleAnim
                    NumberAnimation { target: notifyRipple; property: "scale"; from: 1.0; to: 1.9; duration: 650; easing.type: Easing.OutCubic }
                    NumberAnimation { target: notifyRipple; property: "opacity"; from: 0.9; to: 0; duration: 650; easing.type: Easing.OutCubic }
                }
            }

            // Pulsing urgency badge - same beat as ScreenRecorder's recording
            // indicator (ScreenRecorder.qml), so "something needs attention"
            // reads consistently across the shell.
            Rectangle {
                id: urgencyDot
                visible: osdRoot.notifUrgency === Notifs.NotificationUrgency.Critical
                width: 10
                height: 10
                radius: 5
                color: "#ef4444"
                border.width: 2
                border.color: Config.bgBase
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -2
                anchors.rightMargin: -2

                SequentialAnimation {
                    running: urgencyDot.visible
                    loops: Animation.Infinite
                    PropertyAnimation { target: urgencyDot; property: "opacity"; to: 0.3; duration: 600 }
                    PropertyAnimation { target: urgencyDot; property: "opacity"; to: 1.0; duration: 600 }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Config.cornerRadius / 2
            color: Qt.rgba(255, 255, 255, 0.05)

            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.leftMargin: osdRoot.cardMargin
                anchors.rightMargin: osdRoot.cardMargin
                anchors.topMargin: osdRoot.cardMargin
                anchors.bottomMargin: osdRoot.cardMargin
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: senderText.implicitHeight

                        Text {
                            id: senderText
                            anchors.fill: parent
                            text: osdRoot.notifApp.toUpperCase()
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: true
                            font.italic: true
                            font.letterSpacing: 0.8
                            elide: Text.ElideRight
                        }

                        Glow {
                            anchors.fill: senderText
                            source: senderText
                            radius: 8
                            samples: 24
                            color: Config.accent
                            spread: 0.1
                            visible: true 
                        }
                    }

                    Rectangle {
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: 11
                        color: closeArea.containsMouse ? Qt.rgba(255, 255, 255, 0.25) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            color: closeArea.containsMouse ? Config.accent : Config.textMuted
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                mouse.accepted = true
                                osdRoot.dismiss()
                            }
                        }
                    }
                }

                Text {
                    text: osdRoot.notifTitle
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontSubhead)
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    visible: osdRoot.notifBody !== ""
                    text: osdRoot.notifBody
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }

                // --- ACTION BUTTONS ---
                // The payoff for shell.qml's actionsSupported flag. Most
                // clients send a "default" action meaning "clicking the body
                // opens me"; that isn't a button anywhere else on the desktop,
                // so it's filtered out rather than drawn as one.
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 6
                    visible: osdRoot.notifActions.length > 0

                    Repeater {
                        model: osdRoot.notifActions

                        delegate: Rectangle {
                            required property var modelData

                            visible: modelData && modelData.identifier !== "default"
                                && (modelData.text || "") !== ""
                            width: visible ? actionLabel.implicitWidth + 22 : 0
                            height: visible ? 26 : 0
                            radius: 6
                            color: actionMouse.containsMouse
                                ? Config.accent
                                : Qt.rgba(255, 255, 255, 0.08)
                            border.width: 1
                            border.color: actionMouse.containsMouse
                                ? Config.accent
                                : Qt.rgba(255, 255, 255, 0.15)
                            Behavior on color { ColorAnimation { duration: 130 } }

                            Text {
                                id: actionLabel
                                anchors.centerIn: parent
                                text: modelData ? modelData.text : ""
                                color: actionMouse.containsMouse ? Config.bgBase : Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    mouse.accepted = true
                                    osdRoot.invokeAction(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}