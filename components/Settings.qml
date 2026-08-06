import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "./settings"

PanelWindow {
    id: settingsWindow

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    WlrLayershell.namespace: "synoptik-shell-settings"

    visible: Config.showSettings || progress > 0.0

    screen: {
        let activeName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        let found = Quickshell.screens.find(s => s.name === activeName)
        return found ? found : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    }

    anchors {
        top: true; bottom: true; left: true; right: true
    }

    color: "transparent"

    mask: Region {
        item: (Config.showSettings || progress > 0.01) ? fullScreenBounds : null
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Config.showSettings ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property int activeSection: 0
    property bool visualsExpanded: false
    property bool connectivityExpanded: false
    property bool widgetsExpanded: false

    // --- UNIFIEDSURFACE ANIMATION LOGIC ---
    readonly property bool isOpen: Config.showSettings
    readonly property bool isHorizontal: Config.barPosition === "top" || Config.barPosition === "bottom"

    readonly property real baseWidth: 1230
    readonly property real baseHeight: 810
    readonly property real rawChildWidth: baseWidth
    readonly property real rawChildHeight: baseHeight

    property real lastOpenWidth: rawChildWidth
    property real lastOpenHeight: rawChildHeight

    onIsOpenChanged: {
        if (!isOpen) {
            lastOpenWidth = rawChildWidth
            lastOpenHeight = rawChildHeight
        } else {
            breathingContainer.forceActiveFocus()
        }
    }

    property real targetWidth: isOpen ? rawChildWidth : (isHorizontal ? (lastOpenWidth * 0.50) : (lastOpenWidth * 1.10))
    property real targetHeight: isOpen ? rawChildHeight : (isHorizontal ? (lastOpenHeight * 1.10) : (lastOpenHeight * 0.50))

    Behavior on targetWidth {
        NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
    }

    Behavior on targetHeight {
        NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
    }

    property real progress: 0.0
    readonly property real animScale: Math.max(0.0, progress)

    readonly property real closeFactor: isOpen ? progress : Math.pow(progress, 1.2)
    readonly property real currentHeight: targetHeight * Math.pow(closeFactor, 1.8)
    readonly property real squishRatio: targetHeight > 0 ? (1.0 - (currentHeight / targetHeight)) : 0.0
    readonly property real currentWidth: isOpen ? (targetWidth * animScale) : (targetWidth * (closeFactor + (0.3 * squishRatio * closeFactor)))

    Shortcut {
        sequences: ["Escape"]
        enabled: Config.showSettings
        onActivated: {
            if (mascotSettingsView.showBrowser) {
                mascotSettingsView.showBrowser = false
            } else {
                Config.showSettings = false
            }
        }
    }

    Item {
        id: fullScreenBounds
        anchors.fill: parent

        states: [
            State {
                name: "open"
                when: isOpen
                PropertyChanges { target: settingsWindow; progress: 1.0 }
            },
            State {
                name: "closed"
                when: !isOpen
                PropertyChanges { target: settingsWindow; progress: 0.0 }
            }
        ]

        transitions: [
            Transition {
                from: "closed"; to: "open"
                NumberAnimation {
                    target: settingsWindow
                    property: "progress"
                    duration: 450
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.8
                }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation {
                    target: settingsWindow
                    property: "progress"
                    duration: 300
                    easing.type: Easing.InBack
                    easing.overshoot: 1.4
                }
            }
        ]

        MouseArea {
            anchors.fill: parent
            enabled: Config.showSettings
            onClicked: {
                Config.showSettings = false
                mascotSettingsView.showBrowser = false
            }
        }

        Item {
            id: breathingContainer
            width: Math.max(1, currentWidth)
            height: Math.max(1, currentHeight)
            opacity: animScale
            anchors.centerIn: parent
            focus: true

            Rectangle {
                anchors.fill: parent
                color: Config.bgPanel
                radius: Config.surfaceRadius || 18
                
                readonly property int effectiveBorderWidth: Config.borderThickness
                border.width: effectiveBorderWidth
                border.color: effectiveBorderWidth > 0 ? Config.accent : "transparent"
                clip: true

                Behavior on radius {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                Behavior on border.width {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: settingsWindow.cardMargin
                    spacing: settingsWindow.cardMargin

                    // HEADER
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "SETTINGS"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontTitle)
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            implicitWidth: 28; implicitHeight: 28; radius: 14
                            color: closeHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "close"
                                color: Config.textMain
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 18
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Config.showSettings = false
                                    mascotSettingsView.showBrowser = false
                                }
                            }
                            HoverHandler { id: closeHover }
                        }
                    }

                    // MASTER-DETAIL TWO-COLUMN LAYOUT
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: settingsWindow.cardMargin

                        // LEFT NAVIGATION CARD
                        Rectangle {
                            Layout.preferredWidth: 300
                            Layout.maximumWidth: 300
                            Layout.fillHeight: true
                            color: Qt.rgba(255, 255, 255, 0.03)
                            radius: (Config.surfaceRadius || 18) * 0.75
                            clip: true

                            Flickable {
                                anchors.fill: parent
                                anchors.margins: settingsWindow.cardMargin
                                contentHeight: leftNavColumn.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                ColumnLayout {
                                    id: leftNavColumn
                                    width: parent.width
                                    spacing: 6

                                    // CATEGORY 1: VISUALS
                                    Rectangle {
                                        Layout.fillWidth: true; implicitHeight: 32; radius: Config.cornerRadius / 2
                                        color: visualsCatHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent"

                                        RowLayout {
                                            anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 4
                                            Text { text: settingsWindow.visualsExpanded ? "expand_more" : "chevron_right"; color: Config.textMuted; font.family: "Material Symbols Outlined"; font.pixelSize: 18 }
                                            Text { text: "VISUALS"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: true; Layout.fillWidth: true }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: settingsWindow.visualsExpanded = !settingsWindow.visualsExpanded
                                        }
                                        HoverHandler { id: visualsCatHover }
                                    }

                                    ColumnLayout {
                                        visible: settingsWindow.visualsExpanded
                                        Layout.fillWidth: true; Layout.leftMargin: 6; spacing: 3

                                        Repeater {
                                            model: [
                                                { id: 0, name: "Display",     icon: "aspect_ratio" },
                                                { id: 1, name: "Appearance",  icon: "palette" },
                                                { id: 2, name: "Typography",  icon: "match_case" },
                                                { id: 3, name: "Wallpaper",   icon: "wallpaper" }
                                            ]

                                            delegate: Rectangle {
                                                id: navDelegate1
                                                Layout.fillWidth: true; implicitHeight: 34; radius: Config.cornerRadius / 2
                                                readonly property bool isSelected: settingsWindow.activeSection === modelData.id
                                                color: navDelegate1.isSelected ? Qt.rgba(255, 255, 255, 0.12) : (navHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")

                                                RowLayout {
                                                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                                                    Text { text: modelData.icon; color: navDelegate1.isSelected ? Config.accent : Config.textMuted; font.family: "Material Symbols Outlined"; font.pixelSize: 16 }
                                                    Text { text: modelData.name; color: navDelegate1.isSelected ? Config.accent : Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: navDelegate1.isSelected; Layout.fillWidth: true; elide: Text.ElideRight }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        settingsWindow.activeSection = modelData.id
                                                        mascotSettingsView.showBrowser = false
                                                    }
                                                }
                                                HoverHandler { id: navHover }
                                            }
                                        }
                                    }

                                    // CATEGORY 2: CONNECTIVITY
                                    Rectangle {
                                        Layout.fillWidth: true; implicitHeight: 32; radius: Config.cornerRadius / 2
                                        color: connCatHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent"

                                        RowLayout {
                                            anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 4
                                            Text { text: settingsWindow.connectivityExpanded ? "expand_more" : "chevron_right"; color: Config.textMuted; font.family: "Material Symbols Outlined"; font.pixelSize: 18 }
                                            Text { text: "CONNECTIVITY"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: true; Layout.fillWidth: true }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: settingsWindow.connectivityExpanded = !settingsWindow.connectivityExpanded
                                        }
                                        HoverHandler { id: connCatHover }
                                    }

                                    ColumnLayout {
                                        visible: settingsWindow.connectivityExpanded
                                        Layout.fillWidth: true; Layout.leftMargin: 6; spacing: 3

                                        Repeater {
                                            model: [
                                                { id: 4, name: "Network",   icon: "lan" },
                                                { id: 5, name: "Wi-Fi",     icon: "wifi" },
                                                { id: 6, name: "Bluetooth", icon: "bluetooth" },
                                                { id: 7, name: "Weather",   icon: "thermostat" }
                                            ]

                                            delegate: Rectangle {
                                                id: navDelegate2
                                                Layout.fillWidth: true; implicitHeight: 34; radius: Config.cornerRadius / 2
                                                readonly property bool isSelected: settingsWindow.activeSection === modelData.id
                                                color: navDelegate2.isSelected ? Qt.rgba(255, 255, 255, 0.12) : (navConnHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")

                                                RowLayout {
                                                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                                                    Text { text: modelData.icon; color: navDelegate2.isSelected ? Config.accent : Config.textMuted; font.family: "Material Symbols Outlined"; font.pixelSize: 16 }
                                                    Text { text: modelData.name; color: navDelegate2.isSelected ? Config.accent : Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: navDelegate2.isSelected; Layout.fillWidth: true; elide: Text.ElideRight }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        settingsWindow.activeSection = modelData.id
                                                        mascotSettingsView.showBrowser = false
                                                    }
                                                }
                                                HoverHandler { id: navConnHover }
                                            }
                                        }
                                    }

                                    // CATEGORY 3: WIDGETS
                                    Rectangle {
                                        Layout.fillWidth: true; implicitHeight: 32; radius: Config.cornerRadius / 2
                                        color: widgetsCatHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent"

                                        RowLayout {
                                            anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 4
                                            Text { text: settingsWindow.widgetsExpanded ? "expand_more" : "chevron_right"; color: Config.textMuted; font.family: "Material Symbols Outlined"; font.pixelSize: 18 }
                                            Text { text: "WIDGETS"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: true; Layout.fillWidth: true }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: settingsWindow.widgetsExpanded = !settingsWindow.widgetsExpanded
                                        }
                                        HoverHandler { id: widgetsCatHover }
                                    }

                                    ColumnLayout {
                                        visible: settingsWindow.widgetsExpanded
                                        Layout.fillWidth: true; Layout.leftMargin: 6; spacing: 3

                                        Repeater {
                                            model: [
                                                { id: 8, name: "Mascot", icon: "smart_toy" },
                                                { id: 9, name: "Clock", icon: "schedule" },
                                                { id: 10, name: "Keyboard", icon: "keyboard" }
                                            ]

                                            delegate: Rectangle {
                                                id: navDelegate3
                                                Layout.fillWidth: true; implicitHeight: 34; radius: Config.cornerRadius / 2
                                                readonly property bool isSelected: settingsWindow.activeSection === modelData.id
                                                color: navDelegate3.isSelected ? Qt.rgba(255, 255, 255, 0.12) : (navWidgetsHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")

                                                RowLayout {
                                                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                                                    Text { text: modelData.icon; color: navDelegate3.isSelected ? Config.accent : Config.textMuted; font.family: "Material Symbols Outlined"; font.pixelSize: 16 }
                                                    Text { text: modelData.name; color: navDelegate3.isSelected ? Config.accent : Config.textMain; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: navDelegate3.isSelected; Layout.fillWidth: true; elide: Text.ElideRight }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        settingsWindow.activeSection = modelData.id
                                                        mascotSettingsView.showBrowser = false
                                                    }
                                                }
                                                HoverHandler { id: navWidgetsHover }
                                            }
                                        }
                                    }

                                    // BOTTOM NAV ITEM: SHELL
                                    Rectangle {
                                        id: shellBtn
                                        Layout.fillWidth: true; implicitHeight: 34; radius: Config.cornerRadius / 2
                                        Layout.topMargin: 6
                                        readonly property bool isSelected: settingsWindow.activeSection === 11
                                        color: shellBtn.isSelected ? Qt.rgba(255, 255, 255, 0.12) : (shellNavHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")

                                        RowLayout {
                                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                                            Text { 
                                                text: "terminal"
                                                color: shellBtn.isSelected ? Config.accent : Config.textMuted
                                                font.family: "Material Symbols Outlined"
                                                font.pixelSize: 16 
                                            }
                                            Text { 
                                                text: "Shell"
                                                color: shellBtn.isSelected ? Config.accent : Config.textMain
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontCaption)
                                                font.bold: shellBtn.isSelected
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight 
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                settingsWindow.activeSection = 11
                                                mascotSettingsView.showBrowser = false
                                            }
                                        }
                                        HoverHandler { id: shellNavHover }
                                    }
                                }
                            }
                        }

                        // RIGHT CONTENT CONTAINER
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Qt.rgba(255, 255, 255, 0.03)
                            radius: (Config.surfaceRadius || 18) * 0.75
                            clip: true

                            Item {
                                anchors.fill: parent
                                anchors.margins: settingsWindow.cardMargin

                                DisplaySettings     { anchors.fill: parent; visible: settingsWindow.activeSection === 0 }
                                AppearanceSettings  { anchors.fill: parent; visible: settingsWindow.activeSection === 1 }
                                TypographySettings  { anchors.fill: parent; visible: settingsWindow.activeSection === 2 }
                                WallpaperSettings   { anchors.fill: parent; visible: settingsWindow.activeSection === 3 }
                                NetworkSettings     { anchors.fill: parent; visible: settingsWindow.activeSection === 4 }
                                WifiSettings        { anchors.fill: parent; visible: settingsWindow.activeSection === 5 }
                                BluetoothSettings   { anchors.fill: parent; visible: settingsWindow.activeSection === 6 }

                                // INLINE WEATHER SETTINGS SECTION
                                ColumnLayout {
                                    anchors.fill: parent
                                    visible: settingsWindow.activeSection === 7
                                    spacing: settingsWindow.cardMargin

                                    Text {
                                        text: "LOCATION & WEATHER"
                                        color: Config.textMain
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontSubhead)
                                        font.bold: true
                                    }

                                    Text {
                                        text: "Specify a zipcode or city name to override IP-based geolocation for the weather widget. Leave blank to reset to automatic IP location."
                                        color: Config.textMuted
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontCaption)
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 40
                                        color: Qt.rgba(0, 0, 0, 0.2)
                                        radius: Config.cornerRadius / 2

                                        TextInput {
                                            id: zipInput
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            verticalAlignment: Text.AlignVCenter
                                            color: Config.textMain
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontBody)
                                            text: Config.locationQuery
                                            selectByMouse: true

                                            Connections {
                                                target: Config
                                                function onLocationQueryChanged() {
                                                    if (zipInput.text !== Config.locationQuery) {
                                                        zipInput.text = Config.locationQuery
                                                    }
                                                }
                                            }

                                            HoverHandler {
                                                cursorShape: Qt.IBeamCursor
                                            }

                                            Text {
                                                anchors.fill: parent
                                                verticalAlignment: Text.AlignVCenter
                                                text: "e.g., 90210, London, or leave blank..."
                                                color: Config.textMuted
                                                font.family: Config.sysFont
                                                font.pixelSize: Config.size(Config.fontBody)
                                                visible: zipInput.text === ""
                                            }

                                            onEditingFinished: {
                                                if (Config.isLoaded) {
                                                    Config.locationQuery = zipInput.text.trim()
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillHeight: true }
                                }

                                MascotSettings {
                                    id: mascotSettingsView
                                    anchors.fill: parent
                                    visible: settingsWindow.activeSection === 8
                                }

                                ClockSettings {
                                    anchors.fill: parent
                                    visible: settingsWindow.activeSection === 9
                                }

                                OskSettings {
                                    anchors.fill: parent
                                    visible: settingsWindow.activeSection === 10
                                }

                                Item {
                                    id: shellView
                                    anchors.fill: parent
                                    visible: settingsWindow.activeSection === 11

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
                                                    shellView.statusText = "Downloading and applying latest files..."
                                                    gitPuller.command = ["fish", "-c", "cd '" + shellView.repoDir + "'; and git fetch origin main; and git reset --hard origin/main"]
                                                    gitPuller.running = true
                                                } else {
                                                    shellView.isBusy = false
                                                    shellView.statusText = "Your shell is already up to date."
                                                }
                                            } else {
                                                shellView.isBusy = false
                                                let err = checkError.text.trim()
                                                shellView.statusText = err.length > 0 ? err : "Error checking upstream repository."
                                            }
                                        }
                                    }

                                    Process {
                                        id: gitPuller
                                        running: false

                                        stderr: StdioCollector { id: pullError }

                                        onExited: (code) => {
                                            shellView.isBusy = false
                                            if (code === 0) {
                                                shellView.statusText = "Updated successfully! Reloading..."
                                                Quickshell.execDetached(["fish", "-c", "killall quickshell; and quickshell"])
                                            } else {
                                                let err = pullError.text.trim()
                                                shellView.statusText = err.length > 0 ? err : "Failed to force update files."
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: settingsWindow.cardMargin

                                        Text {
                                            text: "SYNOPTIK SHELL"
                                            color: Config.textMain
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontTitle)
                                            font.bold: true
                                        }

                                        Text {
                                            text: "A modular, hardware-accelerated desktop environment shell built for Hyprland on Arch Linux using Quickshell & QML."
                                            color: Config.textMuted
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontCaption)
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 48
                                            radius: Config.cornerRadius / 2
                                            color: gitHubHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2)
                                            border.width: gitHubHover.hovered ? 2 : 0
                                            border.color: gitHubHover.hovered ? Config.accent : "transparent"

                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 16
                                                spacing: settingsWindow.cardMargin

                                                Text {
                                                    text: "code"
                                                    color: Config.accent
                                                    font.family: "Material Symbols Outlined"
                                                    font.pixelSize: 20
                                                    Layout.preferredWidth: 24
                                                    horizontalAlignment: Text.AlignHCenter
                                                    Layout.alignment: Qt.AlignVCenter
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: false
                                                    Layout.alignment: Qt.AlignVCenter
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
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                Item {
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: "open_in_new"
                                                    color: Config.textMuted
                                                    font.family: "Material Symbols Outlined"
                                                    font.pixelSize: 18
                                                    Layout.alignment: Qt.AlignVCenter
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/natepayn3/Synoptik"])
                                            }
                                            HoverHandler { id: gitHubHover }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: Math.max(48, statusRow.implicitHeight + 16)
                                            radius: Config.cornerRadius / 2
                                            color: Qt.rgba(0, 0, 0, 0.2)
                                            border.width: 0

                                            RowLayout {
                                                id: statusRow
                                                anchors.fill: parent
                                                anchors.leftMargin: 16
                                                anchors.rightMargin: 16
                                                anchors.topMargin: 8
                                                anchors.bottomMargin: 8
                                                spacing: settingsWindow.cardMargin

                                                Text {
                                                    text: shellView.isBusy ? "sync" : "system_update"
                                                    color: Config.accent
                                                    font.family: "Material Symbols Outlined"
                                                    font.pixelSize: 20
                                                    Layout.preferredWidth: 24
                                                    horizontalAlignment: Text.AlignHCenter
                                                    Layout.alignment: Qt.AlignVCenter
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    spacing: 2

                                                    Text {
                                                        text: shellView.isBusy ? "Updating Shell..." : "Repository Status"
                                                        color: Config.textMain
                                                        font.family: Config.sysFont
                                                        font.pixelSize: Config.size(Config.fontBody)
                                                        font.bold: true
                                                    }

                                                    Text {
                                                        text: shellView.statusText
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
                                                        implicitWidth: 100
                                                        implicitHeight: 30
                                                        radius: Config.cornerRadius / 2
                                                        color: reloadBtnHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                                                        border.color: Config.textMuted
                                                        border.width: 1

                                                        Behavior on color { ColorAnimation { duration: 100 } }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "Reload Shell"
                                                            color: Config.textMain
                                                            font.family: Config.sysFont
                                                            font.pixelSize: Config.size(Config.fontCaption)
                                                            font.bold: true
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            enabled: !shellView.isBusy
                                                            onClicked: {
                                                                Quickshell.execDetached(["fish", "-c", "killall qs; and qs -c Synoptik & disown"])
                                                            }
                                                        }
                                                        HoverHandler { id: reloadBtnHover }
                                                    }

                                                    Rectangle {
                                                        implicitWidth: 110
                                                        implicitHeight: 30
                                                        radius: Config.cornerRadius / 2
                                                        color: updateBtnHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                                                        border.color: Config.accent
                                                        border.width: 1

                                                        Behavior on color { ColorAnimation { duration: 100 } }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: shellView.isBusy ? "Updating..." : "Update Shell"
                                                            color: Config.accent
                                                            font.family: Config.sysFont
                                                            font.pixelSize: Config.size(Config.fontCaption)
                                                            font.bold: true
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            enabled: !shellView.isBusy
                                                            onClicked: {
                                                                shellView.isBusy = true
                                                                shellView.statusText = "Checking for latest files..."
                                                                gitChecker.command = ["fish", "-c", "cd '" + shellView.repoDir + "'; and git remote update; and git status -uno"]
                                                                gitChecker.running = true
                                                            }
                                                        }
                                                        HoverHandler { id: updateBtnHover }
                                                    }
                                                }
                                            }
                                        }

                                        Item { Layout.fillHeight: true }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}