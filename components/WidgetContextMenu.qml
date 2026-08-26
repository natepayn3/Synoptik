import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

// Right-click menu shared by every desktop widget (Clock, System Info, Cava,
// Mascot) letting the user toggle any of them on/off from wherever they are,
// instead of navigating into Settings. Meant to be instantiated as a child of
// each widget's drag container (so it opens using that container's own local
// coordinate space) and included in that widget's PanelWindow `mask` region
// only while visible - see openAt()/close().
Rectangle {
    id: menu

    // --- OPEN/CLOSE MORPH: ported from UnifiedSurface.qml's popout squish
    // rather than the flat uniform-scale spring this used before. `progress`
    // drives an OutBack/InBack bounce (same durations/overshoot as the bar
    // panels), and width/height unfurl at different rates off it - height
    // lags width (pow 1.8) the same way the bar popouts grow wide before
    // they grow tall, so this reads as opening rather than just scaling up.
    // (UnifiedSurface's velocity-driven Matrix4x4 jelly-stretch is *not*
    // ported: that reacts to the popout continuously sliding between anchor
    // points while open, but this menu is repositioned by teleporting x/y
    // once before it opens - feeding that same teleport into a velocity
    // spring would read as a glitch, not a slide.)
    property bool isOpen: false
    property real progress: 0.0

    readonly property real targetWidth: Math.max(220, col.implicitWidth + (Config.cardMargin * 2))
    readonly property real targetHeight: col.implicitHeight + (Config.cardMargin * 2)

    readonly property real closeFactor: isOpen ? progress : Math.pow(Math.max(0, progress), 1.2)
    readonly property real heightFactor: Math.pow(Math.max(0, closeFactor), 1.8)
    readonly property real squishRatio: 1.0 - heightFactor
    readonly property real widthFactor: isOpen ? progress : (closeFactor + 0.33 * squishRatio * closeFactor)

    visible: progress > 0.01
    opacity: isOpen ? Math.min(1.0, progress * 1.3) : 0.0
    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    states: [
        State { name: "open"; when: menu.isOpen; PropertyChanges { target: menu; progress: 1.0 } },
        State { name: "closed"; when: !menu.isOpen; PropertyChanges { target: menu; progress: 0.0 } }
    ]

    transitions: [
        Transition {
            from: "closed"; to: "open"
            NumberAnimation { target: menu; property: "progress"; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.55 }
        },
        Transition {
            from: "open"; to: "closed"
            NumberAnimation { target: menu; property: "progress"; duration: 187; easing.type: Easing.InBack; easing.overshoot: 1.2 }
        }
    ]

    z: 1000
    radius: Math.max(0.1, Config.cornerRadius * Math.max(0, progress))
    color: Config.bgPanel
    border.width: Config.showBorders ? Config.borderThickness : 1
    border.color: (typeof shellRoot !== "undefined" && shellRoot.currentBorderColor) ? shellRoot.currentBorderColor : Qt.rgba(255, 255, 255, 0.1)
    clip: true

    Behavior on border.color { ColorAnimation { duration: 150 } }

    // GRAPHIC WATERMARK (same ambient background glyph the other module
    // cards - Battery, Notifications, TaskOverflow - use behind their content)
    Watermark {
        icon: Config.getIcon("cc")
        iconSize: 110
        seed: 33
    }

    implicitWidth: targetWidth
    implicitHeight: targetHeight
    width: targetWidth * Math.max(0, widthFactor)
    height: targetHeight * Math.max(0, heightFactor)

    // --- CONTENT JELLY: same underdamped-spring Matrix4x4 stretch as
    // UnifiedSurface's popout deformation, but driven by the *velocity of
    // this menu's own open/close factors* instead of raw screen-position
    // velocity. widthFactor/heightFactor only ever move via the smooth
    // OutBack/InBack NumberAnimation above - they never teleport the way x/y
    // do on reposition - so this can safely react to their rate of change
    // every tick without ever seeing a spurious spike. Gives the header/rows
    // (`col` below) a squash-and-stretch wobble synced to the pop instead of
    // just sitting there static while the outer card resizes around them.
    property real prevWidthFactor: 0.0
    property real prevHeightFactor: 0.0
    property real jellyDm00: 1.0
    property real jellyDm01: 0.0
    property real jellyDm11: 1.0
    property real jellyVel00: 0.0
    property real jellyVel01: 0.0
    property real jellyVel11: 0.0

    Timer {
        id: jellyTicker
        interval: 16
        repeat: true
        running: menu.visible

        onTriggered: {
            let dt = 0.016
            let vx = (menu.widthFactor - menu.prevWidthFactor) / dt
            let vy = (menu.heightFactor - menu.prevHeightFactor) / dt
            menu.prevWidthFactor = menu.widthFactor
            menu.prevHeightFactor = menu.heightFactor

            let speed = Math.sqrt(vx * vx + vy * vy)

            let target00 = 1.0
            let target01 = 0.0
            let target11 = 1.0

            // Tasteful stretch capped at 9% to keep row content readable
            if (speed > 0.15) {
                let kStretch = 0.35
                let targetStretch = 1.0 + Math.min(speed * kStretch, 0.09)
                let targetCompress = 1.0 / targetStretch
                let cosA = vx / speed
                let sinA = vy / speed
                let cos2 = cosA * cosA
                let sin2 = sinA * sinA
                let cs = cosA * sinA

                target00 = targetStretch * cos2 + targetCompress * sin2
                target01 = (targetStretch - targetCompress) * cs
                target11 = targetStretch * sin2 + targetCompress * cos2
            }

            let kStiffness = 855.0
            let kDamping = 45.0
            let invDamp = 1.0 / (1.0 + kDamping * dt)

            menu.jellyVel00 = (menu.jellyVel00 - kStiffness * (menu.jellyDm00 - target00) * dt) * invDamp
            menu.jellyDm00 += menu.jellyVel00 * dt

            menu.jellyVel01 = (menu.jellyVel01 - kStiffness * (menu.jellyDm01 - target01) * dt) * invDamp
            menu.jellyDm01 += menu.jellyVel01 * dt

            menu.jellyVel11 = (menu.jellyVel11 - kStiffness * (menu.jellyDm11 - target11) * dt) * invDamp
            menu.jellyDm11 += menu.jellyVel11 * dt
        }
    }

    readonly property var widgetDefs: [
        { id: "clock",   icon: "schedule",      label: "Clock",            enabled: Config.showDesktopClock },
        { id: "sysinfo", icon: "monitor_heart", label: "System Info",      enabled: Config.showDesktopSysInfo },
        { id: "cava",    icon: "graphic_eq",    label: "Audio Visualizer", enabled: Config.showDesktopCava },
        { id: "mascot",  icon: "pets",          label: "Desktop Mascot",   enabled: Config.showMascot }
    ]

    function toggle(id) {
        if (id === "clock") Config.showDesktopClock = !Config.showDesktopClock
        else if (id === "sysinfo") Config.showDesktopSysInfo = !Config.showDesktopSysInfo
        else if (id === "cava") Config.showDesktopCava = !Config.showDesktopCava
        else if (id === "mascot") Config.showMascot = !Config.showMascot
    }

    // Opens at (localX, localY) in `container`'s coordinate space, clamped so
    // the card stays fully within the monitor described by windowW/windowH.
    // Broadcasts closeWidgetMenus first so any other open instance (a
    // different widget, or the screen-wide catcher) closes - only one menu
    // is ever open at a time.
    function openAt(localX, localY, container, windowW, windowH) {
        let gx = Math.min(container.x + localX, windowW - implicitWidth - 8)
        let gy = Math.min(container.y + localY, windowH - implicitHeight - 8)
        x = gx - container.x
        y = gy - container.y
        Config.closeWidgetMenus()
        isOpen = true
        menu.forceActiveFocus()
    }

    function close() { isOpen = false }

    Connections {
        target: Config
        function onCloseWidgetMenus() { menu.close() }
    }

    Keys.onEscapePressed: (event) => {
        menu.close()
        event.accepted = true
    }

    // Absorbs clicks on the card itself so they never fall through to the
    // drag area behind it.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    ColumnLayout {
        id: col
        x: Config.cardMargin
        y: Config.cardMargin
        spacing: Config.cardMargin / 2

        transform: Matrix4x4 {
            matrix: {
                let cx = col.width / 2.0
                let cy = col.height / 2.0
                let m = Qt.matrix4x4(
                    1, 0, 0, cx,
                    0, 1, 0, cy,
                    0, 0, 1, 0,
                    0, 0, 0, 1
                )
                let def = Qt.matrix4x4(
                    menu.jellyDm00, menu.jellyDm01, 0, 0,
                    menu.jellyDm01, menu.jellyDm11, 0, 0,
                    0, 0, 1, 0,
                    0, 0, 0, 1
                )
                let inv = Qt.matrix4x4(
                    1, 0, 0, -cx,
                    0, 1, 0, -cy,
                    0, 0, 1, 0,
                    0, 0, 0, 1
                )
                return m.times(def).times(inv)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            spacing: 8

            Text {
                text: Config.getIcon("cc")
                font.family: "Material Symbols Outlined"
                font.pixelSize: Config.size(Config.fontTitle)
                color: Config.textMain
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                implicitWidth: menuTitleText.implicitWidth
                implicitHeight: menuTitleText.implicitHeight
                Layout.alignment: Qt.AlignVCenter

                Glow {
                    anchors.fill: menuTitleText
                    source: menuTitleText
                    radius: 8
                    samples: 16
                    color: Config.accent
                    spread: 0.2
                    transparentBorder: true
                    visible: Config.clockShowGlow
                }

                Text {
                    id: menuTitleText
                    anchors.fill: parent
                    text: "DESKTOP WIDGETS"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontTitle)
                    font.bold: true
                    font.italic: true
                }
            }
        }

        Repeater {
            model: menu.widgetDefs

            delegate: Rectangle {
                Layout.fillWidth: true
                implicitWidth: rowLayout.implicitWidth + 24
                implicitHeight: 44
                radius: Config.cornerRadius / 2
                color: rowHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(0, 0, 0, 0.25)

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    id: rowLayout
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 14

                    Text {
                        text: modelData.icon
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 19
                        color: modelData.enabled ? Config.accent : Config.textMuted
                    }

                    Text {
                        text: modelData.label
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption) + 1
                        font.bold: true
                        color: Config.textMain
                        Layout.fillWidth: true
                    }

                    // Compact switch (mirrors BarSettings.qml's ToggleSwitch look)
                    Rectangle {
                        implicitWidth: 38
                        implicitHeight: 21
                        radius: 6
                        color: modelData.enabled ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.22) : Qt.rgba(0, 0, 0, 0.4)
                        border.width: modelData.enabled ? 1.5 : 1
                        border.color: modelData.enabled ? Config.accent : Qt.rgba(255, 255, 255, 0.15)

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            x: modelData.enabled ? (parent.width - width - 3) : 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 15
                            height: 15
                            radius: 4
                            color: modelData.enabled ? Config.accent : Qt.rgba(255, 255, 255, 0.2)

                            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                TapHandler {
                    onTapped: {
                        menu.toggle(modelData.id)
                        menu.close()
                    }
                }
                HoverHandler { id: rowHover }
            }
        }
    }
}
