import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import Quickshell
import ".."

Item {
    id: playerRoot

    implicitWidth: Config.playerExpanded ? 840 : 420
    implicitHeight: mainColumn.implicitHeight + (Config.cardMargin * 2)

    Behavior on implicitWidth {
        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
    }

    Component.onCompleted: {
        Config.inlinePlayer.videoOutput = inlineVideo
    }

    Component.onDestruction: {
        if (typeof persistentVideoSink !== "undefined") {
            Config.inlinePlayer.videoOutput = persistentVideoSink
        }
    }

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: Config.cardMargin
        spacing: Config.cardMargin / 2

        // OUTER CARD CONTAINER
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: cardLayout.implicitHeight + (Config.cardMargin * 2)
            color: Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius
            clip: true

            // GRAPHIC WATERMARK
            Item {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -15
                anchors.bottomMargin: -20
                implicitWidth: 150
                implicitHeight: 150

                Text {
                    anchors.centerIn: parent
                    text: Config.getIcon("player")
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 150
                    font.bold: true
                    color: Config.accent
                    opacity: 0.07
                    rotation: 15
                }
            }

            ColumnLayout {
                id: cardLayout
                anchors.fill: parent
                anchors.margins: Config.cardMargin
                spacing: 12

                // HEADER
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item {
                        implicitWidth: playerTitleText.implicitWidth
                        implicitHeight: playerTitleText.implicitHeight
                        Layout.fillWidth: true

                        Glow {
                            anchors.fill: playerTitleText
                            source: playerTitleText
                            radius: 8
                            samples: 16
                            color: Config.accent
                            spread: 0.2
                            transparentBorder: true
                            visible: Config.clockShowGlow
                        }

                        Text {
                            id: playerTitleText
                            anchors.fill: parent
                            text: "MEDIA PLAYER"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontTitle)
                            font.bold: true
                            font.italic: true
                            elide: Text.ElideRight
                        }
                    }

                    // DYNAMIC ORIENTATION ANCHOR ARROWS
                    GridLayout {
                        id: anchorControls
                        columns: isHorizontal ? 2 : 1
                        rows: isHorizontal ? 1 : 2
                        columnSpacing: 4
                        rowSpacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        readonly property bool isHorizontal: {
                            if (typeof Config.isHorizontal !== "undefined") return !!Config.isHorizontal;
                            if (typeof Config.barPosition !== "undefined") return Config.barPosition === "top" || Config.barPosition === "bottom";
                            if (typeof Config.isBarHorizontal !== "undefined") return !!Config.isBarHorizontal;
                            if (typeof Config.orientation !== "undefined") return Config.orientation === Qt.Horizontal || Config.orientation === "horizontal";
                            return Config.barPosition !== "left" && Config.barPosition !== "right";
                        }

                        // Inline Comment: Single pass-through call matching Mirror.qml
                        function cycleAnchor(direction) {
                            if (typeof Config.cyclePlayerAnchor === "function") {
                                Config.cyclePlayerAnchor(direction);
                            }
                        }

                        // LEFT / UP ARROW
                        Rectangle {
                            implicitWidth: 20; implicitHeight: 20; radius: 10
                            color: prevHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: anchorControls.isHorizontal ? "keyboard_arrow_left" : "keyboard_arrow_up"
                                color: (Config.playerAnchorPos === "top")
                                    ? Config.accent 
                                    : (prevHover.hovered ? Config.textMain : Config.textMuted)
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 20
                                font.bold: true
                            }

                            TapHandler { onTapped: anchorControls.cycleAnchor(anchorControls.isHorizontal ? "left" : "up") }
                            HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                        }

                        // RIGHT / DOWN ARROW
                        Rectangle {
                            implicitWidth: 20; implicitHeight: 20; radius: 10
                            color: nextHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: anchorControls.isHorizontal ? "keyboard_arrow_right" : "keyboard_arrow_down"
                                color: (Config.playerAnchorPos === "bottom")
                                    ? Config.accent 
                                    : (nextHover.hovered ? Config.textMain : Config.textMuted)
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 20
                                font.bold: true
                            }

                            TapHandler { onTapped: anchorControls.cycleAnchor(anchorControls.isHorizontal ? "right" : "down") }
                            HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }

                    // SIZE TOGGLE BUTTON (2X CANVAS)
                    Rectangle {
                        implicitWidth: 26; implicitHeight: 26; radius: 13
                        color: expandBtnHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: Config.playerExpanded ? "fit_screen" : "aspect_ratio"
                            color: Config.playerExpanded ? Config.accent : Config.textMuted
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            font.bold: true
                        }

                        TapHandler { onTapped: Config.playerExpanded = !Config.playerExpanded }
                        HoverHandler { id: expandBtnHover; cursorShape: Qt.PointingHandCursor }
                    }

                    // PIN PANEL BUTTON
                    Rectangle {
                        implicitWidth: 26; implicitHeight: 26; radius: 13
                        color: pinBtnHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "push_pin"
                            color: Config.playerPinned ? Config.accent : Config.textMuted
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            font.bold: true
                            rotation: Config.playerPinned ? 45 : 0

                            Behavior on rotation {
                                NumberAnimation { duration: 150 }
                            }
                        }

                        TapHandler { onTapped: Config.playerPinned = !Config.playerPinned }
                        HoverHandler { id: pinBtnHover; cursorShape: Qt.PointingHandCursor }
                    }

                    // CLOSE BUTTON
                    Rectangle {
                        implicitWidth: 26; implicitHeight: 26; radius: 13
                        color: closeBtnHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            color: Config.textMuted
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            font.bold: true
                        }

                        TapHandler { onTapped: Config.showPlayer = false }
                        HoverHandler { id: closeBtnHover; cursorShape: Qt.PointingHandCursor }
                    }
                }

                // INLINE URL SPECIFIER BAR
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Config.cornerRadius / 2
                    color: Qt.rgba(0, 0, 0, 0.25)
                    border.width: inlineUrlInput.activeFocus ? 1 : 0
                    border.color: Config.accent
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            text: "link"
                            color: Config.textMuted
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            font.bold: true
                        }

                        TextInput {
                            id: inlineUrlInput
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            selectByMouse: true
                            clip: true
                            text: Config.activeChannelName

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Paste Stream URL..."
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                elide: Text.ElideRight
                                visible: inlineUrlInput.text === ""
                            }

                            onEditingFinished: {
                                if (inlineUrlInput.text.trim() !== "") {
                                    Config.loadDirectStream(inlineUrlInput.text)
                                }
                            }

                            HoverHandler { cursorShape: Qt.IBeamCursor }
                        }

                        Rectangle {
                            implicitWidth: 24; implicitHeight: 24; radius: 12
                            color: refreshBtnHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

                            Text {
                                anchors.centerIn: parent
                                text: "play_arrow"
                                color: refreshBtnHover.hovered ? "#ffffff" : Config.textMuted
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            TapHandler {
                                onTapped: {
                                    if (inlineUrlInput.text.trim() !== "") {
                                        Config.loadDirectStream(inlineUrlInput.text)
                                    }
                                }
                            }
                            HoverHandler { id: refreshBtnHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }

                // SOURCE SELECTOR DROPDOWN BAR
                Rectangle {
                    id: sourceDropdownBar
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Config.cornerRadius / 2
                    color: Qt.rgba(0, 0, 0, 0.3)
                    border.width: 1
                    border.color: dropHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.1)
                    visible: Config.savedUrls && Config.savedUrls.length > 0
                    
                    z: 100

                    property bool expanded: false

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: "history"
                            color: Config.accent
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Text {
                            text: {
                                if (Config.activeStreamTitle !== "") return Config.activeStreamTitle
                                if (Config.activeChannelName !== "") return Config.activeChannelName
                                return "Saved Streams (" + (Config.savedUrls ? Config.savedUrls.length : 0) + ")"
                            }
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: sourceDropdownBar.expanded ? "expand_less" : "expand_more"
                            color: Config.textMuted
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }

                    TapHandler { onTapped: sourceDropdownBar.expanded = !sourceDropdownBar.expanded }
                    HoverHandler { id: dropHover; cursorShape: Qt.PointingHandCursor }

                    // DROPDOWN MENU OVERLAY
                    Rectangle {
                        visible: sourceDropdownBar.expanded && Config.savedUrls && Config.savedUrls.length > 0
                        anchors.top: sourceDropdownBar.bottom
                        anchors.topMargin: 4
                        anchors.left: parent.left
                        anchors.right: parent.right
                        
                        height: Math.min((Config.savedUrls.length * 36) + 4, 184)
                        
                        radius: Config.cornerRadius / 2
                        color: Config.bgPanel 
                        border.width: 1
                        border.color: Config.accent
                        clip: true

                        ScrollView {
                            id: dropScroll
                            anchors.fill: parent
                            contentHeight: scrollContent.implicitHeight
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            Column {
                                id: scrollContent
                                width: dropScroll.availableWidth 
                                spacing: 4
                                padding: 4

                                Repeater {
                                    model: Config.savedUrls

                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        
                                        property string itemUrl: typeof modelData === 'string' ? modelData : modelData.url
                                        property string itemTitle: typeof modelData === 'string' ? modelData : modelData.title
                                        
                                        width: scrollContent.width - 8
                                        implicitHeight: 32
                                        radius: Config.cornerRadius / 2
                                        color: (Config.activeChannelName === itemUrl) ? Qt.rgba(255, 255, 255, 0.15) : (itemHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent")

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10; anchors.rightMargin: 6

                                            Text {
                                                text: itemTitle
                                                color: (Config.activeChannelName === itemUrl) ? Config.accent : Config.textMain
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontCaption)
                                                font.bold: Config.activeChannelName === itemUrl
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight

                                                TapHandler {
                                                    onTapped: {
                                                        sourceDropdownBar.expanded = false
                                                        Config.loadDirectStream(itemUrl)
                                                    }
                                                }
                                                HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
                                            }

                                            Rectangle {
                                                implicitWidth: 24; implicitHeight: 24; radius: 12
                                                color: deleteBtnHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "close"
                                                    color: deleteBtnHover.hovered ? Config.accent : Config.textMuted
                                                    font.family: "Material Symbols Outlined"
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                }

                                                TapHandler {
                                                    onTapped: Config.removeSavedUrl(index)
                                                }
                                                HoverHandler { id: deleteBtnHover; cursorShape: Qt.PointingHandCursor }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // MEDIA DISPLAY CANVAS
                Item {
                    id: mediaCanvas
                    Layout.fillWidth: true
                    implicitHeight: Config.playerExpanded ? 440 : 220
                    clip: true
                    
                    z: 1

                    Behavior on implicitHeight {
                        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                    }

                    // HOVER DETECTOR FOR CANVAS OVERLAYS
                    HoverHandler {
                        id: canvasHover
                    }

                    // ALBUM ART BACKGROUND
                    Image {
                        anchors.fill: parent
                        source: Config.activeStreamThumbnail
                        fillMode: Image.PreserveAspectCrop
                        visible: !inlineVideo.visible && Config.activeStreamThumbnail !== ""
                        opacity: 0.35
                    }

                    VideoOutput {
                        id: inlineVideo
                        anchors.fill: parent
                        fillMode: Config.playerKeepAspect ? VideoOutput.PreserveAspectFit : VideoOutput.Stretch
                        visible: Config.inlinePlayer.playbackState === MediaPlayer.PlayingState && Config.inlinePlayer.hasVideo
                    }

                    // IDLE / LOADING / AUDIO-ONLY PLACEHOLDER
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        visible: Config.isConnecting || !inlineVideo.visible
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Config.isConnecting ? "sync" : (Config.inlinePlayer.playbackState === MediaPlayer.PlayingState ? "graphic_eq" : "tv_off")
                            color: Config.accent
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 42
                            font.bold: true
                            visible: Config.activeStreamThumbnail === "" || Config.isConnecting
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: {
                                if (Config.isConnecting) return (Config.isLoadingStream ? "Resolving Stream via yt-dlp..." : "Buffering Stream...")
                                if (Config.inlinePlayer.playbackState === MediaPlayer.PlayingState && !Config.inlinePlayer.hasVideo) {
                                    if (Config.currentPlaylist && Config.currentPlaylist.length > 0) {
                                        let track = Config.currentPlaylist[Config.activePlaylistIndex]
                                        return (Config.activePlaylistIndex + 1) + "/" + Config.currentPlaylist.length + " • " + track.title
                                    }
                                    return Config.activeStreamTitle !== "" ? Config.activeStreamTitle : "Playing Audio Stream..."
                                }
                                if (Config.activeChannelName !== "") return "Stream Disconnected / Off"
                                return "Enter or Select a Stream URL"
                            }
                            color: Config.activeStreamThumbnail !== "" ? "#ffffff" : Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: Config.activeStreamThumbnail !== ""
                        }
                    }

                    // VERTICAL RIGHT-SIDE VOLUME OVERLAY
                    ColumnLayout {
                        id: volumeOverlay
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 12
                        spacing: 8
                        z: 10
                        visible: (Config.inlinePlayer.playbackState !== MediaPlayer.StoppedState || Config.isConnecting) && canvasHover.hovered

                        property var audio: Config.inlinePlayer.audioOutput

                        // VOLUME PERCENTAGE READOUT (TOP)
                        Text {
                            text: volumeOverlay.audio ? Math.round((volumeOverlay.audio.muted ? 0 : volumeOverlay.audio.volume) * 100) + "%" : "100%"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // VERTICAL VOLUME SLIDER TRACK CONTAINER (MIDDLE)
                        Item {
                            Layout.fillHeight: true
                            implicitWidth: 20
                            Layout.alignment: Qt.AlignHCenter

                            Rectangle {
                                id: volumeTrack
                                anchors.centerIn: parent
                                width: 6
                                height: parent.height
                                radius: 3
                                color: Qt.rgba(0, 0, 0, 0.4)

                                // ACTIVE VOLUME FILL BAR
                                Rectangle {
                                    id: volumeFill
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: (volumeOverlay.audio && !volumeOverlay.audio.muted) ? volumeOverlay.audio.volume * parent.height : 0
                                    radius: 3
                                    color: Config.accent
                                }

                                // THICK HORIZONTAL LINE SLIDER KNOB
                                Rectangle {
                                    id: volumeKnob
                                    width: 16
                                    height: 8
                                    radius: height / 2
                                    color: "#ffffff"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: Math.max(0, Math.min(volumeTrack.height - height, (volumeTrack.height - volumeFill.height) - (height / 2)))
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                function updateVolume(mouseY) {
                                    if (volumeOverlay.audio) {
                                        let trackH = volumeTrack.height
                                        let clampedY = Math.max(0, Math.min(trackH, mouseY))
                                        let vol = Math.max(0, Math.min(1, (trackH - clampedY) / trackH))
                                        volumeOverlay.audio.volume = vol
                                        if (vol > 0) volumeOverlay.audio.muted = false
                                    }
                                }

                                onPressed: (mouse) => updateVolume(mouse.y)
                                onPositionChanged: (mouse) => { if (pressed) updateVolume(mouse.y) }
                            }
                        }

                        // INTERACTIVE MUTE ICON (BOTTOM)
                        Rectangle {
                            implicitWidth: 28; implicitHeight: 28; radius: 14
                            color: muteHover.hovered ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(0, 0, 0, 0.35)

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (!volumeOverlay.audio || volumeOverlay.audio.muted || volumeOverlay.audio.volume === 0) return "volume_off"
                                    if (volumeOverlay.audio.volume < 0.5) return "volume_down"
                                    return "volume_up"
                                }
                                color: Config.accent
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 18
                                font.bold: true
                            }

                            TapHandler {
                                onTapped: {
                                    if (volumeOverlay.audio) {
                                        volumeOverlay.audio.muted = !volumeOverlay.audio.muted
                                    }
                                }
                            }
                            HoverHandler { id: muteHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }

                    // BOTTOM CONTROLS OVERLAY
                    ColumnLayout {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.rightMargin: 48 
                        anchors.leftMargin: 12; anchors.bottomMargin: 12
                        spacing: 8
                        visible: (Config.inlinePlayer.playbackState !== MediaPlayer.StoppedState || Config.isConnecting) && canvasHover.hovered

                        // TRACK PROGRESS BAR
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: Config.inlinePlayer.duration > 0 && !Config.isConnecting

                            function formatTime(ms) {
                                if (ms <= 0) return "0:00"
                                let totalSeconds = Math.floor(ms / 1000)
                                let minutes = Math.floor(totalSeconds / 60)
                                let seconds = totalSeconds % 60
                                return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
                            }

                            Text {
                                text: parent.formatTime(Config.inlinePlayer.position)
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                            }

                            Rectangle {
                                id: progressTrack
                                Layout.fillWidth: true
                                implicitHeight: 6
                                radius: 3
                                color: Qt.rgba(255, 255, 255, 0.2)

                                Rectangle {
                                    id: progressFill
                                    width: Config.inlinePlayer.duration > 0 ? (Config.inlinePlayer.position / Config.inlinePlayer.duration) * parent.width : 0
                                    height: parent.height
                                    radius: 3
                                    color: Config.accent
                                }

                                // THICK VERTICAL LINE SLIDER KNOB
                                Rectangle {
                                    id: progressKnob
                                    width: 8
                                    height: 16
                                    radius: height / 2
                                    color: "#ffffff"
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.max(0, Math.min(progressTrack.width - width, progressFill.width - (width / 2)))
                                    visible: Config.inlinePlayer.duration > 0
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onPositionChanged: (mouse) => {
                                        if (pressed && Config.inlinePlayer.seekable) {
                                            let ratio = Math.max(0, Math.min(1, mouse.x / width))
                                            Config.inlinePlayer.position = ratio * Config.inlinePlayer.duration
                                        }
                                    }
                                    onClicked: (mouse) => {
                                        if (Config.inlinePlayer.seekable) {
                                            let ratio = Math.max(0, Math.min(1, mouse.x / width))
                                            Config.inlinePlayer.position = ratio * Config.inlinePlayer.duration
                                        }
                                    }
                                }
                            }

                            Text {
                                text: parent.formatTime(Config.inlinePlayer.duration)
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontMicro)
                            }
                        }

                        // PLAYBACK CONTROLS
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 20

                            Text {
                                text: "skip_previous"
                                color: Config.accent
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 32
                                font.bold: true
                                opacity: (Config.embeddedStreamUrl !== "" && Config.currentPlaylist.length > 0 && Config.activePlaylistIndex > 0) ? 1.0 : 0.4

                                TapHandler { onTapped: Config.prevTrack() }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                            }

                            Text {
                                text: Config.inlinePlayer.playbackState === MediaPlayer.PlayingState ? "pause_circle" : "play_circle"
                                color: Config.accent
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 32
                                font.bold: true
                                opacity: Config.embeddedStreamUrl !== "" ? 1.0 : 0.4

                                TapHandler {
                                    onTapped: {
                                        if (Config.embeddedStreamUrl === "") return
                                        if (Config.inlinePlayer.playbackState === MediaPlayer.PlayingState) {
                                            Config.inlinePlayer.pause()
                                        } else {
                                            Config.inlinePlayer.play()
                                        }
                                    }
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                            }

                            Text {
                                text: "skip_next"
                                color: Config.accent
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 32
                                font.bold: true
                                opacity: (Config.embeddedStreamUrl !== "" && Config.currentPlaylist.length > 0 && Config.activePlaylistIndex < Config.currentPlaylist.length - 1) ? 1.0 : 0.4

                                TapHandler { onTapped: Config.nextTrack() }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                            }

                            Text {
                                text: "stop_circle"
                                color: Config.accent
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 32
                                font.bold: true
                                opacity: (Config.embeddedStreamUrl !== "" || Config.isLoadingStream) ? 1.0 : 0.4

                                TapHandler { onTapped: Config.stopStream() }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }
            }
        }
    }
}