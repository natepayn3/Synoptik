import QtQuick

QtObject {
    property var configRef: null

    // --- SYSTEM SOUNDS CONFIGURATION ---
    property bool playWindowSounds: true
    property bool playNotificationSounds: true
    property string windowSoundPath: "sound1.wav"
    property string notificationSoundPath: "sound1.wav"
    property real windowSoundVolume: 0.25

    onPlayWindowSoundsChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onPlayNotificationSoundsChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onWindowSoundPathChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onNotificationSoundPathChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onWindowSoundVolumeChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
}
