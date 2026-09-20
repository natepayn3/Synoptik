pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."

// Moved here from components/widgets/ - it was only ever mounted as a
// settings section, so it belongs beside the other pages rather than beside
// the desktop widgets.
SettingsPage {
    id: root

    title: "Sounds"
    description: "Audio feedback for window and notification events."
    icon: "volume_up"

    readonly property var soundFiles: [
        "sound1.wav", "sound2.wav", "sound3.wav",
        "sound4.wav", "sound5.wav", "sound6.wav",
        "sound7.wav", "sound8.wav", "sound9.wav"
    ]

    // "sound1.wav" -> "Sound 1"
    function formatSoundName(fileName) {
        const clean = fileName.replace(".wav", "")
        return clean.charAt(0).toUpperCase() + clean.slice(1).replace(/(\d+)/, " $1")
    }

    // pw-play (PipeWire's own client), not SoundEffect - QSoundEffect's
    // QRtAudioEngine segfaults when the active output device changes
    // mid-playback (e.g. Bluetooth headphones connecting), a bug inside
    // libQt6Multimedia rather than something QT_MEDIA_BACKEND can route
    // around. pw-play sidesteps Qt Multimedia's audio engine entirely.
    function previewSound(fileName) {
        if (!fileName) return
        previewPlayer.running = false
        previewPlayer.command = ["pw-play", "--volume", "0.25", Config.shellDir + "/assets/" + fileName]
        previewPlayer.running = true
    }

    Process { id: previewPlayer }

    SettingsCard {
        title: "Windows & Panels"
        icon: "web_asset"
        subtitle: "Played when a window or shell panel opens."
        bodyEnabled: Config.playWindowSounds !== false

        accessory: ToggleSwitch {
            checked: Config.playWindowSounds !== false

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (Config.isLoaded) Config.playWindowSounds = !Config.playWindowSounds
                }
            }
        }

        SettingsSoundPicker {
            current: Config.windowSoundPath
            onPicked: fileName => {
                Config.windowSoundPath = fileName
                root.previewSound(fileName)
            }
        }
    }

    SettingsCard {
        title: "Notifications"
        icon: "notifications"
        subtitle: "Played when a notification arrives."
        bodyEnabled: Config.playNotificationSounds !== false

        accessory: ToggleSwitch {
            checked: Config.playNotificationSounds !== false

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (Config.isLoaded) Config.playNotificationSounds = !Config.playNotificationSounds
                }
            }
        }

        SettingsSoundPicker {
            current: Config.notificationSoundPath
            onPicked: fileName => {
                Config.notificationSoundPath = fileName
                root.previewSound(fileName)
            }
        }
    }
}
