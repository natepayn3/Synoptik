import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

// Lifted out of Settings.qml, where it was a 550-line inline
// `sourceComponent: Item { ... }` - the only section that was not its own
// file, and the reason the shell file was the largest in the module.
SettingsPage {
    id: root

    title: "Shell"
    description: "Modular, hardware-accelerated desktop shell for Hyprland."
    icon: "terminal"


    property string statusText: "Ready"
    property bool isBusy: false

    readonly property string repoDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")

    Process {
        id: gitChecker
        running: false

        stdout: StdioCollector { id: checkOutput }
        stderr: StdioCollector { id: checkError }

        onExited: (code) => {
            if (code === 0) {
                let output = checkOutput.text
                if (output.includes("behind")) {
                    root.statusText = "Updates available! Downloading..."
                    gitPuller.command = ["fish", "-c",
                        "cd '" + root.repoDir + "'; " +
                        "and set OLD_HEAD (git rev-parse HEAD); " +
                        "and git fetch origin main; " +
                        "and git reset --hard origin/main; " +
                        "and notify-send -u critical 'Synoptik Shell Updated' (git log --pretty=format:'• %s' $OLD_HEAD..origin/main | string collect)"]
                    gitPuller.running = true
                } else {
                    root.isBusy = false
                    root.statusText = "Your shell is fully up to date."
                }
            } else {
                root.isBusy = false
                let err = checkError.text.trim()
                root.statusText = err.length > 0 ? err : "Error checking upstream repository."
            }
        }
    }

    Process {
        id: gitPuller
        running: false

        stderr: StdioCollector { id: pullError }

        onExited: (code) => {
            root.isBusy = false
            if (code === 0) {
                root.statusText = "Updated! Click Reload to apply the new version."
            } else {
                let err = pullError.text.trim()
                root.statusText = err.length > 0 ? err : "Failed to apply updates."
            }
        }
    }

    SettingsCard {
        title: "Repository"
        icon: "code"

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 60
            radius: Config.cornerRadius / 2
            scale: gitHubMouseArea.pressed ? 0.98 : 1.0
            color: Qt.rgba(255, 255, 255, 0.04)
            border.width: 1
            border.color: gitHubHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

            Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 8
                    color: Qt.rgba(255, 255, 255, 0.06)

                    Text {
                        anchors.centerIn: parent
                        text: "code"
                        color: Config.accent
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 18
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "GitHub Repository"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                    }

                    Text {
                        text: "github.com/natepayn3/Synoptik"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                    }
                }

                Text {
                    text: "open_in_new"
                    color: gitHubHover.hovered ? Config.accent : Config.textMuted
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 18
                }
            }

            MouseArea {
                id: gitHubMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/natepayn3/Synoptik"])
            }
            HoverHandler { id: gitHubHover }
        }
    }

    SettingsCard {
        title: "Updates"
        icon: "system_update"

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.max(68, statusRow.implicitHeight + 20)
            radius: Config.cornerRadius / 2
            color: Qt.rgba(255, 255, 255, 0.04)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.08)

            RowLayout {
                id: statusRow
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 12

                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 8
                    color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.15)

                    Text {
                        anchors.centerIn: parent
                        text: root.isBusy ? "sync" : "system_update"
                        color: Config.accent
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 18

                        RotationAnimation on rotation {
                            running: root.isBusy
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: root.isBusy ? "Checking Upstream..." : "Repository Status"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontBody)
                        font.bold: true
                    }

                    Text {
                        text: root.statusText
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAnywhere
                    }
                }

                RowLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        implicitWidth: 110
                        implicitHeight: 32
                        radius: Config.cornerRadius / 2
                        scale: reloadMouseArea.pressed ? 0.95 : 1.0
                        color: reloadBtnHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                        border.color: Qt.rgba(255, 255, 255, 0.15)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "restart_alt"; color: Config.textMain; font.family: "Material Symbols Outlined"; font.pixelSize: 14 }
                            Text { text: "Reload"; color: Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: true }
                        }

                        MouseArea {
                            id: reloadMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.isBusy
                            onClicked: {
                                Config.flushSettings()
                                Quickshell.execDetached(["fish", "-c", "killall qs; and qs -c Synoptik & disown"])
                            }
                        }
                        HoverHandler { id: reloadBtnHover }
                    }

                    Rectangle {
                        implicitWidth: 120
                        implicitHeight: 32
                        radius: Config.cornerRadius / 2
                        scale: updateMouseArea.pressed ? 0.95 : 1.0
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: updateBtnHover.hovered ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.4) : Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.26) }
                            GradientStop { position: 1.0; color: updateBtnHover.hovered ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.22) : Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.12) }
                        }
                        border.color: Config.accent
                        border.width: 1

                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "sync"; color: Config.accent; font.family: "Material Symbols Outlined"; font.pixelSize: 14 }
                            Text { text: root.isBusy ? "Updating..." : "Check Updates"; color: Config.accent; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: true }
                        }

                        MouseArea {
                            id: updateMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.isBusy
                            onClicked: {
                                root.isBusy = true
                                root.statusText = "Checking for updates..."
                                gitChecker.command = ["fish", "-c", "cd '" + root.repoDir + "'; and git remote update; and git status -uno"]
                                gitChecker.running = true
                            }
                        }
                        HoverHandler { id: updateBtnHover }
                    }
                }
            }
        }
    }

    SettingsCard {
        title: "Configuration Profiles"
        icon: "bookmarks"

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            implicitHeight: profilesColumn.implicitHeight + 28
            radius: Config.cornerRadius / 2
            color: Qt.rgba(255, 255, 255, 0.04)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.08)

            ColumnLayout {
                id: profilesColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 8
                        color: Qt.rgba(255, 255, 255, 0.06)
                        Text {
                            anchors.centerIn: parent
                            text: "bookmarks"
                            color: Config.accent
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Configuration Profiles"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.bold: true
                        }

                        Text {
                            text: Config.activeProfile !== ""
                                ? ("Active: " + Config.activeProfile + " • saved snapshots of every setting")
                                : "Save the current setup and switch between machines"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }

                // --- new profile name + save ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: Config.cornerRadius / 2
                        color: Qt.rgba(255, 255, 255, 0.05)
                        border.width: 1
                        border.color: profileNameInput.activeFocus
                            ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.6)
                            : Qt.rgba(255, 255, 255, 0.1)

                        TextInput {
                            id: profileNameInput
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            selectByMouse: true
                            onAccepted: {
                                Config.saveProfile(text)
                                text = ""
                            }
                            HoverHandler { cursorShape: Qt.IBeamCursor }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: profileNameInput.text === ""
                                text: "Profile name (e.g. laptop)"
                                color: Qt.rgba(255, 255, 255, 0.3)
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.italic: true
                            }
                        }
                    }

                    Rectangle {
                        implicitWidth: 92
                        implicitHeight: 32
                        radius: Config.cornerRadius / 2
                        opacity: Config.sanitizeProfileName(profileNameInput.text) === "" ? 0.4 : 1.0
                        scale: saveProfMouse.pressed ? 0.95 : 1.0
                        color: saveProfHover.hovered
                            ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.3)
                            : Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.18)
                        border.width: 1
                        border.color: Config.accent

                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "save"; color: Config.accent; font.family: "Material Symbols Outlined"; font.pixelSize: 14 }
                            Text {
                                text: Config.profileNames.indexOf(Config.sanitizeProfileName(profileNameInput.text)) >= 0 ? "Replace" : "Save"
                                color: Config.accent
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: saveProfMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (Config.sanitizeProfileName(profileNameInput.text) === "") return
                                Config.saveProfile(profileNameInput.text)
                                profileNameInput.text = ""
                            }
                        }
                        HoverHandler { id: saveProfHover }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: Config.profileNames.length === 0
                    text: "No profiles saved yet. Saving one snapshots every current setting to profiles/<name>.json."
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontMicro)
                    font.italic: true
                    wrapMode: Text.WordWrap
                }

                // --- saved profiles ---
                SettingsList {
                    Repeater {
                        model: Config.profileNames

                        delegate: Rectangle {
                            id: profRow
                            required property var modelData
                            readonly property bool isActive: Config.activeProfile === profRow.modelData

                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: Config.cornerRadius / 2
                            color: isActive
                                ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.12)
                                : Qt.rgba(255, 255, 255, 0.03)
                            border.width: 1
                            border.color: isActive ? Config.accent : Qt.rgba(255, 255, 255, 0.08)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: profRow.isActive ? "radio_button_checked" : "bookmark"
                                    color: profRow.isActive ? Config.accent : Config.textMuted
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 15
                                }

                                Text {
                                    text: profRow.modelData
                                    color: profRow.isActive ? Config.accent : Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: profRow.isActive
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    implicitWidth: 62
                                    implicitHeight: 24
                                    radius: Config.cornerRadius / 2
                                    color: loadHover.hovered ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.06)
                                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Load"
                                        color: Config.textMain
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontMicro)
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Config.loadProfile(profRow.modelData)
                                    }
                                    HoverHandler { id: loadHover }
                                }

                                Text {
                                    text: "delete"
                                    color: delHover.hovered ? "#e0564f" : Config.textMuted
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 16

                                    HoverHandler { id: delHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: Config.deleteProfile(profRow.modelData) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
