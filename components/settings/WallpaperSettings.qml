import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import ".."

Flickable {
    id: root
    contentHeight: contentColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    readonly property var awwwTransitions: [
        "fade", "wipe", "wave", "grow", 
        "center", "outer", "left", "right", 
        "top", "bottom", "simple", "random"
    ]

    property string currentWallpaperPath: ""

    Process {
        id: wallpaperBackend
        running: false

        property string pendingIrisPath: ""

        // Inline Comment: Defer applyIrisColors until fish script finishes generating palette
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && Config.enableIris && pendingIrisPath !== "") {
                Config.applyIrisColors(pendingIrisPath);
                pendingIrisPath = "";
            }
        }

        function applyWallpaper(filePath) {
            if (!filePath || filePath === "") return;

            let cleanFilePath = filePath.replace(/^file:\/\//, "");
            root.currentWallpaperPath = cleanFilePath;
            Config.activeWallpaperPath = cleanFilePath;

            let ext = cleanFilePath.split('.').pop().toLowerCase();
            let waylandDisplay = Quickshell.env("WAYLAND_DISPLAY") || "wayland-1";
            let sockPath = "/run/user/" + Quickshell.env("UID") + "/" + waylandDisplay + "-awww-daemon.sock";
            let targets = Config.selectedWallpaperMonitors || [];
            let transition = Config.wallpaperTransitionType || "fade";

            let script = "killall -q mpvpaper 2>/dev/null; ";

            if (targets.length > 0) {
                for (let i = 0; i < targets.length; i++) {
                    let mon = targets[i];
                    if (ext === "mp4" || ext === "webm") {
                        // Inline Comment: Pass panscan=1.0 and video-unscaled=no for ultrawide video cropping
                        script += "awww clear -o \"" + mon + "\" 2>/dev/null; ";
                        script += "pkill -f 'mpvpaper' 2>/dev/null; ";
                        script += "nohup mpvpaper -vs -o 'loop-file=inf no-audio panscan=1.0 video-unscaled=no' \"" + mon + "\" '" + cleanFilePath + "' >/dev/null 2>&1 & disown; ";
                    } else {
                        script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; ";
                        script += "awww img -o \"" + mon + "\" '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; ";
                    }
                }
            } else {
                if (ext === "mp4" || ext === "webm") {
                    script += "awww kill 2>/dev/null; killall -9 -q awww-daemon 2>/dev/null; rm -f " + sockPath + "; ";
                    script += "nohup mpvpaper -vs -o 'loop-file=inf no-audio panscan=1.0 video-unscaled=no' '*' '" + cleanFilePath + "' >/dev/null 2>&1 & disown; ";
                } else {
                    script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; ";
                    script += "awww img '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; ";
                }
            }

            // Inline Comment: Ensure keyframe image exists for iris palette extraction
            if (Config.enableIris) {
                if (ext === "mp4" || ext === "webm") {
                    let fileName = cleanFilePath.split('/').pop();
                    let thumbName = fileName.replace(/[^a-zA-Z0-9]/g, "_") + ".png";
                    let thumbPath = Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + thumbName;
                    
                    pendingIrisPath = thumbPath;
                    script += "test -f '" + thumbPath + "'; or ffmpeg -y -ss 00:00:00 -i '" + cleanFilePath + "' -vframes 1 -vf 'scale=600:-1' '" + thumbPath + "' >/dev/null 2>&1; ";
                    script += "iris '" + thumbPath + "'; ";
                } else {
                    pendingIrisPath = cleanFilePath;
                    script += "iris '" + cleanFilePath + "'; ";
                }
            }

            command = ["fish", "-c", script];
            running = false;
            running = true;
        }
    }

    ColumnLayout {
        id: contentColumn
        width: parent.width
        spacing: 16

        // --- HEADER SECTION WITH RANDOMIZER CONTROLS ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "WALLPAPER SETTINGS"
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
            }

            // Spacer
            Item { Layout.fillWidth: true }

            // Slideshow ASCII Checkbox and Controls
            RowLayout {
                spacing: 8
                visible: folderModel.count > 0

                RowLayout {
                    spacing: 4
                    Text {
                        text: Config.slideshowActive ? "[x]" : "[ ]"
                        color: Config.slideshowActive ? Config.accent : Config.textMuted
                        font.family: "monospace"
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                        
                        TapHandler {
                            onTapped: Config.slideshowActive = !Config.slideshowActive
                        }
                    }
                    Text {
                        text: "Random"
                        color: Config.slideshowActive ? Config.textMain : Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }
                }

                RowLayout {
                    spacing: 4
                    opacity: Config.slideshowActive ? 1.0 : 0.4
                    
                    Text {
                        text: "[-]"
                        color: Config.textMuted
                        font.family: "monospace"
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                        TapHandler {
                            onTapped: if (Config.slideshowMinutes > 1) Config.slideshowMinutes--
                        }
                    }
                    Text {
                        text: Config.slideshowMinutes + "m"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                        Layout.preferredWidth: 24
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        text: "[+]"
                        color: Config.textMuted
                        font.family: "monospace"
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                        TapHandler {
                            onTapped: Config.slideshowMinutes++
                        }
                    }
                }
            }
        }

        // --- SECTION 1: TARGET OUTPUTS ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Target Outputs"
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: Quickshell.screens

                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: 90
                        implicitHeight: 32
                        radius: Config.cornerRadius / 2

                        readonly property bool isSelected: Config.selectedWallpaperMonitors && Config.selectedWallpaperMonitors.includes(modelData.name)
                        color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (monHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                        border.width: isSelected ? 2 : 0
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

                        TapHandler { onTapped: Config.toggleWallpaperMonitor(modelData.name) }
                        HoverHandler { id: monHover; cursorShape: Qt.PointingHandCursor }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        // --- SECTION 2: TRANSITION SELECTOR ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Transition Type"
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.bold: true
            }

            GridLayout {
                columns: 4
                rowSpacing: 6
                columnSpacing: 6
                Layout.fillWidth: true

                Repeater {
                    model: root.awwwTransitions

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: Config.cornerRadius / 2
                        readonly property bool isSelected: Config.wallpaperTransitionType === modelData
                        color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (transHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                        border.width: isSelected ? 2 : 0
                        border.color: Config.accent

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: isSelected ? Config.accent : Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: isSelected
                        }

                        TapHandler { onTapped: Config.wallpaperTransitionType = modelData }
                        HoverHandler { id: transHover; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }

        // --- SECTION 3: FULL-WIDTH WALLPAPER LIBRARY GRID ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Wallpaper Library"
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontMicro)
                font.bold: true
            }

            GridView {
                id: gridView
                Layout.fillWidth: true
                implicitHeight: Math.max(220, contentHeight)

                readonly property int columns: 4
                cellWidth: width / columns
                cellHeight: Math.floor(cellWidth * (9 / 16))

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

                    readonly property string cleanPath: filePath.replace(/^file:\/\//, "")
                    readonly property bool isCurrent: root.currentWallpaperPath === cleanPath || root.currentWallpaperPath === filePath
                    readonly property bool isVideo: {
                        let ext = fileSuffix.toLowerCase();
                        return ext === "mp4" || ext === "webm";
                    }

                    readonly property string thumbName: fileName.replace(/\./g, "_") + ".jpg"
                    readonly property string thumbPath: Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + thumbName
                    readonly property string thumbUrl: "file://" + thumbPath

                    // Inline Comment: Handle thumbnail reload on process exit to avoid initial load warnings
                    Process {
                        id: delegateThumbGenerator
                        running: false

                        onExited: (exitCode, exitStatus) => {
                            if (exitCode === 0) {
                                let path = delegateItem.thumbUrl;
                                thumbImage.source = "";
                                thumbImage.source = path;
                            }
                        }
                    }

                    Component.onCompleted: {
                        let cmd = "if not test -f '" + thumbPath + "'; ffmpeg -y -i '" + filePath + "' -vf 'scale=300:-1' '" + thumbPath + "' >/dev/null 2>&1; end";
                        delegateThumbGenerator.command = ["fish", "-c", cmd];
                        delegateThumbGenerator.running = true;
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 3

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: Config.cornerRadius / 2
                            color: Qt.rgba(255, 255, 255, 0.05)

                            Image {
                                id: thumbImage
                                anchors.fill: parent
                                source: thumbUrl
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 320
                                sourceSize.height: 180
                                asynchronous: true
                                cache: true
                            }
                        }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: Qt.rgba(0, 0, 0, 0.65)
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 6
                            visible: isVideo
                            z: 5

                            Text {
                                anchors.centerIn: parent
                                text: "▶"
                                color: Config.textMain
                                font.pixelSize: 8
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Config.cornerRadius / 2
                            color: "transparent"
                            border.width: isCurrent ? 3 : (cardHover.hovered ? 2 : 0)
                            border.color: Config.accent
                            z: 10

                            Behavior on border.width { NumberAnimation { duration: 150 } }
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