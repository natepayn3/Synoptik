pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: state

    property string audioVolume: "0%"
    property string networkStatus: "Disconnected"
    
    // Polls volume level using standard PipeWire/WirePlumber commands
    property var volumePoller: Process {
        command: ["fish", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2 * 100 \"%\"}'"]
        running: true
        onStdoutChanged: state.audioVolume = stdout.trim()
    }

    // Example background timer for metrics that don't stream outputs
    property var updateTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            // Trigger network or battery scripts here
        }
    }
}