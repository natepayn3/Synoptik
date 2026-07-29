import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: appLauncherModule

    property string pinFilePath: ""
    property var allApps: []
    property var filteredApps: []
    property var localPins: []

    implicitWidth: 420
    implicitHeight: 480

    // Clear search and refresh models when opened
    Connections {
        target: Config
        function onShowAppLauncherChanged() {
            if (Config.showAppLauncher) {
                searchInput.text = ""
                searchInput.forceActiveFocus()
                pinCacheReader.reload()
                appLauncherModule.updateModel()
            }
        }
    }

    Process {
        id: initPinFile
        command: ["fish", "-c", "if not test -f ~/.cache/quickshell_launcher_pins.json; echo '{\"pins\":[]}'> ~/.cache/quickshell_launcher_pins.json; end"]
        running: true
        onExited: appLauncherModule.pinFilePath = Quickshell.env("HOME") + "/.cache/quickshell_launcher_pins.json"
    }

    FileView {
        id: pinCacheReader
        path: appLauncherModule.pinFilePath 
        onTextChanged: {
            let cleanText = text().trim();
            if (!cleanText || cleanText === "[]") return; 
            try {
                let parsed = JSON.parse(cleanText);
                if (parsed && parsed.pins) { 
                    appLauncherModule.localPins = parsed.pins;
                    appLauncherModule.updateModel(); 
                }
            } catch(e) {}
        }
    }

    Process {
        id: appFetcher
        command: ["python", "-c", `
import os, glob, json

apps = []
fallback_options = [
    "/usr/share/pixmaps/archlinux-logo.png",
    "/usr/share/icons/hicolor/48x48/apps/utilities-terminal.png"
]
fallback = next((p for p in fallback_options if os.path.isfile(p)), "")

icon_dirs = [
    os.path.expanduser("~/.local/share/icons"),
    "/usr/share/icons/Papirus",
    "/usr/share/icons/hicolor",
    "/usr/share/pixmaps"
]

# 1. Build a fast single-pass lookup table for icon paths
icon_map = {}
for base in icon_dirs:
    if not os.path.isdir(base): continue
    for root, _, files in os.walk(base):
        # Skip small pixel sizes or irrelevant categories to speed up scanning
        if any(skip in root for skip in ["/16x16/", "/22x22/", "/24x24/", "/32x32/", "/symbolic/"]):
            continue
        for f in files:
            if f.endswith((".svg", ".png", ".xpm")):
                name = os.path.splitext(f)[0]
                if name not in icon_map:
                    icon_map[name] = os.path.join(root, f)

# 2. Fast parse desktop entries
for folder in ["/usr/share/applications", os.path.expanduser("~/.local/share/applications")]:
    if not os.path.isdir(folder): continue
    for entry in os.scandir(folder):
        if not entry.name.endswith(".desktop") or not entry.is_file(): continue
        
        path = entry.path
        name, exec_cmd, icon, desc, nodisplay = "", "", "", "", False
        
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    if line.startswith("Name=") and not name: name = line[5:].strip()
                    elif line.startswith("Exec=") and not exec_cmd: exec_cmd = line[5:].strip()
                    elif line.startswith("Icon=") and not icon: icon = line[5:].strip().split("?")[0]
                    elif line.startswith("Comment=") and not desc: desc = line[8:].strip()
                    elif line.startswith("NoDisplay=true"): nodisplay = True
        except: continue

        if nodisplay or not name or not exec_cmd: continue

        # 3. O(1) Instant Icon Lookup
        resolved = fallback
        if icon:
            if icon.startswith("/") and os.path.isfile(icon):
                resolved = icon
            elif icon in icon_map:
                resolved = icon_map[icon]

        apps.append({
            "name": name.replace("\\x22", "").replace("\\\\", ""),
            "exec": exec_cmd.replace("\\x22", "").replace("\\\\", ""),
            "icon": "file://" + resolved if resolved and not resolved.startswith("file://") else "file://" + fallback,
            "desc": desc.replace("\\x22", "").replace("\\\\", "") if desc else "Application",
            "path": path
        })

print(json.dumps(apps))
        `]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    appLauncherModule.allApps = JSON.parse(this.text);
                    appLauncherModule.updateModel();
                } catch(e) {}
            }
        }
    }

    function togglePin(appPath) {
        let currentPins = appLauncherModule.localPins.slice();
        let idx = currentPins.indexOf(appPath); 
        if (idx !== -1) {
            currentPins.splice(idx, 1);
        } else { 
            currentPins.push(appPath);
        } 
        appLauncherModule.localPins = currentPins;
        appLauncherModule.updateModel();
        
        let jsonStr = JSON.stringify({ "pins": currentPins }); 
        Quickshell.execDetached(["fish", "-c", "echo '" + jsonStr + "' > ~/.cache/quickshell_launcher_pins.json"]);
    } 

    function updateModel() {
        let query = searchInput.text.trim().toLowerCase();
        let pins = []; 
        let others = [];

        for (let i = 0; i < appLauncherModule.allApps.length; i++) {
            let app = appLauncherModule.allApps[i];
            if (query !== "" && !app.name.toLowerCase().includes(query) && !app.desc.toLowerCase().includes(query)) continue; 
            if (appLauncherModule.localPins.includes(app.path)) {
                pins.push(app);
            } else { 
                others.push(app);
            } 
        }

        pins.sort((a,b) => a.name.localeCompare(b.name));
        others.sort((a,b) => a.name.localeCompare(b.name)); 
        appLauncherModule.filteredApps = pins.concat(others);
        
        appListView.currentIndex = 0;
        appListView.positionViewAtBeginning();
    } 

    function launchApp(execString) {
        let cleanExec = execString.replace(/%[uUfFkKcCiI]/g, "").trim();
        Quickshell.execDetached(["fish", "-c", cleanExec]);
        Config.showAppLauncher = false;
    }

    ColumnLayout {
        id: mainLayout
        
        anchors.fill: parent
        anchors.margins: 12
        
        spacing: 12

        // ==========================================
        // APPLICATIONS CARD (Title + Search + List)
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: cardContentLayout.implicitHeight + 24
            radius: Config.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.05)

            ColumnLayout {
                id: cardContentLayout
                
                anchors.fill: parent
                anchors.margins: 12
                
                spacing: 12

                Text {
                    text: "APPLICATIONS"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontTitle)
                    font.bold: true
                    Layout.fillWidth: true
                }

                ColumnLayout {
                    id: innerColumn
                    Layout.fillWidth: true
                    spacing: 12

                    // Search Input Surface
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: Config.cornerRadius / 2
                        color: searchHover.hovered || searchInput.activeFocus ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.25)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        HoverHandler { id: searchHover }

                        TapHandler {
                            onTapped: searchInput.forceActiveFocus()
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: "search"
                                color: searchInput.activeFocus ? Config.accent : Config.textMuted
                                font { family: "Material Symbols Outlined"; pixelSize: 18 }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontBody)
                                font.bold: true
                                clip: true
                                selectByMouse: true
                                focus: true
                                Timer {
                                    running: true
                                    interval: 50
                                    onTriggered: searchInput.forceActiveFocus()
                                }

                                HoverHandler { cursorShape: Qt.IBeamCursor }

                                Text {
                                    text: "Search apps..."
                                    color: Qt.rgba(255, 255, 255, 0.3)
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.italic: true
                                    visible: parent.text === "" && !parent.activeFocus
                                }

                                onTextChanged: appLauncherModule.updateModel() 

                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_Down) {
                                        appListView.incrementCurrentIndex();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Up) {
                                        appListView.decrementCurrentIndex();
                                        event.accepted = true; 
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (appListView.currentItem) {
                                            appLauncherModule.launchApp(appListView.currentItem.appExec);
                                        } 
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Escape) {
                                        // Dismiss the launcher when Escape is pressed
                                        Config.showAppLauncher = false;
                                        event.accepted = true;
                                    }
                                }
                            }
                        }
                    }

                    // App List View Frame Surface
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 340
                        radius: Config.cornerRadius / 2
                        color: Qt.rgba(0, 0, 0, 0.2)
                        clip: true

                        ListView {
                            id: appListView
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 2 
                            keyNavigationEnabled: false
                            boundsBehavior: Flickable.StopAtBounds
                            model: appLauncherModule.filteredApps 
                            
                            delegate: Rectangle {
                                id: appDelegate
                                width: appListView.width 
                                implicitHeight: 54 
                                radius: Config.cornerRadius / 2
                                color: appListView.currentIndex === index 
                                    ? Qt.rgba(255, 255, 255, 0.12) 
                                    : (itemHover.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent")
                                
                                property string appExec: modelData.exec
                                property bool isPinned: appLauncherModule.localPins.includes(modelData.path)

                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 12

                                    Image { 
                                        Layout.preferredWidth: 32 
                                        Layout.preferredHeight: 32
                                        sourceSize.width: 64 
                                        sourceSize.height: 64
                                        source: modelData.icon ? modelData.icon : "file:///usr/share/icons/hicolor/scalable/apps/utilities-terminal.svg"
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true 
                                        spacing: 2
                                        Layout.alignment: Qt.AlignVCenter 

                                        Text { 
                                            text: modelData.name
                                            font.family: Config.sysFont 
                                            font.pixelSize: Config.size(Config.fontBody)
                                            color: Config.textMain 
                                            font.bold: appDelegate.isPinned
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: modelData.desc !== "" ? modelData.desc : "Application" 
                                            font.family: Config.sysFont
                                            font.pixelSize: Config.size(Config.fontCaption)
                                            color: Config.textMuted
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: "keep" 
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 18
                                        color: Config.accent
                                        visible: appDelegate.isPinned 
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                } 

                                MouseArea {
                                    id: itemHover
                                    anchors.fill: parent 
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton 
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    property int lastScreenX: -1 
                                    property int lastScreenY: -1

                                    onPositionChanged: (mouse) => { 
                                        let currentX = Math.floor(mouse.screenX);
                                        let currentY = Math.floor(mouse.screenY);
                                        let deltaX = Math.abs(currentX - lastScreenX); 
                                        let deltaY = Math.abs(currentY - lastScreenY);
                                        if (lastScreenX !== -1 && (deltaX > 2 || deltaY > 2)) {
                                            if (appListView.currentIndex !== index) { 
                                                appListView.currentIndex = index;
                                            }
                                        }
                                        lastScreenX = currentX;
                                        lastScreenY = currentY; 
                                    }

                                    onExited: {
                                        lastScreenX = -1;
                                        lastScreenY = -1; 
                                    }

                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            appLauncherModule.togglePin(modelData.path);
                                        } else { 
                                            appLauncherModule.launchApp(modelData.exec);
                                        }
                                    }
                                }
                            }

                            ScrollBar.vertical: ScrollBar {
                                active: appListView.moving || appListView.flickableDirection
                                policy: ScrollBar.AsNeeded
                            }
                        } 
                    }
                }
            }
        }
    }
}