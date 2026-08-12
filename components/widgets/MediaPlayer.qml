import QtQuick
import QtQuick.Layouts
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
        spacing: 12

        // HEADER
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "MEDIA PLAYER"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontSubhead)
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            // STACKED VERTICAL ANCHOR ARROWS
            ColumnLayout {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                // UP ARROW
                Rectangle {
                    implicitWidth: 20; implicitHeight: 20; radius: 10
                    color: upHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "keyboard_arrow_up"
                        color: (Config.playerAnchorPos === "top") 
                            ? Config.accent 
                            : (upHover.hovered ? Config.textMain : Config.textMuted)
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 20
                    }

                    TapHandler { onTapped: Config.cyclePlayerAnchor("up") }
                    HoverHandler { id: upHover; cursorShape: Qt.PointingHandCursor }
                }

                // DOWN ARROW
                Rectangle {
                    implicitWidth: 20; implicitHeight: 20; radius: 10
                    color: downHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "keyboard_arrow_down"
                        color: (Config.playerAnchorPos === "bottom") 
                            ? Config.accent 
                            : (downHover.hovered ? Config.textMain : Config.textMuted)
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 20
                    }

                    TapHandler { onTapped: Config.cyclePlayerAnchor("down") }
                    HoverHandler { id: downHover; cursorShape: Qt.PointingHandCursor }
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
                }
            }

            TapHandler { onTapped: sourceDropdownBar.expanded = !sourceDropdownBar.expanded }
            HoverHandler { id: dropHover; cursorShape: Qt.PointingHandCursor }
        }

        // DROPDOWN MENU LIST
        ColumnLayout {
            visible: sourceDropdownBar.expanded && Config.savedUrls && Config.savedUrls.length > 0
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: Config.savedUrls

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    
                    property string itemUrl: typeof modelData === 'string' ? modelData : modelData.url
                    property string itemTitle: typeof modelData === 'string' ? modelData : modelData.title
                    
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: Config.cornerRadius / 2
                    color: (Config.activeChannelName === itemUrl) ? Qt.rgba(255, 255, 255, 0.15) : (itemHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2))

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
                            color: deleteBtnHover.hovered ? Qt.rgba(239, 68, 68, 0.3) : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "close"
                                color: deleteBtnHover.hovered ? "#ef4444" : Config.textMuted
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
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

        // MEDIA DISPLAY CANVAS
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Config.playerExpanded ? 440 : 220
            radius: Config.cornerRadius / 2
            color: Qt.rgba(0, 0, 0, 0.35)
            clip: true

            Behavior on implicitHeight {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
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
                fillMode: Config.playerKeepAspect ? VideoOutput.PreserveAspectCrop : VideoOutput.Stretch
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

            // CONTROLS OVERLAY
            ColumnLayout {
                anchors.bottom: parent.bottom
                anchors.left: parent.left; anchors.right: parent.right
                anchors.margins: 12
                spacing: 8
                visible: Config.inlinePlayer.playbackState !== MediaPlayer.StoppedState || Config.isConnecting

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
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Qt.rgba(255, 255, 255, 0.2)

                        Rectangle {
                            width: Config.inlinePlayer.duration > 0 ? (Config.inlinePlayer.position / Config.inlinePlayer.duration) * parent.width : 0
                            height: parent.height
                            radius: 3
                            color: Config.accent
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
                        opacity: (Config.embeddedStreamUrl !== "" && Config.currentPlaylist.length > 0 && Config.activePlaylistIndex > 0) ? 1.0 : 0.4

                        TapHandler { onTapped: Config.prevTrack() }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }

                    Text {
                        text: Config.inlinePlayer.playbackState === MediaPlayer.PlayingState ? "pause_circle" : "play_circle"
                        color: Config.accent
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 32
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
                        opacity: (Config.embeddedStreamUrl !== "" && Config.currentPlaylist.length > 0 && Config.activePlaylistIndex < Config.currentPlaylist.length - 1) ? 1.0 : 0.4

                        TapHandler { onTapped: Config.nextTrack() }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }

                    Text {
                        text: "stop_circle"
                        color: "#ef4444"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 32
                        opacity: (Config.embeddedStreamUrl !== "" || Config.isLoadingStream) ? 1.0 : 0.4

                        TapHandler { onTapped: Config.stopStream() }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }
}