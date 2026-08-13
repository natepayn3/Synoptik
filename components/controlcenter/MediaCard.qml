import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import ".."

Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: mediaRoot.implicitHeight + 24
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
            text: Config.getIcon("cc")
            font.family: "Material Symbols Outlined"
            font.pixelSize: 150
            color: Config.accent
            opacity: 0.12
            rotation: 15
        }
    }

    color: cardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
    Behavior on color { ColorAnimation { duration: 150 } }

    property string mediaTitle: "Not Playing"
    property string mediaArtist: "---"
    property string mediaStatus: "Stopped"
    property string mediaArtUrl: ""
    property var cavaBars: []

    signal sendCommand(var cmd)

    HoverHandler { id: cardHover }

    RowLayout {
        id: mediaRoot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: root.mediaStatus !== "Stopped" ? 16 : 0

        Item {
            id: artContainer
            implicitWidth: visible ? 130 : 0
            implicitHeight: 130
            Layout.alignment: Qt.AlignVCenter
            visible: root.mediaStatus !== "Stopped"

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
                    running: root.visible && root.mediaStatus === "Playing"
                }

                onRotationAngleChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    
                    if (!root.cavaBars || root.cavaBars.length === 0) return;
                    
                    var centerX = width / 2;
                    var centerY = height / 2;
                    var innerRadius = 46; 
                    var barCount = root.cavaBars.length;
                    
                    var maxBarLength = 14;  
                    var barWidth = 2.5;       
                    
                    ctx.save();
                    ctx.fillStyle = Config.accent; 
                    
                    for (var i = 0; i < barCount; i++) {
                        var angle = ((i * 2 * Math.PI) / barCount) + visualizerCanvas.rotationAngle;
                        var value = root.cavaBars[i] / 255.0; 
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
                    target: root
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
                    source: root.mediaArtUrl ? root.mediaArtUrl : ""
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
        }

        // Title and Control Details Column
        ColumnLayout {
            spacing: 8
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignVCenter

            Text { 
                id: titleText
                text: root.mediaTitle
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
                text: root.mediaArtist
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                elide: Text.ElideRight
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
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
                        onClicked: root.sendCommand(["playerctl", "previous"])
                    }
                }

                Item {
                    implicitWidth: 32
                    implicitHeight: 32
                    Layout.alignment: Qt.AlignVCenter
                    Text { 
                        anchors.centerIn: parent
                        text: root.mediaStatus === "Playing" ? "pause_circle" : "play_circle"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 30
                        color: Config.accent
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.sendCommand(["playerctl", "play-pause"])
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
                        onClicked: root.sendCommand(["playerctl", "next"])
                    }
                }
            }
        }
    }
}