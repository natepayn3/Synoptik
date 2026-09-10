import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "services"

Item {
    id: root

    readonly property real screenWidth: Screen.width
    readonly property real screenHeight: Screen.height

    // Dynamic wide layout profile
    implicitWidth: Math.min(1440, Math.max(960, Math.round(screenWidth * 0.72)))
    implicitHeight: Math.min(480, Math.max(340, Math.round(screenHeight * 0.38)))

    property int activeIndex: 0
    property string activeHoveredPath: ""
    // Version counter to invalidate QML image cache when thumbnails finish rendering
    property int thumbEpoch: 0

    readonly property var colorSwatches: [
        { name: "red", hex: "#e53935" },
        { name: "orange", hex: "#fb8c00" },
        { name: "yellow", hex: "#fdd835" },
        { name: "green", hex: "#43a047" },
        { name: "cyan", hex: "#00acc1" },
        { name: "blue", hex: "#1e88e5" },
        { name: "purple", hex: "#8e24aa" },
        { name: "pink", hex: "#ec407a" },
        { name: "brown", hex: "#6d4c41" },
        { name: "white", hex: "#f5f5f5" },
        { name: "gray", hex: "#9e9e9e" },
        { name: "black", hex: "#212121" }
    ]

    // FolderListModel.get(idx, role) and plain ListModel.get(idx) are not the
    // same API (the latter ignores the role arg and returns the whole row) -
    // this normalizes access across whichever backs activeModel.
    function getModelFilePath(model, idx) {
        if (idx < 0 || idx >= model.count) return ""
        if (model === folderModel) return model.get(idx, "filePath")
        let row = model.get(idx)
        return row ? row.filePath : ""
    }

    // Compute unified thumbnail path stripping file extension
    function getThumbPath(filePath) {
        if (!filePath) return ""
        let clean = (typeof filePath === "string" ? filePath : filePath.toString()).replace(/^file:\/\//, "")
        let fileName = clean.split('/').pop()
        let baseName = fileName.replace(/\.[^/.]+$/, "")
        return Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + baseName + ".jpg"
    }

    // Resolves to the cached thumbnail (image or video frame grab)
    function resolveImageSource(rawPath) {
        if (!rawPath) return ""
        let clean = (typeof rawPath === "string" ? rawPath : rawPath.toString()).replace(/^file:\/\//, "")
        return "file://" + getThumbPath(clean)
    }

    Connections {
        target: WallpaperService
        function onThumbEpochChanged() {
            root.thumbEpoch = WallpaperService.thumbEpoch
            ambientBackdrop.source = Qt.binding(() => {
                if (root.activeHoveredPath !== "") return root.resolveImageSource(root.activeHoveredPath)
                if (root.activeModel.count > root.activeIndex && root.activeIndex >= 0) {
                    return root.resolveImageSource(root.getModelFilePath(root.activeModel, root.activeIndex))
                }
                return root.resolveImageSource(Config.activeWallpaperPath)
            })
        }
    }

    // Unified dispatcher routed directly through Config / WallpaperService
    QtObject {
        id: wallpaperBackend

        function triggerBackendRun(filePath, activeOnly) {
            if (!filePath) return
            let cleanFilePath = (typeof filePath === "string" ? filePath : filePath.toString()).replace(/^file:\/\//, "")
            Config.applyWallpaperBackend(cleanFilePath, activeOnly)
        }
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.mp4", "*.webm"]
        showDirs: false
        onCountChanged: if (root.hasActiveFilter) root.rebuildFilteredModel()
    }

    // Holds only the wallpapers matching the active color/type filters.
    // FolderListModel has no external-predicate filtering, and faking it by
    // collapsing non-matching delegates to width:0 breaks the ListView's
    // negative spacing (it still applies between hidden items, dragging
    // surviving tiles far off-layout) - so matches are pulled out of
    // folderModel into their own model instead.
    ListModel {
        id: filteredModel
    }

    readonly property bool hasActiveFilter: Config.colorFilter !== "" || Config.typeFilter !== ""

    // Which model currently backs the ListView
    readonly property var activeModel: hasActiveFilter ? filteredModel : folderModel

    function isVideoSuffix(suffix) {
        let s = (suffix || "").toLowerCase()
        return s === "mp4" || s === "webm"
    }

    function rebuildFilteredModel() {
        filteredModel.clear()
        if (!hasActiveFilter) return
        for (let i = 0; i < folderModel.count; i++) {
            let suffix = folderModel.get(i, "fileSuffix")
            if (Config.typeFilter === "image" && isVideoSuffix(suffix)) continue
            if (Config.typeFilter === "video" && !isVideoSuffix(suffix)) continue

            let rawPath = folderModel.get(i, "filePath")
            if (Config.colorFilter !== "") {
                let clean = (typeof rawPath === "string" ? rawPath : rawPath.toString()).replace(/^file:\/\//, "")
                let tags = (Config.wallpaperColorMap && Config.wallpaperColorMap[clean]) || []
                if (!Array.isArray(tags) || tags.indexOf(Config.colorFilter) === -1) continue
            }

            filteredModel.append({
                filePath: rawPath,
                fileName: folderModel.get(i, "fileName"),
                fileSuffix: suffix
            })
        }
        activeIndex = 0
    }

    Connections {
        target: Config
        function onWallpaperColorMapChanged() {
            if (root.hasActiveFilter) root.rebuildFilteredModel()
        }
        function onColorFilterChanged() {
            root.rebuildFilteredModel()
        }
        function onTypeFilterChanged() {
            root.rebuildFilteredModel()
        }
    }

    // Outer Shell Container
    ClippingRectangle {
        id: outerContainer
        anchors.fill: parent
        anchors.margins: Config.cardMargin !== undefined ? Config.cardMargin : 14
        radius: Config.cornerRadius
        color: Config.bgPanel
        border.width: 0

        // AMBIENT BACKDROP PROJECTION
        Image {
            id: ambientBackdrop
            anchors.fill: parent
            source: {
                if (root.activeHoveredPath !== "") return root.resolveImageSource(root.activeHoveredPath)
                if (root.activeModel.count > root.activeIndex && root.activeIndex >= 0) {
                    return root.resolveImageSource(root.getModelFilePath(root.activeModel, root.activeIndex))
                }
                return root.resolveImageSource(Config.activeWallpaperPath)
            }
            fillMode: Image.PreserveAspectCrop
            opacity: 0.22
            asynchronous: true
            cache: true

            Behavior on source {
                SequentialAnimation {
                    NumberAnimation { target: ambientBackdrop; property: "opacity"; to: 0.05; duration: 100 }
                    PropertyAction { target: ambientBackdrop; property: "source" }
                    NumberAnimation { target: ambientBackdrop; property: "opacity"; to: 0.22; duration: 250 }
                }
            }
        }

        FastBlur {
            anchors.fill: ambientBackdrop
            source: ambientBackdrop
            radius: 54
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.cardMargin !== undefined ? Config.cardMargin : 14
            spacing: 8

            // TOP NAVIGATION BAR
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item {
                    implicitWidth: wallpaperTitleText.implicitWidth
                    implicitHeight: wallpaperTitleText.implicitHeight

                    Glow {
                        anchors.fill: wallpaperTitleText
                        source: wallpaperTitleText
                        radius: 8
                        samples: 16
                        color: Config.accent
                        spread: 0.2
                        transparentBorder: true
                        visible: Config.clockShowGlow
                    }

                    Text {
                        id: wallpaperTitleText
                        anchors.fill: parent
                        text: "WALLPAPERS"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size ? Config.size(Config.fontTitle) : 16
                        font.bold: true
                        font.italic: true
                    }
                }

                Rectangle {
                    implicitWidth: countText.implicitWidth + 12
                    implicitHeight: 20
                    radius: Config.cornerRadius / 2
                    color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.1)

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root.activeModel.count + " items" + (root.hasActiveFilter ? " / " + folderModel.count : "")
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: 10
                        font.bold: true
                    }
                }

                // COLOR FILTER SWATCHES
                RowLayout {
                    spacing: 4

                    Repeater {
                        model: root.colorSwatches

                        Rectangle {
                            id: swatch
                            readonly property bool isActive: Config.colorFilter === modelData.name

                            implicitWidth: 14
                            implicitHeight: 14
                            radius: 3
                            color: modelData.hex
                            border.width: isActive ? 2 : 1
                            border.color: isActive ? Config.accent : Qt.rgba(0, 0, 0, 0.35)
                            scale: isActive ? 1.15 : 1.0

                            Behavior on scale { NumberAnimation { duration: 100 } }

                            ToolTip.visible: swatchHover.containsMouse
                            ToolTip.text: modelData.name
                            ToolTip.delay: 400

                            MouseArea {
                                id: swatchHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Config.colorFilter = swatch.isActive ? "" : modelData.name
                                }
                            }
                        }
                    }

                    Text {
                        text: "✕"
                        visible: Config.colorFilter !== ""
                        color: Config.textMuted
                        font.family: "monospace"
                        font.pixelSize: 11
                        font.bold: true
                        leftPadding: 4

                        TapHandler {
                            onTapped: Config.colorFilter = ""
                        }
                    }
                }

                // IMAGE / VIDEO TYPE FILTER
                RowLayout {
                    spacing: 6

                    Repeater {
                        model: [
                            { key: "", label: "ALL" },
                            { key: "image", label: "IMG" },
                            { key: "video", label: "VID" }
                        ]

                        Text {
                            readonly property bool isActive: Config.typeFilter === modelData.key
                            text: "[" + modelData.label + "]"
                            color: isActive ? Config.accent : Config.textMuted
                            font.family: "monospace"
                            font.pixelSize: 10
                            font.bold: isActive

                            TapHandler {
                                onTapped: Config.typeFilter = modelData.key
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // ASCII RANDOM SHUFFLE CONTROLS
                RowLayout {
                    spacing: 8
                    visible: folderModel.count > 0

                    Text {
                        text: Config.slideshowActive ? "[x]" : "[ ]"
                        color: Config.slideshowActive ? Config.accent : Config.textMuted
                        font.family: "monospace"
                        font.pixelSize: Config.size ? Config.size(Config.fontBody) : 12
                        font.bold: true

                        TapHandler {
                            onTapped: {
                                Config.slideshowActive = !Config.slideshowActive
                            }
                        }
                    }
                    Text {
                        text: "Random"
                        color: Config.slideshowActive ? Config.textMain : Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size ? Config.size(Config.fontMicro) : 10
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 5
                        opacity: Config.slideshowActive ? 1.0 : 0.4

                        Text {
                            text: "[-]"
                            color: Config.textMuted
                            font.family: "monospace"
                            font.pixelSize: Config.size ? Config.size(Config.fontBody) : 12
                            font.bold: true
                            TapHandler {
                                onTapped: {
                                    if (Config.slideshowMinutes > 1) {
                                        Config.slideshowMinutes--
                                    }
                                }
                            }
                        }
                        Text {
                            text: Config.slideshowMinutes + "m"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size ? Config.size(Config.fontMicro) : 10
                            font.bold: true
                            Layout.preferredWidth: 24
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: "[+]"
                            color: Config.textMuted
                            font.family: "monospace"
                            font.pixelSize: Config.size ? Config.size(Config.fontBody) : 12
                            font.bold: true
                            TapHandler {
                                onTapped: {
                                    Config.slideshowMinutes++
                                }
                            }
                        }
                    }
                }
            }

            // ACCORDION DECK CONTAINER
            Item {
                id: bladeContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                focus: true

                Component.onCompleted: forceActiveFocus()
                onVisibleChanged: if (visible) forceActiveFocus()

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_A || event.key === Qt.Key_Left) {
                        root.activeIndex = Math.max(0, root.activeIndex - 1)
                        bladeListView.positionViewAtIndex(root.activeIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_D || event.key === Qt.Key_Right) {
                        root.activeIndex = Math.min(root.activeModel.count - 1, root.activeIndex + 1)
                        bladeListView.positionViewAtIndex(root.activeIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        if (root.activeIndex >= 0 && root.activeModel.count > root.activeIndex) {
                            let activeOnly = (event.modifiers & Qt.ControlModifier) !== 0
                            let target = root.getModelFilePath(root.activeModel, root.activeIndex)
                            wallpaperBackend.triggerBackendRun(target, activeOnly)
                        }
                        event.accepted = true
                    }
                }

                ListView {
                    id: bladeListView
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: -14
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.activeModel
                    clip: false

                    delegate: Item {
                        id: bladeDelegate

                        readonly property bool isSelected: root.activeIndex === index
                        readonly property bool isHovered: bladeHover.containsMouse
                        readonly property string cleanPath: (typeof filePath === "string" ? filePath : "").replace(/^file:\/\//, "")
                        readonly property bool isVid: fileSuffix.toLowerCase() === "mp4" || fileSuffix.toLowerCase() === "webm"
                        readonly property string thumbFile: root.getThumbPath(filePath)

                        readonly property real actualH: bladeListView.height
                        readonly property real exact16by9W: Math.round(actualH * (16.0 / 9.0))

                        readonly property int distFromActive: Math.abs(index - root.activeIndex)
                        readonly property real scaleFactor: Math.max(0.38, Math.pow(0.84, distFromActive))

                        // The checkmark/info-bar above only track browse-focus
                        // (isSelected), so hovering a tile alone already looks
                        // "applied". This tracks the real, backend-confirmed
                        // signal instead (WallpaperService only writes
                        // Config.activeWallpaperPath after the apply process
                        // exits 0) for a distinct "this just actually applied"
                        // flash, separate from plain browsing.
                        readonly property string appliedCleanPath: (Config.activeWallpaperPath || "").replace(/^file:\/\//, "")
                        readonly property bool isActuallyApplied: bladeDelegate.cleanPath !== "" && bladeDelegate.cleanPath === appliedCleanPath
                        onIsActuallyAppliedChanged: if (isActuallyApplied) appliedFlash.restart()

                        width: isSelected ? exact16by9W : (isHovered ? Math.round(112 * scaleFactor + 24) : Math.round(96 * scaleFactor))
                        height: actualH
                        z: isSelected ? 200 : (100 - Math.min(90, distFromActive * 6))

                        Behavior on width {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        Item {
                            id: cardWrapper
                            anchors.fill: parent
                            anchors.topMargin: isSelected ? 0 : Math.round((1.0 - bladeDelegate.scaleFactor) * 44)
                            anchors.bottomMargin: isSelected ? 0 : Math.round((1.0 - bladeDelegate.scaleFactor) * 44)

                            Behavior on anchors.topMargin { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on anchors.bottomMargin { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                            transform: Rotation {
                                id: tiltRot
                                origin.x: cardWrapper.width / 2
                                origin.y: cardWrapper.height / 2
                                axis { x: 0; y: 1; z: 0 }
                                angle: bladeHover.containsMouse ? ((bladeHover.mouseX - (cardWrapper.width / 2)) / Math.max(1, cardWrapper.width)) * 8 : 0
                                Behavior on angle { NumberAnimation { duration: 120 } }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 0
                                color: Qt.rgba(255, 255, 255, 0.05)
                                border.width: 0
                                clip: true

                                Image {
                                    id: cardImg
                                    anchors.fill: parent
                                    property bool usingFallback: false

                                    source: {
                                        root.thumbEpoch
                                        cardImg.usingFallback = false
                                        return "file://" + bladeDelegate.thumbFile
                                    }

                                    onStatusChanged: {
                                        if (status === Image.Error && !usingFallback) {
                                            usingFallback = true
                                            source = filePath
                                        }
                                    }

                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: 320
                                    sourceSize.height: 180
                                    asynchronous: true
                                    cache: true
                                    smooth: false
                                    mipmap: false
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "black"
                                    opacity: isSelected ? 0.0 : Math.min(0.82, 0.15 + ((1.0 - bladeDelegate.scaleFactor) * 0.70))
                                    Behavior on opacity { NumberAnimation { duration: 140 } }
                                }

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.margins: 6
                                    implicitWidth: typeLabel.implicitWidth + 8
                                    implicitHeight: 18
                                    radius: 0
                                    color: Qt.rgba(0, 0, 0, 0.75)
                                    visible: isSelected

                                    Text {
                                        id: typeLabel
                                        anchors.centerIn: parent
                                        text: fileSuffix.toUpperCase()
                                        color: isVid ? Config.accent : Config.textMain
                                        font.family: "monospace"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    implicitHeight: 40
                                    radius: 0
                                    color: Qt.rgba(0, 0, 0, 0.85)
                                    visible: isSelected

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 6

                                        ColumnLayout {
                                            spacing: 0
                                            Layout.fillWidth: true

                                            Text {
                                                text: fileName
                                                color: Config.textMain
                                                font.family: Config.sysFont
                                                font.pixelSize: 11
                                                font.bold: true
                                                elide: Text.ElideMiddle
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: isVid ? "Animated Video Wallpaper" : "Static Image"
                                                color: Config.textMuted
                                                font.family: Config.sysFont
                                                font.pixelSize: 9
                                            }
                                        }

                                        Rectangle {
                                            implicitWidth: 22
                                            implicitHeight: 22
                                            radius: 11
                                            color: Config.accent

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✓"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Config.bgBase
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    opacity: isHovered ? 0.25 : 0.0
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 0.5; color: Qt.rgba(255, 255, 255, 0.35) }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }

                                Rectangle {
                                    id: appliedFlashRect
                                    anchors.fill: parent
                                    color: Config.accent
                                    opacity: 0

                                    SequentialAnimation {
                                        id: appliedFlash
                                        NumberAnimation { target: appliedFlashRect; property: "opacity"; to: 0.4; duration: 90; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: appliedFlashRect; property: "opacity"; to: 0.0; duration: 450; easing.type: Easing.OutCubic }
                                    }
                                }
                            }

                            MouseArea {
                                id: bladeHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onEntered: {
                                    root.activeIndex = index
                                    root.activeHoveredPath = bladeDelegate.cleanPath
                                    bladeListView.positionViewAtIndex(index, ListView.Contain)
                                }
                                onExited: {
                                    root.activeHoveredPath = ""
                                }
                                onClicked: (mouse) => {
                                    let activeOnly = (mouse.modifiers & Qt.ControlModifier) !== 0
                                    wallpaperBackend.triggerBackendRun(filePath, activeOnly)
                                    root.activeIndex = index
                                    bladeContainer.forceActiveFocus()
                                }
                                onWheel: (wheel) => {
                                    let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                                    if (delta > 0) {
                                        root.activeIndex = Math.max(0, root.activeIndex - 1)
                                    } else if (delta < 0) {
                                        root.activeIndex = Math.min(root.activeModel.count - 1, root.activeIndex + 1)
                                    }
                                    bladeListView.positionViewAtIndex(root.activeIndex, ListView.Contain)
                                }
                            }
                        }
                    }
                }
            }

            // FOOTER HINTS
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Text {
                    text: "🖱 Hover / Wheel to Browse"
                    color: Config.textMuted
                    font.family: "monospace"
                    font.pixelSize: 9
                }
                Text {
                    text: "⏎ [Enter / Click] Apply All"
                    color: Config.textMuted
                    font.family: "monospace"
                    font.pixelSize: 9
                }
                Text {
                    text: "⌃ [Ctrl + Enter / Click] Focused Monitor"
                    color: Config.textMuted
                    font.family: "monospace"
                    font.pixelSize: 9
                }
                Item { Layout.fillWidth: true }
            }
        }
    }
}