import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: cardRoot

    Layout.fillWidth: true
    implicitHeight: mediaRoot.implicitHeight + 24
    Layout.preferredHeight: implicitHeight
    z: panelExpanded ? 1000 : 1

    property Item controlCenterPanel: null
    property bool panelExpanded: false
    property bool shouldExpand: panelExpanded

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    property string mediaTitle: "Not Playing"
    property string mediaArtist: "---"
    property string mediaStatus: "Stopped"
    property string mediaArtUrl: ""
    property var cavaBars: []

    signal sendCommand(var cmd)

    onVisibleChanged: {
        if (!visible) panelExpanded = false
    }

    readonly property real collapsedX: {
        let sum = 0
        let p = cardRoot
        while (p && p !== controlCenterPanel) {
            sum += p.x
            p = p.parent
        }
        return sum
    }

    readonly property real collapsedY: {
        let sum = 0
        let p = cardRoot
        while (p && p !== controlCenterPanel) {
            sum += p.y
            p = p.parent
        }
        return sum
    }

    Rectangle {
        id: visualBackground
        parent: controlCenterPanel ? controlCenterPanel : cardRoot.parent
        z: cardRoot.panelExpanded ? 1000 : 100
        clip: true

        x: cardRoot.panelExpanded ? cardRoot.cardMargin : cardRoot.collapsedX
        y: cardRoot.panelExpanded ? cardRoot.cardMargin : cardRoot.collapsedY
        width: cardRoot.panelExpanded ? (controlCenterPanel ? (controlCenterPanel.width - (cardRoot.cardMargin * 2)) : 400) : cardRoot.width
        height: cardRoot.panelExpanded ? (controlCenterPanel ? (controlCenterPanel.height - (cardRoot.cardMargin * 2)) : 500) : cardRoot.implicitHeight

        radius: Config.cornerRadius

        color: cardRoot.panelExpanded
            ? Qt.rgba(Config.bgBase.r, Config.bgBase.g, Config.bgBase.b, 1.0)
            : (cardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04))

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

        MouseArea {
            anchors.fill: parent
            enabled: cardRoot.panelExpanded
            preventStealing: true
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onPressed: (mouse) => mouse.accepted = true
            onReleased: (mouse) => mouse.accepted = true
            onClicked: (mouse) => mouse.accepted = true
        }

        TapHandler {
            enabled: cardRoot.panelExpanded
            gesturePolicy: TapHandler.WithinBounds
            onTapped: {}
        }

        // --- 1. COLLAPSED CARD VIEW ---
        Item {
            id: collapsedView
            anchors.fill: parent
            visible: opacity > 0
            enabled: !cardRoot.panelExpanded
            opacity: cardRoot.panelExpanded ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Watermark {
                icon: Config.getIcon("cc")
                iconSize: 150
                seed: 1
            }

            RowLayout {
                id: mediaRoot
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: cardRoot.mediaStatus !== "Stopped" ? 16 : 0

                Item {
                    id: artContainer
                    implicitWidth: visible ? 130 : 0
                    implicitHeight: 130
                    Layout.alignment: Qt.AlignVCenter
                    visible: cardRoot.mediaStatus !== "Stopped"

                    Canvas {
                        id: visualizerCanvas
                        anchors.fill: parent
                        antialiasing: true
                        
                        property real rotationAngle: 0.0

                        PropertyAnimation on rotationAngle {
                            from: 0.0
                            to: 2 * Math.PI
                            duration: 20000
                            loops: Animation.Infinite
                            running: cardRoot.visible && cardRoot.mediaStatus === "Playing"
                        }

                        onRotationAngleChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            
                            if (!cardRoot.cavaBars || cardRoot.cavaBars.length === 0) return;
                            
                            var centerX = width / 2;
                            var centerY = height / 2;
                            var innerRadius = 46; 
                            var barCount = cardRoot.cavaBars.length;
                            
                            var maxBarLength = 14;  
                            var barWidth = 2.5;       
                            
                            ctx.save();
                            ctx.fillStyle = Config.accent; 
                            
                            for (var i = 0; i < barCount; i++) {
                                var angle = ((i * 2 * Math.PI) / barCount) + visualizerCanvas.rotationAngle;
                                var value = cardRoot.cavaBars[i] / 255.0; 
                                var barLength = value * maxBarLength;
                                
                                ctx.save();
                                ctx.translate(centerX, centerY);
                                ctx.rotate(angle);
                                
                                var startY = innerRadius + 2;
                                var endY = startY + barLength;
                                
                                var baseRadius = barWidth / 2;
                                var tipRadius = baseRadius + (value * 1.2);
                                
                                ctx.beginPath();
                                ctx.moveTo(-baseRadius, startY);
                                ctx.lineTo(-tipRadius, endY);
                                ctx.arc(0, endY, tipRadius, Math.PI, 0, true); 
                                ctx.lineTo(baseRadius, startY);
                                ctx.closePath();
                                ctx.fill();
                                
                                ctx.restore();
                            }
                            ctx.restore();
                        }

                        Connections {
                            target: cardRoot
                            function onCavaBarsChanged() { visualizerCanvas.requestPaint(); }
                        }
                    }

                    Item {
                        width: 88
                        height: 88
                        anchors.centerIn: parent

                        Image {
                            id: artImage
                            anchors.fill: parent
                            source: cardRoot.mediaArtUrl ? cardRoot.mediaArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                        }

                        Rectangle {
                            id: maskTarget
                            anchors.fill: parent
                            radius: width / 2
                            color: "black"
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: artImage
                            maskSource: maskTarget
                            visible: artImage.status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "music_note"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 34
                            color: Config.textMuted
                            visible: artImage.status !== Image.Ready
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cardRoot.panelExpanded = true
                    }
                }

                ColumnLayout {
                    spacing: 6
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignVCenter

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text { 
                            id: titleText
                            text: cardRoot.mediaTitle
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text { 
                            id: artistText
                            text: cardRoot.mediaArtist
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            Layout.fillWidth: true
                            implicitHeight: titleText.implicitHeight + artistText.implicitHeight + 2
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cardRoot.panelExpanded = true
                        }
                    }

                    RowLayout {
                        spacing: 14
                        Layout.alignment: Qt.AlignHCenter

                        Item {
                            implicitWidth: 26
                            implicitHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            Text { 
                                anchors.centerIn: parent
                                text: "skip_previous"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 22
                                color: Config.textMain
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: cardRoot.sendCommand(["playerctl", "previous"])
                            }
                        }

                        Item {
                            implicitWidth: 32
                            implicitHeight: 32
                            Layout.alignment: Qt.AlignVCenter
                            Text { 
                                anchors.centerIn: parent
                                text: cardRoot.mediaStatus === "Playing" ? "pause_circle" : "play_circle"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 30
                                color: Config.accent
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: cardRoot.sendCommand(["playerctl", "play-pause"])
                            }
                        }

                        Item {
                            implicitWidth: 26
                            implicitHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            Text { 
                                anchors.centerIn: parent
                                text: "skip_next"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 22
                                color: Config.textMain
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: cardRoot.sendCommand(["playerctl", "next"])
                            }
                        }
                    }
                }
            }
        }

        // --- 2. EXPANDED FULL PANEL VIEW ---
        Item {
            id: expandedView
            anchors.fill: parent
            anchors.margins: 14
            visible: opacity > 0
            enabled: cardRoot.panelExpanded
            opacity: cardRoot.panelExpanded ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    id: mediaHeaderRow
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    Layout.maximumHeight: 44
                    Layout.alignment: Qt.AlignTop
                    spacing: 10

                    Rectangle {
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: 18
                        Layout.alignment: Qt.AlignVCenter
                        color: backHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                        border.width: 2
                        border.color: backHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.12)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "arrow_back"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 20
                            color: backHover.hovered ? Config.accent : Config.textMain
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
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        Item {
                            implicitWidth: mediaExpTitleText.implicitWidth
                            implicitHeight: mediaExpTitleText.implicitHeight
                            Layout.fillWidth: true

                            Text {
                                id: mediaExpTitleText
                                text: "MEDIA PLAYER"
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontTitle)
                                font.bold: true
                                font.italic: true
                                elide: Text.ElideRight
                            }

                            Glow {
                                anchors.fill: mediaExpTitleText
                                source: mediaExpTitleText
                                radius: 6
                                samples: 12
                                color: Config.accent
                                spread: 0.2
                                transparentBorder: true
                                visible: Config.clockShowGlow
                            }
                        }

                        Text {
                            text: cardRoot.mediaStatus === "Playing" ? "Now Playing" : "Playback Paused"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            color: cardRoot.mediaStatus === "Playing" ? Config.accent : Config.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(255, 255, 255, 0.08)
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 16
                        width: parent.width

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 260
                            implicitHeight: 110
                            radius: Config.cornerRadius / 1.5
                            color: Qt.rgba(0, 0, 0, 0.3)
                            clip: true

                            Image {
                                id: expArtImage
                                anchors.fill: parent
                                source: cardRoot.mediaArtUrl ? cardRoot.mediaArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: expArtImage.status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "album"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 48
                                color: Config.textMuted
                                visible: expArtImage.status !== Image.Ready
                            }
                        }

                        Canvas {
                            id: expandedCavaCanvas
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            antialiasing: true

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                if (!cardRoot.cavaBars || cardRoot.cavaBars.length === 0) return;

                                var bars = cardRoot.cavaBars;
                                var barCount = Math.min(bars.length, 24);
                                var totalW = width;
                                var spacing = 4;
                                var barW = (totalW - (spacing * (barCount - 1))) / barCount;

                                ctx.fillStyle = Config.accent;

                                for (var i = 0; i < barCount; i++) {
                                    var val = bars[Math.floor(i * (bars.length / barCount))] / 255.0;
                                    var barH = Math.max(4, val * height);
                                    var x = i * (barW + spacing);
                                    var y = height - barH;

                                    ctx.beginPath();
                                    if (ctx.roundRect) {
                                        ctx.roundRect(x, y, barW, barH, barW / 2);
                                    } else {
                                        ctx.rect(x, y, barW, barH);
                                    }
                                    ctx.fill();
                                }
                            }

                            Connections {
                                target: cardRoot
                                function onCavaBarsChanged() { expandedCavaCanvas.requestPaint(); }
                            }
                        }

                        ColumnLayout {
                            spacing: 4
                            Layout.fillWidth: true

                            Text { 
                                text: cardRoot.mediaTitle
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontSubhead)
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text { 
                                text: cardRoot.mediaArtist
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        RowLayout {
                            spacing: 20
                            Layout.alignment: Qt.AlignHCenter

                            Item {
                                implicitWidth: 36
                                implicitHeight: 36
                                Layout.alignment: Qt.AlignVCenter
                                Text { 
                                    anchors.centerIn: parent
                                    text: "skip_previous"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 28
                                    color: Config.textMain
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: cardRoot.sendCommand(["playerctl", "previous"])
                                }
                            }

                            Item {
                                implicitWidth: 44
                                implicitHeight: 44
                                Layout.alignment: Qt.AlignVCenter
                                Text { 
                                    anchors.centerIn: parent
                                    text: cardRoot.mediaStatus === "Playing" ? "pause_circle" : "play_circle"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 36
                                    color: Config.accent
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: cardRoot.sendCommand(["playerctl", "play-pause"])
                                }
                            }

                            Item {
                                implicitWidth: 36
                                implicitHeight: 36
                                Layout.alignment: Qt.AlignVCenter
                                Text { 
                                    anchors.centerIn: parent
                                    text: "skip_next"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 28
                                    color: Config.textMain
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: cardRoot.sendCommand(["playerctl", "next"])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}