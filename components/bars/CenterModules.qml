import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: centerGroupContainer
    
    property var rootRef
    property var leftCardRef
    property var rightCardRef
    property var barContentRef

    anchors.centerIn: parent
    anchors.horizontalCenterOffset: (rootRef && rootRef.isHorizontal && rootRef.isScreenFrame) ? (rootRef.barPosition === "left" ? (rootRef.framePadding / 2) : (rootRef.barPosition === "right" ? -(rootRef.framePadding / 2) : 0)) : 0
    anchors.verticalCenterOffset: (rootRef && !rootRef.isHorizontal && rootRef.isScreenFrame) ? (rootRef.barPosition === "top" ? (rootRef.framePadding / 2) : (rootRef.barPosition === "bottom" ? -(rootRef.framePadding / 2) : 0)) : 0

    // Inline Comment: Safe null-checks prevent initialization property lookup errors
    readonly property real leftW: leftCardRef ? leftCardRef.width : 0
    readonly property real rightW: rightCardRef ? rightCardRef.width : 0
    readonly property real barW: barContentRef ? barContentRef.width : 1920

    readonly property real leftH: leftCardRef ? leftCardRef.height : 0
    readonly property real rightH: rightCardRef ? rightCardRef.height : 0
    readonly property real barH: barContentRef ? barContentRef.height : 54

    readonly property real availableW: Math.max(32, barW - leftW - rightW - 48)
    readonly property real availableH: Math.max(32, barH - leftH - rightH - 48)

    width: (rootRef && rootRef.isHorizontal) 
        ? Math.min(centerContentLayout.implicitWidth + 16, availableW) 
        : 36

    height: (rootRef && rootRef.isHorizontal) 
        ? 36
        : Math.min(centerContentLayout.implicitHeight + 16, availableH)
    
    clip: true
    radius: Config.cornerRadius / 2
    color: Qt.rgba(255, 255, 255, 0.05)

    Loader {
        id: centerContentLayout
        anchors.fill: parent
        anchors.leftMargin: (rootRef && rootRef.isHorizontal) ? 8 : 2
        anchors.rightMargin: (rootRef && rootRef.isHorizontal) ? 8 : 2
        anchors.topMargin: (rootRef && !rootRef.isHorizontal) ? 8 : 2
        anchors.bottomMargin: (rootRef && !rootRef.isHorizontal) ? 8 : 2

        sourceComponent: (rootRef && rootRef.isHorizontal) ? horizCenterComp : vertCenterComp
    }

    Component {
        id: horizCenterComp
        RowLayout {
            spacing: 8
            anchors.fill: parent

            WorkspaceIndicators {
                isVertical: false
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                
                implicitWidth: horizTaskbarLoader.item ? horizTaskbarLoader.item.implicitWidth : 32

                Timer {
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
                        activeScreenName: (rootRef && rootRef.screen) ? rootRef.screen.name : ""
                    }
                }
            }
        }
    }

    Component {
        id: vertCenterComp
        ColumnLayout {
            spacing: 8
            anchors.fill: parent

            WorkspaceIndicators {
                isVertical: true
                Layout.alignment: Qt.AlignHCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter

                implicitHeight: vertTaskbarLoader.item ? vertTaskbarLoader.item.implicitHeight : 32

                Timer {
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
                        activeScreenName: (rootRef && rootRef.screen) ? rootRef.screen.name : ""
                    }
                }
            }
        }
    }
}