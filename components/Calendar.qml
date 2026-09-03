import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.qmlmodels
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets

Item {
    id: root

    readonly property real cardMargin: Config.cardMargin !== undefined ? Config.cardMargin : 12

    // Baseline panel bounds to prevent Layout.fillHeight/fillWidth collapse
    implicitWidth: 680
    implicitHeight: 460 + forecastCard.implicitHeight + (cardMargin / 2)

    readonly property var forecastDayLabels: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

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

    FileView {
        id: remindersFileReader
        path: root.storagePath
        onTextChanged: {
            let raw = text()
            if (!raw || raw.trim() === "") return
            try {
                allReminders = JSON.parse(raw.trim())
                root.loadActiveReminders()
            } catch (e) {
                console.error("Failed to parse reminders JSON:", e)
            }
        }
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
    property string formattedDateUpper: Qt.formatDate(new Date(), "dddd, MMM d").toUpperCase()

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: {
            var d = new Date()
            bigHour = root.get12Hour()
            bigMinute = Qt.formatTime(d, "mm")
            bigAmPm = Qt.formatTime(d, "ap")
            formattedDateUpper = Qt.formatDate(d, "dddd, MMM d").toUpperCase()
        }
    }

    ListModel { id: reminderModel }

    // --- SWAPPABLE LAYOUT STATE ---
    // Three independent, single-axis swaps - nothing resizes, only position
    // changes: the forecast strip trades places with the row below it
    // (drag the forecast strip); the month grid trades places with the
    // clock/weather+notes pair as a whole (drag the month grid); and within
    // that pair, clock/weather and notes only ever swap with each other
    // (drag either one) - they can never end up outside the pair.
    property bool forecastOnBottom: false
    property bool bigCardOnLeft: false
    property bool notesOnTop: false
    property bool layoutReady: false

    function applyCalendarArrangement(saved) {
        forecastOnBottom = !!(saved && saved.forecastOnBottom)
        bigCardOnLeft = !!(saved && saved.bigCardOnLeft)
        notesOnTop = !!(saved && saved.notesOnTop)
        layoutReady = true
    }

    function saveCalendarArrangement() {
        Config.calendarArrangement = {
            forecastOnBottom: root.forecastOnBottom,
            bigCardOnLeft: root.bigCardOnLeft,
            notesOnTop: root.notesOnTop
        }
        Config.saveSettings()
    }

    onForecastOnBottomChanged: if (layoutReady) saveCalendarArrangement()
    onBigCardOnLeftChanged: if (layoutReady) saveCalendarArrangement()
    onNotesOnTopChanged: if (layoutReady) saveCalendarArrangement()

    Connections {
        target: Config
        function onIsLoadedChanged() {
            if (Config.isLoaded) root.applyCalendarArrangement(Config.calendarArrangement)
        }
    }
    Component.onCompleted: {
        root.applyCalendarArrangement(Config.isLoaded ? Config.calendarArrangement : null)
    }

    // Swap-threshold checks: each fires only while its own item is being
    // dragged, comparing that item's live center against the center of
    // whichever slot it isn't currently in.
    function forecastDragMoved(dy) {
        let baseY = forecastOnBottom ? (outerArea.mainRowH + outerArea.spacing) : 0
        let center = baseY + dy + outerArea.forecastH / 2
        if (!forecastOnBottom) {
            let otherCenter = (outerArea.forecastH + outerArea.spacing) + outerArea.mainRowH / 2
            if (center > otherCenter) forecastOnBottom = true
        } else {
            let otherCenter = outerArea.forecastH / 2
            if (center < otherCenter) forecastOnBottom = false
        }
    }

    function calendarDragMoved(dx) {
        let baseX = bigCardOnLeft ? 0 : (outerArea.leftColW + outerArea.spacing)
        let center = baseX + dx + outerArea.bigCardW / 2
        if (!bigCardOnLeft) {
            let otherCenter = outerArea.leftColW / 2
            if (center < otherCenter) bigCardOnLeft = true
        } else {
            let otherCenter = (outerArea.bigCardW + outerArea.spacing) + outerArea.leftColW / 2
            if (center > otherCenter) bigCardOnLeft = false
        }
    }

    function clockWeatherDragMoved(dy) {
        let baseY = notesOnTop ? (outerArea.notesH + outerArea.spacing) : 0
        let center = baseY + dy + outerArea.clockWeatherH / 2
        if (!notesOnTop) {
            let otherCenter = (outerArea.clockWeatherH + outerArea.spacing) + outerArea.notesH / 2
            if (center > otherCenter) notesOnTop = true
        } else {
            let otherCenter = outerArea.notesH / 2
            if (center < otherCenter) notesOnTop = false
        }
    }

    function notesDragMoved(dy) {
        let baseY = notesOnTop ? 0 : (outerArea.clockWeatherH + outerArea.spacing)
        let center = baseY + dy + outerArea.notesH / 2
        if (notesOnTop) {
            let otherCenter = (outerArea.notesH + outerArea.spacing) + outerArea.clockWeatherH / 2
            if (center > otherCenter) notesOnTop = false
        } else {
            let otherCenter = outerArea.clockWeatherH / 2
            if (center < otherCenter) notesOnTop = true
        }
    }

    Item {
        id: outerArea
        anchors.fill: parent
        anchors.margins: root.cardMargin

        // Geometry is computed from root's stable authored dimensions, not
        // from this Item's own live width/height - those track whatever the
        // enclosing popup/drawer actually renders at any given moment, which
        // can take a beat to settle to its final size as it opens. Using the
        // fixed implicitWidth/implicitHeight instead means every card's
        // target position is correct from the very first frame, with
        // nothing to visibly "expand into" afterward.
        readonly property real contentW: root.implicitWidth - (root.cardMargin * 2)
        readonly property real contentH: root.implicitHeight - (root.cardMargin * 2)

        readonly property real spacing: root.cardMargin / 2
        readonly property real forecastH: 92
        readonly property real mainRowH: contentH - forecastH - spacing
        readonly property real leftColW: 260
        readonly property real bigCardW: contentW - leftColW - spacing
        readonly property real clockWeatherH: clockWeatherCol.implicitHeight + (root.cardMargin * 2)
        readonly property real notesH: mainRowH - clockWeatherH - spacing

        readonly property real forecastY: root.forecastOnBottom ? (mainRowH + spacing) : 0
        readonly property real mainRowY: root.forecastOnBottom ? 0 : (forecastH + spacing)
        readonly property real columnGroupX: root.bigCardOnLeft ? (bigCardW + spacing) : 0
        readonly property real bigCardX: root.bigCardOnLeft ? 0 : (leftColW + spacing)
        readonly property real clockWeatherY: root.notesOnTop ? (notesH + spacing) : 0
        readonly property real notesY: root.notesOnTop ? 0 : (clockWeatherH + spacing)

    // --- 7-DAY FORECAST STRIP --- (swaps top/bottom with the row below it)
    SwapItem {
        id: forecastSlot
        axis: Qt.Vertical
        targetX: 0
        targetY: outerArea.forecastY
        targetWidth: outerArea.contentW
        targetHeight: outerArea.forecastH
        ready: root.layoutReady
        onDragMoved: (dx, dy) => root.forecastDragMoved(dy)

    // ClippingRectangle (not plain Rectangle) so the watermark actually
    // respects the rounded corners instead of bleeding past them - plain
    // Rectangle.clip only clips to the square bounding box.
    ClippingRectangle {
        id: forecastCard
        anchors.fill: parent
        implicitHeight: 92
        color: Qt.rgba(1, 1, 1, 0.08)
        radius: Config.cornerRadius
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.1)

        Behavior on border.color { ColorAnimation { duration: 150 } }

        Watermark {
            icon: Config.weather.glyph
            iconSize: 110
            baseRotation: -8
            seed: 9
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: root.cardMargin / 2
            anchors.rightMargin: root.cardMargin / 2
            spacing: 4

            Repeater {
                model: Config.weather.forecast

                delegate: ColumnLayout {
                    id: dayCol
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: 2

                    readonly property bool isToday: index === 0

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.forecastDayLabels[new Date(dayCol.modelData.date + "T00:00:00").getDay()]
                        color: dayCol.isToday ? Config.accent : Config.textMuted
                        font.family: Config.sysFont
                        font.pixelSize: Config.size(Config.fontMicro)
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: dayCol.modelData.glyph
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 20
                        color: dayCol.isToday ? Config.accent : Config.textMain
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 3

                        Text {
                            text: dayCol.modelData.maxF + "°"
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                            font.bold: true
                        }

                        Text {
                            text: dayCol.modelData.minF + "°"
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontMicro)
                        }
                    }
                }
            }
        }
    }
    }

    // --- LEFT/RIGHT PAIR: CLOCK/WEATHER + NOTES (swaps sides with the month
    // grid as a unit; the two of them are never dragged directly for this -
    // they only ever swap with each other, below) ---
    Item {
        id: columnGroupSlot
        x: outerArea.columnGroupX
        y: outerArea.mainRowY
        width: outerArea.leftColW
        height: outerArea.mainRowH

        Behavior on x { enabled: root.layoutReady; SpringAnimation { spring: 3.2; damping: 0.4; mass: 0.9 } }
        Behavior on y { enabled: root.layoutReady; SpringAnimation { spring: 3.2; damping: 0.4; mass: 0.9 } }

            // CARD 1: HERO CLOCK & ATMOSPHERIC GRAPHIC WEATHER (swaps up/down
            // with the notes card only)
            SwapItem {
                id: clockWeatherSlot
                axis: Qt.Vertical
                targetX: 0
                targetY: outerArea.clockWeatherY
                targetWidth: columnGroupSlot.width
                targetHeight: outerArea.clockWeatherH
                ready: root.layoutReady
                onDragMoved: (dx, dy) => root.clockWeatherDragMoved(dy)

            // ClippingRectangle (not plain Rectangle) so the watermark actually
            // respects the rounded corners instead of bleeding past them - plain
            // Rectangle.clip only clips to the square bounding box.
            ClippingRectangle {
                anchors.fill: parent
                color: Qt.rgba(1, 1, 1, 0.08)
                radius: Config.cornerRadius
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.1)

                Behavior on border.color { ColorAnimation { duration: 150 } }

                // MASSIVE GRAPHIC WEATHER WATERMARK
                Watermark {
                    icon: Config.weather.glyph
                    iconSize: 150
                    seed: 6
                }

                ColumnLayout {
                    id: clockWeatherCol
                    anchors.fill: parent
                    anchors.margins: root.cardMargin
                    spacing: 10

                    // TOP HEADER: DAY & DATE PILL
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            implicitWidth: 3
                            implicitHeight: 12
                            radius: 1.5
                            color: Config.accent
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: root.formattedDateUpper
                            color: Config.accent
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontCaption)
                            font.bold: true
                            font.letterSpacing: 1.1
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    // HERO CLOCK DISPLAY (CENTERED WITH EXACT MATCH ACCENT GLOW)
                    RowLayout {
                        id: heroTimeRow
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        Item {
                            implicitWidth: heroTimeText.implicitWidth
                            implicitHeight: heroTimeText.implicitHeight

                            Glow {
                                anchors.fill: heroTimeText
                                source: heroTimeText
                                radius: 12
                                samples: 24
                                color: Config.accent
                                spread: 0.2
                                transparentBorder: true
                                visible: Config.clockShowGlow
                            }

                            Text {
                                id: heroTimeText
                                anchors.fill: parent
                                text: bigHour + ":" + bigMinute
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: 68
                                font.bold: true
                                font.italic: true
                                font.letterSpacing: -2.0
                            }
                        }

                        Rectangle {
                            implicitWidth: amPmText.implicitWidth + 10
                            implicitHeight: 22
                            radius: 11
                            color: Qt.rgba(255, 255, 255, 0.10)
                            border.width: 2
                            border.color: Qt.rgba(255, 255, 255, 0.15)
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 8

                            Text {
                                id: amPmText
                                anchors.centerIn: parent
                                text: bigAmPm.toUpperCase()
                                color: Config.textMain
                                font.family: Config.sysFont
                                font.pixelSize: 13
                                font.bold: true
                                font.italic: true
                            }
                        }
                    }

                    // WEATHER TYPOGRAPHY (ELIDED & BOUNDED TO PREVENT OVERFLOW)
                    RowLayout {
                        spacing: 6
                        Layout.fillWidth: true

                        Text {
                            text: Config.weather.temp
                            color: Config.textMain
                            font.family: Config.sysFont
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Rectangle {
                            implicitWidth: 4
                            implicitHeight: 4
                            radius: 2
                            color: Config.accent
                            Layout.alignment: Qt.AlignVCenter
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
                }
            }
            }

            // CARD 2: REMINDERS CARD WITH GRAPHIC WATERMARK (swaps up/down
            // with the clock/weather card only)
            SwapItem {
                id: notesSlot
                axis: Qt.Vertical
                targetX: 0
                targetY: outerArea.notesY
                targetWidth: columnGroupSlot.width
                targetHeight: outerArea.notesH
                ready: root.layoutReady
                onDragMoved: (dx, dy) => root.notesDragMoved(dy)

            // ClippingRectangle (not plain Rectangle) so the watermark actually
            // respects the rounded corners instead of bleeding past them - plain
            // Rectangle.clip only clips to the square bounding box.
            ClippingRectangle {
                anchors.fill: parent
                color: Qt.rgba(1, 1, 1, 0.08)
                radius: Config.cornerRadius
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.1)

                Behavior on border.color { ColorAnimation { duration: 150 } }

                // GRAPHIC NOTES WATERMARK
                Watermark {
                    icon: "edit_note"
                    iconSize: 110
                    baseRotation: 10
                    seed: 7
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
        }

        // --- CARD 3: CALENDAR MONTHGRID (swaps sides with the pair above) ---
        // ClippingRectangle (not plain Rectangle) so the watermark actually
        // respects the rounded corners instead of bleeding past them - plain
        // Rectangle.clip only clips to the square bounding box.
        SwapItem {
            id: bigCardSlot
            axis: Qt.Horizontal
            targetX: outerArea.bigCardX
            targetY: outerArea.mainRowY
            targetWidth: outerArea.bigCardW
            targetHeight: outerArea.mainRowH
            ready: root.layoutReady
            onDragMoved: (dx, dy) => root.calendarDragMoved(dx)

        ClippingRectangle {
            anchors.fill: parent
            color: Qt.rgba(1, 1, 1, 0.08)
            radius: Config.cornerRadius
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.1)

            Behavior on border.color { ColorAnimation { duration: 150 } }

            // GRAPHIC CALENDAR WATERMARK
            Watermark {
                icon: "calendar_month"
                iconSize: 150
                seed: 8
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
}