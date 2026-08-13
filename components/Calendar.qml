import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.qmlmodels
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: root

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    // Baseline panel bounds to prevent Layout.fillHeight/fillWidth collapse
    implicitWidth: 680
    implicitHeight: 460

    // Calendar Navigation State
    property int gridMonth: new Date().getMonth()
    property int gridYear: new Date().getFullYear()

    function prevMonth() {
        if (gridMonth === 0) {
            gridMonth = 11
            gridYear -= 1
        } else {
            gridMonth -= 1
        }
    }

    function nextMonth() {
        if (gridMonth === 11) {
            gridMonth = 0
            gridYear += 1
        } else {
            gridMonth += 1
        }
    }

    // Selected Date & Date Formatting
    property var selectedDate: new Date()
    
    function formatDateKey(d) {
        var year = d.getFullYear()
        var month = (d.getMonth() + 1).toString().padStart(2, '0')
        var day = d.getDate().toString().padStart(2, '0')
        return year + "-" + month + "-" + day
    }

    property string selectedKey: formatDateKey(selectedDate)

    // Reminders Data Store
    property var allReminders: ({})

    // Persistence
    readonly property string storagePath: Quickshell.shellDir.toString().replace(/^file:\/\//, "") + "/reminders.json"

    function saveReminders() {
        var currentList = []
        for (var i = 0; i < reminderModel.count; i++) {
            currentList.push(reminderModel.get(i).title)
        }

        var updated = Object.assign({}, allReminders)
        if (currentList.length > 0) {
            updated[selectedKey] = currentList
        } else {
            delete updated[selectedKey]
        }
        allReminders = updated

        var jsonStr = JSON.stringify(allReminders)
        saveProcess.command = ["fish", "-c", "printf '%s\\n' '" + jsonStr.replace(/'/g, "'\\''") + "' > " + storagePath]
        saveProcess.running = true
    }

    function loadActiveReminders() {
        reminderModel.clear()
        var list = allReminders[selectedKey] || []
        for (var i = 0; i < list.length; i++) {
            reminderModel.append({ title: list[i] })
        }
    }

    onSelectedKeyChanged: loadActiveReminders()

    Process { id: saveProcess }

    Process {
        id: loadProcess
        command: ["fish", "-c", "cat " + storagePath]
        stdout: SplitParser {
            onRead: data => {
                try {
                    allReminders = JSON.parse(data)
                    root.loadActiveReminders()
                } catch (e) {
                    console.error("Failed to parse reminders JSON:", e)
                }
            }
        }
        Component.onCompleted: loadProcess.running = true
    }

    // 12-Hour Clock Logic (No leading zero)
    function get12Hour() {
        var d = new Date()
        var h = d.getHours() % 12
        return (h === 0 ? 12 : h).toString()
    }

    property string bigHour: get12Hour()
    property string bigMinute: Qt.formatTime(new Date(), "mm")
    property string bigAmPm: Qt.formatTime(new Date(), "ap")
    property string dayOfWeekStr: Qt.formatDate(selectedDate, "dddd")

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: {
            var d = new Date()
            bigHour = root.get12Hour()
            bigMinute = Qt.formatTime(d, "mm")
            bigAmPm = Qt.formatTime(d, "ap")
        }
    }

    ListModel { id: reminderModel }

    RowLayout {
        id: mainRow
        anchors.fill: parent
        anchors.margins: root.cardMargin
        spacing: root.cardMargin / 2

        // --- LEFT COLUMN: CLOCK, GRAPHIC WEATHER & REMINDERS ---
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 260
            Layout.maximumWidth: 260
            spacing: root.cardMargin / 2

            // CARD 1: HERO CLOCK & ATMOSPHERIC GRAPHIC WEATHER
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: clockWeatherCol.implicitHeight + (root.cardMargin * 2)
                color: Qt.rgba(1, 1, 1, 0.08)
                radius: Config.cornerRadius
                clip: true

                // ATMOSPHERIC BACKGROUND AMBIENT GLOW
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.9
                    height: parent.height * 0.9
                    radius: width / 2
                    color: Config.accent
                    opacity: 0.08
                }

                // MASSIVE GRAPHIC WEATHER WATERMARK
                Item {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -10
                    anchors.bottomMargin: -20
                    implicitWidth: 130
                    implicitHeight: 130

                    Text {
                        anchors.centerIn: parent
                        text: Config.weather.glyph
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 130
                        color: Config.accent
                        opacity: 0.16
                        rotation: -12
                    }
                }

                ColumnLayout {
                    id: clockWeatherCol
                    anchors.fill: parent
                    anchors.margins: root.cardMargin
                    spacing: 12

                    // HERO CLOCK DISPLAY
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        Text {
                            text: bigHour + ":" + bigMinute
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: 58
                            font.bold: true
                            font.letterSpacing: -1
                        }

                        Text {
                            text: bigAmPm.toLowerCase()
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: 34
                            font.bold: true
                            Layout.alignment: Qt.AlignBaseline
                        }
                    }

                    // GRAPHIC WEATHER HUD OVERLAY CARD
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: weatherHudRow.implicitHeight + 16
                        color: Qt.rgba(0, 0, 0, 0.25)
                        radius: Config.cornerRadius / 1.5

                        RowLayout {
                            id: weatherHudRow
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            // ACTIVE WEATHER ICON WITH BADGE GLOW
                            Rectangle {
                                implicitWidth: 40
                                implicitHeight: 40
                                radius: 20
                                color: Qt.rgba(255, 255, 255, 0.08)
                                Layout.alignment: Qt.AlignVCenter

                                Item {
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    anchors.centerIn: parent

                                    Text {
                                        anchors.centerIn: parent
                                        text: Config.weather.glyph
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 26
                                        color: Config.accent
                                    }
                                }
                            }

                            // MAIN TEMP & CONDITION DESC
                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: Config.weather.temp
                                    color: Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontTitle)
                                    font.bold: true
                                }

                                Text {
                                    text: Config.weather.desc !== "" ? Config.weather.desc : "Current Weather"
                                    color: Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontCaption)
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // FEELS LIKE STAT BADGE
                            ColumnLayout {
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                RowLayout {
                                    spacing: 4
                                    Layout.alignment: Qt.AlignRight

                                    Item {
                                        implicitWidth: 16
                                        implicitHeight: 16
                                        Layout.alignment: Qt.AlignVCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: "thermostat"
                                            font.family: "Material Symbols Outlined"
                                            font.pixelSize: 16
                                            color: Config.accent
                                        }
                                    }

                                    Text {
                                        text: Config.weather.feelsLike
                                        color: Config.accent
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontCaption)
                                        font.bold: true
                                    }
                                }

                                Text {
                                    text: "Feels Like"
                                    color: Config.textMuted
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontMicro)
                                    font.bold: true
                                    Layout.alignment: Qt.AlignRight
                                }
                            }
                        }
                    }
                }
            }

            // CARD 2: REMINDERS CARD WITH GRAPHIC WATERMARK
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Qt.rgba(1, 1, 1, 0.08)
                radius: Config.cornerRadius
                clip: true

                // GRAPHIC NOTES WATERMARK
                Item {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -12
                    anchors.bottomMargin: -16
                    implicitWidth: 110
                    implicitHeight: 110

                    Text {
                        anchors.centerIn: parent
                        text: "edit_note"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 110
                        color: Config.accent
                        opacity: 0.12
                        rotation: -10
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.cardMargin / 2
                    spacing: 8

                    RowLayout {
                        spacing: 6
                        Rectangle {
                            implicitWidth: 3; implicitHeight: 12; radius: 1.5
                            color: Config.accent
                        }
                        Text {
                            text: "NOTES / REMINDERS"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: true
                        }
                    }

                    ListView {
                        id: reminderList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: reminderModel

                        delegate: Rectangle {
                            width: reminderList.width
                            implicitHeight: rowContent.implicitHeight + 10
                            radius: Config.cornerRadius / 2
                            color: itemHover.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(0, 0, 0, 0.25)

                            Behavior on color { ColorAnimation { duration: 150 } }

                            HoverHandler { id: itemHover }

                            RowLayout {
                                id: rowContent
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 6
                                anchors.topMargin: 4
                                anchors.bottomMargin: 4
                                spacing: 8

                                Text {
                                    text: model.title
                                    color: Config.textMain
                                    font.family: Config.sysFont
                                    font.pixelSize: Config.size(Config.fontBody)
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }

                                Rectangle {
                                    id: deleteBtn
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    radius: Config.cornerRadius / 4
                                    color: deleteHover.hovered ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
                                    Layout.alignment: Qt.AlignTop

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: deleteHover.hovered ? Config.accent : Config.textMuted
                                        font.family: Config.sysFont
                                        font.pixelSize: Config.size(Config.fontSubhead)
                                        font.bold: true
                                    }

                                    TapHandler {
                                        onTapped: {
                                            reminderModel.remove(index)
                                            root.saveReminders()
                                        }
                                    }

                                    HoverHandler {
                                        id: deleteHover
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Math.max(32, noteInput.implicitHeight + 8)
                        color: Qt.rgba(0, 0, 0, 0.25)
                        radius: Config.cornerRadius / 2

                        TextEdit {
                            id: noteInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 6
                            anchors.bottomMargin: 6
                            verticalAlignment: Text.AlignVCenter
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Type a note, Enter to save..."
                                color: Config.textMuted
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontCaption)
                                visible: !noteInput.text && !noteInput.activeFocus
                            }

                            HoverHandler { cursorShape: Qt.IBeamCursor }

                            Keys.onPressed: event => {
                                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                    if (noteInput.text.trim() !== "") {
                                        reminderModel.append({ title: noteInput.text.trim() })
                                        root.saveReminders()
                                        noteInput.text = ""
                                    }
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- CARD 3: CALENDAR MONTHGRID CARD WITH GRAPHIC WATERMARK ---
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: Qt.rgba(1, 1, 1, 0.08)
            radius: Config.cornerRadius
            clip: true

            // GRAPHIC CALENDAR WATERMARK
            Item {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -15
                anchors.bottomMargin: -20
                implicitWidth: 150
                implicitHeight: 150

                Text {
                    anchors.centerIn: parent
                    text: "calendar_month"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 150
                    color: Config.accent
                    opacity: 0.07
                    rotation: -8
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.cardMargin
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: dayOfWeekStr.toUpperCase()
                        color: Config.accent
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontTitle)
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.cardMargin

                    Text {
                        text: Qt.formatDate(new Date(root.gridYear, root.gridMonth, 1), "MMMM yyyy").toUpperCase()
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontSubhead)
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: 4

                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: Config.cornerRadius / 2
                            color: prevHover.hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                            border.color: prevHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.15)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Item {
                                implicitWidth: 18
                                implicitHeight: 18
                                anchors.centerIn: parent

                                Text {
                                    anchors.centerIn: parent
                                    text: "chevron_left"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 18
                                    color: prevHover.hovered ? Config.accent : Config.textMain
                                }
                            }

                            TapHandler { onTapped: root.prevMonth() }
                            HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                        }

                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: Config.cornerRadius / 2
                            color: nextHover.hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                            border.color: nextHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.15)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Item {
                                implicitWidth: 18
                                implicitHeight: 18
                                anchors.centerIn: parent

                                Text {
                                    anchors.centerIn: parent
                                    text: "chevron_right"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 18
                                    color: nextHover.hovered ? Config.accent : Config.textMain
                                }
                            }

                            TapHandler { onTapped: root.nextMonth() }
                            HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }

                MonthGrid {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    month: root.gridMonth
                    year: root.gridYear

                    delegate: Rectangle {
                        implicitWidth: 38
                        implicitHeight: 38
                        radius: Config.cornerRadius / 1.5

                        property string cellKey: root.formatDateKey(model.date)
                        property bool isSelected: cellKey === root.selectedKey
                        property bool hasReminders: (root.allReminders[cellKey] || []).length > 0

                        color: isSelected ? Config.accent : (model.today ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                        border.color: isSelected ? Config.accent : (hasReminders ? Config.textMuted : (model.today ? Config.accent : "transparent"))
                        border.width: isSelected || hasReminders || model.today ? 1 : 0

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: model.day
                            color: isSelected ? Config.bgBase : (model.today ? Config.accent : (model.month === grid.month ? Config.textMain : Qt.rgba(255,255,255,0.15)))
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontSubhead)
                            font.bold: model.today || isSelected || hasReminders
                        }

                        TapHandler {
                            onTapped: root.selectedDate = model.date
                        }

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }
    }
}