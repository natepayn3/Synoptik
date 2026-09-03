import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell.Widgets
import ".."
import "../settings"

// ClippingRectangle (not plain Rectangle) so the watermark actually respects
// the rounded corners instead of bleeding past them - plain Rectangle.clip
// only clips to the square bounding box.
ClippingRectangle {
    id: root

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    Layout.fillWidth: true
    Layout.preferredWidth: parent ? parent.width : 356
    implicitHeight: sliderLayout.implicitHeight + (cardMargin * 2)
    radius: Config.cornerRadius
    color: cardHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
    border.width: 1
    border.color: Qt.rgba(255, 255, 255, 0.1)

    Behavior on border.color { ColorAnimation { duration: 150 } }
    Behavior on color { ColorAnimation { duration: 150 } }

    // GRAPHIC WATERMARK
    Watermark {
        icon: "tune"
        iconSize: 150
        baseRotation: -15
        seed: 2
    }

    // --- BRIGHTNESS PROPERTIES ---
    property int currentBrightness: 100
    property bool hasBacklight: false
    signal brightnessChanged(int pct)

    // --- VOLUME PROPERTIES ---
    property int currentVolume: 50
    property bool isAudioMuted: false
    property bool isUserDraggingVol: false
    property real localRatio: 0.0
    signal volumeChanged(int pct)

    HoverHandler { id: cardHover }

    ColumnLayout {
        id: sliderLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: root.cardMargin
        spacing: 12

        // ==========================================
        // NIGHT MODE
        // ==========================================
        // Same dark-card/icon-square language as the WiFi/Bluetooth/Caffeine/
        // DND tiles above, now full-width with an Auto-schedule toggle and
        // start/end hour steppers (Caffeine's -5m/+5m pattern, but hourly).
        Rectangle {
            id: nightCard
            Layout.fillWidth: true
            implicitHeight: nightCardCol.implicitHeight + 20
            radius: Config.cornerRadius
            color: Qt.rgba(0, 0, 0, 0.25)

            function hourLabel(h) {
                let period = h >= 12 ? "PM" : "AM"
                let hr = h % 12
                if (hr === 0) hr = 12
                return hr + " " + period
            }

            ColumnLayout {
                id: nightCardCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        id: nightIcon
                        implicitWidth: 48
                        implicitHeight: 48
                        radius: Config.cornerRadius / 2
                        color: Config.nightModeEnabled
                            ? ((nightIconHover.hovered && !Config.nightModeAuto) ? Qt.lighter(Config.accent, 1.1) : Config.accent)
                            : ((nightIconHover.hovered && !Config.nightModeAuto) ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.3))

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "bedtime"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 24
                            color: Config.nightModeEnabled ? Config.bgBase : Config.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !Config.nightModeAuto
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.nightModeEnabled = !Config.nightModeEnabled
                        }
                        HoverHandler { id: nightIconHover }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "Night Mode"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: true
                            color: Config.textMain
                        }

                        Text {
                            text: Config.nightModeAuto
                                ? ("Auto · " + nightCard.hourLabel(Config.nightModeScheduleStart) + " – " + nightCard.hourLabel(Config.nightModeScheduleEnd))
                                : (Config.nightModeEnabled ? "On" : "Off")
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            color: Config.nightModeEnabled ? Config.accent : Config.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        spacing: 6

                        Text {
                            text: "Auto"
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                            color: Config.nightModeAuto ? Config.accent : Config.textMuted
                        }

                        ToggleSwitch {
                            checked: Config.nightModeAuto

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.nightModeAuto = !Config.nightModeAuto
                            }
                        }
                    }
                }

                // Schedule hour steppers - only shown while Auto is on
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
                    visible: Config.nightModeAuto

                    RowLayout {
                        spacing: 4

                        Rectangle {
                            implicitWidth: 22; implicitHeight: 22; radius: 11
                            color: startMinusHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; text: "remove"; font.family: "Material Symbols Outlined"; font.pixelSize: 12; color: Config.textMain }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.nightModeScheduleStart = (Config.nightModeScheduleStart + 23) % 24
                            }
                            HoverHandler { id: startMinusHover }
                        }

                        Rectangle {
                            implicitWidth: 54; implicitHeight: 22; radius: 6
                            color: Qt.rgba(0, 0, 0, 0.3)
                            border.width: 1; border.color: Config.accent
                            Text {
                                anchors.centerIn: parent
                                text: nightCard.hourLabel(Config.nightModeScheduleStart)
                                color: Config.accent
                                font.family: Config.sysFont
                                font.bold: true
                                font.pixelSize: 10
                            }
                        }

                        Rectangle {
                            implicitWidth: 22; implicitHeight: 22; radius: 11
                            color: startPlusHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; text: "add"; font.family: "Material Symbols Outlined"; font.pixelSize: 12; color: Config.textMain }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.nightModeScheduleStart = (Config.nightModeScheduleStart + 1) % 24
                            }
                            HoverHandler { id: startPlusHover }
                        }
                    }

                    Text {
                        text: "–"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                    }

                    RowLayout {
                        spacing: 4

                        Rectangle {
                            implicitWidth: 22; implicitHeight: 22; radius: 11
                            color: endMinusHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; text: "remove"; font.family: "Material Symbols Outlined"; font.pixelSize: 12; color: Config.textMain }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.nightModeScheduleEnd = (Config.nightModeScheduleEnd + 23) % 24
                            }
                            HoverHandler { id: endMinusHover }
                        }

                        Rectangle {
                            implicitWidth: 54; implicitHeight: 22; radius: 6
                            color: Qt.rgba(0, 0, 0, 0.3)
                            border.width: 1; border.color: Config.accent
                            Text {
                                anchors.centerIn: parent
                                text: nightCard.hourLabel(Config.nightModeScheduleEnd)
                                color: Config.accent
                                font.family: Config.sysFont
                                font.bold: true
                                font.pixelSize: 10
                            }
                        }

                        Rectangle {
                            implicitWidth: 22; implicitHeight: 22; radius: 11
                            color: endPlusHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : Qt.rgba(255, 255, 255, 0.08)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; text: "add"; font.family: "Material Symbols Outlined"; font.pixelSize: 12; color: Config.textMain }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.nightModeScheduleEnd = (Config.nightModeScheduleEnd + 1) % 24
                            }
                            HoverHandler { id: endPlusHover }
                        }
                    }
                }
            }
        }

        // ==========================================
        // SECTION 1: BRIGHTNESS SLIDER
        // ==========================================
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            opacity: root.hasBacklight ? 1.0 : 0.45

            // Brightness Track Container
            Item {
                Layout.fillWidth: true
                implicitHeight: 40

                RectangularGlow {
                    id: activeBrightGlow
                    anchors.fill: brightFillContainer
                    glowRadius: 8
                    spread: 0.2
                    color: Config.accent
                    cornerRadius: brightTrack.radius
                    opacity: (brightHover.hovered || brightDrag.active) && root.hasBacklight && brightFillContainer.width > 0 ? 0.5 : 0.0

                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                Item {
                    id: brightFillContainer
                    x: brightTrack.x
                    y: brightTrack.y
                    height: brightTrack.height

                    width: (root.hasBacklight && root.currentBrightness > 0) 
                        ? Math.max(height, brightTrack.width * (root.currentBrightness / 100.0)) 
                        : 0

                    Behavior on width {
                        enabled: !brightDrag.active
                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                    }
                }

                Rectangle {
                    id: brightTrack
                    anchors.fill: parent
                    radius: Config.cornerRadius / 1.5
                    color: Qt.rgba(0, 0, 0, 0.35)
                    clip: true

                    Rectangle {
                        id: brightFill
                        width: brightFillContainer.width
                        height: parent.height
                        radius: Config.cornerRadius / 1.5
                        color: Config.accent
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "brightness_6"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 20
                        color: root.hasBacklight ? Config.bgBase : Config.textMuted
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.hasBacklight ? (root.currentBrightness + "%") : "Unavailable"
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        color: root.hasBacklight ? Config.textMain : Config.textMuted
                    }

                    DragHandler {
                        id: brightDrag
                        target: null
                        enabled: root.hasBacklight
                        onTranslationChanged: {
                            if (active && root.hasBacklight) {
                                let localX = brightDrag.centroid.position.x
                                let pct = Math.max(1, Math.min(100, Math.round((localX / brightTrack.width) * 100)))
                                
                                if (pct !== root.currentBrightness) {
                                    root.currentBrightness = pct
                                    root.brightnessChanged(pct)
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.hasBacklight
                        cursorShape: root.hasBacklight ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: {
                            let pct = Math.max(1, Math.min(100, Math.round((mouseX / brightTrack.width) * 100)))
                            root.currentBrightness = pct
                            root.brightnessChanged(pct)
                        }
                    }

                    HoverHandler { id: brightHover }
                }
            }
        }

        // ==========================================
        // SECTION 2: VOLUME SLIDER
        // ==========================================
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            // Volume Track Container
            Item {
                Layout.fillWidth: true
                implicitHeight: 40

                RectangularGlow {
                    id: activeVolGlow
                    anchors.fill: volFillContainer
                    glowRadius: 8
                    spread: 0.2
                    color: Config.accent
                    cornerRadius: volTrack.radius
                    opacity: (volHover.hovered || root.isUserDraggingVol) && !root.isAudioMuted && volFillContainer.width > 0 ? 0.5 : 0.0

                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                Item {
                    id: volFillContainer
                    x: volTrack.x
                    y: volTrack.y
                    height: volTrack.height

                    readonly property real targetRatio: root.isUserDraggingVol 
                        ? root.localRatio 
                        : (root.currentVolume / 100.0)

                    width: (root.isAudioMuted || targetRatio <= 0) 
                        ? 0 
                        : Math.max(height, volTrack.width * Math.min(1.0, targetRatio))

                    Behavior on width {
                        enabled: !root.isUserDraggingVol && !volArea.pressed && root.currentVolume >= 0
                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                    }
                }

                Rectangle {
                    id: volTrack
                    anchors.fill: parent
                    radius: Config.cornerRadius / 1.5
                    color: Qt.rgba(0, 0, 0, 0.35)
                    clip: true

                    Rectangle {
                        id: volFill
                        width: volFillContainer.width
                        height: parent.height
                        radius: Config.cornerRadius / 1.5
                        color: Config.accent
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property int activeVol: root.isUserDraggingVol 
                            ? Math.round(root.localRatio * 100) 
                            : root.currentVolume

                        text: root.isAudioMuted ? "volume_off" : (activeVol <= 0 ? "volume_mute" : (activeVol < 50 ? "volume_down" : "volume_up"))
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 20
                        color: (!root.isAudioMuted && activeVol > 10) ? Config.bgBase : Config.textMain
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property int displayVol: root.isUserDraggingVol
                            ? Math.round(root.localRatio * 100)
                            : root.currentVolume

                        text: root.isAudioMuted ? "MUTED" : (displayVol < 0 ? "---" : displayVol + "%")
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        color: root.isAudioMuted ? Config.textMuted : Config.textMain
                    }

                    MouseArea {
                        id: volArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true

                        function applyDrag(mouseXPos) {
                            let trackW = volTrack.width
                            if (trackW <= 0) return

                            let ratio = Math.max(0.0, Math.min(1.0, mouseXPos / trackW))
                            root.localRatio = ratio
                            
                            let pct = Math.round(ratio * 100)
                            if (pct !== root.currentVolume) {
                                root.volumeChanged(pct)
                            }
                        }

                        onPressed: mouse => {
                            root.isUserDraggingVol = true
                            applyDrag(mouse.x)
                        }

                        onPositionChanged: mouse => {
                            if (pressed) {
                                applyDrag(mouse.x)
                            }
                        }

                        onReleased: root.isUserDraggingVol = false
                        onCanceled: root.isUserDraggingVol = false
                    }

                    HoverHandler { id: volHover }
                }
            }
        }
    }
}