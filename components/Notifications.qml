import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications as Notifs

Item {
    id: notifModuleRoot

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    implicitWidth: mainLayout.implicitWidth + (cardMargin * 2)
    implicitHeight: mainLayout.implicitHeight + (cardMargin * 2)

    // Bind to global shellRoot activeNotifs property safely
    readonly property int activeCount: (typeof shellRoot !== "undefined" && shellRoot.activeNotifs !== undefined) ? shellRoot.activeNotifs : 0

    function clearAll() {
        if (typeof notifServer === "undefined" || !notifServer.trackedNotifications) return;
        let notifs = notifServer.trackedNotifications.values;
        if (!notifs) return;
        
        // Loop backwards to dismiss safely
        for (let i = notifs.length - 1; i >= 0; i--) {
            if (notifs[i]) {
                notifs[i].dismiss();
            }
        }
        if (typeof shellRoot !== "undefined" && shellRoot.updateNotifCount) {
            Qt.callLater(shellRoot.updateNotifCount);
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: notifModuleRoot.cardMargin
        spacing: notifModuleRoot.cardMargin

        // Main Card Container
        Rectangle {
            Layout.fillWidth: true
            implicitWidth: 360
            implicitHeight: cardContent.implicitHeight + (notifModuleRoot.cardMargin * 2)
            color: Qt.rgba(1, 1, 1, 0.05)
            radius: Config.cornerRadius
            clip: true

            // GRAPHIC WATERMARK
            Item {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -15
                anchors.bottomMargin: -20
                implicitWidth: 150
                implicitHeight: 150

                Text {
                    anchors.centerIn: parent
                    text: Config.getIcon("notifications")
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 150
                    color: Config.accent
                    opacity: 0.07
                    rotation: 15
                }
            }

            ColumnLayout {
                id: cardContent
                anchors.fill: parent
                anchors.margins: notifModuleRoot.cardMargin
                spacing: notifModuleRoot.cardMargin

                // Header Section
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Dynamic Notification Icon
                    Text {
                        text: notifModuleRoot.activeCount > 0 ? "notifications_active" : "notifications"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: Config.size(Config.fontTitle)
                        color: notifModuleRoot.activeCount > 0 ? Config.accent : Config.textMain

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        text: "NOTIFICATIONS"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontTitle)
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: clearText.implicitWidth + 12
                        implicitHeight: 24
                        radius: Config.cornerRadius / 2
                        color: clearHover.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        visible: notifModuleRoot.activeCount > 0

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: clearText
                            anchors.centerIn: parent
                            text: "CLEAR ALL"
                            color: clearHover.hovered ? Config.accent : Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        TapHandler {
                            onTapped: notifModuleRoot.clearAll()
                        }

                        HoverHandler {
                            id: clearHover
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }

                // Scrollable Cards List
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: notifModuleRoot.activeCount > 0 
                        ? Math.min(scrollContent.implicitHeight, 320) 
                        : emptyStateContainer.implicitHeight
                    color: "transparent"
                    clip: true

                    Behavior on implicitHeight {
                        NumberAnimation { duration: 150 }
                    }

                    Flickable {
                        anchors.fill: parent
                        contentHeight: scrollContent.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: scrollContent
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: (typeof notifServer !== "undefined" && notifServer.trackedNotifications) 
                                    ? notifServer.trackedNotifications.values 
                                    : []

                                delegate: Rectangle {
                                    id: notifCard
                                    Layout.fillWidth: true
                                    implicitHeight: itemLayout.implicitHeight + (notifModuleRoot.cardMargin * 1.5)
                                    radius: Config.cornerRadius / 2
                                    color: itemHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.15)

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    RowLayout {
                                        id: itemLayout
                                        anchors.fill: parent
                                        anchors.margins: notifModuleRoot.cardMargin
                                        spacing: notifModuleRoot.cardMargin

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Text {
                                                    text: (modelData && modelData.appName) ? modelData.appName.toUpperCase() : "SYSTEM"
                                                    color: Config.accent
                                                    font.family: Config.sysFont
                                                    font.pixelSize: Config.size(Config.fontMicro)
                                                    font.bold: true
                                                }

                                                Text {
                                                    visible: modelData && modelData.summary !== ""
                                                    text: "•"
                                                    color: Config.textMain
                                                    font.family: Config.sysFont
                                                    font.pixelSize: Config.size(Config.fontCaption)
                                                }

                                                Text {
                                                    text: (modelData && modelData.summary) ? modelData.summary : ""
                                                    color: Config.textMain
                                                    font.family: Config.sysFont
                                                    font.pixelSize: Config.size(Config.fontCaption)
                                                    font.bold: true
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Text {
                                                text: (modelData && modelData.body) ? modelData.body : ""
                                                color: Config.textMuted
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontCaption)
                                                Layout.fillWidth: true
                                                wrapMode: Text.Wrap
                                            }
                                        }

                                        // Close Button Box
                                        Rectangle {
                                            implicitWidth: 24
                                            implicitHeight: 24
                                            radius: Config.cornerRadius / 2
                                            color: closeHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                            opacity: itemHover.hovered ? 1.0 : 0.0
                                            Layout.alignment: Qt.AlignTop | Qt.AlignRight

                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on opacity { NumberAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "close"
                                                color: closeHover.hovered ? Config.accent : Config.textMuted
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 16

                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }

                                            TapHandler {
                                                onTapped: {
                                                    if (modelData) {
                                                        modelData.dismiss();
                                                    }
                                                }
                                            }

                                            HoverHandler {
                                                id: closeHover
                                                cursorShape: Qt.PointingHandCursor
                                            }
                                        }
                                    }

                                    HoverHandler {
                                        id: itemHover
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }
                            }

                            // Empty State
                            ColumnLayout {
                                id: emptyStateContainer
                                Layout.fillWidth: true
                                spacing: 6
                                visible: notifModuleRoot.activeCount === 0
                                Layout.alignment: Qt.AlignHCenter

                                Text {
                                    Layout.fillWidth: true
                                    text: "inbox"
                                    color: Config.textMuted
                                    opacity: 0.5
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 28
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "No active notifications"
                                    color: Config.textMuted
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}