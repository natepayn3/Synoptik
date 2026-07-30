import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications as Notifs

PanelWindow {
    id: root

    property color flyoutBorderColor: Config.accent
    property real panelWidth: 460
    
    // Dynamic height calculation based on inner layout content
    property real baseContentHeight: contentColumn.implicitHeight
    property real panelHeight: Math.max(80, baseContentHeight + 48)

    // Add padding to implicit dimensions to prevent overshoot clipping
    property real overshootPadding: 50

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
    }

    margins {
        top: (Config.barHeight || 30) - (overshootPadding / 2)
    }

    implicitWidth: panelWidth + overshootPadding
    implicitHeight: panelHeight + overshootPadding
    color: "transparent"

    // Behavior on height changes for smooth resizing transitions
    Behavior on panelHeight {
        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
    }

    // Mask spans the padded frame so the bounce doesn't get clipped
    mask: Region {
        item: mainFrame
    }

    visible: Config.showNotificationOsd || closeTransition.running || openTransition.running

    property string notifTitle: ""
    property string notifBody: ""
    property string notifApp: ""
    property int notifUrgency: Notifs.NotificationUrgency.Normal

    // --- APP ICON RESOLVER ---
    readonly property string appIcon: {
        let app = root.notifApp.toLowerCase()
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

            if ((typeof notifServer !== "undefined" && notifServer && notifServer.dnd) || (typeof Config.showNotifications !== "undefined" && Config.showNotifications)) return;

            root.notifApp = notif.appName ? notif.appName : "System";
            root.notifTitle = notif.summary ? notif.summary : "Notification";
            root.notifBody = notif.body ? notif.body : "";
            root.notifUrgency = notif.urgency;
            root.trigger();
        }
    }

    function trigger() {
        osdHideTimer.stop()
        Config.showNotificationOsd = true
        
        if (root.notifUrgency !== Notifs.NotificationUrgency.Critical) {
            osdHideTimer.restart()
        }
    }

    function dismiss() {
        Config.showNotificationOsd = false
        osdHideTimer.stop()
    }

    Timer {
        id: osdHideTimer
        interval: 4000
        repeat: false
        onTriggered: root.dismiss()
    }

    // Static frame padded to allow bounce room
    Item {
        id: mainFrame
        anchors.fill: parent

        // Centered scaling container
        Item {
            id: breathingContainer
            width: root.panelWidth
            height: root.panelHeight
            anchors.centerIn: parent
            transformOrigin: Item.Center

            states: [
                State {
                    name: "open"
                    when: Config.showNotificationOsd
                    PropertyChanges { target: breathingContainer; scale: 1.0; opacity: 1.0 }
                },
                State {
                    name: "closed"
                    when: !Config.showNotificationOsd
                    PropertyChanges { target: breathingContainer; scale: 0.0; opacity: 0.0 }
                }
            ]

            transitions: [
                Transition {
                    id: openTransition
                    from: "closed"; to: "open"
                    ParallelAnimation {
                        NumberAnimation { properties: "scale"; duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                        NumberAnimation { properties: "opacity"; duration: 200 }
                    }
                },
                Transition {
                    id: closeTransition
                    from: "open"; to: "closed"
                    ParallelAnimation {
                        NumberAnimation { properties: "scale"; duration: 300; easing.type: Easing.InBack }
                        NumberAnimation { properties: "opacity"; duration: 250 }
                    }
                }
            ]

            // --- OUTER BORDER & GRADIENT FRAME ---
            Rectangle {
                anchors.fill: parent
                radius: Config.cornerRadius
                color: Config.showBorders ? Config.accent : "transparent"

                Rectangle {
                    anchors.fill: parent
                    radius: Config.cornerRadius
                    visible: Config.showBorders && Config.animateGradient

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Config.borderStart }
                        GradientStop { id: animStop; position: 1.0; color: Config.borderEnd }
                    }

                    SequentialAnimation {
                        running: Config.showBorders && Config.animateGradient && breathingContainer.opacity > 0
                        loops: Animation.Infinite

                        ColorAnimation { target: animStop; property: "color"; to: Config.accent; duration: 2000; easing.type: Easing.InOutQuad }
                        ColorAnimation { target: animStop; property: "color"; to: Config.borderEnd; duration: 2000; easing.type: Easing.InOutQuad }
                    }
                }

                // --- MAIN INNER BODY ---
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Config.showBorders ? 3 : 0
                    radius: Math.max(0, Config.cornerRadius - (Config.showBorders ? 3 : 0))
                    color: Config.bgPanel

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismiss()
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        // LEFT APP ICON BADGE
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
                                text: root.appIcon
                                color: root.notifUrgency === Notifs.NotificationUrgency.Critical ? "#ef4444" : Config.accent
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 24
                            }
                        }

                        // CONTENT CARD
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Config.cornerRadius / 2
                            color: Qt.rgba(255, 255, 255, 0.05)

                            ColumnLayout {
                                id: contentColumn
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                anchors.topMargin: 10
                                anchors.bottomMargin: 10
                                spacing: 4

                                // HEADER ROW: App Name + Close Button
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Item {
                                        Layout.fillWidth: true
                                        implicitHeight: senderText.implicitHeight

                                        Text {
                                            id: senderText
                                            anchors.fill: parent
                                            text: root.notifApp.toUpperCase()
                                            color: Config.textMuted
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontBody)
                                            font.bold: true
                                            font.letterSpacing: 0.8
                                            elide: Text.ElideRight
                                        }

                                        // GLOW EFFECT (Matches volumeOSD Slider Glow)
                                        Glow {
                                            anchors.fill: senderText
                                            source: senderText
                                            radius: 8
                                            samples: 16
                                            color: Config.accent
                                            spread: 0.1
                                            visible: breathingContainer.opacity > 0
                                        }
                                    }

                                    // DISMISS BUTTON
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
                                                root.dismiss()
                                            }
                                        }
                                    }
                                }

                                // SUMMARY TITLE
                                Text {
                                    text: root.notifTitle
                                    color: Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontSubhead)
                                    font.bold: true
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                // BODY MESSAGE
                                Text {
                                    visible: root.notifBody !== ""
                                    text: root.notifBody
                                    color: Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontBody)
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}