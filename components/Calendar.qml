import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.qmlmodels
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "settings"

MorphingFlyout {
    id: root

    panelWidth: 680
    panelHeight: 460
    isOpen: Config.showCalendar
    alignRight: true

    flyoutBorderColor: Config.accent

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
        running: true
        repeat: true
        onTriggered: {
            var d = new Date()
            bigHour = root.get12Hour()
            bigMinute = Qt.formatTime(d, "mm")
            bigAmPm = Qt.formatTime(d, "ap")
        }
    }

    // --- WEATHER MODULE INTEGRATION ---
    WeatherSettings {
        id: weather
        zipcode: Config.locationQuery || ""
        
        // Fetch new data immediately whenever the zipcode/location updates
        onZipcodeChanged: weather.fetchWeather(true)
    }

    // Fetch once on shell launch
    Component.onCompleted: {
        weather.fetchWeather(true)
    }

    // Refresh every 15 minutes continuously in background
    Timer {
        interval: 900000 // 15 minutes
        running: true
        repeat: true
        onTriggered: weather.fetchWeather(true)
    }

    ListModel { id: reminderModel }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // --- LEFT COLUMN: CLOCK, WEATHER & REMINDERS ---
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 250
            Layout.maximumWidth: 250
            spacing: 12

            // CARD 1: CLOCK & WEATHER
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: clockWeatherCol.implicitHeight + 20
                color: Qt.rgba(255, 255, 255, 0.05)
                radius: Config.cornerRadius

                ColumnLayout {
                    id: clockWeatherCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        Text {
                            text: bigHour + ":" + bigMinute
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size([32, 36, 40])
                            font.bold: true
                        }

                        Text {
                            text: bigAmPm
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontTitle)
                            font.bold: true
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 2

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 6

                            Text {
                                text: weather.glyph
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 24
                                color: Config.accent
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: weather.temp
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: Config.size(Config.fontSubhead)
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        Text {
                            text: weather.desc + "\nFeels like " + weather.feelsLike
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // CARD 2: REMINDERS
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Qt.rgba(255, 255, 255, 0.05)
                radius: Config.cornerRadius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "NOTES / REMINDERS"
                        color: Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontCaption)
                        font.bold: true
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
                            color: itemHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(0, 0, 0, 0.15)

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
                        color: Qt.rgba(0, 0, 0, 0.15)
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

        // --- CARD 3: CALENDAR MONTHGRID ---
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: Qt.rgba(255, 255, 255, 0.05)
            radius: Config.cornerRadius

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
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
                    spacing: 12

                    Text {
                        text: Qt.formatDate(new Date(root.gridYear, root.gridMonth, 1), "MMMM yyyy").toUpperCase()
                        color: Config.textMain
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontSubhead)
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: Config.cornerRadius / 2
                        color: prevHover.hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                        border.color: prevHover.hovered ? Config.accent : Qt.rgba(255, 255, 255, 0.15)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "chevron_left"
                            color: prevHover.hovered ? Config.accent : Config.textMain
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
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

                        Text {
                            anchors.centerIn: parent
                            text: "chevron_right"
                            color: nextHover.hovered ? Config.accent : Config.textMain
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                        }

                        TapHandler { onTapped: root.nextMonth() }
                        HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
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
                            color: isSelected ? Config.textMain : (model.today ? Config.accent : (model.month === grid.month ? Config.textMain : Qt.rgba(255,255,255,0.15)))
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