import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import Quickshell
import ".."

ColumnLayout {
    id: soundSettingsRoot
    spacing: Config.cardMargin

    readonly property var soundFiles: [
        "sound1.mp3", "sound2.mp3", "sound3.mp3",
        "sound4.mp3", "sound5.mp3", "sound6.mp3",
        "sound7.mp3", "sound8.mp3", "sound9.mp3"
    ]

    function formatSoundName(fileName) {
        // Inline Comment: Convert raw filename 'sound1.mp3' to display label 'Sound 1'
        let clean = fileName.replace(".mp3", "")
        return clean.charAt(0).toUpperCase() + clean.slice(1).replace(/(\d+)/, " $1")
    }

    AudioOutput {
        id: previewOutput
        volume: 1.0
    }

    MediaPlayer {
        id: previewPlayer
        audioOutput: previewOutput
    }

    function previewSound(fileName) {
        // Inline Comment: Clean URL format for QtMultimedia preview
        let baseDir = Quickshell.shellDir.toString()
        if (!baseDir.endsWith("/")) baseDir += "/"
        previewPlayer.source = baseDir + "assets/" + fileName
        previewPlayer.stop()
        previewPlayer.play()
    }

    Text {
        text: "SYSTEM SOUNDS"
        color: Config.textMain
        font.family: Config.sysFont
        font.pixelSize: Config.size(Config.fontSubhead)
        font.bold: true
    }

    Text {
        text: "Configure audio feedback and select custom sound assets for windows and desktop notifications."
        color: Config.textMuted
        font.family: Config.sysFont
        font.pixelSize: Config.size(Config.fontCaption)
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }

    // SELECTION CARD: WINDOW SOUNDS
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: windowCol.implicitHeight + 24
        color: Qt.rgba(0, 0, 0, 0.2)
        radius: Config.cornerRadius / 2
        border.width: 0
        opacity: Config.playWindowSounds ? 1.0 : 0.4

        ColumnLayout {
            id: windowCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                spacing: 8
                Layout.fillWidth: true

                // Checkbox container styled directly from ClockWidget design system
                Rectangle {
                    implicitWidth: 20
                    implicitHeight: 20
                    radius: Config.cornerRadius / 4
                    color: Config.playWindowSounds ? Config.accent : Config.bgPanel
                    border.width: Config.showBorders ? 2 : 1
                    border.color: Config.showBorders ? Config.accent : Qt.rgba(255, 255, 255, 0.15)

                    Text {
                        anchors.centerIn: parent
                        text: "check"
                        color: Config.playWindowSounds ? Config.bgBase : Config.textMuted
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 14
                        font.bold: true
                        visible: Config.playWindowSounds
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Config.isLoaded) {
                                Config.playWindowSounds = !Config.playWindowSounds
                            }
                        }
                    }
                }

                Text {
                    text: "web_asset"
                    color: Config.accent
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 18
                }

                Text {
                    text: "Windows & Panel Open Sound"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    font.bold: true
                    Layout.fillWidth: true
                }
            }

            GridLayout {
                columns: 3
                Layout.fillWidth: true
                columnSpacing: 6
                rowSpacing: 6
                enabled: Config.playWindowSounds

                Repeater {
                    model: soundSettingsRoot.soundFiles

                    delegate: Rectangle {
                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: Config.cornerRadius / 2

                        readonly property bool isSelected: Config.windowSoundPath === modelData
                        color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (btnHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")
                        border.width: isSelected ? (Config.showBorders ? 2 : 1) : 0
                        border.color: Config.accent

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 4

                            Text {
                                text: isSelected ? "radio_button_checked" : "radio_button_unchecked"
                                color: isSelected ? Config.accent : Config.textMuted
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                            }

                            Text {
                                text: soundSettingsRoot.formatSoundName(modelData)
                                color: isSelected ? Config.accent : Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: isSelected
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.windowSoundPath = modelData
                                soundSettingsRoot.previewSound(modelData)
                            }
                        }
                        HoverHandler { id: btnHover }
                    }
                }
            }
        }
    }

    // SELECTION CARD: NOTIFICATION SOUNDS
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: notifCol.implicitHeight + 24
        color: Qt.rgba(0, 0, 0, 0.2)
        radius: Config.cornerRadius / 2
        border.width: 0
        opacity: Config.playNotificationSounds ? 1.0 : 0.4

        ColumnLayout {
            id: notifCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                spacing: 8
                Layout.fillWidth: true

                // Checkbox container styled directly from ClockWidget design system
                Rectangle {
                    implicitWidth: 20
                    implicitHeight: 20
                    radius: Config.cornerRadius / 4
                    color: Config.playNotificationSounds ? Config.accent : Config.bgPanel
                    border.width: Config.showBorders ? 2 : 1
                    border.color: Config.showBorders ? Config.accent : Qt.rgba(255, 255, 255, 0.15)

                    Text {
                        anchors.centerIn: parent
                        text: "check"
                        color: Config.playNotificationSounds ? Config.bgBase : Config.textMuted
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 14
                        font.bold: true
                        visible: Config.playNotificationSounds
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Config.isLoaded) {
                                Config.playNotificationSounds = !Config.playNotificationSounds
                            }
                        }
                    }
                }

                Text {
                    text: "notifications"
                    color: Config.accent
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 18
                }

                Text {
                    text: "Notification Arrival Sound"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    font.bold: true
                    Layout.fillWidth: true
                }
            }

            GridLayout {
                columns: 3
                Layout.fillWidth: true
                columnSpacing: 6
                rowSpacing: 6
                enabled: Config.playNotificationSounds

                Repeater {
                    model: soundSettingsRoot.soundFiles

                    delegate: Rectangle {
                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: Config.cornerRadius / 2

                        readonly property bool isSelected: Config.notificationSoundPath === modelData
                        color: isSelected ? Qt.rgba(255, 255, 255, 0.12) : (btnHover2.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")
                        border.width: isSelected ? (Config.showBorders ? 2 : 1) : 0
                        border.color: Config.accent

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 4

                            Text {
                                text: isSelected ? "radio_button_checked" : "radio_button_unchecked"
                                color: isSelected ? Config.accent : Config.textMuted
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 14
                            }

                            Text {
                                text: soundSettingsRoot.formatSoundName(modelData)
                                color: isSelected ? Config.accent : Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: isSelected
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.notificationSoundPath = modelData
                                soundSettingsRoot.previewSound(modelData)
                            }
                        }
                        HoverHandler { id: btnHover2 }
                    }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }
}