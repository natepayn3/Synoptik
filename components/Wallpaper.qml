import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Item {
    id: root

    readonly property real screenWidth: Screen.width
    readonly property real screenHeight: Screen.height

    // Dynamic wide layout profile
    implicitWidth: Math.min(1440, Math.max(960, Math.round(screenWidth * 0.72)))
    implicitHeight: Math.min(480, Math.max(340, Math.round(screenHeight * 0.38)))

    property int activeIndex: 0
    property string activeHoveredPath: ""

    // Helper to compute unified thumbnail path without extension mangling
    function getThumbPath(filePath) {
        if (!filePath) return ""
        let clean = (typeof filePath === "string" ? filePath : filePath.toString()).replace(/^file:\/\//, "")
        let fileName = clean.split('/').pop()
        let baseName = fileName.replace(/\.[^/.]+$/, "")
        return Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + baseName + ".jpg"
    }

    // Resolves either image source or generated video thumbnail
    function resolveImageSource(rawPath) {
        if (!rawPath) return ""
        let clean = (typeof rawPath === "string" ? rawPath : rawPath.toString()).replace(/^file:\/\//, "")
        let ext = clean.split('.').pop().toLowerCase()
        if (ext === "mp4" || ext === "webm") {
            return "file://" + getThumbPath(clean)
        }
        return "file://" + clean
    }

    // Background thumbnail batch generator in Fish
    Process {
        id: thumbBatchProc
        command: [
            "fish", "-c",
            "set -l cache_dir $HOME/.cache/wallpaper-thumbs; " +
            "test -d $cache_dir; or mkdir -p $cache_dir; " +
            "for f in ~/Pictures/Wallpapers/*.{mp4,webm}; " +
            "    test -f $f; or continue; " +
            "    set -l base_name (string replace -r '\\.[^.]+$' '' (path basename $f)); " +
            "    set -l thumb_path \"$cache_dir/$base_name.jpg\"; " +
            "    if not test -f $thumb_path; " +
            "        ffmpeg -y -ss 00:00:01 -i $f -vframes 1 -vf 'scale=720:-1' $thumb_path >/dev/null 2>&1; " +
            "    end; " +
            "end"
        ]
        running: true

        onExited: {
            // Re-evaluate backdrop source once thumbnails finish generating
            ambientBackdrop.source = Qt.binding(() => {
                if (root.activeHoveredPath !== "") return root.resolveImageSource(root.activeHoveredPath)
                if (folderModel.count > root.activeIndex && root.activeIndex >= 0) {
                    return root.resolveImageSource(folderModel.get(root.activeIndex, "filePath"))
                }
                return root.resolveImageSource(Config.activeWallpaperPath)
            })
        }
    }

    // Backend Execution Process
    Process {
        id: wallpaperBackend
        running: false
        property string pendingIrisPath: ""

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                if (Config.enableIris && pendingIrisPath !== "") {
                    Config.applyIrisColors(pendingIrisPath)
                    pendingIrisPath = ""
                }
                if (Config.refreshActiveWallpapers) {
                    Config.refreshActiveWallpapers()
                }
            }
        }

        function triggerBackendRun(filePath, activeOnly) {
            if (!filePath) return

            let cleanFilePath = (typeof filePath === "string" ? filePath : filePath.toString()).replace(/^file:\/\//, "")
            Config.activeWallpaperPath = cleanFilePath

            let ext = cleanFilePath.split('.').pop().toLowerCase()
            let isVid = (ext === "mp4" || ext === "webm")
            let waylandDisplay = Quickshell.env("WAYLAND_DISPLAY") || "wayland-1"
            let sockPath = "/run/user/" + Quickshell.env("UID") + "/" + waylandDisplay + "-awww-daemon.sock"
            let transition = Config.wallpaperTransitionType || "fade"

            let script = "killall -q mpvpaper 2>/dev/null; "

            if (activeOnly) {
                // Focus monitor targeted run
                script += "set TARGET_MON (hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'); "
                if (isVid) {
                    script += "awww clear -o \"$TARGET_MON\" 2>/dev/null; "
                    script += "pkill -f 'mpvpaper' 2>/dev/null; "
                    script += "nohup mpvpaper -vs -o 'input-terminal=no loop-file=inf no-audio panscan=1.0 video-unscaled=no' \"$TARGET_MON\" '" + cleanFilePath + "' < /dev/null >/dev/null 2>&1 & disown; "
                } else {
                    script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; "
                    script += "awww img -o \"$TARGET_MON\" '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; "
                }
            } else {
                // All monitors run
                if (isVid) {
                    script += "awww kill 2>/dev/null; killall -9 -q awww-daemon 2>/dev/null; rm -f " + sockPath + "; "
                    script += "nohup mpvpaper -vs -o 'input-terminal=no loop-file=inf no-audio panscan=1.0 video-unscaled=no' '*' '" + cleanFilePath + "' < /dev/null >/dev/null 2>&1 & disown; "
                } else {
                    script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; "
                    for (let i = 0; i < Quickshell.screens.length; i++) {
                        let monName = Quickshell.screens[i].name
                        script += "awww img -o \"" + monName + "\" '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; "
                    }
                }
            }

            if (Config.enableIris) {
                if (isVid) {
                    let thumbPath = root.getThumbPath(cleanFilePath)
                    pendingIrisPath = thumbPath
                    script += "test -f '" + thumbPath + "'; or ffmpeg -y -ss 00:00:01 -i '" + cleanFilePath + "' -vframes 1 -vf 'scale=600:-1' '" + thumbPath + "' >/dev/null 2>&1; "
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
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.mp4", "*.webm"]
        showDirs: false
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
                if (folderModel.count > root.activeIndex && root.activeIndex >= 0) {
                    return root.resolveImageSource(folderModel.get(root.activeIndex, "filePath"))
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

                Text {
                    text: "WALLPAPERS"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size ? Config.size(Config.fontTitle) : 16
                    font.bold: true
                    font.italic: true
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
                        text: folderModel.count + " items"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: 10
                        font.bold: true
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
                        root.activeIndex = Math.min(folderModel.count - 1, root.activeIndex + 1)
                        bladeListView.positionViewAtIndex(root.activeIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        if (root.activeIndex >= 0 && folderModel.count > root.activeIndex) {
                            let activeOnly = (event.modifiers & Qt.ControlModifier) !== 0
                            let target = folderModel.get(root.activeIndex, "filePath")
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
                    model: folderModel
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

                        // Progressive accordion scaling falloff
                        readonly property int distFromActive: Math.abs(index - root.activeIndex)
                        readonly property real scaleFactor: Math.max(0.38, Math.pow(0.84, distFromActive))

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
                                    source: bladeDelegate.isVid ? ("file://" + bladeDelegate.thumbFile) : filePath
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                }

                                // Depth & distance dimming
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
                                    bladeContainer.forceActiveFocus()
                                    root.activeIndex = index
                                    let activeOnly = (mouse.modifiers & Qt.ControlModifier) !== 0
                                    wallpaperBackend.triggerBackendRun(filePath, activeOnly)
                                }
                                onWheel: (wheel) => {
                                    let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                                    if (delta > 0) {
                                        root.activeIndex = Math.max(0, root.activeIndex - 1)
                                    } else if (delta < 0) {
                                        root.activeIndex = Math.min(folderModel.count - 1, root.activeIndex + 1)
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