import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import ".."

Flickable {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + 32
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        active: root.moving || root.flicking
    }

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    readonly property var awwwTransitions: [
        { name: "fade",   icon: "blur_on" },
        { name: "wipe",   icon: "cleaning_services" },
        { name: "wave",   icon: "waves" },
        { name: "grow",   icon: "fullscreen" },
        { name: "center", icon: "filter_center_focus" },
        { name: "outer",  icon: "crop_free" },
        { name: "left",   icon: "arrow_back" },
        { name: "right",  icon: "arrow_forward" },
        { name: "top",    icon: "arrow_upward" },
        { name: "bottom", icon: "arrow_downward" },
        { name: "simple", icon: "flash_on" },
        { name: "random", icon: "shuffle" }
    ]

    property string currentWallpaperPath: Config.activeWallpaperPath || ""

    Process {
        id: wallpaperBackend
        running: false

        property string pendingIrisPath: ""

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && Config.enableIris && pendingIrisPath !== "") {
                Config.applyIrisColors(pendingIrisPath)
                pendingIrisPath = ""
            }
        }

        function applyWallpaper(filePath) {
            if (!filePath || filePath === "") return

            let cleanFilePath = (typeof filePath === "string" ? filePath : filePath.toString()).replace(/^file:\/\//, "")
            root.currentWallpaperPath = cleanFilePath
            Config.activeWallpaperPath = cleanFilePath

            let ext = cleanFilePath.split('.').pop().toLowerCase()
            let waylandDisplay = Quickshell.env("WAYLAND_DISPLAY") || "wayland-1"
            let sockPath = "/run/user/" + Quickshell.env("UID") + "/" + waylandDisplay + "-awww-daemon.sock"
            let targets = (Config.selectedWallpaperMonitors || []).filter(mon => {
                return Quickshell.screens.some(s => s.name === mon)
            })
            let transition = Config.wallpaperTransitionType || "fade"

            let script = "killall -q mpvpaper 2>/dev/null; "

            if (targets.length > 0) {
                for (let i = 0; i < targets.length; i++) {
                    let mon = targets[i]
                    if (ext === "mp4" || ext === "webm") {
                        script += "awww clear -o \"" + mon + "\" 2>/dev/null; "
                        script += "pkill -f 'mpvpaper' 2>/dev/null; "
                        script += "nohup mpvpaper -vs -o 'loop-file=inf no-audio panscan=1.0 video-unscaled=no' \"" + mon + "\" '" + cleanFilePath + "' >/dev/null 2>&1 & disown; "
                    } else {
                        script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; "
                        script += "awww img -o \"" + mon + "\" '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; "
                    }
                }
            } else {
                if (ext === "mp4" || ext === "webm") {
                    script += "awww kill 2>/dev/null; killall -9 -q awww-daemon 2>/dev/null; rm -f " + sockPath + "; "
                    script += "nohup mpvpaper -vs -o 'loop-file=inf no-audio panscan=1.0 video-unscaled=no' '*' '" + cleanFilePath + "' >/dev/null 2>&1 & disown; "
                } else {
                    script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; "
                    script += "awww img '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; "
                }
            }

            if (Config.enableIris) {
                if (ext === "mp4" || ext === "webm") {
                    let fileName = cleanFilePath.split('/').pop()
                    let thumbName = fileName.replace(/[^a-zA-Z0-9]/g, "_") + ".png"
                    let thumbPath = Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + thumbName
                    
                    pendingIrisPath = thumbPath
                    script += "test -f '" + thumbPath + "'; or ffmpeg -y -ss 00:00:00 -i '" + cleanFilePath + "' -vframes 1 -vf 'scale=600:-1' '" + thumbPath + "' >/dev/null 2>&1; "
                    script += "iris '" + thumbPath + "'; "
                } else {
                    pendingIrisPath = cleanFilePath
                    script += "iris '" + cleanFilePath + "'; "
                }
            }

            command = ["fish", "-c", script]
            running = false
            running = true
        }

        function shuffleRandom() {
            if (folderModel.count <= 0) return
            let randIdx = Math.floor(Math.random() * folderModel.count)
            let path = folderModel.get(randIdx, "filePath")
            if (path) applyWallpaper(path)
        }
    }

    ColumnLayout {
        id: contentColumn
        width: Math.min(root.width - (root.cardMargin * 2), 620)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.cardMargin

        // SECTION HEADER
        Text {
            Layout.fillWidth: true
            text: "WALLPAPER & BACKGROUNDS"
            color: Config.textMain
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontSubhead)
            font.bold: true
        }

        Text {
            text: "Manage active desktop wallpapers, per-monitor outputs, automated background slideshows, and smooth Wayland transitions."
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        // ==========================================
        // 1. ACTIVE WALLPAPER & SLIDESHOW CARD
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: activeCol.implicitHeight + 28
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.05)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)

            ColumnLayout {
                id: activeCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "ACTIVE WALLPAPER"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: true
                        }
                        Text {
                            text: root.currentWallpaperPath !== "" ? root.currentWallpaperPath.split('/').pop() : "No wallpaper set"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            elide: Text.ElideMiddle
                            Layout.maximumWidth: 320
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Random Shuffle Button
                    Rectangle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: 100
                        implicitHeight: 32
                        radius: 16
                        color: Config.accent

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "shuffle"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 15
                                color: Config.bgBase
                            }
                            Text {
                                text: "Random"
                                font.family: Config.sysFont
                                font.pixelSize: 11
                                font.bold: true
                                color: Config.bgBase
                            }
                        }

                        TapHandler { onTapped: wallpaperBackend.shuffleRandom() }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }

                // Automatic Slideshow Bar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: Config.cornerRadius / 2
                    color: Qt.rgba(0, 0, 0, 0.3)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.08)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: 10

                        // Checkbox
                        Rectangle {
                            implicitWidth: 18; implicitHeight: 18; radius: 4
                            color: Config.slideshowActive ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: Config.bgBase
                                visible: Config.slideshowActive
                                font.pixelSize: 11
                                font.bold: true
                            }

                            TapHandler { onTapped: Config.slideshowActive = !Config.slideshowActive }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: "Automatic Wallpaper Slideshow"
                                color: Config.slideshowActive ? Config.textMain : Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: Config.slideshowActive
                            }
                            Text {
                                text: "Cycles randomly through your wallpaper library"
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Interval Stepper
                        RowLayout {
                            spacing: 4
                            opacity: Config.slideshowActive ? 1.0 : 0.4

                            Rectangle {
                                implicitWidth: 26; implicitHeight: 26; radius: 13
                                color: Qt.rgba(255, 255, 255, 0.08)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.1)
                                Text {
                                    anchors.centerIn: parent
                                    text: "remove"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 14
                                    color: Config.textMain
                                }
                                TapHandler {
                                    onTapped: if (Config.slideshowMinutes > 1) Config.slideshowMinutes--
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                            }

                            Rectangle {
                                implicitWidth: 44; implicitHeight: 26; radius: 6
                                color: Qt.rgba(0, 0, 0, 0.4)
                                border.width: 1
                                border.color: Config.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: Config.slideshowMinutes + "m"
                                    color: Config.accent
                                    font.family: Config.sysFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }

                            Rectangle {
                                implicitWidth: 26; implicitHeight: 26; radius: 13
                                color: Qt.rgba(255, 255, 255, 0.08)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.1)
                                Text {
                                    anchors.centerIn: parent
                                    text: "add"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 14
                                    color: Config.textMain
                                }
                                TapHandler {
                                    onTapped: Config.slideshowMinutes++
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // 2. TARGET OUTPUT MONITORS CARD
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: monCol.implicitHeight + 28
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.05)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)

            ColumnLayout {
                id: monCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "TARGET DISPLAYS"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: true
                        }
                        Text {
                            text: "Select monitors to apply wallpapers to (unselected monitors share the global wallpaper)."
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: Quickshell.screens

                        delegate: Rectangle {
                            id: monBtn
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 40
                            radius: Config.cornerRadius / 2

                            readonly property bool isSelected: Config.selectedWallpaperMonitors && Config.selectedWallpaperMonitors.includes(modelData.name)
                            color: isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.16) : (monHover.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2))
                            border.width: isSelected ? 1.5 : 1
                            border.color: isSelected ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: "desktop_windows"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 16
                                    color: monBtn.isSelected ? Config.accent : Config.textMuted
                                }

                                Text {
                                    text: modelData.name
                                    color: monBtn.isSelected ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: monBtn.isSelected
                                }

                                Rectangle {
                                    implicitWidth: 16; implicitHeight: 16; radius: 8
                                    color: monBtn.isSelected ? Config.accent : Qt.rgba(255, 255, 255, 0.08)
                                    Text {
                                        anchors.centerIn: parent
                                        text: monBtn.isSelected ? "✓" : "+"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: monBtn.isSelected ? Config.bgBase : Config.textMuted
                                    }
                                }
                            }

                            MouseArea {
                                id: monHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.toggleWallpaperMonitor(modelData.name)
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // 3. TRANSITION EFFECT CARD
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: transCol.implicitHeight + 28
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.05)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)

            ColumnLayout {
                id: transCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                Text {
                    text: "WAYLAND TRANSITIONS"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    font.bold: true
                }

                GridLayout {
                    columns: 4
                    rowSpacing: 8
                    columnSpacing: 8
                    Layout.fillWidth: true

                    Repeater {
                        model: root.awwwTransitions

                        delegate: Rectangle {
                            id: transBtn
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Config.cornerRadius / 2
                            readonly property bool isSelected: (Config.wallpaperTransitionType || "fade") === modelData.name
                            color: isSelected ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.16) : (transHover.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2))
                            border.width: isSelected ? 1.5 : 1
                            border.color: isSelected ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: modelData.icon
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 14
                                    color: transBtn.isSelected ? Config.accent : Config.textMuted
                                }

                                Text {
                                    text: modelData.name
                                    color: transBtn.isSelected ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: 11
                                    font.bold: transBtn.isSelected
                                }
                            }

                            MouseArea {
                                id: transHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.wallpaperTransitionType = modelData.name
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // 4. WALLPAPER LIBRARY GALLERY CARD
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: galleryCol.implicitHeight + 28
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.05)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)

            ColumnLayout {
                id: galleryCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "WALLPAPER GALLERY"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: true
                        }
                        Text {
                            text: "~/Pictures/Wallpapers"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Count Badge
                    Rectangle {
                        implicitWidth: wpCountText.implicitWidth + 16
                        implicitHeight: 24
                        radius: 12
                        color: Qt.rgba(255, 255, 255, 0.08)

                        Text {
                            id: wpCountText
                            anchors.centerIn: parent
                            text: folderModel.count + " Wallpapers"
                            font.family: Config.sysFont
                            font.pixelSize: 11
                            font.bold: true
                            color: Config.textMuted
                        }
                    }
                }

                // Grid View Box
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(260, gridView.contentHeight + 12)
                    color: Qt.rgba(0, 0, 0, 0.3)
                    radius: Config.cornerRadius / 2
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    clip: true

                    GridView {
                        id: gridView
                        anchors.fill: parent
                        anchors.margins: 6
                        cellWidth: width / 3
                        cellHeight: Math.floor(cellWidth * (9 / 16)) + 8

                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: 2000
                        reuseItems: true

                        model: FolderListModel {
                            id: folderModel
                            folder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"
                            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.mp4", "*.webm"]
                            showDirs: false
                        }

                        delegate: Item {
                            id: delegateItem
                            width: gridView.cellWidth
                            height: gridView.cellHeight

                            readonly property string cleanPath: (typeof filePath === "string" ? filePath : filePath.toString()).replace(/^file:\/\//, "")
                            readonly property bool isCurrent: root.currentWallpaperPath === cleanPath || root.currentWallpaperPath === filePath
                            readonly property bool isVideo: {
                                let ext = fileSuffix.toLowerCase()
                                return ext === "mp4" || ext === "webm"
                            }

                            readonly property string thumbName: fileName.replace(/\./g, "_") + ".jpg"
                            readonly property string thumbPath: Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + thumbName
                            readonly property string thumbUrl: "file://" + thumbPath

                            Process {
                                id: delegateThumbGenerator
                                running: false

                                onExited: (exitCode, exitStatus) => {
                                    if (exitCode === 0) {
                                        let path = delegateItem.thumbUrl
                                        thumbImage.source = ""
                                        thumbImage.source = path
                                    }
                                }
                            }

                            Component.onCompleted: {
                                if (isVideo) {
                                    let cmd = "if not test -f '" + thumbPath + "'; ffmpeg -y -i '" + cleanPath + "' -vf 'scale=300:-1' '" + thumbPath + "' >/dev/null 2>&1; end"
                                    delegateThumbGenerator.command = ["fish", "-c", cmd]
                                    delegateThumbGenerator.running = true
                                }
                            }

                            Item {
                                anchors.fill: parent
                                anchors.margins: 4

                                ClippingRectangle {
                                    id: imageHolder
                                    anchors.fill: parent
                                    radius: Config.cornerRadius / 2
                                    color: Qt.rgba(255, 255, 255, 0.05)

                                    Image {
                                        id: thumbImage
                                        anchors.fill: parent
                                        source: isVideo ? "" : filePath
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: 400
                                        sourceSize.height: 225
                                        asynchronous: true
                                        cache: true
                                    }

                                    // Subtle Vignette Gradient
                                    Rectangle {
                                        anchors.fill: parent
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.45) }
                                        }
                                    }

                                    // Video Play Icon Badge
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: Qt.rgba(0, 0, 0, 0.7)
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.margins: 6
                                        visible: isVideo

                                        Text {
                                            anchors.centerIn: parent
                                            text: "play_arrow"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 13
                                            color: "#FFFFFF"
                                        }
                                    }

                                    // Selected Active Checkmark Badge
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: Config.accent
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 6
                                        visible: isCurrent

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✓"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: Config.bgBase
                                        }
                                    }
                                }

                                // Glowing active border
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Config.cornerRadius / 2
                                    color: "transparent"
                                    border.width: isCurrent ? 2.5 : (cardHover.hovered ? 1.5 : 0)
                                    border.color: Config.accent

                                    Behavior on border.width { NumberAnimation { duration: 120 } }
                                }

                                TapHandler {
                                    onTapped: wallpaperBackend.applyWallpaper(filePath)
                                }
                                HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true; implicitHeight: 20 }
    }
}