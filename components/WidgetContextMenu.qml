import QtQuick
import QtQuick.Layouts

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

    implicitWidth: col.implicitWidth + 20
    implicitHeight: col.implicitHeight + 16
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
        x: 10
        y: 8
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            spacing: 6

            Rectangle {
                implicitWidth: 3
                implicitHeight: 12
                radius: 1.5
                color: Config.accent
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: "DESKTOP WIDGETS"
                color: Config.accent
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
                font.letterSpacing: 1.1
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Repeater {
            model: menu.widgetDefs

            delegate: Rectangle {
                Layout.fillWidth: true
                implicitWidth: rowLayout.implicitWidth + 16
                implicitHeight: 34
                radius: Config.cornerRadius / 2
                color: rowHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    id: rowLayout
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    Text {
                        text: modelData.icon
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                        color: modelData.enabled ? Config.accent : Config.textMuted
                    }

                    Text {
                        text: modelData.label
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
                        color: Config.textMain
                        Layout.fillWidth: true
                    }

                    // Compact switch (mirrors BarSettings.qml's ToggleSwitch look)
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 18
                        radius: 5
                        color: modelData.enabled ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.22) : Qt.rgba(0, 0, 0, 0.4)
                        border.width: modelData.enabled ? 1.5 : 1
                        border.color: modelData.enabled ? Config.accent : Qt.rgba(255, 255, 255, 0.15)

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            x: modelData.enabled ? (parent.width - width - 2) : 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13
                            height: 13
                            radius: 3
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
