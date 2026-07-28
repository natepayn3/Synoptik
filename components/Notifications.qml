import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications as Notifs

MorphingFlyout {
    id: notifFlyoutRoot

    isOpen: Config.showNotifications
    alignRight: true
    panelWidth: 360
    panelHeight: mainLayout.implicitHeight + 40

    // Bind to global notifServer from shell.qml
    readonly property int activeCount: (typeof notifServer !== "undefined" && notifServer.trackedNotifications) 
        ? notifServer.trackedNotifications.values.length 
        : 0

    function clearAll() {
        if (typeof notifServer === "undefined") return;
        let notifs = notifServer.trackedNotifications.values;
        for (let i = notifs.length - 1; i >= 0; i--) {
            if (notifs[i]) {
                notifs[i].dismiss();
            }
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 12

        // Main Card Container
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: cardContent.implicitHeight + 24
            color: Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius

            ColumnLayout {
                id: cardContent
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                // Header Section
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

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
                        color: clearHover.hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                        visible: notifFlyoutRoot.activeCount > 0

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
                            onTapped: notifFlyoutRoot.clearAll()
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
                    implicitHeight: notifFlyoutRoot.activeCount > 0 
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
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 8

                            Repeater {
                                model: (typeof notifServer !== "undefined" && notifServer.trackedNotifications) 
                                    ? notifServer.trackedNotifications.values 
                                    : []

                                delegate: Rectangle {
                                    id: notifCard
                                    Layout.fillWidth: true
                                    implicitHeight: itemLayout.implicitHeight + 16
                                    radius: Config.cornerRadius / 2
                                    color: itemHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.15)

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    RowLayout {
                                        id: itemLayout
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 10

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
                                            color: closeHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
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

                                    TapHandler {
                                        onTapped: {
                                            if (modelData) {
                                                modelData.dismiss();
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
                                visible: notifFlyoutRoot.activeCount === 0
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