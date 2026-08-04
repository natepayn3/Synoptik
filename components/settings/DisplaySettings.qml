import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import ".."

Flickable {
    id: flickable
    Layout.fillWidth: true
    Layout.fillHeight: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + 32
    clip: true

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        active: flickable.moving || flickable.flicking
    }

    // Auto-aligns the leftmost monitor to x: 0 while preserving relative layout spacing
    function normalizeLeftmostMonitor() {
        let screens = Quickshell.screens
        if (!screens || screens.length === 0) return

        let minX = Number.MAX_VALUE
        for (let i = 0; i < screens.length; i++) {
            let cfg = Config.getMonitorConfig(screens[i].name)
            if (cfg && cfg.x < minX) {
                minX = cfg.x
            }
        }

        if (minX !== Number.MAX_VALUE && minX !== 0) {
            for (let j = 0; j < screens.length; j++) {
                let name = screens[j].name
                let cfg = Config.getMonitorConfig(name)
                Config.updateDraftMonitorConfig(name, { x: cfg.x - minX })
            }
        }
    }

    Component.onCompleted: normalizeLeftmostMonitor()

    ColumnLayout {
        id: contentColumn
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(flickable.width - 32, 620)
        spacing: 16

        Text {
            text: "BAR ORIENTATION"
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            font.bold: true
        }

        // Interactive Wireframe Monitor Preview
        Rectangle {
            id: monitorFrame
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 180
            implicitHeight: 108
            color: "transparent"
            border.color: Config.textMain
            border.width: 2
            radius: 12

            Rectangle { anchors.centerIn: parent; width: 24; height: 1; color: Config.textMain; opacity: 0.2 }
            Rectangle { anchors.centerIn: parent; width: 1; height: 24; color: Config.textMain; opacity: 0.2 }

            Rectangle {
                anchors.fill: parent
                anchors.margins: Config.barFrameStyle === "screen" ? 2 : 0
                color: "transparent"
                border.color: Config.accent
                border.width: Config.barFrameStyle === "screen" ? 3 : 0
                radius: Config.barFrameStyle === "screen" ? 10 : 0
                visible: Config.barFrameStyle === "screen"
                opacity: 1.0
            }

            Item {
                id: containerItem
                anchors.fill: parent
                anchors.margins: Config.barFrameStyle === "screen" ? 5 : 6

                Rectangle {
                    id: miniActiveBar
                    color: Config.accent
                    opacity: 1.0
                    radius: Config.barFrameStyle === "floating" ? 4 : 0

                    states: [
                        State {
                            name: "top"
                            when: Config.barPosition === "top"
                            PropertyChanges { target: miniActiveBar; x: 0; y: 0; width: containerItem.width; height: 8 }
                        },
                        State {
                            name: "bottom"
                            when: Config.barPosition === "bottom"
                            PropertyChanges { target: miniActiveBar; x: 0; y: containerItem.height - 8; width: containerItem.width; height: 8 }
                        },
                        State {
                            name: "left"
                            when: Config.barPosition === "left"
                            PropertyChanges { target: miniActiveBar; x: 0; y: 0; width: 8; height: containerItem.height }
                        },
                        State {
                            name: "right"
                            when: Config.barPosition === "right"
                            PropertyChanges { target: miniActiveBar; x: containerItem.width - 8; y: 0; width: 8; height: containerItem.height }
                        }
                    ]

                    transitions: [
                        Transition {
                            from: "*"; to: "*"
                            ParallelAnimation {
                                NumberAnimation { properties: "x,y,width,height"; duration: 150; easing.type: Easing.OutCubic }
                            }
                        }
                    ]
                }
            }

            TapHandler {
                onTapped: (point) => {
                    let localX = point.position.x
                    let localY = point.position.y
                    let xPct = Math.max(0.0, Math.min(1.0, localX / monitorFrame.width))
                    let yPct = Math.max(0.0, Math.min(1.0, localY / monitorFrame.height))
                    let dists = [yPct, 1.0 - yPct, xPct, 1.0 - xPct]
                    let minIdx = dists.indexOf(Math.min(...dists))
                    let edges = ["top", "bottom", "left", "right"]
                    Config.barPosition = edges[minIdx]
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        // Frame Style Buttons
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Text {
                text: "Bar Frame Style:"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontBody)
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Repeater {
                    model: [
                        { name: "Floating", style: "floating", icon: "sliders" },
                        { name: "Edge", style: "edge", icon: "border_left" },
                        { name: "Frame", style: "screen", icon: "web_asset" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: 130
                        implicitHeight: 36
                        radius: Config.cornerRadius / 2

                        readonly property bool isSelected: Config.barFrameStyle === modelData.style
                        color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (modeHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                        border.width: isSelected ? 1 : 0
                        border.color: Config.accent

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: modelData.icon
                                color: isSelected ? Config.accent : Config.textMuted
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 16
                            }

                            Text {
                                text: modelData.name
                                color: isSelected ? Config.accent : Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: isSelected
                                elide: Text.ElideRight
                            }
                        }

                        TapHandler { onTapped: Config.barFrameStyle = modelData.style }
                        HoverHandler { id: modeHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }

        // Display Target Selection
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Text {
                text: "Show Bar On These Displays:"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontBody)
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Repeater {
                    model: Quickshell.screens

                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: 90
                        implicitHeight: 32
                        radius: Config.cornerRadius / 2

                        readonly property bool isSelected: Config.enabledBarScreens.length === 0 || Config.enabledBarScreens.includes(modelData.name)
                        color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (dispHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                        border.width: isSelected ? 1 : 0
                        border.color: Config.accent

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: modelData.name
                                color: isSelected ? Config.accent : Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: isSelected
                                elide: Text.ElideRight
                            }

                            Text {
                                text: isSelected ? "✓" : "+"
                                color: isSelected ? Config.accent : Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: isSelected
                            }
                        }

                        TapHandler { onTapped: Config.toggleBarScreen(modelData.name) }
                        HoverHandler { id: dispHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }

        // --- DISPLAY RESOLUTION & LAYOUT MANAGER ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "DISPLAY RESOLUTION & LAYOUT"
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
            }

            // Canvas Box
            Rectangle {
                id: displayCanvas
                Layout.fillWidth: true
                implicitHeight: 220
                color: Qt.rgba(0, 0, 0, 0.25)
                radius: Config.cornerRadius / 2
                clip: true

                Grid {
                    anchors.fill: parent
                    rows: 8
                    columns: 16

                    Repeater {
                        model: parent.rows * parent.columns
                        Item {
                            width: displayCanvas.width / 16
                            height: displayCanvas.height / 8

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Qt.rgba(255, 255, 255, 0.03)
                            }

                            Rectangle {
                                width: 1
                                height: parent.height
                                color: Qt.rgba(255, 255, 255, 0.03)
                            }
                        }
                    }
                }

                Repeater {
                    model: Quickshell.screens

                    delegate: Item {
                        id: screenWrapper
                        required property var modelData

                        readonly property var monCfg: Config.getMonitorConfig(modelData.name)
                        readonly property bool isSelected: Config.selectedScreenConfig === modelData.name

                        readonly property real scaleFactor: 0.07

                        x: 40 + (monCfg.x * scaleFactor)
                        y: 25 + (monCfg.y * scaleFactor)

                        readonly property bool isRotated: monCfg.transform === 1 || monCfg.transform === 3
                        readonly property real renderWidth: isRotated ? monCfg.height : monCfg.width
                        readonly property real renderHeight: isRotated ? monCfg.width : monCfg.height

                        width: Math.max(80, renderWidth * scaleFactor)
                        height: Math.max(60, renderHeight * scaleFactor)

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: isSelected ? Qt.rgba(255, 255, 255, 0.16) : Qt.rgba(255, 255, 255, 0.05)
                            border.width: isSelected ? 2 : 1
                            border.color: isSelected ? Config.accent : Qt.rgba(255, 255, 255, 0.2)

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: screenWrapper.modelData.name
                                    color: Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontBody)
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: monCfg.width + "x" + monCfg.height
                                    color: Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: monCfg.transform === 1 ? "90°" : (monCfg.transform === 2 ? "180°" : (monCfg.transform === 3 ? "270°" : "0°"))
                                    color: Config.accent
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: true
                                    visible: monCfg.transform > 0
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }

                        TapHandler {
                            onTapped: Config.selectedScreenConfig = screenWrapper.modelData.name
                        }

                        DragHandler {
                            id: dragHandler
                            target: null

                            property real startX: 0
                            property real startY: 0

                            onActiveChanged: {
                                if (active) {
                                    startX = screenWrapper.monCfg.x
                                    startY = screenWrapper.monCfg.y
                                }
                            }

                            onTranslationChanged: {
                                if (!active) return

                                let calcX = Math.round(startX + (translation.x / screenWrapper.scaleFactor))
                                let calcY = Math.round(startY + (translation.y / screenWrapper.scaleFactor))

                                let other = Config.getOtherMonitorConfig(screenWrapper.modelData.name)
                                let snapDist = 60

                                let otherRot = other.transform === 1 || other.transform === 3
                                let otherW = otherRot ? other.height : other.width
                                let otherH = otherRot ? other.width : other.height

                                let selfW = screenWrapper.renderWidth
                                let selfH = screenWrapper.renderHeight

                                if (Math.abs(calcX - (other.x + otherW)) < snapDist) {
                                    calcX = other.x + otherW
                                } else if (Math.abs((calcX + selfW) - other.x) < snapDist) {
                                    calcX = other.x - selfW
                                } else if (Math.abs(calcX - other.x) < snapDist) {
                                    calcX = other.x
                                }

                                if (Math.abs(calcY - other.y) < snapDist) {
                                    calcY = other.y
                                } else if (Math.abs(calcY - (other.y + otherH)) < snapDist) {
                                    calcY = other.y + otherH
                                } else if (Math.abs((calcY + selfH) - other.y) < snapDist) {
                                    calcY = other.y - selfH
                                }

                                Config.updateDraftMonitorConfig(screenWrapper.modelData.name, { x: calcX, y: calcY })
                            }
                        }

                        HoverHandler { cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
                    }
                }
            }

            // Staggered Form Inspector Layout
            ColumnLayout {
                id: inspectorLayout
                Layout.fillWidth: true
                spacing: 12

                readonly property var activeCfg: Config.getMonitorConfig(Config.selectedScreenConfig)
                readonly property real formLabelWidth: 105

                // Row 1: Display Target Header
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Target: " + Config.selectedScreenConfig
                        color: Config.accent
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                    }
                }

                // Row 2: Resolution Selection
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Resolution:"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        Layout.preferredWidth: inspectorLayout.formLabelWidth
                    }

                    ComboBox {
                        id: resCombo
                        Layout.preferredWidth: 240
                        Layout.preferredHeight: 30

                        model: {
                            let modes = Config.detectedModes[Config.selectedScreenConfig]
                            if (modes && modes.length > 0) return modes

                            return [
                                { text: "2560x1440@164.84Hz", w: 2560, h: 1440, r: 164.84 },
                                { text: "2560x1440@120.00Hz", w: 2560, h: 1440, r: 120.0 },
                                { text: "2560x1440@59.95Hz", w: 2560, h: 1440, r: 59.95 },
                                { text: "1920x1080@144.00Hz", w: 1920, h: 1080, r: 144.0 },
                                { text: "1920x1080@60.00Hz", w: 1920, h: 1080, r: 60.0 }
                            ]
                        }
                        textRole: "text"

                        currentIndex: {
                            let cfg = Config.getMonitorConfig(Config.selectedScreenConfig)
                            for (let i = 0; i < model.length; i++) {
                                let m = model[i]
                                let matchW = m.w === cfg.width
                                let matchH = m.h === cfg.height
                                let matchR = m.r ? Math.abs(m.r - cfg.refreshRate) < 0.1 : true
                                if (matchW && matchH && matchR) return i
                            }
                            return 0
                        }

                        onActivated: (index) => {
                            let sel = model[index]
                            let opts = { width: sel.w, height: sel.h }
                            if (sel.r) opts.refreshRate = sel.r
                            Config.updateDraftMonitorConfig(Config.selectedScreenConfig, opts)
                        }

                        background: Rectangle {
                            color: resCombo.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
                            border.color: resCombo.activeFocus || resCombo.pressed ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                            border.width: 1
                            radius: Config.cornerRadius / 2
                        }

                        // Explicit Dropdown Indicator Styling (Fixes Black Arrow)
                        indicator: Text {
                            x: resCombo.width - width - 10
                            y: (resCombo.height - height) / 2
                            text: "▼"
                            font.pixelSize: 8
                            color: Config.textMain
                        }

                        contentItem: Text {
                            text: resCombo.displayText
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                        }

                        delegate: ItemDelegate {
                            width: resCombo.width
                            height: 30

                            contentItem: Text {
                                text: modelData.text || modelData
                                color: parent.hovered ? Config.accent : Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: parent.hovered
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 10
                            }

                            background: Rectangle {
                                color: parent.hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                                radius: Config.cornerRadius / 4
                            }
                        }

                        popup: Popup {
                            y: resCombo.height + 4
                            width: resCombo.width
                            implicitHeight: Math.min(contentItem.implicitHeight + 10, 200)
                            padding: 4

                            contentItem: ListView {
                                clip: true
                                implicitHeight: contentHeight
                                model: resCombo.popup.visible ? resCombo.delegateModel : null
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            }

                            background: Rectangle {
                                color: Config.bgPanel
                                border.color: Config.accent
                                border.width: 1
                                radius: Config.cornerRadius / 2
                            }
                        }
                    }
                }

                // Row 3: Display Scaling Control
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Scale:"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        Layout.preferredWidth: inspectorLayout.formLabelWidth
                    }

                    Repeater {
                        model: [
                            { label: "Auto", val: "auto" },
                            { label: "1.0", val: 1.0 },
                            { label: "1.25", val: 1.25 },
                            { label: "1.33", val: 1.33 },
                            { label: "1.6", val: 1.6 },
                            { label: "2.0", val: 2.0 }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: 48
                            implicitHeight: 28
                            radius: Config.cornerRadius / 2

                            readonly property bool isSelected: {
                                let activeScale = inspectorLayout.activeCfg.scale
                                if (modelData.val === "auto") {
                                    return activeScale === "auto" || !activeScale
                                }
                                let parsed = parseFloat(activeScale)
                                let numVal = isNaN(parsed) ? 1.0 : parsed
                                return Math.abs(numVal - modelData.val) < 0.01
                            }

                            color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (btnHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                            border.width: isSelected ? 1 : 0
                            border.color: Config.accent

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: parent.isSelected ? Config.accent : Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                                font.bold: parent.isSelected
                            }

                            TapHandler {
                                onTapped: Config.updateDraftMonitorConfig(Config.selectedScreenConfig, { scale: modelData.val })
                            }
                            HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }

                // Row 4: Orientation Controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Orientation:"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        Layout.preferredWidth: inspectorLayout.formLabelWidth
                    }

                    Repeater {
                        model: [
                            { name: "Normal (0°)", transform: 0, icon: "screenshot_monitor" },
                            { name: "90°", transform: 1, icon: "rotate_right" },
                            { name: "180°", transform: 2, icon: "autorenew" },
                            { name: "270°", transform: 3, icon: "rotate_left" }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: 92
                            implicitHeight: 26
                            radius: Config.cornerRadius / 2
                            readonly property bool isOrient: inspectorLayout.activeCfg.transform === modelData.transform
                            color: isOrient ? Qt.rgba(255, 255, 255, 0.12) : (orientHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                            border.width: isOrient ? 1 : 0
                            border.color: Config.accent

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: modelData.icon
                                    color: isOrient ? Config.accent : Config.textMuted
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 14
                                }

                                Text {
                                    text: modelData.name
                                    color: isOrient ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: isOrient
                                }
                            }

                            TapHandler {
                                onTapped: Config.updateDraftMonitorConfig(Config.selectedScreenConfig, { transform: modelData.transform })
                            }
                            HoverHandler { id: orientHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }

                // Row 5: Position Offset & Action Controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Position Offset:"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        Layout.preferredWidth: inspectorLayout.formLabelWidth
                    }

                    RowLayout {
                        spacing: 4

                        Rectangle {
                            implicitWidth: 28; implicitHeight: 24; radius: 4; color: Qt.rgba(255, 255, 255, 0.06)
                            Text { anchors.centerIn: parent; text: "←"; color: Config.textMain }
                            TapHandler { 
                                onTapped: {
                                    let cfg = Config.getMonitorConfig(Config.selectedScreenConfig)
                                    Config.updateDraftMonitorConfig(Config.selectedScreenConfig, { x: (cfg ? cfg.x : 0) - 50 })
                                }
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 28; implicitHeight: 24; radius: 4; color: Qt.rgba(255, 255, 255, 0.06)
                            Text { anchors.centerIn: parent; text: "→"; color: Config.textMain }
                            TapHandler { 
                                onTapped: {
                                    let cfg = Config.getMonitorConfig(Config.selectedScreenConfig)
                                    Config.updateDraftMonitorConfig(Config.selectedScreenConfig, { x: (cfg ? cfg.x : 0) + 50 })
                                }
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 28; implicitHeight: 24; radius: 4; color: Qt.rgba(255, 255, 255, 0.06)
                            Text { anchors.centerIn: parent; text: "↑"; color: Config.textMain }
                            TapHandler { 
                                onTapped: {
                                    let cfg = Config.getMonitorConfig(Config.selectedScreenConfig)
                                    Config.updateDraftMonitorConfig(Config.selectedScreenConfig, { y: (cfg ? cfg.y : 0) - 50 })
                                }
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 28; implicitHeight: 24; radius: 4; color: Qt.rgba(255, 255, 255, 0.06)
                            Text { anchors.centerIn: parent; text: "↓"; color: Config.textMain }
                            TapHandler { 
                                onTapped: {
                                    let cfg = Config.getMonitorConfig(Config.selectedScreenConfig)
                                    Config.updateDraftMonitorConfig(Config.selectedScreenConfig, { y: (cfg ? cfg.y : 0) + 50 })
                                }
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }

                    Text {
                        text: {
                            let cfg = Config.getMonitorConfig(Config.selectedScreenConfig)
                            return "(" + (cfg ? cfg.x : 0) + ", " + (cfg ? cfg.y : 0) + ")"
                        }
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                    }

                    Item { Layout.fillWidth: true }

                    // Discard
                    Rectangle {
                        implicitWidth: 80
                        implicitHeight: 30
                        radius: Config.cornerRadius / 2
                        color: discHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.03)

                        Text {
                            anchors.centerIn: parent
                            text: "Discard"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                        }

                        TapHandler { 
                            onTapped: {
                                Config.resetDraftMonitorConfigs()
                                flickable.normalizeLeftmostMonitor()
                            }
                        }
                        HoverHandler { id: discHover; cursorShape: Qt.PointingHandCursor }
                    }

                    // Apply & Save
                    Rectangle {
                        implicitWidth: 120
                        implicitHeight: 30
                        radius: Config.cornerRadius / 2
                        color: applyHover.hovered ? Qt.rgba(255, 255, 255, 0.16) : Qt.rgba(255, 255, 255, 0.12)
                        border.width: 1
                        border.color: Config.accent

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "check"
                                color: Config.accent
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                            }

                            Text {
                                text: "Apply & Save"
                                color: Config.accent
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: true
                            }
                        }

                        TapHandler { onTapped: Config.applyMonitorConfigs() }
                        HoverHandler { id: applyHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }
}