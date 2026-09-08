import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell.Widgets
import Quickshell.Io
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

    // --- PER-APP VOLUME MIXER (right-click the volume slider to expand) ---
    property bool volumeExpanded: false
    property int pendingAppVolIndex: -1
    property int pendingAppVolValue: 0
    // True for the duration of any per-app row's press-drag-release, so the
    // background re-poll (see the Connections at the bottom of this file)
    // can never land mid-drag and overwrite the row you're actively moving -
    // that race was the cause of the single visible "jump" while dragging.
    property bool isDraggingAppVol: false

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
                        NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                    }
                }

                // ClippingRectangle (not plain Rectangle) so the fill respects the
                // rounded corners instead of bleeding past them - plain Rectangle.clip
                // only clips to the square bounding box.
                ClippingRectangle {
                    id: brightTrack
                    anchors.fill: parent
                    radius: Config.cornerRadius / 1.5
                    color: Qt.rgba(0, 0, 0, 0.35)

                    Rectangle {
                        id: brightFill
                        width: brightFillContainer.width
                        height: parent.height
                        radius: Config.cornerRadius / 1.5
                        color: Config.accent
                    }

                    // Same idea as the volume face - a squinting eye instead of
                    // a sun icon, that opens wider as brightness goes up.
                    Item {
                        id: brightEye
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        opacity: root.hasBacklight ? 1.0 : 0.5

                        readonly property color faceColor: root.hasBacklight ? Config.bgBase : Config.textMuted
                        readonly property real openness: root.hasBacklight ? Math.max(0.12, root.currentBrightness / 100) : 0.12

                        Rectangle {
                            anchors.centerIn: parent
                            width: 16
                            height: Math.max(3, 16 * brightEye.openness)
                            radius: height / 2
                            color: brightEye.faceColor

                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

                            // A plain darker dot read as just a smudge rather than an eye -
                            // a bigger pupil plus a small bright glint (the classic flat-icon
                            // eyeball tell) sells it instead.
                            Rectangle {
                                id: brightPupil
                                anchors.centerIn: parent
                                width: 7
                                height: 7
                                radius: 3.5
                                color: Qt.darker(brightEye.faceColor, 1.8)
                                visible: brightEye.openness > 0.35

                                Rectangle {
                                    x: 1.5
                                    y: 1.5
                                    width: 2.5
                                    height: 2.5
                                    radius: 1.25
                                    color: Qt.rgba(1, 1, 1, 0.9)
                                }
                            }
                        }
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
                        NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                    }
                }

                // ClippingRectangle (not plain Rectangle) so the fill respects the
                // rounded corners instead of bleeding past them - plain Rectangle.clip
                // only clips to the square bounding box.
                ClippingRectangle {
                    id: volTrack
                    anchors.fill: parent
                    radius: Config.cornerRadius / 1.5
                    color: Qt.rgba(0, 0, 0, 0.35)

                    Rectangle {
                        id: volFill
                        width: volFillContainer.width
                        height: parent.height
                        radius: Config.cornerRadius / 1.5
                        color: Config.accent
                    }

                    // A tiny face instead of a volume icon - the mouth grows with
                    // the level and flattens when muted, so the number is felt as
                    // an expression, not just read as a percentage.
                    Item {
                        id: volFace
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22

                        readonly property int activeVol: root.isUserDraggingVol
                            ? Math.round(root.localRatio * 100)
                            : root.currentVolume
                        readonly property color faceColor: (!root.isAudioMuted && activeVol > 10) ? Config.bgBase : Config.textMain

                        // Eyes and mouth both widen with volume - roughly 4px eyes / 8px
                        // mouth near silent, up to 10px / 22px at full - the same widening
                        // treatment the battery face uses.
                        readonly property real eyeWidth: 4 + (activeVol / 100) * 6
                        readonly property real mouthWidth: root.isAudioMuted ? 9 : (8 + (activeVol / 100) * 14)

                        property real bob: 0.0
                        SequentialAnimation on bob {
                            running: true
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.0; duration: 900; easing.type: Easing.InOutSine }
                        }
                        transform: Translate { y: -volFace.bob * 1.5 }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 3
                            spacing: 5
                            Rectangle {
                                width: volFace.eyeWidth
                                height: root.isAudioMuted ? 2 : 4
                                radius: height / 2
                                color: volFace.faceColor
                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                Behavior on height { NumberAnimation { duration: 150 } }
                            }
                            Rectangle {
                                width: volFace.eyeWidth
                                height: root.isAudioMuted ? 2 : 4
                                radius: height / 2
                                color: volFace.faceColor
                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                Behavior on height { NumberAnimation { duration: 150 } }
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 12
                            width: volFace.mouthWidth
                            height: root.isAudioMuted ? 2 : (4 + (volFace.activeVol / 100) * 6)
                            radius: height / 2
                            color: volFace.faceColor

                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                            Behavior on height { NumberAnimation { duration: 180 } }
                        }
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
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

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
                            if (mouse.button === Qt.RightButton) {
                                root.volumeExpanded = !root.volumeExpanded
                                return
                            }
                            root.isUserDraggingVol = true
                            applyDrag(mouse.x)
                        }

                        onPositionChanged: mouse => {
                            if (pressed && (pressedButtons & Qt.LeftButton)) {
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

        // ==========================================
        // SECTION 3: PER-APP VOLUME MIXER
        // ==========================================
        // Right-click the volume slider above to expand this. Backed by
        // `pactl -f json list sink-inputs` - each PipeWire playback stream
        // gets its own row. Kept in sync the same event-driven way Audio.qml
        // tracks its sink/source device lists: shell.qml's `pactl subscribe`
        // is already running for the master volume, so a "sink-input" event
        // on that same stream just debounces a re-list here instead of
        // starting a second subscribe process.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.volumeExpanded

            Text {
                Layout.fillWidth: true
                visible: appVolumeModel.count === 0
                text: "No apps are currently playing audio."
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.italic: true
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                model: appVolumeModel

                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    opacity: model.isCorked ? 0.5 : 1.0

                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 8
                        color: Qt.rgba(255, 255, 255, 0.08)

                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            source: Config.getAppIcon(model.iconName)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }

                    Text {
                        Layout.preferredWidth: 84
                        text: model.appName
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        elide: Text.ElideRight
                    }

                    // Compact track - same fill/handle idea as the main sliders,
                    // without the face animation (would be too busy repeated
                    // once per app row).
                    Item {
                        id: appTrack
                        Layout.fillWidth: true
                        implicitHeight: 22

                        property real displayRatio: (root.pendingAppVolIndex === model.streamIndex)
                            ? (root.pendingAppVolValue / 100.0)
                            : (model.volumePct / 100.0)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 5
                            radius: 2.5
                            color: Qt.rgba(0, 0, 0, 0.35)

                            Rectangle {
                                width: parent.width * Math.min(1.0, appTrack.displayRatio)
                                height: parent.height
                                radius: 2.5
                                color: model.isMuted ? Config.textMuted : Config.accent
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true

                            function applyDrag(mouseXPos) {
                                if (appTrack.width <= 0) return
                                let ratio = Math.max(0.0, Math.min(1.0, mouseXPos / appTrack.width))
                                let pct = Math.round(ratio * 100)
                                root.pendingAppVolIndex = model.streamIndex
                                root.pendingAppVolValue = pct
                                appVolumeWriteTimer.restart()
                            }

                            onPressed: mouse => {
                                root.isDraggingAppVol = true
                                applyDrag(mouse.x)
                            }
                            onPositionChanged: mouse => { if (pressed) applyDrag(mouse.x) }
                            onReleased: root.isDraggingAppVol = false
                            onCanceled: root.isDraggingAppVol = false
                        }
                    }

                    Text {
                        Layout.preferredWidth: 30
                        horizontalAlignment: Text.AlignRight
                        text: (root.pendingAppVolIndex === model.streamIndex ? root.pendingAppVolValue : model.volumePct) + "%"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                    }

                    Text {
                        text: model.isMuted ? "volume_off" : "volume_up"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                        color: model.isMuted ? Config.textMuted : Config.accent

                        TapHandler {
                            onTapped: {
                                appVolumeMuteProc.command = ["pactl", "set-sink-input-mute", String(model.streamIndex), model.isMuted ? "0" : "1"]
                                appVolumeMuteProc.running = true
                            }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }

    // --- PER-APP VOLUME MIXER BACKEND ---
    ListModel { id: appVolumeModel }

    // Target-id in-place model synchronizer - same idea as Audio.qml's
    // syncAudioModelInPlace, so a row's MouseArea/drag state isn't torn down
    // and recreated on every re-list (which fires on every "sink-input"
    // pactl event, not just an actual add/remove).
    function syncAppVolumeModelInPlace(newItems) {
        for (let i = appVolumeModel.count - 1; i >= 0; i--) {
            let entry = appVolumeModel.get(i)
            let match = newItems.find(item => item.streamIndex === entry.streamIndex)
            if (!match) appVolumeModel.remove(i)
        }
        for (let j = 0; j < newItems.length; j++) {
            let incoming = newItems[j]
            let foundIdx = -1
            for (let k = 0; k < appVolumeModel.count; k++) {
                if (appVolumeModel.get(k).streamIndex === incoming.streamIndex) { foundIdx = k; break }
            }
            if (foundIdx !== -1) {
                let existing = appVolumeModel.get(foundIdx)
                for (let prop in incoming) {
                    if (existing[prop] !== incoming[prop]) appVolumeModel.setProperty(foundIdx, prop, incoming[prop])
                }
            } else {
                appVolumeModel.append(incoming)
            }
        }
    }

    Process {
        id: appVolumeListProc
        command: ["pactl", "-f", "json", "list", "sink-inputs"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let parsed = []
                try {
                    parsed = JSON.parse(this.text || "[]")
                } catch (e) {
                    return
                }

                let rows = []
                for (let i = 0; i < parsed.length; i++) {
                    let item = parsed[i]
                    let props = item.properties || {}
                    let name = props["application.name"] || props["media.name"] || "Unknown"

                    // The shell's own UI sound effects show up as a stream too
                    // (media.name "quickshell") - not something to mix against
                    // itself, so it's left out of the list.
                    if (!props["application.name"] && name === "quickshell") continue

                    let channels = item.volume ? Object.keys(item.volume) : []
                    let pct = 0
                    if (channels.length > 0) {
                        let sum = 0
                        for (let c = 0; c < channels.length; c++) {
                            sum += parseInt(item.volume[channels[c]].value_percent) || 0
                        }
                        pct = Math.round(sum / channels.length)
                    }

                    rows.push({
                        streamIndex: item.index,
                        appName: name,
                        iconName: props["application.icon_name"] || "",
                        volumePct: pct,
                        isMuted: !!item.mute,
                        isCorked: !!item.corked
                    })
                }
                root.syncAppVolumeModelInPlace(rows)
            }
        }
    }

    Timer {
        id: appVolumeDebounceTimer
        interval: 200
        repeat: false
        onTriggered: {
            appVolumeListProc.running = false
            appVolumeListProc.running = true
        }
    }

    Timer {
        id: appVolumeWriteTimer
        interval: 30
        repeat: false
        onTriggered: {
            if (root.pendingAppVolIndex < 0) return
            appVolumeSetProc.command = ["pactl", "set-sink-input-volume", String(root.pendingAppVolIndex), root.pendingAppVolValue + "%"]
            appVolumeSetProc.running = true
        }
    }

    Process { id: appVolumeSetProc; running: false }
    Process { id: appVolumeMuteProc; running: false }

    onVolumeExpandedChanged: {
        if (volumeExpanded) appVolumeListProc.running = true
    }

    // shellRoot already runs `pactl subscribe` shell-wide for the master
    // volume (see shell.qml) - reuse that instead of starting a second
    // subscribe process just for this card.
    Connections {
        target: (typeof shellRoot !== "undefined") ? shellRoot : null
        function onAudioSubscribeEvent(data) {
            if (root.volumeExpanded && !root.isDraggingAppVol && data.includes("sink-input")) {
                appVolumeDebounceTimer.restart()
            }
        }
    }
}