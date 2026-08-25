import QtQuick

QtObject {
    property var configRef: null

    // --- LOCKSCREEN CONFIGURATION ---
    property real lockscreenBlurRadius: 36
    property bool lockscreenShowMedia: true
    property bool lockscreenShowPower: true
    property string lockscreenMaskStyle: "shapes"
    property string lockscreenShapePalette: "vibrant"
    property bool lockscreenUse12Hour: true
    property bool lockscreenShowSeconds: false
    property bool lockscreenShowAmPm: true
    property string lockscreenDateFormat: "long"
    property int lockscreenClockSize: 150
    property string lockscreenTargetMonitor: "focused"

    onLockscreenBlurRadiusChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onLockscreenShowMediaChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onLockscreenShowPowerChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onLockscreenMaskStyleChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onLockscreenShapePaletteChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onLockscreenUse12HourChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onLockscreenShowSecondsChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onLockscreenShowAmPmChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onLockscreenDateFormatChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onLockscreenClockSizeChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
    onLockscreenTargetMonitorChanged: { if (configRef && configRef.isLoaded) configRef.saveSettings() }
}
