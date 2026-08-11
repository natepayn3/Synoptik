import QtQuick
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import ".."

Item {
    id: playerRoot

    implicitWidth: 420
    implicitHeight: mainColumn.implicitHeight + (Config.cardMargin * 2)

    // Hand video frame output to drawer view when visible
    Component.onCompleted: {
        Config.inlinePlayer.videoOutput = inlineVideo
    }

    // Reassign video frame output to background sink when closing to keep stream decoder warm
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
                text: "EMBEDDED MEDIA PLAYER"
                color: Config.textMain
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontSubhead)
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

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

        // SOURCE SELECTOR DROPDOWN BAR
        Rectangle {
            id: sourceDropdownBar
            Layout.fillWidth: true
            implicitHeight: 36
            radius: Config.cornerRadius / 2
            color: Qt.rgba(0, 0, 0, 0.3)
            border.width: 1
            border.color: dropHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.1)

            property bool expanded: false

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: "live_tv"
                    color: Config.accent
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 16
                }

                Text {
                    text: Config.selectedPlayerName !== "" ? Config.selectedPlayerName : "Select Stream Target..."
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
            visible: sourceDropdownBar.expanded
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [
                    { name: "Standby / Off", id: "", urlKey: "" },
                    { name: "Spotify", id: "Spotify", urlKey: "spotifyUrl" },
                    { name: "YouTube", id: "YouTube", urlKey: "youtubeUrl" },
                    { name: "YouTube Music", id: "YouTube Music", urlKey: "ytMusicUrl" },
                    { name: "Twitch", id: "Twitch", urlKey: "twitchUrl" }
                ]

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: Config.cornerRadius / 2
                    color: (Config.selectedPlayerName === modelData.id) ? Qt.rgba(255, 255, 255, 0.15) : (itemHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2))

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10

                        Text {
                            text: modelData.name
                            color: (Config.selectedPlayerName === modelData.id) ? Config.accent : Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: Config.selectedPlayerName === modelData.id
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            implicitWidth: 6; implicitHeight: 6; radius: 3
                            color: (modelData.urlKey !== "" && Config[modelData.urlKey] !== "") ? Config.accent : Qt.rgba(255, 255, 255, 0.2)
                            visible: modelData.urlKey !== ""
                        }
                    }

                    TapHandler {
                        onTapped: {
                            Config.selectedPlayerName = modelData.id
                            sourceDropdownBar.expanded = false

                            if (modelData.urlKey !== "") {
                                Config.loadStream(modelData.urlKey, modelData.name)
                            } else {
                                Config.stopStream()
                            }
                        }
                    }
                    HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
                }
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
            visible: Config.selectedPlayerName !== ""
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

                    text: {
                        let key = Config.getUrlKeyForSelected()
                        return (key !== "" && typeof Config[key] !== "undefined") ? Config[key] : ""
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Paste " + Config.selectedPlayerName + " URL..."
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        elide: Text.ElideRight
                        visible: inlineUrlInput.text === ""
                    }

                    onEditingFinished: {
                        let key = Config.getUrlKeyForSelected()
                        if (key !== "") {
                            Config[key] = inlineUrlInput.text.trim()
                            Config.loadStream(key, Config.selectedPlayerName)
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
                            let key = Config.getUrlKeyForSelected()
                            if (key !== "") {
                                Config[key] = inlineUrlInput.text.trim()
                                Config.loadStream(key, Config.selectedPlayerName)
                            }
                        }
                    }
                    HoverHandler { id: refreshBtnHover; cursorShape: Qt.PointingHandCursor }
                }
            }
        }

        // MEDIA DISPLAY CANVAS
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 220
            radius: Config.cornerRadius / 2
            color: Qt.rgba(0, 0, 0, 0.35)
            clip: true

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
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: {
                        if (Config.isConnecting) return (Config.isLoadingStream ? "Resolving Stream via yt-dlp..." : "Buffering Stream...")
                        if (Config.inlinePlayer.playbackState === MediaPlayer.PlayingState && !Config.inlinePlayer.hasVideo) return "Playing Audio Stream..."
                        let key = Config.getUrlKeyForSelected()
                        if (Config.selectedPlayerName !== "" && (!Config[key] || Config[key] === "")) return "No Stream URL Configured"
                        if (Config.selectedPlayerName !== "") return "Stream Disconnected / Off"
                        return "Select a Stream Source"
                    }
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }
            }

            // CONTROLS OVERLAY
            ColumnLayout {
                anchors.bottom: parent.bottom
                anchors.left: parent.left; anchors.right: parent.right
                anchors.margins: 12
                spacing: 4
                visible: Config.inlinePlayer.playbackState !== MediaPlayer.StoppedState || Config.isConnecting

                // PLAYBACK CONTROLS (PLAY/PAUSE & STOP)
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 24

                    // Play / Pause Button
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

                    // Stop Button
                    Text {
                        text: "stop_circle"
                        color: "#ef4444"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 32
                        opacity: (Config.embeddedStreamUrl !== "" || Config.isLoadingStream) ? 1.0 : 0.4

                        TapHandler {
                            onTapped: Config.stopStream()
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }
}