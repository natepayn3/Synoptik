import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications as Notifs

PanelWindow {
    id: root

    WlrLayershell.namespace: "test-shell-osd"

    property color flyoutBorderColor: Config.accent
    
    // Dynamic content heights
    property real baseContentHeight: contentColumn.implicitHeight
    property real rawChildWidth: 460
    property real rawChildHeight: Math.max(80, baseContentHeight + 48)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // --- UNIFIEDSURFACE ANIMATION LOGIC ---
    readonly property bool isOpen: Config.showNotificationOsd
    readonly property bool isHorizontal: Config.barPosition === "top" || Config.barPosition === "bottom"

    // Capture dimensions on close trigger to lock evaluation state during transition
    property real lastOpenWidth: rawChildWidth
    property real lastOpenHeight: rawChildHeight

    onIsOpenChanged: {
        if (!isOpen) {
            lastOpenWidth = rawChildWidth
            lastOpenHeight = rawChildHeight
        }
    }

    // Fraction-based morphing sizes matching UnifiedSurface
    property real targetWidth: isOpen ? rawChildWidth : (isHorizontal ? (lastOpenWidth * 0.50) : (lastOpenWidth * 1.10))
    property real targetHeight: isOpen ? rawChildHeight : (isHorizontal ? (lastOpenHeight * 1.10) : (lastOpenHeight * 0.50))

    Behavior on targetWidth {
        NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
    }

    Behavior on targetHeight {
        NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
    }

    property real progress: 0.0
    readonly property real animScale: Math.max(0.0, progress)

    // Smooth closing curve and squish math
    readonly property real closeFactor: isOpen ? progress : Math.pow(progress, 1.2)
    readonly property real currentHeight: targetHeight * Math.pow(closeFactor, 1.8)
    readonly property real squishRatio: targetHeight > 0 ? (1.0 - (currentHeight / targetHeight)) : 0.0
    readonly property real currentWidth: isOpen ? (targetWidth * animScale) : (targetWidth * (closeFactor + (0.3 * squishRatio * closeFactor)))

    anchors {
        top: true; bottom: true; left: true; right: true
    }

    color: "transparent"

    visible: Config.showNotificationOsd || progress > 0.0

    mask: Region {
        item: (Config.showNotificationOsd || progress > 0.01) ? breathingContainer : null
    }

    property string notifTitle: ""
    property string notifBody: ""
    property string notifApp: ""
    property int notifUrgency: Notifs.NotificationUrgency.Normal

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

    Item {
        anchors.fill: parent

        // State Machine driving progress
        states: [
            State {
                name: "open"
                when: isOpen
                PropertyChanges { target: root; progress: 1.0 }
            },
            State {
                name: "closed"
                when: !isOpen
                PropertyChanges { target: root; progress: 0.0 }
            }
        ]

        transitions: [
            Transition {
                from: "closed"; to: "open"
                NumberAnimation {
                    target: root
                    property: "progress"
                    duration: 450
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation {
                    target: root
                    property: "progress"
                    duration: 300
                    easing.type: Easing.InBack
                    easing.overshoot: 1.2
                }
            }
        ]

        Item {
            id: breathingContainer
            width: Math.max(1, currentWidth)
            height: Math.max(1, currentHeight)
            opacity: animScale
            
            // Centers growth baseline strictly around the vertical midpoint of the flyout target
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: (Config.barHeight || 30) + (rawChildHeight / 2)

            Rectangle {
                anchors.fill: parent
                radius: Config.cornerRadius
                color: Config.bgPanel
                border.width: Config.showBorders ? 3 : 0
                border.color: shellRoot.currentBorderColor
                clip: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismiss()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

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

                                    Glow {
                                        anchors.fill: senderText
                                        source: senderText
                                        radius: 8
                                        samples: 24
                                        color: Config.accent
                                        spread: 0.1
                                        visible: breathingContainer.opacity > 0
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
                                            root.dismiss()
                                        }
                                    }
                                }
                            }

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