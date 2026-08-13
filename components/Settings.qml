import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "./settings"
import "./widgets"

Item {
    id: settingsRoot

    implicitWidth: 1000
    implicitHeight: 700
    clip: true

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    // GIGANTIC GEAR WATERMARK
    Item {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -40
        anchors.bottomMargin: -60
        implicitWidth: 350
        implicitHeight: 350

        Text {
            anchors.centerIn: parent
            text: Config.getIcon("settings")
            font.family: "Material Symbols Outlined"
            font.pixelSize: 350
            color: Config.accent
            opacity: 0.07
            rotation: 15
        }
    }

    // Inline Comment: Initialize activeSection to match saved Config state
    property int activeSection: Config.lastSettingsSection
    property bool isMaximized: false
    property bool visualsExpanded: false
    property bool connectivityExpanded: false
    property bool widgetsExpanded: false

    // Inline Comment: Expand parent accordion menu containing the selected tab
    function expandActiveCategory(sectionId) {
        if ([0, 1, 2, 3, 12].includes(sectionId)) visualsExpanded = true
        else if ([4, 5, 6, 7].includes(sectionId)) connectivityExpanded = true
        else if ([8, 9, 10, 13, 14].includes(sectionId)) widgetsExpanded = true
    }

    Component.onCompleted: {
        activeSection = Config.lastSettingsSection
        expandActiveCategory(activeSection)
    }

    Connections {
        target: Config
        function onLastSettingsSectionChanged() {
            if (settingsRoot.activeSection !== Config.lastSettingsSection) {
                settingsRoot.activeSection = Config.lastSettingsSection
                settingsRoot.expandActiveCategory(settingsRoot.activeSection)
            }
        }
    }

    onActiveSectionChanged: {
        if (Config.isLoaded && Config.lastSettingsSection !== activeSection) {
            Config.lastSettingsSection = activeSection
        }
        expandActiveCategory(activeSection)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: settingsRoot.cardMargin
        spacing: settingsRoot.cardMargin / 2

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
                        if (mascotSettingsLoader.item) mascotSettingsLoader.item.showBrowser = false
                    }
                }
                HoverHandler { id: closeHover }
            }
        }

        // MASTER-DETAIL TWO-COLUMN LAYOUT
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: settingsRoot.cardMargin / 2

            // LEFT NAVIGATION CARD
            Rectangle {
                Layout.preferredWidth: 250
                Layout.maximumWidth: 250
                Layout.fillHeight: true
                color: Qt.rgba(255, 255, 255, 0.03)
                radius: (Config.surfaceRadius || 18) * 0.75
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: settingsRoot.cardMargin
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
                                Text { text: settingsRoot.visualsExpanded ? "expand_more" : "chevron_right"; color: Config.textMuted; font.family: "Material Symbols Outlined"; font.pixelSize: 18 }
                                Text { text: "VISUALS"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: true; Layout.fillWidth: true }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsRoot.visualsExpanded = !settingsRoot.visualsExpanded
                            }
                            HoverHandler { id: visualsCatHover }
                        }

                        ColumnLayout {
                            visible: settingsRoot.visualsExpanded
                            Layout.fillWidth: true; Layout.leftMargin: 6; spacing: 3

                            Repeater {
                                model: [
                                    { id: 0, name: "Display",     icon: "aspect_ratio" },
                                    { id: 1, name: "Appearance",  icon: "palette" },
                                    { id: 2, name: "Typography",  icon: "match_case" },
                                    { id: 3, name: "Wallpaper",   icon: "wallpaper" },
                                    { id: 12, name: "Icons",      icon: "account_circle" }
                                ]

                                delegate: Rectangle {
                                    id: navDelegate1
                                    Layout.fillWidth: true; implicitHeight: 34; radius: Config.cornerRadius / 2
                                    readonly property bool isSelected: settingsRoot.activeSection === modelData.id
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
                                            settingsRoot.activeSection = modelData.id
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
                                Text { text: settingsRoot.connectivityExpanded ? "expand_more" : "chevron_right"; color: Config.textMuted; font.family: "Material Symbols Outlined"; font.pixelSize: 18 }
                                Text { text: "CONNECTIVITY"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: true; Layout.fillWidth: true }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsRoot.connectivityExpanded = !settingsRoot.connectivityExpanded
                            }
                            HoverHandler { id: connCatHover }
                        }

                        ColumnLayout {
                            visible: settingsRoot.connectivityExpanded
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
                                    readonly property bool isSelected: settingsRoot.activeSection === modelData.id
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
                                            settingsRoot.activeSection = modelData.id
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
                                Text { text: settingsRoot.widgetsExpanded ? "expand_more" : "chevron_right"; color: Config.textMuted; font.family: "Material Symbols Outlined"; font.pixelSize: 18 }
                                Text { text: "WIDGETS"; color: Config.textMuted; font.family: Config.sysFont; font.pixelSize: Config.size(Config.fontCaption); font.bold: true; Layout.fillWidth: true }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsRoot.widgetsExpanded = !settingsRoot.widgetsExpanded
                            }
                            HoverHandler { id: widgetsCatHover }
                        }

                        ColumnLayout {
                            visible: settingsRoot.widgetsExpanded
                            Layout.fillWidth: true; Layout.leftMargin: 6; spacing: 3

                            Repeater {
                                model: [
                                    { id: 8, name: "Mascot", icon: "smart_toy" },
                                    { id: 9, name: "Clock", icon: "schedule" },
                                    { id: 10, name: "Keyboard", icon: "keyboard" },
                                    { id: 13, name: "Sounds", icon: "volume_up" },
                                ]

                                delegate: Rectangle {
                                    id: navDelegate3
                                    Layout.fillWidth: true; implicitHeight: 34; radius: Config.cornerRadius / 2
                                    readonly property bool isSelected: settingsRoot.activeSection === modelData.id
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
                                            settingsRoot.activeSection = modelData.id
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
                            readonly property bool isSelected: settingsRoot.activeSection === 11
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
                                    settingsRoot.activeSection = 11
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
                    anchors.margins: settingsRoot.cardMargin

                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 0; visible: active; sourceComponent: DisplaySettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 1; visible: active; sourceComponent: AppearanceSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 2; visible: active; sourceComponent: TypographySettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 3; visible: active; sourceComponent: WallpaperSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 4; visible: active; sourceComponent: NetworkSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 5; visible: active; sourceComponent: WifiSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 6; visible: active; sourceComponent: BluetoothSettings {} }

                    Loader {
                        anchors.fill: parent
                        active: settingsRoot.activeSection === 7
                        visible: active
                        sourceComponent: ColumnLayout {
                            anchors.fill: parent
                            spacing: settingsRoot.cardMargin

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
                    }

                    Loader { id: mascotSettingsLoader; anchors.fill: parent; active: settingsRoot.activeSection === 8; visible: active; sourceComponent: MascotSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 9; visible: active; sourceComponent: ClockSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 10; visible: active; sourceComponent: OskSettings {} }

                    Loader {
                        anchors.fill: parent
                        active: settingsRoot.activeSection === 11
                        visible: active
                        sourceComponent: Item {
                            id: shellView
                            anchors.fill: parent

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
                                spacing: settingsRoot.cardMargin

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
                                        spacing: settingsRoot.cardMargin

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
                                        spacing: settingsRoot.cardMargin

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
                                                border.width: 2

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
                                                border.width: 2

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

                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 12; visible: active; sourceComponent: IconSettings {} }
                    Loader { anchors.fill: parent; active: settingsRoot.activeSection === 13; visible: active; sourceComponent: SystemSounds {} }
                }
            }
        }
    }
}