import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls
import ".."

Item {
    id: cardRoot
    
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.alignment: Qt.AlignTop

    // Lock structural footprint to 64px so lower cards stay static in ControlCenter
    implicitHeight: 64
    Layout.preferredHeight: 64
    z: panelExpanded ? 1000 : 1

    property Item controlCenterPanel: null
    property bool panelExpanded: false

    readonly property bool hasHypridle: Config.caffeineHasHypridle
    readonly property int caffeineState: Config.caffeineState
    readonly property string remainingTimeString: Config.caffeineRemainingTimeString
    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    property int typedMinutes: 15

    onVisibleChanged: {
        if (!visible) panelExpanded = false
    }

    // Reactive collapsed position calculation spanning parent hierarchy up to controlCenterPanel (root)
    readonly property real collapsedX: {
        let p0 = cardRoot
        let p1 = p0 ? p0.parent : null
        let p2 = p1 ? p1.parent : null
        let p3 = p2 ? p2.parent : null
        let p4 = p3 ? p3.parent : null
        
        let x0 = p0 ? p0.x : 0
        let x1 = p1 ? p1.x : 0
        let x2 = p2 ? p2.x : 0
        let x3 = p3 ? p3.x : 0
        let x4 = p4 ? p4.x : 0
        
        return x0 + x1 + x2 + x3 + x4
    }

    readonly property real collapsedY: {
        let p0 = cardRoot
        let p1 = p0 ? p0.parent : null
        let p2 = p1 ? p1.parent : null
        let p3 = p2 ? p2.parent : null
        let p4 = p3 ? p3.parent : null
        
        let y0 = p0 ? p0.y : 0
        let y1 = p1 ? p1.y : 0
        let y2 = p2 ? p2.y : 0
        let y3 = p3 ? p3.y : 0
        let y4 = p4 ? p4.y : 0
        
        return y0 + y1 + y2 + y3 + y4
    }

    // Floating overlay container that expands to fill the ControlCenter panel area
    Rectangle {
        id: visualBackground
        parent: controlCenterPanel ? controlCenterPanel : cardRoot.parent.parent.parent
        z: cardRoot.panelExpanded ? 1000 : 100
        clip: true

        x: cardRoot.panelExpanded ? cardRoot.cardMargin : cardRoot.collapsedX
        y: cardRoot.panelExpanded ? cardRoot.cardMargin : cardRoot.collapsedY
        width: cardRoot.panelExpanded ? (controlCenterPanel ? (controlCenterPanel.width - (cardRoot.cardMargin * 2)) : 400) : cardRoot.width
        height: cardRoot.panelExpanded ? (controlCenterPanel ? (controlCenterPanel.height - (cardRoot.cardMargin * 2)) : 500) : 64

        radius: Config.cornerRadius

        color: cardRoot.panelExpanded
            ? Qt.rgba(Config.bgBase.r, Config.bgBase.g, Config.bgBase.b, 1.0)
            : ((cardHover.hovered && cardRoot.hasHypridle) ? Qt.rgba(Config.bgBase.r, Config.bgBase.g, Config.bgBase.b, 0.85) : Qt.rgba(0, 0, 0, 0.25))

        opacity: cardRoot.hasHypridle ? 1.0 : 0.45
        enabled: cardRoot.hasHypridle

        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on color { ColorAnimation { duration: 150 } }

        HoverHandler {
            id: cardHover
            enabled: !cardRoot.panelExpanded
        }

        // Shield overlay: Eat all click and mouse events when panel is expanded so they never leak to items underneath
        MouseArea {
            anchors.fill: parent
            enabled: cardRoot.panelExpanded
            preventStealing: true
            onClicked: {}
        }

        // --- 1. COLLAPSED CARD HEADER VIEW ---
        Item {
            id: collapsedView
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 64
            visible: opacity > 0
            opacity: cardRoot.panelExpanded ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Item {
                anchors.fill: parent
                anchors.margins: 10

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    // Caffeine Toggle Button (Clicking ONLY icon cycles state)
                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: Config.cornerRadius / 2
                        color: {
                            if (!cardRoot.hasHypridle || cardRoot.caffeineState === 0) {
                                return iconHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                            } else if (cardRoot.caffeineState === 1) {
                                return iconHover.hovered ? Qt.lighter(Config.accent, 1.1) : Config.accent
                            } else {
                                return iconHover.hovered ? Qt.lighter(Config.accent, 1.2) : Qt.tint(Config.accent, Qt.rgba(1, 1, 1, 0.4))
                            }
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: cardRoot.caffeineState === 2 ? "schedule" : "coffee"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            color: (!cardRoot.hasHypridle || cardRoot.caffeineState === 0) ? Config.textMuted : Config.bgBase
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: cardRoot.hasHypridle ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (cardRoot.hasHypridle) {
                                    if (cardRoot.caffeineState !== 0) {
                                        Config.startCaffeineTimer(0)
                                    } else {
                                        Config.setIndefiniteCaffeine()
                                    }
                                }
                            }
                        }
                        HoverHandler { id: iconHover }
                    }

                    // Label & Subtitle
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        clip: true

                        Text {
                            text: "Caffeine"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: true
                            color: Config.textMain
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: {
                                if (!cardRoot.hasHypridle) return "Unavailable"
                                switch (cardRoot.caffeineState) {
                                    case 1: return "Awake"
                                    case 2: return cardRoot.remainingTimeString
                                    default: return "Off"
                                }
                            }
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: cardRoot.caffeineState !== 0
                            color: cardRoot.caffeineState !== 0 ? Config.accent : Config.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Chevron visual indicator for panel expansion
                    Text {
                        text: "chevron_right"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 20
                        color: cardHover.hovered ? Config.textMain : Config.textMuted
                        opacity: cardRoot.hasHypridle ? 0.7 : 0.2
                    }
                }

                // Click handler for card expansion
                MouseArea {
                    anchors.fill: parent
                    anchors.leftMargin: 52
                    cursorShape: cardRoot.hasHypridle ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (cardRoot.hasHypridle) cardRoot.panelExpanded = true
                    }
                }
            }
        }

        // --- 2. EXPANDED FULL CONTROL CENTER PANEL VIEW ---
        ColumnLayout {
            id: expandedView
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            visible: opacity > 0
            opacity: cardRoot.panelExpanded ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // Panel Header Bar (Fixed 44px Height)
            RowLayout {
                Layout.fillWidth: true
                implicitHeight: 44
                Layout.preferredHeight: 44
                spacing: 10

                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 18
                    Layout.alignment: Qt.AlignVCenter
                    color: backHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 20
                        color: Config.textMain
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cardRoot.panelExpanded = false
                    }
                    HoverHandler { id: backHover }
                }

                // Title Section with Accent Glow & Italicizing
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    Item {
                        implicitWidth: caffExpTitleText.implicitWidth
                        implicitHeight: caffExpTitleText.implicitHeight
                        Layout.fillWidth: true

                        Text {
                            id: caffExpTitleText
                            text: "CAFFEINE"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontTitle)
                            font.bold: true
                            font.italic: true
                            elide: Text.ElideRight
                        }

                        Glow {
                            anchors.fill: caffExpTitleText
                            source: caffExpTitleText
                            radius: 6
                            samples: 12
                            color: Config.accent
                            spread: 0.2
                            transparentBorder: true
                            visible: Config.clockShowGlow
                        }
                    }

                    Text {
                        text: cardRoot.caffeineState === 2 
                            ? "Countdown Timer Active" 
                            : (cardRoot.caffeineState === 1 ? "System Awake (Indefinite)" : "Anti-Sleep Timer Disabled")
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        color: cardRoot.caffeineState !== 0 ? Config.accent : Config.textMuted
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Cycle State Quick Action Button
                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 18
                    color: cardRoot.caffeineState !== 0
                        ? (topPwrHover.hovered ? Qt.lighter(Config.accent, 1.1) : Config.accent)
                        : (topPwrHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: cardRoot.caffeineState === 2 ? "schedule" : "coffee"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 18
                        color: cardRoot.caffeineState !== 0 ? Config.bgBase : Config.textMuted
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (cardRoot.caffeineState !== 0) {
                                Config.startCaffeineTimer(0)
                            } else {
                                Config.setIndefiniteCaffeine()
                            }
                        }
                    }
                    HoverHandler { id: topPwrHover }
                }
            }

            // Divider Line
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(255, 255, 255, 0.08)
            }

            // Body Content Container (Locks Header Bar & Divider Line strictly to top of card)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // --- 3. STOPWATCH GRAPHIC & TIMER CENTERPIECE ---
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 150
                    Layout.alignment: Qt.AlignHCenter

                    Canvas {
                        id: stopwatchCanvas
                        width: 150
                        height: 150
                        anchors.centerIn: parent

                        property real animProgress: {
                            if (cardRoot.caffeineState === 0) return 0.0
                            if (cardRoot.caffeineState === 1) return 1.0
                            if (cardRoot.caffeineState === 2) {
                                let diffMs = Math.max(0, Config.caffeineTimerEndTime - Date.now())
                                let totalMs = cardRoot.caffeineTimerDuration * 60 * 1000
                                if (totalMs <= 0) return 0.0
                                return Math.min(1.0, Math.max(0.0, diffMs / totalMs))
                            }
                            return 0.0
                        }

                        onAnimProgressChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            var centerX = width / 2
                            var centerY = height / 2
                            var radius = 55
                            var startAngle = -Math.PI / 2
                            var endAngle = startAngle + (2 * Math.PI * animProgress)

                            // Background Circle Track
                            ctx.beginPath()
                            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI, false)
                            ctx.lineWidth = 6
                            ctx.strokeStyle = Qt.rgba(255, 255, 255, 0.06)
                            ctx.stroke()

                            // Active Arc
                            if (animProgress > 0) {
                                ctx.beginPath()
                                ctx.arc(centerX, centerY, radius, startAngle, endAngle, false)
                                ctx.lineWidth = 6
                                ctx.strokeStyle = Config.accent
                                ctx.lineCap = "round"
                                ctx.stroke()
                            }
                        }

                        Timer {
                            interval: 500
                            running: cardRoot.caffeineState === 2 && cardRoot.panelExpanded
                            repeat: true
                            onTriggered: stopwatchCanvas.requestPaint()
                        }
                    }

                    // Center Countdown / Status Text
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            text: cardRoot.caffeineState === 2 
                                ? cardRoot.remainingTimeString 
                                : (cardRoot.caffeineState === 1 ? "∞" : "00:00")
                            font.family: Config.sysFont
                            font.pixelSize: cardRoot.caffeineState === 1 ? 36 : Config.size(24)
                            font.bold: true
                            color: cardRoot.caffeineState !== 0 ? Config.accent : Config.textMuted
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: cardRoot.caffeineState === 2 
                                ? "REMAINING" 
                                : (cardRoot.caffeineState === 1 ? "INDEFINITE" : "DISABLED")
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            color: Config.textMuted
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // --- 4. DURATION ADJUSTMENT CONTROLS ---
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "ADJUST DURATION"
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        color: Config.textMuted
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // Numeric Step & Custom Input Row
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        // -5m Button
                        Rectangle {
                            implicitWidth: 42
                            implicitHeight: 32
                            radius: Config.cornerRadius / 2
                            color: minus5Hover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "-5m"
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: true
                                color: Config.textMain
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cardRoot.typedMinutes = Math.max(1, cardRoot.typedMinutes - 5)
                            }
                            HoverHandler { id: minus5Hover }
                        }

                        // Editable Minutes Input Box (Fixed 2px Border & I-Beam Cursor)
                        Rectangle {
                            implicitWidth: 70
                            implicitHeight: 32
                            radius: Config.cornerRadius / 2
                            color: Qt.rgba(0, 0, 0, 0.35)
                            border.width: 2
                            border.color: minutesInput.activeFocus ? Config.accent : Qt.rgba(255, 255, 255, 0.15)

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 3

                                TextInput {
                                    id: minutesInput
                                    text: cardRoot.typedMinutes.toString()
                                    color: Config.accent
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: true
                                    horizontalAlignment: TextInput.AlignHCenter
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    cursorShape: Qt.IBeamCursor
                                    validator: IntValidator { bottom: 1; top: 1440 }

                                    onTextChanged: {
                                        let val = parseInt(text)
                                        if (!isNaN(val) && val > 0) {
                                            cardRoot.typedMinutes = val
                                        }
                                    }
                                }

                                Text {
                                    text: "min"
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    color: Config.textMuted
                                }
                            }
                        }

                        // +5m Button
                        Rectangle {
                            implicitWidth: 42
                            implicitHeight: 32
                            radius: Config.cornerRadius / 2
                            color: plus5Hover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "+5m"
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: true
                                color: Config.textMain
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cardRoot.typedMinutes = cardRoot.typedMinutes + 5
                            }
                            HoverHandler { id: plus5Hover }
                        }
                    }

                    // Centered Preset Duration Pills Row
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        // 30m Preset Pill
                        Rectangle {
                            implicitWidth: 68
                            implicitHeight: 28
                            radius: 14
                            color: cardRoot.typedMinutes === 30 
                                ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.25)
                                : (p30Hover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.06))
                            border.width: cardRoot.typedMinutes === 30 ? 1 : 0
                            border.color: Config.accent
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "30m"
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: true
                                color: cardRoot.typedMinutes === 30 ? Config.accent : Config.textMain
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cardRoot.typedMinutes = 30
                            }
                            HoverHandler { id: p30Hover }
                        }

                        // 1h Preset Pill
                        Rectangle {
                            implicitWidth: 68
                            implicitHeight: 28
                            radius: 14
                            color: cardRoot.typedMinutes === 60 
                                ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.25)
                                : (p1hHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.06))
                            border.width: cardRoot.typedMinutes === 60 ? 1 : 0
                            border.color: Config.accent
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "1h"
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: true
                                color: cardRoot.typedMinutes === 60 ? Config.accent : Config.textMain
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cardRoot.typedMinutes = 60
                            }
                            HoverHandler { id: p1hHover }
                        }

                        // Always On (Indefinite Awake) Pill
                        Rectangle {
                            implicitWidth: 100
                            implicitHeight: 28
                            radius: 14
                            color: cardRoot.caffeineState === 1 
                                ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.25)
                                : (pAlwaysHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.06))
                            border.width: cardRoot.caffeineState === 1 ? 1 : 0
                            border.color: Config.accent
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "Always On"
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: true
                                color: cardRoot.caffeineState === 1 ? Config.accent : Config.textMain
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.setIndefiniteCaffeine()
                            }
                            HoverHandler { id: pAlwaysHover }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // --- 5. BOTTOM ACTION BUTTONS ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Disable / Allow Sleep Button
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: Config.cornerRadius / 2
                        color: disBtnHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "ALLOW SLEEP"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            color: disBtnHover.hovered ? Config.accent : Config.textMain
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.startCaffeineTimer(0)
                        }
                        HoverHandler { id: disBtnHover }
                    }

                    // Start / Update Timer Button
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: Config.cornerRadius / 2
                        color: startBtnHover.hovered ? Qt.lighter(Config.accent, 1.1) : Config.accent
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: cardRoot.caffeineState === 2 ? "UPDATE TIMER" : "START TIMER"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            color: Config.bgBase
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (cardRoot.typedMinutes > 0) {
                                    Config.startCaffeineTimer(cardRoot.typedMinutes)
                                }
                            }
                        }
                        HoverHandler { id: startBtnHover }
                    }
                }
            }
        }
    }
}