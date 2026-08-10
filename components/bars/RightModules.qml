import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: rightCard

    property var rootRef
    signal popoutRequested(var item)

    // Inline Comment: Map instantiated child items by icon key for PanelWindow origin tracking
    function getButton(key) {
        for (let i = 0; i < repeater.count; i++) {
            let loader = repeater.itemAt(i)
            if (loader && loader.itemKey === key && loader.item) {
                return loader.item
            }
        }
        return rightCard
    }

    width: rootRef.isHorizontal ? (rightModules.implicitWidth + 4) : 36
    height: rootRef.isHorizontal ? 36 : (rightModules.implicitHeight + 4)
    radius: Config.cornerRadius / 2
    color: Qt.rgba(255, 255, 255, 0.05)
    clip: true

    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    states: [
        State {
            name: "horizontal"
            when: rootRef.isHorizontal
            AnchorChanges {
                target: rightCard
                anchors.right: rightCard.parent.right
                anchors.verticalCenter: rightCard.parent.verticalCenter
                anchors.bottom: undefined
                anchors.horizontalCenter: undefined
            }
        },
        State {
            name: "vertical"
            when: !rootRef.isHorizontal
            AnchorChanges {
                target: rightCard
                anchors.right: undefined
                anchors.verticalCenter: undefined
                anchors.bottom: rightCard.parent.bottom
                anchors.horizontalCenter: rightCard.parent.horizontalCenter
            }
        }
    ]

    anchors.rightMargin: rootRef.isHorizontal ? 10 : 0
    anchors.bottomMargin: !rootRef.isHorizontal ? 10 : 0

    GridLayout {
        id: rightModules
        anchors.centerIn: parent
        columns: rootRef.isHorizontal ? 99 : 1
        rows: rootRef.isHorizontal ? 1 : 99
        columnSpacing: 8
        rowSpacing: 8

        Rectangle {
            implicitWidth: 32; implicitHeight: 32; radius: 10
            color: chevronRightHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: {
                    if (rootRef.isHorizontal) return Config.rightCardCollapsed ? "chevron_left" : "chevron_right"
                    return Config.rightCardCollapsed ? "expand_less" : "expand_more"
                }
                color: Config.textMuted
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
            }

            TapHandler { onTapped: Config.rightCardCollapsed = !Config.rightCardCollapsed }
            HoverHandler { id: chevronRightHover; cursorShape: Qt.PointingHandCursor }
        }

        Repeater {
            id: repeater
            model: Config.rightCardOrder || ["audio", "sys", "batt", "cc", "network", "clipboard", "clock"]

            delegate: Loader {
                readonly property string itemKey: modelData

                // Inline Comment: Directly evaluate module visibility on the Loader to prevent child binding loops
                visible: {
                    if (itemKey === "batt" && typeof shellRoot !== "undefined" && !shellRoot.hasBattery) return false
                    return !Config.rightCardCollapsed || Config.isPinned(itemKey)
                }

                sourceComponent: {
                    switch(itemKey) {
                        case "audio": return audioComp
                        case "sys": return sysComp
                        case "batt": return battComp
                        case "cc": return ccComp
                        case "network": return networkComp
                        case "clipboard": return clipComp
                        case "clock": return clockComp
                        default: return null
                    }
                }
            }
        }
    }

    Component {
        id: audioComp
        Rectangle {
            id: btnAudio
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: (Config.showAudio || audioHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: shellRoot.audioMuted ? "hearing_disabled" : (shellRoot.audioVolume === 0 ? "hearing_disabled" : Config.getIcon("audio"))
                color: Config.showAudio ? Config.accent : (shellRoot.audioMuted ? Config.textMuted : Config.textMain)
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.rightCardCollapsed && Config.isPinned("audio")
            }

            TapHandler { onTapped: { popoutRequested(btnAudio); Config.showAudio = !Config.showAudio; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("audio") }
            HoverHandler { id: audioHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: sysComp
        Rectangle {
            id: btnSys
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: (Config.showSystemMonitor || sysHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: Config.getIcon("sys")
                color: Config.showSystemMonitor ? Config.accent : Config.textMain
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.rightCardCollapsed && Config.isPinned("sys")
            }

            TapHandler { onTapped: { popoutRequested(btnSys); Config.showSystemMonitor = !Config.showSystemMonitor; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("sys") }
            HoverHandler { id: sysHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: battComp
        Rectangle {
            id: btnBatt
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: (Config.showBattery || battHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: {
                    if (shellRoot.battStatus === "Charging") return "battery_android_frame_bolt"
                    if (shellRoot.battCapacity <= 10) return "battery_android_frame_0"
                    if (shellRoot.battCapacity <= 25) return "battery_android_frame_1"
                    if (shellRoot.battCapacity <= 40) return "battery_android_frame_2"
                    if (shellRoot.battCapacity <= 60) return "battery_android_frame_3"
                    if (shellRoot.battCapacity <= 75) return "battery_android_frame_4"
                    if (shellRoot.battCapacity <= 90) return "battery_android_frame_5"
                    if (shellRoot.battCapacity < 100) return "battery_android_frame_6"
                    return "battery_android_frame_full"
                }
                color: Config.showBattery ? Config.accent : (shellRoot.battCapacity <= 15 ? "#ef4444" : Config.textMain)
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.rightCardCollapsed && Config.isPinned("batt")
            }

            TapHandler { onTapped: { popoutRequested(btnBatt); Config.showBattery = !Config.showBattery; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("batt") }
            HoverHandler { id: battHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: ccComp
        Rectangle {
            id: btnCC
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: (Config.showControlCenter || ccHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: Config.getIcon("cc")
                color: Config.showControlCenter ? Config.accent : Config.textMain
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.rightCardCollapsed && Config.isPinned("cc")
            }

            TapHandler { onTapped: { popoutRequested(btnCC); Config.showControlCenter = !Config.showControlCenter; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("cc") }
            HoverHandler { id: ccHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: networkComp
        Rectangle {
            id: btnNetwork
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: (Config.showNetwork || networkHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: shellRoot.vpnActive ? "vpn_key" : Config.getIcon("network")
                color: Config.showNetwork ? Config.accent : Config.textMain
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 18
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.rightCardCollapsed && Config.isPinned("network")
            }

            TapHandler { onTapped: { popoutRequested(btnNetwork); Config.showNetwork = !Config.showNetwork; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("network") }
            HoverHandler { id: networkHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: clipComp
        Rectangle {
            id: btnClipboard
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: (Config.showClipboard || clipHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: Config.getIcon("clipboard")
                color: Config.showClipboard ? Config.accent : Config.textMain
                font.family: "Material Symbols Outlined"; font.weight: Font.Bold; font.pixelSize: 20
            }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.rightCardCollapsed && Config.isPinned("clipboard")
            }

            TapHandler { onTapped: { popoutRequested(btnClipboard); Config.showClipboard = !Config.showClipboard; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("clipboard") }
            HoverHandler { id: clipHover; cursorShape: Qt.PointingHandCursor }
        }
    }

    Component {
        id: clockComp
        Rectangle {
            id: btnClock
            implicitWidth: rootRef.isHorizontal ? dateRow.implicitWidth + 20 : 32
            implicitHeight: rootRef.isHorizontal ? 32 : dateColumn.implicitHeight + 12
            radius: 10
            color: (Config.showCalendar || clockHover.hovered) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 2; anchors.rightMargin: 2
                width: 5; height: 5; radius: 2.5
                color: Config.accent
                visible: !Config.rightCardCollapsed && Config.isPinned("clock")
            }

            // Inline Comment: Live horizontal time layout
            RowLayout {
                id: dateRow
                visible: rootRef.isHorizontal
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: (shellRoot.vertHour || (new Date().getHours() % 12 || 12).toString()) + ":" + (shellRoot.vertMinute || Qt.formatTime(new Date(), "mm"))
                    color: Config.showCalendar ? Config.accent : Config.textMain
                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: Config.size(Config.fontTitle)
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: shellRoot.vertAmPm || Qt.formatTime(new Date(), "ap").toLowerCase()
                    color: Config.accent
                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: Config.size(Config.fontSubhead)
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: (shellRoot.vertMonth || Qt.formatDate(new Date(), "MMM")) + " " + (shellRoot.vertDay || Qt.formatDate(new Date(), "d"))
                    color: Config.showCalendar ? Config.accent : Config.textMuted
                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: Config.size(Config.fontSubhead)
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Inline Comment: Live vertical time layout
            ColumnLayout {
                id: dateColumn
                visible: !rootRef.isHorizontal
                anchors.centerIn: parent
                spacing: 1

                Text {
                    text: shellRoot.vertHour || (new Date().getHours() % 12 || 12).toString()
                    color: Config.showCalendar ? Config.accent : Config.textMain
                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: 15
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: shellRoot.vertMinute || Qt.formatTime(new Date(), "mm")
                    color: Config.showCalendar ? Config.accent : Config.textMain
                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: 15
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: shellRoot.vertAmPm || Qt.formatTime(new Date(), "ap").toLowerCase()
                    color: Config.accent
                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: shellRoot.vertMonth || Qt.formatDate(new Date(), "MMM")
                    color: Config.showCalendar ? Config.accent : Config.textMuted
                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: shellRoot.vertDay || Qt.formatDate(new Date(), "d")
                    color: Config.showCalendar ? Config.accent : Config.textMuted
                    font.family: Config.sysFont; font.weight: Font.Bold; font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            TapHandler { onTapped: { popoutRequested(btnClock); Config.showCalendar = !Config.showCalendar; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Config.togglePin("clock") }
            HoverHandler { id: clockHover; cursorShape: Qt.PointingHandCursor }
        }
    }
}