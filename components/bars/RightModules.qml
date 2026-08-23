import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import ".."

Rectangle {
    id: rightCard

    property var rootRef
    signal popoutRequested(var item)

    function getButton(name) {
        let layout = centerContentLayout.item
        if (!layout) return rightCard

        switch (name) {
            case "cc":
            case "controlCenter":
                return layout.ccBtn || rightCard
            case "clock":
            case "calendar":
                return layout.clockBtn || rightCard
            case "overview":
            case "workspacePreview":
                return layout.overviewBtn || rightCard
            default:
                return rightCard
        }
    }

    readonly property real contentWidth: centerContentLayout.item ? centerContentLayout.item.implicitWidth : 0
    readonly property real contentHeight: centerContentLayout.item ? centerContentLayout.item.implicitHeight : 0

    width: (rootRef && rootRef.isHorizontal) 
        ? Math.max(36, contentWidth + 24)
        : Math.max(36, contentWidth + 4)

    height: (rootRef && rootRef.isHorizontal) 
        ? 36
        : Math.min(contentHeight + 16, (rootRef.height || 1080) - 100)

    clip: true
    radius: Config.cornerRadius / 2
    color: Qt.rgba(255, 255, 255, 0.05)
    border.width: 1
    border.color: Qt.rgba(255, 255, 255, 0.1)

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
                anchors.top: undefined
                anchors.horizontalCenter: undefined
            }
        },
        State {
            name: "vertical"
            when: rootRef && !rootRef.isHorizontal
            AnchorChanges {
                target: rightCard
                anchors.right: undefined
                anchors.verticalCenter: undefined
                anchors.bottom: rightCard.parent.bottom
                anchors.horizontalCenter: rightCard.parent.horizontalCenter
            }
        }
    ]

    anchors.rightMargin: (rootRef && rootRef.isHorizontal) ? 30 : 0
    anchors.bottomMargin: (rootRef && !rootRef.isHorizontal) ? 30 : 0

    Loader {
        id: centerContentLayout
        anchors.fill: parent
        anchors.leftMargin: (rootRef && rootRef.isHorizontal) ? 4 : 2
        anchors.rightMargin: (rootRef && rootRef.isHorizontal) ? 4 : 2
        anchors.topMargin: (rootRef && !rootRef.isHorizontal) ? 4 : 2
        anchors.bottomMargin: (rootRef && !rootRef.isHorizontal) ? 4 : 2

        sourceComponent: (rootRef && rootRef.isHorizontal) ? horizRightComp : vertRightComp
    }

    // --- HORIZONTAL RIGHT MODULES ---
    Component {
        id: horizRightComp
        RowLayout {
            id: horizLayout
            spacing: 8

            readonly property var ccBtn: btnCCHoriz
            readonly property var clockBtn: btnClockHoriz
            readonly property var overviewBtn: wsHoriz.overviewButton

            WorkspaceIndicators {
                id: wsHoriz
                isVertical: false
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 6
                onPopoutRequested: item => rightCard.popoutRequested(item)
            }

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
                        if (rootRef && rootRef.stopPeek) rootRef.stopPeek()
                        rightCard.popoutRequested(btnCCHoriz)
                        Config.showControlCenter = !Config.showControlCenter
                    }
                }
                HoverHandler { 
                    id: ccHorizHover
                    cursorShape: Qt.PointingHandCursor 
                    onHoveredChanged: {
                        if (hovered && rootRef && rootRef.startPeek) rootRef.startPeek(btnCCHoriz)
                        else if (!hovered && rootRef && rootRef.stopPeek) rootRef.stopPeek()
                    }
                }
            }

            Rectangle {
                id: btnClockHoriz
                implicitWidth: dateRow.implicitWidth + 20
                implicitHeight: 32
                radius: 10
                color: Config.showCalendar ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                Layout.alignment: Qt.AlignVCenter
                clip: true

                Behavior on color { ColorAnimation { duration: 150 } }

                property real currentSecond: new Date().getSeconds() + (new Date().getMilliseconds() / 1000)
                Timer {
                    interval: 50
                    running: true
                    repeat: true
                    onTriggered: btnClockHoriz.currentSecond = new Date().getSeconds() + (new Date().getMilliseconds() / 1000)
                }

                // Masked Health Bar Container (Matches exact button radius)
                Item {
                    id: horizFillMaskSource
                    anchors.fill: parent
                    z: 0

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * (btnClockHoriz.currentSecond / 60)
                        color: Config.accent
                        opacity: clockHorizHover.hovered ? 0.22 : 0.12

                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        // Leading edge highlight
                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 1
                            color: Config.accent
                            opacity: 0.6
                            visible: parent.width > 2
                        }
                    }

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: horizFillMaskSource.width
                            height: horizFillMaskSource.height
                            radius: btnClockHoriz.radius
                        }
                    }
                }

                Item {
                    anchors.centerIn: parent
                    implicitWidth: dateRow.implicitWidth
                    implicitHeight: dateRow.implicitHeight
                    scale: clockHorizHover.hovered ? 1.05 : 1.0
                    z: 1

                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                    RowLayout {
                        id: dateRow
                        anchors.centerIn: parent
                        spacing: 8

                        // Cascading Depth Time
                        Row {
                            id: overlappingTimeRow
                            Layout.alignment: Qt.AlignVCenter
                            spacing: -2.5

                            readonly property string timeString: (shellRoot.vertHour || (new Date().getHours() % 12 || 12).toString()) + ":" + (shellRoot.vertMinute || Qt.formatTime(new Date(), "mm"))

                            Repeater {
                                model: overlappingTimeRow.timeString.length

                                Text {
                                    text: overlappingTimeRow.timeString[index]
                                    color: (Config.showCalendar || clockHorizHover.hovered) ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.weight: Font.Bold
                                    font.pixelSize: Math.round(Config.size(Config.fontTitle))
                                    renderType: Config.textRenderType
                                    z: overlappingTimeRow.timeString.length - index

                                    opacity: Math.max(0.85, 1.0 - (index * 0.035))
                                    scale: 1.0 - (index * 0.008)
                                    transformOrigin: Item.BottomLeft

                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        horizontalOffset: 1
                                        verticalOffset: 0
                                        radius: 2
                                        samples: 8
                                        color: Qt.rgba(0, 0, 0, 0.35)
                                    }
                                }
                            }
                        }

                        // Micro Accent Capsule
                        Rectangle {
                            implicitWidth: apText.implicitWidth + 5
                            implicitHeight: apText.implicitHeight + 1
                            radius: 3
                            color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.35)
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: -2

                            Text {
                                id: apText
                                anchors.centerIn: parent
                                text: (shellRoot.vertAmPm || Qt.formatTime(new Date(), "ap")).toUpperCase()
                                color: Config.accent
                                font.family: Config.sysFont
                                font.weight: Font.Bold
                                font.pixelSize: Math.max(8, Math.round(Config.size(Config.fontSubhead) - 3))
                                renderType: Config.textRenderType
                            }
                        }

                        // Divider
                        Rectangle {
                            implicitWidth: 1.5
                            implicitHeight: 12
                            radius: 1
                            color: Qt.rgba(255, 255, 255, 0.15)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Cascading Depth Date
                        Row {
                            id: overlappingDateRow
                            Layout.alignment: Qt.AlignVCenter
                            spacing: -2.5

                            readonly property string dateString: (shellRoot.vertMonth || Qt.formatDate(new Date(), "MMM")) + " " + (shellRoot.vertDay || Qt.formatDate(new Date(), "d"))

                            Repeater {
                                model: overlappingDateRow.dateString.length

                                Text {
                                    text: overlappingDateRow.dateString[index]
                                    color: (Config.showCalendar || clockHorizHover.hovered) ? Config.accent : Config.textMuted
                                    font.family: Config.sysFont
                                    font.weight: Font.Bold
                                    font.pixelSize: Math.round(Config.size(Config.fontSubhead))
                                    renderType: Config.textRenderType
                                    z: overlappingDateRow.dateString.length - index

                                    opacity: Math.max(0.85, 1.0 - (index * 0.03))
                                    scale: 1.0 - (index * 0.008)
                                    transformOrigin: Item.BottomLeft

                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        horizontalOffset: 1
                                        verticalOffset: 0
                                        radius: 2
                                        samples: 8
                                        color: Qt.rgba(0, 0, 0, 0.3)
                                    }
                                }
                            }
                        }
                    }
                }

                TapHandler { 
                    onTapped: { 
                        if (rootRef && rootRef.stopPeek) rootRef.stopPeek()
                        rightCard.popoutRequested(btnClockHoriz)
                        Config.showCalendar = !Config.showCalendar 
                    } 
                }
                HoverHandler { 
                    id: clockHorizHover
                    cursorShape: Qt.PointingHandCursor 
                    onHoveredChanged: {
                        if (hovered && rootRef && rootRef.startPeek) rootRef.startPeek(btnClockHoriz)
                        else if (!hovered && rootRef && rootRef.stopPeek) rootRef.stopPeek()
                    }
                }
            }
        }
    }

    // --- VERTICAL RIGHT MODULES ---
    Component {
        id: vertRightComp
        ColumnLayout {
            id: vertLayout
            spacing: 6
            anchors.fill: parent

            readonly property var ccBtn: btnCCVert
            readonly property var clockBtn: btnClockVert
            readonly property var overviewBtn: wsVert.overviewButton

            WorkspaceIndicators {
                id: wsVert
                isVertical: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                onPopoutRequested: item => rightCard.popoutRequested(item)
            }

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
                        if (rootRef && rootRef.stopPeek) rootRef.stopPeek()
                        rightCard.popoutRequested(btnCCVert)
                        Config.showControlCenter = !Config.showControlCenter
                    }
                }
                HoverHandler { 
                    id: ccVertHover
                    cursorShape: Qt.PointingHandCursor 
                    onHoveredChanged: {
                        if (hovered && rootRef && rootRef.startPeek) rootRef.startPeek(btnCCVert)
                        else if (!hovered && rootRef && rootRef.stopPeek) rootRef.stopPeek()
                    }
                }
            }

            Rectangle {
                id: btnClockVert
                implicitWidth: 32
                implicitHeight: dateColumn.implicitHeight + 10
                radius: 10
                color: Config.showCalendar ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                Layout.alignment: Qt.AlignHCenter
                clip: true

                Behavior on color { ColorAnimation { duration: 150 } }

                property real currentSecond: new Date().getSeconds() + (new Date().getMilliseconds() / 1000)
                Timer {
                    interval: 50
                    running: true
                    repeat: true
                    onTriggered: btnClockVert.currentSecond = new Date().getSeconds() + (new Date().getMilliseconds() / 1000)
                }

                // Masked Health Bar Container (Matches exact vertical button radius)
                Item {
                    id: vertFillMaskSource
                    anchors.fill: parent
                    z: 0

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * (btnClockVert.currentSecond / 60)
                        color: Config.accent
                        opacity: clockVertHover.hovered ? 0.22 : 0.12

                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        // Leading edge highlight
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 1
                            color: Config.accent
                            opacity: 0.6
                            visible: parent.height > 2
                        }
                    }

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: vertFillMaskSource.width
                            height: vertFillMaskSource.height
                            radius: btnClockVert.radius
                        }
                    }
                }

                Item {
                    anchors.centerIn: parent
                    implicitWidth: dateColumn.implicitWidth
                    implicitHeight: dateColumn.implicitHeight
                    scale: clockVertHover.hovered ? 1.05 : 1.0
                    z: 1

                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                    ColumnLayout {
                        id: dateColumn
                        anchors.centerIn: parent
                        spacing: 2

                        // 1. Cascading Hour Row
                        Row {
                            id: vertHourRow
                            Layout.alignment: Qt.AlignHCenter
                            spacing: -2
                            z: 4

                            readonly property string hourStr: shellRoot.vertHour || (new Date().getHours() % 12 || 12).toString()

                            Repeater {
                                model: vertHourRow.hourStr.length
                                Text {
                                    text: vertHourRow.hourStr[index]
                                    color: (Config.showCalendar || clockVertHover.hovered) ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.weight: Font.Bold
                                    font.pixelSize: 15
                                    renderType: Config.textRenderType
                                    z: vertHourRow.hourStr.length - index
                                    opacity: Math.max(0.85, 1.0 - (index * 0.035))

                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        horizontalOffset: 1
                                        verticalOffset: 1
                                        radius: 2
                                        samples: 8
                                        color: Qt.rgba(0, 0, 0, 0.35)
                                    }
                                }
                            }
                        }

                        // 2. Cascading Minute Row
                        Row {
                            id: vertMinRow
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: -3
                            spacing: -2
                            z: 3

                            readonly property string minStr: shellRoot.vertMinute || Qt.formatTime(new Date(), "mm")

                            Repeater {
                                model: vertMinRow.minStr.length
                                Text {
                                    text: vertMinRow.minStr[index]
                                    color: (Config.showCalendar || clockVertHover.hovered) ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.weight: Font.Bold
                                    font.pixelSize: 15
                                    renderType: Config.textRenderType
                                    z: vertMinRow.minStr.length - index
                                    opacity: Math.max(0.82, 0.95 - (index * 0.035))

                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        horizontalOffset: 1
                                        verticalOffset: 1
                                        radius: 2
                                        samples: 8
                                        color: Qt.rgba(0, 0, 0, 0.35)
                                    }
                                }
                            }
                        }

                        // 3. Compact AM/PM Accent Badge
                        Rectangle {
                            implicitWidth: apTextVert.implicitWidth + 4
                            implicitHeight: apTextVert.implicitHeight + 1
                            radius: 3
                            color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.35)
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 1
                            z: 2

                            Text {
                                id: apTextVert
                                anchors.centerIn: parent
                                text: (shellRoot.vertAmPm || Qt.formatTime(new Date(), "ap")).toUpperCase()
                                color: Config.accent
                                font.family: Config.sysFont
                                font.weight: Font.Bold
                                font.pixelSize: 9
                                renderType: Config.textRenderType
                            }
                        }

                        // Divider Line
                        Rectangle {
                            implicitWidth: 10
                            implicitHeight: 1
                            radius: 0.5
                            color: Qt.rgba(255, 255, 255, 0.15)
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 1
                            Layout.bottomMargin: 1
                        }

                        // 4. Cascading Month Row
                        Row {
                            id: vertMonthRow
                            Layout.alignment: Qt.AlignHCenter
                            spacing: -2
                            z: 1

                            readonly property string monthStr: shellRoot.vertMonth || Qt.formatDate(new Date(), "MMM")

                            Repeater {
                                model: vertMonthRow.monthStr.length
                                Text {
                                    text: vertMonthRow.monthStr[index]
                                    color: (Config.showCalendar || clockVertHover.hovered) ? Config.accent : Config.textMuted
                                    font.family: Config.sysFont
                                    font.weight: Font.Bold
                                    font.pixelSize: 11
                                    renderType: Config.textRenderType
                                    z: vertMonthRow.monthStr.length - index
                                    opacity: Math.max(0.85, 1.0 - (index * 0.03))
                                }
                            }
                        }

                        // 5. Cascading Day Row
                        Row {
                            id: vertDayRow
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: -2
                            spacing: -2
                            z: 0

                            readonly property string dayStr: shellRoot.vertDay || Qt.formatDate(new Date(), "d")

                            Repeater {
                                model: vertDayRow.dayStr.length
                                Text {
                                    text: vertDayRow.dayStr[index]
                                    color: (Config.showCalendar || clockVertHover.hovered) ? Config.accent : Config.textMuted
                                    font.family: Config.sysFont
                                    font.weight: Font.Bold
                                    font.pixelSize: 11
                                    renderType: Config.textRenderType
                                    z: vertDayRow.dayStr.length - index
                                    opacity: Math.max(0.85, 1.0 - (index * 0.03))
                                }
                            }
                        }
                    }
                }

                TapHandler { 
                    onTapped: { 
                        if (rootRef && rootRef.stopPeek) rootRef.stopPeek()
                        rightCard.popoutRequested(btnClockVert)
                        Config.showCalendar = !Config.showCalendar 
                    } 
                }

                HoverHandler { 
                    id: clockVertHover
                    cursorShape: Qt.PointingHandCursor 
                    onHoveredChanged: {
                        if (hovered && rootRef && rootRef.startPeek) rootRef.startPeek(btnClockVert)
                        else if (!hovered && rootRef && rootRef.stopPeek) rootRef.stopPeek()
                    }
                }
            }
        }
    }
}