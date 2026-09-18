import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import ".."

Flickable {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + 32
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        active: root.moving || root.flicking
    }

    property var themes: []
    property string activeThemeId: ""
    property string statusText: ""
    property bool statusIsError: false
    property string pendingApplyId: ""

    // Only ids that came out of our own directory scan ever reach a shell
    // command, but this stays as a hard boundary check since that string
    // gets interpolated into a pkexec'd sed/printf script.
    function isSafeId(id) {
        return /^[A-Za-z0-9_.-]+$/.test(id)
    }

    function refreshThemes() { themeListProc.running = true }
    function refreshActiveTheme() { activeThemeProc.running = true }

    function applyTheme(id) {
        if (!isSafeId(id) || id === root.activeThemeId) return
        root.pendingApplyId = id
        root.statusText = "Applying …"
        root.statusIsError = false
        let script = "f=/etc/sddm.conf.d/theme.conf\n" +
            "mkdir -p /etc/sddm.conf.d\n" +
            "if [ -f \"$f\" ] && grep -q '^Current=' \"$f\"; then\n" +
            "  sed -i 's/^Current=.*/Current=" + id + "/' \"$f\"\n" +
            "else\n" +
            "  printf '[Theme]\\nCurrent=" + id + "\\n' > \"$f\"\n" +
            "fi\n"
        applyProc.command = ["pkexec", "sh", "-c", script]
        applyProc.running = true
    }

    // Always kills whatever preview window is already open and launches a
    // fresh one - the greeter window takes focus immediately, so a manual
    // Stop button in the settings panel would be unreachable while it's up.
    function startPreview(id) {
        if (!isSafeId(id)) return
        if (previewProc.running) previewProc.running = false
        let dir = "/usr/share/sddm/themes/" + id
        // -x matches the exact process name (not the full command line) so this
        // can't match its own invoking `sh -c "..."` wrapper - that wrapper's
        // argv literally contains this script's text, including the target
        // binary's name, so a `pkill -f` pattern here would kill itself before
        // ever reaching `exec`.
        previewProc.command = ["sh", "-c",
            "pkill -x sddm-greeter-qt6 2>/dev/null; exec sddm-greeter-qt6 --test-mode --theme '" + dir + "'"]
        previewProc.running = true
    }

    Component.onCompleted: {
        refreshThemes()
        refreshActiveTheme()
    }

    // Lists every /usr/share/sddm/themes/<id> that has a metadata.desktop,
    // pulling its display name and (when theme.conf points at a real image)
    // a preview path. Re-run by the Refresh button so a theme dropped in
    // after this panel was last opened shows up without restarting the shell.
    Process {
        id: themeListProc
        running: false
        command: ["sh", "-c",
            "for d in /usr/share/sddm/themes/*/; do " +
            "[ -f \"$d/metadata.desktop\" ] || continue; " +
            "id=$(basename \"$d\"); " +
            "name=$(grep -m1 '^Name=' \"$d/metadata.desktop\" | cut -d= -f2-); " +
            "[ -z \"$name\" ] && name=\"$id\"; " +
            "bg=$(grep -m1 '^background=' \"$d/theme.conf\" 2>/dev/null | cut -d= -f2-); " +
            "bgpath=\"\"; " +
            "if [ -n \"$bg\" ] && [ -f \"$d$bg\" ]; then bgpath=\"$d$bg\"; fi; " +
            "printf '%s\\t%s\\t%s\\n' \"$id\" \"$name\" \"$bgpath\"; " +
            "done"]

        stdout: StdioCollector {
            onStreamFinished: {
                let rows = this.text.split("\n").filter(l => l.trim() !== "")
                let list = rows.map(line => {
                    let parts = line.split("\t")
                    return { id: parts[0] || "", name: parts[1] || parts[0] || "", bg: parts[2] || "" }
                })
                list.sort((a, b) => a.name.localeCompare(b.name))
                root.themes = list
            }
        }
    }

    // SDDM reads /etc/sddm.conf then each /etc/sddm.conf.d/*.conf in order,
    // later Current= values winning - `tail -1` mirrors that resolution.
    Process {
        id: activeThemeProc
        running: false
        command: ["sh", "-c",
            "grep -h '^Current=' /etc/sddm.conf /etc/sddm.conf.d/*.conf 2>/dev/null | tail -1 | cut -d= -f2"]

        stdout: StdioCollector {
            onStreamFinished: root.activeThemeId = this.text.trim()
        }
    }

    Process {
        id: applyProc
        running: false

        stderr: StdioCollector { id: applyError }

        onExited: (code) => {
            if (code === 0) {
                root.activeThemeId = root.pendingApplyId
                root.statusText = "Greeter set. Takes effect at your next login."
                root.statusIsError = false
            } else {
                let err = applyError.text.trim()
                root.statusText = err.length > 0 ? err : "Could not apply the greeter (authentication cancelled?)."
                root.statusIsError = true
            }
            root.pendingApplyId = ""
        }
    }

    Process {
        id: previewProc
        running: false
    }

    ColumnLayout {
        id: contentColumn
        width: root.width
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.topMargin: 16
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "SDDM GREETER"
                    color: Config.textMain
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontSubhead)
                    font.bold: true
                }

                Text {
                    text: "Choose the theme shown on your login screen"
                    color: Config.textMuted
                    font.family: Config.sysFont
                    font.pixelSize: Config.size(Config.fontCaption)
                }
            }

            PillButton {
                label: "Refresh"
                onClicked: { root.refreshThemes(); root.refreshActiveTheme() }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            visible: root.statusText !== ""
            text: root.statusText
            color: root.statusIsError ? "#ef4444" : Config.accent
            font.family: Config.sysFont
            font.pixelSize: Config.size(Config.fontCaption)
            font.bold: true
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            implicitHeight: Math.max(200, themeGrid.contentHeight + 12)
            color: Qt.rgba(0, 0, 0, 0.3)
            radius: Config.cornerRadius / 2
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.08)
            clip: true

            Text {
                anchors.centerIn: parent
                visible: root.themes.length === 0
                text: "No SDDM themes found in /usr/share/sddm/themes"
                color: Config.textMuted
                font.family: Config.sysFont
                font.pixelSize: Config.size(Config.fontCaption)
            }

            GridView {
                id: themeGrid
                anchors.fill: parent
                anchors.margins: 6
                cellWidth: width / 2
                cellHeight: Math.floor(cellWidth * (9 / 16)) + 66

                clip: true
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                model: root.themes

                delegate: Item {
                    id: card
                    width: themeGrid.cellWidth
                    height: themeGrid.cellHeight

                    readonly property bool isActive: modelData.id === root.activeThemeId

                    Item {
                        anchors.fill: parent
                        anchors.margins: 4

                        ClippingRectangle {
                            id: thumb
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: card.height - 58
                            radius: Config.cornerRadius / 2
                            color: Qt.rgba(255, 255, 255, 0.05)

                            Image {
                                anchors.fill: parent
                                visible: modelData.bg !== ""
                                source: modelData.bg !== "" ? ("file://" + modelData.bg) : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 320
                                sourceSize.height: 180
                                asynchronous: true
                                cache: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: modelData.bg === ""
                                text: "wallpaper"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 28
                                color: Config.textMuted
                            }

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: Config.accent
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                visible: card.isActive

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Config.bgBase
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: thumb
                            radius: Config.cornerRadius / 2
                            color: "transparent"
                            border.width: card.isActive ? 2.5 : 0
                            border.color: Config.accent
                        }

                        ColumnLayout {
                            anchors.top: thumb.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.topMargin: 6
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                spacing: 6

                                PillButton {
                                    label: "Preview"
                                    onClicked: root.startPreview(modelData.id)
                                }

                                PillButton {
                                    label: card.isActive ? "Active" : "Set as Greeter"
                                    highlighted: !card.isActive
                                    enabled: !card.isActive && root.pendingApplyId === ""
                                    onClicked: root.applyTheme(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true; implicitHeight: 20 }
    }
}
