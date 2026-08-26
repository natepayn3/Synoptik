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

    // --- OPEN/CLOSE MORPH (same underdamped-spring Matrix4x4 technique as
    // the bar panels' popout in UnifiedSurface.qml, simplified to a uniform
    // scale from the corner it opened at, since this is a small anchored
    // popup rather than a shape that grows from a screen edge) ---
    property bool isOpen: false
    property real springVal: 0.0
    property real springVel: 0.0

    Timer {
        id: springTicker
        interval: 16
        repeat: true
        running: Math.abs(menu.springVal - (menu.isOpen ? 1.0 : 0.0)) > 0.001 || Math.abs(menu.springVel) > 0.001

        onTriggered: {
            let dt = 0.016
            let target = menu.isOpen ? 1.0 : 0.0
            let kStiffness = 420.0
            let kDamping = 26.0
            let invDamp = 1.0 / (1.0 + kDamping * dt)

            menu.springVel = (menu.springVel - kStiffness * (menu.springVal - target) * dt) * invDamp
            menu.springVal += menu.springVel * dt

            if (Math.abs(menu.springVal - target) < 0.001 && Math.abs(menu.springVel) < 0.001) {
                menu.springVal = target
                menu.springVel = 0
            }
        }
    }

    visible: springVal > 0.01
    opacity: Math.min(1.0, springVal * 1.3)

    transform: Matrix4x4 {
        matrix: {
            let s = Math.max(0.0001, menu.springVal)
            return Qt.matrix4x4(
                s, 0, 0, 0,
                0, s, 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1
            )
        }
    }

    z: 1000
    radius: Config.cornerRadius
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

    implicitWidth: Math.max(220, col.implicitWidth + 36)
    implicitHeight: col.implicitHeight + 28
    width: implicitWidth
    height: implicitHeight

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
        x: 18
        y: 14
        spacing: 6

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
