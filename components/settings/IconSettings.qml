import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."

ColumnLayout {
    id: iconSettingsRoot
    anchors.fill: parent
    spacing: Config.cardMargin || 12

    // Unset by default until explicitly clicked
    property string selectedIconId: ""
    property string searchQuery: ""
    property var allIconsList: []
    property bool isLoadingIcons: true

    // --- FETCH FULL MATERIAL SYMBOLS LIST ---
    Process {
        id: iconFetcher
        running: true
        command: ["fish", "-c", "
            if test -f /usr/share/fonts/material-symbols/MaterialSymbolsOutlined.codepoints;
                cat /usr/share/fonts/material-symbols/MaterialSymbolsOutlined.codepoints | cut -d' ' -f1;
            else if test -f ~/.local/share/fonts/MaterialSymbolsOutlined.codepoints;
                cat ~/.local/share/fonts/MaterialSymbolsOutlined.codepoints | cut -d' ' -f1;
            else
                curl -sS --max-time 10 'https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.codepoints' | cut -d' ' -f1;
            end
        "]

        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text ? this.text.trim() : ""
                if (txt.length > 0) {
                    let lines = txt.split('\n').map(l => l.trim()).filter(l => l.length > 0)
                    iconSettingsRoot.allIconsList = lines
                }
                iconSettingsRoot.isLoadingIcons = false
            }
        }
    }

    Text {
        text: "CUSTOMIZE ICONS"
        color: Config.textMain
        font.family: Config.sysFont
        font.pixelSize: Config.size(Config.fontSubhead)
        font.bold: true
    }

    // --- DESCRIPTION WITH DIRECT LINK TO GOOGLE ICONS ---
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            textFormat: Text.StyledText
            text: "Click any icon in the bar mockup to select it, or search installed Material Symbols below. You can also browse glyph names on <a href=\"https://fonts.google.com/icons\" style=\"color: " + Config.accent + "; text-decoration: none;\">fonts.google.com/icons</a>."
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            onLinkActivated: link => Quickshell.execDetached(["xdg-open", link])

            HoverHandler {
                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }
    }

    // --- MULTI-ROW BAR MOCKUP SECTION ---
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: mockupColumn.implicitHeight + 16
        radius: Config.cornerRadius / 2
        color: Qt.rgba(0, 0, 0, 0.25)

        ColumnLayout {
            id: mockupColumn
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            // ROW 1: LEFT MODULES
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Left Card:"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.bold: true
                    Layout.preferredWidth: 90
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Config.cornerRadius / 2
                    color: Qt.rgba(255, 255, 255, 0.05)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Repeater {
                            model: [
                                { id: "power", label: "Power" },
                                { id: "recorder", label: "Recorder" },
                                { id: "screenshot", label: "Screenshot" },
                                { id: "notifications", label: "Notifications" },
                                { id: "wallpaper", label: "Wallpaper" },
                                { id: "settings", label: "Settings" },
                                { id: "launcher", label: "Launcher" }
                            ]

                            delegate: Rectangle {
                                implicitWidth: 32; implicitHeight: 32; radius: 8
                                readonly property bool isSelected: iconSettingsRoot.selectedIconId === modelData.id
                                color: isSelected ? Qt.rgba(255, 255, 255, 0.2) : (btnHoverL.hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent")
                                border.color: isSelected ? Config.accent : "transparent"
                                border.width: isSelected ? 2 : 0

                                Text {
                                    anchors.centerIn: parent
                                    text: Config.getIcon(modelData.id)
                                    color: parent.isSelected ? Config.accent : Config.textMain
                                    font.family: "Material Symbols Outlined"
                                    font.weight: Font.Bold
                                    font.pixelSize: 18
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: iconSettingsRoot.selectedIconId = modelData.id
                                }
                                HoverHandler { id: btnHoverL }
                            }
                        }
                    }
                }
            }

            // ROW 2: WORKSPACES / SPECIALS
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Workspaces:"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.bold: true
                    Layout.preferredWidth: 90
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Config.cornerRadius / 2
                    color: Qt.rgba(255, 255, 255, 0.05)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Repeater {
                            model: [
                                { id: "overview", label: "Overview" },
                                { id: "magic", label: "Magic" },
                                { id: "magic_active", label: "Magic (Active)" },
                                { id: "music", label: "Music" },
                                { id: "music_active", label: "Music (Active)" },
                                { id: "private", label: "Private" },
                                { id: "private_active", label: "Private (Active)" }
                            ]

                            delegate: Rectangle {
                                implicitWidth: 32; implicitHeight: 32; radius: 8
                                readonly property bool isSelected: iconSettingsRoot.selectedIconId === modelData.id
                                color: isSelected ? Qt.rgba(255, 255, 255, 0.2) : (btnHoverC.hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent")
                                border.color: isSelected ? Config.accent : "transparent"
                                border.width: isSelected ? 2 : 0

                                Text {
                                    anchors.centerIn: parent
                                    text: Config.getIcon(modelData.id)
                                    color: parent.isSelected ? Config.accent : Config.textMain
                                    font.family: "Material Symbols Outlined"
                                    font.weight: Font.Bold
                                    font.pixelSize: 18
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: iconSettingsRoot.selectedIconId = modelData.id
                                }
                                HoverHandler { id: btnHoverC }
                            }
                        }
                    }
                }
            }

            // ROW 3: RIGHT MODULES
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Right Card:"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                    font.bold: true
                    Layout.preferredWidth: 90
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Config.cornerRadius / 2
                    color: Qt.rgba(255, 255, 255, 0.05)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Repeater {
                            model: [
                                { id: "audio", label: "Audio" },
                                { id: "sys", label: "System" },
                                { id: "cc", label: "Control Center" },
                                { id: "network", label: "Network" },
                                { id: "clipboard", label: "Clipboard" }
                            ]

                            delegate: Rectangle {
                                implicitWidth: 32; implicitHeight: 32; radius: 8
                                readonly property bool isSelected: iconSettingsRoot.selectedIconId === modelData.id
                                color: isSelected ? Qt.rgba(255, 255, 255, 0.2) : (btnHoverR.hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent")
                                border.color: isSelected ? Config.accent : "transparent"
                                border.width: isSelected ? 2 : 0

                                Text {
                                    anchors.centerIn: parent
                                    text: Config.getIcon(modelData.id)
                                    color: parent.isSelected ? Config.accent : Config.textMain
                                    font.family: "Material Symbols Outlined"
                                    font.weight: Font.Bold
                                    font.pixelSize: 18
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: iconSettingsRoot.selectedIconId = modelData.id
                                }
                                HoverHandler { id: btnHoverR }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- SEARCH BAR & RESET BUTTON ---
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            color: Qt.rgba(0, 0, 0, 0.2)
            radius: Config.cornerRadius / 2
            border.color: (iconSearchInput.activeFocus || searchBoxHover.hovered) ? Config.accent : "transparent"
            border.width: 2

            Behavior on border.color { ColorAnimation { duration: 150 } }

            HoverHandler { id: searchBoxHover; cursorShape: Qt.PointingHandCursor }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: "search"
                    color: Config.textMuted
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 18
                }

                TextInput {
                    id: iconSearchInput
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontBody)
                    selectByMouse: true

                    HoverHandler { cursorShape: Qt.IBeamCursor }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Search Material Design Symbols (e.g. power, terminal, home, wifi)..."
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontBody)
                        visible: iconSearchInput.text === ""
                        elide: Text.ElideRight
                    }

                    onTextChanged: iconSettingsRoot.searchQuery = text.trim().toLowerCase()
                }
            }
        }

        // Reset to Defaults
        Rectangle {
            implicitWidth: 110; implicitHeight: 38
            radius: Config.cornerRadius / 2
            color: resetHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.2)
            border.color: resetHover.hovered ? Config.accent : "transparent"
            border.width: 2

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: "Reset All"
                color: resetHover.hovered ? Config.accent : Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Config.resetIcons()
            }
            HoverHandler { id: resetHover }
        }
    }

    // --- ICON PICKER GRID ---
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Qt.rgba(0, 0, 0, 0.15)
        radius: Config.cornerRadius / 2
        clip: true

        Text {
            anchors.centerIn: parent
            text: iconSettingsRoot.selectedIconId === "" ? "Click an icon above to start customizing..." : "Loading Material Symbols list..."
            color: Config.textMuted
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontBody)
            visible: iconSettingsRoot.selectedIconId === "" || (iconSettingsRoot.isLoadingIcons && iconSettingsRoot.allIconsList.length === 0)
        }

        GridView {
            id: iconGrid
            anchors.fill: parent
            anchors.margins: 10
            clip: true

            // Inline Comment: Calculate columns from min size, then stretch cellWidth to fill 100% of parent width
            readonly property real minCellWidth: 50
            readonly property int columns: Math.max(1, Math.floor(width / minCellWidth))
            
            cellWidth: width / columns
            cellHeight: 52

            visible: iconSettingsRoot.selectedIconId !== "" && (!iconSettingsRoot.isLoadingIcons || iconSettingsRoot.allIconsList.length > 0)

            model: {
                if (iconSettingsRoot.searchQuery === "") {
                    return iconSettingsRoot.allIconsList.slice(0, 300)
                }
                return iconSettingsRoot.allIconsList.filter(name => name.includes(iconSettingsRoot.searchQuery)).slice(0, 300)
            }

            delegate: Item {
                width: GridView.view.cellWidth
                height: GridView.view.cellHeight

                Rectangle {
                    // Inline Comment: Center the visual button inside the dynamically sized grid slot
                    anchors.centerIn: parent
                    width: 44
                    height: 44
                    radius: 8
                    readonly property bool isAssigned: iconSettingsRoot.selectedIconId !== "" && Config.getIcon(iconSettingsRoot.selectedIconId) === modelData
                    color: isAssigned ? Qt.rgba(255, 255, 255, 0.25) : (gridHover.hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent")
                    border.color: isAssigned ? Config.accent : "transparent"
                    border.width: isAssigned ? 2 : 0

                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: parent.isAssigned ? Config.accent : Config.textMain
                        font.family: "Material Symbols Outlined"
                        font.weight: Font.Bold
                        font.pixelSize: 22
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: iconSettingsRoot.selectedIconId !== ""
                        onClicked: {
                            if (iconSettingsRoot.selectedIconId !== "") {
                                Config.setIconOverride(iconSettingsRoot.selectedIconId, modelData)
                            }
                        }
                    }

                    HoverHandler { id: gridHover }
                }
            }
        }
    }
}