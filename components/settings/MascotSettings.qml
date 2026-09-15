import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import ".."

Item {
    id: root

    function formatFileUrl(path) {
        if (!path) return ""
        if (path.startsWith("file://")) return path
        if (path.startsWith("/")) return "file://" + path
        return "file://" + Quickshell.env("HOME") + "/" + path
    }

    // --- STANDARD MASCOT SETTINGS VIEW ---
    // A compact header row (avatar + toggles) rather than a two-column
    // layout with a tall side panel - there are only two toggles now that
    // the quote/phrase feature is gone, and stretching a fixed-size avatar
    // image across a full-height sidebar next to that short a control list
    // just leaves empty space either way.
    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        Text {
            text: "MASCOT CONFIGURATION"
            color: Config.textMain
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontSubhead)
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            // AVATAR THUMBNAIL
            Rectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
                Layout.alignment: Qt.AlignTop
                color: Qt.rgba(0, 0, 0, 0.2)
                radius: Config.cornerRadius
                border.color: Qt.rgba(255, 255, 255, 0.1)
                border.width: 1
                clip: true

                Image {
                    id: avatarImage
                    anchors.fill: parent
                    anchors.margins: 8
                    fillMode: Image.PreserveAspectFit
                    source: root.formatFileUrl(Config.builtinMascotDir + "/avatar.png")
                    visible: avatarImage.status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: avatarImage.status !== Image.Ready
                    text: "hide_image"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 28
                    color: Config.textMuted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 12

                // TOGGLE: ENABLE DESKTOP MASCOT
                SettingsToggleRow {
                    title: "Enable Desktop Mascot"
                    subtitle: "Show the animated mascot on your desktop"
                    checked: Config.showMascot !== false
                    onToggled: {
                        Config.showMascot = (Config.showMascot === false)
                        if (typeof Config.saveConfig === "function") Config.saveConfig()
                        else if (typeof Config.save === "function") Config.save()
                    }
                }

                // TOGGLE: AUDIO THROB
                SettingsToggleRow {
                    title: "Bop to the Beat"
                    subtitle: "Pulse the mascot with the same audio throb as the bar"
                    checked: Config.mascotAudioThrob !== false
                    onToggled: {
                        Config.mascotAudioThrob = (Config.mascotAudioThrob === false)
                        if (typeof Config.saveConfig === "function") Config.saveConfig()
                        else if (typeof Config.save === "function") Config.save()
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
