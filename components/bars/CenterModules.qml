import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: centerGroupContainer
    
    property var rootRef
    property var leftCardRef
    property var rightCardRef
    property var barContentRef

    signal popoutRequested(var item)

    // Inline Comment: Origin lookup for PanelWindow popout placement
    function getButton(key) {
        if (key === "apps" || key === "launcher" || key === "view_apps") {
            let activeLayout = centerContentLayout.item
            if (activeLayout && activeLayout.viewAppsButton) {
                return activeLayout.viewAppsButton
            }
            return null
        }
        return centerGroupContainer
    }

    anchors.centerIn: parent
    anchors.horizontalCenterOffset: (rootRef && rootRef.isHorizontal && rootRef.isScreenFrame) ? (rootRef.barPosition === "left" ? (rootRef.framePadding / 2) : (rootRef.barPosition === "right" ? -(rootRef.framePadding / 2) : 0)) : 0
    anchors.verticalCenterOffset: (rootRef && !rootRef.isHorizontal && rootRef.isScreenFrame) ? (rootRef.barPosition === "top" ? (rootRef.framePadding / 2) : (rootRef.barPosition === "bottom" ? -(rootRef.framePadding / 2) : 0)) : 0

    readonly property real leftW: leftCardRef ? leftCardRef.width : 0
    readonly property real rightW: rightCardRef ? rightCardRef.width : 0
    readonly property real barW: barContentRef ? barContentRef.width : 1920

    readonly property real leftH: leftCardRef ? leftCardRef.height : 0
    readonly property real rightH: rightCardRef ? rightCardRef.height : 0
    readonly property real barH: barContentRef ? barContentRef.height : 54

    readonly property real availableW: Math.max(32, barW - (2 * Math.max(leftW, rightW)) - 48)
    readonly property real availableH: Math.max(32, barH - (2 * Math.max(leftH, rightH)) - 48)

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
            id: horizLayout
            spacing: 8
            anchors.fill: parent

            readonly property var viewAppsButton: taskbarHoriz.viewAppsBtn

            WorkspaceIndicators {
                isVertical: false
                Layout.alignment: Qt.AlignVCenter
            }

            // Inline Comment: Direct instantiation guarantees instant rendering without 350ms blank state
            Taskbar {
                id: taskbarHoriz
                isVertical: false
                activeScreenName: (rootRef && rootRef.screen) ? rootRef.screen.name : ""
                Layout.alignment: Qt.AlignVCenter
                onPopoutRequested: item => centerGroupContainer.popoutRequested(item)
            }
        }
    }

    Component {
        id: vertCenterComp
        ColumnLayout {
            id: vertLayout
            spacing: 8
            anchors.fill: parent

            readonly property var viewAppsButton: taskbarVert.viewAppsBtn

            WorkspaceIndicators {
                isVertical: true
                Layout.alignment: Qt.AlignHCenter
            }

            // Inline Comment: Direct instantiation guarantees instant rendering without 350ms blank state
            Taskbar {
                id: taskbarVert
                isVertical: true
                activeScreenName: (rootRef && rootRef.screen) ? rootRef.screen.name : ""
                Layout.alignment: Qt.AlignHCenter
                onPopoutRequested: item => centerGroupContainer.popoutRequested(item)
            }
        }
    }
}