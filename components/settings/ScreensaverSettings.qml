import QtQuick
import QtQuick.Layouts
import ".."

SettingsPage {
    id: root

    title: "Screensaver"
    description: "Full-screen bouncing screensaver - text, DVD logo and bounce physics."
    icon: "tv"

    // Speed is stored as a float, so the preset chips match on the nearest
    // value rather than on equality: a saved config can hold 3.4999 and would
    // otherwise light no chip at all.
    readonly property real speedPreset: {
        const presets = [2.2, 3.5, 5.5, 8.0]
        const current = Config.screensaverSpeed || 3.5
        for (const p of presets) {
            if (Math.abs(current - p) < 0.1) return p
        }
        return current
    }

    SettingsCard {
        title: "Live Preview"
        icon: "preview"
        subtitle: "Real-time viewport of the floating bounce animation."

        accessory: SettingsButton {
            label: "Test Now"
            icon: "play_arrow"
            variant: "accent"
            onClicked: Config.showScreensaver = true
        }

        Rectangle {
            id: miniBox
            Layout.fillWidth: true
            implicitHeight: 180
            radius: Config.cornerRadius - 2
            color: "#000000"
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.15)
            clip: true

            property real pX: 30
            property real pY: 30
            property real pDx: 1.8
            property real pDy: 1.4
            readonly property var previewColors: ["#FF0055", "#00F0FF", "#FFE600", "#00FF66", "#FF6B00", "#9D00FF"]
            property int colorIdx: 0
            property color pColor: previewColors[colorIdx]

            Timer {
                interval: 16
                running: root.visible
                repeat: true
                onTriggered: {
                    let bw = miniBox.width
                    let bh = miniBox.height
                    let ow = miniLogo.width
                    let oh = miniLogo.height
                    if (bw <= 0 || bh <= 0 || ow <= 0 || oh <= 0) return

                    let nx = miniBox.pX + miniBox.pDx
                    let ny = miniBox.pY + miniBox.pDy
                    let hit = false

                    if (nx + ow >= bw) { miniBox.pDx = -Math.abs(miniBox.pDx); nx = bw - ow; hit = true; }
                    else if (nx <= 0) { miniBox.pDx = Math.abs(miniBox.pDx); nx = 0; hit = true; }

                    if (ny + oh >= bh) { miniBox.pDy = -Math.abs(miniBox.pDy); ny = bh - oh; hit = true; }
                    else if (ny <= 0) { miniBox.pDy = Math.abs(miniBox.pDy); ny = 0; hit = true; }

                    if (hit) {
                        miniBox.colorIdx = (miniBox.colorIdx + 1) % miniBox.previewColors.length
                        miniBox.pColor = miniBox.previewColors[miniBox.colorIdx]
                    }

                    miniBox.pX = nx
                    miniBox.pY = ny
                }
            }

            Item {
                id: miniLogo
                x: miniBox.pX
                y: miniBox.pY
                width: miniCol.implicitWidth + 8
                height: miniCol.implicitHeight + 4

                Column {
                    id: miniCol
                    anchors.centerIn: parent
                    spacing: 1

                    // DVD Mode in Preview
                    Column {
                        visible: (Config.screensaverMode || "text") === "dvd"
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: -2

                        Text {
                            text: "DVD"
                            font.family: Config.sysFont !== "" ? Config.sysFont : "system-ui"
                            font.pixelSize: 22
                            font.bold: true
                            font.letterSpacing: 2
                            font.italic: true
                            color: miniBox.pColor
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Rectangle {
                            width: parent.width * 0.95
                            height: 1.5
                            color: miniBox.pColor
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "V I D E O"
                            font.family: Config.sysFont !== "" ? Config.sysFont : "system-ui"
                            font.pixelSize: 6
                            font.bold: true
                            font.letterSpacing: 3
                            color: miniBox.pColor
                            anchors.horizontalCenter: parent.horizontalCenter
                            topPadding: 1
                        }
                    }

                    // Activate Linux Mode in Preview
                    Column {
                        visible: Config.screensaverMode === "activate" || Config.screensaverMode === "clock"
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 1

                        Text {
                            text: "Activate Linux"
                            font.family: Config.sysFont !== "" ? Config.sysFont : "system-ui"
                            font.pixelSize: 17
                            font.bold: true
                            font.letterSpacing: 1
                            color: miniBox.pColor
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "Go to Settings to activate Linux"
                            font.family: Config.sysFont !== "" ? Config.sysFont : "system-ui"
                            font.pixelSize: 8
                            color: Qt.rgba(miniBox.pColor.r, miniBox.pColor.g, miniBox.pColor.b, 0.8)
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    // Custom Text Mode in Preview
                    Column {
                        visible: (Config.screensaverMode || "text") === "text"
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            text: (Config.screensaverText !== undefined && Config.screensaverText !== "") ? Config.screensaverText : "SYNOPTIK"
                            font.family: Config.sysFont !== "" ? Config.sysFont : "system-ui"
                            font.pixelSize: 20
                            font.bold: true
                            font.letterSpacing: 2
                            color: miniBox.pColor
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }

    SettingsCard {
        title: "Display Mode"
        icon: "title"

        SettingsSegmented {
            currentValue: Config.screensaverMode || "text"
            itemWidth: 160
            model: [
                { label: "Custom Text",    value: "text",     icon: "title" },
                { label: "DVD Logo",       value: "dvd",      icon: "disc_full" },
                { label: "Activate Linux", value: "activate", icon: "verified" }
            ]
            onSelected: value => Config.screensaverMode = value
        }

        SettingsField {
            label: "Floating Text"
            visible: (Config.screensaverMode || "text") === "text"

            SettingsTextField {
                id: customText

                text: Config.screensaverText !== undefined ? Config.screensaverText : ""
                placeholder: "Type floating text — e.g. SYNOPTIK"
                icon: "text_fields"
                onEdited: value => Config.screensaverText = value
            }
        }

        SettingsField {
            label: "Font Size"

            SettingsSegmented {
                currentValue: Config.screensaverFontSize || 54
                itemWidth: 160
                model: [
                    { label: "Medium (42px)", value: 42 },
                    { label: "Large (54px)",  value: 54 },
                    { label: "Huge (72px)",   value: 72 }
                ]
                onSelected: value => Config.screensaverFontSize = value
            }
        }
    }

    SettingsCard {
        title: "Animation & Physics"
        icon: "motion_photos_on"

        SettingsField {
            label: "Speed"

            SettingsSegmented {
                currentValue: root.speedPreset
                itemWidth: 150
                model: [
                    { label: "Relaxed (2.2)", value: 2.2 },
                    { label: "Normal (3.5)",  value: 3.5 },
                    { label: "Fast (5.5)",    value: 5.5 },
                    { label: "Turbo (8.0)",   value: 8.0 }
                ]
                onSelected: value => Config.screensaverSpeed = value
            }
        }

        SettingsToggleRow {
            title: "Corner Hit Counter & Flash"
            subtitle: "Show a running corner-hit count and flash each time the logo lands in a corner"
            checked: Config.screensaverCornerCounter !== false
            onToggled: Config.screensaverCornerCounter = (Config.screensaverCornerCounter === false)
        }
    }
}
