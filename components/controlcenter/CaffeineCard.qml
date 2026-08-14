import QtQuick
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

                    // Quick +/- buttons when active, or Chevron indicator
                    RowLayout {
                        spacing: 4
                        visible: cardRoot.caffeineState === 2
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 13
                            color: minusMiniHover.hovered ? Qt.rgba(255, 255, 255, 0.25) : Qt.rgba(255, 255, 255, 0.1)

                            Text {
                                anchors.centerIn: parent
                                text: "remove"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                                color: minusMiniHover.hovered ? Config.accent : Config.textMain
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.addCaffeineMinutes(-5)
                            }
                            HoverHandler { id: minusMiniHover }
                        }

                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 13
                            color: plusMiniHover.hovered ? Qt.rgba(255, 255, 255, 0.25) : Qt.rgba(255, 255, 255, 0.1)

                            Text {
                                anchors.centerIn: parent
                                text: "add"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                                color: plusMiniHover.hovered ? Config.accent : Config.textMain
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.addCaffeineMinutes(5)
                            }
                            HoverHandler { id: plusMiniHover }
                        }
                    }

                    Text {
                        text: "chevron_right"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 20
                        color: cardHover.hovered ? Config.textMain : Config.textMuted
                        opacity: cardRoot.hasHypridle ? 0.7 : 0.2
                        visible: cardRoot.caffeineState !== 2
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
            spacing: 14
            visible: opacity > 0
            opacity: cardRoot.panelExpanded ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // Header Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 18
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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "CAFFEINE"
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                        color: Config.textMain
                        elide: Text.ElideRight
                        Layout.fillWidth: true
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
                            // Normalize against 1 hour (3600000ms) or max duration
                            let norm = diffMs / 3600000.0
                            return Math.min(1.0, Math.max(0.05, norm))
                        }
                        return 0.0
                    }

                    onAnimProgressChanged: requestPaint()

                    Connections {
                        target: Config
                        function onCaffeineRemainingTimeStringChanged() { stopwatchCanvas.requestPaint() }
                        function onCaffeineStateChanged() { stopwatchCanvas.requestPaint() }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        var cx = width / 2;
                        var cy = height / 2 + 6;
                        var radius = 56;

                        // Stopwatch Crown & Top Loop Graphic
                        ctx.strokeStyle = Qt.rgba(255, 255, 255, cardRoot.caffeineState !== 0 ? 0.35 : 0.15);
                        ctx.lineWidth = 2.5;
                        ctx.beginPath();
                        ctx.arc(cx, 11, 5, 0, 2 * Math.PI);
                        ctx.stroke();

                        ctx.fillStyle = Qt.rgba(255, 255, 255, cardRoot.caffeineState !== 0 ? 0.4 : 0.2);
                        ctx.fillRect(cx - 3.5, 16, 7, 5);

                        // Stopwatch Outer Ring Track
                        ctx.lineWidth = 6;
                        ctx.strokeStyle = Qt.rgba(255, 255, 255, 0.08);
                        ctx.beginPath();
                        ctx.arc(cx, cy, radius, 0, 2 * Math.PI);
                        ctx.stroke();

                        // Sweeping Animated Progress Arc
                        if (stopwatchCanvas.animProgress > 0) {
                            ctx.lineWidth = 6;
                            ctx.strokeStyle = Config.accent;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            var startAngle = -Math.PI / 2;
                            var endAngle = startAngle + (stopwatchCanvas.animProgress * 2 * Math.PI);
                            ctx.arc(cx, cy, radius, startAngle, endAngle);
                            ctx.stroke();
                        }
                    }
                }

                // Inner Stopwatch Text Layout
                ColumnLayout {
                    anchors.centerIn: stopwatchCanvas
                    anchors.verticalCenterOffset: 6
                    spacing: 2

                    Text {
                        text: {
                            if (cardRoot.caffeineState === 2) return cardRoot.remainingTimeString !== "" ? cardRoot.remainingTimeString : "00:00"
                            if (cardRoot.caffeineState === 1) return "∞"
                            return "00:00"
                        }
                        font.family: Config.sysFont
                        font.pixelSize: cardRoot.caffeineState === 1 ? 36 : 26
                        font.bold: true
                        color: cardRoot.caffeineState !== 0 ? Config.accent : Config.textMuted
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: {
                            if (cardRoot.caffeineState === 2) return "REMAINING"
                            if (cardRoot.caffeineState === 1) return "ALWAYS ON"
                            return "DISABLED"
                        }
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        color: cardRoot.caffeineState !== 0 ? Config.textMain : Config.textMuted
                        opacity: 0.7
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // --- 4. PLUS / MINUS CONTROLS & EDITABLE MINUTES INPUT ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Layout.alignment: Qt.AlignHCenter

                Text {
                    text: "ADJUST DURATION"
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                    color: Config.textMuted
                    Layout.alignment: Qt.AlignHCenter
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    // -15m Button
                    Rectangle {
                        implicitWidth: 42
                        implicitHeight: 36
                        radius: Config.cornerRadius / 2
                        color: btnM15Hover.hovered ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "-15m"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            color: btnM15Hover.hovered ? Config.accent : Config.textMain
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.addCaffeineMinutes(-15)
                        }
                        HoverHandler { id: btnM15Hover }
                    }

                    // -5m Button
                    Rectangle {
                        implicitWidth: 38
                        implicitHeight: 36
                        radius: Config.cornerRadius / 2
                        color: btnM5Hover.hovered ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "-5m"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            color: btnM5Hover.hovered ? Config.accent : Config.textMain
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.addCaffeineMinutes(-5)
                        }
                        HoverHandler { id: btnM5Hover }
                    }

                    // Editable Specific Number Input Field
                    Rectangle {
                        implicitWidth: 84
                        implicitHeight: 36
                        radius: Config.cornerRadius / 2
                        color: Qt.rgba(0, 0, 0, 0.4)
                        border.color: numInput.activeFocus ? Config.accent : (numInputHover.hovered ? Qt.rgba(255, 255, 255, 0.3) : Qt.rgba(255, 255, 255, 0.15))
                        border.width: 2

                        HoverHandler {
                            id: numInputHover
                            cursorShape: Qt.IBeamCursor
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 2

                            TextInput {
                                id: numInput
                                Layout.fillWidth: true
                                verticalAlignment: TextInput.AlignVCenter
                                horizontalAlignment: TextInput.AlignHCenter
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: 14
                                font.bold: true
                                selectByMouse: true
                                text: cardRoot.typedMinutes.toString()

                                onTextChanged: {
                                    let val = parseInt(text)
                                    if (!isNaN(val) && val > 0) {
                                        cardRoot.typedMinutes = val
                                    }
                                }

                                onAccepted: {
                                    if (cardRoot.typedMinutes > 0) {
                                        Config.startCaffeineTimer(cardRoot.typedMinutes)
                                    }
                                }
                            }

                            Text {
                                text: "min"
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                color: Config.textMuted
                                Layout.alignment: Qt.AlignVCenter
                                Layout.rightMargin: 4
                            }
                        }
                    }

                    // +5m Button
                    Rectangle {
                        implicitWidth: 38
                        implicitHeight: 36
                        radius: Config.cornerRadius / 2
                        color: btnP5Hover.hovered ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "+5m"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            color: btnP5Hover.hovered ? Config.accent : Config.textMain
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.addCaffeineMinutes(5)
                        }
                        HoverHandler { id: btnP5Hover }
                    }

                    // +15m Button
                    Rectangle {
                        implicitWidth: 42
                        implicitHeight: 36
                        radius: Config.cornerRadius / 2
                        color: btnP15Hover.hovered ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "+15m"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            color: btnP15Hover.hovered ? Config.accent : Config.textMain
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.addCaffeineMinutes(15)
                        }
                        HoverHandler { id: btnP15Hover }
                    }
                }
            }

            // --- 5. QUICK PRESET PILLS ROW ---
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 15
                    color: pr15Hover.hovered ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.06)

                    Text {
                        anchors.centerIn: parent
                        text: "15m"
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        color: pr15Hover.hovered ? Config.accent : Config.textMain
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cardRoot.typedMinutes = 15
                            Config.startCaffeineTimer(15)
                        }
                    }
                    HoverHandler { id: pr15Hover }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 15
                    color: pr30Hover.hovered ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.06)

                    Text {
                        anchors.centerIn: parent
                        text: "30m"
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        color: pr30Hover.hovered ? Config.accent : Config.textMain
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cardRoot.typedMinutes = 30
                            Config.startCaffeineTimer(30)
                        }
                    }
                    HoverHandler { id: pr30Hover }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 15
                    color: pr1hHover.hovered ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.06)

                    Text {
                        anchors.centerIn: parent
                        text: "1h"
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        color: pr1hHover.hovered ? Config.accent : Config.textMain
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cardRoot.typedMinutes = 60
                            Config.startCaffeineTimer(60)
                        }
                    }
                    HoverHandler { id: pr1hHover }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 15
                    color: pr2hHover.hovered ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.06)

                    Text {
                        anchors.centerIn: parent
                        text: "2h"
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        color: pr2hHover.hovered ? Config.accent : Config.textMain
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cardRoot.typedMinutes = 120
                            Config.startCaffeineTimer(120)
                        }
                    }
                    HoverHandler { id: pr2hHover }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 15
                    color: prInfHover.hovered ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.06)

                    Text {
                        anchors.centerIn: parent
                        text: "Always On"
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        color: prInfHover.hovered ? Config.accent : Config.textMain
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.setIndefiniteCaffeine()
                    }
                    HoverHandler { id: prInfHover }
                }
            }

            Item { Layout.fillHeight: true }

            // --- 6. PRIMARY ACTION CONTROL BUTTONS ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Turn Off / Allow Sleep Button
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Config.cornerRadius / 2
                    color: offBtnHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "ALLOW SLEEP"
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        color: offBtnHover.hovered ? Config.accent : Config.textMain
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.startCaffeineTimer(0)
                    }
                    HoverHandler { id: offBtnHover }
                }

                // Apply Timer Button
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