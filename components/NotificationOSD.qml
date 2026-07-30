import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications as Notifs

PanelWindow {
    id: root

    property color flyoutBorderColor: Config.accent
    property real panelWidth: 400
    property real panelHeight: 110
    readonly property real bounceBuffer: 64

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property bool alignRight: false
    property bool alignCenter: true

    anchors {
        top: true
        left: alignCenter || !alignRight
        right: alignCenter || alignRight
    }

    margins {
        top: (Config.barHeight || 30)
        left: 0
        right: 0
    }

    implicitWidth: panelWidth + bounceBuffer
    implicitHeight: panelHeight + bounceBuffer
    color: "transparent"

    visible: Config.showNotificationOsd || closeTransition.running || openTransition.running

    property string notifTitle: ""
    property string notifBody: ""
    property string notifApp: ""
    property int notifUrgency: Notifs.NotificationUrgency.Normal

    Connections {
        target: typeof notifServer !== "undefined" ? notifServer : null

        function onNotification(notif) {
            if (!notif) return;

            // 1. Force notification tracking immediately so shellRoot.activeNotifs increments
            notif.tracked = true;

            // 2. Trigger OSD visual flyout unless DND or Panel is open
            if (notifServer.dnd || (typeof Config.showNotifications !== "undefined" && Config.showNotifications)) return;

            root.notifApp = notif.appName ? notif.appName : "System";
            root.notifTitle = notif.summary ? notif.summary : "";
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
        interval: 3000
        repeat: false
        onTriggered: root.dismiss()
    }

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
                    NumberAnimation { properties: "scale"; duration: 450; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
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

        // --- OUTER GRADIENT BORDER CONTAINER ---
        Rectangle {
            anchors.fill: parent
            radius: Config.cornerRadius
            color: Config.showBorders ? Config.accent : "transparent"

            // Clean horizontal gradient canvas with color animation
            Rectangle {
                anchors.fill: parent
                radius: Config.cornerRadius
                visible: Config.showBorders && Config.animateGradient

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop { position: 0.0; color: Config.borderStart }
                    GradientStop { 
                        id: animStop
                        position: 1.0; 
                        color: Config.borderEnd 
                    }
                }

                // Smooth color-shift pulse
                SequentialAnimation {
                    running: Config.showBorders && Config.animateGradient && breathingContainer.opacity > 0
                    loops: Animation.Infinite

                    ColorAnimation {
                        target: animStop
                        property: "color"
                        to: Config.accent
                        duration: 2000
                        easing.type: Easing.InOutQuad
                    }
                    ColorAnimation {
                        target: animStop
                        property: "color"
                        to: Config.borderEnd
                        duration: 2000
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            // --- INNER CONTENT MASK ---
            Rectangle {
                anchors.fill: parent
                anchors.margins: Config.showBorders ? 3 : 0
                radius: Math.max(0, Config.cornerRadius - (Config.showBorders ? 3 : 0))
                color: Config.bgPanel

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(255, 255, 255, 0.05)
                    radius: parent.radius

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismiss()
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            Item { Layout.fillWidth: true }

                            RowLayout {
                                spacing: 8
                                Layout.alignment: Qt.AlignHCenter

                                Text {
                                    text: root.notifApp.toUpperCase()
                                    color: Config.accent
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontSubhead)
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    visible: root.notifTitle !== ""
                                    text: "•"
                                    color: Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontSubhead)
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    text: root.notifTitle
                                    color: Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontTitle)
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: root.panelWidth - 120
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Text {
                            text: root.notifBody
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                        }
                    }
                }
            }
        }
    }
}