import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: barRoot

    property string password: ""
    property bool isAuthenticating: false
    property bool isError: false
    property bool isSuccess: false
    property bool capsLockActive: false
    property string placeholderText: "Enter password..."
    property string paletteMode: Config.lockscreenShapePalette || "vibrant"
    property string maskStyle: Config.lockscreenMaskStyle || "shapes"

    onMaskStyleChanged: shuffleShapes()
    onPaletteModeChanged: shuffleShapes()

    signal submitPassword(string pass)
    signal clearRequested()

    implicitWidth: 440
    implicitHeight: 58

    // Internal Shape Data Model
    property var shapeItems: []

    // Curated Special Characters Bank
    readonly property var specialChars: [
        "!", "@", "#", "$", "%", "^", "&", "*", "~", "?",
        "+", "=", "<", ">", "/", "§", "★", "◆", "▲", "■",
        "✦", "❖", "◈", "⚡", "λ", "π", "Ω", "¥", "€", "∞",
        "∆", "∑", "√", "⬡", "⌘"
    ]

    // Curated Palette Banks
    readonly property var vibrantPalette: [
        "#00f0ff", "#a855f7", "#f59e0b", "#10b981", "#ec4899",
        "#38bdf8", "#f43f5e", "#84cc16", "#06b6d4", "#e879f9",
        "#fbbf24", "#34d399", "#60a5fa", "#f472b6", "#a78bfa"
    ]

    readonly property var neonPalette: [
        "#00f0ff", "#ff0055", "#00ff66", "#ff5f00", "#ccff00",
        "#bf00ff", "#0066ff", "#ff00a0", "#40e0d0", "#ff2a6d"
    ]

    readonly property var pastelPalette: [
        "#93c5fd", "#c4b5fd", "#fca5a5", "#fde047", "#86efac",
        "#f9a8d4", "#a5f3fc", "#fed7aa", "#d8b4fe", "#cbd5e1"
    ]

    readonly property var monochromePalette: [
        "#ffffff", "#f1f5f9", "#e2e8f0", "#cbd5e1", "#94a3b8",
        "#64748b", "#f8fafc", "#e0e0e0"
    ]

    function getRandomColor() {
        if (paletteMode === "accent") {
            let base = Config.accent
            let variants = [
                base,
                Qt.lighter(base, 1.3),
                Qt.lighter(base, 1.6),
                Qt.darker(base, 1.2),
                Qt.lighter(base, 1.15)
            ]
            return variants[Math.floor(Math.random() * variants.length)]
        } else if (paletteMode === "neon") {
            return neonPalette[Math.floor(Math.random() * neonPalette.length)]
        } else if (paletteMode === "pastel") {
            return pastelPalette[Math.floor(Math.random() * pastelPalette.length)]
        } else if (paletteMode === "monochrome") {
            return monochromePalette[Math.floor(Math.random() * monochromePalette.length)]
        } else {
            // Default: Vibrant
            let list = vibrantPalette.concat([Config.accent])
            return list[Math.floor(Math.random() * list.length)]
        }
    }

    function generateShapeToken(charIndex) {
        let rotations = [0, 45, 90, 135, 180, 225, 270, 315]
        let pickedChar = specialChars[Math.floor(Math.random() * specialChars.length)]
        return {
            id: Date.now() + "_" + Math.random(),
            shapeIndex: Math.floor(Math.random() * 16),
            color: getRandomColor(),
            rotation: rotations[Math.floor(Math.random() * rotations.length)],
            isOutline: Math.random() < 0.22,
            charGlyph: pickedChar,
            maskStyle: barRoot.maskStyle,
            animIndex: charIndex
        }
    }

    function shuffleShapes() {
        let newItems = []
        for (let i = 0; i < password.length; i++) {
            newItems.push(generateShapeToken(i))
        }
        shapeItems = newItems
    }

    function syncShapesWithPassword(newText) {
        let currentLen = shapeItems.length
        let targetLen = newText.length

        if (targetLen === 0) {
            shapeItems = []
            return
        }

        if (targetLen > currentLen) {
            let updated = shapeItems.slice()
            for (let i = currentLen; i < targetLen; i++) {
                updated.push(generateShapeToken(i))
            }
            shapeItems = updated
        } else if (targetLen < currentLen) {
            shapeItems = shapeItems.slice(0, targetLen)
        }
    }

    function triggerSubmit() {
        if (password.length > 0 && !isAuthenticating) {
            barRoot.submitPassword(password)
        }
    }

    function clearInput() {
        password = ""
        shapeItems = []
        hiddenInput.text = ""
        barRoot.clearRequested()
    }

    function triggerErrorFeedback() {
        isError = true
        shakeAnimation.restart()
        errorResetTimer.restart()
    }

    function forceFocus() {
        hiddenInput.forceActiveFocus()
    }

    // Hardware / Compositor CapsLock Detection Process
    Process {
        id: capsCheckProc
        command: [
            "sh", "-c",
            "hyprctl devices -j 2>/dev/null | grep -q '\"capsLock\": true' && echo 1 || (cat /sys/class/leds/*capslock*/brightness 2>/dev/null | grep -q '[1-9]' && echo 1 || echo 0)"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                barRoot.capsLockActive = (this.text.trim() === "1")
            }
        }
    }

    function checkCapsLock() {
        capsCheckProc.running = false
        capsCheckProc.running = true
    }

    Timer {
        id: errorResetTimer
        interval: 650
        repeat: false
        onTriggered: {
            clearInput()
            isError = false
            forceFocus()
        }
    }

    // Horizontal Shake Animation for Error Feedback
    SequentialAnimation {
        id: shakeAnimation
        NumberAnimation { target: shakeContainer; property: "x"; to: -14; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeContainer; property: "x"; to: 14; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeContainer; property: "x"; to: -10; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeContainer; property: "x"; to: 10; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeContainer; property: "x"; to: -5; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeContainer; property: "x"; to: 5; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeContainer; property: "x"; to: 0; duration: 40; easing.type: Easing.OutQuad }
    }

    Item {
        id: shakeContainer
        anchors.fill: parent

        // Outer Glow
        RectangularGlow {
            anchors.fill: barBg
            glowRadius: barRoot.isError ? 16 : (barRoot.isSuccess ? 18 : (hiddenInput.activeFocus ? 12 : 6))
            spread: 0.2
            color: barRoot.isError 
                ? Qt.rgba(239/255, 68/255, 68/255, 0.6) 
                : (barRoot.isSuccess 
                    ? Qt.rgba(16/255, 185/255, 129/255, 0.7) 
                    : Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, hiddenInput.activeFocus ? 0.4 : 0.15))
            cornerRadius: barBg.radius
            visible: Config.clockShowGlow !== false

            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on glowRadius { NumberAnimation { duration: 200 } }
        }

        // Main Bar Surface
        Rectangle {
            id: barBg
            anchors.fill: parent
            radius: 29
            color: Qt.rgba(Config.bgPanel.r, Config.bgPanel.g, Config.bgPanel.b, 0.72)
            border.width: 1.5
            border.color: barRoot.isError 
                ? "#ef4444" 
                : (barRoot.isSuccess 
                    ? "#10b981" 
                    : (hiddenInput.activeFocus ? Config.accent : Qt.rgba(255, 255, 255, 0.15)))

            Behavior on border.color { ColorAnimation { duration: 200 } }

            // Click anywhere on bar to focus
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onPressed: barRoot.forceFocus()
                onClicked: barRoot.forceFocus()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 10
                spacing: 10

                // LEADING ICON (LOCK / KEY)
                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 18
                    color: barRoot.isError 
                        ? Qt.rgba(239/255, 68/255, 68/255, 0.18) 
                        : (barRoot.isSuccess 
                            ? Qt.rgba(16/255, 185/255, 129/255, 0.2) 
                            : Qt.rgba(255, 255, 255, 0.08))

                    Text {
                        anchors.centerIn: parent
                        text: barRoot.isSuccess ? "lock_open" : (barRoot.isError ? "lock_reset" : "lock")
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 20
                        color: barRoot.isError ? "#ef4444" : (barRoot.isSuccess ? "#10b981" : Config.accent)

                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onPressed: barRoot.forceFocus()
                        onClicked: barRoot.forceFocus()
                    }
                }

                // CENTER: SHAPES CONTAINER / PLACEHOLDER
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onPressed: barRoot.forceFocus()
                        onClicked: barRoot.forceFocus()
                    }

                    // Placeholder Text & Leading Cursor
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        visible: barRoot.password.length === 0
                        spacing: 8

                        // Soft Blinking Cursor (All the way to the left)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 2
                            implicitHeight: 20
                            radius: 1
                            color: Config.accent
                            visible: hiddenInput.activeFocus

                            SequentialAnimation on opacity {
                                running: hiddenInput.activeFocus && barRoot.password.length === 0
                                loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 0.0; duration: 530; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 0.0; to: 1.0; duration: 530; easing.type: Easing.InOutQuad }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: barRoot.placeholderText
                            color: Config.textMuted
                            font.family: Config.sysFont
                            font.pixelSize: Config.size(Config.fontBody)
                            font.italic: true
                            opacity: 0.7
                        }
                    }

                    // Horizontal Shapes Flow
                    Flickable {
                        id: shapesFlickable
                        anchors.fill: parent
                        contentWidth: shapesRow.width
                        contentHeight: parent.height
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: shapesRow.width > shapesFlickable.width
                        clip: true

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onPressed: barRoot.forceFocus()
                            onClicked: barRoot.forceFocus()
                        }

                        Row {
                            id: shapesRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Repeater {
                                model: barRoot.shapeItems

                                delegate: LockscreenShapeGlyph {
                                    id: glyphItem
                                    shapeIndex: modelData.shapeIndex !== undefined ? modelData.shapeIndex : 0
                                    shapeColor: modelData.color !== undefined ? modelData.color : Config.accent
                                    targetRotation: modelData.rotation !== undefined ? modelData.rotation : 0
                                    isOutline: modelData.isOutline !== undefined ? modelData.isOutline : false
                                    charGlyph: modelData.charGlyph !== undefined ? modelData.charGlyph : "*"
                                    maskStyle: modelData.maskStyle !== undefined ? modelData.maskStyle : barRoot.maskStyle
                                    isError: barRoot.isError
                                    isSuccess: barRoot.isSuccess
                                    isAuthenticating: barRoot.isAuthenticating
                                    animIndex: index
                                }
                            }

                            onWidthChanged: {
                                if (width > shapesFlickable.width) {
                                    shapesFlickable.contentX = width - shapesFlickable.width
                                } else {
                                    shapesFlickable.contentX = 0
                                }
                            }
                        }
                    }
                }

                // TRAILING ACTIONS / INDICATORS

                // CAPS LOCK BADGE
                Rectangle {
                    visible: barRoot.capsLockActive
                    implicitWidth: capsRow.implicitWidth + 12
                    implicitHeight: 26
                    radius: 13
                    color: Qt.rgba(245/255, 158/255, 11/255, 0.2)
                    border.width: 1
                    border.color: "#f59e0b"

                    RowLayout {
                        id: capsRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: "arrow_upward"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#f59e0b"
                        }

                        Text {
                            text: "CAPS"
                            font.family: Config.sysFont
                            font.pixelSize: 10
                            font.bold: true
                            color: "#f59e0b"
                        }
                    }
                }

                // CLEAR (X) BUTTON
                Rectangle {
                    id: clearBtn
                    visible: barRoot.password.length > 0 && !barRoot.isAuthenticating
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 16
                    color: clearMouse.containsMouse ? Qt.rgba(239/255, 68/255, 68/255, 0.2) : Qt.rgba(255, 255, 255, 0.08)

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "cancel"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 18
                        color: clearMouse.containsMouse ? "#ef4444" : Config.textMuted

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            barRoot.clearInput()
                            barRoot.forceFocus()
                        }
                    }
                }

                // SUBMIT BUTTON (ARROW OR SPINNER)
                Rectangle {
                    id: submitBtn
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    color: submitMouse.containsMouse 
                        ? Config.accent 
                        : (barRoot.password.length > 0 ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.85) : Qt.rgba(255, 255, 255, 0.08))

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Item {
                        anchors.centerIn: parent
                        width: 24
                        height: 24

                        // Submitting Spinner
                        Text {
                            anchors.centerIn: parent
                            visible: barRoot.isAuthenticating
                            text: "progress_activity"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            color: Config.bgBase

                            RotationAnimation on rotation {
                                running: barRoot.isAuthenticating
                                from: 0
                                to: 360
                                duration: 800
                                loops: Animation.Infinite
                            }
                        }

                        // Arrow Forward
                        Text {
                            anchors.centerIn: parent
                            visible: !barRoot.isAuthenticating
                            text: "arrow_forward"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            font.bold: true
                            color: barRoot.password.length > 0 ? Config.bgBase : Config.textMuted
                        }
                    }

                    MouseArea {
                        id: submitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (barRoot.password.length > 0 && !barRoot.isAuthenticating) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: barRoot.password.length > 0 && !barRoot.isAuthenticating
                        onClicked: {
                            barRoot.triggerSubmit()
                        }
                    }
                }
            }
        }
    }

    // Real TextInput handling keystrokes without blocking mouse events
    TextInput {
        id: hiddenInput
        anchors.fill: parent
        opacity: 0.01
        color: "transparent"
        z: -1
        focus: true
        echoMode: TextInput.NoEcho
        clip: true
        cursorVisible: false
        selectByMouse: false

        onTextChanged: {
            barRoot.password = text
            barRoot.syncShapesWithPassword(text)
        }

        Keys.onPressed: (event) => {
            // Ignore OS key autorepeat so a single hold doesn't rapid-fire toggle
            if (event.key === Qt.Key_CapsLock) {
                if (!event.isAutoRepeat) {
                    barRoot.capsLockActive = !barRoot.capsLockActive
                }
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true
                barRoot.triggerSubmit()
            } else if (event.key === Qt.Key_Escape) {
                event.accepted = true
                barRoot.clearInput()
            } else if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_U || event.key === Qt.Key_Backspace) {
                    event.accepted = true
                    barRoot.clearInput()
                }
            }
        }
    }

    Component.onCompleted: {
        forceFocus()
        checkCapsLock()
    }
}