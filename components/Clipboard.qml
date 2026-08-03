import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: clipRoot

    implicitWidth: 380
    implicitHeight: mainLayout.implicitHeight + 24

    ListModel { id: clipModel }

    function refreshClipboard() {
        fetchProc.running = false
        fetchProc.running = true
    }

    Component.onCompleted: {
        refreshClipboard()
    }

    Connections {
        target: Config
        function onShowClipboardChanged() {
            if (Config.showClipboard) {
                refreshClipboard()
            }
        }
    }
    
    // Process 1: Instantaneous list fetching
    Process {
        id: fetchProc
        running: false
        command: ["cliphist", "list"]
        
        stdout: StdioCollector {
            id: fetchOut 
            onStreamFinished: {
                let outText = fetchOut.text
                
                if (!outText || outText.trim() === "") {
                    clipModel.clear()
                    return
                }
                
                let lines = outText.trim().split("\n")
                let newItems = []
                
                for (let line of lines) {
                    if (!line) continue
                    let firstTab = line.indexOf("\t")
                    
                    if (firstTab !== -1) {
                        let id = line.substring(0, firstTab).trim()
                        let text = line.substring(firstTab + 1).trim()
                        
                        let isBinary = text.includes("binary data") || text.includes("image") || text.startsWith("[[")
                        let isBase64 = text.startsWith("data:image/")
                        // Fix 1: Only consider Web URLs valid image previews if they end in standard image extensions
                        let isWebUrl = /^https?:\/\/.*\.(png|jpg|jpeg|webp|gif|svg)(\?.*)?$/i.test(text)
                        let isLocalFile = (text.startsWith("/") || text.startsWith("file://")) && 
                                          /\.(png|jpg|jpeg|webp|gif|svg)$/i.test(text)

                        let finalImgPath = ""
                        
                        if (isBinary || isBase64) {
                            // Fix 2: Don't set the image path immediately on list fetch, let cacheProc inject it when ready
                            finalImgPath = ""
                        } else if (isWebUrl) {
                            finalImgPath = text
                        } else if (isLocalFile) {
                            finalImgPath = text.startsWith("file://") ? text : ("file://" + text)
                        }

                        let isVisualItem = isBinary || isBase64 || isWebUrl || isLocalFile

                        newItems.push({
                            itemId: id,
                            previewText: text,
                            isImage: isVisualItem,
                            imagePath: finalImgPath
                        })
                    }
                }
                
                clipModel.clear()
                for (let item of newItems) {
                    clipModel.append(item)
                }

                // Immediately kick off the background cache builder once the UI is saturated
                cacheProc.running = false
                cacheProc.running = true
            }
        }
    }

    // Process 2: Heavy asynchronous image generation
    Process {
        id: cacheProc
        running: false
        command: [
            "fish", "-c", 
            "mkdir -p /tmp/cliphist; " +
            "cliphist list | while read -l line; " +
                "set -l id (string split -m 1 \\t -- \"$line\")[1]; " +
                "set -l img_path \"/tmp/cliphist/$id.png\"; " +
                // If file already exists, echo the ID so QML binds it immediately
                "if test -f \"$img_path\"; " +
                    "echo \"$id\"; " +
                "else; " +
                    "if string match -q -r 'binary data|image|^\\[\\[' -- \"$line\"; " +
                        "set -l tmp \"/tmp/cliphist/raw_$id\"; " +
                        "printf '%s\\n' \"$line\" | cliphist decode > \"$tmp\" 2>/dev/null; " +
                        "if test -s \"$tmp\"; magick \"$tmp\" PNG:\"$img_path\" 2>/dev/null; and echo \"$id\"; end; " +
                        "rm -f \"$tmp\"; " +
                    "else if string match -q -r 'data:image' -- \"$line\"; " +
                        "set -l b64 (echo \"$line\" | string replace -r '.*data:image/[^;]+;base64,' ''); " +
                        "set -l tmp \"/tmp/cliphist/raw_$id\"; " +
                        "echo \"$b64\" | base64 -d > \"$tmp\" 2>/dev/null; " +
                        "if test -s \"$tmp\"; magick \"$tmp\" PNG:\"$img_path\" 2>/dev/null; and echo \"$id\"; end; " +
                        "rm -f \"$tmp\"; " +
                    "end; " +
                "end; " +
            "end"
        ]

        stdout: StdioCollector {
            id: cacheOut
            onStreamFinished: {
                let out = cacheOut.text
                if (!out) return
                
                let generatedIds = out.trim().split("\n")
                if (generatedIds.length === 0 || !generatedIds[0]) return

                // Lazily update models for cached items
                for (let i = 0; i < clipModel.count; i++) {
                    let item = clipModel.get(i)
                    if (generatedIds.includes(item.itemId)) {
                        let targetPath = "file:///tmp/cliphist/" + item.itemId + ".png"
                        clipModel.setProperty(i, "imagePath", targetPath + "?t=" + Date.now())
                    }
                }
            }
        }
    }

    Process { 
        id: copyProc
        onExited: {
            refreshClipboard()
        }
    }

    Process {
        id: wipeProc
        running: false
        command: ["fish", "-c", "cliphist wipe; and rm -rf /tmp/cliphist/*"]
        onExited: {
            refreshClipboard()
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        Rectangle {
            id: mainCard
            Layout.fillWidth: true
            implicitHeight: cardContent.implicitHeight + 24
            color: Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius

            Behavior on implicitHeight {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                id: cardContent
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "CLIPBOARD"
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontTitle)
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: clearText.implicitWidth + 12
                        implicitHeight: 24
                        radius: Config.cornerRadius / 2
                        color: clearHover.hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                        visible: clipModel.count > 0

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: clearText
                            anchors.centerIn: parent
                            text: "CLEAR ALL"
                            color: clearHover.hovered ? Config.accent : Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        TapHandler { 
                            onTapped: {
                                wipeProc.running = false
                                wipeProc.running = true 
                            }
                        }
                        HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: clipModel.count > 0 
                        ? Math.min(clipList.contentHeight, 320) 
                        : emptyStateContainer.implicitHeight
                    color: "transparent"
                    clip: true

                    Behavior on implicitHeight {
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }

                    ListView {
                        id: clipList
                        anchors.fill: parent
                        model: clipModel
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: delegateRoot
                            required property string itemId
                            required property string previewText
                            required property bool isImage
                            required property string imagePath

                            width: ListView.view.width
                            implicitHeight: (delegateRoot.isImage && delegateRoot.imagePath !== "" && imgPreview.status === Image.Ready) ? 110 : 38
                            radius: 8
                            color: itemHover.hovered ? Qt.rgba(255, 255, 255, 0.1) : Qt.rgba(255, 255, 255, 0.03)

                            Text {
                                visible: !delegateRoot.isImage || delegateRoot.imagePath === "" || imgPreview.status !== Image.Ready
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10; rightMargin: 10
                                }
                                text: delegateRoot.previewText
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontBody)
                                elide: Text.ElideRight
                            }

                            Image {
                                id: imgPreview
                                visible: delegateRoot.isImage && delegateRoot.imagePath !== "" && status === Image.Ready
                                anchors {
                                    fill: parent
                                    margins: 6
                                }
                                source: (delegateRoot.isImage && delegateRoot.imagePath !== "") ? delegateRoot.imagePath : ""
                                fillMode: Image.PreserveAspectFit
                                sourceSize.height: 110
                                cache: false
                                asynchronous: true
                            }

                            TapHandler {
                                onTapped: {
                                    copyProc.command = ["fish", "-c", "cliphist list | awk 'BEGIN{FS=\"\\t\"} $1 == \"" + itemId + "\" {print $0}' | cliphist decode | wl-copy"]
                                    copyProc.running = false
                                    copyProc.running = true
                                }
                            }
                            HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
                        }

                        ColumnLayout {
                            id: emptyStateContainer
                            anchors.centerIn: parent
                            spacing: 6
                            visible: clipModel.count === 0 && !fetchProc.running

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "content_paste_off"
                                color: Config.textMuted
                                opacity: 0.5
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 28
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Clipboard history is empty"
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                            }
                        }
                    }
                }
            }
        }
    }
}