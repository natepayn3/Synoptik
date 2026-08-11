import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Item {
    id: root

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    // Dynamic panel dimensions based on wallpaper count
    readonly property int minPanelWidth: 620
    readonly property int maxPanelWidth: 800
    
    // Height available for delegate cards
    readonly property int calcCardHeight: implicitHeight - (cardMargin * 4) - 40
    readonly property int activeCardWidth: Math.round(calcCardHeight * (16 / 9))
    
    // Dynamic Content Width Calculation
    readonly property int calculatedContentWidth: {
        let count = folderModel.count;
        if (count === 0) return minPanelWidth;
        let unexpandedWidth = (count - 1) * (80 + 8);
        let totalNeeded = unexpandedWidth + activeCardWidth + (cardMargin * 4);
        return Math.min(maxPanelWidth, Math.max(minPanelWidth, totalNeeded));
    }

    // Dynamic Height Calculation: 150px when empty, 320px when populated
    readonly property int calculatedContentHeight: folderModel.count === 0 ? 150 : 320

    implicitWidth: calculatedContentWidth
    implicitHeight: calculatedContentHeight

    Behavior on implicitWidth {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    Process {
        id: thumbDirCreator
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/wallpaper-thumbs"]
        running: true
    }

    Process {
        id: thumbGenerator
        running: false
    }

    Process {
        id: wallpaperBackend
        running: false

        function triggerBackendRun(filePath, activeOnly) {
            if (!filePath || filePath === "") return;

            let cleanFilePath = filePath.replace(/^file:\/\//, "");

            // Inline Comment: Assigning activeWallpaperPath notifies Config.qml to trigger applyIrisColors()
            Config.activeWallpaperPath = cleanFilePath;

            let ext = cleanFilePath.split('.').pop().toLowerCase();
            let waylandDisplay = Quickshell.env("WAYLAND_DISPLAY") || "wayland-1";
            let sockPath = "/run/user/" + Quickshell.env("UID") + "/" + waylandDisplay + "-awww-daemon.sock";
            let transition = Config.wallpaperTransitionType || "fade";
            
            let script = "killall -q mpvpaper; ";
            script += "set TARGET_MON (hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'); ";
            
            if (activeOnly) {
                if (ext === "mp4" || ext === "webm") {
                    script += "awww clear -o \"$TARGET_MON\" 2>/dev/null; pkill -f \"mpvpaper.*$TARGET_MON\"; mpvpaper -vs -o 'loop no-audio' \"$TARGET_MON\" '" + cleanFilePath + "' >/dev/null 2>&1 & disown; ";
                } else {
                    script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; ";
                    script += "awww img -o \"$TARGET_MON\" '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 16 --transition-duration 1; ";
                }
            } else {
                if (ext === "mp4" || ext === "webm") {
                    script += "awww kill 2>/dev/null; killall -9 -q awww-daemon; rm -f " + sockPath + "; mpvpaper -vs -o 'loop no-audio' '*' '" + cleanFilePath + "' >/dev/null 2>&1 & disown; ";
                } else {
                    script += "if not pgrep -x 'awww-daemon' > /dev/null; rm -f " + sockPath + "; nohup awww-daemon >/dev/null 2>&1 & disown; sleep 0.5; end; ";
                    script += "awww img '" + cleanFilePath + "' --transition-type " + transition + " --transition-step 64 --transition-duration 2; ";
                }
            }

            // Inline Comment: Execute CLI iris command directly in fish subshell
            if (Config.enableIris) {
                script += "iris '" + cleanFilePath + "'; ";
            }
            
            command = ["fish", "-c", script];
            running = false;
            running = true;
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: root.cardMargin
        spacing: 0

        Rectangle {
            id: outerCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.05)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.cardMargin
                spacing: folderModel.count === 0 ? 0 : root.cardMargin

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "WALLPAPERS"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontTitle)
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

                // ==========================================
                // ACCORDION CAROUSEL VIEW
                // ==========================================
                Rectangle {
                    id: accordionContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    radius: Config.cornerRadius / 1.5
                    clip: true
                    visible: folderModel.count > 0

                    property int hoveredIndex: -1

                    Timer {
                        id: debounceHoverTimer
                        interval: 80
                        repeat: false
                        property int targetIndex: -1
                        onTriggered: {
                            accordionContainer.hoveredIndex = targetIndex;
                        }
                    }

                    WheelHandler {
                        id: wheelHandler
                        target: accordionList
                        property real scrollSpeed: 1.2
                        onWheel: (event) => {
                            let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                            accordionList.flick(delta * 12 * scrollSpeed, 0);
                        }
                    }

                    ListView {
                        id: accordionList
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: 8
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        focus: true

                        model: FolderListModel {
                            id: folderModel
                            folder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"
                            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.mp4", "*.webm"]
                            showDirs: false
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < count) {
                                positionViewAtIndex(currentIndex, ListView.Contain);
                            }
                        }

                        Keys.onLeftPressed: decrementCurrentIndex()
                        Keys.onRightPressed: incrementCurrentIndex()
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_A) {
                                decrementCurrentIndex();
                            } else if (event.key === Qt.Key_D) {
                                incrementCurrentIndex();
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                if (currentIndex >= 0 && folderModel.count > currentIndex) {
                                    let activeOnly = (event.modifiers & Qt.ControlModifier) !== 0;
                                    let targetPath = folderModel.get(currentIndex, "filePath");
                                    wallpaperBackend.triggerBackendRun(targetPath, activeOnly);
                                }
                            }
                        }

                        delegate: Item {
                            id: delegateItem
                            
                            readonly property bool isSelected: ListView.isCurrentItem
                            readonly property bool isHovered: hoverHandler.hovered || accordionContainer.hoveredIndex === index
                            readonly property bool isAnyHovered: accordionContainer.hoveredIndex !== -1
                            readonly property string itemFilePath: filePath
                            
                            height: accordionList.height - 6
                            width: (isHovered || (isSelected && !isAnyHovered)) ? Math.round(height * (16 / 9)) : (isAnyHovered ? 60 : 80)

                            z: (isHovered || isSelected) ? 100 : (100 - index)

                            Behavior on width {
                                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                            }

                            readonly property bool isVideo: {
                                let ext = fileSuffix.toLowerCase();
                                return ext === "mp4" || ext === "webm";
                            }

                            readonly property string thumbName: isVideo ? (fileName.replace(/[^a-zA-Z0-9]/g, "_") + ".png") : ""
                            readonly property string thumbPath: isVideo ? (Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + thumbName) : ""
                            readonly property string thumbUrl: isVideo ? ("file://" + thumbPath) : ""

                            Component.onCompleted: {
                                if (isVideo) {
                                    let cmd = "if not test -f '" + thumbPath + "'; ffmpeg -y -ss 00:00:00 -i '" + filePath + "' -frames:v 1 -vf 'scale=600:-1' '" + thumbPath + "' >/dev/null 2>&1; end";
                                    thumbGenerator.command = ["fish", "-c", cmd];
                                    thumbGenerator.running = true;
                                }
                            }

                            Rectangle {
                                id: cardFrame
                                anchors.fill: parent
                                radius: Config.cornerRadius / 2
                                color: isHovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.04)
                                clip: true

                                Behavior on color { ColorAnimation { duration: 200 } }

                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: Config.cornerRadius / 2
                                    color: "transparent"

                                    Image {
                                        anchors.fill: parent
                                        source: isVideo ? delegateItem.thumbUrl : fileUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                    }

                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: Qt.rgba(0, 0, 0, 0.65)
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        visible: isVideo
                                        z: 11

                                        Text {
                                            anchors.centerIn: parent
                                            text: "▶"
                                            color: Config.textMain
                                            font.pixelSize: 11
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Config.cornerRadius / 2
                                    color: "transparent"
                                    border.width: (isHovered || isSelected) ? 3 : 0
                                    border.color: Config.accent
                                    z: 10

                                    Behavior on border.width { NumberAnimation { duration: 150 } }
                                }

                                TapHandler {
                                    id: ctrlTapHandler
                                    acceptedModifiers: Qt.ControlModifier
                                    onTapped: {
                                        accordionList.forceActiveFocus();
                                        accordionList.currentIndex = index;
                                        wallpaperBackend.triggerBackendRun(filePath, true);
                                    }
                                }

                                TapHandler {
                                    id: normalTapHandler
                                    acceptedModifiers: Qt.NoModifier
                                    onTapped: {
                                        accordionList.forceActiveFocus();
                                        accordionList.currentIndex = index;
                                        wallpaperBackend.triggerBackendRun(filePath, false);
                                    }
                                }

                                HoverHandler {
                                    id: hoverHandler
                                    cursorShape: Qt.PointingHandCursor
                                    onHoveredChanged: {
                                        if (hovered) {
                                            accordionList.forceActiveFocus();
                                            debounceHoverTimer.stop();
                                            accordionContainer.hoveredIndex = index;
                                            accordionList.currentIndex = index;
                                        } else if (accordionContainer.hoveredIndex === index) {
                                            debounceHoverTimer.targetIndex = -1;
                                            debounceHoverTimer.restart();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    text: "No images found in ~/Pictures/Wallpapers"
                    color: Config.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: true
                    verticalAlignment: Text.AlignVCenter
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    visible: folderModel.count === 0
                }
            }
        }
    }
}