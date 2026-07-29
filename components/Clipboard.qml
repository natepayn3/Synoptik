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

    Component.onCompleted: {
        if (Config.showClipboard) {
            fetchProc.running = true
        }
    }

    Process {
        id: fetchProc
        running: false
        
        command: ["fish", "-c", "mkdir -p /tmp/cliphist; cliphist list | awk -F'\\t' '/binary data|image|\\[\\[/ {print $1}' | while read -l id; if not test -f /tmp/cliphist/$id.png; set -l tmp_raw /tmp/cliphist/raw_$id; printf '%s\\t' \"$id\" | cliphist decode > $tmp_raw 2>/dev/null; if test -s $tmp_raw; magick $tmp_raw /tmp/cliphist/$id.png 2>/dev/null; or cp $tmp_raw /tmp/cliphist/$id.png 2>/dev/null; end; rm -f $tmp_raw; end; end; cliphist list"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                clipModel.clear()
                let lines = this.text.trim().split("\n")
                for (let line of lines) {
                    if (!line) continue
                    let firstTab = line.indexOf("\t")
                    if (firstTab !== -1) {
                        let id = line.substring(0, firstTab).trim()
                        let text = line.substring(firstTab + 1).trim()
                        
                        let isBinary = text.includes("binary data") || text.includes("image") || text.startsWith("[[")
                        let isBase64 = text.startsWith("data:image/")
                        let isWebUrl = text.startsWith("http://") || text.startsWith("https://")
                        let isLocalFile = (text.startsWith("/") || text.startsWith("file://")) && 
                                          /\.(png|jpg|jpeg|webp|gif|svg)$/i.test(text)

                        let finalImgPath = ""
                        
                        if (isBinary) {
                            finalImgPath = "file:///tmp/cliphist/" + id + ".png"
                        } else if (isBase64) {
                            let b64Data = text.replace(/^data:image\/[^;]+;base64,/, "")
                            decodeB64Proc.command = ["fish", "-c", "echo '" + b64Data + "' | base64 -d > /tmp/cliphist/raw_" + id + "; and magick /tmp/cliphist/raw_" + id + " /tmp/cliphist/" + id + ".png; and rm -f /tmp/cliphist/raw_" + id]
                            decodeB64Proc.running = true
                            finalImgPath = "file:///tmp/cliphist/" + id + ".png"
                        } else if (isWebUrl) {
                            finalImgPath = text
                        } else if (isLocalFile) {
                            finalImgPath = text.startsWith("file://") ? text : ("file://" + text)
                        }

                        let isVisualItem = isBinary || isBase64 || isWebUrl || isLocalFile

                        clipModel.append({
                            itemId: id,
                            previewText: text,
                            isImage: isVisualItem,
                            imagePath: finalImgPath
                        })
                    }
                }
            }
        }
    }

    Process { id: decodeB64Proc }
    Process { id: copyProc }

    Process {
        id: wipeProc
        running: false
        command: ["fish", "-c", "cliphist wipe; and rm -rf /tmp/cliphist/*"]
        onExited: {
            fetchProc.running = false
            fetchProc.running = true
        }
    }

    Connections {
        target: Config
        function onShowClipboardChanged() {
            if (Config.showClipboard) {
                fetchProc.running = false
                fetchProc.running = true
            }
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
                            required property string itemId
                            required property string previewText
                            required property bool isImage
                            required property string imagePath

                            width: ListView.view.width
                            implicitHeight: isImage ? 110 : 38
                            radius: 8
                            color: itemHover.hovered ? Qt.rgba(255, 255, 255, 0.1) : Qt.rgba(255, 255, 255, 0.03)

                            Text {
                                visible: !parent.isImage
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10; rightMargin: 10
                                }
                                text: parent.previewText
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontBody)
                                elide: Text.ElideRight
                            }

                            Image {
                                visible: parent.isImage
                                anchors {
                                    fill: parent
                                    margins: 6
                                }
                                source: parent.isImage ? parent.imagePath : ""
                                fillMode: Image.PreserveAspectFit
                                sourceSize.height: 110
                                cache: false
                                asynchronous: true
                            }

                            TapHandler {
                                onTapped: {
                                    copyProc.command = ["fish", "-c", "printf '%s\\t' '" + itemId + "' | cliphist decode | wl-copy"]
                                    copyProc.running = true
                                    Config.showClipboard = false
                                }
                            }
                            HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
                        }

                        ColumnLayout {
                            id: emptyStateContainer
                            anchors.centerIn: parent
                            spacing: 6
                            visible: clipModel.count === 0

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