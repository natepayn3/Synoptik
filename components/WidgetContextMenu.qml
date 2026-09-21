import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Widgets
import "settings"

// Right-click menu shared by every desktop widget (Clock, System Info, Cava,
// Mascot) letting the user toggle any of them on/off from wherever they are,
// instead of navigating into Settings. Meant to be instantiated as a child of
// each widget's drag container (so it opens using that container's own local
// coordinate space) and included in that widget's PanelWindow `mask` region
// only while visible - see openAt()/close().
//
// ClippingRectangle (not plain Rectangle) so the watermark actually respects
// the rounded corners instead of bleeding past them - plain Rectangle.clip
// only clips to the square bounding box.
ClippingRectangle {
    id: menu

    // Widget id (matching an entry in widgetDefs below) of whatever container
    // this particular menu instance lives inside, e.g. "mascot" for the
    // instance nested in Mascot.qml. Left blank for instances not hosted by
    // any single toggleable widget (the empty-desktop catcher in
    // DesktopContextArea.qml) - toggling never has to close those.
    property string hostWidgetId: ""

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

    Behavior on border.color { ColorAnimation { duration: 150 } }

    // --- PANEL DEPTH ---
    // Flat bgPanel fill reads as a paper cutout at this size. A vertical
    // sheen (bright at the top, sinking to a shadow at the bottom) plus a
    // 1px catch-light on the top edge is the cheapest way to make it read as
    // a lit surface. Declared before Watermark and col so it sits under both.
    Rectangle {
        anchors.fill: parent
        // menu.radius, not parent.radius: `parent` is typed as a bare Item
        // here, so ClippingRectangle's own radius isn't reachable through it
        // and comes back undefined.
        radius: menu.radius
        gradient: Gradient {
            GradientStop { position: 0.0;  color: Qt.rgba(255, 255, 255, 0.07) }
            GradientStop { position: 0.45; color: Qt.rgba(255, 255, 255, 0.015) }
            GradientStop { position: 1.0;  color: Qt.rgba(0, 0, 0, 0.18) }
        }
    }

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
        height: 1
        color: Qt.rgba(255, 255, 255, 0.18)
        visible: menu.heightFactor > 0.5
    }

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

    // Static - deliberately holds no live Config reads. Each entry used to
    // embed `enabled: Config.showXxx` directly, which meant toggling *any
    // one* widget re-evaluated this whole array into a brand-new object
    // (since the array literal's binding depends on all 8 properties at
    // once). A plain JS array gives Repeater no way to diff that against
    // the old one, so it tore down and rebuilt every delegate - and every
    // freshly-built ToggleSwitch bound to checked: true fired its "just
    // switched on" bounce once, since it's transitioning off its own
    // declared default of false. isEnabled() below reads the per-id Config
    // property directly inside each row's own binding instead, so only the
    // one row whose property actually changed re-evaluates.
    // "assistant" used to be its own row here, back when it was a separate
    // widget from the mascot - now it's just the mascot's expanded form, so
    // "mascot" (labeled "Assistant" - the character is its collapsed state)
    // is the only row that shows/hides it. Toggling the expanded/collapsed
    // state itself is done by clicking the character (or its header avatar
    // to collapse), not from this generic widget list.
    readonly property var widgetDefs: [
        { id: "clock",   icon: "schedule",      label: "Clock" },
        { id: "sysinfo", icon: "monitor_heart", label: "System Info" },
        { id: "cava",    icon: "graphic_eq",    label: "Audio Visualizer" },
        { id: "mascot",  icon: "face",          label: "Assistant" },
        { id: "media",   icon: "album",         label: "Media Player" },
        { id: "mirror",  icon: "photo_camera",  label: "Mirror" },
        { id: "appdock", icon: "dock_to_bottom", label: "App Dock" }
    ]

    // Drives the header chip. Depends on all seven Config properties, which
    // is fine for a label - unlike widgetDefs itself (see its note above),
    // re-evaluating this never touches the Repeater's model, so no delegate
    // is ever torn down and no ToggleSwitch replays its bounce.
    readonly property int enabledCount: {
        let n = 0
        for (let i = 0; i < widgetDefs.length; i++) {
            if (isEnabled(widgetDefs[i].id)) n++
        }
        return n
    }

    function isEnabled(id) {
        if (id === "clock") return Config.showDesktopClock
        else if (id === "sysinfo") return Config.showDesktopSysInfo
        else if (id === "cava") return Config.showDesktopCava
        else if (id === "mascot") return Config.showMascot
        else if (id === "media") return Config.showDesktopMediaCard
        else if (id === "mirror") return Config.showMirror
        else if (id === "appdock") return Config.showAppDock
        return false
    }

    function toggle(id) {
        if (id === "clock") Config.showDesktopClock = !Config.showDesktopClock
        else if (id === "sysinfo") Config.showDesktopSysInfo = !Config.showDesktopSysInfo
        else if (id === "cava") Config.showDesktopCava = !Config.showDesktopCava
        else if (id === "mascot") Config.showMascot = !Config.showMascot
        else if (id === "media") Config.showDesktopMediaCard = !Config.showDesktopMediaCard
        else if (id === "mirror") Config.showMirror = !Config.showMirror
        else if (id === "appdock") Config.showAppDock = !Config.showAppDock
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
        // Anchored dead-center on menu's actual live width instead of a
        // hand-computed x - a manual (menu.width - col.width) / 2 here
        // still came out lopsided (targetWidth's 220px floor, the open/close
        // widthFactor animation, and col's own implicit-width resolution
        // all have to land in exact agreement for that math to work; anchors
        // just always match parent's real width, no arithmetic to get wrong).
        anchors.horizontalCenter: parent.horizontalCenter
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
            Layout.alignment: Qt.AlignHCenter
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

            // How many widgets are live, without having to count toggles.
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: countText.implicitWidth + 14
                implicitHeight: 20
                radius: 10
                color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.45)

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: menu.enabledCount + "/" + menu.widgetDefs.length
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.bold: true
                    color: Config.accent
                }
            }
        }

        Repeater {
            model: menu.widgetDefs

            delegate: Rectangle {
                id: rowRoot
                required property int index
                required property var modelData

                readonly property bool isOn: menu.isEnabled(modelData.id)
                readonly property color accentTint: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 1.0)

                // CASCADE: each row rides the menu's own open progress rather
                // than firing a one-shot animation of its own, offset by its
                // index so the list unfurls top-to-bottom. Two things fall out
                // of driving it off progress: it reverses for free on close,
                // and it can never desync from the card's pop the way a
                // separate timer would. The 0.45 divisor is the slice of the
                // open each row spends fading in; 0.07 per index is the gap
                // between neighbours.
                readonly property real appear: Math.max(0, Math.min(1, (menu.progress - index * 0.07) / 0.45))

                Layout.fillWidth: true
                implicitWidth: rowLayout.implicitWidth + 24
                implicitHeight: 44
                radius: Config.cornerRadius / 2

                opacity: appear

                // Two transforms, not one summed expression: the hover nudge
                // wants easing, the cascade slide does not (appear is already
                // smooth, and a Behavior on top of it visibly drags the
                // stagger). Separate Translates keep the Behavior off the
                // cascade.
                transform: [
                    Translate { x: (1 - rowRoot.appear) * -18 },
                    Translate {
                        x: rowHover.hovered ? 3 : 0
                        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }
                ]

                // An enabled row used to be indistinguishable from a disabled
                // one apart from the toggle itself - seven identical slabs.
                // Live rows now carry an accent wash; hover deepens it.
                color: rowHover.hovered
                     ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, rowRoot.isOn ? 0.24 : 0.12)
                     : (rowRoot.isOn ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.14)
                                     : Qt.rgba(0, 0, 0, 0.25))

                Behavior on color { ColorAnimation { duration: 120 } }

                // Accent rail on the leading edge, growing out of nothing when
                // the widget switches on - the at-a-glance "this one is live"
                // marker that scanning seven toggles otherwise requires.
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    radius: 1.5
                    height: rowRoot.isOn ? parent.height - 16 : 0
                    color: Config.accent
                    opacity: rowRoot.isOn ? 1.0 : 0.0

                    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }

                RowLayout {
                    id: rowLayout
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    // Icon chip - gives the list a launcher rhythm and carries
                    // the on/off state a second time, in colour rather than
                    // position, so it survives a glance that skips the toggle.
                    Rectangle {
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 9
                        color: rowRoot.isOn ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.22)
                                            : Qt.rgba(255, 255, 255, 0.06)
                        border.width: 1
                        border.color: rowRoot.isOn ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.5)
                                                   : Qt.rgba(255, 255, 255, 0.08)

                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on border.color { ColorAnimation { duration: 160 } }

                        Text {
                            anchors.centerIn: parent
                            text: rowRoot.modelData.icon
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                            color: rowRoot.isOn ? Config.accent : Config.textMuted
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                    }

                    Text {
                        text: rowRoot.modelData.label
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption) + 1
                        font.bold: true
                        color: Config.textMain
                        opacity: rowRoot.isOn ? 1.0 : 0.72
                        Layout.fillWidth: true

                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }

                    // Same shared switch every Settings page uses, bounce and all.
                    ToggleSwitch {
                        checked: rowRoot.isOn
                    }
                }

                TapHandler {
                    onTapped: {
                        // Only close first when this toggle turns off the very
                        // widget hosting this menu instance - that can tear down
                        // this menu's own container, so `menu` must not be
                        // touched after such a toggle. Toggling anything else
                        // (a different widget, or turning one on) never disturbs
                        // this menu's container, so it stays open and the user
                        // can flip several toggles from one right-click.
                        let closesOwnHost = (rowRoot.modelData.id === menu.hostWidgetId)
                        if (closesOwnHost) menu.close()
                        menu.toggle(rowRoot.modelData.id)
                    }
                }
                HoverHandler { id: rowHover }
            }
        }
    }
}
