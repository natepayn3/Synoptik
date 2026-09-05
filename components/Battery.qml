import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Item {
    id: root

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    implicitWidth: mainLayout.implicitWidth + (cardMargin * 2)
    implicitHeight: mainLayout.implicitHeight + (cardMargin * 2)

    property string battName: (typeof shellRoot !== "undefined" && shellRoot.hasBattery) ? shellRoot.battName : "BAT0"
    property int battCapacity: (typeof shellRoot !== "undefined" && shellRoot.hasBattery) ? shellRoot.battCapacity : 0
    property string battStatus: (typeof shellRoot !== "undefined" && shellRoot.hasBattery) ? shellRoot.battStatus : "Discharging"
    property string powerDraw: "2.4"

    // Periodic poller for power consumption details
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!battDetailProc.running) {
                battDetailProc.running = true
            }
        }
    }

    // Detailed Stats Poller
    Process {
        id: battDetailProc
        command: ["fish", "-c", "cat /sys/class/power_supply/" + root.battName + "/power_now 2>/dev/null; or echo 0"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let val = parseInt(this.text.trim()) || 0
                if (val > 0) {
                    root.powerDraw = (val / 1000000.0).toFixed(1)
                }
            }
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: root.cardMargin
        spacing: root.cardMargin / 2

        // Card 1: Title, Charging Status, & Capacity Track
        // ClippingRectangle (not plain Rectangle) so the watermark actually
        // respects the rounded corners instead of bleeding past them - plain
        // Rectangle.clip only clips to the square bounding box.
        ClippingRectangle {
            Layout.fillWidth: true
            implicitWidth: 360
            implicitHeight: topCardContent.implicitHeight + (root.cardMargin * 2)
            radius: Config.cornerRadius
            color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)

            Behavior on border.color { ColorAnimation { duration: 150 } }

            // GRAPHIC WATERMARK
            Watermark {
                icon: Config.getIcon("batt")
                iconSize: 150
                seed: 22
            }

            ColumnLayout {
                id: topCardContent
                anchors.fill: parent
                anchors.margins: root.cardMargin
                spacing: root.cardMargin

                // Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: {
                            if (root.battStatus === "Charging") return "battery_android_frame_bolt"
                            if (root.battCapacity <= 10) return "battery_android_0"
                            if (root.battCapacity <= 25) return "battery_android_frame_1"
                            if (root.battCapacity <= 40) return "battery_android_frame_2"
                            if (root.battCapacity <= 60) return "battery_android_frame_3"
                            if (root.battCapacity <= 75) return "battery_android_frame_4"
                            if (root.battCapacity <= 90) return "battery_android_frame_5"
                            if (root.battCapacity < 100) return "battery_android_frame_6"
                            return "battery_android_frame_full"
                        }
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: Config.size(Config.fontTitle)
                        color: Config.textMain
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item {
                        implicitWidth: battTitleText.implicitWidth
                        implicitHeight: battTitleText.implicitHeight
                        Layout.fillWidth: true

                        Glow {
                            anchors.fill: battTitleText
                            source: battTitleText
                            radius: 8
                            samples: 16
                            color: Config.accent
                            spread: 0.2
                            transparentBorder: true
                            visible: Config.clockShowGlow
                        }

                        Text {
                            id: battTitleText
                            anchors.fill: parent
                            text: "BATTERY"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontTitle)
                            font.bold: true
                            font.italic: true
                        }
                    }

                    Rectangle {
                        implicitWidth: statusText.implicitWidth + 12
                        implicitHeight: 22
                        radius: Config.cornerRadius / 2
                        color: root.battStatus === "Charging" ? Qt.rgba(16, 185, 129, 0.2) : Qt.rgba(255, 255, 255, 0.08)

                        Text {
                            id: statusText
                            anchors.centerIn: parent
                            text: root.battStatus.toUpperCase()
                            color: root.battStatus === "Charging" ? Config.accent : Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                        }
                    }
                }

                // Battery Status Track Row
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        spacing: 10

                        Text {
                            text: root.battCapacity + "% Available"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontSubhead)
                            font.bold: true
                        }
                    }

                    // Slider Container
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 40

                        // Unclipped glow layer matching track corner radius
                        RectangularGlow {
                            id: activeGlow
                            readonly property bool isCritical: root.battCapacity <= 15 && root.battStatus !== "Charging"

                            anchors.fill: battFillContainer
                            glowRadius: 16
                            spread: 0.2
                            color: root.battCapacity <= 15 ? "#ef4444" : Config.accent
                            cornerRadius: battTrack.radius
                            opacity: (root.battStatus === "Charging" || isCritical) && battFillContainer.width > 0 ? 0.5 : 0.0

                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            // Ambient breathing pulse once the battery is genuinely
                            // critical (draining, not just charging through a low
                            // reading) - the glow visibly breathes to read as urgent
                            // rather than sitting at one flat brightness.
                            SequentialAnimation {
                                running: activeGlow.isCritical
                                loops: Animation.Infinite
                                NumberAnimation { target: activeGlow; property: "glowRadius"; to: 26; duration: 900; easing.type: Easing.InOutSine }
                                NumberAnimation { target: activeGlow; property: "glowRadius"; to: 16; duration: 900; easing.type: Easing.InOutSine }
                            }
                        }

                        // Unclipped reference container tracking physical fill dimensions
                        Item {
                            id: battFillContainer
                            x: battTrack.x
                            y: battTrack.y
                            height: battTrack.height

                            readonly property real targetRatio: Math.max(0.0, Math.min(1.0, root.battCapacity / 100.0))

                            width: targetRatio <= 0 ? 0 : Math.max(height, battTrack.width * targetRatio)

                            Behavior on width {
                                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                            }
                        }

                        // Progress Track
                        // ClippingRectangle (not plain Rectangle) so the fill and charging
                        // shimmer actually respect the rounded corners instead of bleeding
                        // past them - plain Rectangle.clip only clips to the square
                        // bounding box.
                        ClippingRectangle {
                            id: battTrack
                            anchors.fill: parent
                            radius: Config.cornerRadius / 1.5
                            color: Qt.rgba(0, 0, 0, 0.35)

                            Rectangle {
                                id: battFill
                                width: battFillContainer.width
                                height: parent.height
                                radius: Config.cornerRadius / 1.5
                                color: root.battCapacity <= 15 ? "#ef4444" : Config.accent
                            }

                            // A tiny face instead of a plain fraction - same idea as the
                            // volume slider's face-in-track, riding centered in the filled
                            // portion so it travels with the level instead of sitting fixed.
                            Item {
                                id: battFace
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, (battFillContainer.width / 2) - (width / 2))
                                width: 22
                                height: 22

                                readonly property bool isCritical: root.battCapacity <= 15 && root.battStatus !== "Charging"
                                readonly property color faceColor: root.battCapacity > 10 ? Config.bgBase : Config.textMain

                                // Eyes and mouth both widen with the charge level - roughly
                                // 4px eyes / 10px mouth near empty, up to 10px / 24px at full -
                                // a subtle stretch as the bar fills, not just the mouth.
                                readonly property real eyeWidth: 4 + (root.battCapacity / 100) * 6
                                readonly property real mouthWidth: isCritical ? 9 : (10 + (root.battCapacity / 100) * 14)

                                property real bob: 0.0
                                SequentialAnimation on bob {
                                    running: true
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.0; duration: 900; easing.type: Easing.InOutSine }
                                }
                                transform: Translate { y: -battFace.bob * 1.5 }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 3
                                    spacing: 5
                                    Rectangle {
                                        width: battFace.eyeWidth
                                        height: battFace.isCritical ? 2 : 4
                                        radius: height / 2
                                        color: battFace.faceColor
                                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                        Behavior on height { NumberAnimation { duration: 150 } }
                                    }
                                    Rectangle {
                                        width: battFace.eyeWidth
                                        height: battFace.isCritical ? 2 : 4
                                        radius: height / 2
                                        color: battFace.faceColor
                                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                        Behavior on height { NumberAnimation { duration: 150 } }
                                    }
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 12
                                    width: battFace.mouthWidth
                                    height: battFace.isCritical ? 2 : (4 + (root.battCapacity / 100) * 4)
                                    radius: height / 2
                                    color: battFace.faceColor

                                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                    Behavior on height { NumberAnimation { duration: 180 } }
                                }
                            }

                            // Charging shimmer - a soft highlight sweeping across the
                            // fill so "charging" reads as active energy, not just a
                            // static color change.
                            Rectangle {
                                id: chargeSheen
                                visible: root.battStatus === "Charging" && battFillContainer.width > 0
                                width: Math.max(1, battFillContainer.width * 0.4)
                                height: parent.height
                                x: -width
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.55) }
                                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                                }

                                SequentialAnimation {
                                    running: chargeSheen.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { target: chargeSheen; property: "x"; from: -chargeSheen.width; to: battTrack.width; duration: 1500; easing.type: Easing.InOutSine }
                                    PauseAnimation { duration: 550 }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Bottom Stats Row
        RowLayout {
            Layout.fillWidth: true
            spacing: root.cardMargin

            // Card 2: Device Stats
            // ClippingRectangle (not plain Rectangle) so the watermark actually
            // respects the rounded corners instead of bleeding past them - plain
            // Rectangle.clip only clips to the square bounding box.
            ClippingRectangle {
                Layout.fillWidth: true
                implicitHeight: 64
                radius: Config.cornerRadius
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.1)

                Behavior on border.color { ColorAnimation { duration: 150 } }

                // GRAPHIC WATERMARK
                Watermark {
                    icon: "devices"
                    iconSize: 80
                    seed: 23
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        text: "DEVICE"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.battName
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // Card 3: Discharge Stats
            // ClippingRectangle (not plain Rectangle) so the watermark actually
            // respects the rounded corners instead of bleeding past them - plain
            // Rectangle.clip only clips to the square bounding box.
            ClippingRectangle {
                Layout.fillWidth: true
                implicitHeight: 64
                radius: Config.cornerRadius
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.1)

                Behavior on border.color { ColorAnimation { duration: 150 } }

                // GRAPHIC WATERMARK
                Watermark {
                    icon: "bolt"
                    iconSize: 80
                    seed: 24
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        text: "DISCHARGE"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.powerDraw + " W"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}