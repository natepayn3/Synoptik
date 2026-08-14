import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
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
        if (key === "cc" || key === "controlCenter") {
            let activeLayout = centerContentLayout.item
            if (activeLayout && activeLayout.ccBtn) {
                return activeLayout.ccBtn
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
            readonly property var ccBtn: btnCCHoriz

            WorkspaceIndicators {
                isVertical: false
                Layout.alignment: Qt.AlignVCenter
            }

            // Control Center Button
            Rectangle {
                id: btnCCHoriz
                implicitWidth: 32
                implicitHeight: 32
                radius: 10
                color: Config.showControlCenter ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                Layout.alignment: Qt.AlignVCenter

                Behavior on color { ColorAnimation { duration: 150 } }

                Item {
                    anchors.centerIn: parent
                    implicitWidth: ccIconHorizText.implicitWidth
                    implicitHeight: ccIconHorizText.implicitHeight
                    scale: ccHorizHover.hovered ? 1.25 : 1.0

                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                    Glow {
                        anchors.fill: ccIconHorizText
                        source: ccIconHorizText
                        radius: ccHorizHover.hovered ? 8 : 0
                        samples: 16
                        color: Config.accent
                        spread: 0.2
                        transparentBorder: true
                        visible: ccHorizHover.hovered

                        Behavior on radius { NumberAnimation { duration: 180 } }
                    }

                    Text {
                        id: ccIconHorizText
                        anchors.centerIn: parent
                        text: Config.getIcon("cc")
                        color: (Config.showControlCenter || ccHorizHover.hovered) ? Config.accent : Config.textMain
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                TapHandler {
                    onTapped: {
                        popoutRequested(btnCCHoriz)
                        Config.showControlCenter = !Config.showControlCenter
                    }
                }
                HoverHandler { id: ccHorizHover; cursorShape: Qt.PointingHandCursor }
            }

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
            readonly property var ccBtn: btnCCVert

            WorkspaceIndicators {
                isVertical: true
                Layout.alignment: Qt.AlignHCenter
            }

            // Control Center Button
            Rectangle {
                id: btnCCVert
                implicitWidth: 32
                implicitHeight: 32
                radius: 10
                color: Config.showControlCenter ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                Layout.alignment: Qt.AlignHCenter

                Behavior on color { ColorAnimation { duration: 150 } }

                Item {
                    anchors.centerIn: parent
                    implicitWidth: ccIconVertText.implicitWidth
                    implicitHeight: ccIconVertText.implicitHeight
                    scale: ccVertHover.hovered ? 1.25 : 1.0

                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                    Glow {
                        anchors.fill: ccIconVertText
                        source: ccIconVertText
                        radius: ccVertHover.hovered ? 8 : 0
                        samples: 16
                        color: Config.accent
                        spread: 0.2
                        transparentBorder: true
                        visible: ccVertHover.hovered

                        Behavior on radius { NumberAnimation { duration: 180 } }
                    }

                    Text {
                        id: ccIconVertText
                        anchors.centerIn: parent
                        text: Config.getIcon("cc")
                        color: (Config.showControlCenter || ccVertHover.hovered) ? Config.accent : Config.textMain
                        font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                TapHandler {
                    onTapped: {
                        popoutRequested(btnCCVert)
                        Config.showControlCenter = !Config.showControlCenter
                    }
                }
                HoverHandler { id: ccVertHover; cursorShape: Qt.PointingHandCursor }
            }

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